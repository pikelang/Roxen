// This is a roxen module. Copyright © 1996 - 1998, Idonex AB.

// HTTP Proxy module. Should be cleaned and optimized. Currently the
// limit of proxy connections/second is somewhere around 70% of normal
// requests, but there is no real reason for them to take longer.

constant cvs_version = "$Id: proxy.pike,v 1.36 1999/04/07 18:55:59 peter Exp $";
constant thread_safe = 1;

#include <module.h>
#include <config.h>
#include <stat.h>

#if DEBUG_LEVEL > 21
# ifndef PROXY_DEBUG
#  define PROXY_DEBUG
# endif
#endif

import Array;

inherit "module";
inherit "roxenlib";

#include <proxyauth.pike>
#include <roxen.h>

mapping (object:string) requests = ([]);
mapping stats = ([ "http": ([ "cache":([]), "new":([]) ]),
                   "length": ([ "cache":([]), "new":([]) ]) ]);

#ifdef THREADS
object requests_mutex = Thread.Mutex();
object stats_mutex = Thread.Mutex();
#endif

object logfile;

function nf=lambda(){};

void init_proxies();

void do_timeout(int|void timeout);

function (string:int) no_cache_for;

mapping (int:int) http_codes_to_cache = ([]);
void start()
{
  string pos;
  pos=QUERY(mountpoint);
  init_proxies();
  do_timeout(600);
  if(strlen(pos)>2 && (pos[-1] == pos[-2]) && pos[-1] == '/')
    set("mountpoint", pos[0..strlen(pos)-2]); // Evil me..

  if(strlen(QUERY(NoCacheFor)))
    if(catch(no_cache_for = Regexp("("+(QUERY(NoCacheFor)-"\r"-"\n\n")/"\n"*")|("
				   +")")->match))
      report_error("Parse error in 'No cache' regular expression.\n");

  if(!no_cache_for) no_cache_for = lambda(string i){return 0;};

  http_codes_to_cache = ([]);
  if(strlen(QUERY(HttpcodesToCache)))
    foreach(QUERY(HttpcodesToCache), string s)
      if(!(int)s)
	report_error("PROXY: illegal httpcode "+s+" ignored.\n");
      else
	http_codes_to_cache[(int)s] = 1;

  if(logfile) 
    destruct(logfile);

  if(!strlen(QUERY(logfile)))
    return;

#ifdef PROXY_DEBUG
  perror("Proxy online.\n");
#endif

  if(QUERY(logfile) == "stdout")
  {
    logfile=Stdio.stdout;
  } else if(QUERY(logfile) == "stderr"){
    logfile=Stdio.stderr;
  } else {
    logfile=open(QUERY(logfile), "wac");
  }
}

void do_write(string host, string oh, string more)
{
  logfile->write(more + (host?host:oh) + "\n");
}

#define MY_TIME(X) sprintf("%s%d:%d", (X)>(60*60)?(X)/(60*60)+":":"",\
			     (X)%(60*60)/60, (X)%60)
void log_client(string host, string oh, string id, string more, string client, int _time)
{
  more = "[" + cern_http_date(time(1)) + "] http://" + (host?host:oh) + ":" +
         id + " " + more + " " + MY_TIME(_time) + " ";
  if(query("log_client_resolved"))
    roxen->ip_to_host(client, do_write, client, more);
  else
    logfile->write(more + roxen->quick_ip_to_host(client) + "\n");
}

