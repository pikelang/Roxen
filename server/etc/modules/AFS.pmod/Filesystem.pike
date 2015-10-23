//! Common code for implementing Action Filesystems.

#include <module.h>

#ifdef AFS_DEBUG
#define AFS_DEBUG_MSG(msg...) report_debug (msg)
#else
#define AFS_DEBUG_MSG(msg...) 0
#endif

// inherit "module";

//////////////////////////////////////////////////////////////////////////////
//
// ActionFS stuff
//

// Client session management

mapping(string:AFS.ClientSession) client_sessions = ([]);
//! Mapping from session id to a ClientSession object. Use
//! @expr{@[REP.get_session()]->cs@} to get the session for the
//! current request.

mapping|int(0..0)|AFS.ClientSession
  get_client_session(RequestID id, void|Roxen.OnError on_error)
//! Attempts to get an existing session or create a new one if
//! needed. The client must provide a session id in the HTTP
//! variable session-id.
//!
//! @note
//! May return @expr{0@} or throw an error (depending on the @[on_error]
//! parameter) if no session ID was given in the session-id
//! variable.
//!
//! @param on_error
//!        A @[Roxen.OnError] value that describes how the function
//!        should handle errors.
//!
//! @returns
//!        A ClientSession object if successful, or an HTTP response
//!        mapping if the session couldn't be found/used. In the case
//!        of error the @[on_error] value will determine how the
//!        function returns.
{
  string sid = id->variables["session_id"];

  if (!sid)
    return Roxen.raise_err(on_error, "No session id given!\n");

  string session_hash = sprintf("%q", sid);	// FIXME!
  AFS.ClientSession cs = client_sessions[session_hash];

  if (!cs) {
    // We need to create a new session
    if (mixed err = catch {
	cs = AFS.ClientSession(id)->reset_session();
      }) {
#ifdef DEBUG_CLIENT_SESSION_CREATION
      werror("Unable to create session:\n%s\n",
	     describe_backtrace(err));
#endif /* DEBUG_CLIENT_SESSION_CREATION */
      return Roxen.http_low_answer(401, "Unauthorized");
    }

    // Check the session table again in case of race.
    // vvv Relying on the interpreter lock from here.
    if (AFS.ClientSession cs2 = client_sessions[session_hash])
      cs = cs2;
    else
      client_sessions[session_hash] = cs;
    // ^^^ Relying on the interpreter lock to here.

    return cs;

  }

  cs->reset_session_timer();
  return cs;
}

mapping(AFS.Types.ClientMessage:multiset(AFS.ClientSession.Subscription))
client_subscriptions = ([]);

//! Register all @expr{"filesystem-actions"@} provider modules.
//! Typically called from @[start()].
protected void init_action_modules(Configuration conf)
{
  fs_actions = ([]);

  // Scan configuration for AFS.Actions
  foreach (conf->get_providers("filesystem-actions"), RoxenModule fsam) {
    get_fs_actions(fsam);
  }

  get_fs_actions(this);
}

// See the corresponding defvar:s.
int client_poll_timeout;
int client_poll_interval;

class PollAction
//! This class implements a simple polling command that will return
//! any pending command responses for the given session.  The command
//! will not do anything by it self at this time except return so that
//! the standard handler can return pending responses.  The client may
//! pass a @[timeout] query variable to set how long the server will
//! allow the client to wait for a new message. If there are pending
//! messages, the poll action will always return straight away with
//! those messages, but if the queue is empty, it will wait the
//! specified number of seconds before simply returning an empty
//! response.
{
  inherit AFS.Action;
  constant display_name = "Standard Poll action";
  constant name = "poll";

  mapping(string:RXML.Type) opt_arg_types = ([
    "timeout"  : RXML.t_int,
    "interval" : RXML.t_int,
  ]);

  int(0..0)|mapping exec(RequestID id,
			 void|AFS.ClientSession cs,
			 mapping(string:mixed) args,
			 void|string tag)
  {
    ASSERT_IF_DEBUG(cs);

    if (int timeout = args["timeout"]) {
      if (timeout == -1) {
	// Auto mode.
	if (!zero_type (args->interval) &&
	    (args->interval != client_poll_interval))
	  cs->push_response (AFS.ClientMessages.poll,
			     ([ "poll_interval" : client_poll_interval ]),
			     tag);

	return cs->set_notification_id(id, client_poll_timeout);
      } else {
	return cs->set_notification_id(id, timeout);
      }
    }

    return 0;
  }
}

//! A mapping of all known fs_actions that clients may use.
protected mapping(string:AFS.Action) fs_actions = ([
]);

