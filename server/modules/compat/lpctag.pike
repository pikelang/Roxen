// This is (not really) a roxen module.
inherit "module";

void start() 
{
  object configuration = my_configuration();
  werror("\n ***** lpctag module outdated. Adding piketag module instead.\n");
  configuration->add_modules( ({"piketag"}), 0 );
  call_out( configuration->disable_module, 0.5,  "lpctag#0" );
}
