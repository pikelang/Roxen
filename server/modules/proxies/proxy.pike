// This is a roxen module. (c) Informationsvävarna AB 1996.

// HTTP Proxy module. Should be cleaned and optimized. Currently the
// limit of proxy connections/second is somewhere around 70% of normal
// requests, but there is no real reason for them to take longer.

string cvs_version = "$Id: proxy.pike,v 1.28 1998/01/17 02:57:27 grubba Exp $";
#include <module.h>
#include <config.h>

#if DEBUG_LEVEL > 21
# ifndef PROXY_DEBUG
#  define PROXY_DEBUG
# endif
#endif

#define CONNECTION_REFUSED(X) "\
HTTP/1.0 500 "+X+"\r\n\
Content-type: text/html\r\n\
\r\n\
<title>Roxen: "+X+"</title>\n\
<h1>Proxy Request Failed</h1>\
<hr>\
<font size=+2><i>"+X+"</i></font>\
<hr>\
<font size=-2><a href=http://www.roxen.com/>Roxen Challenger</a></font>"

import Stdio;
import Array;

inherit "module";
inherit "socket";
inherit "roxenlib";

#include <proxyauth.pike>
#include <roxen.h>

program filep = files.file;

mapping (object:string) requests = ([ ]);
object logfile;

function nf=lambda(){};

void init_proxies();

function (string:int) no_cache_for;

void start()
{
  string pos;
  pos=QUERY(mountpoint);
  init_proxies();
  if(strlen(pos)>2 && (pos[-1] == pos[-2]) && pos[-1] == '/')
    set("mountpoint", pos[0..strlen(pos)-2]); // Evil me..

  if(strlen(QUERY(NoCacheFor)))
    if(catch(no_cache_for = Regexp("("+(QUERY(NoCacheFor)-"\r"-"\n\n")/"\n"*")|("
				   +")")->match))
      report_error("Parse error in 'No cache' regular expression.\n");

  if(!no_cache_for) no_cache_for = lambda(string i){return 0;};
  
  if(logfile) 
    destruct(logfile);

  if(!strlen(QUERY(logfile)))
    return;

#ifdef PROXY_DEBUG
  perror("Proxy online.\n");
#endif

  if(QUERY(logfile) == "stdout")
  {
    logfile=stdout;
  } else if(QUERY(logfile) == "stderr") {
    logfile=stderr;
  } else {
    if(logfile=open(QUERY(logfile), "wac"))
      mark_fd(logfile->query_fd(),"Proxy logfile ("+QUERY(logfile)+")")
	;
  }
}

void do_write(string host, string oh, string id, string more)
{
  if(!host)     host=oh;
  logfile->write("[" + cern_http_date(time(1)) + "] http://" +
		 host + ":" + id + "\t" + more + "\n");
}

void log(string file, string more)
{
  string host, rest;

  if(!logfile) return;
  sscanf(file, "%s:%s", host, rest);
  roxen->ip_to_host(host, do_write, host, rest, more);
}



array proxies=({});
array filters=({});

void init_proxies()
{
  string foo;
  array err;

  proxies = ({ });
  filters = ({ });
  foreach(QUERY(Proxies)/"\n", foo)
  {
    array bar;
    if(!strlen(foo) || foo[0] == '#')
      continue;
    
    bar = replace(foo, "\t", " ")/" " -({ "" });
    if(sizeof(bar) < 3) continue;
    if(err=catch(proxies += ({ ({ Regexp(bar[0])->match, 
				  ({ bar[1], (int)bar[2] }) }) })))
      report_error("Syntax error in regular expression in proxy: "+bar[0]+"\n"+
		   err[0]);
  }

  foreach(QUERY(Filters)/"\n", foo)
  {
    array bar;
    if(!strlen(foo) || foo[0] == '#')
      continue;
    
    bar = replace(foo, "\t", " ")/" " -({ "" });
    if(sizeof(bar) < 2) continue;
    if(err=catch(filters += ({ ({ Regexp(bar[0])->match, 
				   bar[1..]*" " })})))
      report_error("Syntax error in regular expression in proxy: "+bar[0]+"\n"+
		   err[0]);
  }
}

