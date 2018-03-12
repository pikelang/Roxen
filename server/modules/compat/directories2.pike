// This is (not really) a roxen module. Copyright © 2000 - 2009, Roxen IS.
//

inherit "module";

constant module_type = MODULE_DEPRECATED;
constant module_name = "DEPRECATED: Directories 2";

void start(int num, Configuration conf)
{
  module_dependencies (conf, ({ "directories" }));
  werror("\n ***** directories2 module is now directories. Adding directories module instead.\n");
  call_out( conf->disable_module, 0.5, "directories2#0" );
}
