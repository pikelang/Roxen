inherit "roxenlib";
constant name= "Change password and/or username...";

constant doc = ("Change the configuration interface username and/or password. "
		"This is a shortcut to the initial configuration page of "
		"roxen");

mixed handle(object id, object mc)
{
  return http_redirect(roxen->config_url()+"(changepass)/Actions/");
}
