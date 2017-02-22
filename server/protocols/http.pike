// This is a roxen protocol module.
// Modified by Francesco Chemolli to add throttling capabilities.
// Copyright © 1996 - 2001, Roxen IS.

constant cvs_version = "$Id$";
// #define REQUEST_DEBUG
#define MAGIC_ERROR

#ifdef MAGIC_ERROR
inherit "highlight_pike";
#endif

// HTTP protocol module.
#include <config.h>
#define TIMER_PREFIX "http:"
#include <timers.h>

inherit RequestID;

#ifdef PROFILE
#define HRTIME() gethrtime()
#define HRSEC(X) ((int)((X)*1000000))
#define SECHR(X) ((X)/(float)1000000)
int req_time = HRTIME();
#endif

#ifdef ID_OBJ_DEBUG
RoxenDebug.ObjectMarker __marker = RoxenDebug.ObjectMarker (this_object());
#endif

#ifdef REQUEST_DEBUG
int footime, bartime;
#define REQUEST_WERR(X) do {			\
    if (this) {					\
      bartime = gethrtime()-footime;		\
      werror("%s (%d)\n", (X), bartime);	\
      footime=gethrtime();			\
    } else {					\
      werror("%s\n", (X));			\
    }						\
  } while (0)
#else
#define REQUEST_WERR(X) do {} while (0)
#endif

#ifdef FD_DEBUG
#define MARK_FD(X) do {							\
    int _fd = my_fd && my_fd->query_fd ? my_fd->query_fd() : -1;	\
    REQUEST_WERR("FD " + (_fd == -1 ? sprintf ("%O", my_fd) : _fd) + ": " + (X)); \
    mark_fd(_fd, (X)+" "+remoteaddr);					\
  } while (0)
#else
#define MARK_FD(X) do {} while (0)
#endif

#ifdef THROTTLING_DEBUG
#undef THROTTLING_DEBUG
#define THROTTLING_DEBUG(X) werror("Throttling: "+X+"\n")
#else
#define THROTTLING_DEBUG(X)
#endif

constant decode          = MIME.decode_base64;
constant find_supports_and_vars = roxen.find_supports_and_vars;
constant version         = roxen.version;
constant _query          = roxen.query;

private static array(string) cache;
private static int wanted_data, have_data;
private static object(String.Buffer) data_buffer;

int kept_alive;

#ifdef DEBUG
#define CHECK_FD_SAFE_USE do {						\
    if (this_thread() != roxen->backend_thread &&			\
	(my_fd->query_read_callback() || my_fd->query_write_callback() || \
	 my_fd->query_close_callback() ||				\
	 !zero_type (find_call_out (do_timeout))))			\
      error ("Got callbacks but not called from backend thread.\n");	\
  } while (0)
#else
#define CHECK_FD_SAFE_USE do {} while (0)
#endif

#include <roxen.h>
#include <module.h>
#include <variables.h>
#include <request_trace.h>

#define MY_TRACE_ENTER(A, B) \
  do {RequestID id = this_object(); TRACE_ENTER (A, B);} while (0)
#define MY_TRACE_LEAVE(A) \
  do {RequestID id = this_object(); TRACE_LEAVE (A);} while (0)

mapping(string:array) real_variables = ([]);
mapping(string:mixed)|FakedVariables variables = FakedVariables( real_variables );

mapping (string:mixed)  misc            =
([
#ifdef REQUEST_DEBUG
  "trace_enter":lambda(mixed ...args) {
		  REQUEST_WERR(sprintf("TRACE_ENTER(%{%O,%})", args));
		},
  "trace_leave":lambda(mixed ...args) {
		  REQUEST_WERR(sprintf("TRACE_LEAVE(%{%O,%})", args));
		}
#endif // REQUEST_DEBUG
]);
mapping (string:mixed)  connection_misc = ([ ]);
mapping (string:string) cookies         = ([ ]);
mapping (string:string) request_headers = ([ ]);
mapping (string:string) client_var      = ([ ]);

multiset (string) prestate  = (< >);
multiset (string) config    = (< >);
multiset (string) pragma    = (< >);

mapping file;

string rest_query="";
string raw="";
string extra_extension = ""; // special hack for the language module

static mapping connection_stats = ([]);

class AuthEmulator
// Emulate the old (rather cumbersome) authentication API 
{
  mixed `[]( int i )
  {
    User u;
    switch( i )
    {
      case 0:
	return conf->authenticate( this_object() );
      case 1:
	if( u = conf->authenticate( this_object() ) )
	  return u->name();
	if( realauth )
	  return (realauth/":")[0];

      case 2:
	if( u = conf->authenticate( this_object() ) )
	  return 0;
	if( realauth )
	  return ((realauth/":")[1..])*":";
    }
  }
  int `!( )
  {
    return !realauth;
  }
}

array|AuthEmulator auth;


void decode_map( mapping what, function decoder )
{
  foreach( indices( what ), mixed q )
  {
    string ni;
    mixed val;
    if( stringp( q ) )
      catch { ni = decoder( q ); };
    val = what[q];
    if( stringp( val ) )
      catch { val = decoder( val ); };
    else if( arrayp( val ) )
      val = map( val, lambda( mixed q ) {
                        if( stringp( q ) )
                          catch { return decoder( q ); };
                        return q;
                      } );
    else if( mappingp( val ) )
      decode_map( val, decoder );
    else if( multisetp( val ) )
      val = mkmultiset( map( indices(val), lambda( mixed q ) {
                                             if( stringp( q ) )
                                               catch { return decoder( q ); };
                                             return q;
                                           } ));
    what[ni] = val;
    if( q != ni )
      m_delete( what, q );
  }
}

void decode_charset_encoding( string|function(string:string) decoder )
{
  if( misc->request_charset_decoded )
    return;
  if(stringp(decoder))
    decoder = Roxen._charset_decoder(Locale.Charset.decoder(decoder))->decode;
  if( !decoder )
    return;
  
  misc->request_charset_decoded = 1;

  string safe_decoder(string s) {
    catch { return decoder(s); };
    return s;
  };

  if( prot ) prot = safe_decoder( prot );
  if( clientprot ) clientprot = safe_decoder( clientprot );
  if( method ) method = safe_decoder( method );
  if( rest_query ) rest_query = safe_decoder( rest_query );
  if( query ) query = safe_decoder( query );
  if( not_query ) not_query = safe_decoder( not_query );
  if( realauth )
  {
    rawauth = safe_decoder( rawauth );
    realauth = safe_decoder( realauth );
  }
  if( since )
    since = safe_decoder( since );

  decode_map( real_variables, decoder );
  decode_map( misc, decoder );
  decode_map( cookies, decoder );
  decode_map( request_headers, decoder );

  if( client )
    client = map( client, safe_decoder );
  if( referer )
    referer = map( referer, safe_decoder );
  prestate = mkmultiset( map( (array(string))indices( prestate ),
			      safe_decoder ) );
  config = mkmultiset( map( (array(string))indices( config ),
			    safe_decoder ) );
  pragma = mkmultiset( map( (array(string))indices( pragma ),
			    safe_decoder ) );
}

// Parse a HTTP/1.1 HTTP/1.0 or 0.9 request, including form data and
// state variables.  Return 0 if more is expected, 1 if done, and -1
// if fatal error.
object pipe;

//used values: throttle->doit=0|1 to enable it
//             throttle->rate the rate
//             throttle->fixed if it's not to be touched again
mapping (string:mixed) throttle=([]);

object throttler;//the inter-request throttling object.

/* Pipe-using send functions */

// FIXME:
//I'm choosing the pipe type upon setup. Thus I'm assuming that all headers
//have been defined before then. This is actually not true in case
//of throttling and keep-alive. We'll take care of that later.
private void setup_pipe()
{
  if(!my_fd) {
    end();
    return;
  }
  if ( throttle->doit && conf->query("req_throttle") )
    throttle->doit = 0;
  if( throttle->doit || conf->throttler )
    pipe=roxen.slowpipe();
  else
    pipe=roxen.fastpipe();
  if (throttle->doit) 
  { 
    //we are sure that pipe is really a slowpipe.
    throttle->rate=max(throttle->rate, conf->query("req_throttle_min"));
    pipe->throttle(throttle->rate,
                   (int)(throttle->rate*conf->query("req_throttle_depth_mult")),
                   0);
    THROTTLING_DEBUG("throtting request at "+throttle->rate);
  }
  if( pipe->set_status_mapping )
    pipe->set_status_mapping( connection_stats );
  if ( conf->throttler )
    pipe->assign_throttler( conf->throttler );
}


void send (string|object what, int|void len)
{
  if( len>0 && port_obj && port_obj->minimum_byterate )
    call_out( end, len / port_obj->minimum_byterate );

  if(!what) return;
  if(!pipe) setup_pipe();
  if(stringp(what))  {
    REQUEST_WERR(sprintf("HTTP: Pipe string %O", what));
    pipe->write(what);
  }
  else {
    REQUEST_WERR(sprintf("HTTP: Pipe stream %O, length %O", what, len));
    pipe->input(what,len);
  }
}

