// This is a roxen module. Copyright © 1996 - 1998, Idonex AB.

constant cvs_version = "$Id: http.pike,v 1.74 1998/03/26 11:36:19 per Exp $";
// HTTP protocol module.
#include <config.h>
private inherit "roxenlib";
// int first;
#if efun(gethrtime)
# define HRTIME() gethrtime()
# define HRSEC(X) ((int)((X)*1000000))
# define SECHR(X) ((X)/(float)1000000)
#else
# define HRTIME() (predef::time())
# define HRSEC(X) (X)
# define SECHR(X) ((float)(X))
#endif

#ifdef PROFILE
int req_time = HRTIME();
#endif

#ifdef FD_DEBUG
#define MARK_FD(X) catch(mark_fd(my_fd->query_fd(), (X)+" "+remoteaddr))
#else
#define MARK_FD(X)
#endif

constant decode=roxen->decode;
constant find_supports=roxen->find_supports;
constant version=roxen->version;
constant handle=roxen->handle;
constant _query=roxen->query;
constant thepipe = roxen->pipe;
constant _time=predef::time;

private static array(string) cache;
private static int wanted_data, have_data;

object conf;

#include <roxen.h>
#include <module.h>

#undef QUERY
#if constant(cpp)
#define QUERY(X)	_query( #X )
#else /* !constant(cpp) */
#define QUERY(X) 	_query("X")
#endif /* constant(cpp) */

int time = predef::time(1);
string raw_url;
int do_not_disconnect;

mapping (string:string) variables = ([ ]);
mapping (string:mixed) misc = ([ ]);
mapping (string:string) cookies = ([ ]);

multiset   (string) prestate     = (< >);
multiset   (string) config       = (< >);
multiset   (string) supports;
multiset (string) pragma    = (< >);

string remoteaddr, host;

array  (string) client;
array  (string) referer;

mapping file;

object my_fd; /* The client. */
object pipe;

// string range;
string prot;
string clientprot;
string method;

string realfile, virtfile;
string rest_query="";
string raw;
string query;
string not_query;
string extra_extension = ""; // special hack for the language module
string data, leftovers;
array (int|string) auth;
string rawauth, realauth;
string since;

// Parse a HTTP/1.1 HTTP/1.0 or 0.9 request, including form data and
// state variables.  Return 0 if more is expected, 1 if done, and -1
// if fatal error.

void end(string|void a,int|void b);

private void setup_pipe()
{
  if(!my_fd) 
  {
    end();
    return;
  }
  if(!pipe) pipe=thepipe();
}

void send(string|object what, int|void len)
{
  if(!what) return;
  if(!pipe) setup_pipe();
  if(!pipe) return;
  if(stringp(what))  pipe->write(what);
  else               pipe->input(what,len);
}

string scan_for_query( string f )
{
  if(sscanf(f,"%s?%s", f, query) == 2)
  {
    string v, a, b;

    foreach(query / "&", v)
      if(sscanf(v, "%s=%s", a, b) == 2)
      {
	a = http_decode_string(replace(a, "+", " "));
	b = http_decode_string(replace(b, "+", " "));
	
	if(variables[ a ])
	  variables[ a ] +=  "\0" + b;
	else
	  variables[ a ] = b;
      } else
	if(strlen( rest_query ))
	  rest_query += "&" + http_decode_string( v );
	else
	  rest_query = http_decode_string( v );
    rest_query=replace(rest_query, "+", "\000"); /* IDIOTIC STUPID STANDARD */
  } 
  return f;
}


