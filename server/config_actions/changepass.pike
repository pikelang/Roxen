/*
 * $Id: changepass.pike,v 1.5 1997/08/20 14:23:51 per Exp $
 */

inherit "roxenlib";
constant name= "Security//Change password and/or username...";

constant doc = ("Change the configuration interface username and/or password. "
		"This is a shortcut to the initial configuration page of "
		"roxen");

mixed handle(object id, object mc)
{
  return http_redirect(roxen->config_url()+"(changepass)/Actions/?"+time());
}
