// This is a roxen module. Copyright © 1996 - 2004, Roxen IS.

// HTTP Proxy module. Should be cleaned and optimized. Currently the
// limit of proxy connections/second is somewhere around 70% of normal
// requests, but there is no real reason for them to take longer.

constant cvs_version = "$Id$";
constant thread_safe = 1;

#include <config.h>
#include <stat.h>

inherit "module";

#include <proxyauth.pike>
#include <roxen.h>
#include <module.h>

mapping stats = ([ "http": ([ "cache":([]), "new":([]) ]),
                   "length": ([ "cache":([]), "new":([]) ]) ]);

#ifdef THREADS
object stats_mutex = Thread.Mutex();
#endif

function(string:int) log_function;

string|void init_proxies();

function (string:int) no_cache_for;

mapping (int:int) http_codes_to_cache = ([]);

int cache_memory_filesize, cache_expired_cheat, cacher_timeout, remote_timeout;
int browser_timeout, browser_idle_timeout;
int browser_socket_keepalive, browser_socket_buffersize;
int server_timeout, server_idle_timeout;
int server_continue, server_socket_keepalive;

void start(int level, Configuration conf)
{
  string pos;
  pos=query("mountpoint");

  init_proxies();
  check_variable("browser_timeout", query("browser_timeout"));
  check_variable("browser_idle_timeout", query("browser_idle_timeout"));
  check_variable("browser_socket_keepalive", query("browser_socket_keepalive"));
  check_variable("browser_socket_buffersize", query("browser_socket_buffersize"));
  check_variable("server_timeout", query("server_timeout"));
  check_variable("server_idle_timeout", query("server_idle_timeout"));
  check_variable("server_continue", query("server_continue"));
  check_variable("server_socket_keepalive", query("server_socket_keepalive"));
  check_variable("cacher_timeout", query("cacher_timeout"));
  check_variable("remote_timeout", query("remote_timeout"));
  check_variable("cache_expired_cheat", query("cache_expired_cheat"));
  check_variable("cache_memory_filesize", query("cache_memory_filesize"));
  check_variable("http_codes_to_cache", query("http_codes_to_cache"));

  if(strlen(pos)>2 && (pos[-1] == pos[-2]) && pos[-1] == '/')
    set("mountpoint", pos[0..strlen(pos)-2]); // Evil me..

  if(strlen(query("NoCacheFor")))
    if(catch(no_cache_for = Regexp("("+(query("NoCacheFor")-"\r"-"\n\n")/"\n"*")|("
				   +")")->match))
      report_error("Parse error in 'No cache' regular expression.\n");

  if(!no_cache_for) no_cache_for = lambda(string i){return 0;};

#ifdef PROXY_DEBUG
  werror("PROXY: Proxy online.\n");
#endif

  if(log_function)
  {
    destruct(function_object(log_function));
    log_function = 0;
  }
  if (!strlen(query("logfile")))
    return;
  log_function = roxen.LogFile( query("logfile") )->write;
}

mixed log(object id, mapping file)
{
  object r;
  if(!(r = id->misc->proxy_request))
    return 0;

  id->misc->proxy_request = 0;
  r->sent += file->len;
  call_out(r->log, 0, r);
  return 1;
}

void do_write(string host, string oh, string more)
{
  log_function(more + (host?host:oh) + "\n");
}

#define MY_TIME(X) sprintf("%s%d:%d", (X)>(60*60)?(X)/(60*60)+":":"",\
			     (X)%(60*60)/60, (X)%60)
void log_client(string host, string oh, string id, string more, string client,
		int _time, string resolve)
{
  more = "[" + cern_http_date(time(1)) + "] http://" + (host?host:oh) + ":" +
         id + " " + more + " " + MY_TIME(_time) + " ";

  switch (resolve) {
  case "Resolved":
    roxen->ip_to_host(client, do_write, client, more);
    break;
  case "IfCached":
    log_function(more + roxen->quick_ip_to_host(client) + "\n");
    break;
  default:
    log_function(more + client + "\n");
  }
}
#undef MY_TIME

array cachers=({});
array proxies=({});
array filters=({});

string|void init_proxies()
{
  string foo, res = "";
  array err;

  cachers = ({ });
  proxies = ({ });
  filters = ({ });

  foreach(query("Cachers")/"\n", foo)
  {
    array bar;
    if(!strlen(foo) || foo[0] == '#')
      continue;
    
    bar = replace(foo, "\t", " ")/" " -({ "" });

    if(sizeof(bar) < 3)
    {
      res += "Line \"" + foo + "\" has too few arguments\n";
      continue;
    }

    if(err=catch(cachers += ({ ({ Regexp(bar[0])->match, 
				  ({ bar[1], (int)bar[2] }) }) })))
      res += "Syntax error in regular expression in ccaching proxy: " +
	     bar[0] + "\n" + err[0];
  }

  foreach(query("Proxies")/"\n", foo)
  {
    array bar;
    if(!strlen(foo) || foo[0] == '#')
      continue;
    
    bar = replace(foo, "\t", " ")/" " -({ "" });

    if(sizeof(bar) < 3)
    {
      res += "Line \"" + foo + "\" has too few arguments\n";
      continue;
    }

    if(err=catch(proxies += ({ ({ Regexp(bar[0])->match, 
				  ({ bar[1], (int)bar[2] }) }) })))
      res += "Syntax error in regular expression in ccaching proxy: " +
	     bar[0] + "\n" + err[0];
  }

  foreach(query("Filters")/"\n", foo)
  {
    array bar;
    if(!strlen(foo) || foo[0] == '#')
      continue;
    
    bar = replace(foo, "\t", " ")/" " -({ "" });

    if(sizeof(bar) < 2)
    {
      res += "PROXY: Line \"" + foo + "\" has too few arguments\n";
      continue;
    }

    if(err=catch(filters += ({ ({ Regexp(bar[0])->match, 
				   bar[1..]*" " })})))
      res += "PROXY: Syntax error in regular expression in proxy: " + bar[0] + "\n" +
	     err[0];
  }

  if(!strlen(res))
    return 0;

  report_notice("PROXY: " + res);
  return res;
}

