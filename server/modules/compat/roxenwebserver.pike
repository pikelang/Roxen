// This is a ChiliMoon module which provides miscellaneous backward
// compatibility tags and entities which are part of Roxen Webserver,
// but got replaced or dropped in ChiliMoon.
//
// Copyright (c) 2004-2005, Stephen R. van den Berg, The Netherlands.
//                         <srb@cuci.nl>
//
// This module is open source software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
// by the Free Software Foundation; either version 2, or (at your option) any
// later version.
//

constant cvs_version =
 "$Id: roxenwebserver.pike,v 1.3 2004/05/30 23:28:19 _cvs_stephen Exp $";
constant thread_safe = 1;
constant module_unique = 1;

#include <module.h>

inherit "module";

constant module_type = MODULE_TAG|MODULE_FIRST;
constant module_name = "Tags: Roxen Webserver";
constant module_doc  = 
 "This is a ChiliMoon module which provides miscellaneous backward "
 "compatibility tags and entities which are part of Roxen Webserver, "
 "but got replaced or dropped in ChiliMoon. <br />"
 "<p>Copyright &copy; 2004-2005, by "
 "<a href='mailto:srb@cuci.nl'>Stephen R. van den Berg</a>, "
 "The Netherlands.</p>"
 "<p>This module is open source software; you can redistribute it and/or "
 "modify it under the terms of the GNU General Public License as published "
 "by the Free Software Foundation; either version 2, or (at your option) any "
 "later version.</p>";

constant name = "roxenwebserver";

void create()
{
  set_module_creator("Stephen R. van den Berg <srb@cuci.nl>");
}

// ----------------- Entities ----------------------

void set_entities(RXML.Context c)
{
  c->add_scope("roxen", Roxen.scope_roxen);
}

// ----------------- Rest ----------------------

string status() {
  return "";
}
  
void start()
{
  query_tag_set()->prepare_context=set_entities;
}

mapping first_try(RequestID id)
{
  constant introxen="/internal-roxen-";
  string m=id->not_query;

  if(sizeof(m)>sizeof(introxen) && has_prefix(m,introxen))
    id->not_query = "/*/" + m[sizeof(introxen)..];

  if(!id->misc->_roxenwebserver)
  {
    id->misc->rxmlprefix = "<use package=\"roxenwebserver\" />"
     +(id->misc->rxmlprefix||"");
    id->misc->_roxenwebserver = 1;
  }

  return 0;
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"&system.":#"<desc type='scope'><p><short>
 Obsoleted by the &amp;system. scope.</short>
 </p>
</desc>",
]);
#endif
