// This is (not really) a roxen module.
inherit "module";

void start(int num, Configuration conf) {
  module_dependencies (conf, ({ "rxmltags","rxmlparse","ssi","accessed","compat" }));
  werror("\n ***** HTML parse outdated. Adding other modules instead.\n");
  call_out( conf->disable_module, 0.5,  "htmlparse#0" );
}