#define CASE_ASSIGN(X) case #X: X = value; break;
string check_variable(string name, mixed value)
{
  string res;

  switch(name)
  {
   CASE_ASSIGN(browser_timeout)
   CASE_ASSIGN(browser_idle_timeout)
   CASE_ASSIGN(browser_socket_buffersize)
   CASE_ASSIGN(browser_socket_keepalive)
   CASE_ASSIGN(server_continue)
   CASE_ASSIGN(server_timeout)
   CASE_ASSIGN(server_idle_timeout)
   CASE_ASSIGN(server_socket_keepalive)
   CASE_ASSIGN(cache_expired_cheat)
   CASE_ASSIGN(cacher_timeout)
   CASE_ASSIGN(remote_timeout)
   case "cache_memory_filesize":
     cache_memory_filesize = 1024 * value;
     break;
   case "http_codes_to_cache":
     http_codes_to_cache = ([]);
     foreach(value, string s)
     {
       if(s == ("" + (int)s))
         http_codes_to_cache[(int)s] = 1;
       else
         res = "No integer value: " + s;
     }
     break;
   case "Proxies":
   case "Cachers":
   case "Filters":
     array tmp,c;
     string tmp2, res;
     tmp = this_object()[lower_case(name)];
     tmp2 = query(name);

     set(name, value);
     if(c=catch(res = init_proxies()) || res)
     {
       this_object()[lower_case(name)] = tmp;
       set(name, tmp2);
       res += "Error while compiling regular expression. Syntax error: " + c[0];
     }
     else
     {
       //this_object()[lower_case(name)] = tmp;
       set(name, tmp2);
     }
  }
  if(!res)
    return 0;
  report_debug(res + "\n");
  return res;
}

