/*
 * $Id: reloadconfigurations.pike,v 1.4 2000/08/16 14:49:14 lange Exp $
 */
#include <roxen.h>
//<locale-token project="admin_tasks">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("admin_tasks",X,Y)

constant action = "maintenance";

string name= LOCALE(24, "Reload configurations from disk");
string doc = LOCALE(25, 
		    "Force a reload of all configuration information from "
		    "the configuration files.");

mixed parse( RequestID id )
{
  roxen->reload_all_configurations();
  return LOCALE(26, "All configurations reloaded from disk.")+
    "<p><cf-ok/></p>";
}
