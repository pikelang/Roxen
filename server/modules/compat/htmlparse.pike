// This is (not really) a roxen module.
inherit "module";

void start() 
{
  object configuration = my_configuration();
  werror("\n ***** HTML parse outdated. Adding other modules instead.\n");
  configuration->add_modules( ({"rxmlparse", "rxmltags",
                                "ssi",       "accessed",
                                "compat"}), 0 );
  call_out( configuration->disable_module, 0.5,  "htmlparse#0" );
}
