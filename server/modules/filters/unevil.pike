// Copyright (C) 2001 Roxen IS
// Module author: Johan Sundström

inherit "module";
#include <request_trace.h>

constant cvs_version = "$Id: unevil.pike,v 1.1 2001/06/27 12:42:28 jhs Exp $";
constant thread_safe = 1;
constant module_type = MODULE_FILTER;
constant module_name = "SmartTags Preventer";
constant unsmarttags = "meta name=\"MSSmartTagsPreventParsing\""
		       " content=\"TRUE\"";
constant module_doc  = "<p>This module puts a &lt;" + unsmarttags +
#"&gt; tag on all of your pages before sending them to the client.
This should prevent evil browsers from tampering with your page,
adding non authoritative links all over the place.</p>";

string prevent_evil(string page)
{
  string lower = lower_case( page );
  int header;
  if((header = search( lower, "</head>" )) < 0)
    return sprintf("<head><%s></head>%s", unsmarttags, page);
  return sprintf("%s<%s>%s", page[..header-1], unsmarttags,
		 page[header..]);
}

mapping filter(mapping result, RequestID id)
{
  if(!result				// nobody had anything to say
  || !stringp(result->data)		// got a file object
  || !glob("text/html*", result->type)	// only for HTML files
  || id->misc[this_object()]++)		// already purged of all evil
    return 0; // signal that we didn't rewrite the result

  TRACE_ENTER("Opt-out-tagging \"Smart Tags\".", 0);
  result->data = prevent_evil(result->data);
  TRACE_LEAVE("");
  return result;
}
