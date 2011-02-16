// $Id: Action.pike,v 1.1 2011/02/16 12:45:48 grubba Exp $

//
// AFS.Action interface
//
// (C) 2011 Roxen Internet Software AB
//
//

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

//! An object of this class is instantiated per @[AFS.Filesystem] instance.

//! Indicate that this class (and any subclass) is an AFS.Action
constant filesystem_action = 1;

//! This is to be overridden by subclasses with a displaystring for the action name.
constant display_name = 0;

//! The action name, as called by the client.
constant name = 0;

//! Array of subscribable AFS.ClientMessages for this action. 0
//! if subscriptions aren't supported.
constant subscribable_types = 0;

mapping(string:RXML.Type) req_arg_types = ([]);
mapping(string:RXML.Type) opt_arg_types = ([]);

constant def_arg_type = RXML.t_string;

mapping(string:mixed) eval_args (mapping(string:mixed) vars,
				 void|Roxen.OnError on_error,
				 void|array(string) ignore_args)
//! Parses and evaluates the tag arguments according to
//! @[req_arg_types] and @[opt_arg_types]. The @[vars] mapping
//! contains the unparsed arguments on entry. Arguments not mentioned
//! in @[req_arg_types] or @[opt_arg_types] are evaluated with the
//! default argument type, unless listed in
//! @[ignore_args]. @[on_error] determines how errors are handled.
//!
//! @note
//!  This code is stolen from the RXML parser and modified to be allow
//!  reuse here.
//!
//! @returns
//!   A mapping of parsed arguments.
{
  mapping(string:mixed) args = ([]);

  mapping(string:RXML.Type) atypes = vars & req_arg_types;
  if (sizeof (atypes) < sizeof (req_arg_types)) {
    array(string) missing = sort (indices (req_arg_types - atypes));
    string err_msg = sprintf("Required " +
			     (sizeof (missing) > 1 ?
			      "arguments " + String.implode_nicely (missing) + " are" :
			      "argument " + missing[0] + " is") + " missing.\n");
#ifdef DEBUG_FS_ACTIONS
    werror(err_msg);
#endif

    return Roxen.raise_err (on_error, err_msg);
  }

  atypes += vars & opt_arg_types;
  if (ignore_args)
    foreach (indices (vars) - ignore_args, string arg) {
      if (sizeof(vars[arg]) != 1)
	return Roxen.raise_err(on_error, "Multiple %O arguments found!", arg);

      mixed err = catch {
	  args[arg] = (atypes[arg] ||
		       def_arg_type)->encode (vars[arg][0]);
	};
      if (objectp(err) && err->is_RXML_Backtrace) {
	return Roxen.raise_err(on_error,
			     "Failed to parse argument %O", arg);
      }
    }
  else
    foreach (vars; string arg; mixed val) {
      if (sizeof(val) != 1)
	return Roxen.raise_err(on_error, "Multiple %O arguments found!", arg);
      mixed err = catch {
	  args[arg] = (atypes[arg] ||
		       def_arg_type)->encode (val[0]);
	};
      if (objectp(err) && err->is_RXML_Backtrace) {
	return Roxen.raise_err(on_error,
			     "Failed to parse argument %O", arg);
      }
    }
  return args;
}


//! Called when the system wants to create an instance of this action.
//! Use this method to initialize the internal data needed for this action
//! rather than performing all initialization in create().
//! @returns 
//!   Non-zero if an error occured.
//! @note
//!   This callback is not yet in use!
int(0..1) register() {
  return 0;
}