private int really_set_config(array mod_config)
{
  string url, m;
  string base;
  base = conf->query("MyWorldLocation")||"/";
  if(supports->cookies)
  {
#ifdef REQUEST_DEBUG
    perror("Setting cookie..\n");
#endif
    if(mod_config)
      foreach(mod_config, m)
	if(m[-1]=='-')
	  config[m[1..]]=0;
	else
	  config[m]=1;
      
    if(sscanf(replace(raw_url,({"%3c","%3e","%3C","%3E" }),
		      ({"<",">","<",">"})),"/<%*s>/%s",url)!=2)
      url = "/";

    if ((base[-1] == '/') && (strlen(url) && url[0] == '/')) {
      url = base + url[1..];
    } else {
      url = base + url;
    }

    my_fd->write(prot + " 302 Config in cookie!\r\n"
		 "Set-Cookie: "
		  + http_roxen_config_cookie(indices(config) * ",") + "\r\n"
		 "Location: " + url + "\r\n"
		 "Content-Type: text/html\r\n"
		 "Content-Length: 0\r\n\r\n");
  } else {
#ifdef REQUEST_DEBUG
    perror("Setting {config} for user without Cookie support..\n");
#endif
    if(mod_config)
      foreach(mod_config, m)
	if(m[-1]=='-')
	  prestate[m[1..]]=0;
	else
	  prestate[m]=1;
      
    if (sscanf(replace(raw_url, ({ "%3c", "%3e", "%3C", "%3E" }), 
		       ({ "<", ">", "<", ">" })),   "/<%*s>/%s", url) == 2) {
      url = "/" + url;
    }
    if (sscanf(replace(url, ({ "%28", "%29" }), ({ "(", ")" })),
	       "/(%*s)/%s", url) == 2) {
      url = "/" + url;
    }

    url = add_pre_state(url, prestate);

    if (base[-1] == '/') {
      url = base + url[1..];
    } else {
      url = base + url;
    }

    my_fd->write(prot + " 302 Config In Prestate!\r\n"
		 "\r\nLocation: " + url + "\r\n"
		 "Content-Type: text/html\r\n"
		 "Content-Length: 0\r\n\r\n");
  }
  return -2;
}

private static mixed f, line;

