// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.

inherit "module";
// All roxen modules must inherit module.pike

constant cvs_version = "$Id$";
constant module_type = MODULE_FILTER;
constant module_name = "RefDoc for MODULE_FILTER";
constant module_doc = "This module does nothing, but its inlined "
		      "documentation gets imported into the roxen "
		      "programmer manual. You hardly want to add "
		      "this module to your virtual servers.";
mapping last_seen;
int handled;
int seen;

mapping|void filter(mapping|void result, RequestID id)
//! The @[filter()] method is called for all files just before the
//! final resulting page is sent back to the browser. In effect, filter
//! modules are essentially MODULE_LAST modules that get called for all
//! requests, not only failed requests. The result parameter is either a
//! zero (for an unhandled request) or a standard <ref>result
//! mapping</ref>, as returned by any previous modules in the server.
//! The id argument, as usual, is the request information object
//! associated with the request.
//!
//! The returned value is either zero, here signifying that you didn't
//! rewrite or in any way alter the result mapping, or a new or changed
//! result mapping.
//!
//! Since all data server by your virtual server gets passed your
//! filter module(s), you typically need to make sure your filter
//! module doesn't interfere with such requests it wasn't intended to
//! touch, or you may end up with some pretty hard to find problems.
{
  seen++;
  last_seen = result;
  string|array(string) type = result->type;
  if (arrayp(type))
    type = type[0];
  if(!result                       // If nobody had anything to say, neither do we.
  || !stringp(result->data)        // Got a file descriptor. Hardly ever happens anyway.
  || !id->prestate->filterpass     // No prestate, no action for this module.
  || !glob("text/*", type)         // Only touch content types we're interested in.
    )
    return 0;

  handled++;
  result->data = sprintf("%O", result);
  result->type = "text/plain"; // When we're still mangling the request. :-)
  return result;
}

string status()
{
  return sprintf("Received <b>%d</b> requests, of which <b>%d</b> were "
		 "touched by the module. Last seen request's result "
		 "mapping: <pre>%s</pre>",
		 seen, handled, Roxen.html_encode_string(sprintf("%O", last_seen)));
}
