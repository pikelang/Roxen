/*
 * $Id: reloadconfigurations.pike,v 1.7 2004/05/29 00:32:05 _cvs_stephen Exp $
 */

constant task = "maintenance";
constant name = "Reload configurations from disk";
constant doc  = ("Force a reload of all configuration information from "
		 "the configuration files.");

mixed parse( RequestID id )
{
  roxen->reload_all_configurations();
  return "<font size='+1'><b>Reload configurations from disk</b></font><p />"
    "All configurations reloaded from disk."
    "<p><cf-ok/></p>";
}
