/*
 * $Id: reloadconfigurations.pike,v 1.6 2002/06/13 00:18:10 nilsson Exp $
 */

constant task = "maintenance";
constant name = "Reload configurations from disk";
constant doc  = ("Force a reload of all configuration information from "
		 "the configuration files.");

mixed parse( RequestID id )
{
  roxen->reload_all_configurations();
  return "All configurations reloaded from disk."
    "<p><cf-ok/></p>";
}
