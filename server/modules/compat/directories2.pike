// This is (not really) a roxen module. Copyright © 2000, Roxen IS.
//

inherit "module";

void start(int num, Configuration conf)
{
  module_dependencies (conf, ({ "directories" }));
  werror("\n ***** directories2 module is now directories. Adding directories module instead.\n");
  call_out( conf->disable_module, 0.5, "directories2#0" );
}