void create()
{         
  defvar("logfile", "", "Logfile", TYPE_FILE,
	 "Empty the field for no log at all. "
	 "For filename substitution patterns "
	 "see the description of the main logfile.");
  
  defvar("log_resolve_client", "Resolved", "Log client hostnames",
         TYPE_STRING_LIST|VAR_MORE,
	 "Specify if client hostnames should be logged always \"Resolved\", "
	 "only resolved \"IfCached\" or as \"IPAddress\". "
	 "Note, that all resolving of hostnames is done asynchroneously and "
	 "request speed is not affected by the resolve method.",
	 ({ "Resolved", "IfCached", "IPAddress"}),
	 lambda(){return !query("logfile") || !strlen(query("logfile"));});

  defvar("online_stats", 0, "Online stats",
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

  defvar("http_codes_to_cache", ({ "200", "300", "301", "404" }),
	 "Http codes to cache", TYPE_STRING_LIST|VAR_MORE,
	 "Cache documents with these http codes. "
	 "A reasonable set is \"200\", \"300\", \"301\", \"404\".");

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

  defvar("cache_without_content_length", 0, "Cache pages without content-length",
	 TYPE_FLAG|VAR_MORE,
	 "A content-length of zero is often used to prevent caching of pages. "
	 "To bypass content-length checks set this to true.");

  defvar("cache_expired_cheat", 0, "Cache expired cheat time",
         TYPE_INT|VAR_MORE,
         "In some special environments caching of already expired pages "
         "may be useful. "
         "Set this option to the desired time in seconds to cheat. "
         "A negative value has the effect that a page gets expired earlier. "
         "A positive value has the effect that a page gets expired later. "
         //"This also applies to Pragma \"cache-control: max-age\"."
	 );

  defvar("Cachers", "", "Remote caching proxy regular expressions",
	 TYPE_TEXT_FIELD|VAR_MORE,
	 "Here you can add redirects to remote caching proxy servers. "
	 "If a page is considered cacheable (no cookies, no queries, ...) "
	 "and requested from a host matching a pattern, this proxy will "
	 "query the remote caching proxy server at the host and port "
	 "specified.<p> "
	 "Note, that this proxy does not check (yet) if the remote caching "
	 "proxy server handles the request in caching or proxy mode.<p>"
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

  defvar("cacher_timeout", 10, "Remote caching proxy server timeout",
	 TYPE_INT|VAR_MORE,
	 "If the remote caching proxy server does not respond within the "
	 "specified time (seconds) the request will be redirected to a "
	 "matching remote proxy server. If there is no matching remote "
	 "proxy server the server host will be contacted directly (by this "
	 "proxy). Set to zero if an error should be returned to the "
	 "browser instead.",
	 0, lambda(){return !query("Cachers") || !strlen(query("Cachers"));});

  defvar("Proxies", "", "Remote proxy regular expressions", TYPE_TEXT_FIELD|VAR_MORE,
	 "Here you can add redirects to remote proxy servers. If a file is "
	 "requested from a server host matching a pattern, this proxy will "
	 "query the remote proxy server at the host and port specified.<p> "
	 "Hopefully, that remote proxy will then connect the server host. "
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

  defvar("remote_timeout", 10, "Remote proxy server timeout",
	 TYPE_INT|VAR_MORE,
	 "If the remote proxy server does not respond within the "
	 "specified time (seconds) the server host will be contacted "
	 "directly (by this proxy). Set to zero if an error should be "
	 "returned to the browser instead.",
	 0, lambda(){return !query("Proxies") || !strlen(query("Proxies"));});

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
  defvar("filesize_disk_max", 32, "Cache filesize maximum for disk cache",
         TYPE_INT_LIST|VAR_MORE,
	 "Cache files to disk upto this size (mb). "
	 "Set to zero for unlimited.",
	 ({ 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024 }));
 */
  defvar("cache_memory_filesize", 16, "Cache filesize maximum for memory cache",
         TYPE_INT_LIST|VAR_MORE,
	 "While caching keep files in memory upto this size (kb).",
	 ({ 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024 }));

  defvar("browser_socket_buffersize", 8192, "Browser socket buffer size",
         TYPE_INT_LIST|VAR_MORE,
	 "Try set the socket buffer size of the browser connection.",
	 ({ 4096, 8192, 16384, 32768 }));

  defvar("browser_socket_keepalive", 0, "Browser socket keep alive",
         TYPE_FLAG|VAR_MORE,
	 "Try keep browser connection active by enabling the periodic "
	 "transmission of messages on the browser socket. ");

  defvar("browser_timeout", 0, "Browser timeout",
         TYPE_INT|VAR_MORE,
	 "Time in seconds after which a browser connection will "
	 "be terminated. Set to zero if you do not want timeout checks.");

  defvar("browser_idle_timeout", 0, "Browser idle timeout",
         TYPE_INT|VAR_MORE,
	 "Time in seconds after which an idle browser connection will "
	 "be terminated. Set to zero if you do not want idle timeout checks.");

  defvar("server_timeout", 0, "Server timeout",
         TYPE_INT|VAR_MORE,
	 "Time in seconds after which a server connection will "
	 "be terminated. Set to zero if you do not want timeout checks.");

  defvar("server_idle_timeout", 0, "Server idle timeout",
         TYPE_INT|VAR_MORE,
	 "Time in seconds after which an idle server connection will "
	 "be terminated. Set to zero if you do not want idle timeout checks.");

  defvar("server_continue", 1, "Server continue",
         TYPE_FLAG|VAR_MORE,
	 "If this option is set a caching server connection will be continued "
	 "even if the requesting browser connection vanished. "
	 "If a high loaded proxy regularly runs out of sockets unsetting this "
	 "option might help a bit.");

  defvar("server_socket_keepalive", 0, "Server socket keep alive",
         TYPE_FLAG|VAR_MORE,
	 "Try keeps server connection active by enabling the periodic "
	 "transmission of messages on the server socket.");
/*
  defvar("server_additional_output", 0, "Server additional output",
         TYPE_FLAG|VAR_MORE,
	 "If this option is set a caching server connection will be used "
	 "for additional requests to the same URL. "
	 "Note that this might be a problem with broken or frozen server "
	 "connections. "
	 "It should probably only used together with \"Timeout Server "
	 "Connection\" set to an appropriate value.");
 */
}

void destroy()
{
  //report_debug("PROXY: destroy\n");

  cachers = 0;
  proxies = 0;
  filters = 0;
  http_codes_to_cache = 0;
  log_function = 0;
  stats = 0;
#ifdef THREADS
  stats_mutex = 0;
#endif
}

constant module_type = MODULE_PROXY|MODULE_LOCATION|MODULE_LOGGER|MODULE_PROVIDER;
constant module_name = "HTTP-Proxy";
constant module_doc  = "This is a caching HTTP-proxy with quite "
  " a few bells and whistles";

string query_provides() { return "http_request_init"; }

mapping http_request_init(RequestID id)
{
  werror("http_request_init(%O)...\n", id);
  if (has_prefix(id->misc->prot_cache_key, "http://")) {
    if ((query_location() == "http:/") &&
	(!has_prefix(id->raw_url, "http:/"))) {
      // Undo the RFC 2068 5.1.2 stuff
      werror("Setting raw_url to %O\n", id->misc->prot_cache_key);
      id->raw_url = id->misc->prot_cache_key;
    }
  }
  return UNDEFINED;
}

string query_location()  { return query("mountpoint"); }

string status()
{
  string res="";
/*
  if(sizeof(requests))
  {
    res += "<hr><h1>Current connections</h1><p>";
    foreach( indices(requests), object request)
      if(request)
       res += requests[request] + ": " + request->status() + "\n";
  }
  res += "<hr>";
 */
 return ("<pre><font size=+1>"+res+"</font></pre>");
}

mapping find_file( string f, object id )
{
  string host, file;
  int port;
  mixed tmp;

#ifdef PROXY_DEBUG
  werror("PROXY: Request for "+f+"\n");
#endif
  f=id->raw_url[strlen(query("mountpoint"))+1 .. ];

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

  // http_pipe_in_progress MUST reach id->pipe before send_result comes there
  // otherwise id->pipe and id->file will be messed up
  Request(id, this_object(), host, port, file);
  return http_pipe_in_progress();
}

#define PROXY_DEBUG
#ifdef PROXY_DEBUG
#define SERVER_DEBUG(X) report_debug("PROXY: Server "+(X)+" for "+name+".\n");
#else
#define SERVER_DEBUG(X)
#endif

program pipe;
class Server 
{
  object conf, proxy, client, to_disk, to_disk_pipe, from_server;

  string name = "", _remoteaddr = "", _data = "", proxyhost;
  string filter;

  int received, cache_is_wanted, _http_code, _start, _last_got;
  int headers_size, browser_socket_buffersize, server_continue;
  int first_write_done;

  array remote, cacher;
  mapping headers;

  private void parse_headers(int p)
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
    }
  }

  private int received_content_length()
  {
    if(!proxy || !proxy->http_codes_to_cache[_http_code])
    {
      //SERVER_DEBUG("received_content_length - http_code("+_http_code+")")
      return 0;
    }

    if(!headers)
    {
      SERVER_DEBUG("received_content_length - !headers")
      return 0;
    }

    if((headers["content-length"] &&
        (int)headers["content-length"] > 0 &&
        (int)headers["content-length"] <= (received - headers_size)) ||
       query("cache_without_content_length"))
    {
      //SERVER_DEBUG("received_content_length - ok(" + headers["content-length"] + "," + (received - headers_size) + ")")
      return 1;
    }

    //SERVER_DEBUG("received_content_length - low(" + headers["content-length"] + "," + (received - headers_size) + ")")
    return 0;
  }

  void check_timed_out(int|void server_idle_timeout, int|void server_timeout)
  {
    if(!from_server || !from_server->query_address())
    {
      //SERVER_DEBUG("check_timed_out - connection vanished")
      finish("interrupted - server connection vanished");
      return;
    }

    if(proxy)
    {
      server_idle_timeout = proxy->server_idle_timeout;
      server_timeout = proxy->server_timeout;
      server_continue = proxy->server_continue;
    }

    if(server_idle_timeout && server_idle_timeout < idle())
    {
      SERVER_DEBUG("check_timed_out - server_idle_timeout")

      finish("interrupted by proxyserver - server_idle_timeout");
      return;
    }

    if(server_timeout && server_timeout < (time() - _start))
    {
      SERVER_DEBUG("check_timed_out - server_timeout")

      finish("interrupted by proxyserver - server_timeout");
      return;
    }

    if(!client && !server_continue)
    {
      destruct();
      return;
    }
    if(!client)
    {
      destruct();
      return;
    }

    call_out(check_timed_out, 60, server_idle_timeout, server_timeout);
  }

  private void send(string|object data, int|void more_soon)
  {
    if(!client || catch(client->send(data, more_soon)))
      finish();
  }
    
  private void write(string|object data)
  {
    //SERVER_DEBUG("write(" + (stringp(data)?strlen(data):"-") + ")")

    if(!client || catch(client->send_now(data)))
    {
      SERVER_DEBUG("write - client vanished")

      finish();
    }
  }

  private void server_got(mixed foo, string d)
  {
    //SERVER_DEBUG("server_got(" + strlen(d) + ")");

    _last_got = time();

    int len = strlen(d);

    if(_data)
      _data += d;

    if(conf)
      conf->received += len;
    received += len;

    // parse header if complete
    if(!headers){
      if(!len)
        return;

      mode("Header");

      int p;
      if(((p = search(_data, "\r\n\r\n"))!=-1)||
         ((p = search(_data, "\n\r\n\r"))!=-1))
        parse_headers(p += 4);
      else if(((p = search(_data, "\r\r"))!=-1)||
              ((p = search(_data, "\n\n"))!=-1))
        parse_headers(p += 2);

      // do not send anything before header is complete
      //   or recognized as invalid
      if(!headers)
	return;

      // remove pending remote (caching) proxy timeout callback
      if(remote || cacher)
        remove_call_out(connected_to_server);

      // header is complete and parsed
      headers_size = p;
      client->http_code(_http_code);

      //SERVER_DEBUG(sprintf("Headers=%O\n", headers))

#define NOT_MODIFIED "HTTP/1.0 304 Not Modified\r\n\r\n"
      if(client && client->id->since &&
	 _http_code == 200 && headers["last-modified"] &&
         !client->modified(headers["last-modified"], client->id->since))
      {
        if(from_server){
          from_server->set_blocking(0,0,0);
          from_server = 0;
        }
	finish(304, NOT_MODIFIED);
	return;
      }

      if(cache_is_wanted &&
	 (cache_is_wanted = client->headers_cache_wanted(headers)))
        mode("Caching");
      else
        mode("Proxy");

      // FIX_ME: add proxy headers and adjust content-length
      // if(query("proxy_header_wanted")

      // leave the rest to client->id->send
      if(!cache_is_wanted)
      {
	//SERVER_DEBUG("server_got(" + len + ") - proxy only")

        from_server->set_read_callback(0);
	_last_got = -1;

	send(_data, 1);
	_data = 0;
	send(from_server);

	return;
      }

      // first write after header is complete and cache is wanted
      first_write_done = 1;
      write(_data);
      return;
    }

    write(d);

/*  // ready ?
    if(headers["content-length"] &&
       (int)headers["content-length"] <= (received - headers_size))
    {
      //SERVER_DEBUG("server_got(" + (received - headers_size) + ") - content-length=" + headers["content-length"])
    }
 */
    // caching

    if(!this_object() || !cache_is_wanted){
      return;
    }

    if(!proxy)
    {
      cache_is_wanted = 0;
      mode("Proxy");
      return;
    }

    // write got data to disk if over memory filesize max and caching
    if(!to_disk && (strlen(_data) > cache_memory_filesize))
    {
      if(to_disk = roxen->create_cache_file("http", name))
      {
        //SERVER_DEBUG("server_got(" + strlen(_data) + ") setup to_disk")

        mode("ToDisk");
	d = _data;
	len = strlen(_data);
      }
      else
      {
	SERVER_DEBUG("server_got(" + strlen(_data) + ") - to_disk failed")

	cache_is_wanted = 0;
        mode("Proxy");
        return;
      }
    }

    if(to_disk)
    {
      //SERVER_DEBUG("server_got(" + len + ") - to_disk")

      if(!to_disk->file || !to_disk->file->query_fd())
      {
        SERVER_DEBUG("server_got - to_disk->file vanished")

        cache_is_wanted = 0;
        to_disk = 0;
        _data = 0;
        return;
      }

      if(!to_disk_pipe || catch(to_disk_pipe->write(d)))
      {
	 //SERVER_DEBUG("server_got(" + len + ") - setup and write to_disk_pipe")

	 if (!pipe)
	   pipe = (program)"fastpipe";
	 to_disk_pipe = pipe();
	 to_disk_pipe->write(d);
	 to_disk_pipe->set_done_callback(lambda(){to_disk_pipe=0;});
	 to_disk_pipe->output(to_disk->file);
      }
    }
  }

  private void server_done()
  {
    //SERVER_DEBUG("server_done");

    if(from_server){
      from_server->set_blocking(0,0,0);
      from_server = 0;
    }

    finish();
  }

  private void finish(int|string|void http_or_last_message, string|void s)
  {
    //SERVER_DEBUG("finish(" + http_or_last_message + "," + s + ")")

    if(s && intp(http_or_last_message))
    {
      _http_code = http_or_last_message;
    }

    // make the logger happy - do rest of caching after client->finish
    if(cache_is_wanted && !to_disk && !http_or_last_message &&
       (from_server || (cache_is_wanted = received_content_length())))
      mode("ToDisk");

    if(client)
    {
      if(!s && first_write_done <= 0)
      {
        SERVER_DEBUG("finish - first_write")

        first_write_done = 1;
        write(_data);
      }

      client->finish(http_or_last_message, s);
      client = 0;
    }

    if(!from_server || !from_server->query_address() || http_or_last_message)
    {
      destruct();
      return;
    }

    if(!client && !server_continue)
    {
      destruct();
      return;
    }

    // wait for disk pipe to finish
    if(cache_is_wanted && to_disk && to_disk_pipe)
    {
      //SERVER_DEBUG("finish - waiting for disk pipe")

      call_out(finish, 5);
      return;
    }

    if(to_disk)
    {
      //SERVER_DEBUG("finish - to_disk->http_check_cache_file")

      //if(cache_is_wanted = received_content_length())
      //{
        call_out(roxen->http_check_cache_file, 0, to_disk);
        to_disk = 0;
        to_disk_pipe = 0;
      //}
      //else
	// delete_cache_file(to_disk); // done by http_check_cache_file
    }
    else if(cache_is_wanted && (cache_is_wanted = received_content_length()) &&
      (to_disk = roxen->create_cache_file("http", name)))
    {
      //SERVER_DEBUG("finish - write memory cache to_disk_pipe")

      if (!pipe)
	pipe = (program)"fastpipe";
      to_disk_pipe = pipe();
      to_disk_pipe->write(_data);
      to_disk_pipe->set_done_callback(lambda(){to_disk_pipe=0;finish();});
      to_disk_pipe->output(to_disk->file);
      return;
    }

    destruct();
  }

  void destroy()
  {
    //SERVER_DEBUG("destroy")

    remove_call_out(check_timed_out);

    client = 0;
    headers = 0;
    remote = 0;
    cacher = 0;
    if(to_disk_pipe)
    {
      to_disk_pipe->set_done_callback(0);
      to_disk_pipe->finish();
      to_disk_pipe = 0;
    }
    if(to_disk)
    {
      //delete_cache_file(to_disk);
      call_out(roxen->http_check_cache_file, 0, to_disk);
      to_disk = 0;
    }
    proxy = 0;
    conf = 0;
    _data = 0;

    if(from_server){
      from_server->set_blocking(0,0,0);
      from_server = 0;
    }
  }

  string mode(string|void m)
  {
    if(client)
      return client->mode(m);

    return "Server";
  }
      
  int idle()
  {
    if(_last_got == 0)
      return time() - _start;
    else if(_last_got < 0)
      return 0;

    return time() - _last_got;
  }

  int bytes_sent()
  {
    return received;
  }

  private string process_request(object id)
  {
    string url;

    string new_raw = replace(id->raw, "\r\n", "\n");
    int delimiter;
    if((delimiter = search(new_raw, "\n\n"))>=0)
      new_raw = new_raw[..delimiter-1];

    new_raw = replace(new_raw, "\n", "\r\n")+"\r\n\r\n"+(id->data||"");

    // FIX_ME: fast recursion if this proxy is specified as remote /wk
    if(remote || cacher)
      return new_raw;

    // Strip command.
    if((delimiter = search(new_raw, "\n")) >= 0)
      new_raw = new_raw[delimiter+1..];

    url=id->raw_url[strlen(query("mountpoint"))..];
    sscanf(url, "%*[/]%s", url);	// Strip initial '/''s.
    if(!sscanf(url, "%*s/%s", url))
      url="";

    return sprintf("%s /%s HTTP/1.0\r\n%s", id->method || "GET", url, new_raw);
  }

  private array is_remote_proxy(array proxies, string host, int port,
    int timeout)
  {
    foreach(proxies, array tmp)
      if(tmp[0](host))
	if(tmp[1][0]!="no_proxy")
	{
	  if(timeout)
	    call_out(connected_to_server, timeout, 0);
          return tmp[1] + ({ host }) + ({ port });
	}
        else
          return 0;
  }

  private string is_filter(string hmm)
  {
    foreach(filters, array tmp)
      if(tmp[0](hmm))
        return tmp[1];
  }

  void create(object _client, object _proxy, string host, int port, string _name)
  {
    _start = time();
    client = _client;
    proxy = _proxy;
    server_continue = proxy->server_continue;

    client->server = this_object();
    conf = client->id->conf;
    browser_socket_buffersize = client->browser_socket_buffersize;

    name = _name;
    proxyhost = host + ":" + port;

    cache_is_wanted = client->cache_is_wanted;
    
    if(filter = is_filter(name)){
      //SERVER_DEBUG("create - Filter is "+filter+"\n");
    }

    if(cache_is_wanted &&
       (cacher = is_remote_proxy(cachers, host, port, cacher_timeout)))
    {
      host = cacher[0];
      port = cacher[1];
      client->cacher = 1;
    }
    else if(remote = is_remote_proxy(proxies, host, port, remote_timeout))
    {
      host = remote[0];
      port = remote[1];
      client->remote = 1;
    }

    // periodic checking for server connection and client
    call_out(check_timed_out, 300);

    mode("HostLookup");
    roxen->host_to_ip(host, got_hostname, host, port);
  }

  string error_msg(string s)
  {
    return
      "<title>Roxen: " + s + "</title>\n"
      "<h1>Proxy Request Failed</h1>"
      "<hr>"
      "<font size=+2><i>" + s + "</i></font>"
      "<hr>"
      "<font size=-2>Roxen"
      " at <a href=" + conf->query("MyWorldLocation")+">" +
      conf->query("MyWorldLocation") + "</a></font>";
  }

  void got_hostname(string host, string oh, int port)
  {
    // remote timeout callback may come here
    if(from_server)
      return;

    if(!host)
    {
      //SERVER_DEBUG("got_hostname - no host ("+oh+")")
      finish(500, error_msg("Unknown host: "+oh));
      return;
    }
    mode("Connecting");

    object from_server = Stdio.File();
    from_server->async_connect(host, port, connected_to_server, from_server);
  }

  private void connected_to_server(int connected, object|void _from_server)
  {
    //SERVER_DEBUG("connected_to_server("+connected+")")

    if(!connected || !_from_server || !_from_server->query_address())
    {
      // remote timeout callback may come here
      if(headers)
      {
        //SERVER_DEBUG("connected_to_server - already connected/headers")
	if(_from_server)
	{
	  _from_server->set_blocking(0,0,0);
	  _from_server = 0;
	}
	return;
      }

      // any further connect is coming late
      if(from_server)
      {
	from_server->set_blocking(0,0,0);
	from_server = 0;
      }

      if(remote && remote_timeout)
      {
        /* SERVER_DEBUG("connected_to_server - remote(" + remote[0] + "," +
		     remote[1]+")_connect failed") /**/

	client->remote = 0;
	remove_call_out(connected_to_server);
	if(_from_server)
	{
	  _from_server->set_blocking(0,0,0);
	  _from_server = 0;
	}
        mode("HostLookup");
        call_out(roxen->host_to_ip, 0, remote[2], got_hostname, remote[2], remote[3]);
	remote = 0;
	return;
      }

      if(cacher && cacher_timeout)
      {
        /* SERVER_DEBUG("connected_to_server - cacher(" + cacher[0] + "," +
		     cacher[1] + ")_connect failed") /**/

	client->cacher = 0;
	remove_call_out(connected_to_server);
	if(_from_server)
	{
	  _from_server->set_blocking(0,0,0);
	  _from_server = 0;
	}
        mode("HostLookup");
	if(remote = is_remote_proxy(proxies, cacher[2], cacher[3],
	  remote_timeout))
	{
	  cacher = 0;
	  client->remote = 1;
          roxen->host_to_ip(remote[0], got_hostname, remote[0], remote[1]);
	}
	else
	{
          call_out(roxen->host_to_ip, 0, cacher[2], got_hostname,
                   cacher[2], cacher[3]);
	  cacher = 0;
	}
	return;
      }

      if(remote)
        finish(500, error_msg("Connection refused by remote proxy: " +
               remote[0] + ":" + remote[1] + "."));
      else if(cacher)
        finish(500, error_msg("Connection refused by remote caching proxy: " +
               cacher[0] + ":" + cacher[1] + "."));
      else
        finish(500, error_msg("Connection refused by: "+ proxyhost +
	       "."));
      return;
    }

    from_server = _from_server;

    mode("Connected");

    if(proxy->server_keepalive &&
       functionp(from_server->set_keepalive)&&!from_server->set_keepalive(1))
    {
      SERVER_DEBUG("set_keepalive(server) failed");
      if(!from_server || !from_server->query_address())
      {
        finish(500, error_msg("Connection to server vanished"));
	return;
      }
    }

    string to_send = process_request(client->id);

    if(!to_send)
    {
      finish(500, error_msg("Request cannot be processed"));
      return;
    }
    if(from_server->write(to_send)<strlen(to_send))
    {
      SERVER_DEBUG("connected_to_server - write request failed")
      finish(500, error_msg("Server write request failed"));
      return;
    }

    if(filter)
    {
      object f, q;
      f=Stdio.File();
      q=f->pipe();
      from_server->set_blocking(0,0,0);
      spawne((filter/" ")[0], (filter/" ")[1..], ([ ]), from_server, q,
	     Stdio.stderr);
      destruct(from_server);
      destruct(q);
      from_server=f;
    }
 
    from_server->set_read_callback(server_got);
    from_server->set_write_callback(0);
    from_server->set_close_callback(server_done);
  }
}

#ifdef PROXY_DEBUG
#define REQUEST_DEBUG(X) report_debug("PROXY: Request("+_remoteaddr+") " +\
  (X) + " for " + name+".\n");
