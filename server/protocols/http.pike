// This is a roxen module. (c) Informationsvävarna AB 1996.


string cvs_version = "$Id: http.pike,v 1.16 1997/01/29 07:42:38 per Exp $";
// HTTP protocol module.
#include <config.h>
inherit "roxenlib";
int first;

constant shuffle=roxen->shuffle;
constant decode=roxen->decode;
constant find_supports=roxen->find_supports;
constant version=roxen->version;
constant errors=roxen->errors;
constant handle=roxen->handle;
constant _query=roxen->query;
//constant This = object_program(this_object());

#define SPEED_MAX


function _time=time;
private static array(string) cache;
private static int wanted_data, have_data;

object conf;


#ifdef REQUEST_DEBUG
int kept_alive;
#endif

#include <roxen.h>
#include <module.h>

#undef QUERY
#define QUERY(X) _query("X")

int time;
string raw_url;
int do_not_disconnect = 0;

mapping (string:string) variables = ([ ]);
mapping (string:mixed) misc = ([ ]);

multiset   (string) prestate     = (< >);
multiset   (string) config       = (< >);
multiset   (string) supports     = (< >);

string remoteaddr, host;

array  (string) client      = ({ "Unknown" });
array  (string) referer     = ({ });
multiset   (string) pragma      = (< >);

mapping (string:string) cookies = ([ ]);

mixed file;

object my_fd; /* The client. */
object pipe;

// string range;
string prot;
string method;

string realfile, virtfile;
string rest_query="";
string raw;
string query;
string not_query;
string extra_extension = ""; // special hack for the language module
string data;
array (int|string) auth;
string rawauth, realauth;
string since;

// Parse a HTTP/1.1 HTTP/1.0 or 0.9 request, including form data and
// state variables.  Return 0 if more is expected, 1 if done, and -1
// if fatal error.

void end(string|void);

private void setup_pipe(int noend)
{
  if(!my_fd) return end();
  if(!pipe)  pipe=((program)"/precompiled/pipe")();
#ifdef REQUEST_DEBUG
  perror("REQUEST: Pipe setup.\n");
#endif
//  pipe->output(my_fd);
}

void send(string|object what, int|void noend)
{
  if(!what) return;
  if(!pipe) setup_pipe(noend);

#ifdef REQUEST_DEBUG
  perror("REQUEST: Sending some data\n");
#endif
  if(stringp(what))  pipe->write(what);
  else               pipe->input(what);
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
  } 
  rest_query=replace(rest_query, "+", "\000"); /* IDIOTIC STUPID STANDARD */
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
  
    url = base + url;

    my_fd->write(prot+" 302 Config in cookie!\r\n"
		 "Set-Cookie: "
		 +http_roxen_config_cookie(indices(config)*",")+"\r\n"
		 "Location: "+url+"\r\n"
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
      
    sscanf(replace(raw_url, ({ "%3c", "%3e", "%3C", "%3E" }), 
		   ({ "<", ">", "<", ">" })),   "/<%*s>/%s", url);
    sscanf(replace(url, ({ "%28", "%29" }), ({ "(", ")" })),"/(%*s)/%s", url);

    my_fd->write(prot+" 302 Config In Prestate!\r\n"
		 +"\r\nLocation: "+conf->query("MyWorldLocation")+
		 add_pre_state(url, aggregate_multiset(@prestate))+"\r\n"
		 +"Content-Type: text/html\r\n"
		 +"Content-Length: 0\r\n\r\n");
  }
  return -2;
}

