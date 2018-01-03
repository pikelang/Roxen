// This is a roxen module. Copyright © 1996 - 2009, Roxen IS.

// Logs the User-agent fields in a separate log.

constant cvs_version = "$Id$";
constant thread_safe=1;
#include <module.h>

inherit "module";

constant module_type = MODULE_LOGGER;
constant module_name = "Client logger";
constant module_doc  = "This is a client logger. It simply logs the 'user-agent'"
  " field in a log somewhere, the format should be compatible "
  "with other client loggers out there, making it somewhat useful"
  ". It is also possible to add the clientname to the normal log,"
  " this saves a file descriptor, but breaks some log analyzers. ";

void create()
{
  defvar("logfile", "$LOGDIR/Clients", "Client log file",
	 TYPE_STRING,
	 "This is the file into which all client names will be put.\n");
}

// This is a pointer to the method 'log' in the file object. For speed.
function logf;

void start()
{
  object c;
  if(!(c=open(query("logfile"), "wca"))) {
    report_error("Clientlogger: Cannot open logfile.\n");
    logf=0; // Reset the old value, if any..
  }
  else
    logf = c->write;
}

void log(RequestID id, mapping file)
{
  logf && logf(id->client ? id->client*" " + "\n" : "unknown\n");
}