#else
#define REQUEST_DEBUG(X)
#endif

class Request 
{
  object proxy, id, server, from_disk;

  string name = "", _remoteaddr = "", cache_file_info, _mode = "Proxy";

  int browser_socket_buffersize, sent, cache_is_wanted, _http_code, remote, cacher;
  int _start;

  void log(object|void r)
  {
    //REQUEST_DEBUG("log")

    if(!proxy)
      return;

    string _mode = mode();
    mode(_mode + "*");

    if(log_function){
      string more = sent + " " + _mode + " " + _http_code + " ";
      mode(_mode + "-");
      string host, rest;
      sscanf(name, "%s:%s", host, rest);
      roxen->ip_to_host(host, proxy->log_client, host, rest, more, _remoteaddr,
	time() - _start, query("log_resolve_client"));
    }

    if(query("online_stats")){
      string cache_new = "new";
      if(_mode == "Disk")
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

      stats->http[cache_new][_http_code]++;
      stats->length[cache_new][sent_msb]++;

#ifdef THREADS
      key = 0;
#endif
    }
    destruct();
  }

  void check_timed_out(int|void browser_idle_timeout, int|void browser_timeout)
  {
    if(!id || !id->my_fd || !id->my_fd->query_address())
    {
      //REQUEST_DEBUG("check_timed_out - id vanished")
      destruct();
      return;
    }
    
    if(proxy)
    {
      browser_idle_timeout = proxy->browser_idle_timeout;
      browser_timeout = proxy->browser_timeout;
    }

    if(browser_idle_timeout && browser_idle_timeout < idle())
    {
      REQUEST_DEBUG("check_timed_out - browser_idle_timeout")

      finish("interrupted by proxy server - browser_idle_timeout");
      return;
    }

    if(browser_timeout && browser_timeout < (time() - _start))
    {
      REQUEST_DEBUG("check_timed_out - browser_timeout")

      finish("interrupted by proxy server - browser_timeout");
      return;
    }

    call_out(check_timed_out, 60, browser_idle_timeout, browser_timeout);
  }

