// Config tablist look-a-like module. Copyright © 1999, Idonex AB.
//

constant cvs_version="$Id: configtablist.pike,v 1.17 1999/09/23 20:50:38 nilsson Exp $";

#include <module.h>
inherit "module";

array register_module() {
  return ({ MODULE_PARSER, "Old tab list modules.", "Use the Tab list module instead", 0, 1});
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
  _do_call_outs();
}
