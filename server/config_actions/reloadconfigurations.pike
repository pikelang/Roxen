inherit "roxenlib";
constant name= "Reload configurations from disk";

constant doc = ("Force a reload of all configuration information from the "
		"configuration files");

int more=1;

mixed handle(object id, object mc)
{
  roxen->setvars(roxen->retrieve("Variables", 0));
  roxen->enable_configurations();
  return http_redirect(roxen->config_url()+"Actions/");
}
