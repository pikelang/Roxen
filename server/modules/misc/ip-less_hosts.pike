// This is a roxen module. Copyright © 1996 - 1998, Idonex AB.
 
constant cvs_version = "$Id: ip-less_hosts.pike,v 1.21 1998/07/29 06:31:18 neotron Exp $";
constant thread_safe=1;

#include <module.h>
inherit "module";

//#define IP_LESS_DEBUG

array register_module()
{
  return ({ MODULE_FIRST,
	      "IP-Less virtual hosting",
	      "This module adds support for IP-less virtual hosts, "
	      "simply add this module to a server with a real listen port "
	      "(Server Variables -&gt; Listen ports) "
	      "configured, then add no ports to all the servers you want to "
	      "use ip-less virtual hosting for, but configure their "
	      "server-URLs. This module will then automagically "
	      "select the server the request should be sent to."
	      "<p><b>Please note that the ip less hosting module "
	      "doesn't work together with proxies. The reason is that the "
	      "host header sent isn't the one of the proxy server, but the "
	      "one of the requested host. We recommend having the proxies in "
	      "their own virtual server, with a unique IP and / or port.</b>",
	      0, 1 });
}

mapping config_cache = ([ ]);

int is_ip(string s)
{
  return(replace(s,
		 ({ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "." }),
		 ({ "","","","","","","","","","","" })) == "");
}

object find_server_for(object id, string host)
{
  object old_conf = id->conf;

  host = lower_case(host);
  if(config_cache[host]) {
    id->conf=config_cache[host];
  } else {

    if (is_ip(host)) {
      // Not likely to be anything else than the current virtual server.
      config_cache[host] = id->conf;
      return(id->conf);
    }


#if constant(String.fuzzymatch)
    int best;
    object c;
    string hn;
#ifdef IP_LESS_DEBUG
    roxen_perror("IPLESS: find_server_for(object, \""+host+"\")...\n");
#endif /* IP_LESS_DEBUG */
    foreach(roxen->configurations, object s) {
      string h = lower_case(s->query("MyWorldLocation"));

      // Remove http:// and trailing slash...
      // Would get interresting correlation problems with the "http" otherwise.
      sscanf(h, "%*s://%s/", h);

      int corr = String.fuzzymatch(host, h);
#ifdef IP_LESS_DEBUG
      roxen_perror(sprintf("IPLESS: host: \"%s\"\n"
			   "IPLESS: server: \"%s\"\n"
			   "IPLESS: corr: %d\n",
			   host, h, corr));
#endif /* IP_LESS_DEBUG */
      if ((corr > best) ||
	  ((corr == best) && hn && (sizeof(hn) > sizeof(h)))) {
	/* Either better correlation,
	 * or the same, but a shorter hostname.
	 */
#ifdef IP_LESS_DEBUG
	roxen_perror(sprintf("IPLESS: \"%s\" is a better match for \"%s\" than \"%s\"\n",
			     h, host, hn||""));
#endif /* IP_LESS_DEBUG */
	best = corr;
	c = s;
	hn = h;
      }
    }
    id->conf = config_cache[host] = (c || id->conf);

#elif constant(Array.diff_longest_sequence)

    /* The idea of the algorithm is to find the server-url with the longest
     * common sequence of characters with the host-string, and among those with
     * the same correlation take the one which is shortest (ie least amount to
     * throw away).
     */

    int best;
    array a = host/"";
    string hn;
    object c;
#ifdef IP_LESS_DEBUG
    roxen_perror("IPLESS: find_server_for(object, \""+host+"\")...\n");
#endif /* IP_LESS_DEBUG */
    foreach(roxen->configurations, object s) {
      string h = lower_case(s->query("MyWorldLocation"));

      // Remove http:// et al here...
      // Would get interresting correlation problems with the "http" otherwise.
      int i = search(h, "://");
      if (i != -1) {
	h = h[i+3..];
      }

      array common = Array.diff_longest_sequence(a, h/"");
      int corr = sizeof(common);
#ifdef IP_LESS_DEBUG
      string common_s = rows(h/"", common)*"";
      roxen_perror(sprintf("IPLESS: h: \"%s\"\n"
			   "IPLESS: common: %O (\"%s\")\n"
			   "IPLESS: corr: %d\n",
			   h, common, common_s, corr));
#endif /* IP_LESS_DEBUG */
      if ((corr > best) ||
	  ((corr == best) && hn && (sizeof(hn) > sizeof(h)))) {
	/* Either better correlation,
	 * or the same, but a shorter hostname.
	 */
#ifdef IP_LESS_DEBUG
	roxen_perror(sprintf("IPLESS: \"%s\" is a better match for \"%s\" than \"%s\"\n",
			     h, host, hn||""));
#endif /* IP_LESS_DEBUG */
	best = corr;
	c = s;
	hn = h;
      }
    }
    id->conf = config_cache[host] = (c || id->conf);
  
#else /* !constant(Array.diff_longest_sequence) */
    array possible = ({});
    foreach(roxen->configurations, object s)
      if(search(lower_case(s->query("MyWorldLocation")), host)+1)
	possible += ({ s });
    id->conf=config_cache[host]=
      (sizeof(possible)?
       Array.sort_array(possible,lambda(object s, string q) {
	 return (strlen(s->query("MyWorldLocation"))-strlen(q));},host)[0]:
	   ((sscanf(host, "%*[^.].%s", host)==2)?find_server_for(id,host):id->conf));
#endif /* constant(Array.diff_longest_sequence) */
  }

  if (id->conf != old_conf) {
    /* Need to re-authenticate with the new server */

    if (id->rawauth) {
      array(string) y = id->rawauth / " ";

      id->realauth = 0;
      id->auth = 0;

      if (sizeof(y) >= 2) {
	y[1] = MIME.decode_base64(y[1]);
	id->realauth = y[1];
	if (id->conf && id->conf->auth_module) {
	  y = id->conf->auth_module->auth(y, id);
	}
	id->auth = y;
      }
    }
  }

  return id->conf;
}

mapping first_try(object id)
{
  if(id->misc->host) find_server_for(id,lower_case((id->misc->host/":")[0]));
}

void clear_memory_cache()
{
  config_cache = ([]);
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
