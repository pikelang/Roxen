/*
 * $Id: reloadconfigurations.pike,v 1.3 2000/07/17 16:12:41 lange Exp $
 */

constant action="maintenance";
constant name= "Reload configurations from disk";
constant doc = ("Force a reload of all configuration information from the "
		"configuration files.");

mixed parse( RequestID id )
{
  roxen->reload_all_configurations();
  return "All configurations reloaded from disk.<p><cf-ok>";
}
