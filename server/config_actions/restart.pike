inherit "roxenlib";
constant name= "Restart Roxen";

constant doc = ("Roxen will shutdown and then restart automatically "
		"if you select this action.");

mixed handle(object id, object mc)
{
  return http_redirect(roxen->config_url()+"(restart)/Actions/");
}

