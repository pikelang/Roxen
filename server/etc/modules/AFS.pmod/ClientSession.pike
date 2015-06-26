// $Id$

//!
//! Represents a client session
//!

#if constant(roxen)
// This include is to get ASSERT_IF_DEBUG and the OBJ_COUNT stuff.
#include <roxen.h>
#else

// Our own debug macros when run outside Roxen.
#ifdef DEBUG
#define DO_IF_DEBUG(X...) X
#define ASSERT_IF_DEBUG(TEST, ARGS...) do {			\
    if (!(TEST)) error ("Assertion failed: " #TEST "\n", ARGS);	\
  } while (0)
#else
#define DO_IF_DEBUG(X...)
#define ASSERT_IF_DEBUG(TEST, ARGS...) do {} while (0)
#endif

#ifdef OBJ_COUNT_DEBUG
#define DECLARE_OBJ_COUNT \
  protected int __object_count = ++all_constants()->_obj_count
#define OBJ_COUNT ("[" + this_program::__object_count + "]")
#else
#define DECLARE_OBJ_COUNT ;
#define OBJ_COUNT ""
#endif

#endif  // !constant(roxen)


#ifdef DEBUG_CLIENT_SESSION
#define DWERROR(x ...) werror(x)
#else
#define DWERROR(x ...)
#endif

constant NOTIFY_DELAY = 0.1;
constant DEFAULT_SESSION_TTL = 60.0;
constant THROTTLE_WINDOW = 2;

//! Session time to live between requests
float session_ttl = DEFAULT_SESSION_TTL;

//! Last time the session kill timer was reset
int last_activity = time();

//! Aggregated subscribe set. Index is a subscription type and the
//! value are subscription parameters, such as ids of the objects to
//! which the client listens.
private multiset(.Types.ClientMessage) subscribed_to = (<>);

//! Subscriptions per subscription ID. This allows the client to
//! cancel one subscription without affecting others.
private mapping(SubscriptionID:Subscription) subscriptions = ([]);

//! Request waiting for server push notifications.
private RequestID notification_id;

//! Client tag associated with the long-standing poll request. Only valid
//! when notification_id is set.
private string notification_poll_tag;

//! Pending callout to flush data to notification request.
private mixed send_callout;

//! Notification request TTL callback
private mixed notification_ttl_callback;

//! Holds pending responses to be sent to the client on next poll.
protected array(mapping) command_responses = ({});

#ifdef DEBUG
// Internal counter for debug purposes. Increments every time a
// response is pushed to the response queue for the session.
int response_counter = 0;
#endif

//! Pointer to the caller context that created us (i.e. where a global
//! session table is kept).
object my_parent_obj;

//! Timestamps indexed on response hashes so we can detect if same message
//! is delivered too frequently and needs throttling.
mapping(string:int) sent_responses = ([]);


//!  Modifies a response mapping in place with required members. Please
//!  see @[push_response] for a description of input parameters.
//!
//!  @returns
//!    If the response is already queued the return value is 0, otherwise
//!    a reference to the modified @[resp] mapping.
//!
//! @note
//!   @[lfun::destroy()]-safe.
private mapping|int(0..0) prepare_response(AFS.Types.ClientMessage msg_type,
					   mapping resp, void|string tag)
{
  ASSERT_IF_DEBUG(mappingp(resp));
  resp->msg_type = msg_type;
  resp->sid = session_id;
  if (tag)
    resp->tag = tag;

  //  Compute hash for current response. The hash has no value to clients so
  //  we'll zap it in get_responses().
  string resp_hash =
    resp->_hash ||
    (resp->_hash = Crypto.MD5.hash(sprintf("%O", resp)));

  return resp;
}


