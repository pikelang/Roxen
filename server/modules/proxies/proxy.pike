// This is a roxen module. Copyright © 1996 - 1998, Idonex AB.

// HTTP Proxy module. Should be cleaned and optimized. Currently the
// limit of proxy connections/second is somewhere around 70% of normal
// requests, but there is no real reason for them to take longer.

string cvs_version = "$Id: proxy.pike,v 1.34 1999/03/05 02:05:47 grubba Exp $";
constant thread_safe = 1;

#include <module.h>
#include <config.h>
#include <stat.h>

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
<font size=-2><a href=http://www.roxen.com/>Roxen Challenger</a>\
 at <a href="+id->conf->query("MyWorldLocation")+">"+id->conf->query("MyWorldLocation")+"</a></font>"

import Stdio;
import Array;

inherit "module";
inherit "socket";
inherit "roxenlib";

#include <proxyauth.pike>
#include <roxen.h>

program filep = Stdio.File;

mapping (object:string) requests = ([ ]);
mapping retcodes = ([ "cache":([]), "new":([]) ]);

#ifdef THREADS
object mutex  = Thread.Mutex();
#define RETCODE_NEW(X) {object key = mutex?mutex->lock():0;retcodes->new[X]++;key=0;}
#define RETCODE_CACHE(X) {object key = mutex?mutex->lock():0;retcodes->cache[X]++;key=0;}
#else
#define RETCODE_NEW(X) retcodes->new[X]++;
#define RETCODE_CACHE(X) retcodes->cache[X]++;
#endif
object logfile;

function nf=lambda(){};

void init_proxies();

void do_timeout();

function (string:int) no_cache_for;

void start()
{
  string pos;
  pos=QUERY(mountpoint);
  init_proxies();
  do_timeout();
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
    logfile=open(QUERY(logfile), "wac");
  }
}

void do_write(string host, string oh, string id, string more)
{
#ifdef PROXY_DEBUG
  roxen_perror(sprintf("PROXY: do_write(\"%O\",\"%s\",\"%s\",\"%s\")\n",
		       host, oh, id, more));
#endif /* PROXY_DEBUG */
  if(!host)     host=oh;
  logfile->write("[" + cern_http_date(time(1)) + "] http://" +
		 host + ":" + id + "\t" + more + "\n");
}

void log(string file, string more)
{
  string host, rest;

#ifdef PROXY_DEBUG
  roxen_perror(sprintf("PROXY: log(\"%s\",\"%s\")\n", file, more));
#endif /* PROXY_DEBUG */
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

void do_timeout(int|void timeout)
{
  if(!query("browser_timeout")&&!query("server_timeout"))
    return;
  if(!timeout){
    if(!query("server_continue"))
      timeout=300;
    if(query("browser_timeout"))
      timeout=min(timeout,(int)query("browser_timeout"));
    if(query("server_timeout"))
      timeout=min(timeout,(int)query("server_timeout"));
    if(!timeout)
      return;
//#ifdef PROXY_DEBUG
    report_debug("PROXY: checking requests every "+timeout+"seconds\n");
//#endif
  }
  gc();
  foreach(indices(requests), object foo)
    if(objectp(foo))
      foo->check_timed_out();
  call_out(do_timeout, timeout, timeout);
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

  defvar("reload_from_cache", 0, "Handle reloads from diskcache", TYPE_FLAG|VAR_MORE,
	 "This option disables the no-cache pragma and reloads will be done "
	 "from the proxy's diskcache. "
	 "Note that with this option set there is no way the client can "
	 "initiate a reload from the original server to the diskcache of "
	 "this proxy. "
	 "Thus documents will be cached forever unless expired (via an expire "
	 "header). "
	 "Please consider this option only if you have installed other means "
	 "to force reload of pages.");

  defvar("modified_from_cache", 0, "Handle if-modified-since from diskcache", TYPE_FLAG|VAR_MORE,
	 "With this option set if-modified-since requests will be checked "
	 "against the proxy's diskcache. "
	 "This can be a major improvement to proxy response times if there are "
	 "many clients with local cache and uptodate checks set to every time. "
	 "Set to \"No\" if requests should go to the original server. ");

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
	 "Please note that this <b>must</b> be "
	 "<a href=$configurl/regexp.html>Regular Expressions</a>.");

  defvar("browser_timeout", 86400, "Connection To Browser Timeout",
         TYPE_INT|VAR_MORE,
	 "Time in seconds after which a browser connection will "
	 "be terminated. Set to zero if you do not want timeout checks.");

  defvar("server_timeout", 86400, "Connection To Server Timeout",
         TYPE_INT|VAR_MORE,
	 "Time in seconds after which a server connection will "
	 "be terminated. Set to zero if you do not want timeout checks.");

  defvar("server_idle_timeout", 3600, "Connection To Server Idle Timeout",
         TYPE_INT|VAR_MORE,
	 "Time in seconds after which an idle caching server connection will "
	 "be terminated. Set to zero if you do not want idle timeout checks.");

  defvar("server_continue", 1, "Continue Server Connection",
         TYPE_FLAG|VAR_MORE,
	 "If this option is set a caching server connection will be continued "
	 "even if the requesting browser connection vanished. "
	 "If a high loaded proxy regularly runs out of sockets unsetting this "
	 "option might help a bit.");

  defvar("additional_output", 0, "Allow additional output",
         TYPE_FLAG|VAR_MORE,
	 "If this option is set a caching server connection will be used "
	 "for additional requests to the same URL. "
	 "Note that this might be a problem with broken or frozen server "
	 "connections. "
	 "It should probably only used together with \"Timeout Server "
	 "Connection\" set to an appropriate value.");
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

  string new_raw = replace(id->raw, "\r\n", "\n");
  int delimiter;
  if((delimiter = search(new_raw, "\n\n"))>=0)
    new_raw = new_raw[..delimiter-1];

  new_raw = replace(new_raw, "\n", "\r\n")+"\r\n\r\n"+(id->data||"");

  if(is_remote) return new_raw;
  
  // Strip command.
  if((delimiter = search(new_raw, "\n")) >= 0)
    new_raw = new_raw[delimiter+1..];

  url=id->raw_url[strlen(QUERY(mountpoint))..];
  sscanf(url, "%*[/]%s", url);	// Strip initial '/''s.
  if(!sscanf(url, "%*s/%s", url)) url="";

  return sprintf("%s /%s HTTP/1.0\r\n%s", id->method || "GET", 
		 url, new_raw);
}

