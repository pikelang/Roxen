// Config tablist look-a-like module. Copyright © 1999, Idonex AB.
//

constant cvs_version="$Id: configtablist.pike,v 1.19 1999/09/29 10:27:05 nilsson Exp $";

#include <module.h>
inherit "module";
inherit "roxenlib";

#define old_rxml_compat 1

array register_module() {
  return ({ MODULE_PARSER, "Old tab list module", "Use the <i>Tab list</i> module instead", 0, 1});
}

// This is heavy stuff, boys and girls. Do not try this at home!
void create(object configuration, int q) {
  werror("\nConfig tab list outdated. Add Tab list instead.");
  if(configuration)
    if(!configuration->modules["tablist"] ||
       (!configuration->modules["tablist"]->copies &&
        !configuration->modules["tablist"]->master)) {
      configuration->enable_module("tablist#0");
    if(roxen->root)
      roxen->configuration_interface()->build_root(roxen->root);
  }
}

#if old_rxml_compat
string tag_ctablist(string t, mapping a, string c) {
  return make_container("tablist",a,c);
}

mapping query_container_callers() {
  return ([ "config_tablist":tag_ctablist ]);
}
#endif
