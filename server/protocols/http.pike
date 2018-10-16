// This is a roxen protocol module.
// Modified by Francesco Chemolli to add throttling capabilities.
// Copyright © 1996 - 2004, Roxen IS.

constant cvs_version = "$Id$";
// #define REQUEST_DEBUG
#define MAGIC_ERROR

#define REQUESTID this

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
int req_time = HRTIME();
#endif

#ifdef REQUEST_DEBUG
int footime, bartime;
#define REQUEST_WERR(X) do {bartime = gethrtime()-footime; werror("%s (%d)\n", (X), bartime);footime=gethrtime();} while (0)
#else
#define REQUEST_WERR(X) do {} while (0)
#endif

#ifdef FD_DEBUG
#ifdef REQUEST_DEBUG
#define FD_WERR(X)	REQUEST_WERR(X)
#else
#define FD_WERR(X)	werror("%s\n", (X))
#endif
#define MARK_FD(X) do {							\
    int _fd = my_fd && my_fd->query_fd ? my_fd->query_fd() : -1;	\
    FD_WERR("FD " + (_fd == -1 ? sprintf ("%O", my_fd) : _fd) + ": " + (X)); \
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

private static multiset(string) none_match;

int kept_alive;

#if defined(DEBUG) && defined(THREADS)
#define CHECK_FD_SAFE_USE do {						\
    if (this_thread() != roxen->backend_thread &&			\
	(my_fd->query_read_callback() || my_fd->query_write_callback() || \
	 my_fd->query_close_callback() ||				\
	 !zero_type (find_call_out (do_timeout))))			\
      error ("Got callbacks but not called from backend thread.\n"	\
	     "backend_thread:%O\n"					\
	     "this thread:%O\n"						\
	     "rcb:%O\n"							\
	     "wcb:%O\n"							\
	     "ccb:%O\n"							\
	     "timeout:%O\n",						\
	     roxen->backend_thread, this_thread(),			\
	     my_fd->query_read_callback(),				\
	     my_fd->query_write_callback(),				\
	     my_fd->query_close_callback(),				\
	     find_call_out (do_timeout));				\
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
  //decode_map( cookies, decoder );
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


void send(string|object what, int|void len)
{
  if( len>0 && port_obj && port_obj->minimum_byterate )
    call_out( end, len / port_obj->minimum_byterate );

  if(!what) return;
  if(!pipe) setup_pipe();
  if(stringp(what))  {
#ifdef CONNECTION_DEBUG
#define TOSTR(X)	#X
#define TOSTR2(X)	TOSTR(X)

    if (has_prefix(file->type || "", TOSTR2(CONNECTION_DEBUG))) {
      werror ("HTTP: Response =================================================\n"
	      "%s\n",
	      replace (sprintf ("%O", what),
		       ({"\\r\\n", "\\n", "\\t"}),
		       ({"\n",     "\n",  "\t"})));
    } else {
      werror ("HTTP: Response =================================================\n"
	      "string[%d]\n", sizeof(what));
    }
#else
    REQUEST_WERR(sprintf("HTTP: Pipe string %O", what));
#endif
    pipe->write(what);
  }
  else {
#ifdef CONNECTION_DEBUG
    werror ("HTTP: Response =================================================\n"
	    "Stream %O, length %O\n", what, len);
#else
    REQUEST_WERR(sprintf("HTTP: Pipe stream %O, length %O", what, len));
#endif
    pipe->input(what,len);
  }
}

int(0..1) my_fd_busy;
int(0..1) pipe_pending;

void start_sender( )
{
  if (my_fd_busy) {
    // We're waiting for the previous request to finish.
    pipe_pending = 1;
#ifdef CONNECTION_DEBUG
    werror("HTTP: Pipe pending.\n");
#endif
    return;
  }
  if (pipe) 
  {
    MARK_FD("HTTP really handled, piping response");
#ifdef FD_DEBUG
    call_out(timer, 30, predef::time(1)); // Update FD with time...
    pipe->set_done_callback(lambda (int fsent) {
			      remove_call_out(timer);
			      do_log(fsent);
			    } );
#else
    pipe->set_done_callback( do_log );
#endif
    pipe->output( my_fd );
  } else {
    MARK_FD("HTTP really handled, pipe done");
    do_log();
  }
}

void my_fd_released()
{
  my_fd_busy = 0;
#ifdef CONNECTION_DEBUG
  werror("HTTP: Fd released.\n");
#endif
  if (pipe_pending) {
    start_sender();
  }
}

