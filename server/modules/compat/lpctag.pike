// This is (not really) a roxen module. Copyright © 2000 - 2009, Roxen IS.
//

inherit "module";

constant module_name = "DEPRECATED: lpctag";

void start(int num, Configuration conf)
{
  module_dependencies (conf, ({ "piketag" }));
  werror("\n ***** lpctag module outdated. Adding piketag module instead.\n");
  call_out( conf->disable_module, 0.5, "lpctag#0" );
}