private int parse_got(string s)
{
  multiset (string) sup;
  array mod_config;
  string a, b, linename, contents;
  int config_in_url;

//  roxen->httpobjects[my_id] = "Parsed data...";
  raw = s;

  if (!line) {
    int start = search(s, "\r\n");

    if ((< -1, 0 >)[start]) {
      // Not enough data, or malformed request.
      return ([ -1:0, 0:2 ])[start];
    }
    line = s[..start-1];

    // Parse the command
    start = search(line, " ");
    if (start != -1) {
      method = upper_case(line[..start-1]);

      int end = search(reverse(line[start+1..]), " ");
      if (end != -1) {
	f = line[start+1..sizeof(line)-(end+2)];
	clientprot = line[sizeof(line)-end..];
	if (clientprot != "HTTP/0.9") {
	  prot = "HTTP/1.0";

	  // Check that the request is complete
	  int end;
	  if ((end = search(s, "\r\n\r\n")) == -1) {
	    // No, we need more data.
	    return 0;
	  }
	  data = s[end+4..];
	  s = s[sizeof(line)+2..end-1];
	} else {
	  prot = clientprot;
	  data = s[sizeof(line)+2..];
	  s = "";	// No headers.
	}
      } else {
	f = line[start+1..];
	prot = clientprot = "HTTP/0.9";
	data = s[sizeof(line)+2..];
	s = "";		// No headers.
      }
    } else {
      method = upper_case(line);
      f = "/";
      prot = clientprot = "HTTP/0.9";
    }
  } else {
    // HTTP/1.0 or later
    // Check that the request is complete
    int end;
    if ((end = search(s, "\r\n\r\n")) == -1) {
      // No, we still need more data.
      return 0;
    }
    data = s[end+4..];
    s = s[sizeof(line)+2..end-1];
  }


  if(method == "PING")
  { 
    my_fd->write("PONG\n"); 
    return -2; 
  }

  raw_url    = f;
  time       = _time(1);
  

  if(!remoteaddr)
  {
    if(my_fd) catch(remoteaddr = ((my_fd->query_address()||"")/" ")[0]);
    if(!remoteaddr) {
      end();
      return 0;
    }
  }

  f = scan_for_query( f );
//  f = http_decode_string( f );

  if (sscanf(f, "/<%s>/%s", a, f)==2)
  {
    config_in_url = 1;
    mod_config = (a/",");
    f = "/"+f;
  }
  
  if ((sscanf(f, "/(%s)/%s", a, f)==2) && strlen(a))
  {
    prestate = aggregate_multiset(@(a/","-({""})));
    f = "/"+f;
  }
  
  not_query = simplify_path(http_decode_string(f));

  if(sizeof(s)) {
//    sscanf(s, "%s\r\n\r\n%s", s, data);

//     s = replace(s, "\n\t", ", ") - "\r"; 
//     Handle rfc822 continuation lines and strip \r
  
    foreach(s/"\r\n" - ({ "" }), line)
    {
      linename=contents=0;
      sscanf(line, "%s:%s", linename, contents);
      if(linename&&contents)
      {
	linename=lower_case(linename);
	sscanf(contents, "%*[\t ]%s", contents);
	
	if(strlen(contents))
	{
	  switch (linename) {
	  case "content-length":
	    misc->len = (int)(contents-" ");
	    if(!misc->len) continue;
	    if(method == "POST")
	    {
	      if(!data) data="";
	      int l = misc->len-1; /* Length - 1 */
	      wanted_data=l;
	      have_data=strlen(data);

	      if(strlen(data) <= l) // \r are included. 
	      {
		return 0;
	      }
	      leftovers = data[l+1..];
	      data = data[..l];
	      switch(lower_case(((misc["content-type"]||"")/";")[0]-" "))
	      {
	      default: // Normal form data.
		string v;
		if(l < 200000)
		{
		  foreach(replace(data-"\n", "+", " ")/"&", v)
		    if(sscanf(v, "%s=%s", a, b) == 2)
		    {
		      a = http_decode_string( a );
		      b = http_decode_string( b );
		     
		      if(variables[ a ])
			variables[ a ] +=  "\0" + b;
		      else
			variables[ a ] = b;
		    }
		}
		break;

	      case "multipart/form-data":
//		perror("Multipart/form-data post detected\n");
		object messg = MIME.Message(data, misc);
		foreach(messg->body_parts, object part) {
		  if(part->disp_params->filename) {
		    variables[part->disp_params->name]=part->getdata();
		    variables[part->disp_params->name+".filename"]=
		      part->disp_params->filename;
		    if(!misc->files)
		      misc->files = ({ part->disp_params->name });
		    else
		      misc->files += ({ part->disp_params->name });
		  } else {
		    variables[part->disp_params->name]=part->getdata();
		  }
		}
		break;
	      }
	    }
	    break;
	  
	  case "authorization":
	    string *y;
	    rawauth = contents;
	    y = contents /= " ";
	    if(sizeof(y) < 2)
	      break;
	    y[1] = decode(y[1]);
	    realauth=y[1];
	    if(conf && conf->auth_module)
	      y = conf->auth_module->auth( y, this_object() );
	    auth=y;
	    break;
	  
	  case "proxy-authorization":
	    string *y;
	    y = contents /= " ";
	    if(sizeof(y) < 2)
	      break;
	    y[1] = decode(y[1]);
	    if(conf && conf->auth_module)
	      y = conf->auth_module->auth( y, this_object() );
	    misc->proxyauth=y;
	    break;
	  
	  case "pragma":
	    pragma|=aggregate_multiset(@replace(contents, " ", "")/ ",");
	    break;

	  case "user-agent":
	    if(!client)
	    {
	      sscanf(contents, "%s via", contents);
	      client = contents/" " - ({ "" });
	    }
	    break;

	    /* Some of M$'s non-standard user-agent info */
	  case "ua-pixels":	/* Screen resolution */
	  case "ua-color":	/* Color scheme */
	  case "ua-os":		/* OS-name */
	  case "ua-cpu":	/* CPU-type */
	    /* None of the above are interresting or useful for us */
	    /* IGNORED */
	    break;

	  case "referer":
	    referer = contents/" ";
	    break;
	    
	   case "extension":
#ifdef DEBUG
	    perror("Client extension: "+contents+"\n");
#endif
	    
	   case "connection":
	    contents = lower_case(contents);
	    
	   case "content-type":
	    misc[linename] = lower_case(contents);
	    break;

	  case "accept":
	  case "accept-encoding":
	  case "accept-charset":
	  case "accept-language":
	  case "session-id":
	  case "message-id":
	  case "from":
	    if(misc[linename])
	      misc[linename] += (contents-" ") / ",";
	    else
	      misc[linename] = (contents-" ") / ",";
	    break;

	  case "cookie": /* This header is quite heavily parsed */
	    string c;
	    misc->cookies = contents;
	    foreach(contents/";", c)
	    {
	      string name, value;
	      while(c[0]==' ') c=c[1..];
	      if(sscanf(c, "%s=%s", name, value) == 2)
	      {
		value=http_decode_string(value);
		name=http_decode_string(name);
		cookies[ name ]=value;
		if(name == "RoxenConfig" && strlen(value))
		{
		  array tmpconfig = value/"," + ({ });
		  string m;

		  if(mod_config && sizeof(mod_config))
		    foreach(mod_config, m)
		      if(!strlen(m))
		      { continue; } /* Bug in parser force { and } */
		      else if(m[0]=='-')
			tmpconfig -= ({ m[1..] });
		      else
			tmpconfig |= ({ m });
		  mod_config = 0;
		  config = aggregate_multiset(@tmpconfig);
		}
	      }
	    }
	    break;

	  case "host":
	  case "proxy-connection":
	  case "security-scheme":
	    misc[linename] = contents;
	    break;	    

	  case "proxy-by":
	  case "proxy-maintainer":
	  case "proxy-software":
	  case "mime-version":
	    break;
	    
	  case "if-modified-since":
	    since=contents;
	    break;
	    
	  case "via":
	  case "cache-control":
	  case "negotiate":
	  case "forwarded":
	    misc[linename]=contents;
	    break;

#ifdef DEBUG
	  default:
	    /*   x-* headers are experimental.    */
	    if(linename[0] != 'x')
	      perror("Unknown header: `"+linename+"' -> `"+contents+"'\n");
#endif
	  }
	}
      }
    } 
  }
  if(!client) client = ({ "unknown" });
  if(!supports)
    supports = find_supports(lower_case(client*" "));
  if(!referer) referer = ({ });
  if(misc->proxyauth) {
    // The Proxy-authorization header should be removed... So there.
    mixed tmp1,tmp2;
    
    foreach(tmp2 = (raw / "\n"), tmp1) {
      if(!search(lower_case(tmp1), "proxy-authorization:"))
	tmp2 -= ({tmp1});
    }
    raw = tmp2 * "\n"; 
  }

  if(config_in_url) {
    return really_set_config( mod_config );
  }
  if(!supports->cookies)
    config = prestate;
  else
    if(conf
       && QUERY(set_cookie)
       && !cookies->RoxenUserID && strlen(not_query)
       && not_query[0]=='/' && method!="PUT")
    {
      if (!(QUERY(set_cookie_only_once) &&
	    cache_lookup("hosts_for_cookie",remoteaddr))) {
	misc->moreheads = ([ "Set-Cookie":http_roxen_id_cookie(), ]);
      }
      if (QUERY(set_cookie_only_once))
	cache_set("hosts_for_cookie",remoteaddr,1);
    }
  return 1;	// Done.
}

