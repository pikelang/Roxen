// This is (not really) a roxen module. Copyright © 1996 - 1998, Idonex AB.

#include <module.h>
inherit "module";

void start() 
{
  object configuration = my_configuration();
  werror("\n ***** HTML parse outdated. Adding other modules instead.\n");
  if(configuration)
    foreach(({"rxmlparse","rxmltags","ssi","accessed","compat"}), string mod)
      if(!configuration->enabled_modules[mod] )
        configuration->enable_module(mod+"#0");
  call_out( configuration->disable_module, 0.5,  "htmlparse#0" );
}