string scan_for_query( string f )
{
  query=0;
  rest_query="";
  if(sscanf(f,"%s?%s", f, query) == 2)
  {
    string v, a, b;

    if (search("&" + query, "&roxen_magic_per_u=%25") != -1) {
      // Broken Safari detected
      //   (http://bugzilla.opendarwin.org/show_bug.cgi?id=6452)
      // Assume that %u and %U won't occur naturally.
      REQUEST_WERR(sprintf("Broken http encoding detected. query=%O\n",
			   query));
      query = replace(query, ({ "%25u", "%25U" }), ({ "%u", "%U" }));
      REQUEST_WERR(sprintf("Repaired query=%O\n", query));
    }
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
    // FIXME: Delayed chaining! my_fd_busy.
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

#if 0
//! Parse cookie strings.
//!
//! @param contents
//!   HTTP transport-encoded cookie header value or array with values.
//!
//! @returns
//!   Returns the resulting current cookie mapping.
//!
//! @deprecated CookieJar
//!
//! @seealso
//!   Use @[CookieJar] instead.
mapping(string:string) parse_cookies( array|string contents )
{
  if(!contents)
    return cookies;

//       misc->cookies += ({contents});

  array tmp = arrayp(contents) ? contents : ({ contents});
  
  foreach(tmp, string cookieheader) {
    
    foreach(((cookieheader/";") - ({""})), string c)
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
  }
  return cookies;
}
#endif

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

  init_cookies();

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
    // FIXME: This code is suspect, and probably ought to be removed.
    NO_PROTO_CACHE();	// FIXME: Why?

    set_output_charset( client_var->charset );
    input_charset = client_var->charset;
    decode_charset_encoding( client_var->charset );
  }
#else
  supports = (< "images", "gifinline", "forms", "mailto">);
#endif
  if (!has_value(client, "MSIE"))
    supports->vary = 1;
  else {
    // FIXME: Vary seems to work in MSIE 7.
  }
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
  if(!supports->cookies && !sizeof(config))
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
      // HTTP/1.1 and later default to keep-alive.
      misc->connection = "keep-alive";
      if (prot == "HTTP/1.0") {
	// But HTTP/1.0 did not.
	misc->connection = "close";
      }
      break;
      
    case 2:     // HTTP/0.9
    case 1:     // PING
      misc->connection = "close";
      method = sl[0];
      f = sl[-1];
      if( sizeof( sl ) == 1 )
	sscanf( method, "%s%*[\r\n]", method );
	
      clientprot = prot = "HTTP/0.9";
      if(method != "PING")
	method = "GET"; // 0.9 only supports get.
      else
      {
	// FIXME: my_fd_busy.
	my_fd->write("PONG\r\n");
	TIMER_END(parse_got_2_parse_line);
	TIMER_END(parse_got_2);
	return 2;
      }
      s = data = ""; // no headers or extra data...
      sscanf( f, "%s%*[\r\n]", f );
      if (sizeof(sl) == 1)
	NO_PROTO_CACHE();
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
     case "if-match": break; // Not supported yet.
     case "if-none-match":
       none_match = (multiset)((contents-" ")/",");
       break;

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
       if (has_prefix(contents, "bytes"))
         // Only care about "byte" ranges.
         misc->range = contents[6..];
       break;

     case "range":
       contents = lower_case(contents-" ");
       if (!misc->range && has_prefix(contents, "bytes"))
         // Only care about "byte" ranges. Also the Request-Range header
         // has precedence since Stupid Netscape (TM) sends both but can't
         // handle multipart/byteranges but only multipart/x-byteranges.
         // Duh!!!
         misc->range = contents[6..];
       break;

     case "connection":
       misc->client_connection = (<@(lower_case(contents)/" " - ({""}))>);
       if (misc->client_connection->close) {
	 misc->connection = "close";
       } else if (misc->client_connection["keep-alive"]) {
	 misc->connection = "keep-alive";
       }
       break;
     case "host":
       misc[linename] = lower_case(contents);
       break;
     case "content-type":
       misc[linename] = contents;
       break;
     case "destination":
       if (mixed err = catch {
	   contents = http_decode_string (Standards.URI(contents)->path);
	 }) {
#ifdef DEBUG
	 report_debug(sprintf("Destination header contained a bad URI: %O\n"
			      "%s", contents, describe_error(err)));
#endif /* DEBUG */
       }
       misc["new-uri"] = VFS.normalize_path (contents);
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
      ready_to_receive();
      TIMER_END(parse_got_2_more_data);
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
  } else {
    leftovers = data;
  }
  TIMER_END(parse_got_2_more_data);
  if (!(< "HTTP/1.0", "HTTP/0.9" >)[prot]) {
    if (!misc->host) {
      // RFC 2616 requires this behaviour.
      REQUEST_WERR("HTTP: HTTP/1.1 request without a host header.");
      // FIXME: my_fd_busy.
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

  if (my_fd) {
    MARK_FD("HTTP closed");
    CHECK_FD_SAFE_USE;
    if (mixed err = catch (my_fd->close())) {
#ifdef DEBUG
      report_debug ("Failed to close http(s) connection: " +
		    describe_error (err));
#endif
    }
    my_fd = 0;
  }

  MERGE_TIMERS(conf);
  destruct();
}

static void cleanup_request_object()
{
  if( conf )
    conf->connection_drop( this_object() );
  xml_data = 0;
}

void end(int|void keepit)
{
  CHECK_FD_SAFE_USE;

  cleanup_request_object();

  if(keepit
     && !file->raw
     && misc->connection != "close"
     && my_fd
     // Is this necessary now when this function no longer is called
     // from the close callback? /mast
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
    o->my_fd_busy = !!pipe;
    o->pipe = 0;
    o->connection_misc = connection_misc;
    o->kept_alive = kept_alive+1;
    object fd = my_fd;
    my_fd=0;
    pipe = 0;
    chained_to = o;
    call_out (o->chain, 0, fd,port_obj,leftovers);
    disconnect();
    return;
  }

  data_buffer = 0;
  pipe = 0;
  disconnect();
}

static void close_cb()
{
#ifdef CONNECTION_DEBUG
  werror ("HTTP: Client close ---------------------------------------------\n");
#else
  REQUEST_WERR ("HTTP: Got remote close.");
#endif

  CHECK_FD_SAFE_USE;

  cleanup_request_object();

  data_buffer = 0;
  pipe = 0;

  // Avoid that the fd is closed by disconnect() - the write direction
  // might still want to use it. We rely on refcount garbing instead.
  my_fd = 0;

  disconnect();
}

static void do_timeout()
{
  int elapsed = predef::time(1)-time;
  if(time && elapsed >= 30)
  {
#ifdef CONNECTION_DEBUG
    werror("HTTP: Connection timed out. Closing.\n"
	   "rcb:%O\n"
	   "wcb:%O\n"
	   "ccb:%O\n",
	   my_fd->query_read_callback(),
	   my_fd->query_write_callback(),
	   my_fd->query_close_callback());
#else
    REQUEST_WERR(sprintf("HTTP: Connection timed out. Closing.\n"
			 "rcb:%O\n"
			 "wcb:%O\n"
			 "ccb:%O\n",
			 my_fd->query_read_callback(),
			 my_fd->query_write_callback(),
			 my_fd->query_close_callback()));
#endif
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
  return ("<a href=\"/(old_error,find_file)/error/?"+
	  "file="+Roxen.http_encode_url(file)+
	  (fun ? "&fun="+Roxen.http_encode_url(fun) : "") +
	  "&off="+qq+
	  "&error="+eid+
	  "&error_md5="+get_err_md5(get_err_info(eid))+
	  (line ? "&line="+line+"#here" : "") +
	  "\">");
}

static string error_page(string title, void|string msg,
			 void|string longmsg, void|string body)
{
  if (longmsg && has_suffix (longmsg, "\n"))
    longmsg = longmsg[..sizeof (longmsg) - 2];
  return #"\
<html><head>
  <title>Internal Server Error</title>
  <style>
    .msg  { font-family:    verdana, helvetica, arial, sans-serif;
            font-size:      12px;
            line-height:    160% }
    .big  { font-family:    georgia, times, serif;
            font-size:      18px;
	    padding-top:    6px }
    .info { font-family:    verdana, helvetica, arial, sans-serif;
            font-size:      10px;
            color:          #999999 }
    .list { padding-left:   20px;
            list-style-type:square; }
    .code { font-family:    monaco, courier, monospace;
            font-size:      10px;
            color:          #404070; }
  </style>
</head>
<body text='#000000' style='margin: 0; padding: 0' vlink='#2331d1' 
      rightmargin='0' leftmargin='0' alink='#f6f6ff' link='#0000ee' 
      bgcolor='#f2f1eb' bottommargin='0' topmargin='0'>
<table border='0' cellspacing='30' cellpadding='0' height='99%'>
  <tr>
    <td width='1'><img src='/internal-roxen-500' /></td>
    <td valign='bottom'><img src='/internal-roxen-server-error' /></td>
  </tr>
  <tr>
    <td></td>
    <td>
      <div class='msg'>" + title + #"</div>" +
    (msg ? #"
      <div class='big'>" + msg + #"</div>" : "") +
    (longmsg ? #"
      <div class='code'><pre>" + longmsg + #"</pre></div>" : "") + #"
    </td>
  </tr>
  <tr>
    <td colspan='2'>" +
    (body ? #"
      <div class='msg'>" + body + #"</div>" : "") + #"
    </td>
  </tr>
  <tr valign='bottom' height='100%'>
    <td colspan='2'>
      <table border='0' cellspacing='0' cellpadding='0'>
        <tr>
          <td><img src='/internal-roxen-roxen-mini.gif' /></td>
          <td class='info'>
	    &nbsp;&nbsp;<b>" + roxen_product_name + #"</b>
	    <font color='#ffbe00'>|</font> " + roxen_dist_version + #"
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
</body></html>";
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
    return error_page("Unregistered error");
  }

  [string msg, array(string) rxml_bt, array(array) bt,
   string raw_bt_descr, string raw_url, string raw] = err_info;

  sscanf (msg, "%s\n%s", string title, string longmsg);
  if (!title) title = msg;
  string body = "";

  if (rxml_bt && sizeof (rxml_bt)) {
    body +=
      "RXML frame backtrace"
      "<ul class='list'>";
    foreach(rxml_bt, string line)
      body += "<li class='code'>" + Roxen.html_encode_string(line) + "</li>\n";
    body += "</ul>\n";
  }

  if (bt && sizeof (bt)) {
    body +=
      "Pike backtrace"
      "<ul class='list'>";
    int q = sizeof (bt);
    foreach(bt, [string file, int line, string func, string descr])
    {
#if constant(PIKE_MODULE_RELOC)
      file = file && master()->relocate_module(file);
#endif
      q--;
      body +=
	"<li>" +
	link_to(file, line, func, eid, q) +     //  inserts <a>
	(file ? Roxen.html_encode_string(file) : "<i>Unknown program</i>") +
	(line ? ":" + line : "") +
	"</a>" +
	(file ? Roxen.html_encode_string(get_cvs_id(file)) : "") +
	"<br /><span class='code'>" +
	replace(Roxen.html_encode_string(descr), " ", "&nbsp;") +
	"</span></li>\n";
    }
    body += "</ul>\n\n";
  }

  body +=
    "<p>Generate "
    "<a href=\"/(old_error,plain)/error/?"
    "error=" + eid +
    "&error_md5=" + get_err_md5(get_err_info(eid)) +
    "\">"
    "text-only version</a> of this error message for bug reports.</p>";
  return error_page("The server failed to fulfill your query.",
		    title, longmsg != "" && longmsg, body);
}

string generate_bugreport(string msg, array(string) rxml_bt, array(string) bt,
			  string raw_bt_descr, string raw_url, string raw)
{
  return ("Roxen version: "+roxen.version()+
	  (roxen.real_version != roxen.version()?
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
  NO_PROTO_CACHE();
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
      file =
	Roxen.http_low_answer(500, error_page("The server failed to fulfill "
					      "your query due to an internal "
					      "error in the internal error "
					      "routine."));
    }
  } else {
    file =
      Roxen.http_low_answer(500, error_page("The server failed to fulfill "
					    "your query."));
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
#define INTERNAL_ERROR(err) do {					\
    if (mixed __eRr = catch (internal_error (err)))			\
      report_error("Internal server error: " + describe_backtrace(err) + \
		   "internal_error() also failed: " + describe_backtrace(__eRr)); \
  } while (0)

int wants_more()
{
  return !!cache;
}

static object(this_program) chained_to;

// Paranoia.
static void destroy()
{
  if (chained_to) {
    // This happens when do_log() is called before the request
    // has been chained (eg for short data over fast connections).
    call_out(chained_to->my_fd_released, 0);
    chained_to = 0;
  }
}

void do_log( int|void fsent )
{
#ifdef CONNECTION_DEBUG
  werror ("HTTP: Response sent ============================================\n");
#endif
  MARK_FD("HTTP logging"); // fd can be closed here
  if (chained_to) {
    // Release the other sender.
    call_out(chained_to->my_fd_released, 0);
    chained_to = 0;
  }
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
    call_out (disconnect, 0);
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
  // Check that the file is valid and is present in the backtrace.
  string data;
  foreach(bt, array frame) {
    if (frame[0] == variables->file) {
      data = Stdio.read_bytes(variables->file);
      break;
    }
  }
  if(!data)
    return error_page("Source file could not be read:", variables->file);

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
    lines[off] = indent + "<font size='+1'><b>"+down+code+"</a></b></font>";
  }
  lines[max(off-20,0)] = "<a name=here>"+lines[max(off-20,0)]+"</a>";

  return error_page("Source code for", variables->file, 0,
		    "<span class='code'><pre>" +
		    (lines * "\n") +
		    "</pre></span>");
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
  void create(mapping _file, array _ranges, array(string)|string t, object id)
  {
    file = _file->file;
    len = _file->len;
    if (arrayp(t)) type = t[-1];
    else type = t;

    ranges = _ranges;
    int clen;
    foreach(ranges, array range)
    {
      int rlen = 1+ range[1] - range[0];
      string sep =  sprintf("\r\n--" BOUND "\r\nContent-Type: %s\r\n"
			    "Content-Range: bytes %d-%d/%d\r\n\r\n",
			    type, @range, len);
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


// Handle byte ranges.
// NOTE: Modifies both arguments destructively.
void handle_byte_ranges(mapping(string:mixed) file,
			mapping(string:array(string)|string) variant_heads)
{
  if(misc->range && file->len && (method == "GET") &&
     (file->error == 200) && (objectp(file->file) || file->data))
    // Plain and simple file and a Range header. Let's play.
    // Also we only bother with 200-requests. Anything else should be
    // nicely and completely ignored.
    // Also this is only used for GET requests.
  {
    // split the range header. If no valid ranges are found, ignore it.
    // If one is found, send that range. If many are found we need to
    // use a wrapper and send a multi-part message.
    array ranges = parse_range_header(file->len);
    if(ranges) // No incorrect syntax...
    {
      NO_PROTO_CACHE();
      if(sizeof(ranges)) // And we have valid ranges as well.
      {
	m_delete(variant_heads, "Content-Length");

	file->error = 206; // 206 Partial Content
	if(sizeof(ranges) == 1)
	{
	  variant_heads["Content-Range"] = sprintf("bytes %d-%d/%d",
						   @ranges[0],
						   file->len);
	  if (objectp(file->file)) {
	    file->file->seek(ranges[0][0]);
	  } else {
	    file->data = file->data[ranges[0][0]..ranges[0][1]];
	  }
	  if(ranges[0][1] == (file->len - 1) &&
	     GLOBVAR(RestoreConnLogFull))
	    // Log continuations (ie REST in FTP), 'range XXX-'
	    // using the entire length of the file, not just the
	    // "sent" part. Ie add the "start" byte location when logging
	    misc->_log_cheat_addition = ranges[0][0];
	  file->len = ranges[0][1] - ranges[0][0]+1;
	} else {
	  // Multiple ranges. Multipart reply and stuff needed.

	  array(string)|string content_type =
	    variant_heads["Content-Type"] || "application/octet-stream";

	  if(request_headers["request-range"]) {
	    // Compat with old Netscape.
	    variant_heads["Content-Type"] =
	      "multipart/x-byteranges; boundary=" BOUND;
	  } else {
	    variant_heads["Content-Type"] =
	      "multipart/byteranges; boundary=" BOUND;
	  }

	  if (objectp(file->file)) {
	    // We do this by replacing the file object with a wrapper.
	    // Nice and handy.
	    file->file = MultiRangeWrapper(file, ranges,
					   content_type, this_object());
	  } else {
	    array(string) res = allocate(sizeof(ranges)*3+1);
	    mapping(string:string) part_heads = ([
	      "Content-Type":content_type,
	    ]);
	    int j;
	    foreach(ranges; int i; array(int) range) {
	      res[j++] = "\r\n--" BOUND "\r\n";
	      part_heads["Content-Range"] =
		sprintf("bytes %d-%d/%d", @range, file->len);
	      res[j++] = Roxen.make_http_headers(part_heads);
	      res[j++] = data[range[0]..range[1]];
	    }
	    res[j++] = "\r\n--" BOUND "\r\n";
	    file->len = sizeof(file->data = res * "");
	  }
	}
	variant_heads["Content-Length"] = (string)file->len;
      } else {
	// Got the header, but the specified ranges were out of bounds.
	// Reply with a 416 Requested Range not satisfiable.
	file->error = 416;
	variant_heads["Content-Range"] = "*/"+file->len;
	file->file = file->data = file->type = file->len = 0;
      }
    }
  }
}

// Tell the client that it can start sending some more data
void ready_to_receive()
{
  // FIXME: Only send once?
  if (clientprot == "HTTP/1.1" && request_headers->expect &&
      (request_headers->expect ==  "100-continue" ||
       has_value(request_headers->expect, "100-continue" )) &&
      !my_fd_busy)
    my_fd->write("HTTP/1.1 100 Continue\r\n");
}

// Send and account the formatted result
void low_send_result(string headers, string data, int|void len,
		     Stdio.File|void file)
{
  MY_TRACE_ENTER(sprintf("Sending %d bytes of headers, "
			 "%d bytes of string data, "
			 "len:%d",
			 sizeof(headers), data && sizeof(data), len), 0);
  conf->hsent += sizeof(headers);
  if(!kept_alive && (len > 0) &&
     ((sizeof(headers) + len) < (HTTP_BLOCKING_SIZE_THRESHOLD))) {
    MY_TRACE_ENTER("Blocking write.", 0);
    TIMER_START(blocking_write);
    if (data && sizeof(data) != len) {
      data = data[..len-1];
    }
    if (file) {
      data = file->read(len);
    } else if (!data) data = "";
#ifdef CONNECTION_DEBUG
    werror("HTTP: Response =================================================\n"
	   "%s\n",
	   replace(sprintf("%O", headers + data),
		   ({"\\r\\n", "\\n", "\\t"}),
		   ({"\n",     "\n",  "\t"})));
#else
    REQUEST_WERR(sprintf("HTTP: Send blocking %O", headers + data));
#endif
    int s = my_fd->write(({ headers, data }));
    TIMER_END(blocking_write);
    MY_TRACE_LEAVE(sprintf("Blocking write wrote %d bytes.", s));
    do_log(s);
  } else {
    MY_TRACE_ENTER("Async write.", 0);
#ifdef CONNECTION_DEBUG
    werror("HTTP: Response headers =========================================\n"
	   "%s\n",
	   replace(sprintf("%O", headers),
		   ({"\\r\\n", "\\n", "\\t"}),
		   ({"\n",     "\n",  "\t"})));
#else
    REQUEST_WERR(sprintf("HTTP: Send headers %O", headers));
#endif
    if (sizeof(headers))
      send(headers);
    if (data && sizeof(data))
      send(data, len);
    if (file)
      send(file, len);
    start_sender();
    MY_TRACE_LEAVE("Async write done");
  }
  MY_TRACE_LEAVE("Result sent.\n");
}

// Send the result.
void send_result(mapping|void result)
{
  TIMER_START(send_result);

  CHECK_FD_SAFE_USE;

  array err;
  int tmp;
  if (result)
    file = result;
#ifdef PROFILE
  int elapsed = HRTIME()-req_time;
  string nid =
#ifdef FILE_PROFILE
    (raw_url/"?")[0]
#else
    dirname((raw_url/"?")[0])
#endif
    + "?method="+method;
  array p;
  if(!(p=conf->profile_map[nid])) {
    // ({ count, sum, max })
    p = conf->profile_map[nid] = ({0, 0, 0});
  }
  p[0]++;
  p[1] += elapsed;
  if(elapsed > p[2]) p[2]=elapsed;
#endif

  REQUEST_WERR(sprintf("HTTP: response: prot %O, method %O, file %O, misc: %O",
		       prot, method, file, misc));

#ifdef DEBUG_CACHEABLE
  report_debug("<=== Request for %s returned cacheable %d (proto cache %s).\n",
	       raw_url, misc->cacheable,
	       misc->no_proto_cache ? "disabled" : "enabled");
#endif

  if( prot == "HTTP/0.9" )  NO_PROTO_CACHE();

  if(!leftovers) 
    leftovers = data||"";

  if(!mappingp(file))
  {
    NO_PROTO_CACHE();
    if(misc->error_code)
      file = Roxen.http_status(misc->error_code, errors[misc->error_code]);
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
      my_fd = 0;
      return;
    }

    if(file->type == "raw")  file->raw = 1;
  }

  // Invariant part of header. (Cached)
  // Contains the result line except for the protocol and code parts.
  // Note: Only a single CRLF as terminator.
  string head_string="";

  // Variant part of header.
  // Currently the Date and Connection headers.
  // Note: Terminated with a double CRLF.
  string variant_string="";

  // The full header block (prot + " " + code + head_string + variant_string).
  string full_headers="";

#if 0
  REQUEST_WERR(sprintf("HTTP: Sending result for prot:%O, method:%O, file:%O",
		       prot, method, file));
#endif
  if(!file->raw && (prot != "HTTP/0.9"))
  {
    if (!sizeof (file) && multi_status)
      file = multi_status->http_answer();

    if (file->error == Protocols.HTTP.HTTP_NO_CONTENT) {
      file->len = 0;
      file->data = "";
    }

    string head_status = file->rettext;
    if (head_status) {
      if (!file->file && !file->data &&
	  (!file->type || file->type == "text/html")) {
	// If we got no body then put the message there to make it
	// more visible.
	file->data = "<html><body>" +
	  replace (Roxen.html_encode_string (head_status), "\n", "<br />\n") +
	  "</body></html>";
	file->len = sizeof (file->data);
	file->type = "text/html";
      }
      if (has_value (head_status, "\n"))
	// Fold lines nicely.
	head_status = map (head_status / "\n", String.trim_all_whites) * " ";
    }

    mapping(string:string) heads = make_response_headers (file);

    // Notes about the variant headers:
    //
    // Date		Changes with every request.
    // Content-Type	May change if a byte-range request is performed.
    // Content-Length	May change due to If-* headers, etc.
    // Connection	Depends on the protocol version and state.
    mapping(string:string) variant_heads = ([ "Date":"",
					      "Content-Type":"",
					      "Content-Length":"",
					      "Connection":"",
					      "Expires":"",
    ]) & heads;
    m_delete(heads, "Date");
    m_delete(heads, "Content-Type");
    m_delete(heads, "Content-Length");
    m_delete(heads, "Connection");
    m_delete(heads, "Expires");

    // FIXME: prot.
    head_string = sprintf(" %s\r\n", 
			  head_status || errors[file->error] || "");

    if (mixed err = catch(head_string += Roxen.make_http_headers(heads, 1)))
    {
#ifdef DEBUG
      report_debug("Roxen.make_http_headers failed: " +
		   describe_error (err));
#endif
      foreach(heads; string x; string|array(string) val) {
	if( !arrayp( val ) ) val = ({val});
	foreach( val, string xx ) {
	  if (!stringp (xx) && catch {xx = (string) xx;})
	    report_error("Error in request for %O:\n"
			 "Invalid value for header %O: %O\n",
			 raw_url, x, xx);
	  else if (String.width (xx) > 8)
	    report_error("Error in request for %O:\n"
			 "Invalid widestring value for header %O: %O\n",
			 raw_url, x, xx);
	  else
	    head_string += x+": "+xx+"\r\n";
	}
      }
      head_string += "\r\n";
    }

    if (objectp(cookies)) {
      // Disconnect the cookie jar.
      real_cookies = cookies = ~cookies;
    }

    int varies = misc->vary && (sizeof(misc->vary) - misc->vary["Host"]);
#ifdef RAM_CACHE
    if( (misc->cacheable > 0) && !misc->no_proto_cache)
    {
      if ((<"HEAD","GET">)[method]) {
	if( file->len>0 && // known length.
	    ((file->len + sizeof(head_string)) < 
	     conf->datacache->max_file_size)
	    // vvv Relying on the interpreter lock from here.
	    && misc->cachekey )
	{
	  misc->cachekey->activate();
	  // ^^^ Relying on the interpreter lock to here.
	  string data = "";
	  if( file->data ) data = file->data[..file->len-1];
	  if( file->file ) data = file->file->read(file->len);
	  MY_TRACE_ENTER(sprintf("Storing in ram cache, entry: %O",
				 raw_url), 0);
	  MY_TRACE_LEAVE ("");
	  conf->datacache->set(raw_url, data,
			       ([
				 "hs":head_string,
				 "key":misc->cachekey,
				 "etag":misc->etag,
				 "callbacks":misc->_cachecallbacks,
				 "len":file->len,
				 "raw":file->raw,
				 "error":file->error,
				 "type":variant_heads["Content-Type"],
				 "last_modified":misc->last_modified,
				 "varies":varies,
				 "expires":variant_heads["Expires"],
				 "mtime":(file->stat &&
					  file->stat[ST_MTIME]),
				 "rf":realfile,
			       ]),
			       misc->cacheable, this_object());
	  file = ([
	    "data":data,
	    "raw":file->raw,
	    "len":strlen(data),
	    "error":file->error,
	  ]);
	  cache_status["protstore"] = 1;
	}
      }
    }
#endif

    if ((method != "HEAD") && (undefinedp(file->len) || (file->len < 0)) &&
	(misc->connection == "keep-alive")) {
      // Unknown length ==> Connection: close.
      if (file->file) {
	variant_heads->Connection = "close";
	misc->connection = "close";
      } else if (!file->data) {
	file->data = "";
	file->len = 0;
      }
    }

    if (file->error == 200) {
      int conditional;
      if (none_match) {
	// NOTE: misc->etag may be zero below, but that's ok.
	if (none_match[misc->etag] || (misc->etag && none_match["*"])) {
	  // We have a if-none-match header that matches our etag.
	  if ((<"HEAD", "GET">)[method]) {
	    // RFC 2616 14.26:
	    //   Instead, if the request method was GET or HEAD, the server
	    //   SHOULD respond with a 304 (Not Modified) response, including
	    //   the cache- related header fields (particularly ETag) of one
	    //   of the entities that matched. For all other request methods,
	    //   the server MUST respond with a status of 412 (Precondition
	    //   Failed). 
	    conditional = 304;
	  } else {
	    conditional = 412;
	  }
	} else {
	  conditional = -1;
	}
      }
      if(since && misc->last_modified && (conditional >= 0))
      {
	/* ({ time, len }) */
	array(int) since_info = Roxen.parse_since( since );
//	werror("since: %{%O, %}\n"
//	       "lm:    %O\n"
//	       "cacheable: %O\n",
//	       since_info,
//	       misc->last_modified,
//	       misc->cacheable);
	if ( ((since_info[0] >= misc->last_modified) && 
	      ((since_info[1] == -1) || (since_info[1] == file->len)))
	     // never say 'not modified' if cacheable has been lowered.
	     && (zero_type(misc->cacheable) ||
		 (misc->cacheable >= INITIAL_CACHEABLE))
	       // actually ok, or...
//	     || ((misc->cacheable>0) 
//		 && (since_info[0] + misc->cacheable<= predef::time(1))
//	       // cacheable, and not enough time has passed.
	     )
	{
	  conditional = conditional || 304;
	} else {
	  conditional = -1;
	}
      }
      if (conditional > 0) {
	// All conditionals apply.
	file->error = conditional;
	file->file = file->data = file->len = 0;
	// Must update the content length after the modifications of the
	// data to send that might have been done above for 206 or 304.
	variant_heads["Content-Length"] = "0";
      }
    }

    if (varies && (prot == "HTTP/1.0")) {
      // The Vary header is new in HTTP/1.1.
      // It expired a year ago.
      variant_heads["Expires"] = Roxen->http_date(predef::time(1)-31557600);
    }
    if( (method == "HEAD") || (file->error == 204) || (file->error == 304) ||
	(file->error < 200))
    {
      // RFC 2068 4.4.1
      //   Any response message which MUST NOT include a message-body
      //   (such as the 1xx, 204, and 304 responses and any response
      //   to a HEAD request) is always terminated by the first empty
      //   line after the header fields, regardless of the entity-header
      //   fields present in the message.

      file->len = 1; // Keep those alive, please...
      file->data = "";
      file->file = 0;
    } else {
      if ((method != "HEAD") && (undefinedp(file->len) || (file->len < 0)) &&
	  (misc->connection == "keep-alive")) {
	// Unknown length ==> Connection: close.
	variant_heads->Connection = "close";
	misc->connection = "close";
      }
      if (misc->range) {
	// Handle byte ranges.
	int skip;
	string if_range;
	if (if_range = request_headers["if-range"]) {
	  // Check If-Range header (RFC 2068 14.27).
	  if (has_prefix(if_range, "\"")) {
	    // ETag
	    if (if_range != misc->etag) {
	      // ETag has changed.
	      skip = 1;
	    }
	  } else {
	    array(int) since_info = Roxen.parse_since(if_range);
	    if (!since_info || (since_info[0] < misc->last_modified)) {
	      // Failed to parse since info, or the file has changed.
	      skip = 1;
	    }
	  }
	}
	if (!skip) {
	  // NOTE: Modifies both arguments destructively.
	  handle_byte_ranges(file, variant_heads);
	}
      }
    }

    variant_string = Roxen.make_http_headers(variant_heads);
    full_headers = prot + " " + file->error + head_string + variant_string;

    low_send_result(full_headers, file->data, file->len, file->file);
  }
  else {
    // RAW or HTTP/0.9 mode.

    if(!file->type) file->type="text/plain";

    // No headers!
    low_send_result("", file->data, file->len, file->file);
  }

  MARK_FD("HTTP handled");
  

  TIMER_END(send_result);
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

  else {
    if (result && result->pipe)
      // Could be destructed here already since handle_request might
      // have handed over us to another thread that finished quickly.
      return;
    file = result;
  }

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
      if ((scanres < 2) || (port == port_obj->default_port)) {
	// Some clients don't send the port in the host header
	// if they've connected to the default port.
	// NOTE: We want the (probable) port number that the client
	//       used here; NOT the actual port number, since there
	//       may be port remappers in the way.
	port = port_obj->default_port;
	// Remove redundant port number.
	cached_url_base = port_obj->prot_name + "://" + host;
      } else {
	cached_url_base = port_obj->prot_name + "://" + tmp;
      }
    }
    // Then use the port object.
    else {
      string host = (port_obj->conf_data[conf] ||
		     (["hostname":"*"]))->hostname;
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
// array ccd = ({});
void got_data(mixed fooid, string s, void|int chained)
{
#ifdef CONNECTION_DEBUG
  werror ("HTTP: Request --------------------------------------------------\n"
	  "%s\n",
	  replace (sprintf ("%O", s),
		   ({"\\r\\n", "\\n", "\\t"}),
		   ({"\n",     "\n",  "\t"})));
#else
  REQUEST_WERR(sprintf("HTTP: Got %O", s));
#endif

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

      REQUEST_WERR("HTTP: We want more data.");

      // Reset timeout.
      remove_call_out(do_timeout);
      call_out(do_timeout, 90);

      if (chained)
	my_fd->set_nonblocking(got_data, 0, close_cb);
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
      MARK_FD ("HTTP: Port closed.");
      call_out (disconnect, 0);
      return;
    }

    switch( parse_got( s ) )
    {
      case 0:
	REQUEST_WERR("HTTP: Request needs more data.");
	if (chained)
	  my_fd->set_nonblocking(got_data, 0, close_cb);
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

#ifdef CONNECTION_DEBUG
    werror ("HTTP: Request received -----------------------------------------\n");
#endif

    if( method == "GET" || method == "HEAD" ) {
      // NOTE: Setting misc->cacheable enables use of the RAM_CACHE.
      misc->cacheable = INITIAL_CACHEABLE; // FIXME: Make configurable.
#ifdef DEBUG_CACHEABLE
      report_debug("===> Request for %s initiated cacheable to %d.\n", raw_url,
		   misc->cacheable);
#endif
    }

    TIMER_START(find_conf);

    string path;

    // RFC 2068 5.1.2:
    //
    // To allow for transition to absoluteURIs in all requests in future
    // versions of HTTP, all HTTP/1.1 servers MUST accept the absoluteURI
    // form in requests, even though HTTP/1.1 clients will only generate
    // them in requests to proxies. 
    if (has_prefix(raw_url, port_obj->url_prefix)) {
      sscanf(raw_url[sizeof(port_obj->url_prefix)..], "%[^/]%s",
	     misc->host, raw_url);
    }
    if (misc->host) {
      // Parse and canonicalize the host header.
      misc->port = port_obj->port;
      sscanf(lower_case(misc->host), "%[^:]:%d", misc->hostname, misc->port);
      misc->host = misc->hostname + ":" + misc->port;
    }
    if( !conf || !(path = port_obj->path ) ||
	(sizeof( path ) && !has_prefix(raw_url, path)) ) {
      // FIXME: port_obj->name & port_obj->default_port are constant
      // consider caching them?

      if (misc->host) {
	conf =
	  port_obj->find_configuration_for_url(port_obj->url_prefix +
					       misc->host + raw_url,
					       this_object());
      } else {
	conf =
	  port_obj->find_configuration_for_url(port_obj->url_prefix + "*:" +
					       port_obj->port + raw_url,
					       this_object());
      }
    }
    else if( strlen(path) )
      adjust_for_config_path( path );

    TIMER_END(find_conf);

    if (rawauth)
    {
      /* Need to authenticate with the configuration */
      NO_PROTO_CACHE();
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
      NO_PROTO_CACHE();
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

    remove_call_out(do_timeout);
#ifdef RAM_CACHE
    TIMER_START(cache_lookup);
    array cv;
    if(misc->cacheable && !misc->no_proto_cache &&
       (cv = conf->datacache->get(raw_url, this_object())) )
    {
      MY_TRACE_ENTER(sprintf("Found %O in ram cache - checking entry",
			     raw_url), 0);
      if( !cv[1]->key ) {
	MY_TRACE_LEAVE("Entry invalid due to zero key");
	conf->datacache->expire_entry(raw_url, this_object());
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
	    // Callback failed; in destructed object?
	    if (e = catch {
		werror("Cache callback internal server error:\n"
		       "%s\n",
		       describe_backtrace(e));
		// Invalidate the key.
		destruct(cv[1]->key);
	      }) {
	      // Fall back to a standard internal error.
	      INTERNAL_ERROR( e );
	      TIMER_END(cache_lookup);
	      send_result();
	      return;
	    }
	  }
	}
	if( !cv[1]->key )
	{
	  MY_TRACE_LEAVE ("Entry invalid due to zero key");
	  conf->datacache->expire_entry(raw_url, this_object());
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
	    if (objectp(cookies)) {
	      // Disconnect the cookie jar.
	      real_cookies = cookies = ~cookies;
	    }

	    int code = file->error;
	    int len = sizeof(d);
	    // Make sure we don't mess with the RAM cache.
	    file += ([]);
	    if (since && file->last_modified) {
	      array(int) since_info = Roxen.parse_since( since );
	      if ((since_info[0] >= file->last_modified) &&
		  ((since_info[1] == -1) ||
		   (since_info[1] == len))) {
		// Not modified.
		code = 304;
		d = "";
		len = 0;
	      }
	    }
	    file->error = code;
	    if (method == "HEAD") {
	      d = "";
	    }
	    mapping(string:string) variant_heads = ([
	      "Date":Roxen.http_date(predef::time(1)),
	      "Content-Length":(string)len,
	      "Content-Type":file->type,
	      "Connection":misc->connection,
	    ]);
	    string expires;
	    if (expires = (file->varies && (prot == "HTTP/1.0")?
			   Roxen->http_date(predef::time(1)-31557600):
			   file->expires)) {
	      variant_heads["Expires"] = expires;
	    }
	    if (misc->range) {
	      // Handle byte ranges.
	      int skip;
	      string if_range;
	      if (if_range = request_headers["if-range"]) {
		// Check If-Range header (RFC 2068 14.27).
		if (has_prefix(if_range, "\"")) {
		  // ETag
		  if (if_range != file->etag) {
		    // ETag has changed.
		    skip = 1;
		  }
		} else {
		  array(int) since_info = Roxen.parse_since(if_range);
		  if (!since_info || (since_info[0] < file->last_modified)) {
		    // Failed to parse since info, or the file has changed.
		    skip = 1;
		  }
		}
	      }
	      if (!skip) {
		file->data = d;
		file->len = len;

		// NOTE: Modifies both arguments destructively.
		handle_byte_ranges(file, variant_heads);

		d = file->data;
		code = file->error;
	      }
	    }
	    string full_headers = "";
	    if (prot != "HTTP/0.9") {
	      full_headers = prot + " " + code + file->hs +
		Roxen.make_http_headers(variant_heads);
	    }

	    MY_TRACE_LEAVE ("Using entry from ram cache");
	    cache_status["protcache"] = 1;

	    TIMER_END(cache_lookup);
	    low_send_result(full_headers, d, sizeof(d));
	    return;
	  }
#ifndef RAM_CACHE_ASUME_STATIC_CONTENT
	  else
	    MY_TRACE_LEAVE (
	      sprintf ("Entry out of date (disk: %s, cache: mtime %d)",
		       st ? "mtime " + st->mtime : "gone", file->mtime));
#endif
	}
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
  c->request_headers = request_headers + ([]);
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
#if 0
    if (f->query_accept_callback)
      f->set_nonblocking(got_data, f->query_write_callback(), close_cb, 0, 0,
			 f->query_accept_callback());
    else
#endif /* 0 */
      f->set_nonblocking(got_data, f->query_write_callback(), close_cb);
    my_fd = f;
    CHECK_FD_SAFE_USE;
    MARK_FD("HTTP connection");
    if( c ) port_obj = c;
    if( cc ) conf = cc;
    time = predef::time(1);
    hrtime = gethrtime();
    call_out(do_timeout, 90);
  }
  root_id = this_object();
}

void chain(object f, object c, string le)
{
  my_fd = f;

#if defined(DEBUG) && defined(THREADS)
  if (this_thread() != roxen->backend_thread)
    error ("Not called from backend\n");
#endif

  CHECK_FD_SAFE_USE;

  port_obj = c;
  MARK_FD("HTTP kept alive");
  time = predef::time();
  hrtime = gethrtime();

  if ( le && strlen( le ) ) {
#ifdef CONNECTION_DEBUG
    werror("HTTP: Leftovers: %O\n", le);
#else
    REQUEST_WERR(sprintf("HTTP: %d bytes left over.\n", sizeof(le)));
#endif
    got_data(0, le, 1);
  }
  else
  {
    // If no pipelined data is available, call out...
    remove_call_out(do_timeout);
    call_out(do_timeout, 90);

    my_fd->set_nonblocking(got_data, 0, close_cb);
  }
}

Stdio.File connection( )
{
  return my_fd;
}

Configuration configuration()
{
  return conf;
}
