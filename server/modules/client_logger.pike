#include <module.h>
inherit "module";

array register_module()
{
  return ({ MODULE_LOGGER, 
	      "Client logger", 
	      "This is a client logger. It simply logs the 'user-agent'"
	      " field in a log somewhere." 
	  });
}

void create()
{
  defvar("logfile", GLOBVAR(logdirprefix)+"/Clients", "Client log file", 
	 TYPE_STRING,
	 "This is the file into which all client names will be put.\n");
}

// This is a pointer to the method 'log' in the file object. For speed.
function logf;

void start()
{
  object c;
  logf=0; // Reset the old value, if any..
  if(!(c=open(query("logfile"), "wca")))
    report_error("Clientlogger: Cannot open logfile.\n");
  else
    logf = c->write;
}

void log(object id, mapping file) 
{
  logf && logf(id->client*" " + "\n");
}
