// Config tablist look-a-like module. Copyright © 1999, Idonex AB.
//

constant cvs_version="$Id: configtablist.pike,v 1.1 1999/11/27 12:18:34 nilsson Exp $";

#include <module.h>
inherit "module";
inherit "roxenlib";

array register_module() {
  return ({ MODULE_PARSER, "Old tab list module", "Use the <i>Tab list</i> module instead", 0, 1});
}

void start() {
  object configuration = my_configuration();
  werror("\n ***** Config tab list outdated. Adding Tab list instead.\n");
  if(configuration)
    if(!configuration->enabled_modules->tablist )
      configuration->enable_module("tablist#0");
  call_out( configuration->disable_module, 0.5,  "configtablist#0" );
}

string tag_ctablist(string t, mapping a, string c) {
  return make_container("tablist",a,c);
}

mapping query_container_callers() {
  return ([ "config_tablist":tag_ctablist ]);
}