string check_variable(string name, mixed value)
{
  if(name == "Proxies")
  {
    array tmp,c;
    string tmp2;
    tmp = proxies;
    tmp2 = QUERY(Proxies);

    set("Proxies", value);
    if(c=catch(init_proxies()))
    {
      proxies = tmp;
      set("Proxies", tmp2);
      return "Error while compiling regular expression. Syntax error: "
	     +c[0]+"\n";
    }
    proxies = tmp;
    set("Proxies", tmp2);
  }
}

void create()
{         
  defvar("logfile", "", "Logfile", TYPE_FILE,
	 "Empty the field for no log at all");
  
  defvar("mountpoint", "http:/", "Location", TYPE_LOCATION|VAR_MORE,
	 "By default, this is http:/. If you set anything else, all "
	 "normal WWW-clients will fail. But, other might be useful"
	 ", like /http/. if you set this location, a link formed like "
	 " this: &lt;a href=\"/http/\"&lt;my.www.server&gt;/a&gt; will enable"
	 " accesses to local WWW-servers through a firewall.<p>"
	 "Please consider security, though.");

  defvar("NoCacheFor", "", "No cache for", TYPE_TEXT_FIELD|VAR_MORE,
	 "This is a list of regular expressions. URLs that match "
	 "any entry in this list will not be cached at all.");

  defvar("cache_cookies", 0, "Cache pages with cookies", TYPE_FLAG|VAR_MORE,
	 "If this option is set, documents with cookies will be cached. "
	 "As such pages might be dynamically made depending on the values of "
	 "the cookies, you might want to leave this option off.");
  
  defvar("Proxies", "", "Remote proxy regular expressions", TYPE_TEXT_FIELD|VAR_MORE,
	 "Here you can add redirects to remote proxy servers. If a file is "
	 "requested from a host matching a pattern, the proxy will query the "
	 "proxy server at the host and port specified.<p> "
	 "Hopefully, that proxy will then connect to the remote computer. "
	 "<p>"
	 "Example:<hr noshade>"
	 "<pre>"
	 "# All hosts inside *.rydnet.lysator.liu.se has to be\n"
	 "# accessed through lysator.liu.se\n"
	 ".*\\.rydnet\\.lysator\\.liu\\.se        130.236.253.11  80\n"
	 "# Do not access *.dec.com via a remote proxy\n"
	 ".*\\.dec\\.com                         no_proxy        0\n"
	 "# But all other .com\n"
	 ".*\\.com                         130.236.253.11        0\n"
	 "</pre>"
	 "Please note that this <b>must</b> be "
	 "<a href=$configurl/regexp.html>Regular Expressions</a>.");

  defvar("Filters", "", "External filter regular expressions", TYPE_TEXT_FIELD|VAR_MORE,
	 "External filters to run if the regular expression match. "
	 "<p>Examples (this one works): "
	 "<pre>"
	 "www2.infoseek:[0-9]*/       bin/proxyfilterdemo infoseek\n"
	 "www2.infoseek.com:[0-9]*/.*html   bin/proxyfilterdemo infoseek\n"
	 "www.lycos.com:[0-9]*/       bin/proxyfilterdemo lycos\n"
	 "www.lycos.com:[0-9]*/.*html bin/proxyfilterdemo lycos\n"
	 "</pre>"
	 "Please note that this <b>must<b> be "
	 "<a href=$configurl/regexp.html>Regular Expressions</a>.");
}

mixed *register_module()
{
  return ({  MODULE_PROXY|MODULE_LOCATION, 
	       "HTTP-Proxy", "This is a caching HTTP-proxy with quite "
	       " a few bells and whistles", });
}

string query_location()  { return QUERY(mountpoint); }

string status()
{
  string res="";
  object foo;
  int total;

  if(sizeof(requests))
  {
    res += "<hr><h1>Current connections</h1><p>";
    foreach( indices(requests), foo )
      if(objectp(foo))
	res += requests[foo] + ": " + foo->status() + "\n";
  }
  res += "<hr>";
 return ("<pre><font size=+1>"+res+"</font></pre>");
}

