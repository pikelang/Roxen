// This is a roxen module. (c) Informationsvävarna AB 1996.

// Like the redirect module, but transparent to the user. This module
// will connect to another server, and get the data from there, and
// then return the new data to the user.  The same results can be
// achieved using the proxy and the redirect module.  With
// caching. This module is therefore quite obsolete, really.  But
// since it is so small, I have left it here.

constant cvs_version = "$Id: relay.pike,v 1.9 1997/08/31 04:12:42 peter Exp $";
constant thread_safe = 1;

#include <module.h>

inherit "module";
inherit "roxenlib";
inherit "socket";

#define CONN_REFUSED "\
HTTP/1.0 503 Service Unavailable\r\n\
Content-type: text/html\r\n\
\r\n\
<title>Service unavailable</title>\
\
<h1 align=center>Service unavailable</h1>\
<hr noshade>\
<font size=+2>Please try again later.</font>\
<i>Sorry</i>\
<hr noshade>"

/* Simply relay a request to another server if the data was not found. */

mixed *register_module()
{
  return ({ 
    MODULE_LAST | MODULE_FIRST,
    "HTTP-Relay", 
    "Relays HTTP requests from this server to another one. <p>"
      "Like the redirect module, but transparent to the user. This module "
      "will connect to another server, and get the data from there, and "
      "then return the new data to the user.  The same results can be "
      "achieved using the proxy and the redirect module.  With "
      "caching. This module is therefore quite obsolete, really.  But "
      "since it is so small, I have left it here. "
      });
}

void create()
{
  defvar("pri", "Last", "Module priority", TYPE_STRING_LIST,
	 "If last, first try to find the file in a normal way, otherways, "
	 "first try redirection.",
	 ({ "Last", "First" }));

  defvar("relayh", "", "Relay host", TYPE_STRING,
	 "The ip-number of the host to relay to");

  defvar("relayp", 80, "Relay port", TYPE_INT,
	 "The port-number of the host to relay to");
  
  defvar("always", "", "Always redirect", TYPE_TEXT_FIELD,
	 "Always relay these, even if the URL match the 'Don't-list'.");

  defvar("anti", "", "Don`t redirect", TYPE_TEXT_FIELD,
	 "Never relay these, unless the URL match the 'Always-list'.");
}

string comment()
{
  return "http://"+query("relayh")+":"+query("relayp")+"/";
}

void connected(object to, object id)
{
  if(!id || !to || !to->query_address()) {
    if (id)
      id->end(CONN_REFUSED);
    if (to)
      destruct(to);
    return;
  }
  to->write(id->raw);
  id->do_not_disconnect = 0;
  roxen->shuffle(to, id->my_fd);
}

array (string) always_list=({ });

array (string) anti_list = ({ });

void start()
{
  always_list=(QUERY(always)-"\r")/"\n";
  anti_list=(QUERY(anti)-"\r")/"\n";
}

int is_in_anti_list(string s)
{
  int i;
  for(i=0; i<sizeof(anti_list); i++) 
    if(glob(anti_list[i], s))  return 1;
}

int is_in_always_list(string s)
{
  int i;
  for(i=0; i<sizeof(always_list); i++) 
    if(glob(always_list[i], s)) return 1;
}

mapping relay(object fid)
{
  if(!is_in_always_list(fid["not_query"]) &&
     is_in_anti_list(fid["not_query"]))
    return 0;
  
  fid -> do_not_disconnect = 1;
  
  async_connect(QUERY(relayh), QUERY(relayp), connected, fid );
  return http_pipe_in_progress();
}

mapping last_resort(object fid)
{
  if(QUERY(pri) != "Last")  return 0;
  return relay(fid);
}

mapping first_try(object fid)
{
  if(QUERY(pri) == "Last") return 0;
  return relay(fid);
}
