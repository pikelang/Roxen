#include <module.h>
inherit "module";


array register_module()
{
  return ({
    MODULE_LOGGER,
    "Extended Log File Format logger",
    "Logs requests accoding to the <a href=http://www.w3."
    "org/pub/WWW/TR/WD-logfile.html>extended log file format</a>",
    });
}

void create()
{
  defvar("logfile",
	 "../logs/"+lower_case(roxen->current_configuration->name)+"/log",
	 "Logfile", TYPE_FILE,"The file in which the requests will be logged");

  defvar("format", "time cs-method cs-uri",
	 "Log format", TYPE_STRING,
	 "This is the actual format to use. One or more of the "
	 " following fields can be specified: "
	 "<dl compact>"
	 "<dt>bytes<dd>The length of the data transfered, in bytes\n"
	 "<dt>dns<dd>The dns name\n"
	 "<dt>ip<dd>The IP-number\n"
	 "<dt>method<dd>The method (GET, PUT etc.) used\n"
	 "<dt>status<dd>The status code\n"
	 "<dt>time<dd>The time of the access\n"
	 "<dt>uri-query<dd>The query portion of the URI "
	    "(everything after a '?')"
	 "<dt>uri-stem<dd>The stem portion of the URI "
	    "(everything before a '?')"
	 "<dt>uri<dd>The full uri requested\n"
	 "</dl>"
	 "if the 'prefix-fieldname' is used, the prefix is one or more "
	 " of:\n"
	 " <dl compact>"
	 "<dt>c<dd>Client\n"
	 "<dt>s<dd>Server\n"
	 "<dt>cs<dd>Client to Server\n"
	 "<dt>sc<dd>Server to Client\n"
	 "</dl>\n"
	 "Thus cs-bytes is the amount of bytes sent to the server by "
	 " the client.  sc-* is always the default, no prefix is needed."
	 "Where such a prefix (sc) _is_ needed if one is to follow the"
	 "standard, roxen will add one automatically.\n"
	 "\n");
  
	 
}


void log(object id, mapping file)
{
      
}
  