void log(string file, int sent, string mode, int http_code, string client,
	 int _time)
{
  if(logfile){
    string more = sent + " " + mode + " " + http_code + " ";
    string host, rest;
    sscanf(file, "%s:%s", host, rest);
    roxen->ip_to_host(host, log_client, host, rest, more, client, _time);
  }
  if(query("online_stats")){
    string cache_new = "new";
    if(search(mode, "Disk") != -1)
      cache_new = "cache";

    /*
     first range for length stats is 256 bytes
     further ranges are power of 2
     */
    int sent_msb, sent_i = sent>>8;
    for(sent_msb=0;sent_i;sent_msb++)
      sent_i>>=1;

#ifdef THREADS
    object key = stats_mutex?stats_mutex->lock():0;
#endif
    stats->http[cache_new][http_code]++;
    stats->length[cache_new][sent_msb]++;
  }
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

void do_timeout(int|void timeout)
{
  if(!query("browser_timeout") && !query("server_timeout") &&
     !query("server_idle_timeout"))
    timeout = 600;
  else {
    gc();
    foreach(indices(requests), object foo)
      if(objectp(foo))
        foo->check_timed_out();
    timeout=300;
  }
  call_out(do_timeout, timeout, timeout);
}

void create()
{         
  defvar("logfile", "", "Logfile", TYPE_FILE,
	 "Empty the field for no log at all");
  
  defvar("log_client_resolved", 1, "Log Resolved Client Hostnames",
         TYPE_FLAG|VAR_MORE,
	 "Set this option to zero if only already resolved hostnames "
	 "should be logged (from hosts cache).");

  defvar("online_stats", 0, "Online Stats",
         TYPE_FLAG|VAR_MORE,
	 "Set this option to enable online statistics as e.g. HTTP returncodes "
	 "and length of proxy connections, see Actions->Status->Proxy. "
	 "Note that this will result in an additional load of about 3% of "
	 "the proxy load.");

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

  defvar("HttpcodesToCache", ({ "200", "300", "301", "302", "404" }),
	 "Httpcodes To Cache", TYPE_STRING_LIST|VAR_MORE,
	 "Cache documents with these codes to disk cache (if enabled).");

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

/* nothing yet
  defvar("filesize_disk_max", 32, "Filesize Maximum for Disk Cache",
         TYPE_INT_LIST|VAR_MORE,
	 "Cache files to disk upto this size (mb). "
	 "Set to zero for unlimited.",
	 ({ 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024 }));
 */
  defvar("filesize_memory_max", 16, "Filesize Maximum for Memory Cache",
         TYPE_INT_LIST|VAR_MORE,
	 "While caching keep files in memory upto this size (kb).",
	 ({ 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024 }));

  defvar("browser_keepalive", 1, "Browser Keep Alive",
         TYPE_FLAG|VAR_MORE,
	 "Try keep browser connection active by enabling the periodic "
	 "transmission of messages on the browser socket. ");

  defvar("browser_timeout", 0, "Browser Timeout",
         TYPE_INT|VAR_MORE,
	 "Time in seconds after which a browser connection will "
	 "be terminated. Set to zero if you do not want timeout checks.");

  defvar("browser_idle_timeout", 0, "Browser Idle Timeout",
         TYPE_INT|VAR_MORE,
	 "Time in seconds after which an idle browser connection will "
	 "be terminated. Set to zero if you do not want idle timeout checks.");

  defvar("server_timeout", 0, "Server Timeout",
         TYPE_INT|VAR_MORE,
	 "Time in seconds after which a server connection will "
	 "be terminated. Set to zero if you do not want timeout checks.");

  defvar("server_idle_timeout", 0, "Server Idle Timeout",
         TYPE_INT|VAR_MORE,
	 "Time in seconds after which an idle server connection will "
	 "be terminated. Set to zero if you do not want idle timeout checks.");

  defvar("server_continue", 1, "Server Continue",
         TYPE_FLAG|VAR_MORE,
	 "If this option is set a caching server connection will be continued "
	 "even if the requesting browser connection vanished. "
	 "If a high loaded proxy regularly runs out of sockets unsetting this "
	 "option might help a bit.");

  defvar("server_keepalive", 1, "Server Keep Alive",
         TYPE_FLAG|VAR_MORE,
	 "Try keeps server connection active by enabling the periodic "
	 "transmission of messages on the server socket.");

  defvar("server_additional_output", 0, "Server Additional Output",
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

  if(sizeof(requests))
  {
    res += "<hr><h1>Current connections</h1><p>";
    foreach( indices(requests), object request)
      if(request)
       res += requests[request] + ": " + request->status() + "\n";
  }
  res += "<hr>";
 return ("<pre><font size=+1>"+res+"</font></pre>");
}

mapping find_file( string f, object id )
{
  string host, file, key;
  string filter;
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
  if(tmp = proxy_auth_needed(id))
    return tmp;
  if(!file) file="";

  id->do_not_disconnect = 1;
  Request(id, this_object(), host, port, file);
  return http_pipe_in_progress();
}

#define PROXY_DEBUG
#ifdef PROXY_DEBUG
#define SERVER_DEBUG(X) report_debug("PROXY: Server "+(X)+" for "+name+".\n");
#else
#define SERVER_DEBUG(X)
#endif

#define MODE(X) { _mode = (X);\
		  foreach(clients, object client)\
		   if(client)client->_mode = (X);}
class Server {
  object conf, proxy, to_disk, to_disk_pipe, from_server;

  string name = "", _remoteaddr = "", _data = "", _mode = "Server", proxyhost;
  string filter;

  int no_clients, _received, cache_is_wanted, _http_code, _start, _last_got;
  int _done_done;

  array clients = ({});
#ifdef THREADS
object clients_mutex = Thread.Mutex();
#endif

  array remote;
  mapping headers;

  static private void parse_headers(int p)
  {
    headers = ([]);
    string h = _data[..p-1], _name, value;
    sscanf(h, "%s\n", headers["_code"]);
    foreach((h-"\r")/"\n", string line)
      if(sscanf(line, "%s:%s", _name, value) == 2){
	sscanf(value, "%*[ \t]%s", value);
	headers[lower_case(_name-" ")] = value;
      }
    sscanf(upper_case(headers["_code"]), "HTTP/%*s %d", _http_code);
    if(_http_code <= 0)
    {
      SERVER_DEBUG("parse_headers - invalid http_code("+_http_code+") in "+
		    _data[..p-1]);
      return;
    }
    foreach(clients, object client)
      if(client)
	client->http_code(_http_code);
  }

  void remove_client(object client)
  {
    //SERVER_DEBUG("remove_client")

#ifdef THREADS
    object key = clients_mutex?clients_mutex->lock():0;
#endif

    clients -= ({ client });

#ifdef THREADS
    key = 0;
#endif
  }

  int add_client(object client)
  {
    //SERVER_DEBUG("add_client")

    // not implemented yet
    if(to_disk)
      return 0;

#ifdef THREADS
    object key = clients_mutex?clients_mutex->lock():0;
#endif

    if(sizeof(clients))
      clients += ({ client });
    else
      clients = ({ client });
    no_clients++;

#ifdef THREADS
    key = 0;
#endif

    client->server = this_object();

    if(_data)
    {
      client->_mode = _mode;
      client->_http_code = _http_code;
      _got(0, "");
      return 1;
    }

    remove_client(client);
    return 0;
  }

  static private void _got(mixed foo, string d)
  {
    //SERVER_DEBUG("_got("+d+")");

    _last_got = time();

    if(_data)
      _data += d;

    if(conf)
      conf->received += strlen(d);

    // parse header if complete
    if(!headers){
      if(!strlen(d))
        return;

      int p;
      if(((p = search(_data, "\r\n\r\n"))!=-1)||
         ((p = search(_data, "\n\r\n\r"))!=-1))
        parse_headers(p+4);
      else if(((p = search(_data, "\r\r"))!=-1)||
              ((p = search(_data, "\n\n"))!=-1))
        parse_headers(p+2);

      // do not send anything before header is complete
      if(!headers)
	return;

      // FIX_ME: add proxy headers
      // if(query("proxy_header_wanted")
      // content-length ?

      if(cache_is_wanted && (!proxy || !proxy->http_codes_to_cache[_http_code]))
      {
	//SERVER_DEBUG("_got - no cache for http_code("+_http_code+")")
	cache_is_wanted = 0;
        if(remote)
          MODE("Remote")
        else
          MODE("Server")
      }
    }

    int active_client;
    foreach(clients, object client)
      if(client)
      {
	// send already cahed data to additional client
	if(!client->_first_sent && headers && _data)
	{
	  client->_first_sent = 1;
	  client->write(_data);
	} else
	  client->write(d);
	// write may have gone client detected
	if(client)
	  active_client = 1;
	else
	  remove_client(client);
      } else
	remove_client(client);
   
    if(!this_object()){
      return;
    }

    if(!active_client && (!proxy || !query("server_continue"))) catch{
      //SERVER_DEBUG("_got - no clients");
      destruct();
      return;
    };

    if(proxy && query("server_timeout")) catch{
      if((int)query("server_timeout")<(time()-_start)){
        //SERVER_DEBUG("_got - timeout");
        finish("Proxy connection to server timed out");
        return;
      }
    };

    if(to_disk)
      to_disk->file->write(d);
    else if(cache_is_wanted &&
	    (!proxy || strlen(_data) > (1024*(int)query("filesize_memory_max"))) &&
            (to_disk = roxen->create_cache_file("http", name)))
    {
      //SERVER_DEBUG("_got("+strlen(_data)+") continuing by disk caching")

      if(remote)
        MODE("RemoteToDisk")
      else
        MODE("ServerToDisk")

      int len;
      while((len = to_disk->file->write(_data)) < strlen(_data))
      {
        if(len < 0)
	{
          //SERVER_DEBUG("_got - write failed")
	  cache_is_wanted = 0;
	  to_disk = 0;
	  _data = 0;
          return;
	}
        //SERVER_DEBUG("_got - short("+len+") write");
	_data = _data[len..];
      }
      _data = 0;
    } else
    {
      //SERVER_DEBUG("_got("+strlen(_data)+") still caching to memory")
    }
  }

  static private void _done()
  {
    //SERVER_DEBUG("_done ("+sizeof(clients)+" clients)");

    if(_done_done){
      SERVER_DEBUG("already _done_done");
      return;
    }

    if(to_disk){
      roxen->http_check_cache_file(to_disk);
      to_disk = 0;
    } else if(cache_is_wanted && strlen(_data)&&
       (to_disk = roxen->create_cache_file("http", name))){
      //SERVER_DEBUG("_done - shuffle to disk")
      if(remote)
        MODE("RemoteToDisk")
      else
        MODE("ServerToDisk")

      to_disk_pipe = roxen->pipe();
      to_disk_pipe->set_done_callback(_done);
      to_disk_pipe->write(_data);
      to_disk_pipe->output(to_disk->file);
      return;
    }

    _done_done = 1;

    finish();
  }

  static private void finish(int|string|void http_or_last_message, string|void s)
  {
    foreach(clients, object client)
      if(client)
	client->finish(http_or_last_message, s);
    clients = 0;

    destruct();
  }

  int idle()
  {
    if(_last_got <= 0)
      return time() - _start;
    return time() - _last_got;
  }

  static private string process_request(object id)
  {
    string url;

    string new_raw = replace(id->raw, "\r\n", "\n");
    int delimiter;
    if((delimiter = search(new_raw, "\n\n"))>=0)
      new_raw = new_raw[..delimiter-1];

    new_raw = replace(new_raw, "\n", "\r\n")+"\r\n\r\n"+(id->data||"");

    if(remote)
      return new_raw;

    // Strip command.
    if((delimiter = search(new_raw, "\n")) >= 0)
      new_raw = new_raw[delimiter+1..];

    url=id->raw_url[strlen(QUERY(mountpoint))..];
    sscanf(url, "%*[/]%s", url);	// Strip initial '/''s.
    if(!sscanf(url, "%*s/%s", url))
      url="";

    return sprintf("%s /%s HTTP/1.0\r\n%s", id->method || "GET", url, new_raw);
  }

  static private array is_remote_proxy(string hmm)
  {
    foreach(proxies, array tmp)
      if(tmp[0](hmm))
	if(tmp[1][0]!="no_proxy")
          return tmp[1];
        else
          return 0;
  }

  static private string is_filter(string hmm)
  {
    foreach(filters, array tmp)
      if(tmp[0](hmm))
        return tmp[1];
  }

  void create(object client, object _proxy, string host, int port, string _name)
  {
    _start = time();

    conf = client->id->conf;
    proxy = _proxy;

    name = _name;
    proxyhost = host + ":" + port;

    _mode = "HostLookup";
    cache_is_wanted = client->cache_is_wanted;
    
    if(filter = is_filter(name)){
      //SERVER_DEBUG("create - Filter is "+filter+"\n");
    }

    if(remote = is_remote_proxy(host)){
      host = remote[0];
      port = remote[1];
    }

    add_client(client);
    roxen->host_to_ip(host, got_hostname, host, port, connected_to_server);
  }

  void destroy()
  {
    if(!this_object())
    {
      return;
    }

    //SERVER_DEBUG("destroy")

    if(clients)
      foreach(clients, object client)
        if(client && client->server)
	  client->server = 0;
    clients = 0;
#ifdef THREADS
    if(clients_mutex)
      clients_mutex = 0;
#endif

    if(headers)
      headers = 0;

    if(remote)
      remote = 0;

    if(from_server){
      from_server->set_read_callback(0);
      from_server->set_close_callback(0);
      from_server = 0;
    }

    if(to_disk)
      to_disk = 0;

    if(to_disk_pipe)
      to_disk_pipe = 0;

    if(proxy)
      proxy = 0;

    if(conf)
      conf = 0;
  }

#define ERROR_MSG(X) "\
HTTP/1.0 500 "+X+"\r\n\
Content-type: text/html\r\n\
\r\n\
<title>Roxen: "+X+"</title>\n\
<h1>Proxy Request Failed</h1>\
<hr>\
<font size=+2><i>"+X+"</i></font>\
<hr>\
<font size=-2>Roxen Challenger\
 at <a href="+conf->query("MyWorldLocation")+">"+\
conf->query("MyWorldLocation")+"</a></font>"

  static private void got_hostname(string host, string oh, int port,
                                   function callback, mixed ... args)
  {
    if(!host)
    {
      //SERVER_DEBUG("got_hostname - no host ("+oh+")")
      finish(500, ERROR_MSG("Unknown host: "+oh));
      return;
    }
    MODE("Connecting")
    from_server = Stdio.File();
    if(from_server->async_connect(host, port, callback, @args))
    {
      //SERVER_DEBUG("got_hostname - async_connect ok")
    } else {
      //SERVER_DEBUG("got_hostname - async_connect failed")
    }
  }

  static private void connected_to_server(int connected)
  {
    if(!connected || !from_server || !from_server->query_address())
    {
      if(remote)
        finish(500, ERROR_MSG("Connection refused by remote proxy: " +
               remote[0] + ":" + remote[1] + "."));
      else
        finish(500, ERROR_MSG("Connection refused by: "+ proxyhost +
	       "."));
      return;
    }

    if(query("server_keepalive") &&
       functionp(from_server->set_keepalive)&&!from_server->set_keepalive(1))
    {
      SERVER_DEBUG("set_keepalive(server) failed");
      if(!from_server || !from_server->query_address())
      {
        finish(500, ERROR_MSG("Connection To Server Vanished"));
	return;
      }
    }

    if(remote)
      MODE("Remote" + (cache_is_wanted?"Caching":""))
    else
      MODE("Server" + (cache_is_wanted?"Caching":""))

    string to_send;
    foreach(clients, object client)
      if(client && client->id){
        to_send = process_request(client->id);
	break;
      }

    if(!to_send)
    {
      finish(500, ERROR_MSG("Request cannot be processed."));
      return;
    }
    if(from_server->write(to_send)<strlen(to_send))
    {
      //SERVER_DEBUG("connected_to_server - write failed")
    }

    string cmd;
    if(filter)
    {
      object f, q;
      f=Stdio.File();
      q=f->pipe();
      from_server->set_blocking();
      spawne((filter/" ")[0], (filter/" ")[1..], ([ ]), from_server, q,
	     Stdio.stderr);
      destruct(from_server);
      destruct(q);
      from_server=f;
    }
 
    from_server->set_read_callback(_got);
    from_server->set_write_callback(0);
    from_server->set_close_callback(_done);
  }
}

#define PROXY_DEBUG
#ifdef PROXY_DEBUG
#define REQUEST_DEBUG(X) report_debug("PROXY: Request("+_remoteaddr+") " +\
  (X) + " for " + name+".\n");
