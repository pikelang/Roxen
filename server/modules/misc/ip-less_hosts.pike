// This is a roxen module. (c) Informationsvävarna AB 1996.
 
constant cvs_version = "$Id: ip-less_hosts.pike,v 1.9 1998/03/02 14:43:57 grubba Exp $";
constant thread_safe=1;

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
  host = lower_case(host);
  if(config_cache[host]) return id->conf=config_cache[host];
#if constant(Array.diff_longest_sequence)
  int best;
  array a = host/"";
  object c;
  foreach(roxen->configurations, object s) {
    int corr = sizeof(Array.diff_longest_sequence(a, lower_case(s->query("MyWorldLocation"))/""));
    if (corr > best) {
      best = corr;
      c = s;
    }
  }
  return id->conf = config_cache[host] = (c || id->conf);
  
#else /* !constant(Array.diff_longest_sequence) */
  array possible = ({});
  foreach(roxen->configurations, object s)
    if(search(lower_case(s->query("MyWorldLocation")), host)+1)
      possible += ({ s });
  return id->conf=config_cache[host]=
    (sizeof(possible)?
     Array.sort_array(possible,lambda(object s, string q) {
       return (strlen(s->query("MyWorldLocation"))-strlen(q));},host)[0]:
       ((sscanf(host, "%*[^.].%s", host)==2)?find_server_for(id,host):id->conf));
#endif /* constant(Array.diff_longest_sequence) */
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
