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
//!  @param resp
//!        The response to a command. A command response mapping has
//!        the following predefined fields:
//!
void push_response(AFS.Types.ClientMessage msg_type, mapping resp,
		   void|string tag) {
  ASSERT_IF_DEBUG(mappingp(resp));

  resp->msg_type = msg_type;

  if (tag)
    resp["tag"] = tag;

  resp["sid"] = session_id;

  command_responses += ({ resp });
  response_counter++;
  DWERROR("Added response to %O\n", this);

  if (notification_id && !send_callout) {
    send_callout = roxen.background_run(NOTIFY_DELAY, send_data);
  }
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


this_program reset_session()
//! Sends a @[AFS.ClientMessages.reset_session] message to the client
//! and clears all subscriptions and outgoing message queue.
{
  // First we clear any pending messages, since they are now invalid.
  get_responses();
  foreach (subscriptions; SubscriptionID sid;)
    cancel_subscription (sid);
  push_response(AFS.ClientMessages.reset_session, ([]));
  return this;
}


//! Returns any pending response mappings and clears the response
//! buffer.
//!
//! @returns
//!   An array of responses to commands (and/or notifications from the
//!   server). Any mapping in the array will be a response mapping as
//!   described in @[push_response()].
array(mapping) get_responses() {
  array(mapping) ret = command_responses;
  // Relying on the interpreter lock here.
  command_responses = ({});
  DWERROR("Polling %d response(s) from %O\n", sizeof(ret), this);
  return ret;
}

//! Callback when a for the session watchdog timer.
protected void session_killer_cb() {
  DWERROR("Session %O timed out.\n", this);
  if (notification_id)
    send_data (1);
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
  last_activity = time();
}

//! Session id as requested by the client
string session_id;

protected void create(RequestID id) {
  session_id = id->variables["session_id"];
  ASSERT_IF_DEBUG(session_id);

  session_ttl = (float)(id->variables["session_ttl"] || DEFAULT_SESSION_TTL);

  reset_session_timer();
}

protected void destroy()
{
  DWERROR("Destroying client session %O\n", this);

  foreach (subscriptions; SubscriptionID sid;)
    cancel_subscription (sid);

  if (session_killer)
    remove_call_out(session_killer);
  if (send_callout) {
    DWERROR("Destroying client session with a pending send!\n");
    remove_call_out(send_callout);
  }
  if (notification_ttl_callback)
    remove_call_out(notification_ttl_callback);
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
  if (notification_id && objectp(notification_id)) {
    array(mapping) res = get_responses();

    if (sizeof(res) || force) {
      mapping res = Roxen.http_low_answer(200, Standards.JSON.encode(res));
      notification_id->set_output_charset("utf-8");
      res->type = "application/json";

      // send_result must be called in the backend thread to avoid
      // races, since the connection is in callback mode. It's in
      // callback mode because of the close callback
      // notify_conn_closed.
      call_out (notification_id->send_result, 0, res);
      notification_id = 0;

      // We probably have a TTL callback for the poll that we no longer
      // need, so let's remove that.
      if (notification_ttl_callback) {
	remove_call_out(notification_ttl_callback);
	notification_ttl_callback = 0;
      }
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

mapping set_notification_id(RequestID id, void|int ttl)
//! Set the @[id] as the notification the current notification
//! channel.  The client can expect async messages to arrive over the
//! connection at some point. After a response has been received, the
//! client must refresh the notification channel.
//!
//! @note
//! A client may only have at the most one notification channel at the
//! time for any given session.
//!
//! @fixme
//! How should we handle the second connection?
{
  ASSERT_IF_DEBUG(!notification_id);

  // If there are pending messages or if the ttl is zero, just send
  // a response right away.
  if (sizeof(command_responses) || !ttl) {
    mapping res =
      Roxen.http_low_answer(200, Standards.JSON.encode(get_responses()));
    id->set_output_charset("utf-8");
    res->type = "application/json";
    return res;
  }

  id->my_fd->set_nonblocking(0,0,notify_conn_closed);

  notification_id = id;
  notification_ttl_callback = roxen.background_run(ttl, notification_timeout);
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
