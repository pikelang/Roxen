// This is a ChiliMoon module which provides the insert href tag.
//
// This module is open source software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
// by the Free Software Foundation; either version 2, or (at your option) any
// later version.
//

#define _ok id->misc->defines[" _ok"]

constant cvs_version =
 "$Id: inserthref.pike,v 1.1 2004/06/01 17:02:37 _cvs_stephen Exp $";
constant thread_safe = 1;
constant module_unique = 1;

#include <module.h>
#include <request_trace.h>

inherit "module";


// ---------------- Module registration stuff ----------------

constant module_type = MODULE_TAG;
constant module_name = "Tags: Insert href";
constant module_doc  =
 "This module provides the insert href tag.<br />"
 "<p>This module is open source software; you can redistribute it and/or "
 "modify it under the terms of the GNU General Public License as published "
 "by the Free Software Foundation; either version 2, or (at your option) any "
 "later version.</p>";

void create() {
  set_module_creator("Stephen R. van den Berg <srb@cuci.nl>");
}

string status() {
  return "";
}

class TagInsertHref {
  inherit RXML.Tag;
  constant name = "insert";
  constant plugin_name = "href";

  string get_data(string var, mapping args, RequestID id) {
    if(args->nocache)
      NOCACHE();
    else
      CACHE(60);
    Protocols.HTTP.Query q=Protocols.HTTP.get_url(args->href);
    if(q && q->status>0 && q->status<400)
      return q->data();

    RXML.run_error(q ? q->status_desc + "\n": "No server response\n");
  }
}

// --------------------- Documentation -----------------------

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([

//----------------------------------------------------------------------

  "insert#href":#"<desc type='plugin'><p><short>
 Inserts the contents at that URL.</short> This function has to be
 enabled in the <module>Additional RXML tags</module> module in the
 ChiliMoon administration interface. The page download will block
 the current thread, and if running unthreaded, the whole server.
 There is no timeout in the download, so if the server connected to
 hangs during transaction, so will the current thread in this server.</p></desc>

<attr name='href' value='string'><p>
 The URL to the page that should be inserted.</p>
</attr>

<attr name='nocache' value='string'><p>
 If provided the resulting page will get a zero cache time in the RAM cache.
 The default time is up to 60 seconds depending on the cache limit imposed by
 other RXML tags on the same page.</p>
</attr>",

//----------------------------------------------------------------------

    ]);
#endif
