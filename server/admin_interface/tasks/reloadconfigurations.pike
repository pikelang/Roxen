/*
 * $Id: reloadconfigurations.pike,v 1.8 2004/05/31 23:01:45 _cvs_stephen Exp $
 */

constant task = "maintenance";
constant name = "Reload configurations from disk";
constant doc  = ("Force a reload of all configuration information from "
		 "the configuration files.");

mixed parse( RequestID id )
{
  core->reload_all_configurations();
  return "<font size='+1'><b>Reload configurations from disk</b></font><p />"
    "All configurations reloaded from disk."
    "<p><cf-ok/></p>";
}