int cache_wanted(object id)
{
  if(!id || (((id->method == "POST") || (id->query && strlen(id->query)))
             || id->auth
             || (!query("cache_cookies") && sizeof(id->cookies))
             || no_cache_for(id->not_query)))
    return 0;
  return 1;
}

class Connection {
  import Array;

  object cache, pipe, proxy, from;
  int connect_time;
  array ids;
  string name;
  array my_clients = ({ });
  int cached_retcode;

  void log(string what) 
  {
    catch(proxy->log(name, what));
  }
  
  string hostname(string s)
  {
    return roxen->quick_ip_to_host(s);
  }

  int new;
  
  void my_pipe_done()
  {
    object id;
    array b;
    int received, sent;
    catch{
      sent = pipe->bytes_sent();
    };

    if(cache){
      if(catch {
	received = cache->file->stat()[ST_SIZE];
      }) {
	cache->file = 0;
      }
      if(cache->done_callback) {
	cache->done_callback(cache);
      }
    }

    string result = sent?sent+" ":"- ";
    if(cache){
      result += "New"+" "+cache->headers[" returncode"];
      RETCODE_NEW(cache->headers[" returncode"]);
    } else if(new){
      result += "New -";
      RETCODE_NEW("?");
    } else {
      result += "Cache "+cached_retcode;
      RETCODE_CACHE(cached_retcode);
    }
    log(result + " " + map(my_clients,hostname)*",");

    if(cache)

    if(ids) 
      foreach(ids, id) 
	if(id)
	{
	  if(b) id->conf->sent += sent;
	  if(received) {
	    id->conf->received += received;
	    received = 0;
	  }
	  id->end();
	}
    destruct();
  }

  void check_timed_out()
  {
    string ret;
    int has_server=1, has_browser=0;
    if(!from||catch(ret=from->query_address())||!ret){
      //report_debug("PROXY: no server connection: "+name+"\n");
      has_server=0;
    }
    /*
    if(!objectp(pipe)){
      report_debug("PROXY: no server pipe: "+name+"\n");
      destruct();
      return;
    }
    */
    if(query("server_timeout")&&connect_time>0&&
       (time()-connect_time)>(int)query("server_timeout")){
      report_debug("PROXY: server connection timed out ("+
                   (time()-connect_time)+"s): "+name+"\n");
      if(from)destruct(from);
      return;
    }
    foreach(ids, object id){
      if(!objectp(id))
	continue;
/*
      if(catch(ret=id->my_fd->query_address())||!ret){
	report_debug("PROXY: no browser connection : "+name+"\n");
	if(id)
          id->end();
        continue;
      }
 */
      if(query("browser_timeout")&&
	 (time()-id->time)>(int)query("browser_timeout")){
	report_debug("PROXY: browser connection timed out ("+
                     (time()-id->time)+"s): "+name+"\n");
	if(id)
	  id->end( "Proxy Connection timed out.\n" );

        continue;
      }
      has_browser = 1;
    }
    if(!has_browser){
      if(!has_server){
        report_debug("PROXY: no browser/server connections: "+name+"\n");
        destruct();
        return;
      }
      if(new&&!cache){
        report_debug("PROXY: no browser/cache connections: "+name+"\n");
	if(from)
	  destruct(from);
        return;
      }
      if(!query("server_continue")){
        report_debug("PROXY: no browser connections: "+name+"\n");
        if(from)
          destruct(from);
        return;
      }
    }
  }

