/*
 * $Id: reloadconfigurations.pike,v 1.1 2000/02/04 06:07:19 per Exp $
 */

inherit "roxenlib";
constant action="maintenance";
constant name= "Reload configurations from disk";
constant doc = ("Force a reload of all configuration information from the "
		"configuration files");

mixed parse(object id)
{
  roxen->reload_all_configurations();
  return "All configurations reloaded from disk<p><cf-ok>";
}
