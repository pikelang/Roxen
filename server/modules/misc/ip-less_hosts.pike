// This is a roxen module. (c) Informationsvävarna AB 1996.

string cvs_version = "$Id: ip-less_hosts.pike,v 1.3 1997/08/19 02:32:00 per Exp $";

#include <module.h>
inherit "module";

array register_module()
{
  return ({ MODULE_FIRST,
	    "IP-Less virtual hosting",
	    "This module adds support for IP-less virtual hosts, "
	    "simply add this module to a server with a real listen port "
	    "(Server Variables -&gt; Listen ports) "
	    "configured, then add no ports to all the servers you want to use "
	    "ip-less virtual hosting for, but "
	    "configure their server-URLs. This module will then automagically "
	    "select the server the request should be sent to",0,1
	  });
}

mapping config_cache = ([ ]);

object find_server_for(object id, string host)
{
  if(config_cache[host]) return id->conf=config_cache[host];
  array possible = ({});
  foreach(roxen->configurations, object s)
    if(search(s->query("MyWorldLocation"), host)+1)
      possible += ({ s });
  return id->conf=config_cache[host]=
    (sizeof(possible)?
     Array.sort_array(possible,lambda(object s, string q) {
       return -(strlen(s->query("MyWorldLocation"))-strlen(q));},host)[0]:
       ((sscanf(host, "%*[^.].%s", host)==2)?find_server_for(id,host):id->conf));
}

mapping first_try(object id)
{
  if(id->misc->host) find_server_for(id,lower_case((id->misc->host/":")[0]));
}

void start()
{
  config_cache = ([]);
}
inherit "http";
string status()
{
  string res="<table><tr bgcolor=lightblue><td>Host</td><td>Server</td></tr>";
  foreach(sort(indices(config_cache)), string s)
    res+="<tr><td>"+s+"</td><td><a href=/Configurations/"+
      http_encode_string(config_cache[s]->name)+">"+
      (config_cache[s]->name)+"</a></td></tr>";
  return res+"</table>";
}