void disconnect()
{
  file = 0;
  MARK_FD("my_fd in HTTP disconnected?");
  if(do_not_disconnect)return;
  destruct();
}

void end(string|void s, int|void keepit)
{
  pipe = 0;
#ifdef PROFILE
  if(conf)
  {
    float elapsed = SECHR(HRTIME()-req_time);
    array p;
    if(!(p=conf->profile_map[not_query]))
      p = conf->profile_map[not_query] = ({0,0.0,0.0});
    conf->profile_map[not_query][0]++;
    p[1] += elapsed;
    if(elapsed > p[2]) p[2]=elapsed;
  }
#endif

#ifdef KEEP_ALIVE
  if(keepit &&
     (!(file->raw || file->len <= 0))
     && (misc->connection || (prot == "HTTP/1.1"))
     && my_fd)
  {
    // Now.. Transfer control to a new http-object. Reset all variables etc..
    object o = object_program(this_object())();
    o->remoteaddr = remoteaddr;
    o->supports = supports;
    o->host = host;
    o->client = client;
    MARK_FD("HTTP kept alive");
    object fd = my_fd;
    my_fd=0;
    if(s) leftovers += s;
    o->chain(fd,conf,leftovers);
    disconnect();
    return;
  }
#endif

  if(objectp(my_fd))
  {
    MARK_FD("HTTP closed");
    catch {
      my_fd->set_close_callback(0);
      my_fd->set_read_callback(0);
      my_fd->set_blocking();
      if(s) my_fd->write(s);
      my_fd->close();
      destruct(my_fd);
    };
    my_fd = 0;
  }
  disconnect();  
}