  void continue_server_connection(void|int timeout)
  {
    if(!timeout){
      timeout = 30;
      return;
    }
    if(query("server_continue") || !query("server_idle_timeout"))
      return;
    if(!from||!from->query_address()||!objectp(pipe))
      return;
    int ok_to_terminate;
    if(query("server_idle_timeout") && cache &&
       (time()-cache->file->stat()[ST_MTIME])>(int)query("server_idle_timeout"))
      ok_to_terminate=1;

    if(!ok_to_terminate)
      foreach(ids, object id){
#ifdef PROXY_DEBUG
        if(id)
	  report_debug("id "+roxen->quick_ip_to_host(id->remoteaddr)+"\n");
        if(id && id->my_fd)
	  report_debug("id->my_fd "+roxen->quick_ip_to_host(id->remoteaddr)+"\n");
        if(id && id->my_fd && id->my_fd->query_address())
	  report_debug("id->query "+roxen->quick_ip_to_host(id->remoteaddr)+"\n");
#endif
        if(!id || !id->my_fd || !id->my_fd->query_address()){
	  ok_to_terminate=2;
	  break;
        }
      }
    if(!ok_to_terminate){
      call_out(continue_server_connection, timeout);
      return;
    }
//#ifdef PROXY_DEBUG
    if(ok_to_terminate==1)
      report_debug("PROXY: server connection is "+
		   (time()-cache->file->stat()[ST_MTIME])+"s idle for "+
		   name+"\n");
    if(ok_to_terminate==2)
      report_debug("PROXY: server connection not present for "+name+"\n");
//#endif
    if(objectp(pipe)){
      pipe->finish();
//#ifdef PROXY_DEBUG
      report_debug("PROXY: server connection pipe finished for "+name+"\n");
//#endif
    }
  }

  void assign(object s, string f, object i, int no_cache)
  {
    new = !no_cache;

    if(no_cache && !i) 
    { 
      destruct(); 
      return; 
    }

    connect_time = time();
    from = s;
    name = f;
    my_clients = ({ i->remoteaddr });
    ids = ({ i });

    if(!no_cache && (!i || proxy->cache_wanted(i))){
      if(cache = roxen->create_cache_file("http", f)){
        cache->done_callback = roxen->http_check_cache_file;
        pipe = roxen->shuffle(s, cache->file, i->my_fd,
			      lambda(){my_pipe_done();});
        continue_server_connection();
	return;
      }
    }
    pipe = roxen->shuffle(s, i->my_fd, 0, lambda(){my_pipe_done();});
  }

  string status()
  {
    return "Sending to "+map(my_clients, hostname)*",";
  }

  void destroy()
  {
    if(cache)
      remove_call_out(continue_server_connection);

    if(from)
      destruct(from);

    if(ids)
      foreach(ids, object id)
	if(id){
	  id->end( "Connection Interrupted.\n" );
#ifdef PROXY_DEBUG
          report_debug("PROXY: connection interrupted ("+name+")\n");
#endif
	}

    if(cache)
      destruct(cache);
  }
};

private void cache_connect(string host, int port, string cl,
                                 string entry, function callback,
                                 mixed ... args)
{
  object cache;
#ifdef PROXY_DEBUG
  report_debug("PROXY: cache_connect requested to "+host+":"+port+"\n");
#endif
  cache = roxen->cache_file(cl, entry);
  if(cache)
  {
    object f;
    f=cache->file;
    return callback(f, cache, @args);
  }
  async_connect(host, port, callback, 0, @args);
}

constant MONTHS= (["jan":0, "feb":1, "mar":2, "apr":3, "may":4, "jun":5,
		   "jul":6, "aug":7, "sep":8, "oct":9, "nov":10, "dec":11,]);

private int convert_time(string a)
{
  int day, year, month, hour, minute, second, i;
  string m, tz;
  if((i=sscanf(a, "%d%*[ -]%s%*[ -]%d %d:%d:%d %s", day, m, year, hour, minute, second, tz))!=9){
//#ifdef PROXY_DEBUG
    report_debug("PROXY: time format not handled: "+a+", matched="+i+"\n");
//#endif
    return -1;
  }
  if(year>1900)
    year -= 1900;
  month=MONTHS[lower_case(m)];
  if(tz != "GMT"){
//#ifdef PROXY_DEBUG
    report_debug("PROXY: timezone ("+tz+") not handled\n");
//#endif
    return -1;
  }
  if (catch(i=mktime(second, minute, hour, day, month, year, 0, 0))){
#ifdef PROXY_DEBUG
    report_debug("PROXY: mktime could not convert: "+a+"("+second+","+minute
		 +","+hour+","+day+","+ month+","+year+","+0+","+0+")\n");
#endif
    return -1;
  }
  return i;
}