//! Main authentication callback when executing actions.
//!
//! This function is called with the same arguments as @[exec()],
//! but slightly earlier.
//!
//! The callback can assume that the request has at least read
//! permission on the global print_db_ppoint_handle.
//!
//! @param id
//!   The request id of the request that wants to execute the action.
//! @param cs
//!   The @[AFS.ClientSession] object associated with the request.
//! @param args
//!   Request arguments as returned by @[eval_args()].
//! @param tag
//!   Optional tag requested by the client. If this parameter is !0,
//!   it must be included in the "_.tag" parameter in the response,
//!   unless a HTTP response mapping is returned.
//!
//! @returns
//!   Returns @expr{1@} if the request should be allowed, and
//!   @[exec()] be called. Returns @expr{0@} (zero) if the
//!   request should be disallowed.
//!
//! The default implementation returns @expr{1@}.
//!
//! @note
//!   This function may perform permission-related filtering
//!   of @[args]. This is typically used when the user has some
//!   permissions to REP, but not sufficient to parts of the set.
//!
//! @seealso
//!   @[exec()]
int(0..1) access_perm(RequestID id,
		      AFS.ClientSession cs,
		      mapping(string:mixed) args,
		      void|string tag)
{
  return 1;
}

//! Main callback when executing actions. This method is the one
//! actions wants to override to handle execution.
//!
//! At the point where this method is called, only basic permission
//! checking has been done. The action is expected to perform it's own
//! authentication checks if needed.
//!
//! @param id
//!   The request id of the request that wants to execute the action.
//! @param cs
//!   The @[AFS.ClientSession] object associated with the request.
//! @param args
//!   Request arguments as returned by @[eval_args()].
//! @param tag
//!   Optional tag requested by the client. If this parameter is @expr{!0@},
//!   it must be included in the @expr{"_.tag"@} parameter in the response,
//!   unless a HTTP response mapping is returned.
//! @returns
//!   This method is expected to return @expr{0@} if the method is able to
//!   execute. For permission like problems (high level ones) an HTTP
//!   response mapping indicating permission error may be returned,
//!   which will then be sent back to the client as a HTTP error. For
//!   other errors, it is required that the command handles the error
//!   and appends an application level error response to the
//!   @[ClientSession] response queue.
int(0..0)|mapping exec(RequestID id,
		       AFS.ClientSession cs,
		       mapping(string:mixed) args,
		       void|string tag) {
  return Roxen.http_low_answer(501, "Operation not implemented");
}


//! Callback called by the internal client notification system, to
//! push data to a subscribing client. You need to specify the
//! AFS.ClientMessages types that your action supports pushing
//! in @[subscribable_types].
//!
//! @param cmt
//!   The client message type to push. This will be one of the types
//!   that you've specified in @[subscribable_types]. If you have
//!   specified that your push action can handle multiple message
//!   types, you obviously need to check the type before deciding what
//!   to send to clients.
//!
//! @param subscription_id
//!   The subscription ID for this subscription.
//!
//! @param cs
//!   The client session.
//!
//! @param args
//!   The args that the client sent when setting up the
//!   subscription. These will be equal to the args sent to @[exec]
//!   when the subscription was set up.
//!
//! @param push_args
//!   Message type specific arguments. Typically equal to the
//!   arguments sent to @[AFS.Filesystem()->broadcast_client_message()@].
//!
//! @note
//!   The client session is destructed asynchronously when it times out.
void push (AFS.Types.ClientMessage cmt,
	   AFS.ClientSession.SubscriptionID subscription_id,
	   AFS.ClientSession cs,
	   mapping(string:mixed) args,
	   mixed ... push_args)
{
  error ("Broadcast not implemented.\n");
}

enum ActionStatus {
  ACTION_OK = 0,
  ACTION_ERROR,
};

//! @ignore
DECLARE_OBJ_COUNT;
//! @endignore

protected string _sprintf (int flag)
{
  return flag == 'O' && sprintf ("AFS.Action(%s)" + OBJ_COUNT, name);
}

//! Not yet in use. Intended to be a result wrapper until the response
//! is sent to the client. May not be needed after all...
class ActionResult(void|string tag) {
  ActionStatus status = ACTION_OK;

  int error_id;
  string error;

  string|int|float|array|mapping data;
}
