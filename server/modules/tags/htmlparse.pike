// This is a roxen module. Copyright © 1996 - 1998, Idonex AB.
//

#include <module.h>
inherit "module";

array register_module() {
  return ({ MODULE_PARSER, "Old RXML parser", "Use the <i>RXML parser</i> and "
    "<i>RXML tags</i> modules instead", 0, 1});
}

// This is heavy stuff, boys and girls. Do not try this at home!
void create(object configuration, int q) {
  werror("\nHTML parse outdated. Add other modules instead.");
  if(configuration)
    foreach(({"rxmlparse","rxmltags","ssi","accessed"}), string mod)
      if(!configuration->modules[mod] ||
        (!configuration->modules[mod]->copies &&
         !configuration->modules[mod]->master)) {
        configuration->enable_module(mod+"#0");
    if(roxen->root)
      roxen->configuration_interface()->build_root(roxen->root);
  }
}
