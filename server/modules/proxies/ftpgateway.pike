#include <module.h>
#include <config.h>

#if DEBUG_LEVEL > 21
# ifndef PROXY_DEBUG
#  define PROXY_DEBUG
# endif
#endif

#define CONNECTION_REFUSED "\
HTTP/1.0 500 Connection refused by remote host\r\n\
Content-type: text/html\r\n\
\r\n\
<title>Roxen internal error</title>\n\
<h1>Proxy request failed</h1>\
<hr>\
<font size=+2><i>Host unknown or connection refused</i></font>\
<hr>\
<font size=-2><a href=http://roxen.com/>"+roxen->version()+"</a></font>"

inherit "module";
inherit "socket";
inherit "roxenlib";

#include "base_server/proxyauth.pike"

program filep = (program)"/precompiled/file";

multiset requests=(<>);
object logfile;

function nf=lambda(){};

mapping ftp_connections=([]);
multiset dataports=(<>);
int serial=0;
mapping request_port=([]);

void init_proxies();

void start()
{
  string pos;
  pos=QUERY(mountpoint);
  init_proxies();
  if(strlen(pos)>2 && (pos[-1] == pos[-2]) && pos[-1] == '/')
    set("mountpoint", pos[0..strlen(pos)-2]); // Evil me..

  if(logfile) 
    destruct(logfile);

  if(!strlen(QUERY(logfile)))
    return;

#ifdef PROXY_DEBUG
  perror("FTP gateway online.\n");
#endif

  if(QUERY(logfile) == "stdout")
  {
    logfile=stdout;
  } else if(QUERY(logfile) == "stderr") {
    logfile=stderr;
  } else {
    if(logfile=open(QUERY(logfile), "wac"))
      mark_fd(logfile->query_fd(),"FTP gateway logfile ("+QUERY(logfile)+")")
	;
  }
}

void do_write(string host, string oh, string id, string more)
{
  if(!host)     host=oh;
  logfile->write("ftp://" + host + ":" + id + "\t" + more + "\n");
}

void log(string file, string more)
{
  string host, rest;

  if(!logfile) return;
  sscanf(file, "%s:%s", host, rest);
  roxen->ip_to_host(host, do_write, host, rest, more);
}


