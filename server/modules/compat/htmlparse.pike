// This is (not really) a roxen module. Copyright © 2000 - 2009, Roxen IS.
//

inherit "module";

constant module_type = MODULE_DEPRECATED;
constant module_name = "HTML Parse";

void start(int num, Configuration conf) {
  module_dependencies (conf, ({ "rxmltags","rxmlparse","ssi","accessed","compat" }));
  werror("\n ***** HTML parse outdated. Adding other modules instead.\n");
  call_out( conf->disable_module, 0.5,  "htmlparse#0" );
}
