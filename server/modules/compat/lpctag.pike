// This is (not really) a roxen module.
inherit "module";

void start(int num, Configuration conf)
{
  module_dependencies (conf, ({ "piketag" }));
  werror("\n ***** lpctag module outdated. Adding piketag module instead.\n");
  call_out( conf->disable_module, 0.5, "lpctag#0" );
}
