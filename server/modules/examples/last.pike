// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.

inherit "module";
// All roxen modules must inherit module.pike

constant cvs_version = "$Id$";
constant module_type = MODULE_LAST;
constant module_name = "RefDoc for MODULE_LAST";
constant module_doc = "This module does nothing, but its inlined "
		      "documentation gets imported into the roxen "
		      "programmer manual. You hardly want to add "
		      "this module to your virtual servers.";

int seen_requests;

mapping|int(0..1) last_resort(RequestID id)
//! The <pi>last_resort()</pi> method is called when all previous
//! modules have failed to return a response.
//!
//! The id argument is the request information object associated with
//! the request.
//!
//! The returned value is either zero, if you didn't handle the
//! request, a result mapping or the integer one, signifying that the
//! request should be processed again from start (used only by the
//! <ref>Path info support</ref> module).
{
  seen_requests++;
}

string status()
{
  return sprintf("<b>%d</b> requests have fallen through to this "
		 "module.", seen_requests);
}