static void do_timeout(mapping foo)
{
  int elapsed = _time()-time;
  if(elapsed >= 30)
  {
    MARK_FD("HTTP timeout");
    end("HTTP/1.0 408 Timeout\r\n"
	"Content-type: text/plain\r\n"
	"Server: Roxen Challenger\r\n"
	"\r\n"
	"Your connection timed out.\n"
	"Please try again.\n");
  } else {
    // premature call_out... *¤#!"
    call_out(do_timeout, 10);
    MARK_FD("HTTP premature timeout");
  }
}

static string last_id, last_from;
string get_id(string from)
{
  if(last_from == from) return last_id;
  last_from=from;
  catch {
    object f = open(from,"r");
    string id;
    id = f->read(200);
    if(sscanf(id, "%*s$"+"Id: %*s,v %s ", id) == 3)
      return last_id=" (version "+id+")";
  };
  last_id = "";
  return "";
}

void add_id(array to)
{
  foreach(to[1], array q)
    if(stringp(q[0]))
      q[0]+=get_id(q[0]);
}

string format_backtrace(array bt)
{
  // first entry is always the error, 
  // second is the actual function, 
  // rest is backtrace.

  string reason = roxen->diagnose_error( bt );

  string res = ("<title>Internal Server Error</title>"
		"<body bgcolor=white text=black link=darkblue vlink=darkblue>"
		"<table width=\"100%\" border=0 cellpadding=0 cellspacing=0>"
		"<tr><td valign=bottom align=left><img border=0 "
		"src=\"/internal-roxen-roxen-icon-gray\" alt=\"\"></td>"
		"<td>&nbsp;</td><td width=100% height=39>"
		"<table cellpadding=0 cellspacing=0 width=100% border=0>"
		"<td width=\"100%\" align=right valigh=center height=28>"
		"<b><font size=+1>Failed to complete your request</font>"
		"</b></td></tr><tr width=\"100%\"><td bgcolor=\"#003366\" "
		"align=right height=12 width=\"100%\"><font color=white "
		"size=-2>Internal Server Error&nbsp;&nbsp;</font></td>"
		"</tr></table></td></tr></table>");

  res += ("<p>\n\n"
	  "<font size=+2 color=darkred>"
	  "<img alt=\"\" hspace=10 align=left src=/internal-roxen-manual-warning>"
	  +bt[0]+"</font><br>\n"
	  "The error occured while calling <b>"+bt[1]+"</b><p>\n"
	  +(reason?reason+"<p>":"")
	  +"<br><h3><br>Complete Backtrace:</h3>\n\n<ol>");
  int q = sizeof(bt)-1;
  foreach(bt[1..], string line)
  {
    string fun, args, where, fo;
    if(sscanf(html_encode_string(line), "%s(%s) in %s", fun, args, where) == 3)
    {
      sscanf(where, "%*s in %s", fo);
      line += get_id(fo);
      res += ("<li value="+(q--)+"> "+(line-(getcwd()+"/"))+"<p>\n");
    } else
      res += "<li value="+(q--)+"> <b><font color=darkgreen>"+line+"</font></b><p>\n";
  }
  res += ("</ul><p><b><a href=\"/(plain)"+http_encode_string(not_query)+
	  (query?"?"+http_encode_string(query):"")+"\">"+
	  "Generate text-only version of this error message, for bug reports"+
	  "</a></b>");
  return res+"</body>";
}