  void send(string|object data, int|void more_soon)
  {
    if(!id ||
       catch(more_soon?id->send(data):id->send_result(http_stream(data))))
    {
      destruct();
      return;
    }
  }

  void send_pipe_done()
  {
    //REQUEST_DEBUG("send_pipe_done - sent=" + sent)

    if(!server)
    {
      //REQUEST_DEBUG("send_pipe_done - server finished")
      id->do_log();
      return;
    }
  }

  void send_now(string s)
  {
    //REQUEST_DEBUG("send_now(" + strlen(s) + ")")
    if(!id || catch(id->send(s)))
    {
      REQUEST_DEBUG("send_now(" + strlen(s) + ") - id vanished")
      destruct();
      return;
    }
  }

  // also used by Server
  int headers_cache_wanted(mapping headers)
  {
    cache_is_wanted = 0;

    if(!proxy)
    {
      //REQUEST_DEBUG("headers_cache_is_wanted - proxy is gone")
      return 0;
    }

    if(!headers)
    {
      REQUEST_DEBUG("headers_cache_is_wanted - no headers")
      return 0;
    }

    if(!proxy->http_codes_to_cache[_http_code])
    {
      //REQUEST_DEBUG("headers_cache_is_wanted - http_code("+_http_code+")")
      return 0;
    }

    if(!query("cache_without_content_length") &&
       (!headers["content-length"] || (int)headers["content-length"] <= 0))
    {
      //REQUEST_DEBUG("headers_cache_is_wanted - no content length")
      return 0;
    }

    if(headers["expires"] &&
       !Roxen.is_modified(headers["expires"],
	 time() - cache_expired_cheat))
    {
      //REQUEST_DEBUG("headers_cache_is_wanted - expired("+headers["expires"]+")")
      return 0;
    }

    cache_is_wanted = 1;
    return 1;
  }