array proxies=({});
void init_proxies()
{
  string foo;
  array err;

  proxies = ({ });
  foreach(QUERY(Proxies)/"\n", foo)
  {
    array bar;
    if(!strlen(foo) || foo[0] == '#')
      continue;
    
    bar = replace(foo, "\t", " ")/" " -({ "" });
    if(sizeof(bar) < 3) continue;
    if(err=catch(proxies += ({ ({ Regexp(bar[0])->match, 
				  ({ bar[1], (int)bar[2] }) }) })))
      report_error("Syntax error in regular expression in gateway: "
                   +bar[0]+"\n"+err[0]);
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
  defvar("logfile", GLOBVAR(logdirprefix)+
	 short_name(roxen->current_configuration->name)+"/ftp_proxy_log",
	 "Logfile", TYPE_FILE,  "Empty the field for no log at all");
  
  defvar("mountpoint", "ftp:/", "Location", TYPE_LOCATION,
	 "By default, this is http:/. If you set anything else, all "
	 "normal WWW-clients will fail. But, other might be useful"
	 ", like /http/. if you set this location, a link formed like "
	 " this: &lt;a href=\"/http/\"&lt;my.www.server&gt;/a&gt; will enable"
	 " accesses to local WWW-servers through a firewall.<p>"
	 "Please consider security, though.");
  
  defvar("Proxies", "", "Remote gateway regular expressions", TYPE_TEXT_FIELD,
	 "Here you can add redirects to remote gateways. If a file is "
	 "requested from a host matching a pattern, the gateway will query the "
	 "Ftp gateway server at the host and port specified.<p> "
	 "Hopefully, that gateway will then connect to the remote ftp server.<br>"
	 "Currently, <b>remote gateway has to be a http-ftp gateway</b> like this one."
	 "<p>"
	 "Example:<hr noshade>"
	 "<pre>"
	 "# All hosts inside *.rydnet.lysator.liu.se has to be\n"
	 "# accessed through lysator.liu.se\n"
	 ".*\\.rydnet\\.lysator\\.liu\\.se        130.236.253.11  21\n"
	 "</pre>"
	 "Please note that this <b>must</b> be "
	 "<a href=$configurl/regexp.html>Regular Expressions</a>.");

  defvar("method", "Active", "FTP transfer method", TYPE_STRING_LIST,
	 "What method to use to transfer files. ",
	 ({"Active","Passive"}));

  defvar("keeptime", 60, "Connection timeout", TYPE_INT,
	 "How long time in <b>seconds</b> a connection to a ftp server is kept without usage before "+
	 "it's killed");
  defvar("portkeeptime", 60, "Port timeout", TYPE_INT,
	 "How long time in <b>seconds</b> a dataport is kept open without usage before closage");
  defvar("icons", "Yes", "Icons", TYPE_STRING_LIST,
	 "Icons in directory listnings",({"Yes","No"}));
//  defvar("logo", "Yes", "Roxen logo", TYPE_STRING_LIST,
//	 "Show a Roxen logo in the right-up corner on directories",({"Yes","No"}));
  defvar("hold", "Yes", "Hold until response", TYPE_STRING_LIST,
	 "Hold data transfer until response from server; "+
	 "if the server sends file size, size will be sent to the http client. "+
	 "This may slow down a minimum of time.",({"Yes","No"}));
  defvar("connection_timeout", 120, "Connection timeout", TYPE_INT,
	 "Time in seconds before a <i>connection attempt</i> is retried (!).");
  defvar("data_connection_timeout", 30, "Data connection timeout", TYPE_INT,
	 "Time in seconds before a <i>data connection</i> is timeouted and cancelled.");
  defvar("save_dataports", "No", "Save dataports", TYPE_STRING_LIST,
	 "Some ftpd's have problems when the same port is reused. Try this out on your own. :)",
	 ({"Yes","No"}));
  defvar("server_info", "Yes", "Show server information", TYPE_STRING_LIST,
	 "Should the gateway show information that the server gives at point of login at the bottom of directory listnings?",
	 /*                  (    ((                              )                 )    (                               ) */
	 ({"Yes","No"}));
}

mixed *register_module()
{
  return 
    ({  MODULE_PROXY|MODULE_LOCATION, 
	  "FTP gateway", 
	  "(soon caching) FTP gateway", 
	  });
}

string query_location()  { return QUERY(mountpoint); }

string status()
{
  string res="";
  object foo;
  int total;

  res += "<h2>Current connections: "+sizeof(requests-(<0>))+"</h2>";
  foreach( indices(requests), foo )
     if(objectp(foo))
	res += foo->comment() + "<br>\n";
#if 0
  res += "<h2>Server connections unused: "+sizeof(ftp_connections)+"</h2>";

  foreach( indices(ftp_connections), foo )
    res += foo + ":"+sizeof(ftp_connections[foo])+"<br>\n";
#endif
  res += "<h2>Ports unused: "+sizeof(dataports)+"</h2>";

  return res;
}

string process_request(object id, int is_remote)
{
  string url;
  if(!id) return 0;
}

void connected_to_server(object o, string file, object id, int is_remote)
{
  object new_request;
  
  if(!o)
  {
    id->end(CONNECTION_REFUSED);
    return;
  }

#ifdef PROXY_DEBUG
  perror("FTP PROXY: Connected.\n");
#endif

  new_request=((program)"struct/proxy_request")();
  if(o->query_address())
  {
    string to_send;
    to_send=replace(id->raw, "\n", "\r\n");
    if(!to_send)
    {
      id->do_not_disconnect = 0;  
      id->disconnect();

      log(file, "Client abort");
      destruct(new_request);
      return;
    }
    log(file, "FTP remote gateway: New");
    o->write(to_send);
    new_request->assign(o, file, id, 0);
    id->disconnect();
  } else {
    log(file, "FTP remote gateway: Cache");
    new_request->assign(o, file, id, 1);
  }
  
  if(objectp(new_request)) requests[new_request] = 1;
}

array is_remote_proxy(string hmm)
{
  array tmp;
  foreach(proxies, tmp) if(tmp[0](hmm)) return tmp[1];
}

mixed|mapping find_file( string f, object id )
{
  string host, file, key, user;
  mixed tmp;
  array more;
  int port;
  
  f=id->raw_url[strlen(QUERY(mountpoint))+1 .. 100000];
#ifdef PROXY_DEBUG
  perror("FTP PROXY: Request for "+f+"\n");
#endif
  
  /***********
    insert user magic here
    ************/
   
  if(sscanf(f, "%[^:/]:%d/%s", host, port, file) < 2)
  {
    if(sscanf(f, "%[^/]/%s", host, file) < 2)
    {
      if(strstr(f, "/") == -1)
      {
	host = f;
	file="/";
      } else {
	report_debug("I cannot find a hostname and a filename in "+f+"\n");
	return 0; /* This is not a proxy request. */
      }
    }
    port=21; /* Default FTP port. Really! :-) */
  }
  if(tmp = proxy_auth_needed(id))
    return tmp;

  sscanf(host, "%s@%s", user, host);
  
  if(!file)
    file="/";
  
  key = host+":"+port+"/"+file;
  id->do_not_disconnect = 1;  
  if(more = is_remote_proxy(host))
    async_connect(more[0], more[1], connected_to_server,  key, id, 1);
  
#undef RECOMPILE 

#ifdef RECOMPILE
  requests[compile_file("lpc/struct/ftp_gateway_request.pike")
	  (id, this_object(),host,port,file, user)]=1;
#else
  requests[((program)"struct/ftp_gateway_request")
	  (id,this_object(),host,port,file, user)]=1;
#endif
  return http_pipe_in_progress();
}	  

string comment() { return QUERY(mountpoint); }

/************ optimization ************/

object ftp_connection(string hostid)
{
   multiset lo;
   mixed o,*oa;

   if (!(lo=ftp_connections[hostid])) return 0; /* no list */
   if (!sizeof(oa=indices(lo))) return 0; /* empty list */
   lo[o=oa[0]]=0; /* remove from list */
   return o[0..1];
}

void remove_connection(string hostid,mixed m)
{
   if (!ftp_connections[hostid][m]) return;
   ftp_connections[hostid][m]=0;
   if (!sizeof(indices(ftp_connections[hostid])))
      m_delete(ftp_connections,hostid);
   if (!objectp(m[1])) return;
   m[1]->close();
   destruct(m[1]);
}


void save_connection(string hostid,object server,string info)
{
   mixed m;

   if (!(ftp_connections[hostid])) ftp_connections[hostid]=(<m=({server,info,serial++})>);
   else ftp_connections[hostid][m=({server,info,serial++})]=1;
   call_out(remove_connection,QUERY(keeptime),hostid,m);
   server->set_id(server);
   server->set_nonblocking(lambda() {},0,
			   lambda(object serv) { if (objectp(serv)) { serv->set_id(0); destruct(serv); } });
}

void remove_dataport(mixed m)
{
   if (!dataports[m]) return;
   if (!objectp(m[1])) return;
   dataports[m]=0;

   if (objectp(m[1])) destruct(m[1]);
}

void dataport_accept(object u)
{
  if (request_port[u])
    (request_port[u])(u);
  else 
  {
    object con;
    perror("FTP GATEWAY: accept on forgotten port, cancelling connection\n");
    con=u->accept();
    if (con) { destruct(con); }
  }
}

mixed create_dataport(function acceptfunc)
{
  int i, ii;
  object dataport;
  dataport=Port();
  ii=random(20000)+20000;
  for (i=0; i<500&&ii<65535; i++)
  {
    if (!dataport->bind(ii,dataport_accept,0))
      ii+=random(200);
    else break;
  }
  if (i>=500||ii>65535)
  {
    return 0;
  }
  request_port[dataport]=acceptfunc;
  return ({ii,dataport});
}

mixed get_dataport(function acceptfunc)
{
   mixed o,*oa;
   for (;;)
   {
      if (!sizeof(oa=indices(dataports))) return create_dataport(acceptfunc); /* no dataports left */
      dataports[o=oa[0]]=0; /* delete */
      if (objectp(o[1])) 
      {
	 request_port[o[1]]=acceptfunc;
	 return o[0..1];
      }
   }
}

void save_dataport(mixed *m) /* ({portno,object}) */
{
   if (QUERY(save_dataports)=="Yes")
   {
      m+=({serial++});
      dataports[m]=1;
      m_delete(request_port,m[1]);
      call_out(remove_dataport,QUERY(portkeeptime),m);
   }
   else destruct(m[1]);
}





