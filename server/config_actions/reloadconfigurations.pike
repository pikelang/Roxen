/*
 * $Id: reloadconfigurations.pike,v 1.6 1998/07/25 04:20:44 neotron Exp $
 */

inherit "roxenlib";
constant name= "Maintenance//Reload configurations from disk";

constant doc = ("Force a reload of all configuration information from the "
		"configuration files");

constant more=1;

mixed handle(object id, object mc)
{
  roxen->reload_all_configurations();
  return http_redirect(roxen->config_url()+"Actions/?"+time());  
}