#else
#define REQUEST_DEBUG(X)
#endif

class Request {
  object conf, proxy, id, _fd, server, from_disk;
  string name = "", _remoteaddr = "", cache_file_info;
  int sent, cache_is_wanted, _http_code, remote;
  string _mode = "Proxy", buffer="";
  int _first_sent, _start, _last_send;

  static private void _send()
  {
    _last_send = time();

    // check _fd first ?
    if(!strlen(buffer))
      return;

    if(!_fd || !_fd->query_address())
    {
      //REQUEST_DEBUG("_send - connection vanished")
      destruct();
      return;
    }

    int len = _fd->write(buffer);
    if(len < 0) 
    {
       //REQUEST_DEBUG("_send - write failed")
       return;
    }
    sent += len;
    buffer = buffer[len..];
  }
  
  void write(string data)
  {
    if(!_fd || !_fd->query_address())
    {
      //REQUEST_DEBUG("write - connection vanished")
      destruct();
      return;
    }
    if(!strlen(buffer) && strlen(data)){
      buffer=data;
      _send();
    } else
      buffer += data;
  }

  static private void _done()
  {
    //REQUEST_DEBUG("_done")
    finish();
  }
 
  void finish(int|string|void http_or_last_message, string|void s)
  {
    server = 0;

    // immediate finish with http_code
    if(s && intp(http_or_last_message))
    {
      sent = strlen(s);
      _http_code = http_or_last_message;

      if(id)
        id->end(s);

      call_out(destruct, 0, this_object());
      return;
    }

    // send last message and wait for buffer to empty
    if(stringp(http_or_last_message))
      write("\n\n" + http_or_last_message + "\n\n");

    // wait for buffer to empty
    // FIX_ME: at least this should be a pipe
    if(strlen(buffer)){
      //REQUEST_DEBUG("finish - "+strlen(buffer)+" bytes in buffer")
      if(!_fd || !_fd->query_address())
      {
        REQUEST_DEBUG("finish - connection vanished")
        destruct();
        return;
      }
      call_out(finish, 5);
      return;
    }

    //REQUEST_DEBUG("finish - destructing")
    destruct();
  }