void start_sender( )
{
  if (pipe) 
  {
    MARK_FD("HTTP really handled, piping response");
#ifdef FD_DEBUG
    call_out(timer, 30, predef::time(1)); // Update FD with time...
#endif
    pipe->set_done_callback( do_log );
    pipe->output( my_fd );
  } else {
    MARK_FD("HTTP really handled, pipe done");
    do_log();
  }
}

string scan_for_query( string f )
{
  query=0;
  rest_query="";
  if(sscanf(f,"%s?%s", f, query) == 2)
  {
    string v, a, b;

    foreach(query / "&", v)
      if(sscanf(v, "%s=%s", a, b) == 2)
      {
	a = http_decode_string(replace(a, "+", " "));
	b = http_decode_string(replace(b, "+", " "));
	real_variables[ a ] += ({ b });
      } else
	if(strlen( rest_query ))
	  rest_query += "&" + http_decode_string( v );
	else
	  rest_query = http_decode_string( v );
    rest_query=replace(rest_query, "+", "\000"); /* IDIOTIC STUPID STANDARD */
  }
  return f;
}

#define OLD_RXML_CONFIG

#ifdef OLD_RXML_CONFIG
private void really_set_config(array mod_config)
{
  string url;

  if(sscanf(replace(raw_url,({"%3c","%3e","%3C","%3E" }),
                    ({"<",">","<",">"})),"/<%*s>/%s",url)!=2)
    url = "/";
  else
    url = "/"+url;

  multiset do_mod_config( multiset config )
  {
    if(!mod_config) return config;
    foreach(mod_config, string m)
      if(m[0]=='-')
        config[m[1..]]=0;
      else
        config[m]=1;
    return config;
  };

  void do_send_reply( string what, string url ) {
    CHECK_FD_SAFE_USE;
    url = url_base() + url[1..];
    my_fd->set_blocking();
    my_fd->write( prot + " 302 Roxen config coming up\r\n"+
                  (what?what+"\r\n":"")+"Location: "+url+"\r\n"
                  "Connection: close\r\nDate: "+
                  Roxen.http_date(predef::time(1))+
                  "\r\nContent-Type: text/html\r\n"
                  "Content-Length: 1\r\n\r\nx" );
    my_fd->close();
    my_fd = 0;
    end();
  };

  if(supports->cookies)
  {
    do_send_reply("Set-Cookie: "+
         Roxen.http_roxen_config_cookie(indices(do_mod_config(config))*","),
                  url );
    return;
  }
  if (sscanf(replace(url, ({ "%28", "%29" }), ({ "(", ")" })),
             "/(%*s)/%s", url) == 2)
    url = "/" + url;
    
  do_send_reply(0,Roxen.add_pre_state( url, do_mod_config( prestate ) ));
}
#endif

private static mixed f, line;
private static int hstart;

class CacheKey {
#if ID_CACHEKEY_DEBUG
  constant __num = ({ 0 });
  int _num;
  string _sprintf() { return "CacheKey(#" + _num + ")"; }
  void create() { _num = ++__num[0]; }
  void destroy() { werror("CacheKey(#" + _num + "): --DESTROY--\n"
			  "%s\n\n", "" || describe_backtrace(backtrace())); }
#endif
}

//! Parse a cookie string.
//!
//! @param contents
//!   HTTP transport-encoded cookie header value.
//!
//! @returns
//!   Returns the resulting current cookie mapping.
mapping(string:string) parse_cookies( string contents )
{
  if(!contents)
    return cookies;

//       misc->cookies += ({contents});
  foreach(((contents/";") - ({""})), string c)
  {
    string name, value;
    while(sizeof(c) && c[0]==' ') c=c[1..];
    if(sscanf(c, "%s=%s", name, value) == 2)
    {
      value=http_decode_string(value);
      name=http_decode_string(name);
      cookies[ name ]=value;
#ifdef OLD_RXML_CONFIG
      if( (name == "RoxenConfig") && strlen(value) )
	config =  mkmultiset( value/"," );
#endif
    }
  }
  return cookies;
}

