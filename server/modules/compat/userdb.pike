inherit "module";

void start(int num, Configuration conf)
{
  module_dependencies( conf, ({ "userdb_system","auth_httpbasic"}));
  werror("\n ***** UserDB module outdated. Adding other modules instead.\n");
  call_out( conf->disable_module, 0.5,  "userdb#0" );
}