string generate_bugreport(array from)
{
  add_id(from);
  return ("<pre>"+html_encode_string("Roxen version: "+version()+
	  (roxen->real_version != version()?" ("+roxen->real_version+")":"")+
	  "\nRequested URL: "+not_query+(query?"?"+query:"")+"\n"
	  "\nError: "+
	  describe_backtrace(from)-(getcwd()+"/")+
	  "\n\nRequest data:\n"+raw));
}

void internal_error(array err)
{
  if(QUERY(show_internals)) {
    if(prestate->plain) 
    {
      file =  http_low_answer(500,generate_bugreport(err));
      return;
    }
    array(string) bt = (describe_backtrace(err)/"\n") - ({""});
    file = http_low_answer(500, format_backtrace(bt));
  } else {
    file = http_low_answer(500, "<h1>Error: The server failed to "
			   "fulfill your query, due to an internal error.</h1>");
  }
  
  report_error("Internal server error: " +
	       describe_backtrace(err) + "\n");
}

int wants_more()
{
  return !!cache;
}

constant errors =
([
  200:"200 OK",
  201:"201 URI follows",
  202:"202 Accepted",
  203:"203 Provisional Information",
  204:"204 No Content",
  
  300:"300 Moved",
  301:"301 Permanent Relocation",
  302:"302 Temporary Relocation",
  303:"303 Temporary Relocation method and URI",
  304:"304 Not Modified",

  400:"400 Bad Request",
  401:"401 Access denied",
  402:"402 Payment Required",
  403:"403 Forbidden",
  404:"404 No such file or directory.",
  405:"405 Method not allowed",
  407:"407 Proxy authorization needed",
  408:"408 Request timeout",
  409:"409 Conflict",
  410:"410 This document is no more. It has gone to meet it's creator. It is gone. It will not be coming back. Give up. I promise. There is no such file or directory.",
  
  500:"500 Internal Server Error.",
  501:"501 Not Implemented",
  502:"502 Gateway Timeout",
  503:"503 Service unavailable",
  
  ]);


void do_log()
{
  MARK_FD("HTTP logging"); // fd can be closed here
  if(conf)
  {
    int len;
    if(pipe) file->len = pipe->bytes_sent();
    if(conf)
    {
      if(file->len > 0) conf->sent+=file->len;
      conf->log(file, this_object());
    }
  }
  end(0,1);
  return;
}