protected int(0..1) push_response_low(AFS.Types.ClientMessage msg_type,
				      mapping resp, void|string tag,
				      void|SubscriptionID subscription_id,
				      void|int(0..1) do_throttle)
{
  // Only string indexes are supported by Standards.JSON.encode().
  ASSERT_IF_DEBUG (!has_value (map (indices (resp), stringp), 0));

  resp = resp + ([]);
  if (subscription_id)
    resp->subscription_id = subscription_id;

  //  The _throttled entry is a timestamp identifying the earliest time of
  //  delivery. We set a trivial past timestamp to indicate that it's
  //  managed, but need to update it below before it's queued.
  if (do_throttle)
    resp->_throttled = 1;
  
  //  Add required members and skip duplicate responses
  if (!prepare_response(msg_type, resp, tag))
    return 0;

  string hash = resp->_hash;
  if (!hash)
    return 0;
  
  //  If we already know the entry will be throttled we can compute next
  //  wake-up time here.
  float wakeup_delay = (float) NOTIFY_DELAY;
  if (do_throttle) {
    int now = time();
    int last_ts = sent_responses[hash];
    if (last_ts + THROTTLE_WINDOW > now)
      wakeup_delay = (float) (last_ts + THROTTLE_WINDOW - now);

    //  Make sure we have a reasonable delivery timestamp before putting it
    //  in the queue (which might still be in the past if last_ts is zero).
    //  This avoids the scan for immediate responses in set_notification_id()
    //  to find a false candidate which would yield an unnecessary empty poll
    //  result.
    resp->_throttled = last_ts + THROTTLE_WINDOW;
  }

  command_responses += ({ resp });
#ifdef DEBUG
  response_counter++;
#endif
  DWERROR("Added response to %O\n", this);

  if (notification_id && !send_callout) {
    send_callout = call_out(roxen.handle, wakeup_delay, send_data);
  }

  //  Throttled messages are not yet known if they will be delivered or not,
  //  so flag them as undelivered at this point. This means we won't perform
  //  action logging for potentially suppressed messages in low_call_cb()
  //  synchronously, but we'll instead log these during actual delivery.
  return do_throttle ? 0 : 1;
}


//! Adds a command response to the array of responses.
//!
//! To prevent interference between third party extensions and the
//! built-in functions, any third party actions must prefix their
//! actions with a "namespace". This is done by adding a dotted prefix
//! part to the name of the action. For example, "third.party.action"
//! where "third.party" would be the namespace and "action" would be
//! the action. This convention will ensure that two commands doesn't
//! collide unintentionally.
//!
//! Description of the response mapping:
//!
//! @param resp
//!   The response to a command. A command response mapping has
//!   the following predefined fields:
//!
//! @mapping
//! @member AFS.Types.ClientMessage "msg_type"
//!   The message type.
//!
//! @member string "tag"
//!   Value containing the tag the client sent with the command that
//!   generated the response. This member is absent when no tag was
//!   included with the command.
//!
//!   Note that the client side lib ROXEN.AFS currently assumes that
//!   the tag is used for a single response only. If the need for
//!   actions with multiple responses arise (apart from the
//!   subscription stuff) then a system with some sort of continuation
//!   marks needs to be added, so that ROXEN.AFS can know whether to
//!   expect more responses with the same tag or not.
//!
//! @member string "sid"
//!   Session id for which this response is valid.
//! @endmapping
//!
//! @param tag
//!   The client-submitted tag associated to the request (see above).
//!
//! @returns
//!    If the response is scheduled for later sending (barring any future
//!    throttling), the return value is 1. A message that was rejected from
//!    sending, e.g. as being considered stale or duplicate, returns 0.
int(0..1) push_response(AFS.Types.ClientMessage msg_type, mapping resp,
			void|string tag, void|SubscriptionID subscription_id)
{
  return push_response_low(msg_type, resp, tag, subscription_id);
}


//! Same as @[push_response] but throttles sending so that similar messages
//! aren't delivered too rapidly.
int(0..1) push_throttled_response(AFS.Types.ClientMessage msg_type,
				  mapping resp, void|string tag,
				  void|SubscriptionID subscription_id)
{
  //  This return value should always be 0 as throttled responses are never
  //  delivered instantly.
  return
    push_response_low(msg_type, resp, tag, subscription_id, 1);
}


void push_error(string action,
		string error_code,
		string display_message,
		mapping(string:mixed) args,
		void|string tag)