  static private int cache_wanted()
  {
    if(id->method != "GET" ||
       (id->query && strlen(id->query)) ||
       id->auth ||
       (!query("cache_cookies") && sizeof(id->cookies)) ||
       no_cache_for(id->not_query))
      return 0;
    return 1;
  }

  int|void http_code(int|void code)
  {
    if(code)
      _http_code = code;
    return _http_code;
  }

  int idle()
  {
    if(from_disk)
      return 0;

    if(_last_send <= 0)
      return time() - _start;

    return time() - _last_send;
  }

#define FINISH(X) {report_debug(X+" for "+name+"\n");\
                   if(!from_disk)destruct();if(catch(from_disk->finish()))destruct();return;}

  void check_timed_out()
  {
    // does not work
    return;
    // do not check upcoming and short connections
    if((time()-_start)<300)
      return;

    /*
    if(!from_server || !from_server->query_address())
    {
	FINISH("PROXY: no server connection")
    };

    if(query("server_timeout")) catch{
      if((int)query("server_timeout")<(time()-connect_time))
	FINISH("PROXY: server timeout")
    };

    if(query("server_idle_timeout") && to_disk) catch{
      if((time()-to_disk->file->stat()[ST_MTIME])>
	   (int)query("server_idle_timeout"))
        FINISH("PROXY: server_idle_timeout")
    };
    int has_browser;
    foreach(clients, object client){
      if(query("browser_timeout")) catch{
        if((int)query("browser_timeout")<(time()-client->id->time)){
          REQUEST_DEBUG("browser ("+client->id->remoteaddr+") timeout");
	  client->finish("Proxy Connection timed out.\n" );
	  continue;
	}
      };
      catch{
	if(client->id && client->id->my_fd && client->id->my_fd->query_address())
	  has_browser += 1;
      };
    }
    if(!has_browser){
      if(!to_disk)
        FINISH("PROXY: no browser (no cache) connections")
      else if(!query("server_continue"))
        FINISH("PROXY: no browser connections")
    }
    */
  }

  constant MONTHS= (["jan":0, "feb":1, "mar":2, "apr":3, "may":4, "jun":5,
		     "jul":6, "aug":7, "sep":8, "oct":9, "nov":10, "dec":11,]);

  static private int convert_time(string a)
  {
    int day, year, month, hour, minute, second, i;
    string m, tz;
    if((i=sscanf(a, "%d%*[ -]%s%*[ -]%d %d:%d:%d %s", day, m, year, hour, minute, second, tz))!=9){
      REQUEST_DEBUG("time format not handled: "+a+", matched="+i)
      return -1;
    }
    if(year>1900)
      year -= 1900;
    month=MONTHS[lower_case(m)];
    if(tz != "GMT"){
      REQUEST_DEBUG("timezone ("+tz+") not handled")
      return -1;
    }
    if (catch(i=mktime(second, minute, hour, day, month, year, 0, 0))){
      REQUEST_DEBUG("mktime could not convert: "+a+"("+second+","+minute+","+
                    hour+","+day+","+ month+","+year+","+0+","+0+")\n");
      return -1;
    }
    return i;
  }

  static private int modified(string modified, string since)
  {
    int modified_t, since_t;

    if(sscanf(since, "%*s, %s; %*s", since) < 2)
    {
      REQUEST_DEBUG("modified - could not convert since: "+since)
        return 0;
    }

    if(sscanf(modified, "%*s, %s", modified) < 2)
    {
      REQUEST_DEBUG("modified - could not convert modified: "+modified);
      return 0;
    }

    //REQUEST_DEBUG("modified (since="+since+"), modified="+modified+")")
    if(((modified_t=convert_time(modified))<0)||
       ((since_t=convert_time(since))<0)||
       modified_t>since_t)
      return 1;
    return 0;
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

  void add_request(object request)
  {
    if(!this_object() || !proxy)
    {
      //REQUEST_DEBUG("add_request - already destructed")
      return;
    }

    //REQUEST_DEBUG("add_request")

#ifdef THREADS
    object key = requests_mutex?requests_mutex->lock():0;
#endif
    proxy->requests[request] = name;
#ifdef THREADS
    key = 0;
#endif
  }

  void from_disk_done ()
  {
    //REQUEST_DEBUG("from_disk_done")

    if(from_disk)
    {
      sent = from_disk->bytes_sent();
      from_disk = 0;
    }
    destruct();
  }

  void create(object _id, object _proxy, string host, int port, string file)
  {
    _start = time();

    id = _id;
    _fd = id->my_fd;

    proxy = _proxy;
    conf = id->conf;

    name = host+":"+port+"/"+file;
    _remoteaddr = id->remoteaddr;

    if(!id || !_fd)
    {
      //REQUEST_DEBUG("create - id vanished");
      destruct();
    }

    _fd->set_write_callback(_send);
    _fd->set_close_callback(_done);

    if(query("browser_keepalive") &&
       functionp(_fd->set_keepalive)&&!_fd->set_keepalive(1))
    {
      //REQUEST_DEBUG("create - set_keepalive failed");
      if(!_fd || !_fd->query_address())
      {
        //REQUEST_DEBUG("create - connection vanished")
        destruct();
        return;
      }
    }

    // try caches
    if((cache_is_wanted = cache_wanted()) &&
       !(id->pragma["no-cache"] && !query("reload_from_cache")))
    {
      // try memory cache not implemented

      // try disk cache
      object disk_cache;
      if((disk_cache = roxen->cache_file("http", name)) &&
	 http_codes_to_cache[_http_code = disk_cache->headers[" returncode"]])
      {
	//REQUEST_DEBUG("create - disk_cache")
	_mode = "Disk";

        if(query("modified_from_cache") && id->since &&
           disk_cache->headers["last-modified"] &&
           !modified(disk_cache->headers["last-modified"], id->since))
        {
#define NOT_MODIFIED "HTTP/1.0 304 Not Modified\r\n\r\n"
	  disk_cache = 0;
          finish(304, NOT_MODIFIED);
	  return;
	}

        from_disk = roxen->shuffle(disk_cache->file, id->my_fd, 0, from_disk_done);
        cache_file_info = ((disk_cache->rfile/"roxen_cache/http/")[1]) + "\t" +
          (disk_cache->file->stat()[ST_SIZE]-disk_cache->headers->head_size);
	disk_cache->file = 0;
	disk_cache = 0;
        call_out(add_request, 0, this_object());
        return;
      }

      // try incoming requests
      object request;
      // FIX_ME: should loop over all matching requests
      if(query("server_additional_output") && sizeof(requests) &&
	 (request=search(requests, name)) && request->server &&
	 request->server->_data && request->server->headers &&
	 (request->server->idle() < 30))
      {
	//REQUEST_DEBUG("create - running server("+sizeof(request->server->clients)+", "+sizeof(requests)+") found")
        if(id->since &&
           request->server->_headers["last-modified"] &&
           !modified(request->server->_headers["last-modified"], id->since))
	{
          finish(304, NOT_MODIFIED);
	  return;
	}
	if(request->server->add_client(this_object()))
	{
          add_request(this_object());
          return;
	}
      }
    }

    server = Server(this_object(), proxy, host, port, name);

    call_out(add_request, 0, this_object());
  }

  void destroy()
  {
    if(!this_object())
    {
      REQUEST_DEBUG("destroy - request already destructed");
      return;
    }

    //REQUEST_DEBUG("destroy")

    if(_fd){
      _fd->set_write_callback(0);
      _fd->set_close_callback(0);
      _fd = 0;
    }

    if(from_disk)
    {
      from_disk->finish();
      from_disk = 0;
    }

    if(id){
      id->do_not_disconnect = 0;
      id->disconnect();
      id = 0;
    }

    if(conf)
    {
      conf->sent += sent;
      conf = 0;
    }

    if(proxy)
    {
      proxy->log(name, sent, _mode, _http_code, _remoteaddr, time() - _start);
      proxy = 0;
    }
  }

  string mode()
  {
    if(server && server->no_clients > 1)
      return _mode + "(" + server->no_clients + ")";

    return _mode;
  }

  int bytes_sent()
  {
    if(from_disk)
      return sent + from_disk->bytes_sent();
    return sent;
  }
}

string comment()
{
  return QUERY(mountpoint);
}
