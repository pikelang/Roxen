// This is (not really) a roxen module. Copyright © 2000 - 2009, Roxen IS.
//

inherit "module";

constant module_type = MODULE_DEPRECATED;
constant module_name = "Fastdir";

void start(int num, Configuration conf)
{
  werror("\n ***** fastdir module is now directories. Adding directories module instead.\n");
  module_dependencies (conf, ({ "directories" }));
  call_out( conf->disable_module, 0.5, "fastdir#0" );
}
