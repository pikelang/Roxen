/*
 * $Id$
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
  string res = "<h2 class='no-margin-top'>" +
    LOCALE(24, "Reload configurations from disk") + "</h2>";
  roxen->reload_all_configurations();
  res += LOCALE(26, "All configurations reloaded from disk.") +
    "<p><cf-ok/></p>";
  return res;
}