int things_to_do_when_not_sending_from_cache( )
{
#ifdef OLD_RXML_CONFIG
  array mod_config;
  int config_in_url;
#endif
  array|string contents;
  misc->pref_languages=PrefLanguages();

  misc->cachekey = CacheKey();
  misc->_cachecallbacks = ({});
  if( contents = request_headers[ "accept-language" ] )
  {
    if( !arrayp( contents ) )
      contents = (contents-" ")/",";
    else
      contents =
	Array.flatten( map( map( contents, `-, " " ), `/, "," ))-({""});
    misc->pref_languages->languages=contents;
    misc["accept-language"] = contents;
  }

  if( contents = request_headers[ "cookie" ] )
  {
    // FIXME:
    // "misc->cookies"? Shouldn't it be just "cookies"?
    //   /grubba 2002-03-22
    misc->cookies = ({});
    foreach( arrayp( contents )? contents : ({ contents }), contents )
    {
      parse_cookies(contents);
    }
  }

  string f = raw_url;


  f = scan_for_query( f );
  f = http_decode_string( f );

  // f is sent to Unix API's that take NUL-terminated strings...
  if(search(f, "\0") != -1)
     sscanf(f, "%s\0", f);
  
  if( strlen( f ) > 5 )
  {
    string a;
    switch( f[1] )
    {
#ifdef OLD_RXML_CONFIG
      case '<':
        if (sscanf(f, "/<%s>/%s", a, f)==2)
        {
          config_in_url = 1;
          mod_config = (a/",");
          f = "/"+f;
        }
#endif
        // intentional fall-through
     case '(':
       if(strlen(f) && sscanf(f, "/(%s)/%s", a, f)==2)
       {
         prestate = (multiset)( a/","-({""}) );
         f = "/"+f;
       }
    }
  }

  not_query = Roxen.simplify_path(f);
#ifndef DISABLE_SUPPORTS
  if( !supports )
  {
    if( !client )
    {
      client = ({ "unknown" });
      array s_and_v = find_supports_and_vars("", supports);
      supports = s_and_v[0];
      client_var = s_and_v[1];
    }
    else 
    {
      if( !client_var->Fullname )
        client_var->Fullname = "unknown";
      client_var->fullname=lower_case(client_var->Fullname);
      array s_and_v=find_supports_and_vars(client_var->fullname,supports,client_var);
      supports = s_and_v[0];
      client_var = s_and_v[1];
    }
  }
  if ( client_var->charset && client_var->charset  != "iso-8859-1" )
  {
    misc->no_proto_cache = 1;
    set_output_charset( client_var->charset );
    input_charset = client_var->charset;
    decode_charset_encoding( client_var->charset );
  }
#else
  supports = (< "images", "gifinline", "forms", "mailto">);
#endif
  //REQUEST_WERR("HTTP: parse_got(): supports");
  if(!referer) referer = ({ });
  if(misc->proxyauth) 
  {
    // The Proxy-authorization header should be removed... So there.
    mixed tmp1,tmp2;

    foreach(tmp2 = (raw / "\n"), tmp1) {
      if(!search(lower_case(tmp1), "proxy-authorization:"))
	tmp2 -= ({tmp1});
    }
    raw = tmp2 * "\n";
  }
#ifdef OLD_RXML_CONFIG
  if(config_in_url) {
    //REQUEST_WERR("HTTP: parse_got(): config_in_url");
    really_set_config( mod_config );
    return 1;
  }
#endif
  if(!supports->cookies)
    config = prestate;
  else
    if( port_obj->set_cookie
       && !cookies->RoxenUserID && strlen(not_query)
       && not_query[0]=='/' && method!="PUT")
    {
      if (!(port_obj->set_cookie_only_once &&
	    cache_lookup("hosts_for_cookie",remoteaddr)))
	misc->moreheads = ([ "Set-Cookie":Roxen.http_roxen_id_cookie(), ]);
      if (port_obj->set_cookie_only_once)
	cache_set("hosts_for_cookie",remoteaddr,1);
    }

  if( mixed q = real_variables->magic_roxen_automatic_charset_variable )
    decode_charset_encoding(Roxen.get_client_charset_decoder(q[0],this_object()));
}

static Roxen.HeaderParser hp = Roxen.HeaderParser();
static function(string:array(string|mapping)) hpf = hp->feed;
int last;

private int parse_got( string new_data )
{
  TIMER_START(parse_got);
  if( !method )
  {
    array res;
    if( mixed err = catch( res = hpf( new_data ) ) ) {
#ifdef DEBUG
      report_debug ("Got bad request, HeaderParser error: " + describe_error (err));
#endif
      return 1;
    }
    if( !res )
    {
      TIMER_END(parse_got);
      return 0; // Not enough data
    }
    data = res[0];
    line = res[1];
    request_headers = res[2];
  }
  TIMER_END(parse_got);
  return parse_got_2();
}

private final int parse_got_2( )
{
  TIMER_START(parse_got_2);
  TIMER_START(parse_got_2_parse_line);
  string trailer, trailer_trailer;
  multiset (string) sup;
  string a, b, s="", linename, contents;
  array(string) sl = line / " ";
  switch( sizeof( sl ) )
  {
    default:
      sl = ({ sl[0], sl[1..sizeof(sl)-2]*" ", sl[-1] });
      /* FALL_THROUGH */

    case 3: /* HTTP/1.0 */
      method = sl[0];
      f = sl[1];
      clientprot = sl[2];
      prot = clientprot;
      if(!(< "HTTP/1.0", "HTTP/1.1" >)[prot])
      {
	int maj,min;
	if( sscanf(prot, "HTTP/%d.%d", maj, min) == 2 )
	  // Comply with the annoying weirdness of RFC 2616.
	  prot = "HTTP/" + maj + "." + min;
	else
	  // We're nice here and assume HTTP even if the protocol
	  // is something very weird.
	  prot = "HTTP/1.1";
      }
      break;
      
    case 2:     // HTTP/0.9
    case 1:     // PING
      method = sl[0];
      f = sl[-1];
      if( sizeof( sl ) == 1 )
	sscanf( method, "%s%*[\r\n]", method );
	
      clientprot = prot = "HTTP/0.9";
      if(method != "PING")
	method = "GET"; // 0.9 only supports get.
      else
      {
	my_fd->write("PONG\r\n");
	TIMER_END(parse_got_2);
	return 2;
      }
      s = data = ""; // no headers or extra data...
      sscanf( f, "%s%*[\r\n]", f );
      misc->no_proto_cache = 1;
      break;

    case 0:
      /* Not reached */
      break;
  }
  TIMER_END(parse_got_2_parse_line);
  REQUEST_WERR(sprintf("HTTP: request line %O", line));
  REQUEST_WERR(sprintf("HTTP: headers %O", request_headers));
  REQUEST_WERR(sprintf("HTTP: data (length %d) %O", strlen(data),data));
  raw_url    = f;
  time       = predef::time(1);
  // if(!data) data = "";
  //REQUEST_WERR(sprintf("HTTP: raw_url %O", raw_url));

  if(!remoteaddr)
  {
    if(my_fd) {
      remoteaddr = my_fd->query_address();
      if(remoteaddr)
      	sscanf(remoteaddr, "%s %*s", remoteaddr);
    }
    if(!remoteaddr) {
      REQUEST_WERR("HTTP: No remote address.");
      TIMER_END(parse_got_2);
      return 2;
    }
  }

  TIMER_START(parse_got_2_parse_headers);
  foreach( (array)request_headers, [string linename, array|string contents] )
  {
    if( arrayp(contents) ) contents = contents[0];
    switch (linename) 
    {
     case "cache-control":	// Opera sends "no-cache" here.
     case "pragma": pragma|=(multiset)((contents-" ")/",");  break;

     case "content-length": misc->len = (int)contents;       break;
     case "authorization":  rawauth = contents;              break;
     case "referer": referer = ({contents}); break;
     case "if-modified-since": since=contents; break;

     case "proxy-authorization":
       array y;
       y = contents / " ";
       if(sizeof(y) < 2)
         break;
       y[1] = decode(y[1]);
       misc->proxyauth=y;
       break;

     case "user-agent":
       if( !client )
       {
         sscanf(contents, "%s via", contents);
         client_var->Fullname=contents;
         client = contents/" " - ({ "" });
       }
       break;

     case "request-range":
       contents = lower_case(contents-" ");
       if(!search(contents, "bytes"))
         // Only care about "byte" ranges.
         misc->range = contents[6..];
       break;

     case "range":
       contents = lower_case(contents-" ");
       if(!misc->range && !search(contents, "bytes"))
         // Only care about "byte" ranges. Also the Request-Range header
         // has precedence since Stupid Netscape (TM) sends both but can't
         // handle multipart/byteranges but only multipart/x-byteranges.
         // Duh!!!
         misc->range = contents[6..];
       break;


     case "host":
     case "connection":
       misc[linename] = lower_case(contents);
       break;
     case "content-type":
       misc[linename] = contents;
       break;
    }
  }
  TIMER_END(parse_got_2_parse_headers);
  TIMER_START(parse_got_2_more_data);
  if(misc->len)
  {
    if(!data) data="";
    int l = misc->len;
    wanted_data=l;
    have_data=strlen(data);
	
    if(strlen(data) < l)
    {
      REQUEST_WERR(sprintf("HTTP: More data needed in %s.", method));
      TIMER_END(parse_got_2);
      return 0;
    }
    leftovers = data[l+2..];
    data = data[..l+1];
	
    switch(method) {
    case "POST":
      switch(lower_case((((misc["content-type"]||"")+";")/";")[0]-" "))
      {
      default: 
	// Normal form data.
	string v;

	// Ok.. This might seem somewhat odd, but IE seems to add a
	// (spurious) \r\n to the end of the data, and some versions of
	// opera seem to add (spurious) \r\n to the start of the data.
	//
	// Oh, the joy of supporting all webbrowsers is endless.
	data = String.trim_all_whites( data );
	l = misc->len = strlen(data);

	if(l < 200000)
	  foreach(replace(data,"+"," ")/"&", v)
	    if(sscanf(v, "%s=%s", a, b) == 2)
	    {
	      a = http_decode_string( a );
	      b = http_decode_string( b );
	      real_variables[ a ] += ({ b });
	    }
	break;
	    
      case "multipart/form-data":
	object messg = MIME.Message(data, request_headers);
	if (!messg->body_parts) {
	  report_error("HTTP: Bad multipart/form-data.\n"
		       "  headers:\n"
		       "%{    %O:%O\n%}"
		       "  data:\n"
		       "%{    %O\"\\n\"\n%}",
		       (array)request_headers,
		       data/"\n");
	  /* FIXME: Should this be reported to the client? */
	} else {
	  foreach(messg->body_parts, object part)
	  {
	    if(part->disp_params->filename)
	    {
	      real_variables[part->disp_params->name] += ({part->getdata()});
	      real_variables[part->disp_params->name+".filename"] +=
	      ({part->disp_params->filename});
	      misc->files += ({ part->disp_params->name });
	    } else 
	      real_variables[part->disp_params->name] += ({part->getdata()});
	    if(part->headers["content-type"])
	      real_variables[part->disp_params->name+".mimetype"] +=
		({ part->headers["content-type"] });
	  }
	}
	break;
      }
      break;
    }
  }
  TIMER_END(parse_got_2_more_data);
  if (!(< "HTTP/1.0", "HTTP/0.9" >)[prot]) {
    if (!misc->host) {
      // RFC 2616 requires this behaviour.
      REQUEST_WERR("HTTP: HTTP/1.1 request without a host header.");
      my_fd->write((prot||"HTTP/1.1") +
		   " 400 Bad request (missing host header).\r\n"
		   "Content-Length: 0\r\n"
		   "Date: "+Roxen.http_date(predef::time())+"\r\n"
		   "\r\n");
      TIMER_END(parse_got_2);
      return 2;
    }
  }
  TIMER_END(parse_got_2);
  return 3;	// Done.
}

int get_max_cache()
{
  return misc->cacheable;
}

int set_max_cache( int t )
{
  int ot = misc->cacheable;
  misc->cacheable = t;
  return ot;
}

void disconnect()
{
  file = 0;
  conf && conf->connection_drop( this_object() );
#ifdef REQUEST_DEBUG
  if (my_fd) 
    MARK_FD("HTTP my_fd in HTTP disconnected?");
#endif
  MERGE_TIMERS(conf);
  if(do_not_disconnect) return;
  destruct();
}

void end(int|void keepit)
{
  if( conf )
    conf->connection_drop( this_object() );

  CHECK_FD_SAFE_USE;

#if constant(Parser.XML.Tree.XMLNSParser)
  if (xml_data) {
    mixed err = catch {
      // Disconnect the XML graph to make it easier on the gc.
      xml_data->walk_postorder(lambda(Parser.XML.Tree.AbstractNode node) {
				 node->mParent = 0;
			       });
      xml_data = 0;
    };
#ifdef DEBUG
    if (err)
      report_debug ("Failed to disconnect XML tree: " + describe_backtrace (err));
#endif
  }
#endif /* Parser.XML.Tree.XMLNSParser */

  if(keepit
     && !file->raw
     && (misc->connection == "keep-alive" ||
         (prot == "HTTP/1.1" && misc->connection != "close"))
     && my_fd
     && !catch(my_fd->query_address()) )
  {
    // Now.. Transfer control to a new http-object. Reset all variables etc..
    object o = object_program(this_object())(0, 0, 0);
    o->remoteaddr = remoteaddr;
    o->client = client;
    o->supports = supports;
    o->client_var = client_var;
    o->host = host;
    o->conf = conf;
    o->pipe = pipe;
    o->connection_misc = connection_misc;
    o->kept_alive = kept_alive+1;
    MARK_FD("HTTP kept alive");
    object fd = my_fd;
    my_fd=0;
    o->chain(fd,port_obj,leftovers);
    pipe = 0;
    disconnect();
    return;
  }

  data_buffer = 0;
  pipe = 0;
  if(objectp(my_fd))
  {
    MARK_FD("HTTP closed");
    mixed err = catch
    {
#if 0
      // Don't set to blocking mode if SSL.
      if (!my_fd->CipherSpec)
	// This causes connections to be closed prematurely, at least on NT.
#endif
	my_fd->set_blocking();
      my_fd->close();
      destruct(my_fd);
    };
#ifdef DEBUG
    if (err) report_debug ("Close failure (1): %s", describe_backtrace (err));
#endif
    err = catch {
      my_fd = 0;
    };
#ifdef DEBUG
    if (err) report_debug ("Close failure (2): %s", describe_backtrace (err));
#endif
  }
  disconnect();
}

static void do_timeout()
{
  int elapsed = predef::time(1)-time;
  if(time && elapsed >= 30)
  {
    REQUEST_WERR("HTTP: Connection timed out. Closing.");
    MARK_FD("HTTP timeout");
    end();
  } else {
#ifdef DEBUG
    error ("This shouldn't happen.\n");
#endif
    // premature call_out... *¤#!"
    call_out(do_timeout, 10);
    MARK_FD("HTTP premature timeout");
  }
}

string link_to(string file, int line, string fun, int eid, int qq)
{
  if (!file || !line) return "<a>";
  if(file[0]!='/') file = combine_path(getcwd(), file);
  return ("<a href=\"/(old_error,find_file)/error/?"+
	  "file="+Roxen.http_encode_url(file)+
	  (fun ? "&fun="+Roxen.http_encode_url(fun) : "") +
	  "&off="+qq+
	  "&error="+eid+
	  "&error_md5="+get_err_md5(get_err_info(eid))+
	  (line ? "&line="+line+"#here" : "") +
	  "\">");
}

static string error_page_header (string title)
{
  title = Roxen.html_encode_string (title);
  return #"<html><head><title>" + title + #"</title></head>
<body bgcolor='white' text='black' link='#ce5c00' vlink='#ce5c00'>
<table width='100%'><tr>
<td><a href='http://www.roxen.com/'><img border='0' src='/internal-roxen-roxen-small'></a></td>
<td><b><font size='+1'>" + title + #"</font></b></td>
<td align='right'><font size='+1'>Roxen WebServer " + Roxen.html_encode_string (roxen_version()) + #"</font></td>
</tr></table>

";
}

static string get_err_md5(array(string|array(string)|array(array)) err_info)
{
  if (err_info) {
    return Crypto.string_to_hex(Crypto.md5()->update(err_info[3])->digest());
  }
  return "NONE";
}

static array(string|array(string)|array(array)) get_err_info(int eid,
							     string|void md5)
{
  array(string|array(string)|array(array)) err_info = 
    roxen.query_var ("errors")[eid];
  
  if (!err_info ||
      (md5 && (md5 != get_err_md5(err_info)))) {
    // Extra safety...
    return 0;
  }
  return err_info;
}


string format_backtrace(int eid, string|void md5)
{
  array(string|array(string)|array(array)) err_info = get_err_info(eid, md5);

  if (!err_info) {
    return error_page_header("Unregistred Error");
  }

  [string msg, array(string) rxml_bt, array(array) bt,
   string raw_bt_descr, string raw_url, string raw] = err_info;

  string res = error_page_header ("Internal Server Error") +
    "<h1>" + replace (Roxen.html_encode_string (msg), "\n", "<br />\n") + "</h1>\n";

  if (rxml_bt && sizeof (rxml_bt)) {
    res += "<h3>RXML frame backtrace</h3>\n<ul>\n";
    foreach (rxml_bt, string line)
      res += "<li>" + Roxen.html_encode_string (line) + "</li>\n";
    res += "</ul>\n\n";
  }

  if (bt && sizeof (bt)) {
    res += "<h3>Pike backtrace</h3>\n<ul>\n";
    int q = sizeof (bt);
    foreach(bt, [string file, int line, string func, string descr])
    {
#if constant(PIKE_MODULE_RELOC)
      file = file && master()->relocate_module(file);
#endif
      res += "<li value="+(q--)+">" +
	link_to (file, line, func, eid, q) +
	(file ? Roxen.html_encode_string (file) : "<i>Unknown program</i>") +
	(line ? ":" + line : "") +
	"</a>" + (file ? Roxen.html_encode_string (get_cvs_id (file)) : "") + ":<br />\n" +
	replace (Roxen.html_encode_string (descr),
		 ({"(", ")", " "}), ({"<b>(</b>", "<b>)</b>", "&nbsp;"})) +
	"</li>\n";
    }
    res += "</ul>\n\n";
  }

  res += ("<p><b><a href=\"/(old_error,plain)/error/?"
	  "error="+eid+
	  "&error_md5="+get_err_md5(get_err_info(eid))+
	  "\">"
	  "Generate text only version of this error message, for bug reports"+
	  "</a></b></p>\n\n");
  return res+"</body></html>";
}

string generate_bugreport(string msg, array(string) rxml_bt, array(string) bt,
			  string raw_bt_descr, string raw_url, string raw)
{
  return ("Roxen version: "+version()+
	  (roxen.real_version != version()?
	   " ("+roxen.real_version+")":"")+
	  "\nPike version: " + predef::version() +
	  "\nRequested URL: "+raw_url+"\n"
	  "\nError: " + raw_bt_descr +
	  "\nRequest data:\n"+raw);
}

string censor(string what)
{
  string a, b, c;
  if(!what)
    return "No backtrace";
  if(sscanf(what, "%suthorization:%s\n%s", a, b, c)==3)
    return a+"uthorization: ################ (censored)\n"+c;
  return what;
}

int store_error(mixed _err)
{
  mixed err = _err;
  _err = 0; // hide in backtrace, they are bad enough anyway...
  mapping e = roxen.query_var("errors");
  if(!e) roxen.set_var("errors", ([]));
  e = roxen.query_var("errors"); /* threads... */

  int id = ++e[0];
  if(id>1024) id = 1;

  string msg;
  array(string) rxml_bt;

  if (!err) msg = "Unknown error";
  else {
    msg = describe_error (err);
    // Ugly, but it's hard to fix it better..
    int i = search (msg, "\nRXML frame backtrace:\n");
    if (i >= 0) {
      rxml_bt = (msg[i + sizeof ("\nRXML frame backtrace:")..] / "\n | ")[1..];
      if (sizeof (rxml_bt)) rxml_bt[-1] = rxml_bt[-1][..sizeof (rxml_bt[-1]) - 2];
      msg = msg[..i - 1];
    }
  }
  function dp =  master()->describe_program;

  string cwd = getcwd() + "/";
  array bt;
  if (arrayp (err) && sizeof (err) >= 2 && arrayp (err[1]) ||
      objectp (err) && err->is_generic_error) {

    object d = master()->Describer();
    d->identify_parts(err[1]);
    function dcl = d->describe_comma_list;
    bt = ({});

    foreach (reverse (err[1]), mixed ent) {
      string file, func, descr;
      int line;
      if (arrayp (ent)) {
	if (sizeof (ent) && stringp (ent[0]))
	  if (ent[0][..sizeof (cwd) - 1] == cwd)
	    file = ent[0] = ent[0][sizeof (cwd)..];
	  else
	    file = ent[0];
	if (sizeof (ent) >= 2) line = ent[1];
	if (sizeof (ent) >= 3)
	  if(functionp(ent[2])) {
	    func = "";
	    if (object o = function_object (ent[2])) {
	      string s;
	      if (!catch (s = sprintf ("%O",o)) && s != "object")
		func = s + "->";
	    }
	    func += function_name(ent[2]);
	    if (!file)
	      catch {
		file = dp(object_program( function_object( ent[2] ) ) );
		if (file[..sizeof (cwd) - 1] == cwd) file = file[sizeof (cwd)..];
	      };
	  }
	  else if (stringp(ent[2])) func = ent[2];
	  else func ="<unknown function>";
	if (sizeof (ent) >= 4)
	  descr = func + "(" +dcl(ent[3..],999999)+")";
	else
	  descr = func + "()";
      }
      else if (stringp (ent)) descr = ent;
      else if (catch (descr = sprintf ("%O", ent)))
	descr = "???";
      bt += ({({file, line, func, descr})});
    }
  }

  add_cvs_ids (err);
  e[id] = ({msg,rxml_bt,bt,describe_backtrace (err),raw_url,censor(raw)});
  return id;
}

array get_error(string eid, string md5)
{
  mapping e = roxen.query_var("errors");
  if(e) {
    array r = e[(int)eid];
    if (r && (md5 == Crypto.string_to_hex(Crypto.md5()->
					  update(r[3])->digest()))) {
      return r;
    }
  }
  return 0;
}


void internal_error(array _err)
{
  misc->no_proto_cache = 1;
  mixed err = _err;
  _err = 0; // hide in backtrace, they are bad enough anyway...
  array err2;
  if(port_obj && port_obj->query("show_internals"))
  {
    err2 = catch {
      file = Roxen.http_low_answer(500, format_backtrace(store_error(err)));
    };
    if(err2) {
      werror("Internal server error in internal_error():\n" +
	     describe_backtrace(err2)+"\n while processing \n"+
	     describe_backtrace(err));
      file = Roxen.http_low_answer(500, "<h1>Error: The server failed to "
			     "fulfill your query, due to an "
			     "internal error in the internal error routine.</h1>");
    }
  } else {
    file = Roxen.http_low_answer(500, "<h1>Error: The server failed to "
			   "fulfill your query, due to an internal error.</h1>");
  }
  report_error("Internal server error: " +
	       describe_backtrace(err) + "\n");
#ifdef INTERNAL_ERROR_DEBUG
  report_error(sprintf("Raw backtrace:%O\n", err));
#endif /* INTERNAL_ERROR_DEBUG */
}

// This macro ensures that something gets reported even when the very
// call to internal_error() fails. That happens eg when this_object()
// has been destructed.
#define INTERNAL_ERROR(err)							\
  if (mixed __eRr = catch (internal_error (err)))				\
    report_error("Internal server error: " + describe_backtrace(err) +		\
		 "internal_error() also failed: " + describe_backtrace(__eRr))

int wants_more()
{
  return !!cache;
}

void do_log( int|void fsent )
{
  MARK_FD("HTTP logging"); // fd can be closed here
  TIMER_START(do_log);
  if(conf)
  {
    int len;
    if(!fsent && pipe)
      file->len = pipe->bytes_sent();
    else
      file->len = fsent;
    if(conf)
    {
      if(file->len > 0) conf->sent+=file->len;
      file->len += misc->_log_cheat_addition;
      conf->log(file, this_object());
    }
  }
  if( !port_obj ) 
  {
    TIMER_END(do_log);
    MERGE_TIMERS(conf);
    if( conf )
      conf->connection_drop( this_object() );
    mixed err = catch  // paranoia
    {
      my_fd->close();
      destruct( my_fd );
      destruct( );
    };
#ifdef DEBUG
    if (err) report_debug ("Close failure (3): %s", describe_backtrace (err));
#endif
    return;
  }
  TIMER_END(do_log);
  end(1);
  return;
}

#ifdef FD_DEBUG
void timer(int start)
{
  if(pipe) {
    // FIXME: Disconnect if no data has been sent for a long while
    //   (30min?)
    MARK_FD(sprintf("HTTP piping %d %d %d %d (%s)",
		    pipe->sent,
		    stringp(pipe->current_input) ?
		    strlen(pipe->current_input) : -1,
		    pipe->last_called,
		    predef::time(1) - start,
		    not_query));
  } else {
    MARK_FD("HTTP piping, but no pipe for "+not_query);
  }
  call_out(timer, 30, start);
}
#endif

string handle_error_file_request (string msg, array(string) rxml_bt, array(array) bt,
				  string raw_bt_descr, string raw_url, string raw)
{
  string data = Stdio.read_bytes(variables->file);

  if(!data)
    return error_page_header (variables->file) +
      "<h3><i>Source file could not be read</i></h3>\n"
      "</body></html>";

  string down;
  int next = (int) variables->off + 1;

  if(next < sizeof (bt)) {
    [string file, int line, string func, string descr] = bt[next];
    down = link_to (file, line, func, (int) variables->error, next);
  }
  else
    down = "<a>";

  int off = 49;
  array (string) lines = data/"\n";
  int start = (int)variables->line-50;
  if(start < 0)
  {
    off += start;
    start = 0;
  }
  int end = (int)variables->line+50;

  // The highlighting doesn't work well enough on recent pike code.
  //lines=highlight_pike("foo", ([ "nopre":1 ]), lines[start..end]*"\n")/"\n";
  lines = map (lines[start..end], Roxen.html_encode_string);

  if(sizeof(lines)>off) {
    sscanf (lines[off], "%[ \t]%s", string indent, string code);
    if (!sizeof (code)) code = "&nbsp;";
    lines[off] = indent + "<font size='+1'><b>"+down+code+"</a></b></font></a>";
  }
  lines[max(off-20,0)] = "<a name=here>"+lines[max(off-20,0)]+"</a>";

  return error_page_header (variables->file) +
    "<font size='-1'><pre>" + lines*"\n" + "</pre></font>\n"
    "</body></html>";
}

// The wrapper for multiple ranges (send a multipart/byteranges reply).
#define BOUND "Byte_Me_Now_Roxen"

class MultiRangeWrapper
{
  object file;
  function rcb;
  int current_pos, len, separator;
  array ranges;
  array range_info = ({});
  string type;
  string stored_data = "";
  void create(mapping _file, mapping heads, array _ranges, object id)
  {
    file = _file->file;
    len = _file->len;
    foreach(indices(heads), string h)
    {
      if(lower_case(h) == "content-type") {
	type = heads[h];
	m_delete(heads, h);
      }
    }
    if(id->request_headers["request-range"])
      heads["Content-Type"] = "multipart/x-byteranges; boundary=" BOUND;
    else
      heads["Content-Type"] = "multipart/byteranges; boundary=" BOUND;
    ranges = _ranges;
    int clen;
    foreach(ranges, array range)
    {
      int rlen = 1+ range[1] - range[0];
      string sep =  sprintf("\r\n--" BOUND "\r\nContent-Type: %s\r\n"
			    "Content-Range: bytes %d-%d/%d\r\n\r\n",
			    type||"application/octet-stream",
			    @range, len);
      clen += rlen + strlen(sep);
      range_info += ({ ({ rlen, sep }) });
    }
    clen += strlen(BOUND) + 8; // End boundary length.
    _file->len = clen;
  }

  string read(int num_bytes)
  {
    string out = stored_data;
    int rlen, total = num_bytes;
    num_bytes -= strlen(out);
    stored_data = "";
    foreach(ranges, array range)
    {
      rlen = range_info[0][0] - current_pos;
      if(separator != 1) {
	// New range, write new separator.
	//	write("Initiating new range %d -> %d.\n", @range);
	out += range_info[0][1];
	num_bytes -= strlen(range_info[0][1]);
	file->seek(range[0]);
	separator = 1;
      }
      if(num_bytes > 0) {
	if(rlen <= num_bytes)
	  // Entire range fits.
	{
	  out += file->read(rlen);
	  num_bytes -= rlen;
	  current_pos = separator = 0;
	  ranges = ranges[1..]; // One range done.
	  range_info = range_info[1..];
	} else {
	  out += file->read(num_bytes);
	  current_pos += num_bytes;
	  num_bytes = 0;
	}
      }
      if(num_bytes <= 0)
	break; // Return data
    }
    if(!sizeof(ranges) && separator != 2) {
      // End boundary. Only write once and only when
      // no more ranges remain.
      separator = 2;
      out += "\r\n--" BOUND "--\r\n";
    }
    if(strlen(out) > total)
    {
      // Oops. too much data again. Write and store. Write and store.
      stored_data = out[total..];
      return out[..total-1];
    }
    return out ; // We are finally done.
  }

  mixed `->(string what)
  {
    switch(what) {
     case "read":
      return read;

     case "set_nonblocking":
      return 0;

     case "query_fd":
      return lambda() { return -1; };

     default:
      return file[what];
    }
  }
}


// Parse the range header into multiple ranges.
array parse_range_header(int len)
{
  array ranges = ({});
  foreach(misc->range / ",", string range)
  {
    int r1, r2;
    if(range[0] == '-' ) {
      // End of file request
      r1 = (len - (int)range[1..]);
      if(r1 < 0) {
	// Entire file requested here.
	r1 = 0;
      }
      ranges += ({ ({ len - (int)range[1..], len-1 }) });
    } else if(range[-1] == '-') {
      // Rest of file request
      r1 = (int)range;
      if(r1 >= len)
	// Range beginning is after EOF.
	continue;
      ranges += ({ ({ r1, len-1 }) });
    } else if(sscanf(range, "%d-%d", r1, r2)==2) {
      // Standard range
      if(r1 <= r2) {
	if(r1 >= len)
	  // Range beginning is after EOF.
	  continue;
	ranges += ({ ({ r1, r2 < len ? r2 : len -1  }) });
      }
      else
	// A syntatically incorrect range should make the server
	// ignore the header. Really.
	return 0;
    } else
      // Invalid syntax again...
      return 0;
  }
  return ranges;
}

// Tell the client that it can start sending some more data
void ready_to_receive()
{
  if (clientprot == "HTTP/1.1" && request_headers->Expect &&
      (request_headers->Expect ==  "100-continue" ||
       has_value(request_headers->Expect, "100-continue" )))
    my_fd->write("HTTP/1.1 100 Continue\r\n");
}

// Send the result.
void send_result(mapping|void result)
{
  TIMER_START(send_result);

  CHECK_FD_SAFE_USE;

  array err;
  int tmp;
  mapping heads;
  string head_string="";
  if (result)
    file = result;
#ifdef PROFILE
  float elapsed = SECHR(HRTIME()-req_time);
  string nid =
#ifdef FILE_PROFILE
    (raw_url/"?")[0]
#else
    dirname((raw_url/"?")[0])
#endif
         ;
  array p;
  if(!(p=conf->profile_map[nid]))
    p = conf->profile_map[nid] = ({0,0.0,0.0});
  p[0]++;
  p[1] += elapsed;
  if(elapsed > p[2]) p[2]=elapsed;
#endif

  REQUEST_WERR(sprintf("HTTP: response: prot %O, method %O, file %O, misc: %O",
		       prot, method, file, misc));

  if( prot == "HTTP/0.9" )  misc->no_proto_cache = 1;

  if(!leftovers) 
    leftovers = data||"";

  if(!mappingp(file))
  {
    misc->no_proto_cache = 1;
    if(misc->error_code)
      file = Roxen.http_low_answer(misc->error_code, errors[misc->error]);
    else if(err = catch {
      file = conf->error_file( this_object() );
    })
      INTERNAL_ERROR(err);
  } 
    else 
    {
      if((file->file == -1) || file->leave_me)
      {
	TIMER_END(send_result);
	file = 0;
	pipe = 0;
        if(do_not_disconnect) 
          return;
        my_fd = 0;
        return;
      }

      if(file->type == "raw")  file->raw = 1;
      else if(!file->type)     file->type="text/plain";
    }

    if(!file->raw)
    {
      heads = ([]);
      if (!file->stat) file->stat = misc->stat;
      if(objectp(file->file)) {
	if(!file->stat)
	  file->stat = file->file->stat();
	if (zero_type(misc->cacheable) && file->file->is_file) {
	  // Assume a cacheablity on the order of the age of the file.
	  misc->cacheable = (predef::time(1) - file->stat[ST_MTIME])/4;
	}
      }

      if( Stat fstat = file->stat )
      {
	if( !file->len )
	  file->len = fstat[1];

	if ( fstat[ST_MTIME] > misc->last_modified )
	  misc->last_modified = fstat[ST_MTIME];
      }	

      if( !zero_type(misc->cacheable) &&
	  (misc->cacheable < INITIAL_CACHEABLE) ) {
	if (misc->cacheable == 0)
	  heads["Expires"] = Roxen.http_date( 0 );
	else
	  heads["Expires"] = Roxen.http_date( predef::time(1)+misc->cacheable );

	if (misc->cacheable < INITIAL_CACHEABLE) {
	  // Data with expiry is assumed to have been generated at the
	  // same instant.
	  misc->last_modified = predef::time(1);
	}
      }

      if (misc->last_modified)
	heads["Last-Modified"] = Roxen.http_date(misc->last_modified);

//	    werror("lm:    %O\n"
//		   "cacheable: %O\n",
//		   misc->last_modified,
//		   misc->cacheable);

      if(since && (!file->error || file->error == 200) && misc->last_modified)
      {
	/* ({ time, len }) */
	array(int) since_info = Roxen.parse_since( since );
//	  werror("since: %{%O, %}\n"
//		 "lm:    %O\n"
//		 "cacheable: %O\n",
//		 since_info,
//		 misc->last_modified,
//		 misc->cacheable);
	if ( ((since_info[0] >= misc->last_modified) && 
	      ((since_info[1] == -1) || (since_info[1] == file->len)))
	     // never say 'not modified' if cacheable has been lowered.
	     && (zero_type(misc->cacheable) ||
		 (misc->cacheable >= INITIAL_CACHEABLE))
	     // actually ok, or...
//	       || ((misc->cacheable>0) 
//		   && (since_info[0] + misc->cacheable<= predef::time(1))
//		   // cacheable, and not enough time has passed.
	     )
	{
	  file->error = 304;
	  file->file = 0;
	  file->data="";
	}
      }

      if(prot != "HTTP/0.9") 
      {
        string h, charset="";

        if( stringp(file->data) )
        {
	  if (sizeof (output_charset) ||
	      has_prefix (file->type, "text/") ||
	      (String.width(file->data) > 8))
          {
	    int allow_entities =
	      has_prefix(file->type, "text/xml") ||
	      has_prefix(file->type, "text/html");
            [charset,file->data] = output_encode( file->data, allow_entities );
            if( charset && (search(file["type"], "; charset=") == -1))
	      charset = "; charset="+charset;
            else
              charset = "";
          }
          file->len = strlen(file->data);
        }
        heads["Content-Type"] = file["type"]+charset;
        heads["Accept-Ranges"] = "bytes";
        heads["Server"] = replace(version(), " ", "·");
        if( misc->connection )
          heads["Connection"] = misc->connection;

        if(file->encoding) heads["Content-Encoding"] = file->encoding;

        if(!file->error)
          file->error=200;

        heads->Date = Roxen.http_date(predef::time(1));
        if(file->expires)
          heads->Expires = Roxen.http_date(file->expires);

        if(mappingp(file->extra_heads))
          heads |= file->extra_heads;

        if(mappingp(misc->moreheads))
          heads |= misc->moreheads;

        if(misc->range && file->len && objectp(file->file) && !file->data &&
           file->error == 200 && (method == "GET" || method == "HEAD"))
          // Plain and simple file and a Range header. Let's play.
          // Also we only bother with 200-requests. Anything else should be
          // nicely and completely ignored. Also this is only used for GET and
          // HEAD requests.
        {
          // split the range header. If no valid ranges are found, ignore it.
          // If one is found, send that range. If many are found we need to
          // use a wrapper and send a multi-part message.
          array ranges = parse_range_header(file->len);
          if(ranges) // No incorrect syntax...
          {
            misc->no_proto_cache = 1;
            if(sizeof(ranges)) // And we have valid ranges as well.
            {
              file->error = 206; // 206 Partial Content
              if(sizeof(ranges) == 1)
              {
                heads["Content-Range"] = sprintf("bytes %d-%d/%d",
                                                 @ranges[0], file->len);
                file->file->seek(ranges[0][0]);
                if(ranges[0][1] == (file->len - 1) &&
                   GLOBVAR(RestoreConnLogFull))
                  // Log continuations (ie REST in FTP), 'range XXX-'
                  // using the entire length of the file, not just the
                  // "sent" part. Ie add the "start" byte location when logging
                  misc->_log_cheat_addition = ranges[0][0];
                file->len = ranges[0][1] - ranges[0][0]+1;
              } else {
                // Multiple ranges. Multipart reply and stuff needed.
                // We do this by replacing the file object with a wrapper.
                // Nice and handy.
                file->file = MultiRangeWrapper(file, heads, ranges, this_object());
              }
            } else {
              // Got the header, but the specified ranges was out of bounds.
              // Reply with a 416 Requested Range not satisfiable.
              file->error = 416;
              heads["Content-Range"] = "*/"+file->len;
              if(method == "GET") {
                file->data = "The requested byte range is out-of-bounds. Sorry.";
                file->len = strlen(file->data);
                file->file = 0;
              }
            }
          }
        }
	head_string = sprintf("%s %d %s\r\n",
			      prot, file->error,
			      file->rettext ||errors[file->error]||"");

//         if( file->len > 0 || (file->error != 200) )
	heads["Content-Length"] = (string)file->len;

        // Some browsers, e.g. Netscape 4.7, doesn't trust a zero
        // content length when using keep-alive. So let's force a
        // close in that case.
        if( file->error/100 == 2 && file->len <= 0 )
	{
	  heads->Connection = "close";
          misc->connection = "close";
        }
	if( mixed err = catch( head_string += Roxen.make_http_headers( heads ) ) )
	{
#ifdef DEBUG
	  report_debug ("Roxen.make_http_headers failed: " + describe_error (err));
#endif
	  foreach( indices( heads ), string x )
	    if( stringp( heads[x] ) )
	      head_string += x+": "+heads[x]+"\r\n";
	    else if( arrayp( heads[x] ) )
	      foreach( heads[x], string xx )
		head_string += x+": "+xx+"\r\n";
	    else if( catch {
	      head_string += x+": "+(string)heads[x];
	    } )
	      error("Illegal value in headers array! "
		    "Expected string or array(string)\n");
	  head_string += "\r\n";
	}

        if( strlen( charset ) || String.width( head_string ) > 8 )
          head_string = output_encode( head_string, 0, charset )[1];
        conf->hsent += strlen(head_string);
      }
    }
#if 0
    REQUEST_WERR(sprintf("HTTP: Sending result for prot:%O, method:%O, file:%O",
			 prot, method, file));
#endif
    MARK_FD("HTTP handled");
  
    if( (method!="HEAD") && (file->error!=304) )
      // No data for these two...
    {
#ifdef RAM_CACHE
      if( (misc->cacheable > 0) && (file->data || file->file) &&
	  (prot != "HTTP/0.9") && !misc->no_proto_cache)
      {
        if( file->len>0 && // known length.
	    ((file->len + strlen( head_string )) < 
             conf->datacache->max_file_size) 
            && misc->cachekey )
        {
          string data = "";
          if( file->file )   data += file->file->read();
          if( file->data )   data += file->data;
	  MY_TRACE_ENTER (sprintf ("Storing in ram cache, entry: %O", raw_url), 0);
	  MY_TRACE_LEAVE ("");
          conf->datacache->set( raw_url, data,
                                ([
                                  // We have to handle the date header.
                                  "hs":head_string,
                                  "key":misc->cachekey,
                                  "callbacks":misc->_cachecallbacks,
                                  "len":file->len,
                                  // fix non-keep-alive when sending from cache
                                  "raw":file->raw,
                                  "error":file->error,
                                  "mtime":(file->stat && file->stat[ST_MTIME]),
                                  "rf":realfile,
                                ]), 
                                misc->cacheable );
          file = ([ "data":data, "raw":file->raw, "len":strlen(data) ]);
        }
      }
#endif
      if(!kept_alive &&
	 (file->len > 0) &&
	 ((sizeof(head_string) + file->len) < (HTTP_BLOCKING_SIZE_THRESHOLD)))
      {
	// The first time we get a request, the output buffers will
	// be empty. We can thus just do a single blocking write()
	// if the data will fit in the output buffer (usually 4KB).
        int s;
	TIMER_END(send_result);
	TIMER_START(blocking_write);
	string data = head_string +
	  (file->file?file->file->read(file->len):
	   (file->data[..file->len-1]));
	REQUEST_WERR (sprintf ("HTTP: Send %O", data));
	s = my_fd->write(data);
	TIMER_END(blocking_write);
        do_log( s );
        return;
      }
      if(strlen(head_string))                 send(head_string);
      if(file->data && strlen(file->data))    send(file->data, file->len);
      if(file->file)                          send(file->file, file->len);
    }
    else 
    {
      if( strlen( head_string ) < (HTTP_BLOCKING_SIZE_THRESHOLD))
      {
	REQUEST_WERR (sprintf ("HTTP: Send %O", head_string));
	do_log( my_fd->write( head_string ) );
        return;
      }
      send(head_string);
      file->len = 1; // Keep those alive, please...
    }
  TIMER_END(send_result);
  start_sender();
}


// Execute the request
void handle_request( )
{
  REQUEST_WERR("HTTP: handle_request()");
  TIMER_START(handle_request);
#ifdef MAGIC_ERROR
  if(prestate->old_error)
  {
    array err = get_error(variables->error, variables->error_md5 || "NONE");
    if(err && arrayp(err))
    {
      if(prestate->plain)
      {
	file = ([
	  "type":"text/plain",
	  "data":generate_bugreport( @err ),
	]);
	TIMER_END(handle_request);
        send_result();
        return;
      } else {
	if(prestate->find_file)
        {
	  if (!roxen.configuration_authenticate (this_object(), "View Settings"))
	    file = Roxen.http_auth_required("admin");
	  else
	    file = ([
	      "type":"text/html",
	      "data":handle_error_file_request( @err ),
	    ]);
	  TIMER_END(handle_request);
          send_result();
          return;
	}
      }
    }
  }
#endif /* MAGIC_ERROR */

  MARK_FD("HTTP handling request");

  array e;
  mapping result;
  if(e= catch(result = conf->handle_request( this_object() )))
    INTERNAL_ERROR( e );

  if (result && result->pipe)
    // Could be destructed here already since handle_request might
    // have handed over us to another thread that finished quickly.
    return;

  file = result;

  if( file && file->try_again_later )
  {
    if( objectp( file->try_again_later ) )
      ;
    else
      call_out( roxen.handle, file->try_again_later, handle_request );
    return;
  }

  TIMER_END(handle_request);
  send_result();
}

string url_base()
// See the RequestID class for doc.
{
  // Note: Code duplication in base_server/prototypes.pike.

  if (!cached_url_base) {
    // First look at the host header in the request.
    if (string tmp = misc->host) {
      int scanres = sscanf (tmp, "%[^:]:%d", string host, int port);
      if (scanres < 2)
	// Some clients don't send the port in the host header.
	port = port_obj->port;
      if (port_obj->default_port == port)
	// Remove redundant port number.
	cached_url_base = port_obj->prot_name + "://" + host;
      else
	if (scanres < 2)
	  cached_url_base = port_obj->prot_name + "://" + host + ":" + port;
	else
	  cached_url_base = port_obj->prot_name + "://" + tmp;
    }

    // Then use the port object.
    else {
      string host = port_obj->conf_data[conf]->hostname;
      if (host == "*")
	if (conf && sizeof (host = conf->get_url()) &&
	    sscanf (host, "%*s://%[^:/]", host) == 2) {
	  // Use the hostname in the configuration url.
	}
	else
	  // Fall back to the numeric ip.
	  host = port_obj->ip;
      cached_url_base = port_obj->prot_name + "://" + host;
      if (port_obj->port != port_obj->default_port)
	cached_url_base += ":" + port_obj->port;
    }

    if (string p = misc->site_prefix_path) cached_url_base += p;
    cached_url_base += "/";
  }
  return cached_url_base;
}

/* We got some data on a socket.
 * =================================================
 */
int processed;
// array ccd = ({});
void got_data(mixed fooid, string s)
{
  REQUEST_WERR(sprintf("HTTP: Got %O", s));

  if(wanted_data)
  {
    // NOTE: No need to make a data buffer if it's a small request.
    if(strlen(s) + have_data < wanted_data)
    {
      if (!data_buffer) {
	// The 16384 is some reasonable extra padding to
	// avoid having to realloc.
	data_buffer = String.Buffer(wanted_data + 16384);
	data_buffer->add(data);
	data = "";
      }
      data_buffer->add(s);
      have_data += strlen(s);

      // Reset timeout.
      remove_call_out(do_timeout);
      call_out(do_timeout, 90);
      REQUEST_WERR("HTTP: We want more data.");
      return;
    }
    if (data_buffer) {
      data_buffer->add(s);
      data = data_buffer->get();
      data_buffer = 0;
    } else {
      data += s;
    }
  }

  if (mixed err = catch {
    MARK_FD("HTTP got data");
    raw += s;

    // The port has been closed, but old (probably keep-alive)
    // connections remain.  Close those connections.
    if( !port_obj ) 
    {
      if( conf )
	conf->connection_drop( this_object() );
      mixed err = catch  // paranoia
      {
	my_fd->set_blocking();
	my_fd->close();
	destruct( my_fd );
	destruct( );
      };
#ifdef DEBUG
      if (err) report_debug ("Close failure (4): %s", describe_backtrace (err));
#endif
      return;
    }

    switch( parse_got( s ) )
    {
      case 0:
	REQUEST_WERR("HTTP: Request needs more data.");
	return;

      case 1:
	REQUEST_WERR("HTTP: Stupid Client Error.");
	my_fd->write((prot||"HTTP/1.0")+" 500 Illegal request\r\n"
		     "Content-Length: 0\r\n"+
		     "Date: "+Roxen.http_date(predef::time())+"\r\n"
		     "\r\n");
	end();
	return;			// Stupid request.
    
      case 2:
	REQUEST_WERR("HTTP: Done.");
	end();
	return;
    }

    if( method == "GET" || method == "HEAD" )
      misc->cacheable = INITIAL_CACHEABLE; // FIXME: Make configurable.

    TIMER_START(find_conf);
    string path;
    if( !conf || !(path = port_obj->path ) 
	|| (sizeof( path ) 
	    && raw_url[..sizeof(path) - 1] != path) )

    {
      // FIXME: port_obj->name & port_obj->default_port are constant
      // consider caching them?

      // RFC 2068 5.1.2:
      //
      // To allow for transition to absoluteURIs in all requests in future
      // versions of HTTP, all HTTP/1.1 servers MUST accept the absoluteURI
      // form in requests, even though HTTP/1.1 clients will only generate
      // them in requests to proxies. 
      if (has_prefix(raw_url, port_obj->name+"://") &&
	  (conf = port_obj->find_configuration_for_url(raw_url,
						       this_object(), 1))) {
	sscanf(raw_url[sizeof(port_obj->name+"://")..],
	       "%[^/]%s", misc->host, raw_url);
      } else {
	if (misc->host) {
	  conf =
	    port_obj->find_configuration_for_url(port_obj->name + "://" +
						 misc->host +
						 (search(misc->host, ":")<0?
						  (":"+port_obj->port):"") +
						 raw_url,
						 this_object());
	} else {
	  conf =
	    port_obj->find_configuration_for_url(port_obj->name +
						 "://*:" + port_obj->port +
						 raw_url,
						 this_object());
	}
      }
    }
    else if( strlen(path) )
      adjust_for_config_path( path );

    TIMER_END(find_conf);

    if (rawauth)
    {
      /* Need to authenticate with the configuration */
      misc->no_proto_cache = 1;
      array(string) y = rawauth / " ";
      realauth = 0;
      auth = 0;
      if (sizeof(y) >= 2)
      {
	y[1] = MIME.decode_base64(y[1]);
	realauth = y[1];
      }
    }


    if( misc->proxyauth )
    {
      /* Need to authenticate with the configuration */
      misc->no_proto_cache = 1;
      if (sizeof(misc->proxyauth) >= 2)
      {
	//    misc->proxyauth[1] = MIME.decode_base64(misc->proxyauth[1]);
	if (conf->auth_module)
	  misc->proxyauth
	    = conf->auth_module->auth(misc->proxyauth,this_object() );
      }
    }

    conf->connection_add( this_object(), connection_stats );
    conf->received += strlen(raw);
    conf->requests++;

    CHECK_FD_SAFE_USE;
    my_fd->set_close_callback(0);
    my_fd->set_read_callback(0);
    if (my_fd->set_accept_callback) my_fd->set_accept_callback (0);
    processed=1;

    remove_call_out(do_timeout);
#ifdef RAM_CACHE
    TIMER_START(cache_lookup);
    array cv;
    if( prot != "HTTP/0.9" &&
	misc->cacheable    &&
	!misc->no_proto_cache &&
	!since             &&
	(cv = conf->datacache->get( raw_url )) )
    {
      MY_TRACE_ENTER (sprintf ("Found %O in ram cache - checking entry", raw_url), 0);
      if( !cv[1]->key ) {
	MY_TRACE_LEAVE ("Entry invalid due to zero key");
	conf->datacache->expire_entry( raw_url );
      }
      else 
      {
	int can_cache = 1;
	if(!leftovers) 
	  leftovers = data||"";
	
	string d = cv[ 0 ];
	file = cv[1];
	
	if( sizeof(file->callbacks) )
	{
	  if( mixed e = catch 
	  {
	    foreach( file->callbacks, function f ) {
	      MY_TRACE_ENTER (sprintf ("Checking with %s",
				       master()->describe_function (f)), 0);
	      if( !f(this_object(), cv[1]->key ) )
	      {
		MY_TRACE_LEAVE ("Entry invalid according to callback");
		MY_TRACE_LEAVE ("");
		can_cache = 0;
		break;
	      }
	      MY_TRACE_LEAVE ("");
	    }
	  } )
	  {
	    INTERNAL_ERROR( e );
	    TIMER_END(cache_lookup);
	    send_result();
	    return;
	  }
	}
	if( !cv[1]->key )
	{
	  MY_TRACE_LEAVE ("Entry invalid due to zero key");
	  conf->datacache->expire_entry( raw_url );
	  can_cache = 0;
	}
	if( can_cache )
	{
#ifndef RAM_CACHE_ASUME_STATIC_CONTENT
	  Stat st;
	  if( !file->rf || !file->mtime || 
	      ((st = file_stat( file->rf )) && st->mtime == file->mtime ))
#endif
	  {
	    string fix_date( string headers )
	    {
	      string a, b;
	      if( sscanf( headers, "%sDate: %*s\n%s", a, b ) == 3 )
		return a+"Date: "+Roxen.http_date( predef::time(1) ) +"\r\n"+b;
	      return headers;
	    };
	    
	    MY_TRACE_LEAVE ("Using entry from ram cache");
	    conf->hsent += strlen(file->hs);
	    cache_status["protcache"] = 1;
	    if( strlen( d ) < (HTTP_BLOCKING_SIZE_THRESHOLD) )
	    {
	      TIMER_END(cache_lookup);
	      do_log( my_fd->write( fix_date(file->hs)+d ) );
	    } 
	    else 
	    {
	      TIMER_END(cache_lookup);
	      send( fix_date(file->hs)+d );
	      start_sender( );
	    }
	    return;
	  }
#ifndef RAM_CACHE_ASUME_STATIC_CONTENT
	  else
	    MY_TRACE_LEAVE (
	      sprintf ("Entry out of date (disk: %s, cache: mtime %d)",
		       st ? "mtime " + st->mtime : "gone", file->mtime));
#endif
	} else
	  misc->no_proto_cache = 1; // Never cache in this case.
	file = 0;
      }
    }
    TIMER_END(cache_lookup);
#endif	// RAM_CACHE
    TIMER_START(parse_request);
    if( things_to_do_when_not_sending_from_cache( ) )
      return;
    REQUEST_WERR(sprintf("HTTP: cooked headers %O", request_headers));
    REQUEST_WERR(sprintf("HTTP: cooked variables %O", real_variables));
    REQUEST_WERR(sprintf("HTTP: cooked cookies %O", cookies));
    TIMER_END(parse_request);

    REQUEST_WERR("HTTP: Calling roxen.handle().");
    roxen.handle(handle_request);
  })
  {
    report_error("Internal server error: " + describe_backtrace(err));
    my_fd->set_blocking();
    my_fd->close();
    disconnect();
  }
}

/* Get a somewhat identical copy of this object, used when doing
 * 'simulated' requests. */

object clone_me()
{
  object c,t;
  c=object_program(t=this_object())(0, port_obj, conf);
#ifdef ID_OBJ_DEBUG
  werror ("clone %O -> %O\n", t, c);
#endif

  c->port_obj = port_obj;
  c->conf = conf;
  c->root_id = root_id;
  c->time = time;
  c->raw_url = raw_url;

  c->real_variables = copy_value( real_variables );
  c->variables = FakedVariables( c->real_variables );
  c->misc = copy_value( misc );
  c->misc->orig = t;

  c->connection_misc = connection_misc;

  c->prestate = prestate;
  c->supports = supports;
  c->config = config;
  c->client_var = client_var;

  c->remoteaddr = remoteaddr;
  c->host = host;

  c->client = client;
  c->referer = referer;
  c->pragma = pragma;

  c->cookies = cookies;
  c->request_headers = request_headers;
  c->my_fd = 0;
  c->prot = prot;
  c->clientprot = clientprot;
  c->method = method;

// realfile virtfile   // Should not be copied.
  c->rest_query = rest_query;
  c->raw = raw;
  c->query = query;
  c->not_query = not_query;
  c->data = data;
  c->extra_extension = extra_extension;

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
  else if((predef::time(1) - time) > 4800)
    end();
}

static void create(object f, object c, object cc)
{
  if(f)
  {
    f->set_nonblocking(got_data, f->query_write_callback(), end);
    my_fd = f;
    MARK_FD("HTTP connection");
    if( c ) port_obj = c;
    if( cc ) conf = cc;
    time = predef::time(1);
    call_out(do_timeout, 90);
  }
  root_id = this_object();
}

void chain(object f, object c, string le)
{
  my_fd = f;
  f->set_nonblocking(0, f->query_write_callback(), end);
  port_obj = c;
  processed = 0;
  do_not_disconnect=-1;		// Block destruction until we return.
  MARK_FD("HTTP kept alive");
  time = predef::time();

  if ( le && strlen( le ) )
    got_data( 0,le );
  else
  {
    // If no pipelined data is available, call out...
    remove_call_out(do_timeout);
    call_out(do_timeout, 90);
  }

  if(!my_fd)
  {
    if(do_not_disconnect == -1)
    {
      do_not_disconnect=0;
      disconnect();
    }
  }
  else
  {
    if(do_not_disconnect == -1)
      do_not_disconnect = 0;
    if(!processed)
    {
      f->set_nonblocking(got_data, f->query_write_callback(), end);
    }
  }
}

string _sprintf( )
{
  return "RequestID(" + (raw_url||"") + ")"
#ifdef ID_OBJ_DEBUG
    + (__marker ? "[" + __marker->count + "]" : "")
#endif
    ;
}

Stdio.File connection( )
{
  return my_fd;
}

Configuration configuration()
{
  return conf;
}
