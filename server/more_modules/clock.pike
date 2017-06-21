// This is a Clock Module.

string cvs_version = "$Id$";
// One of the first modules written for Spinner, here for nostalgical
// reasons.  It could be used as an example of how to write a simple
// location module.

#include <module.h>

inherit "module";
inherit "roxenlib";

void create()
{
  defvar("modification", 0, "Time modification", TYPE_INT, 
	 "Time difference in seconds from system clock.");

  defvar("mountpoint", "/clock/", "Mount point", TYPE_LOCATION, 
	 "Clock location in filesystem.");
}

array(mixed) register_module()
{
  return ({ 
    MODULE_LOCATION,
    "Explicit clock", 
    "This is the Clock Module.",
    });
}

string query_location() { return query("mountpoint"); }

int my_time() {  return time(1)+query("modification"); }

mapping find_file( string f )
{
  if((int)f)
    return http_string_answer("<title>And the time is...</title>"+
			      "<h1>Local time: "+ctime((int)f)+
			      "</h1><h1>GMT: "+http_date((int)f)+"</h1>");

  return http_string_answer("<html><head><title>" + ctime(my_time())
			    +"</title></head><body><h1>"
			    +ctime(time(1))+"</h1></body></html>\n")
    + ([ "extra_heads":
	([
	  "Expires": http_date(time(1)+5),
	  "Refresh":5-time(1)%5,
	  "Last-Modified":http_date(time(1)-1)
	  ])
	]);
}

string query_name()
{
  return query("mountpoint")+" ("+ctime(my_time())[11..15]+")";
}