  private int cache_wanted()
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
    if(id&&id->pipe&&id->pipe->last_called)
      return time() - id->pipe->last_called;

    return 0;
  }

  constant MONTHS= (["jan":0, "feb":1, "mar":2, "apr":3, "may":4, "jun":5,
		     "jul":6, "aug":7, "sep":8, "oct":9, "nov":10, "dec":11,]);

  private int convert_time(string a)
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

  // also used by server
  int modified(string modified, string since)
  {
    int modified_t, since_t;

    if(sscanf(since, "%*s, %[^;]s%*s", since) < 2)
    {
      REQUEST_DEBUG("modified - could not convert since: "+since)
      return 1;
    }

    if(sscanf(modified, "%*s, %s", modified) < 2)
    {
      REQUEST_DEBUG("modified - could not convert modified: "+modified);
      return 1;
    }

    //REQUEST_DEBUG("modified (since="+since+"), modified="+modified+")")
    if(((modified_t=convert_time(modified))<0)||
       ((since_t=convert_time(since))<0)||
       modified_t>since_t)
      return 1;
    return 0;
  }

  void create(object _id, object _proxy, string host, int port, string file)
  {
    _start = time();

    id = _id;

    id->misc->proxy_request = this_object();

    proxy = _proxy;

    name = host+":"+port+"/"+file;
    _remoteaddr = id->remoteaddr;

    browser_socket_buffersize = proxy->browser_socket_buffersize;
    if(browser_socket_buffersize != 8192 &&
       catch(id->my_fd->set_buffer(browser_socket_buffersize)))
    {
      REQUEST_DEBUG("create - set_buffer(" + browser_socket_buffersize + ") failed")
      browser_socket_buffersize = 8192;
    }
    if(browser_socket_keepalive &&
       functionp(id->my_fd->set_keepalive)&&!id->my_fd->set_keepalive(1))
    {
      //REQUEST_DEBUG("create - set_keepalive failed");
      if(!id->my_fd || !id->my_fd->query_address())
      {
        //REQUEST_DEBUG("create - connection vanished")
        destruct();
        return;
      }
    }

    // periodic checking for client connection
    call_out(check_timed_out, 60);

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
	  disk_cache = 0;
          finish(304, NOT_MODIFIED);
	  return;
	}

        int len = disk_cache->file->stat()[ST_SIZE]-disk_cache->headers->head_size;
        cache_file_info = ((disk_cache->rfile/"roxen_cache/http/")[1]) + "\t" +
          len;

        from_disk = disk_cache->file;
        id->send_result(http_file_answer(disk_cache->file, "raw", len));

	disk_cache->file = 0;
	disk_cache = 0;
        return;
      }

      // FIX_ME: does not work for now /wk
      // try incoming requests
      // FIX_ME: should loop over all matching requests
      /*
      object request;
      if(query("server_additional_output") && sizeof(requests) &&
	 (request=search(requests, name)) && request->server &&
	 request->server->_data && request->server->headers &&
	 (request->server->idle() < 30))
      {
	REQUEST_DEBUG("create - running server("+sizeof(request->server->clients)+", "+sizeof(requests)+") found")
        if(id->since &&
           request->server->_headers["last-modified"] &&
           !modified(request->server->_headers["last-modified"], id->since))
	{
          finish(304, NOT_MODIFIED);
	  return;
	}
	if(request->server->add_client(this_object()))
	{
          //add_request(this_object());
          return;
	}
      }
      */
    }

    server = Server(this_object(), proxy, host, port, name);
  }

  int done_done;
  void finish(int|string|void http_or_last_message, string|void s)
  {
    if(!this_object())
      return;

    //REQUEST_DEBUG("finish(" + http_or_last_message + "," + s + ")")

    server = 0;

    // immediate finish with http_code
    if(s && intp(http_or_last_message))
    {
      sent = strlen(s);
      _http_code = http_or_last_message;
      catch(id->send_result(http_low_answer(http_or_last_message, s)));
      return;
    }

    if(stringp(http_or_last_message))
    {
      id->end(http_or_last_message + "\n\n");
      return;
    }

    if(!id)
    {
      REQUEST_DEBUG("finish - id vanished")
      destruct();
      return;
    }

    if(id->pipe)
    {
      //REQUEST_DEBUG("finish - pipe is running")
      if (!done_done)
	id->start_sender(send_pipe_done);
      done_done = 1;
      return;
    }
    REQUEST_DEBUG("finish - last send")
    send("");
  }

  void destroy()
  {
    //REQUEST_DEBUG("destroy")

    remove_call_out(check_timed_out);

    from_disk = 0;
    server = 0;
    proxy = 0;
    id = 0;
  }

  string mode(string|void m)
  {
    if(m)
      _mode = m;

    if(remote)
      return "Remote" + _mode;
    if(cacher)
      return "Cacher" + _mode;

    return _mode;
  }

  int bytes_sent()
  {
    if(id&&id->pipe)
      return sent + id->pipe->bytes_sent();

    return sent;
  }
}