void handle_request( )
{
  mixed *err;
  int tmp;
  function funp;
  mapping heads;
  string head_string;
  object thiso=this_object();

  remove_call_out(do_timeout);
  MARK_FD("HTTP handling request");

  if(conf)
  {
//  perror("Handle request, got conf.\n");
    object oc = conf;
    foreach(conf->first_modules(), funp) 
    {
      if(file = funp( thiso)) break;
      if(conf != oc) {
	handle_request();
	return;
      }
    }    
    if(!file) err=catch(file = conf->get_file(thiso));

    if(err) internal_error(err);

    if(!mappingp(file))
      foreach(conf->last_modules(), funp) if(file = funp(thiso)) break;
  } else if(err=catch(file = roxen->configuration_parse( thiso ))) {
    if(err==-1) return;
    internal_error(err);
  }

  if(!mappingp(file))
  {
    if(misc->error_code)
      file = http_low_answer(misc->error_code, errors[misc->error]);
    else if(method != "GET" && method != "HEAD" && method != "POST")
      file = http_low_answer(501, "Not implemented.");
    else
      if(catch {
	file=http_low_answer(404,
			     replace(parse_rxml(conf->query("ZNoSuchFile"),
						thiso),
				     ({"$File", "$Me"}), 
				     ({not_query,
				       conf->query("MyWorldLocation")})));})
	internal_error(err);
  } else {
    if((file->file == -1) || file->leave_me) 
    {
      if(do_not_disconnect) {
	file = 0;
	pipe = 0;
	return;
      }
      my_fd = 0; file = 0;
      return;
    }

    if(file->type == "raw")  file->raw = 1;
    else if(!file->type)     file->type="text/plain";
  }
  
  if(!file->raw && prot != "HTTP/0.9")
  {
    string h;
    heads=
      (["MIME-Version":(file["mime-version"] || "1.0"),
	"Content-type":file["type"],
	"Server":replace(version(), " ", "·"),
	"Date":http_date(time) ]);    

    if(file->encoding)
      heads["Content-Encoding"] = file->encoding;
    
    if(!file->error) 
      file->error=200;
    
    if(file->expires)
      heads->Expires = http_date(file->expires);

    if(!file->len)
    {
      if(objectp(file->file))
	if(!file->stat && !(file->stat=misc->stat))
	  file->stat = (int *)file->file->stat();
      array fstat;
      if(arrayp(fstat = file->stat))
      {
	if(file->file && !file->len)
	  file->len = fstat[1];
    
    
	heads["Last-Modified"] = http_date(fstat[3]);
	
	if(since)
	{
	  if(is_modified(since, fstat[3], fstat[1]))
	  {
	    file->error = 304;
	    file->file = 0;
	    file->data="";
// 	    method="";
	  }
	}
      }
      if(stringp(file->data)) 
	file->len += strlen(file->data);
    }
    
    if(mappingp(file->extra_heads)) {
      heads |= file->extra_heads;
    }

    if(mappingp(misc->moreheads)) {
      heads |= misc->moreheads;
    }
    
    array myheads = ({prot+" "+(file->rettext||errors[file->error])});
    foreach(indices(heads), h)
      if(arrayp(heads[h]))
	foreach(heads[h], tmp)
	  myheads += ({ `+(h,": ", tmp)});
      else
	myheads +=  ({ `+(h, ": ", heads[h])});
    

    if(file->len > -1)
      myheads += ({"Content-length: " + file->len });
#ifdef KEEP_ALIVE
    myheads += ({ "Connection: Keep-Alive" });
#endif
    head_string = (myheads+({"",""}))*"\r\n";
    
    if(conf) conf->hsent+=strlen(head_string||"");
  }

  if(method == "HEAD")
  {
    file->file = 0;
    file->data="";
  }
MARK_FD("HTTP handled");


#ifdef KEEP_ALIVE
  if(!leftovers) leftovers = data||"";
#endif

  if(file->len > 0 && file->len < 2000)
  {
    my_fd->write(head_string + (file->file?file->file->read():file->data));
    do_log();
    return;
  }

  if(head_string) send(head_string);

  if(method != "HEAD" && file->error != 304)
    // No data for these two...
  {
    if(file->data && strlen(file->data))
      send(file->data, file->len);
    if(file->file)  
      send(file->file, file->len);
  } else
    file->len = 1; // Keep those alive, please...
  if (pipe) {
    MARK_FD("HTTP really handled, piping");
    pipe->set_done_callback( do_log );
    pipe->output(my_fd);
  } else {
    MARK_FD("HTTP really handled, pipe done");
    do_log();
  }
}