int newer(string modified, string since)
{
 int modified_t, since_t;

 sscanf(since, "%*s, %s; %*s", since);
 sscanf(modified, "%*s, %s", modified);
 if(((modified_t=convert_time(modified))<0)||
    ((since_t=convert_time(since))<0)||
    modified_t>since_t)
   return 1;
 return 0;
}

void connected_to_server(object o, object cache, string file, object id, int is_remote,
			 string filter)
{
  id->do_not_disconnect = 0;

  object new_request;
  if(!id)
  {
    if(o)
      destruct(o);
    if(cache)
      destruct(cache);
    return;
  }
    
  if(!objectp(o))
  {
    switch(o)
    {
     default:
      log(file, "UnknownHost 500 "+roxen->quick_ip_to_host(id->remoteaddr));
      id->end(CONNECTION_REFUSED("Unknown host "+(id->misc->proxyhost || "")));
      RETCODE_NEW(500)
    }
    if(cache)
      destruct(cache);
    return;
  }

#ifdef PROXY_DEBUG
  perror("PROXY: Connected.\n");
#endif

  new_request=Connection();
  new_request->proxy = this_object();

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
    new_request->assign(o, file, id, 0);

// What is the last test for???? /Per
  } else if(!objectp(o) || !o->stat() || (o->stat()[ST_SIZE] == -4)) { 
    if(is_remote){
      log(file, "New 500 "+roxen->quick_ip_to_host(id->remoteaddr));
      id->end(CONNECTION_REFUSED("Connection refused by remote proxy."));
      RETCODE_NEW(500)
    } else {
      log(file, "New 500 "+roxen->quick_ip_to_host(id->remoteaddr));
      id->end(CONNECTION_REFUSED("Connection refused by remote host."));
      RETCODE_NEW(500)
    }
    destruct(new_request);
    if(objectp(o))
      destruct(o);
    return;
  } else {
    if(query("modified_from_cache") && id->since &&
       cache->headers["last-modified"] &&
       !newer(cache->headers["last-modified"], id->since))
    {
      // FIX ME: this should not be necessary /wk
      id->do_not_disconnect = 1;

      id->end("HTTP/1.0 304 Not Modified\r\n\r\n");
      log(file, "- Cache 304 "+roxen->quick_ip_to_host(id->remoteaddr));
      RETCODE_CACHE(304)
      destruct(new_request);
      destruct(cache);
      destruct(o);
      return;
    }
    new_request->cached_retcode = cache->headers[" returncode"];
    cache->file = 0; // do _not_ close the actual file when returning...
    destruct(cache);

    new_request->assign(o, file, id, 1);
  }
  if(objectp(new_request)){
#ifdef THREADS
    object key = mutex?mutex->lock():0;
#endif
    requests[new_request] = file;
  }
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
#ifdef PROXY_DEBUG
	report_debug("I cannot find a hostname and a filename in "+f+"\n");
#endif
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

  if(filter = is_filter(key = host+":"+port+"/"+file)){
#ifdef PROXY_DEBUG
    perror("Proxy: Filter is "+filter+"\n");
#endif
  }

  id->do_not_disconnect = 1;

  if((id->pragma["no-cache"] && !query("reload_from_cache")) ||
     !cache_wanted(id) ||
     (id->method != "GET" && id->method != "HEAD") ) {
    if(more = is_remote_proxy(host))
      async_connect(more[0], more[1], connected_to_server, 0, key, id, 1,
		    filter);
    else
      async_connect(host, port, connected_to_server, 0, key, id, 0, filter);
  } else {
    object request;
    if(query("additional_output") && !id->since && !filter &&
       sizeof(requests) && (request=search(requests, key)) &&
       request->pipe && request->cache){
      id->do_not_disconnect = 0;
      request->pipe->output(id->my_fd, request->cache->headers->head_size);
      { // lock this range
#ifdef THREADS
        object range = mutex?mutex->lock():0;
#endif
        request->ids += ({ id });
        request->my_clients += ({ id->remoteaddr });
      }
//#ifdef PROXY_DEBUG
      report_debug("PROXY: another request for "+key+" from "+
	     roxen->quick_ip_to_host(id->remoteaddr)+"\n");
//#endif

      return http_pipe_in_progress();
    }

    if(more = is_remote_proxy(host))
      cache_connect(more[0], more[1], "http", key, connected_to_server,
			  key, id, 1, filter);
    else
      cache_connect(host, port, "http", key, connected_to_server,
			  key, id, 0, filter);
  }
  return http_pipe_in_progress();
}

string comment() { return QUERY(mountpoint); }