//! Create an error response and push it to the client response queue.
//! An error response consists of an error_code field describing the
//! error condition as a string identifier. This can be used to handle
//! errors on the client side.
//!
//! A message field contains the (default) display string which can be
//! displayed to the user to explain the error condition. Before
//! displaying the string, the client should substitute any "{xxx}"
//! tokens in the error message with the args["xxx"] value. Note that
//! the indices in the args mapping does not contain "{" and "}" in
//! the message itself. Nor can the client expect the values in the
//! args mapping to be strings. Clients are advised to create a new
//! mapping with "{" / "}"-wrapped indices and string values before
//! replacing them into the display string.
//!
//! In the future, the client can also expect a message_id field,
//! which will give a specifig string identifier for the error. This
//! can be used with localized lookup tables to create localized
//! strings on the client.
{
  ASSERT_IF_DEBUG(stringp(action));
  ASSERT_IF_DEBUG(stringp(error_code));
  ASSERT_IF_DEBUG(stringp(display_message));
  ASSERT_IF_DEBUG(mappingp(args));

  mapping err = ([
    "action"     : action,
    "error_code" : error_code,
    "message"    : display_message,
    "args"       : args,
  ]);

  push_response(AFS.ClientMessages.error, err, tag);
}


this_program reset_session(int(0..1) dont_inform_client)
//! Sends a @[AFS.ClientMessages.reset_session] message to the client
//! and clears all subscriptions and outgoing message queue.
{
  // First we clear any pending messages, since they are now invalid.
  get_responses();
  foreach (subscriptions; SubscriptionID sid;)
    cancel_subscription (sid);
  if (!dont_inform_client) {
    push_response(AFS.ClientMessages.reset_session, ([]));
  }
  return this;
}


//! Tear down the session and remove it from the list of sessions.
//! The GC will clean it later.
//!
//! @note
//!   @[lfun::destroy()]-safe.
void destroy_session()
{
  DWERROR("Cleaning up after session %O.\n", this);
  
  // Cannot destruct here for two reasons: send_data registers a
  // callback to send the response, and we aren't sure we'll never get
  // called while the session still is in use by another thread.
  //
  // Also, we need to make sure it's really us before doing m_delete
  // to avoid deleting another, legitimate, session with the same
  // session_hash (session_hash is provided by the client, and new
  // ClientSessions are set up by REP.get_client_session()).
  if (mapping(string:AFS.ClientSession) client_sessions =
      my_parent_obj && my_parent_obj->client_sessions) {
    // Relying on the interpreter lock here.
    if (client_sessions[client_session_key] == this)
      m_delete (client_sessions, client_session_key);
  }

  foreach (subscriptions; SubscriptionID sid;)
    cancel_subscription (sid);

  // Clean up callouts and send any remaining data.
  if (notification_ttl_callback) {
    remove_call_out(notification_ttl_callback);
    notification_ttl_callback = 0;
  }

  if (session_killer) {
    remove_call_out(session_killer);
    session_killer = 0;
  }

  if (send_callout) {
    remove_call_out(send_callout);
    send_callout = 0;
  }

  if (notification_id)
    send_data (1);
}