//! Utility method that scans the given @[RoxenModule] for
//! @[AFS.Action] classes. Whenever it finds a class that inherits
//! the @[AFS.Action] class, it will create an instance of that
//! class and enter it into the @[fs_actions] mapping. This will allow
//! the action to be executed by clients.
//!
//! @param module
//!  The @[RoxenModule] to scan for actions.
//!
void get_fs_actions(RoxenModule module)
{
#ifdef DEBUG_FS_ACTIONS
  werror("Looking for AFS.Actions in %O\n", module);
#endif /* DEBUG_FS_ACTIONS */
  foreach(sort(indices(module)), string i) {
#ifdef DEBUG_FS_ACTIONS
    werror(" %s %d %d\n", i,
	   programp(module[i]),
	   programp(module[i]) && module[i]->filesystem_action);
#endif /* DEBUG_FS_ACTIONS */
    if (programp(module[i]) && module[i]->filesystem_action) {
      AFS.Action fsa = module[i]();
#ifdef DEBUG_FS_ACTIONS
      werror(" - Found action %O\n", fsa->name);
#endif /* DEBUG_FS_ACTIONS */
      fs_actions[fsa->name] = fsa;
    }
  }
}

//! Call an AFS action.
//!
//! Implements the main dispatcher for calling the actual actions.
//! This function is called from @[find_file()] with the subpath
//! within the actions URL namespace and it looks up the corresponding
//! @[AFS.Action] object which should handle it, sets up various
//! contexts and calls it.
//!
//! This function has two operating modes; either via @[find_file()],
//! in which case @[id] will be set, or via simulated calls, in which
//! case @[id] typically will be zero.
//!
//! @param path
//!   Path (relative to "/actions/") of the action to call.
//!
//! @param id
//!   @[RequestID] for the call. May be zero, in which
//!   case @[variables] must be set.
//!
//! @param cs
//!   @[AFS.ClientSession] for the call. Required when @[id]
//!   is zero. For convenience this parameter may be a mapping
//!   which will be returned straight away.
//!
//! @param variables
//!   Overriding set of request variables. Required when @[id]
//!   is zero.
//!
//! @returns
//!   If no session ID is given, the method will return an HTTP response
//!   mapping with a 400 result.
//!
//!   If the requested session ID is invalid for this session, ie used
//!   by some other session, a HTTP response mapping with a 401 response
//!   is returned.
//!
//!   If the requested action is unknown, a response mapping with 404 is
//!   returned.
//!
//!   When executing, actions may signal access problem by returning an
//!   HTTP response mapping with appropriate HTTP response codes.
//!
//!   Failures such as non-existing items, DB errors etc should not
//!   generate HTTP error responses but rather generate an application
//!   level error message that is returned to the client.
//!
//!   Application-level data is returned as an array of JSON
//!   response mappings.
//!
//! @seealso
//!   @[find_file()]
mapping|array(mapping) call_fs_action(string path, RequestID id,
				      AFS.ClientSession|mapping|void cs,
				      mapping(string:array)|void variables)
{
  // We do require a proper session. Without it, we can't enqueue the
  // response or return data already queued for the client.
  if (!cs) {
    cs = get_client_session(id, Roxen.RETURN_ZERO);
  }

  if (!cs || mappingp(cs)) {
    AFS_DEBUG_MSG ("AFS call %O: No session id\n",
		   fs_actions[path] && fs_actions[path]->name);
    return cs || Roxen.http_low_answer(400, "Please provide a session id!");
  }

  // Now we have an authenticated client with a proper session. Let's
  // look up the action and call the exec() method to run it.
  AFS.Action fsa = fs_actions[path];

  if (!fsa) {
    AFS_DEBUG_MSG ("AFS: Call to unknown action %O\n", path);
    return Roxen.http_low_answer(404, "Unknown action.");
  }

  variables = (variables || id->real_variables) + ([]);

  string subscription_id;
  if (array v = m_delete (variables, "subscribe")) {
    if (sizeof (v) == 1) {
      subscription_id = v[0];
    } else {
      AFS_DEBUG_MSG ("AFS call %O: Multiple subscribe arguments\n", fsa->name);
      return Roxen.http_low_answer (Protocols.HTTP.HTTP_BAD,
				    "Multiple subscribe arguments found.\n");
    }
  }

  string tag;
  if (array t = m_delete (variables, "tag")) {
    tag = t * "\0";
  }

  mapping(string:mixed) args;
  if (mixed err = catch (
	args = fsa->decode_args(variables, Roxen.THROW_RXML))) {
    if (objectp (err) && err->is_RXML_Backtrace) {
      AFS_DEBUG_MSG ("AFS call %O: %sRaw args: %O\n", fsa->name, err->msg,
		     mkmapping (indices (variables),
				column (values (variables), 0)));
      return Roxen.http_low_answer (Protocols.HTTP.HTTP_BAD, err->msg);
    }
    throw (err);
  }

  if (!fsa->access_perm(id, cs, args, tag)) {
    AFS_DEBUG_MSG ("AFS call %O: Permission denied. Args: %O\n",
		   fsa->name, args - (["session_id": 1]));
    return Roxen.http_low_answer(403, "Permission denied.");
  }

  if (subscription_id && cs && cs->get_subscription(subscription_id)) {
    // Client is trying to change a subscription, which isn't supported!
    AFS_DEBUG_MSG ("AFS call %O: Subscription change attempt\n", fsa->name);
    return Roxen.http_low_answer(403,
				 sprintf("Client has already subscribed to "
					 "objects using the key %q and "
					 "modifying existing subscriptions is "
					 "not allowed.",
					 subscription_id));
  }

  if (subscription_id) {
    if (array(AFS.Types.ClientMessage) types = fsa->subscribable_types) {
      foreach (types, AFS.Types.ClientMessage cmt) {
	cs->add_subscription (subscription_id, cmt, fsa->push, args);
      }
    } else {
      AFS_DEBUG_MSG ("AFS call %O: Unsubscribable action\n", fsa->name);
      return Roxen.http_low_answer (Protocols.HTTP.HTTP_BAD,
				    sprintf ("Subscriptions not implemented "
					     "for action %s.", fsa->name));
    }
  }

  AFS_DEBUG_MSG ("AFS call %O: Executing with args: %O\n",
		 fsa->name, args - (["session_id": 1]));
  mapping|array(mapping) res = (fsa->exec(id, cs, args, tag) ||
				cs->get_responses());
#ifdef AFS_DEBUG
  if (mappingp (res))
    AFS_DEBUG_MSG ("AFS call %O: Returned http response: %O\n", fsa->name, res);
  else if (sizeof (res)) {
    AFS_DEBUG_MSG ("AFS call %O: Returned response messages:\n", fsa->name);
    foreach (res; int i; mapping msg) {
      if (msg->msg_type == "error")
	AFS_DEBUG_MSG ("  %d: Error: %O\n", i, msg->message || msg);
      else
	AFS_DEBUG_MSG ("  %d: %O\n", i, msg->msg_type);
    }
  }
  else
    AFS_DEBUG_MSG ("AFS call %O: Returned no response messages.\n", fsa->name);
#endif
  return res;
}

