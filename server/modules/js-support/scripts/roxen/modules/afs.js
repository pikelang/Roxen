/*global ROXEN, YAHOO */

/**
 * Module interface to the new Action File System
 *
 * @module afs
 * @class AFS
 * @namespace ROXEN
 * @static
 */
ROXEN.AFS = function () {

  // 1 - Log AFS calls and responses.
  // 2 - Also log calls to tagged callbacks, i.e. the single-response
  //     callbacks passed to call().
  // 3 - Also log calls to global and error callbacks.
  var debug_log = 0;

  var session = ROXEN.config.session;

  /**
   * AFS actions path prefix.
   */
  var actions_prefix = "/actions/";

  /**
   * AFS session variable name in action URLs.
   */
  var session_var = "session_id";
  
  /**
   * How long a poll for new msgs is held by the server.
   * A value of 0 disables blocking polls.
   * A value of -1 means automatic (parameters decided by server).
   * A value of -2 disables polling altogether.
   *
   * @property poll_timeout
   * @type {Int}
   * @private
   */
  var poll_timeout = -1; // Auto mode.

  /**
   * Seconds to wait after the last AFS response before issuing
   * another poll. When the client is idle, this is effectively the
   * interval between polls.
   *
   * @property poll_delay
   * @type {Int}
   * @private
   */
  var poll_delay = 30;

  /**
   * Seconds to wait after a low-level AFS error before issuing
   * another poll.
   *
   * @property poll_error_delay
   * @type {Int}
   * @private
   */
  var poll_error_delay = 30;

  // True as long as the last AFS call was successful.
  var connection_ok = false;

  // Number of ongoing AFS calls.
  var open_connections = 0;

  var poll_delay_timeout_id;

  // Maps the tag for the ongoing calls to the callback function and an
  // optional group identifier when the response comes.
  var tagged_callbacks = {};

  // Track groups of connections so they can aborted.
  var groups = {};

  // Counter to produce unique tags.
  var tag_count = 0;

  // Set of callback functions that will receive all AFS responses.
  var global_callbacks = [];

  // Set of callback functions that get called when there are
  // low-level AFS errors (connection errors or JSON format errors).
  var error_callbacks = [];

  function encode_afs_args (args)
  {
    var query = [];
    var json_args = {}, got_json_args = false;

    // Send strings as ordinary variables. Everything else is sent as
    // json in the special __afs variable. That way it's possible to
    // send variables that are parsed by the server outside the main
    // afs query handler.

    for (var name in args)
      if (args.hasOwnProperty (name)) {
	var val = args[name];
	if (YAHOO.lang.isString (val))
	  // Assume the name only contains ordinary characters. May
	  // escape it later should it be a problem.
	  query.push (name + "=" + ROXEN.escapeURIComponent (val));
	else {
	  json_args[name] = val;
	  got_json_args = true;
	}
      }

    if (got_json_args)
      query.push ("__afs=" + YAHOO.lang.JSON.stringify (json_args));

    return query.join ("&");
  }

  function request_failure (resp)
  {
    ROXEN.log("ROXEN.AFS: connection error: " +
	      resp.status + " " + resp.statusText + "\n");

    for (var i = 0; i < error_callbacks.length; j++) {
      var cb = error_callbacks[i];
      if (debug_log > 2)
	ROXEN.log ("  AFS calling error callback: " + cb.name + "\n");
      cb (resp);
    }

    // Forget all ongoing calls since we cannot hope to receive any
    // useful responses to them anyway after this.
    tagged_callbacks = {};
    groups = {};

    if (open_connections) {
      open_connections = 0;
      restart_poll (true);
    }

    connection_ok = false;
  }

  function json_parse_failure (err)
  {
    ROXEN.log("ROXEN.AFS: JSON parse error: " + err + "\n");

    for (var i = 0; i < error_callbacks.length; j++) {
      var cb = error_callbacks[i];
      if (debug_log > 2)
	ROXEN.log ("  AFS calling error callback: " + cb.name + "\n");
      // FIXME: Need a flag to tell it apart from a connection error?
      cb (err);
    }

    // Forget all ongoing calls since we cannot hope to receive any
    // useful responses to them anyway after this.
    tagged_callbacks = {};
    groups = {};

    if (open_connections) {
      open_connections = 0;
      restart_poll (true);
    }

    connection_ok = false;
  }

  function request_success (resp)
  {
    var msgs;
    try {
      msgs = YAHOO.lang.JSON.parse(resp.responseText);
    }
    catch (err) {
      json_parse_failure (err);
      return;
    }
    msgs._etag = resp.getResponseHeader.Etag || resp.getResponseHeader.ETag;

    for (var i = 0; i < msgs.length; i++) {
      var msg = msgs[i];
      var tag = msg.tag;

      if (tag) {
	if (debug_log)
	  ROXEN.log ("AFS response: " + msg.msg_type + ", tag " + tag + "\n");

        var ent = tagged_callbacks[tag];
	var cb = ent && ent[0];
	if (ent === undefined)
	  ROXEN.log ("ROXEN.AFS: Warning: Got AFS response with " +
		     "unknown tag: " + msg.msg_type + "\n");
        else if (cb == -1) {
          if (debug_log > 1)
	    ROXEN.log ("  AFS tagged callback was canceled");
	  delete tagged_callbacks[tag];
        } else {
	  if (debug_log > 1)
	    ROXEN.log ("  AFS calling tagged callback: " + cb.name + "\n");
	  cb (msg);
	  // Assume no more than one response with a given tag. See
	  // also AFS.ClientSession.push_response.
	  delete tagged_callbacks[tag];
	  var group = ent[1];
          if (group) {
            var g = groups[group];
            g.splice(g.indexOf(tag), 1);
          }
	}
      }

      else {
	if (debug_log)
	  ROXEN.log ("AFS response: " + msg.msg_type + "\n");
      }

      for (var j = 0; j < global_callbacks.length; j++) {
	var cb = global_callbacks[j];
	if (debug_log > 2)
	  ROXEN.log ("  AFS calling global callback: " + cb.name + "\n");
	cb (msg);
      }
    }

    if (open_connections > 0) {
      open_connections--;
      if (!open_connections) restart_poll (false);
    }

    connection_ok = true;
  }

  /**
   * Calls an AFS action.
   *
   * @param {String}   action Requested action name.
   * @param {Object}   args   Action arguments. "session_id" (or whatever
   *                          name the session variable is given) and "tag"
   *                          arguments get added to it.
   * @param {Function} fn     Optional callback function to run when the
   *                          corresponding AFS response comes back.
   *                          It gets a single argument that is the
   *                          response message in JSON. If this isn't
   *                          given then the AFS action is untagged,
   *                          and any response it produces will be
   *                          sent to the global callbacks only.
   * @param {Object}   scope  Scope correction (optional).
   * @param {String}   group  Group identifier (optional).
   * @return {Object}         Returns the connection object.
   */
  function call(action, args, fn, scope, group) {
    return call_or_post(action, "GET", args, 0, fn, scope, group);
  }
  
  function post(action, args, postargs, fn, scope, group) {
    if (!ROXEN.isObject(postargs))
      postargs = { };
    var postdata = [ ];
    var item = 0;
    for (var idx in postargs) {
      postdata[item++] =
	encodeURIComponent(idx) + "=" + encodeURIComponent(postargs[idx]);
    }
    return call_or_post(action, "POST", args, postdata.join("&"), fn, scope);
  }
  
  function call_or_post(action, method, args, postdata, fn, scope, group) {
    if (!ROXEN.isObject(args)) {
      args = {};
    }

    if (scope)
      fn = ROXEN.bind (scope, fn);

    if (fn) {
      var tag = ++tag_count+"";
      if (debug_log)
	ROXEN.log ("AFS call: " + action + " " +
		   YAHOO.lang.JSON.stringify (args) +
		   ", callback " + fn.name + ", tag " + tag + "\n");
      args.tag = tag;
      tagged_callbacks[tag] = [ fn, group ];
    }
    else {
      if (debug_log)
	ROXEN.log ("AFS call: " + action + " " +
		   YAHOO.lang.JSON.stringify (args));
    }

    args[session_var] = session;

    open_connections++;
    var url = actions_prefix + action + "?" + encode_afs_args (args);
    var con = YAHOO.util.Connect.asyncRequest ( method, url,
                                                { cache: false,
                                                  success: request_success,
                                                  failure: request_failure },
                                                postdata);
    if (fn && group) {
      if (!groups[group]) groups[group] = [ ];
      groups[group].push(args.tag);
    }

    return con;
  }

  /**
   * Abort all requests created with specified group.
   *
   * @param {String} group
   *   Group identifier.
   */
  function abort(group_name) {
    var group = groups[group_name];
    if (!group) return;
    for (var i = 0; i < group.length; i++) {
      tagged_callbacks[group[i]][0] = -1;
    }
    delete groups[group_name];
  }
  

  /**
   * Returns the status of the AFS connection, without querying the
   * server.
   *
   * @return {Boolean}
   *   Returns true if the last AFS call returned successfully, false
   *   otherwise.
   */
  function has_connection()
  {
    return connection_ok;
  }

  /**
   * Adds a global callback, i.e. a callback that will be called for
   * every AFS response from the server.
   *
   * @param {Function} fn
   *   Callback function. It will be called with a single argument
   *   that is the AFS response message in JSON.
   * @param {Object} scope
   *   Optional scope correction.
   * @return {Function}
   *   Returns the function actually added, which can be used in a later
   *   call to remove_global_callback.
   */
  function add_global_callback (fn, scope)
  {
    if (scope)
      fn = ROXEN.bind (scope, fn);
    global_callbacks.push (fn);
    return fn;
  }

  /**
   * Removes a callback from the set of global callbacks.
   *
   * @param {Function} fn
   *   Callback to remove. Nothing happens if it doesn't match any
   *   registered callback.
   */
  function remove_global_callback (fn)
  {
    for (var i = 0; i < global_callbacks.length; i++)
      if (global_callbacks[i] === fn) {
	global_callbacks.splice (i, 1);
	break;
      }
  }

  /**
   * Adds a callback that will be called whenever there is a low-level
   * AFS error; either a connection error or a syntax error in a JSON
   * response.
   *
   * @param {Function} fn
   *   Callback function. It will be called with a single argument
   *   which is either a YAHOO.util.Connect.asyncRequest failure
   *   handler response, or an exception object thrown by
   *   YAHOO.lang.JSON.parse.
   * @param {Object} scope
   *   Optional scope correction.
   * @return {Function}
   *   Returns the function actually added, which can be used in a later
   *   call to remove_global_callback.
   */
  function add_error_callback (fn, scope)
  {
    if (scope)
      fn = ROXEN.bind (scope, fn);
    error_callbacks.push (fn);
    return fn;
  }

  /**
   * Removes a callback from the set of callbacks called for low-level
   * AFS errors.
   *
   * @param {Function} fn
   *   Callback to remove. Nothing happens if it doesn't match any
   *   registered callback.
   */
  function remove_error_callback (fn)
  {
    for (var i = 0; i < error_callbacks.length; i++)
      if (error_callbacks[i] === fn) {
	error_callbacks.splice (i, 1);
	break;
      }
  }

  function poll_callback (response)
  {
    if (poll_timeout == -1 && !ROXEN.isUndefined (response.poll_interval))
      poll_delay = response.poll_interval;
  }

  function restart_poll (after_error)
  {
    if (poll_timeout >= -1 && !poll_delay_timeout_id) {
      var delay = (after_error ? poll_error_delay : poll_delay) * 1000;
      if (debug_log > 2)
	ROXEN.log ("AFS poll delay " + delay + " ms\n");
      poll_delay_timeout_id =
	setTimeout (function () {
	  poll_delay_timeout_id = undefined;
	  call ("poll",
		{timeout  : poll_timeout,
		 interval : poll_delay},
		poll_callback);
	}, delay);
    }
  }

  /**
   * (Re)initializes the AFS lib. All open connections are forgotten,
   * and a poll action is started right away (provided polling is
   * enabled).
   *
   * Global and error callbacks are not forgotten, and responses from
   * old open connections can still be delivered to them (subject to
   * change if necessary).
   *
   * @param {String}   afs_actions_path   Path prefix for all AFS actions.
   *                                      If not provided /actions/ is used.
   */
  function init(options)
  {
    if (options) {
      if (options["actions_prefix"])
	actions_prefix = options["actions_prefix"];
      if (options["session_var"])
	session_var = options["session_var"];
      if (options["poll_timeout"])
        poll_timeout = options["poll_timeout"];
    }
    
    if (debug_log)
      ROXEN.log ("AFS init\n");

    connection_ok = false;
    open_connections = 0;
    tagged_callbacks = {};

    if (poll_delay_timeout_id) {
      clearTimeout (poll_delay_timeout_id);
      poll_delay_timeout_id = undefined;
    }

    if (poll_timeout >= -1 && !open_connections)
      call ("poll",
	    {timeout  : poll_timeout,
	     interval : poll_delay},
	    poll_callback);
  }

  /**
   * Makes an asynchronous GET request to any URL.
   *
   * Note that this really has nothing to do with AFS.
   *
   * @method request
   * @param {String}   url   Requested URL.
   * @param {Function} fn    Callback function to run when done.
   *                         fn's argument list is (result, status).
   *                         status is AFS_REQUEST_SUCCESS or
   *                         AFS_REQUEST_FAILURE.
   * @param {Object}   scope Scope correction (optional).
   * @return {Object}        Returns the connection object.
   */
  function request(url, fn, scope) {
    var cb = {
      cache: false,
      success: function (o) {
        fn.call(scope, o, "AFS_REQUEST_SUCCESS");
      },
      failure: function  (o) {
        ROXEN.log("ROXEN.AFS: connection error: " +
                   o.status + " " + o.statusText + "\n");
        fn.call(scope, o, "AFS_REQUEST_FAILURE");
      }
    };
    return YAHOO.util.Connect.asyncRequest("GET", url, cb);
  }

  return {
    call: call,
    post: post,
    abort: abort,
    has_connection: has_connection,
    add_global_callback: add_global_callback,
    remove_global_callback: remove_global_callback,
    add_error_callback: add_error_callback,
    remove_error_callback: remove_error_callback,
    init: init,
    request: request
  };
}();