//! Returns any pending response mappings and clears the response
//! buffer.
//!
//! @param client_poll_tag
//!   If the caller collects commands to send when a long-standing poll
//!   terminates the tag of the poll request should be given here.
//!
//! @returns
//!   An array of responses to commands (and/or notifications from the
//!   server). Any mapping in the array will be a response mapping as
//!   described in @[push_response()]. If @[client_poll_tag] was provided
//!   the response will also include an entry with an empty response
//!   mapping associated to the poll request tag (unless one exists already).
//!
//! @note
//!   @[lfun::destroy()]-safe.
array(mapping) get_responses(void|string client_poll_tag)
{
  array(mapping) ret = command_responses;
  // Relying on the interpreter lock here.
  command_responses = ({});

  //  Include a response to a pending poll
  if (client_poll_tag) {
    if (mapping poll_res =
	prepare_response(AFS.ClientMessages.poll, ([ ]), client_poll_tag))
      ret += ({ poll_res });
  }

  //  Throttle any entries that need to be delayed until a given time
  array(mapping) delayed = ({ });
  int now = time();
  for (int i = sizeof(ret) - 1; i >= 0; i--) {
    string hash = ret[i]->_hash;
    if (hash && ret[i]->_throttled) {
      //  If same hash has been seen too recently we compute earliest next
      //  delivery and leave the message in the queue.
      if (int last_ts = sent_responses[hash]) {
	if (last_ts + THROTTLE_WINDOW > now) {
	  ret[i]->_throttled = last_ts + THROTTLE_WINDOW;
	  delayed += ({ ret[i] });
	  ret = ret[..(i - 1)] + ret[(i + 1)..];
	  continue;
	}
      }
      
      //  Item will be sent now so record the timestamp
      sent_responses[hash] = now;
    }
  }
  command_responses += delayed;

  //  Clear any _hash value that the client doesn't need to see. If an entry
  //  has a zero _hash it's a dead record that was merged into a newer
  //  response and should be removed.
  //
  //  We also make another effort at removing duplicate hashes that would
  //  have been queued up in parallel, preserving the latest entry if
  //  possible.
  mapping(string:int) dup_hash = ([ ]);
  for (int i = sizeof(ret) - 1; i >= 0; i--) {
    string item_hash;
    if (!(item_hash = m_delete(ret[i], "_hash")) || dup_hash[item_hash]++) {
      ret = ret[..(i - 1)] + ret[(i + 1)..];
    }
  }
  
  DWERROR("Polling %d response(s) from %O\n", sizeof(ret), this);
  return ret;
}


//! Callback for the session watchdog timer.
protected void session_killer_cb()
{
  destroy_session();
}


protected mixed session_killer;

//! Resets the session timer watchdog to the TTL value. This method
//! may be called whenever it's known that the session won't be
//! touched for a prolonged period of time to prevent it from being
//! killed. Upon every call, the TTL will be reset.
void reset_session_timer()
{
  if (session_killer)
    remove_call_out(session_killer);

  session_killer = roxen.background_run(session_ttl, session_killer_cb);
  int now = time();
  last_activity = now;

  //  Also a good time to clear any obsolete throttle hashes
  int expired_ts = now - THROTTLE_WINDOW;
  foreach (sent_responses; string hash; int ts) {
    if (ts < expired_ts)
      m_delete(sent_responses, hash);
  }
}

//! Key in my_parent_obj's table of client sessions
string client_session_key;

//! Session id as requested by the client
string session_id;

protected void create(RequestID id, object _parent_obj,
		      string _client_session_key)
{
  my_parent_obj = _parent_obj;
  client_session_key = _client_session_key;
  session_id = id->variables["session_id"];
  ASSERT_IF_DEBUG(session_id);

  session_ttl = (float)(id->variables["session_ttl"] || DEFAULT_SESSION_TTL);

  reset_session_timer();
}

protected void destroy()
{
  DWERROR("Destroying client session %O\n", this);

  // Do the teardown work.
  destroy_session();

  my_parent_obj = 0;
}

//! @ignore
DECLARE_OBJ_COUNT;
//! @endignore

protected string _sprintf(int t)
{
  return sprintf("ClientSession(%q, %d, %d%s)" + OBJ_COUNT,
		 (session_id || "<no id>"),
		 sizeof(command_responses),
		 (int)session_ttl + time() - last_activity,
		 (notification_id?", NOTIFY":""));
}

//////////////////////////////////////////////////////////////////////
//
// Notification handling below
//

protected void reqid_send_result (RequestID id, mapping res)
{
#if constant(System.CPU_TIME_IS_THREAD_LOCAL)
  // Reset handler CPU time now that we're in the sending thread
  // (backend) to avoid bogus timing -- [Bug 7129].
  id->handle_vtime = gethrvtime();
#endif
  id->send_result (res);
}