//! Call an @[ActionFS] action via JSON.
//!
//! This function calls @[call_fs_action()], and encodes the
//! JSON result if needed.
//!
//! This function is typically called from @[find_file()].
//!
//! @returns
//!   Returns the same response mappings as @[call_fs_action()],
//!   except for application data, which is returned as a result
//!   mapping containing the data JSON encoded.
//!
//! @seealso
//!   @[find_file()], @[call_fs_action()]
mapping(string:mixed)|int(-1..0)|Stdio.File find_action(string path,
							RequestID id)
{
  NOCACHE(); // Never cache action requests.

  mapping|array(mapping) res;
#if 0
  float action_vtime = gauge
#endif
    {
      res = call_fs_action(path, id);
      if (!mappingp(res)) {
	string json_res =
	  Standards.JSON.encode(res,
#ifdef AFS_HUMAN_READABLE
				Standards.JSON.HUMAN_READABLE|
				Standards.JSON.PIKE_CANONICAL
#endif
			       );
	res = Roxen.http_low_answer(200, json_res);
	id->set_output_charset("utf-8");
	res->type = "application/json";
      }
    };

  return res;
}


array(AFS.ClientSession) get_message_subscribers(AFS.Types.ClientMessage cmt)
//! Get all ClientSessions that are currently subscribing to the
//! specified message type.
//!
//! @param cmt
//!   The @[AFS.Types.ClientMessage] for the subscription.
//!
//! @note
//!   ClientSessions may be destructed asynchronously when they time out.
{
  return (array) (client_subscriptions[cmt] || ({}));
}

void broadcast_client_message(AFS.Types.ClientMessage cmt,
			      mixed ... push_args)
//! Broadcast a message to subscribing clients.
//!
//! @param cmt
//!   The message type to broadcast.
//!
//! @param push_args
//!   Arguments sent to the action push callback (@[AFS.Action.push()]).
{
  if (multiset subscriptions = client_subscriptions[cmt]) {
    foreach (get_iterator (subscriptions);
	     AFS.ClientSession.Subscription sub;) {
      ASSERT_IF_DEBUG (cmt == sub->cmt);
      sub->push (@push_args);
    }
  }
}