string process_request(object id, int is_remote)
{
  string url;
  if(!id) return 0;

  string new_raw;
  int delimiter;
  if((delimiter = search(id->raw, "\n\n"))>=0)
    new_raw = id->raw[..delimiter-1];
  else
    new_raw = id->raw;

  new_raw = replace(new_raw, "\n", "\r\n")+"\r\n\r\n"+id->data;

  if(is_remote) return new_raw;
  
  url=id->raw_url[strlen(QUERY(mountpoint))..];
  while(url[0]=='/')              url=url[1..];
  if(!sscanf(url, "%*s/%s", url)) url="";

  return sprintf("%s /%s HTTP/1.0\r\n%s", id->method || "GET", 
		 url, new_raw[search(new_raw, "\n")+1..]);
}

class Connection {
  import Array;

  object cache, pipe, proxy, from;
  array ids;
  string name;
  array my_clients = ({ });

  void log(string what) 
  {
    proxy->log(name, what);
  }
  
  int cache_wanted(object id)
  {
    if(!id || (((id->method == "POST") || (id->query && strlen(id->query)))
	       || id->auth
	       || (!proxy->query("cache_cookies") && sizeof(id->cookies))
	       || proxy->no_cache_for(id->not_query)))
      return 0;
    return 1;
  }
  
  string hostname(string s)
  {
    return roxen->quick_ip_to_host(s);
  }

  int new;
  array stat;
  
  void my_pipe_done(object cache)
  {
    object id;
    array b;
    int received, i;
    
    if(cache)
    {
      if(catch {
	b = cache->file->stat();
	received = 1;
      }) {
	cache->file = 0;
      }
      if(cache->done_callback) {
	cache->done_callback(cache);
      }
    } else if(from) {
      if (catch(b=from->stat()) && stat) {
	// Used cached stat info.
	b = stat;
      }
      destruct(from);
    }
    
    if(b) 
      log(b[1]+" "+ (new?"New ":"Cache ") + 
	  map(my_clients,hostname)*",");
    else  
      log("- " + (new?"New ":"Cache ") + 
	  map(my_clients, hostname)*",");
    
    if(ids) 
      foreach(ids, id) 
	if(id)
	{
	  if(b) id->conf->sent += b[1];
	  if(received) {
	    id->conf->received += b[1];
	    received = 0;
	  }
	  id->end();
	} 
    destruct();
  }

  void assign(object s, string f, object i, int no_cache, object prox)
  {
    new = !no_cache;

    if(no_cache && !i) 
    { 
      destruct(); 
      return; 
    }

    from = s;
    //    proxy = previous_object(); 
    // Sometimes this was roxen, which caused.. problems. =)
    proxy = prox;
    name = f;
    my_clients = ({ i->remoteaddr });
    ids = ({ i });

    /* The convenience function (shuffle) is used to do the actual
     * transport. The callback has to be used to log the size of
     * new incoming connections.
     */
    if(!no_cache && (!i || cache_wanted(i)))
    {
      if(cache = roxen->create_cache_file("http", f))
      {
	cache->done_callback = roxen->http_check_cache_file;
	/* For fresh incoming cachefiles we have two pipe outputs
	 * where the order in which they are given to the fallback
	 * pipe->output in the global shuffle function is relevant.
	 */
	roxen->shuffle(s, cache->file, i->my_fd,
		       lambda(){my_pipe_done(cache);});
	return;
      }
    }
    /* If the fallback is used in the global shuffle function with cached
     * files the actual file is closed when my_pipe_done is reached.
     * With the following stat workaround the size can be logged.
     */
    if(!new){
      stat = s->stat();
    }
    roxen->shuffle(s, i->my_fd, 0, lambda(){my_pipe_done(0);});
  }
    
  int send_to(object o, object b)
  {
    string s;
    if(!objectp(pipe))
      return 0;
    if(catch((s=o->query_address()))||!s)
    {
      b->end("Aj.\n");
      return 0;
    } else {
      pipe->output(o);
      my_clients += ({ (s / " ")[0] });
      ids += ({ b });
      return 1;
    }
  }
    