private int parse_got(string s)
{
  multiset (string) sup;
  array mod_config;
  mixed f, line;
  string a, b, linename, contents, real_raw;
  int config_in_url;
  
  real_raw = s;
  s -= "\r"; // I just hate all thoose CR LF.
  
  if(strlen(s) < 3)
    return 0;			// Not finished, I promise.
  
  if(!(s[-1] == '\n' && search(s, "HTTP/") == -1))
    if(search(s, "\n\n") == -1)
      return 0;
  raw = s;
  
  s = replace(s, "\t", " ");
  
  if(sscanf(s,"%s %s %s\n%s", method, f, prot, s) < 4)
  {
    if(sscanf(s,"%s %s\n", method, f) < 2)
      f="";
    s="";
    prot = "HTTP/0.9";
  }
  
  if(!method)
    method = "GET";
  method = upper_case(method);
  if(method == "PING")
  { 
    my_fd->write("PONG\n"); 
    return -2; 
  }

  raw_url    = f;
  time       = _time(1);
  

  if(!remoteaddr)
  {
    catch(remoteaddr = ((my_fd->query_address()||"")/" ")[0]);
    if(!remoteaddr) this_object()->end();
  }

#if 0
  sscanf(f,"%s;%s", f, range);
#endif

  f = scan_for_query( f );
  f = http_decode_string( f );

  if (sscanf(f, "/<%s>%s", a, f))
  {
    config_in_url = 1;
    mod_config = (a/",");
  }
  
  if (sscanf(f, "/(%s)%s", a, f) && strlen(a))
    prestate = aggregate_multiset(@(a/","-({""})));
  
  not_query = f;

  if(strlen(s))
  {
    sscanf(real_raw, "%s\r\n\r\n%s", s, data);

  /* We do _not_ want to parse the 'GET ...\n' line. /Per */
    sscanf(s, "%*s\n%s", s); 

    s = replace(s, "\n\t", ", ") - "\r"; 
    // Handle rfc822 continuation lines and strip \r
  
    foreach(s/"\n" - ({ "" }), line)
    {
      linename=contents=0;
      sscanf(line, "%s:%s", linename, contents);
      if(linename&&contents)
      {
	linename=lower_case(linename);
	sscanf(contents, "%*[\t ]%s", contents);
	
	if(strlen(contents))
	{
	  switch (linename)
	  {
	   case "content-length":	
	    misc->len = (int)(contents-" ");
	    
	    if(method == "POST")
	    {
	      int l = (int)(contents-" ")-1; /* Length - 1 */
	      wanted_data=l;
	      have_data=strlen(data);
	      if(strlen(data) <= l) // \r are included.
		return 0;
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
		string boundary;
//		perror("Multipart/form-data post detected\n");
		sscanf(misc["content-type"], "%*sboundary=%s",boundary);
		foreach((data/("--"+boundary))-({"--",""}), contents)
		{
		  string pre, metainfo,post;
		  if(sscanf(contents,
			    "%[\r\n]%*[Cc]ontent-%*[dD]isposition:%[^\r\n]%[\r\n]%s",
			    pre,metainfo,post,contents)>4)
		  {
		    mapping info=([]);
		    if(!strlen(contents))
		      continue;
		    while(contents[-1]=='-')
		      contents=contents[..strlen(contents)-2];
		    if(contents[-1]=='\r')contents=contents[..strlen(contents)-2];
		    if(contents[-1]=='\n')contents=contents[..strlen(contents)-2];
		    if(contents[-1]=='\r')contents=contents[..strlen(contents)-2];
		    foreach(metainfo/";", v)
		    {
		      sscanf(v, "%*[ \t]%s", v); v=reverse(v);
		      sscanf(v, "%*[ \t]%s", v); v=reverse(v);
		      if(lower_case(v)!="form-data")
		      {
			string var, value;
			if(sscanf(v, "%s=\"%s\"", var, value))
			  info[lower_case(var)]=value;
		      }
		    }
		    if(info->filename)
		    {
		      variables[info->name]=contents;
		      variables[info->name+".filename"]=info->filename;
		      if(!misc->files)
			misc->files = ({ info->name });
		      else
			misc->files += ({ info->name });
		    } else {
		      variables[info->name]=contents;
		    }
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
	    pragma|=aggregate_multiset(@explode(replace(contents, " ", ""), ","));
	    break;

	   case "user-agent":
	    sscanf(contents, "%s via", contents);
	    client = explode(contents, " ") - ({ "" });
	    break;

	   case "referer":
	     referer = contents/" ";
	     break;
	    
	   case "extension":
#ifdef DEBUG
	    perror("Client extension: "+contents+"\n");
#endif
	    linename="extension";
	    
	   case "connection":
	    contents = lower_case(contents);
	    
	   case "content-type":
	     misc[linename] = lower_case(contents);
	    break;

	   case "accept":
	   case "accept-encoding":
	   case "accept-language":
	   case "session-id":
	   case "message-id":
	   case "from":
	    if(misc[linename])
	      misc[linename] += explode(contents-" ", ",");
	    else
	      misc[linename] = explode(contents-" ", ",");
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
#ifdef MORE_HEADERS
	    if(misc[linename])
	      misc[linename] += explode(contents-" ", ",");
	    else
	      misc[linename] = explode(contents-" ", ",");
#endif
	   case "mime-version":
	    break;
	    
	   case "if-modified-since":
//	    if(QUERY(IfModified))
	      since=contents;
	    break;

	   case "forwarded":
	     misc["forwarded"]=contents;
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
  supports = find_supports(lower_case(client*" "));
  
  if(misc->proxyauth) {
    // The Proxy-authorization header should be removed... So there.
    mixed tmp1,tmp2;
    
    foreach(tmp2 = (raw / "\n"), tmp1) {
      if(!search(lower_case(tmp1), "proxy-authorization:"))
	tmp2 -= ({tmp1});
    }
    raw = tmp2 * "\n"; 
  }
  if(config_in_url)
    return really_set_config( mod_config );

  if(!supports->cookies)
    config = prestate;
  else
    if(conf
       && !cookies->RoxenUserID && strlen(not_query)
       && not_query[0]=='/' && method!="PUT"
       && QUERY(set_cookie))
    {
#ifdef DEBUG
      perror("Setting unique ID.\n");
#endif
      misc->moreheads = ([ "Set-Cookie":http_roxen_id_cookie(), ]);
    }
#ifdef DEBUG
#if DEBUG_LEVEL > 30
    else
      perror("Unique ID: "+cookies->RoxenUserID+"\n");
#endif
#endif
  not_query = simplify_path(not_query);
  return 1;	// Done.
}

void disconnect()
{
  if(do_not_disconnect)
  {
#ifdef REQUEST_DEBUG
  perror("REQUEST: Not disconnecting...\n");
#endif
  return;
  } 
#ifdef REQUEST_DEBUG
  perror("REQUEST: Disconnecting...\n");
#endif
  if(mappingp(file) && objectp(file->file))   
    destruct(file->file);
  if(objectp(pipe) && pipe != previous_object()) 
    destruct(pipe);
  my_fd = 0;
  destruct();
}

#ifdef KEEP_CONNECTION_ALIVE
void no_more_keep_connection_alive(mapping foo)
{
  if(!pipe || !objectp(my_fd)) end();
}
#endif

void end(string|void s)
{
#ifdef REQUEST_DEBUG
  perror("REQUEST: End...\n");
#endif
#ifdef KEEP_CONNECTION_ALIVE
  remove_call_out(no_more_keep_connection_alive);
#endif
  if(objectp(my_fd))
  {
    if(s) my_fd->write(s);
    destruct(my_fd);
  }
  disconnect();
}

static void timeout(mapping foo)
{
  end(prot+" 408 Timeout\n");
}


#ifdef KEEP_CONNECTION_ALIVE
void got_data(mixed fooid, string s);

void keep_connection_alive()
{
  pipe=0;
  my_fd->set_read_callback(got_data);
  my_fd->set_close_callback(end);
/*my_fd->set_write_callback(lambda(){});*/

  if(cache && strlen(cache))
    got_data(1, "");
  else
    call_out(no_more_keep_connection_alive, 100);
}
#endif


mapping internal_error(array err)
{
  if(QUERY(show_internals))
    file = http_low_answer(500, "<h1>Error: Internal server error.</h1>"
			   + "<font size=+1><pre>"+ describe_backtrace(err)
			   + "</pre></font>");
  else
    file = http_low_answer(500, "<h1>Error: The server failed to "
			   "fulfill your query.</h1>");
  
  
  report_error("Internal server error: " +
	       describe_backtrace(err) + "\n");
}

int wants_more()
{
  return !!cache;
}

static void handle_request( )
{
  mixed *err;
  int tmp;
#ifdef KEEP_CONNECTION_ALIVE
  int keep_alive;
#endif
  function funp;
  mapping heads;
  string head_string;
  object thiso=this_object();

#ifndef SPEED_MAX
  remove_call_out(timeout);
#endif
  
  if(conf)
  {
//  perror("Handle request, got conf.\n");
    foreach(conf->first_modules(), funp) if(file = funp( thiso)) break;
    
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
    if(method != "GET" && method != "HEAD" && method != "POST")
      file = http_low_answer(501, "Not implemented.");
    else
      file=http_low_answer(404,
			   replace(parse_rxml(conf->query("ZNoSuchFile"),
					      thiso),
				   ({"$File", "$Me"}), 
				   ({not_query,
				       conf->query("MyWorldLocation")})));
  } else {
    if((file->file == -1) || file->leave_me) 
    {
      if(!file->stay) disconnect();
      return;
    }

    if(file->type == "raw")
      file->raw = 1;
    else if(!file->type)
      file->type="text/plain";
  }
  
  if(!file->raw && prot != "HTTP/0.9")
  {
    string h;
    heads=
      ([
	"Content-type":file["type"],
		      "Server":version(),
		      "Date":http_date(time)
	 ]);
    
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
	    method="HEAD";
	  }
	}
      }
      if(stringp(file->data)) 
	file->len += strlen(file->data);
    }
    
#ifdef KEEP_CONNECTION_ALIVE
#ifdef REQUEST_DEBUG
    if(kept_alive)
      perror(sprintf("Connection: Kept alive %d times.\n", kept_alive));
#endif
    if(misc->connection && search(misc->connection, "keep-alive") != -1)
    {
      if(file->len > 0)
      {
	heads->Connection = "keep-alive; timeout=100, maxreq=666";
	keep_alive=1;
#ifdef REQUEST_DEBUG
	kept_alive++;
#endif
      }
    }
#endif

    if(mappingp(file->extra_heads)) 
      heads |= file->extra_heads;

    if(mappingp(misc->moreheads))
      heads |= misc->moreheads;
    
    array myheads = ({prot+" "+(file->rettext||errors[file->error])});
    foreach(indices(heads), h)
      if(arrayp(heads[h]))
	foreach(heads[h], tmp)
	  myheads += ({ sum(h,": ", tmp)});
      else
	myheads +=  ({ sum(h, ": ", heads[h])});
    

    if(file->len > -1)
      myheads += ({"Content-length: " + file->len });
    head_string = (myheads+({"",""}))*"\r\n";
    
    if(conf)conf->hsent+=strlen(head_string||"");
    my_fd->set_read_callback(0);
    my_fd->set_close_callback(0);

    if(method=="HEAD")
    {
      if(conf)conf->log(file, thiso);
#ifdef KEEP_CONNECTION_ALIVE
      if(keep_alive)
      {
	my_fd->write(head_string);
	misc->connection = 0;
	keep_connection_alive();
      } else
#endif
	end(head_string);
      return;
    }

    if(conf)
      conf->sent+=(file->len>0 ? file->len : 1000);
    
    if(!file->data &&
       (file->len<=0 || (file->len > 30000))
#ifdef KEEP_CONNECTION_ALIVE
       && !keep_alive
#endif
       && objectp(file->file))
    {
      if(head_string) my_fd->write(head_string);
      shuffle( file->file, my_fd );
      if(conf)conf->log(file, thiso); 
      my_fd=file->file=file=pipe=0;
      destruct(thiso);
      return;
    }
  
    if(file->len < 3000 &&
#ifdef KEEP_CONNECTION_ALIVE
       !keep_alive &&
#endif
       file->len >= 0)
    {
//    perror("fo\n");
      if(file->data)
	head_string += file->data;
      if(file->file) 
      {
	head_string += file->file->read(file->len);
	destruct(file->file);
      }
      if(conf) conf->log(file, thiso);
      end(head_string);
//      perror("end\n");
      return;
    }
  }

// perror("Last case...\n");
  if(head_string) send(head_string);
  if(file->data)  send(file->data);
  if(file->file)  send(file->file);
  pipe->output(my_fd);
  
  if(conf) conf->log(file, thiso);

#ifdef KEEP_CONNECTION_ALIVE
  if(keep_alive)
  {
    if(my_fd)
    {
      misc->connection=0;
      pipe->set_done_callback(keep_connection_alive);
    }
  } else 
#endif
  {
    my_fd=0;
    pipe=file=0;
    destruct(thiso);
  }
}

/* We got some data on a socket.
 * ================================================= 
 */

void got_data(mixed fooid, string s)
{
  int tmp;
//  perror("Got data.\n");
#ifndef SPEED_MAX
  remove_call_out(timeout);
#endif
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
    cache += ({ s });
    s = cache*""; 
    cache = 0;
  }
#ifdef KEEP_CONNECTION_ALIVE
  remove_call_out(no_more_keep_connection_alive);
#endif
  tmp = parse_got(s);
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
#ifdef THREADS
  handle(handle_request);
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

  c->my_fd = 0;
  c->conf = conf;
  c->time = time;
  c->method = method;
  c->prot = prot;
  c->pragma = pragma;
  c->cookies = cookies;
  c->prestate = prestate;
  c->supports = supports;
  c->remoteaddr = remoteaddr;
  c->client = client;
  c->auth = auth;
  c->misc = copy_value(misc);
  c->misc->orig = t;
  c->realauth = realauth;
  return c;
}

void clean()
{
  if(!(my_fd && objectp(my_fd))) end();
  else if((_time(1) - time) > 4800) end();
}

void create(object f, object c)
{
  if(f)
  {
    my_fd = f;
    my_fd->set_read_callback(got_data);
    my_fd->set_close_callback(end);
    conf = c;
    mark_fd(my_fd->query_fd(), "HTTP connection");
    
#ifndef SPEED_MAX
    call_out(timeout, 60);
#endif
  }
}
