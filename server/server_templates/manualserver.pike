/*
 * $Id: manualserver.pike,v 1.2 1999/01/26 06:21:40 peter Exp $
 */

#include <module.h>

constant selected = 0;
constant name = "Manual viewing server";
constant desc = "A virtual server with the modules needed for a manuals viewing server.";
constant modules = ({
  "obox#0",
  "flik#0",
  "weblayout#0",
  "tablify#0",
  "business#0",
  "wizard_tag#0",
  "filesystem#0",
  "lpctag#0",
  "directories#0",
  "configtablist#0",
  "check_spelling#0",
  "ximg#0",
  "indirect_href#0",
  "fnord#0",
  "contenttypes#0",
  "killframe#0",
  "ismap#0",
  "graphic_text#0",
  "countdown#0",
  "htmlparse#0",
  "sed#0"
});

void enable(object config)
{
  foreach(modules, string module)
    config->enable_module(module);
}

void post(object node)
{
  object o,o2;
  if(o = node->descend( "Global", 1 )) {
    o->folded = 0;
    if(o2 = o->descend( "Ports", 1 )) {
      o2->folded = 0;
      o2->change(1);
    }
  }
  
  if(o = node->descend( "Filesystem", 1 ))
  {
    o->folded = 1;
    if(o = o->descend( "0", 1))
      if(o2 = o->descend( "searchpath", 1))
      {
	o2->data[VAR_VALUE] = "manual/unparsed/";
	o2->change(1);
      }
  }
  
  o->save();
}