protected void send_data(void|int force)
//! Send pending messages to a waiting notification request.
//! Depending on @[force] empty responses are ignored. This is useful
//! in case there is a race between the notification thread and
//! another thread, handling a command from the same client. The delay
//! between pushing responses and calling this call back could mean
//! that the command response already returned the data so we can just
//! ignore the callback and do nothing. In the case where the TTL for
//! the notification request has been reached, the @[force] argument
//! should be !0, which causes an empty array to be sent to the
//! client.
//!
//! @note
//!   @[lfun::destroy()]-safe.
{
  if (notification_id) {
    //  Temporarily clear notification_id prior to emptying the command queue
    //  so that we don't risk any races if new push commands are generated
    //  during this handling.
    RequestID prev_notification_id = notification_id;
    notification_id = 0;
    array(mapping) commands = get_responses(notification_poll_tag);

    if (sizeof(commands) || force) {
      // Reset handle_time, since we've just been waiting up until
      // here -- [Bug 7129].
      prev_notification_id->handle_time = gethrtime();
      
      mapping res = Roxen.http_low_answer(200, Standards.JSON.encode(commands));
      prev_notification_id->set_output_charset("utf-8");
      res->type = "application/json";

      // send_result must be called in the backend thread to avoid
      // races, since the connection is in callback mode. It's in
      // callback mode because of the close callback
      // notify_conn_closed.
      call_out (reqid_send_result, 0, prev_notification_id, res);

      // We probably have a TTL callback for the poll that we no longer
      // need, so let's remove that.
      if (notification_ttl_callback) {
	remove_call_out(notification_ttl_callback);
	notification_ttl_callback = 0;
      }
    } else {
      //  Bring back old notification ID if a new one hasn't been set
      if (!notification_id)
	notification_id = prev_notification_id;
    }
  }

  send_callout = 0;
}

protected void notify_conn_closed(mixed opaque)
//! Callback for when the connection is closed. This removes the
//! connection data from the client session.
{
  // Note: Might consider calling send_data(1) here instead, since
  // this callback gets called when the read end is closed - we might
  // still send the response to the client.

  if (notification_ttl_callback)
    remove_call_out(notification_ttl_callback);
  if (send_callout)
    remove_call_out(send_callout);

  notification_ttl_callback = 0;
  notification_id = 0;
  send_callout = 0;
}

protected void notification_timeout()
//! Called when a notification request TTL has been reached.
{
  // Remove pending send call outs. We will flush existing data
  // anyway.
  if (send_callout)
    remove_call_out(send_callout);

  if (notification_id) {
    // Flush existing data, forcing at least an empty array to be
    // sent.
    send_data(1);
  }

  notification_ttl_callback = 0;
  notification_id = 0;
}

mapping set_notification_id(RequestID id, string client_poll_tag, void|int ttl)
//! Set the @[id] as the current notification channel. The client can
//! expect async messages to arrive over the connection at some point.
//! After a response has been received, the client must refresh the
//! notification channel.
//!
//! @param client_poll_tag
//!   Associates a client tag to the poll request that initiated this
//!   notification channel. A corresponding poll response will be included
//!   when the pending notification is completed.
//!
//! @note
//! A client may only have at the most one notification channel at the
//! time for any given session.
//!
//! @fixme
//! How should we handle the second connection?
{
  if (notification_id) {
    // Close the old connection. If there's queued data it'll get sent
    // on the new one instead.
    if (Stdio.File fd = notification_id->my_fd)
      fd->close();
    notify_conn_closed (0);
  }
 
  // If there are pending, non-throttled, messages or if the ttl is zero,
  // just send a response right away including any present poll tag.
  int now = time();
  int earliest_send = Int.NATIVE_MAX;
  int got_immediate_responses = !ttl;
  if (!got_immediate_responses) {
    foreach (command_responses, mapping ret) {
      earliest_send = min(earliest_send, ret->_throttled);
      if (earliest_send <= now) {
	got_immediate_responses = 1;
	break;
      }
    }
  }
  if (got_immediate_responses) {
    string json = Standards.JSON.encode(get_responses(client_poll_tag));
    mapping res = Roxen.http_low_answer(200, json);
    id->set_output_charset("utf-8");
    res->type = "application/json";
    return res;
  }

  notification_id = id;
  notification_poll_tag = client_poll_tag;
  notification_ttl_callback = roxen.background_run(ttl, notification_timeout);

  //  If queued items are waiting in a notification channel we will need a
  //  wake-up call.
 reschedule_callout:
  if ((earliest_send < Int.NATIVE_MAX) && notification_id) {
    //  May need to replan already scheduled call-out
    int delay = earliest_send - now;
    if (send_callout) {
      if (find_call_out(send_callout) <= delay) {
	//  Scheduled call comes first so leave it untouched
	break reschedule_callout;
      }
      
      //  We remove existing entry and replan it to the earlier time
      remove_call_out(send_callout);
    }
    send_callout = call_out(roxen.handle, delay, send_data);
  }

  // This must be last since the backend might call notify_conn_closed
  // at any time after this call, possibly even before this function returns.
  id->my_fd->set_nonblocking(0,0,notify_conn_closed);

  return Roxen.http_pipe_in_progress();
}

