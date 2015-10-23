// This is a roxen module. Copyright © 1997 - 2009, Roxen IS.

inherit "module";

constant module_name = "DEPRECATED: UserDB";

void start(int num, Configuration conf)
{
  module_dependencies( conf, ({ "userdb_system","auth_httpbasic"}));
  werror("\n ***** UserDB module outdated. Adding other modules instead.\n");
  call_out( conf->disable_module, 0.5,  "userdb#0" );
}