  string status()
  {
    return "Sending to "+map(my_clients, hostname)*",";
  }
  
  void end()
  {
    object id;
    foreach(ids, id) 
      if(id) 
	id->end( "Connection Interrupted.\n" );
    destruct();
  }
};

void connected_to_server(object o, string file, object id, int is_remote,
			 string filter)
{
  object new_request;
  if(!id)
  {
    if(o)
      destruct(o);
    return;
  }
    
  if(!objectp(o))
  {
    switch(o)
    {
     default:
      id->end(CONNECTION_REFUSED("Unknown host "+(id->misc->proxyhost || "")));
    }
    return;
  }

#ifdef PROXY_DEBUG
  perror("PROXY: Connected.\n");
#endif

  new_request=Connection();

  if(o->query_address())
  {
    string to_send;
    to_send = process_request(id, is_remote);
    if(!to_send)
    {
      id->end("");  
      destruct(new_request);
      return;
    }
    o->write(to_send);
    string cmd;
    if(filter)
    {
      object f, q;
      f=File();
      q=f->pipe();
      o->set_blocking();
      spawne((filter/" ")[0], (filter/" ")[1..], ([ ]), o, q, stderr);
      destruct(o);
      destruct(q);
      o=f;
    }
    new_request->assign(o, file, id, 0, this_object());

// What is the last test for???? /Per
  } else if(!objectp(o) || !o->stat() || (o->stat()[1] == -4)) { 
    id->end(CONNECTION_REFUSED("Connection refused by remote host."));
    return;
  } else {
    if(id->since)
    {
      if(is_modified(id->since, ((array(int))o->stat())[3]))
      {
	id->end("HTTP/1.0 304 Not Modified\r\n\r\n");
	destruct(new_request);
	return;
      }
    }
    new_request->assign(o, file, id, 1, this_object());
  }
  if(objectp(new_request)) 
    requests[new_request] = file;
}



array is_remote_proxy(string hmm)
{
  array tmp;
  foreach(proxies, tmp) if(tmp[0](hmm))
    if(tmp[1][0]!="no_proxy")
      return tmp[1];
    else
      return 0;
}

string is_filter(string hmm)
{
  array tmp;
  foreach(filters, tmp) if(tmp[0](hmm)) return tmp[1];
}

mapping find_file( string f, object id )
{
  string host, file, key;
  string filter;
  array more;
  int port;
  mixed tmp;

#ifdef PROXY_DEBUG
  perror("PROXY: Request for "+f+"\n");
#endif
  f=id->raw_url[strlen(QUERY(mountpoint))+1 .. ];

  if(sscanf(f, "%[^:/]:%d/%s", host, port, file) < 2)
  {
    if(sscanf(f, "%[^/]/%s", host, file) < 2)
    {
      if(search(f, "/") == -1)
      {
	host=f;
	file="";
      } else {
	report_debug("I cannot find a hostname and a filename in "+f+"\n");
	return 0; /* This is not a proxy request. */
      }
    }
    port=80; /* Default */
  }
  host = lower_case(host);
  sscanf(host, "%*s@%s", host);
  id->misc->proxyhost = host; // Used if the host is unknown.
  if(tmp = proxy_auth_needed(id))
    return tmp;

  if(!file) file="";

  if(filter = is_filter(key = host+":"+port+"/"+file))
    perror("Proxy: Filter is "+filter+"\n");

//  perror("key = "+key+"\n");

  id->do_not_disconnect = 1;  
  if(id->pragma["no-cache"] || id->method != "GET")
  {
    if(more = is_remote_proxy(host))
      async_connect(more[0], more[1], connected_to_server,  key, id, 1,
		    filter);
    else
      async_connect(host, port, connected_to_server,  key, id, 0, filter);
  } else {
    if(more = is_remote_proxy(host))
      async_cache_connect(more[0], more[1], "http", key, connected_to_server,
			  key, id, 1, filter);
    else
      async_cache_connect(host, port, "http", key, connected_to_server,
			  key, id, 0, filter);
  }
  return http_pipe_in_progress();
}

string comment() { return QUERY(mountpoint); }