void add_subscription(SubscriptionID sid, AFS.Types.ClientMessage cmt,
		      function (AFS.Types.ClientMessage,string,
				AFS.ClientSession, mapping(string:mixed),
				mixed...:void)/*AFS.Action.push*/ callback,
		      mapping(string:mixed) args)
//! Add a subscription.
//!
//! @param sid
//!   The subscription id string (which is defined by the client) for
//!   this subscription.
//!
//! @param cmt
//!   The @[AFS.Types.ClientMessage] for the subscription.
//!
//! @param subscription
//!   The @[AFS.ClientSession.Subscription] to add.
{
  ASSERT_IF_DEBUG(!subscriptions[sid]);

  DWERROR ("Setting up subscription %s for session %O.\n", sid, this);

  Subscription subscription =
    Subscription (cmt, callback, sid, this, args);

  subscriptions[sid] = subscription;
  subscribed_to[cmt] = 1;
  if (my_parent_obj) {
    if (!my_parent_obj->client_subscriptions[cmt])
      my_parent_obj->client_subscriptions[cmt] = (< >);
    my_parent_obj->client_subscriptions[cmt][subscription] = 1;
  }
}

void cancel_subscription(string sid)
//! Cancel a subscription and make sure the session is no longer
//! notified about changes.
//!
//! @param sid
//!   The subscription id string (which is defined by the client) that
//!   is to be removed.
//!
//! @note
//!   @[lfun::destroy()]-safe.
{
  if (Subscription sub = m_delete (subscriptions, sid)) {
    DWERROR ("Canceling subscription %s for session %O.\n", sid, this);
    subscribed_to[sub->cmt] = 0;
    if (my_parent_obj) {
      my_parent_obj->client_subscriptions[sub->cmt][sub] = 0;
      if (!sizeof(my_parent_obj->client_subscriptions[sub->cmt]))
	my_parent_obj->client_subscriptions[sub->cmt] = 0;
    }
  }
}

AFS.ClientSession.Subscription get_subscription(string sid)
//! Returns the subscription specified by the subscription id @[sid].
{
  return subscriptions[sid];
}

int(0..1) is_subscribed_to(AFS.Types.ClientMessage cmt)
//! Returns 1 if this client session is subscribing to the @[cmt].
{
  return !zero_type (subscribed_to[cmt]);
}

//! ID for a subscription, specified by the client when a subscription
//! is set up.
typedef string SubscriptionID;

//! A subscription.
class Subscription
(
 //! The ClientMessage type this subscription represents.
 string /*AFS.Types.ClientMessage*/ cmt,

 //! The action callback to call when pushing data (ie @[AFS.Action.push])
 function (string/*AFS.Types.ClientMessage*/,string,AFS.ClientSession,
	   mapping(string:mixed),mixed...:void) cb,

 //! The subscription id for this subscription.
 SubscriptionID subscription_id,

 //! The clientsession this subscription belongs to.
 AFS.ClientSession cs,

 //! The args that were provided by the client when setting up this
 //! subscription.
 mapping(string:mixed) args
)
{
  void push (mixed ... push_args)
  {
    roxen.handle(cb, cmt, subscription_id, cs, args, @push_args);
  }
}