/* We got some data on a socket.
 * ================================================= 
 */
int processed;
void got_data(mixed fooid, string s)
{
  int tmp;
  MARK_FD("HTTP got data");
  remove_call_out(do_timeout);
  call_out(do_timeout, 30); // Close down if we don't get more data 
                         // within 30 seconds. Should be more than enough.
  if(wanted_data)
  {
    if(strlen(s)+have_data < wanted_data)
    {
      cache += ({ s });
      have_data += strlen(s);
      return;
    }
  }
  
  if(cache) 
  {
    s = cache*""+s; 
    cache = 0;
  }
  sscanf(s, "%*[\n\r]%s", s);
  if(strlen(s)) tmp = parse_got(s);

  switch(-tmp)
  { 
   case 0:
    cache = ({ s });		// More on the way.
    return;
    
   case 1:
    end(prot+" 500 Stupid Client Error\r\nContent-Length: 0\r\n\r\n");
    return;			// Stupid request.
    
   case 2:
    end();
    return;
  }

  if(conf)
  {
    conf->received += strlen(s);
    conf->requests++;
  }

  my_fd->set_close_callback(0); 
  my_fd->set_read_callback(0); 
  processed=1;
#ifdef THREADS
  roxen->handle(this_object()->handle_request);
#else
  handle_request();
#endif
}

/* Get a somewhat identical copy of this object, used when doing 
 * 'simulated' requests. */

object clone_me()
{
  object c,t;
  c=object_program(t=this_object())();

// c->first = first;
  c->conf = conf;
  c->time = time;
  c->raw_url = raw_url;
  c->variables = copy_value(variables);
  c->misc = copy_value(misc);
  c->misc->orig = t;

  c->prestate = prestate;
  c->supports = supports;
  c->config = config;

  c->remoteaddr = remoteaddr;
  c->host = host;

  c->client = client;
  c->referer = referer;
  c->pragma = pragma;

  c->cookies = cookies;
  c->my_fd = 0;
  c->prot = prot;
  c->clientprot = clientprot;
  c->method = method;
  
// realfile virtfile   // Should not be copied.  
  c->rest_query = rest_query;
  c->raw = raw;
  c->query = query;
  c->not_query = not_query;
  c->extra_extension = extra_extension;
  c->data = data;
  
  c->auth = auth;
  c->realauth = realauth;
  c->rawauth = rawauth;
  c->since = since;
  return c;
}

void clean()
{
  if(!(my_fd && objectp(my_fd)))
    end();
  else if((_time(1) - time) > 4800) 
    end();
}

void create(object f, object c)
{
  if(f)
  {
    f->set_blocking();
    my_fd = f;
    conf = c;
    MARK_FD("HTTP connection");
    my_fd->set_close_callback(end);
    my_fd->set_read_callback(got_data);
    // No need to wait more than 30 seconds to get more data.
    call_out(do_timeout, 30);
  }
}

void chain(object f, object c, string le)
{
  my_fd = f;
  conf = c;
  do_not_disconnect=-1;
  if(strlen(le)) got_data(0,le);
  if(!my_fd)
  {
    if(do_not_disconnect == -1)
    {
      do_not_disconnect=0;
      disconnect();
    }
  } else {
    if(do_not_disconnect == -1) 
      do_not_disconnect = 0;
    if(!processed) {
      f->set_close_callback(end);
      f->set_read_callback(got_data);
    }
  }
}

// void chain(object fd, object conf, string leftovers)
// {
//   call_out(real_chain,0,fd,conf,leftovers);
// }
                                                                                                                                                                                                                  
