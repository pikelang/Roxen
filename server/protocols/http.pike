// This is a roxen protocol module.
// Modified by Francesco Chemolli to add throttling capabilities.
// Copyright � 1996 - 2009, Roxen IS.

constant cvs_version = "$Id$";
// #define REQUEST_DEBUG
#define MAGIC_ERROR

#define REQUESTID this

#ifdef MAGIC_ERROR
//inherit "highlight_pike";
#endif

// HTTP protocol module.
#include <roxen.h>
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
    int _fd = -1;							\
    if (my_fd->query_fd)						\
      _fd = my_fd->query_fd();						\
    if (my_fd->query_stream)						\
      if (object stream = my_fd->query_stream()) /* SSL */		\
	if (stream->query_fd)						\
	  _fd = stream->query_fd();					\
    FD_WERR("FD " + (_fd == -1 ? sprintf ("%O", my_fd) : _fd) + ": " + (X)); \
    mark_fd(_fd, (X)+" "+remoteaddr);					\
  } while (0)
#else
#define MARK_FD(X) do {} while (0)
#endif

#ifdef CONNECTION_DEBUG
// Currently only used by CONNECTION_DEBUG to label each message with
// the fd.
private string debug_fd_str;
private string debug_my_fd()
{
  if (my_fd->query_fd)
    return debug_fd_str = (string) my_fd->query_fd();
  if (my_fd->query_stream)
    if (object stream = my_fd->query_stream()) // SSL
      if (stream->query_fd)
	return debug_fd_str = (string) stream->query_fd();
  return debug_fd_str = sprintf ("%O", my_fd);
}
#define DEBUG_GET_FD							\
  (my_fd ? debug_fd_str || debug_my_fd() :				\
   debug_fd_str ? "ex " + debug_fd_str : "??")
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

private array(string) cache;
private int wanted_data, have_data;
private object(String.Buffer) data_buffer;

private multiset(string) none_match;

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
#include <request_trace.h>

#define MY_TRACE_ENTER(MSG) ID_TRACE_ENTER (this, (MSG), 0)
#define MY_TRACE_LEAVE(MSG) ID_TRACE_LEAVE (this, (MSG))

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
int raw_bytes = 0;
string extra_extension = ""; // special hack for the language module

protected mapping connection_stats = ([]);

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


void send(string|object what, int|void len,
#ifdef CONNECTION_DEBUG
	  void|int connection_debug_verbose
#endif
	 )
{
  if( len>0 && port_obj && port_obj->minimum_byterate )
    call_out( end, len / port_obj->minimum_byterate );

  if(!what) return;
  if(!pipe) setup_pipe();
  if(stringp(what)) {
#ifdef CONNECTION_DEBUG
    if (sizeof (what) < 2000 ||
	connection_debug_verbose
#if TOSTR(CONNECTION_DEBUG) != "1"
	// CONNECTION_DEBUG may be defined to something like "text/"
	// to see the response content for all content types with that
	// prefix, only headers are shown otherwise.
	|| has_prefix(file->type || "", TOSTR(CONNECTION_DEBUG))
#endif
       )
      werror ("HTTP[%s]: Response (length %d) ===============================\n"
	      "%O\n", DEBUG_GET_FD, sizeof (what), what);
    else
      werror ("HTTP[%s]: Response =============================================\n"
	      "String, length %d\n", DEBUG_GET_FD, sizeof (what));
#else
    REQUEST_WERR(sprintf("HTTP: Pipe string %O", what));
#endif
    pipe->write(what);
  }
  else {
#ifdef CONNECTION_DEBUG
    werror ("HTTP[%s]: Response =============================================\n"
	    "Stream %O, length %O\n", DEBUG_GET_FD, what, len);
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
    REQUEST_WERR ("HTTP: Pipe pending.\n");
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
  REQUEST_WERR ("HTTP: Fd released.\n");
  if (pipe_pending) {
    start_sender();
  }
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
    string res = prot + " 302 Roxen config coming up\r\n"+
      (what?what+"\r\n":"")+"Location: "+url+"\r\n"
      "Connection: close\r\nDate: "+
      Roxen.http_date(predef::time(1))+
      "\r\nContent-Type: text/html\r\n"
      "Content-Length: 1\r\n\r\nx";
#ifdef CONNECTION_DEBUG
    werror ("HTTP[%s]: Blocking response (length %d) ========================\n"
	    "%O\n", DEBUG_GET_FD, sizeof (res), res);
#else
    REQUEST_WERR(sprintf("HTTP: Send blocking %O", res));
#endif
    my_fd->set_blocking();
    my_fd->write (res);
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

  misc->cachekey = ProtocolCacheKey();
  misc->_cachecallbacks = ({});

  init_pref_languages();
  init_cookies();

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
    // I guess the line above can be removed if we register a vary
    // dependency on User-Agent. /mast

    set_output_charset( client_var->charset );
    input_charset = client_var->charset;
  }

#else  // DISABLE_SUPPORTS
  supports = (< "images", "gifinline", "forms", "mailto">);
#endif

  {
    string f = raw_url;
    sscanf (f, "%s?%s", f, query);

    if (query) {
      int i = search (query, "roxen_magic_per_u=%25");
      if (i >= 0 && (i == 0 || query[i - 1] == '&')) {
	// Broken Safari detected
	//   (http://bugs.webkit.org/show_bug.cgi?id=6452, historically
	//   http://bugzilla.opendarwin.org/show_bug.cgi?id=6452)
	// Assume that %u and %U won't occur naturally.
	REQUEST_WERR(sprintf("Broken http encoding detected. query=%O\n",
			     query));
	query = replace(query, ({ "%25u", "%25U" }), ({ "%u", "%U" }));
	REQUEST_WERR(sprintf("Repaired query=%O\n", query));
      }
    }

    {
      mapping(string:array(string)) vars =
	misc->post_variables ? misc->post_variables + ([]) : ([]);
      if (query)
	split_query_vars (query, vars);

      if (sizeof (vars)) {
      decode_query: {
	  if (input_charset) {
	    if (mixed err = catch {
		f = decode_query_charset (_Roxen.http_decode_string (f),
					  vars, input_charset);
	      }) {
	      report_debug ("Client %O sent query %O which failed to decode "
			    "with its own charset %O: %s",
			    client_var->fullname, raw_url,
			    input_charset, describe_error (err));
	      input_charset = 0;
	    }
	    else break decode_query;
	  }

	  f = decode_query_charset (_Roxen.http_decode_string (f),
				    vars, "roxen-http-default");
	}

	if (array(string) rest = m_delete (real_variables, ""))
	  rest_query = rest[0];

	if (input_charset && misc->post_variables) {
	  if (query) {
	    // Complicated to repopulate misc->post_variables with
	    // decoded values.
	    function(string:string) decoder =
	      Roxen.get_decoder_for_client_charset (input_charset);
	    mapping(string:array(string)) decoded_vars = ([]);
	    foreach (misc->post_variables; string var; array(string) vals) {
	      var = decoder (var);
	      // We know the post_variables are first in the array values.
	      decoded_vars[var] = real_variables[var][..sizeof (vals) - 1];
	    }
	    misc->post_variables = decoded_vars;
	  }
	  else
	    misc->post_variables = real_variables + ([]);

	  // Ensure that the variable names in misc->post_parts and
	  // misc->files are decoded too.
	  if (misc->post_parts) {
	    mapping(string:string) decoded_names = ([]);
	    function(string:string) decoder =
	      Roxen.get_decoder_for_client_charset (input_charset);

	    mapping(string:array(MIME.Message)) decoded_post_parts = ([]);
	    foreach (misc->post_parts; string var; array(MIME.Message) parts) {
	      string decoded_var = decoder (var);
	      decoded_names[var] = decoded_var;
	      decoded_post_parts[decoded_var] = parts;
	    }
	    misc->post_parts = decoded_post_parts;

	    if (misc->files)
	      misc->files = map (misc->files, decoded_names);
	  }
	}
      }

      else {
	// No variables to decode, only the path. Optimize
	// decode_query with "roxen-http-default" since we know
	// there's no magic_roxen_automatic_charset_variable.
	f = http_decode_string (f);
	if (input_charset) {
	  if (mixed err = catch {
	      f = Roxen.get_decoder_for_client_charset (input_charset) (f);
	    })
	    report_debug ("Client %O requested path %O which failed to decode "
			  "with the input charset %O: %s",
			  client_var->fullname, f, input_charset,
			  describe_error (err));
	}
	else
	  catch (f = utf8_to_string (f));
      }

      // Now after charset decode we can add the multipart/form-data
      // variables in case they were rfc 2388 correct.
      if (mapping(string:array(string)) ppv =
	  m_delete (misc, "proper_post_vars")) {
	misc->post_variables = ppv;
	foreach (ppv; string var; array(string) val) {
	  if (array(string) oldval = real_variables[var])
	    // Ensure POST variables come first, for consistency.
	    real_variables[var] = val + oldval;
	  else
	    real_variables[var] = val;
	}
      }
    }

#if 0
    // f is sent to Unix API's that take NUL-terminated strings...
    // This should really not be necessary. /mast
    if(search(f, "\0") != -1)
      sscanf(f, "%s\0", f);
#endif
  
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
	  if(sscanf(f, "/(%s)/%s", a, f)==2)
	  {
	    prestate = (multiset)( a/","-({""}) );
	    f = "/"+f;
	  }
      }
    }

    if (has_prefix (f, "/"))
      not_query = combine_path_unix ("/", f);
    else
      not_query = combine_path_unix ("/", f)[1..];
  }

  {
    int i = search (client, "MSIE");
    if (i < 0)
      supports->vary = 1;
    else if (++i < sizeof (client) &&
	     sscanf (client[i], "%d", int msie_major) == 1) {
      // Vary doesn't work in MSIE <= 6.
      // FIXME: Does it really work in MSIE 7?
      if (msie_major >= 7)
	supports->vary = 1;
    }
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
  else {
    // FIXME: Improve protocol cachability.
    if( port_obj->set_cookie
       && !cookies->RoxenUserID && strlen(not_query)
       && not_query[0]=='/' && method!="PUT")
    {
      NO_PROTO_CACHE();
      if (!(port_obj->set_cookie_only_once &&
	    cache_lookup("hosts_for_cookie",remoteaddr))) {
	misc->moreheads = ([ "Set-Cookie":Roxen.http_roxen_id_cookie(), ]);
      }
      if (port_obj->set_cookie_only_once)
	cache_set("hosts_for_cookie",remoteaddr,1);
    }
  }
}

//! @param fragment
//!   Some incremental data received from the client.
//!
//! @returns
//!   @int
//!     @value 0
//!       More data needed.
//!     @value 1
//!       Failure (not used).
//!     @value 2
//!       Done and handled (not used).
//!     @value 3
//!       Processing done.
//!   @endint
private int got_chunk_fragment(string fragment)
{
#ifdef CONNECTION_DEBUG
  werror("HTTP[%s]: Fragment (length %d+%d/%d) ============================\n"
	 "%O\n", DEBUG_GET_FD,
	 sizeof(fragment), sizeof(misc->chunk_buf||""), misc->chunk_len,
	 fragment);
#else
  REQUEST_WERR(sprintf("HTTP: Got Fragment %O", fragment));
#endif
  string buf = fragment;
  int chunk_offset;
  if (misc->chunk_len) {
    if (misc->chunk_len >= sizeof(fragment)) {
      data_buffer->add(fragment);      
      misc->chunk_len -= sizeof(fragment);
      return 0; // More data needed (eg EOF marker).
    } else {
      data_buffer->add(fragment[..misc->chunk_len - 1]);
      chunk_offset = misc->chunk_len;
      misc->chunk_len = 0;
    }
  } else {
    buf = misc->chunk_buf + buf;
  }
  misc->chunk_buf = "";

  while(misc->chunked == 1) {
    int chunk_data_offset;
    string chunk_extras;
    int n = sscanf(buf, "%" + chunk_offset + "*s%x%s\r\n%n",
		   misc->chunk_len, chunk_extras,
		   chunk_data_offset);
    if (n < 4) {
      misc->chunk_buf = buf[chunk_offset..];
      misc->chunk_len = 0;
      return 0; // More data needed to parse the chunk length.
    }

#ifdef CONNECTION_DEBUG
    werror("HTTP[%s]: Got chunk with %d bytes of data.\n",
	   DEBUG_GET_FD, misc->chunk_len);
#endif

    // FIXME: Currently we ignore the chunk_extras.

    if (sizeof(buf) < chunk_data_offset + misc->chunk_len) {
      if (!data_buffer) {
	// The 16384 is some reasonable extra padding to
	// avoid having to realloc.
	data_buffer =
	  String.Buffer(sizeof(data) + misc->chunk_len + 16384);
	if (sizeof(data)) data_buffer->add(data);
	data = "";
      }
      data_buffer->add(buf[chunk_data_offset..]);
      misc->chunk_len -= sizeof(buf) - chunk_data_offset;
      return 0; // More data needed for the chunk.
    } else if (misc->chunk_len) {
      string str =
	buf[chunk_data_offset..chunk_data_offset + misc->chunk_len - 1];
      if (sizeof(data) && !data_buffer) {
	// The 16384 is some reasonable extra padding to
	// avoid having to realloc.
	data_buffer = String.Buffer(sizeof(data) + misc->chunk_len + 16384);
	data_buffer->add(data);
	data = "";
      }
      if (data_buffer) {
	data_buffer->add(str);
      } else {
	data = str;
      }
      chunk_offset = chunk_data_offset + misc->chunk_len;
    } else {
      // End marker for chunks!
      if (data_buffer) {
	data = data_buffer->get();
	data_buffer = 0;
      }
      chunk_offset = chunk_data_offset;
      misc->len = sizeof(data);
      misc->chunked = 2;
      break;
    }
  }

  // Entity headers...
  if (misc->chunked == 2) {
    if (!misc->chunked_hp) {
#ifdef CONNECTION_DEBUG
      werror("HTTP[%s]: Parsing entity headers...\n", DEBUG_GET_FD);
#endif
      if (buf[chunk_offset..chunk_offset + 1] == "\r\n") {
	// Special case: No entity headers; done.
#ifdef CONNECTION_DEBUG
	werror("HTTP[%s]: No entity headers.\n", DEBUG_GET_FD);
#endif
	leftovers = buf[chunk_offset+2..];
	misc->chunked = 3;
	return 3;
      }
      misc->chunked_hp = Roxen.HeaderParser();
      misc->chunked_hp->feed("   \r\n"); // Dummy first line...
      // Note: At least three spaces in the first line are needed
      //       to avoid the HTTP/0.9 support in the header parser.
    }
    array res;
    if (mixed err = catch {
	res = misc->chunked_hp->feed(buf[chunk_offset..]);
      }) {
#if defined(DEBUG) || defined(CONNECTION_DEBUG)
      report_debug ("Got bad request (chunked), HeaderParser error: " +
		    describe_error (err));
#endif
      // Assume no entity headers, and ensure that the connection won't be
      // reused.
      misc->connection = "close";
      leftovers = "";
    } else {
      if (!res) return 0;
#ifdef CONNECTION_DEBUG
      werror("HTTP[%s]: Got entity headers: %O.\n", DEBUG_GET_FD, res[2]);
#endif
      leftovers = res[0];
      request_headers |= res[2];
      // Note: None of the headers special-cased in parse_got() below are
      //       allowed as entity headers, so there's no need for extra
      //       parsing here (as is done for the main headers there).
    }
    misc->chunked = 3;
    m_delete(misc, "chunked_hp");
  }
#ifdef CONNECTION_DEBUG
  werror("HTTP[%s]: Chunked parsing done.\n", DEBUG_GET_FD);
#endif
  return 3;
}

protected Roxen.HeaderParser hp = Roxen.HeaderParser();

//! Parse some data received from the client.
//!
//! @param new_data
//!   Incremental data from the client.
//!
//! This function is called from @[got_data] when it has received
//! some data to parse the request headers.
//!
//! @returns
//!   @int
//!     @value 0
//!       Need more data.
//!     @value 1
//!       Failure.
//!     @value 2
//!       Done and handled.
//!     @value 3
//!       Done.
//!   @endint
private int parse_got( string new_data )
{
  if (hp) {
    string line;

    TIMER_START(parse_got);
    if (!hrtime)
      hrtime = gethrtime();
    {
      array res;
      if( mixed err = catch( res = hp->feed( new_data ) ) ) {
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
      [data, line, request_headers] = res;
    }
    hp = 0;
    TIMER_END(parse_got);

    // The following was earlier a separate function parse_got_2.

    TIMER_START(parse_got_2);
    TIMER_START(parse_got_2_parse_line);
    string f;
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
#ifdef CONNECTION_DEBUG
	  werror ("HTTP[%s]: Response =============================================\n"
		  "%O\n", DEBUG_GET_FD, "PONG\r\n");
#else
	  REQUEST_WERR("HTTP: Send PONG");
#endif
	  my_fd->write("PONG\r\n");
	  TIMER_END(parse_got_2_parse_line);
	  TIMER_END(parse_got_2);
	  return 2;
	}
	data = ""; // no headers or extra data...
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
    //REQUEST_WERR(sprintf("HTTP: raw_url %O", raw_url));

    if(!remoteaddr)
    {
      if(my_fd) {
	remoteaddr = my_fd->query_address();
	if(remoteaddr)
	  sscanf(remoteaddr, "%s %*s", remoteaddr);
      }
      if(!remoteaddr) {
	REQUEST_WERR(sprintf ("HTTP: No remote address (error %d).",
			      my_fd->errno()));
	TIMER_END(parse_got_2);
	return 2;
      }
    }

    TIMER_START(parse_got_2_parse_headers);
    foreach (request_headers; string linename; array|string contents)
    {
      if( arrayp(contents) ) contents = contents[0];
      switch (linename) 
      {
       case "cache-control":	// Opera sends "no-cache" here.
       case "pragma": pragma|=(multiset)((contents-" ")/",");  break;

       case "content-length": misc->len = (int)contents;       break;
       case "transfer-encoding":
	 misc->transfer_encoding =
	   map(lower_case(contents)/";", String.trim_all_whites);
	 if (has_value(misc->transfer_encoding, "chunked")) {
	   misc->chunked = 1;
	   misc->chunk_buf = "";
	   new_data = data; // For got_chunk_fragment() below.
	   data = "";
	 }
	 break;
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
	 // The following is the useless result of an old "fix" (it
	 // was lowercased before that); it'd been better to have used
	 // the field directly in request_headers instead if the
	 // lowercasing messed things up.
	 misc[linename] = contents;
#define WS "%*[ \t]"
	 sscanf (contents, WS"%[^ \t/]"WS"/"WS"%[^ \t;]"WS";"WS"%s",
		 string ct_type, string ct_subtype,
		 misc->content_type_params);
	 misc->content_type_type = lower_case (ct_type + "/" + ct_subtype);
	 break;
       case "destination":
	 // FIXME: This silently strips away the server if the
	 // destination is an absolute URI, and it can be a different
	 // one according to RFC 4918, section 10.3. If we cannot use
	 // it as destination (which is probably the case), then the
	 // request MUST NOT succeed.
	 if (mixed err = catch {
	     contents = http_decode_string (Standards.URI(contents,
							  "dummy:")->path);
	   }) {
#ifdef DEBUG
	   report_debug(sprintf("Destination header contained a bad URI: %O\n"
				"%s", contents, describe_error(err)));
#endif /* DEBUG */
	 }
	 misc["new-uri"] = VFS.normalize_path (contents);
	 break;

       case "expect":
	 // RFC 2616, section 14.20: "A server that does not
	 // understand or is unable to comply with any of the
	 // expectation values in the Expect field of a request MUST
	 // respond with appropriate error status." We only handle the
	 // standard 100-continue case (see ready_to_receive).
	 // Also: "Comparison of expectation values is case-insensitive
	 // for unquoted tokens (including the 100-continue token), and
	 // is case-sensitive for quoted-string expectation-extensions."
	 if (String.trim_all_whites(lower_case(contents)) != "100-continue") {
	   string res = "HTTP/1.1 417 Expectation Failed\r\n\r\n";
#ifdef CONNECTION_DEBUG
	   werror ("HTTP[%s]: Response (length %d) =================================\n"
		   "%O\n", DEBUG_GET_FD, sizeof (res), res);
#else
	   REQUEST_WERR(sprintf("HTTP: Send %O", res));
#endif
	   my_fd->write (res);
	   return 2;
	 }
	 break;
      }
    }
    TIMER_END(parse_got_2_parse_headers);
  }

  TIMER_START(parse_got_2_more_data);
  if (misc->chunked) {
    int ret = got_chunk_fragment(new_data);
    if (ret != 3) {
      REQUEST_WERR(sprintf("HTTP: More data needed in %s (chunked).", method));
      ready_to_receive();
      TIMER_END(parse_got_2_more_data);
      TIMER_END(parse_got_2);
      return ret;
    }
  } else if(misc->len)
  {
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
  } else {
    leftovers = data;
    data = "";
  }
  if (sizeof(data) && method == "POST") {
    // FIXME: Get this POST variable munching out of the backend thread!

    // See http://www.w3.org/TR/html401/interact/forms.html#h-17.13.4
    // and rfc 2388 for specs of the format of form submissions.
    switch (misc->content_type_type)
    {
      case "application/x-www-form-urlencoded": {
	// Form data.

	// Ok.. This might seem somewhat odd, but IE seems to add a
	// (spurious) \r\n to the end of the data, and some versions of
	// opera seem to add (spurious) \r\n to the start of the data.
	//
	// 4.5 and older trimmed id->data directly. We no longer do
	// that to allow the application to see the unmodified data if
	// the client says it's application/x-www-form-urlencoded but
	// in reality sends something else (some versions of the roxen
	// applauncher did that). (This is safe for correct
	// applauncher/x-www-form-urlencoded data since it doesn't
	// contain any whitespace.)
	string v = String.trim_all_whites (data);

	// This will be charset decoded later in
	// things_to_do_when_not_sending_from_cache.
	split_query_vars (v, misc->post_variables = ([]));
	break;
      }
	    
      case "multipart/form-data": {
	// Set Guess to one in order to fix the incorrect quoting of paths
	// from Internet Explorer when sending a file.
	MIME.Message messg = MIME.Message(data, request_headers, UNDEFINED, 1);
	array(MIME.Message) parts = messg->body_parts;

	if (!parts) {
	  report_error("HTTP: Bad multipart/form-data.\n"
		       "  headers:\n"
		       "%{    %O:%O\n%}"
		       "  data:\n"
		       "%{    %O\"\\n\"\n%}",
		       (array)request_headers,
		       data/"\n");
	  /* FIXME: Should this be reported to the client? */
	}

	else {
	  // We got two cases here: On one hand we got what rfc 2388 says, and
	  // on the other we got how essentially all browsers actually behave.
	  //
	  // The latter means that the text values and form variable names are
	  // sent in some poorly defined encoding, which is best to treat like
	  // the same sorry situation for url variables and
	  // application/x-www-form-urlencoded.
	  //
	  // On the first hint that the data actually is correct according to
	  // rfc 2388, we skip the bug compat charset handling. The hints we
	  // look for are:
	  //
	  // o  A Content-Disposition parameter which is rfc 2047 encoded.
	  // o  A Content-Type header which specifies a charset.

	  {
	    // Another difference is that multiple values for the same field
	    // are simply included as multiple body parts by browsers, while
	    // rfc 2388 mandates using one multipart/mixed entry. Let's
	    // convert to the simpler de-facto form.
	    array(MIME.Message) subparts = ({});
	    foreach (parts; int i; MIME.Message part)
	      if (array(MIME.Message) sub = part->body_parts) {
		// Assume multipart/mixed - it should never be anything else.
		subparts += sub;
		parts[i] = 0;
	      }
	    if (sizeof (subparts))
	      parts = parts - ({0}) + subparts; // Note: Keeps order per field.
	  }

	  mapping(string:string) rfc2047_decoded = ([]);
	  int rfc2388_mode;
	  foreach (parts, MIME.Message part) {
	    foreach (part->disp_params;; string param) {
	      string decoded;
	      if (!catch (decoded = MIME.decode_words_text_remapped (param)) &&
		  decoded != param)
		rfc2047_decoded[param] = decoded;
	    }
	    if (part->params->charset)
	      rfc2388_mode = 1;
	  }
	  if (sizeof (rfc2047_decoded))
	    rfc2388_mode = 1;

	  mapping(string:array(MIME.Message)) post_parts =
	    misc->post_parts = ([]);

	  if (rfc2388_mode) {
	    // Will this be executed ever?

	    // misc->proper_post_vars is temporary storage that is moved into
	    // real_variables after charset decode in
	    // things_to_do_when_not_sending_from_cache.
	    mapping(string:array(string)) post_vars =
	      misc->proper_post_vars = ([]);

	    foreach (parts, MIME.Message part) {
	      string name = part->disp_params->name;
	      if (string decoded = rfc2047_decoded[name]) name = decoded;

	      post_parts[name] += ({part});

	      string data = part->getdata();
	      if (string charset = part->param->charset) {
		if (mixed err = catch {
		    data = Locale.Charset.decoder (charset)->
		      feed (data)->drain();
		  })
		  report_debug ("Client %q sent data for %q which failed to "
				"decode with supplied charset %q: %s",
				client_var->fullname, name, charset,
				describe_error (err));
	      }
	      post_vars[name] += ({data});

	      if (part->headers["content-type"])
		// Use type and subtype fields to avoid any extra parameters.
		post_vars[name + ".mimetype"] += ({part->type + "/" +
						   part->subtype});

	      if (string filename = part->disp_params->filename) {
		if (string decoded = rfc2047_decoded[filename])
		  filename = decoded;
		post_vars[name + ".filename"] += ({filename});
		misc->files += ({name});
	      }
	    }
	  }

	  else {
	    mapping(string:array(string)) post_vars =
	      misc->post_variables = ([]);
	    foreach (parts, MIME.Message part) {
	      string name = part->disp_params->name;

	      post_parts[name] += ({part}); // Note: name still encoded here.

	      // Buglet: The following split into xxx, xxx.mimetype and
	      // xxx.filename doesn't work well if the same variable xxx is
	      // used both for files and other variables in the same form.
	      // That's a quite odd case, though.

	      post_vars[name] += ({part->getdata()});

	      if (part->headers["content-type"])
		// Use type and subtype fields to avoid any extra parameters.
		post_vars[name + ".mimetype"] += ({part->type + "/" +
						   part->subtype});

	      if (string filename = part->disp_params->filename) {
		post_vars[name + ".filename"] += ({filename});
		misc->files += ({name}); // Note: name still encoded here.
	      }
	    }
	  }
	}
	break;
      }
    }
  }
  TIMER_END(parse_got_2_more_data);

  if (!(< "HTTP/1.0", "HTTP/0.9" >)[prot]) {
    if (!misc->host) {
      // RFC 2616 requires this behaviour.
      string res = (prot||"HTTP/1.1") +
	" 400 Bad request (missing host header).\r\n"
	"Content-Length: 0\r\n"
	"Date: "+Roxen.http_date(predef::time())+"\r\n"
	"\r\n";
#ifdef CONNECTION_DEBUG
      werror ("HTTP[%s]: Response (length %d) =================================\n"
	      "%O\n", DEBUG_GET_FD, sizeof (res), res);
#else
      REQUEST_WERR("HTTP: HTTP/1.1 request without a host header.");
#endif
      // FIXME: my_fd_busy.
      my_fd->write (res);
      TIMER_END(parse_got_2);
      return 2;
    }
  }
  TIMER_END(parse_got_2);

  return 3;	// Done.
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
		    describe_backtrace (err));
#endif
    }
    my_fd = 0;
  }

  MERGE_TIMERS(conf);
  destruct();
}

protected void cleanup_request_object()
{
  if( conf )
    conf->connection_drop( this_object() );
  xml_data = 0;
}

void end(int|void keepit)
{
  if (my_fd) {
    CHECK_FD_SAFE_USE;
  }

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

    // Don't share these since proxies can send different user-agent headers
    // when multiplexing several clients into one connection
    //o->client = client;
    //o->supports = supports;
    //o->client_var = client_var;

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

protected void close_cb()
{
#ifdef CONNECTION_DEBUG
  werror ("HTTP[%s]: Client close -----------------------------------------\n",
	  DEBUG_GET_FD);
#else
  REQUEST_WERR ("HTTP: Got remote close.");
#endif

  CHECK_FD_SAFE_USE;

  cleanup_request_object();

  data_buffer = 0;
  pipe = 0;

  // Zero my_fd to avoid that the fd is closed by disconnect() - the
  // write direction might still want to use it. We rely on refcount
  // garbing instead, which means we must be careful about
  // deinstalling callbacks (they might not point to this object in
  // all cases).
  //
  // http_fallback.ssl_alert_callback also counts on that my_fd
  // doesn't get closed since it calls this close callback and then
  // passes the connection on to fallback_redirect_request.
  my_fd->set_read_callback (0);
  my_fd->set_close_callback (0);
  if (my_fd->set_alert_callback) {
    // Ugly hack in case of an ssl connection: Zero the alert and
    // accept callbacks too. They are set by the http_fallback in
    // prot_https.pike. It normally ensures that they get zeroed too
    // after a successful connect or http redirect, but if the client
    // drops the connection very early, before either path has been
    // taken, we get here directly. (http_fallback can't wrap close_cb
    // since it's installed afterwards.)
    my_fd->set_alert_callback (0);
    my_fd->set_accept_callback (0);
  }
  my_fd = 0;

  disconnect();
}

protected void do_timeout()
{
  int elapsed = predef::time(1)-time;
  if(time && elapsed >= 30)
  {
    // FIXME: Hardcoded timeout of 30 seconds above.
#ifdef CONNECTION_DEBUG
    werror ("HTTP[%s]: Connection timed out. Closing.\n", DEBUG_GET_FD);
#endif
    REQUEST_WERR(sprintf("HTTP: Connection timed out. Closing.\n"
			 "rcb:%O\n"
			 "wcb:%O\n"
			 "ccb:%O\n",
			 my_fd->query_read_callback(),
			 my_fd->query_write_callback(),
			 my_fd->query_close_callback()));
    MARK_FD("HTTP timeout");
    if (my_fd && my_fd->linger) {
      // We don't care if there's still data in the buffers
      // (there probably is), just terminate the connection
      // as soon as possible.
      my_fd->linger(0);
    }
    end();
  } else {
#ifdef DEBUG
    error ("This shouldn't happen.\n");
#endif
    // premature call_out... *�#!"
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

protected string error_page(string title, void|string msg,
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


protected string get_err_md5(array(string|array(string)|array(array)) err_info)
{
  if (err_info) {
    return String.string2hex(Crypto.MD5.hash(err_info[3]));
  }
  return "NONE";
}

protected array(string|array(string)|array(array)) get_err_info(int eid,
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
	  if (has_prefix (ent[0], cwd))
	    file = ent[0] = ent[0][sizeof (cwd)..];
	  else if (has_prefix (ent[0], roxenloader.server_dir + "/"))
	    file = ent[0] = ent[0][sizeof (roxenloader.server_dir + "/")..];
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
	  descr = func + "(" +dcl(ent[3..],1000)+")";
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
    if (r && (md5 == String.string2hex(Crypto.MD5.hash(r[3])))) {
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

protected object(this_program) chained_to;

protected void destroy()
{
  // To avoid references to destructed RequestID objects. Happens
  // otherwise when prot_https makes a http -> https redirect, for
  // instance.
  remove_call_out (do_timeout);

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
  werror ("HTTP[%s]: Response sent ========================================\n",
	  DEBUG_GET_FD);
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
    if(!(file->len = fsent) && pipe) {
      file->len = pipe->bytes_sent();
    }
    if(conf)
    {
      if(file->len > 0) conf->sent+=file->len;
      file->len += misc->_log_cheat_addition;

      {
	float t = (gethrtime() - hrtime)/1E6;
	if (t >  0.01) conf->request_num_runs_001s++;
	if (t >  0.05) conf->request_num_runs_005s++;
	if (t >  0.15) conf->request_num_runs_015s++;
	if (t >  0.50) conf->request_num_runs_05s++;
	if (t >  1.00) conf->request_num_runs_1s++;
	if (t >  5.00) conf->request_num_runs_5s++;
	if (t > 15.00) conf->request_num_runs_15s++;
	conf->request_acc_time += (int)(1E6*t);
      }
      {
	float t = handle_time/1E6;
	if (t >  0.01) conf->handle_num_runs_001s++;
	if (t >  0.05) conf->handle_num_runs_005s++;
	if (t >  0.15) conf->handle_num_runs_015s++;
	if (t >  0.50) conf->handle_num_runs_05s++;
	if (t >  1.00) conf->handle_num_runs_1s++;
	if (t >  5.00) conf->handle_num_runs_5s++;
	if (t > 15.00) conf->handle_num_runs_15s++;
	conf->handle_acc_time += (int)(1E6*t);
      }
      {
	float t = queue_time/1E6;
	if (t >  0.01) conf->queue_num_runs_001s++;
	if (t >  0.05) conf->queue_num_runs_005s++;
	if (t >  0.15) conf->queue_num_runs_015s++;
	if (t >  0.50) conf->queue_num_runs_05s++;
	if (t >  1.00) conf->queue_num_runs_1s++;
	if (t >  5.00) conf->queue_num_runs_5s++;
	if (t > 15.00) conf->queue_num_runs_15s++;
	conf->queue_acc_time += (int)(1E6*t);
      }

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
	// werror("Initiating new range %d -> %d.\n", @range);
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
      ranges += ({ ({ r1, len-1 }) });
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
	      //res[j++] = Roxen.make_http_headers(part_heads);
	      // It seems like Acrobat/IE can freeze if the content-range header precedes the content-type header
              res[j++] = "Content-Type: "+part_heads["Content-Type"] + "\r\n" + "Content-Range: "+part_heads["Content-Range"] + "\r\n\r\n";
	      res[j++] = file->data[range[0]..range[1]];
	    }
	    res[j++] = "\r\n--" BOUND "--\r\n";
	    file->len = sizeof(file->data = res * "");
	  }
	}
	variant_heads["Content-Length"] = (string)file->len;
      } else {
	// Got the header, but the specified ranges were out of bounds.
	// Reply with a 416 Requested Range not satisfiable.
	file->error = 416;
	variant_heads["Content-Range"] = "*/"+file->len;
	file->file = file->type = file->len = 0;
	file->data = "";
      }
    }
  }
}

// Tell the client that it can start sending some more data
void ready_to_receive()
{
  // FIXME: Only send once?
  if (clientprot == "HTTP/1.1" && stringp(request_headers->expect) &&
      (String.trim_all_whites(lower_case(request_headers->expect)) == 
       "100-continue") && !my_fd_busy) {
    string res = "HTTP/1.1 100 Continue\r\n\r\n";
#ifdef CONNECTION_DEBUG
    werror ("HTTP[%s]: Response (length %d) =================================\n"
	    "%O\n", DEBUG_GET_FD, sizeof (res), res);
#else
    REQUEST_WERR(sprintf("HTTP: Send %O", res));
#endif
    my_fd->write (res);
  }
}

// Send and account the formatted result
void low_send_result(string headers, string data, int|void len,
		     Stdio.File|void file)
{

  if (!my_fd) {
    do_log(0);
    return;
  }

  // Note: data may be UNDEFINED.
  if (!data) data = "";

  if (String.width (data) != 8) {
    int from, to;
    foreach (data; from; int chr)
      if (chr > 255)
	break;
    to = from + 1024;
    from -= 1024;
    error ("Attempt to send wide data: %s%O%s\n"
	   "Response mapping: %O\n"
	   "output_charset: %O\n",
	   from > 0 ? "..." : "",
	   data[from..to],
	   to < sizeof (data) ? "..." : "",
	   (this_program::file->data ?
	    this_program::file | (["data": "..."]) : this_program::file),
	   output_charset);
  }

  conf->hsent += sizeof(headers);
  if(!kept_alive && (len > 0) &&
     ((sizeof(headers) + len) < (HTTP_BLOCKING_SIZE_THRESHOLD))) {
    MY_TRACE_ENTER(sprintf("Sending blocking %d bytes of headers and "
			   "%d bytes of string data",
			   sizeof(headers), sizeof(data)));
    TIMER_START(blocking_write);
    if (sizeof(data) != len) {
      data = data[..len-1];
    }
    if (file) {
      data = file->read(len);
    }
#ifdef CONNECTION_DEBUG
    werror("HTTP[%s]: Blocking response (length %d) ======================\n"
	   "%O\n", DEBUG_GET_FD, sizeof (headers) + sizeof (data),
	   headers + data);
#else
    REQUEST_WERR(sprintf("HTTP: Send blocking %O", headers + data));
#endif
    int s = my_fd->write(({ headers, data }));
    TIMER_END(blocking_write);
    MY_TRACE_LEAVE(sprintf("Blocking write wrote %d bytes", s));
    do_log(s);
  } else {
    MY_TRACE_ENTER(sprintf("Sending async %d bytes of headers and "
			   "%d bytes of string data",
			   sizeof(headers), sizeof(data)));
#ifndef CONNECTION_DEBUG
    REQUEST_WERR(sprintf("HTTP: Send headers %O", headers));
#endif
    if (sizeof(headers))
      send(headers, 0,
#ifdef CONNECTION_DEBUG
	   1
#endif
	  );
    if (sizeof(data))
      send(data, len);
    if (file)
      send(file, len);
    // MY_TRACE_LEAVE before start_sender since it might destruct us.
    MY_TRACE_LEAVE ("Async sender started");
    start_sender();
  }
}

#ifdef HTTP_COMPRESSION
#ifdef HTTP_COMPR_STREAM
//! Class that will compress a file on the fly, i.e. read() will
//! return compressed data from the source file fed to @[create] or
//! @[open]. Writing is not supported currently.
class GzStreamingFile
{
  protected Gz.deflate def; 
  protected Stdio.File srcfile; 
  protected string read_buf; 
  protected int crc; 
  protected int file_pos; 
  protected int at_eof; 
  protected int src_at_eof; 
  protected int trailer_written;
  protected int level;
 
  constant default_level = 7;
  constant read_chunk_size = 1024*128; 
 
  void create (void|Stdio.File file, void|int level)
  //! If the argument @[file] is provided, @[open] will be called with
  //! that file as argument. @[level] is the compression level.
  {
    if (level)
      this_program::level = level;
    else
      this_program::level = default_level;

    if (file)
      open (file);
  } 
 
  int open (Stdio.File file) 
  //! Opens the stream for reading with @[file] as source. 
  { 
    read_buf = make_header(); 
    file_pos = 0; 
    srcfile = file; 
    crc = Gz.crc32(""); 
    at_eof = 0; 
    src_at_eof = 0; 
    trailer_written = 0; 
    def = Gz.deflate (-level, Gz.DEFAULT_STRATEGY); 
    return 1; 
  } 
 
  string read (int len) 
  {
    String.Buffer buf = String.Buffer(); 
    while (sizeof (read_buf) + sizeof (buf) < len && !src_at_eof) { 
      string chunk = srcfile->read (read_chunk_size); 
      if (sizeof (chunk) < read_chunk_size) 
        src_at_eof = 1;
      buf->add (def->deflate (chunk, Gz.NO_FLUSH)); 
      crc = Gz.crc32 (chunk, crc); 
    } 
 
    if (src_at_eof && !trailer_written) {
      buf->add (def->deflate ("", Gz.FINISH)); 
      buf->add (sprintf("%-4c%-4c", crc, srcfile->tell())); 
      trailer_written = 1; 
    } 
 
    read_buf += buf->get(); 
 
    string result = read_buf[..len-1]; 
    read_buf = read_buf[sizeof(result)..]; 
    file_pos += sizeof (result); 
    if (src_at_eof && !sizeof (read_buf)) 
      at_eof = 1; 

    return result; 
  } 
  int tell() 
  { 
    return file_pos; 
  } 
 
  int eof() 
  { 
    return at_eof; 
  } 
 
  int seek (int pos) 
  //! Note: the source file won't be seeked automatically. 
  { 
    open (srcfile); 
    int offset; 
    while (offset + read_chunk_size < pos) 
      offset += sizeof (read (read_chunk_size)); 
 
    read (pos-offset); 
    return file_pos; 
  } 
 
  string make_header() 
  { 
    return sprintf("%1c%1c%1c%1c%4c%1c%1c", 
                   0x1f, 0x8b, 8, 0, 0, 0, 3); 
  }

  string _sprintf()
  {
    return sprintf ("GzStreamingFile (%O)", srcfile);
  }
}
#endif

private int(0..1) compression_enabled_for_mimetype (string mimetype)
{
  mapping(string:int) compress_exact_mimetypes = conf->http_compr_exact_mimes;
  mapping(string:int) compress_main_mimetypes = conf->http_compr_main_mimes;

  if (mimetype)
    // We are not interested in the charset spec.
    mimetype = (mimetype / ";")[0];

  return (conf->http_compr_enabled &&
	  mimetype &&
	  (compress_exact_mimetypes[mimetype] ||
	   (sscanf (mimetype, "%[^/]", string main_type) &&
	    compress_main_mimetypes[main_type])));
}

private string gzip_data(string data)
{
  Stdio.FakeFile f = Stdio.FakeFile("", "wb");

  // Reuse the Gz.File object to reduce the overhead of instantiating
  // Gz.deflate objects etc.
  Gz.File gzfile = conf->gz_file_pool->get();
  if(!gzfile) {
    gzfile = Gz.File(f, "wb");
    gzfile->setparams(conf->query("http_compression_level"), 
		      Gz.DEFAULT_STRATEGY); 
    conf->gz_file_pool->set(gzfile);
  } else {
    gzfile->open(f, "wb");
  }

  gzfile->write(data);
  gzfile->close();

  return (string)f;
}

private string gunzip_data(string data)
{
  Stdio.FakeFile f = Stdio.FakeFile(data, "rb");

  Gz.File gzfile = conf->gz_file_pool->get();
  if(!gzfile) {
    gzfile = Gz.File(f, "rb");
    gzfile->setparams(conf->query("http_compression_level"), 
		      Gz.DEFAULT_STRATEGY);
    conf->gz_file_pool->set(gzfile);
  } else {
    gzfile->open(f, "rb");
  }

  string res = gzfile->read();
  gzfile->close();
  return res;
}

private
#ifdef HTTP_COMPR_STREAM
GzStreamingFile|
#endif
string try_gzip_data(Stdio.File|string data,
		     string mimetype)
{
  int min_data_length = conf->http_compr_minlen;
  int max_data_length = conf->http_compr_maxlen;

  int len = sizeof(data);

  if (compression_enabled_for_mimetype (mimetype)) {
    if (stringp (data)) {
      if (len >= min_data_length &&
	  (!max_data_length || len <= max_data_length)) {
	data = gzip_data(data);
	if (len>sizeof(data))
	  return data;
      }
    }
#ifdef HTTP_COMPR_STREAM
    else if (objectp (data) && functionp (data->read) &&
	     functionp (data->tell)) {
      return GzStreamingFile (data, conf->query ("http_compression_level"));
    }
#endif
  }
  return 0;
}

private int(0..1) compress_dynamic_requests()
{
  return conf->http_compr_dynamic_reqs;
}

private int(0..1) client_gzip_enabled()
{
  array(string)|string accept_encoding = request_headers["accept-encoding"];

  if (stringp (accept_encoding)) {
    return has_value("," + lower_case(accept_encoding - " " - "\t") + ",",
		     ",gzip,");
  } else if (arrayp (accept_encoding)) {
    foreach (accept_encoding, string ae) {
      if (has_value("," + lower_case(ae - " " - "\t") + ",", ",gzip,"))
	return 1;
    }
  }

  return 0;
}

#endif // HTTP_COMPRESSION

// Send the result.
void send_result(mapping|void result)
{
  TIMER_START(send_result);

  if (my_fd)
    CHECK_FD_SAFE_USE;

  destruct_threadbound_session_objects();

  handle_time = gethrtime() - handle_time;
#if constant(System.CPU_TIME_IS_THREAD_LOCAL)
  handle_vtime = gethrvtime() - handle_vtime;
#endif

  array err;
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

  if(!mappingp(file))
  {
    NO_PROTO_CACHE();
    if(misc->error_code)
      file = Roxen.http_status(misc->error_code,
			       Roxen.http_status_messages[misc->error_code]);
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
      if (do_not_disconnect) return;
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
	  replace (Roxen.html_encode_string (string_to_utf8(head_status)),
		   "\n", "<br />\n") +
	  "</body></html>";
	file->len = sizeof (file->data);
	file->type = "text/html; charset=utf-8";
      }
      if (has_value (head_status, "\n"))
	// Fold lines nicely.
	head_status = map (head_status / "\n", String.trim_all_whites) * " ";
    }

#ifdef HTTP_COMPRESSION
    if(compression_enabled_for_mimetype (get_response_content_type (file))) {
      // Notify proxies etc. that we depend on the Accept-Encoding header,
      // but we don't want to register it as a vary callback since it's
      // handled directly by the protocol cache.
      if(!misc->vary)
	misc->vary = (< "accept-encoding" >);
      else
	misc->vary["accept-encoding"] = 1;
    }
#endif

    mapping(string:string) heads = make_response_headers (file);

    // Notes about the variant headers:
    //
    // Date		Changes with every request.
    // Content-Type	May change if a byte-range request is performed.
    // Content-Length	May change due to If-* headers, etc.
    // Connection	Depends on the protocol version and state.
    // Expires          Might need to modify this for HTTP/1.0 clients.
    // Cache-Control    Might need to modify this when sending stale responses.
    mapping(string:string) variant_heads = ([ "Date":"",
					      "Content-Type":"",
					      "Content-Length":"",
					      "Connection":"",
					      "Expires":"",
					      "Cache-Control": "",
#ifdef HTTP_COMPRESSION
                                              "Content-Encoding":"",
                                              "ETag":"",
					      // Keeping the ETag
					      // while transforming
					      // content (gzip) may
					      // confuse clients.
#endif
    ]) & heads;
    m_delete(heads, "Date");
    m_delete(heads, "Content-Type");
    m_delete(heads, "Content-Length");
    m_delete(heads, "Connection");
    m_delete(heads, "Expires");
    m_delete(heads, "Cache-Control");
#ifdef HTTP_COMPRESSION
    m_delete(heads, "Content-Encoding");
    m_delete(heads, "ETag");
#endif

    // FIXME: prot.
    head_string = sprintf(" %s\r\n", head_status ||
			  Roxen.http_status_messages[file->error] || "");

    if (mixed err = catch(head_string += Roxen.make_http_headers(heads, 1)))
    {
      report_debug("Roxen.make_http_headers failed on %O: %s",
		   heads, describe_error (err));
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
    }

    if (objectp(cookies)) {
      // Disconnect the cookie jar.
      real_cookies = cookies = ~cookies;
    }

    int varies = misc->vary && (sizeof(misc->vary) - misc->vary["host"]);
#ifdef RAM_CACHE
    int stored_in_cache;
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

#ifdef HTTP_COMPRESSION
          string uncompressed = data;
          string compressed;
	  string encoding = file->encoding;
          if(!encoding) {
            if(compressed = 
	       try_gzip_data(data, variant_heads["Content-Type"])) {
              data = compressed;
              encoding = "gzip";
            }
          }
#endif

	  conf->datacache->set(misc->prot_cache_key, data,
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
				 "cache_control":variant_heads["Cache-Control"],
				 "mtime":(file->stat &&
					  file->stat[ST_MTIME]),
				 "rf":realfile,
				 "refresh":predef::time(1) +
				 5 + 3*misc->cacheable/4,
#ifdef HTTP_COMPRESSION
                                 "encoding" : encoding,
#endif				 
			       ]),
			       misc->cacheable, this_object());
	  stored_in_cache = 1;
	  file = ([
#ifndef HTTP_COMPRESSION
            "data":data,
	    "len":strlen(data),
#endif
	    "raw":file->raw,
	    "error":file->error,
	    "type":variant_heads["Content-Type"],
	  ]);

#ifdef HTTP_COMPRESSION
	  if(!misc->range && compressed && client_gzip_enabled()) {
	    file->data = compressed;
	    file->encoding = encoding;
	    file->compressed = 1;
	  } else {
	    file->data = uncompressed;
	  }
	  file->len = sizeof(file->data);
	  variant_heads["Content-Length"] = (string)file->len;
#endif
	  cache_status["protstore"] = 1;
	}
      }
    }

    if (!stored_in_cache && misc->is_spci_refresh) {
      // If this was a protocol cache refresh request that didn't make
      // it to the protocol cache, remove the stale entry to prevent
      // overcaching. Reasons for the refresh request not to make it
      // to the cache include files that were removed recently,
      // transitions from cacheable to non-cacheable etc.
      conf->datacache->expire_entry (misc->prot_cache_key, 0);
    }
#endif

#ifdef HTTP_COMPRESSION
    // Don't use compression if we're dealing with byte ranges. Who
    // knows what kind of interesting effects that might have.
    if(!file->compressed && (file->data || file->file) && !misc->range &&
       compress_dynamic_requests() && client_gzip_enabled()) {
      if (mixed /*Stdio.File|string*/ compressed =
	  try_gzip_data(file->data ? file->data : file->file,
			variant_heads["Content-Type"])) {
	if (file->data) {
	  file->data = compressed;
	  file->len = sizeof(file->data);
	  variant_heads["Content-Length"] = (string)file->len;
	} else if (file->file) {
	  file->file = compressed;
	  m_delete (file, "len"); // We don't know the length since we will be streaming compressed data...
	  m_delete (variant_heads, "Content-Length");
	}
	file->encoding = "gzip";
	file->compressed = 1;      
      }
    }
    
    if(file->compressed && misc->etag) {
      string etag = misc->etag;
      if(etag[sizeof(etag)-1..] == "\"")
	misc->etag = etag[..sizeof(etag)-2] + ";gzip\"";
    }
#endif

    // Some browsers, e.g. Netscape 4.7, don't trust a zero
    // content length when using keep-alive. So let's force a
    // close in that case.
    if( file->error/100 == 2 && file->len <= 0 )
    {
      variant_heads->Connection = "close";
      misc->connection = "close";
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
#ifndef DISABLE_VARY_EXPIRES_FALLBACK
      variant_heads["Expires"] = Roxen->http_date(predef::time(1)-31557600);
#endif /* !DISABLE_VARY_EXPIRES_FALLBACK */
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
#ifdef HTTP_COMPRESSION
      if(misc->etag)
        variant_heads["ETag"] = misc->etag;
      if(file->encoding)
        variant_heads["Content-Encoding"] = file->encoding;
      // Perhaps set some gzip log status if file->encoding == "gzip" here?
#endif
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
	    //  Needs strict equality according to RFC 7233
	    array(int) since_info = Roxen.parse_since(if_range);
	    if (!since_info || (since_info[0] != misc->last_modified)) {
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

// Execute the request. This is called from a handler thread.
protected void handle_request_from_queue( )
{
  if (mixed err = catch {

  REQUEST_WERR("HTTP: handle_request_from_queue()");

  int now = gethrtime();
  queue_time = now - queue_time;

  // Let's see if the queue time was so long that we should return a
  // "503 - server too busy" response..
  int queue_timeout = conf->handler_queue_timeout;
  if (queue_timeout && queue_time/1E6 > queue_timeout) {
    REQUEST_WERR (sprintf ("HTTP: Too long in queue (%d ms) - returning 503\n",
			   queue_time));
    file = Roxen.http_rxml_answer (conf->query ("503-message"),
				   this, 0, "text/html");
    file->error = Protocols.HTTP.HTTP_UNAVAIL;
    NO_PROTO_CACHE();
    handle_time = 0;
    handle_vtime = 0;
    TIMER_END(handle_request);
    send_result();
    return;
  }

  handle_request();

  }) {
    call_out (disconnect, 0);
    report_error("Internal server error: " + describe_backtrace(err));
  }
}

void handle_request()
{
  if (mixed err = catch {

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

  handle_time = gethrtime();
#if constant(System.CPU_TIME_IS_THREAD_LOCAL)
  handle_vtime = gethrvtime();
#endif

  mapping result;
  array e = catch(result = conf->handle_request( this_object() ));
  // Note: Could be destructed here already since handle_request might
  // have handed over us to another thread that finished quickly. The
  // right place to put code is probably send_result instead.
  //
  // I wonder exactly where that handing-over might happen. There
  // should probably be destruct_threadbound_session_objects calls
  // there too. /mast

  if (this)
    destruct_threadbound_session_objects();

  if(e)
    INTERNAL_ERROR( e );

  else {
    if (result && result->pipe) {
      REQUEST_WERR("HTTP: handle_request: pipe in progress.");
      TIMER_END(handle_request);
      return;
    }
    file = result;
  }

  if( file && file->try_again_later )
  {
    if( objectp( file->try_again_later ) )
      ;
    else
      call_out( roxen.handle, file->try_again_later, handle_request );
    TIMER_END(handle_request);
    return;
  }

  TIMER_END(handle_request);
  send_result();

  }) {
    call_out (disconnect, 0);
    report_error("Internal server error: " + describe_backtrace(err));
  }
}

/* We got some data on a socket.
 * =================================================
 */
// array ccd = ({});
void got_data(mixed fooid, string s, void|int chained)
{
  if (mixed err = catch {

#ifdef CONNECTION_DEBUG
  if (wanted_data < 2000)
    werror ("HTTP[%s]: Request ----------------------------------------------\n"
	    "%O\n", DEBUG_GET_FD, s);
  else
    werror ("HTTP[%s]: Request ----------------------------------------------\n"
	    "Length %d\n", DEBUG_GET_FD, sizeof (s));
#else
  REQUEST_WERR(sprintf("HTTP: Got %O", s));
#endif

  // Keep track of how much data we've received.
  raw_bytes += sizeof(s);

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
  } else if (misc->chunked) {
    if (!got_chunk_fragment(s)) {
      REQUEST_WERR("HTTP: We want more data (chunked).");

      // Reset timeout.
      remove_call_out(do_timeout);
      call_out(do_timeout, 90);

      if (chained)
	my_fd->set_nonblocking(got_data, 0, close_cb);
      return;
    }
    s = "";
  }

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

      case 1: {
	string res = (prot||"HTTP/1.0")+" 500 Illegal request\r\n"
	  "Content-Length: 0\r\n"+
	  "Date: "+Roxen.http_date(predef::time())+"\r\n"
	  "\r\n";
#ifdef CONNECTION_DEBUG
	werror ("HTTP[%s]: Response (length %d) =================================\n"
		"%O\n", DEBUG_GET_FD, sizeof (res), res);
#else
	REQUEST_WERR("HTTP: Stupid Client Error.");
#endif
	my_fd->write (res);
	end();
	return;			// Stupid request.
      }
    
      case 2:
	REQUEST_WERR("HTTP: Done.");
	end();
	return;
    }

#ifdef CONNECTION_DEBUG
    werror ("HTTP[%s]: Request received -------------------------------------\n",
	    DEBUG_GET_FD);
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
    misc->prot_cache_key = raw_url;
    if (has_prefix(raw_url, port_obj->url_prefix)) {
      sscanf(raw_url[sizeof(port_obj->url_prefix)..], "%[^/]%s",
	     misc->host, raw_url);
    }

    string canon_hostport;
    if (string host = misc->host) {
      // Parse and canonicalize the host header for use in the url
      // used for port matching.
      int port = port_obj->default_port;
      if (has_prefix(host, "[")) {
	//  IPv6 address
	sscanf(lower_case(host), "[%s]:%d", host, port);
	host = Protocols.IPv6.normalize_addr_basic (host) || host;
	canon_hostport = "[" + host + "]:" + port;
      } else {
	sscanf(lower_case(host), "%[^:]:%d", host, port);
	canon_hostport = host + ":" + port;
      }
      misc->hostname = host;
      misc->port = port;
    }

    if( !conf || !(path = port_obj->path ) ||
	(sizeof( path ) && !has_prefix(raw_url, path)) ) {
      // FIXME: port_obj->name & port_obj->default_port are constant
      // consider caching them?

      string port_match_url = (port_obj->url_prefix +
			       (canon_hostport || ("*:" + port_obj->port)) +
			       raw_url);
      conf = port_obj->find_configuration_for_url(port_match_url, this);

      // Note: The call above might have replaced port_obj from one
      // bound to a specific interface to one bound to ANY.

      if (misc->defaulted_conf > 1)
	// Use the full url in the cache if a fallback configuration
	// (with or without the default_server flag) was chosen.
	misc->prot_cache_key = port_match_url;
    }
    else if( strlen(path) )
      adjust_for_config_path( path );

    TIMER_END(find_conf);

    // The "http_request_init" provider hook allows modules to do
    // things very early in the request path, before the request is
    // put in the handler queue and before the protocol cache is
    // queried.
    //
    // Use with great care; this is run in the backend thread, and
    // some things in the id object are still not initialized.
    foreach (conf->get_providers ("http_request_init"), RoxenModule mod)
      if (mapping res = mod->http_request_init (this)) {
	conf->received += raw_bytes - sizeof(leftovers);
	conf->requests++;
	// RequestID.make_response_headers assumes the supports multiset exists.
	if (!supports) supports = (<>);
	send_result (res);
	return;
      }

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
	//
	// FIXME: Obsolete API!
	if (conf->auth_module)
	  misc->proxyauth
	    = conf->auth_module->auth(misc->proxyauth,this_object() );
      }
    }

    conf->connection_add( this_object(), connection_stats );
    conf->received += raw_bytes - sizeof(leftovers);
    conf->requests++;

    CHECK_FD_SAFE_USE;
    my_fd->set_close_callback(0);
    my_fd->set_read_callback(0);

    remove_call_out(do_timeout);
#ifdef RAM_CACHE
    TIMER_START(cache_lookup);
    array cv;
    if(misc->cacheable && !misc->no_proto_cache &&
       (cv = conf->datacache->get(misc->prot_cache_key, this)) )
    {
      MY_TRACE_ENTER(sprintf("Checking entry %O", misc->prot_cache_key));
      if( !cv[1]->key ) {
	MY_TRACE_LEAVE("Entry invalid due to zero key");
	conf->datacache->expire_entry(misc->prot_cache_key, this);
      }
      else 
      {
	int can_cache = 1;
	string d = cv[ 0 ];
#ifdef DEBUG
	if (!stringp (d))
	  error ("Strange value from data cache for %O: %O\n", raw_url, cv);
#endif
	file = cv[1];
	
	if( sizeof(file->callbacks) )
	{
	  if( mixed e = catch 
	  {
	    foreach( file->callbacks, function f ) {
	      if (!file->key) break;
	      MY_TRACE_ENTER (sprintf ("Checking with %O", f));
	      if( !f(this_object(), file->key ) )
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
		destruct(file->key);
	      }) {
	      // Fall back to a standard internal error.
	      INTERNAL_ERROR( e );
	      TIMER_END(cache_lookup);
	      send_result();
	      return;
	    }
	  }
	}
	if(roxen.invalidp(file->key))
	{
	  // Stale or invalid key.
	  if (!file->key) {
	    // Invalid.
	    MY_TRACE_LEAVE ("Entry invalid due to zero key");
	    conf->datacache->expire_entry(misc->prot_cache_key, this);
	    can_cache = 0;
	  } else {
	    cache_status["stale"] = 1;
	    if (file->refresh > predef::time(1)) {
	      // Stale and no refresh in progress.
	      // We want a refresh as soon as possible,
	      // so move the refresh time to now.
	      // Note that we use the return value from m_delete()
	      // to make sure we are free from races.
	      // Note also that we check above that the change is needed,
	      // so as to avoid the risk of starving the code below.
	      if (m_delete(file, "refresh")) {
		file->refresh = predef::time(1);
	      }
	    }
	  }
	}      
	if( can_cache )
	{
#ifndef RAM_CACHE_ASUME_STATIC_CONTENT
	  Stat st;
	  if( !file->rf || !file->mtime || 
	      ((st = file_stat( file->rf )) && st->mtime == file->mtime ))
#endif
	  {
	    int refresh;
	    if (file->refresh && (file->refresh <= predef::time(1))) {
	      // We might need to refresh the entry.
	      // Note that we use the return value from m_delete()
	      // to make sure we are free from races.
	      if (refresh = m_delete(file, "refresh")) {
		refresh = 1 + predef::time(1) - refresh;
	      }
	    }

	    int code = file->error;
	    int len = sizeof(d);
            mapping(string:string) variant_heads = ([]);
	    // Make sure we don't mess with the RAM cache.
	    file += ([]);
#ifdef HTTP_COMPRESSION
	    if(file->etag)
	      variant_heads["ETag"] = file->etag;
            if(file->encoding == "gzip") {
              if(!misc->range && client_gzip_enabled()) {
                variant_heads["Content-Encoding"] = file->encoding;
                if(file->etag) {
                  string etag = file->etag;
		  if(etag[sizeof(etag)-1..] == "\"")
                    etag = etag[..sizeof(etag)-2] + ";gzip\"";
                  file->etag = variant_heads["ETag"] = etag;
                }
		// Perhaps set some gzip log status here?
              } else {
                d = gunzip_data(d);
                len = sizeof(d);
              }
            }
#endif
	    if (none_match) {
	      //  RFC 2616, Section 14.26:
	      //
	      //  If none of the entity tags match, then the server
	      //  MAY perform the requested method as if the
	      //  If-None-Match header field did not exist, but MUST
	      //  also ignore any If-Modified-Since header field(s) in
	      //  the request. That is, if no entity tags match, then
	      //  the server MUST NOT return a 304 (Not Modified)
	      //  response.
	      if (none_match[file->etag] || (none_match["*"] && file->etag)) {
		// Not modified.
		code = 304;
		d = "";
		len = 0;
	      }
	    } else if (since && file->last_modified) {
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
	    variant_heads += ([
	      "Date":Roxen.http_date(predef::time(1)),
	      "Content-Length":(string)len,
	      "Content-Type":file->type,
	      "Connection":misc->connection,
	    ]);

	    // Don't allow any downstream caching if the response is stale. One
	    // reason for this is that if a client has been notified somehow
	    // about the change that has made this entry stale, and then
	    // proceeds to retrieve the resource to get the new version, it at
	    // least shouldn't overcache the response if it's unlucky and gets
	    // the old stale version. (One might consider disabling this if all
	    // clients can be assumed to be end users.)
	    if (cache_status->stale) {
	      variant_heads["Cache-Control"] = "no-cache";
	      // RFC2616, 14.9.3: "If a cache returns a stale response, /.../,
	      // the cache MUST attach a Warning header to the stale response,
	      // using Warning 110 (Response is stale)."
	      variant_heads["Warning"] = "110 " +
		replace (my_fd->query_address (1) || "roxen", " ", ":") +
		" \"Response is stale - update is underway\" "
		"\"" + variant_heads["Date"] + "\"";
	    }
	    else if (string cc = file->cache_control)
	      variant_heads["Cache-Control"] = cc;

	    string expires;
	    if (expires = (cache_status->stale // See above.
#ifndef DISABLE_VARY_EXPIRES_FALLBACK
			   || (file->varies && (prot == "HTTP/1.0"))
#endif /* !DISABLE_VARY_EXPIRES_FALLBACK */
			   ? Roxen->http_date(predef::time(1)-31557600) :
			   file->expires)) {
	      variant_heads["Expires"] = expires;
	    }
	    // Some browsers, e.g. Netscape 4.7, don't trust a zero
	    // content length when using keep-alive. So let's force a
	    // close in that case.
	    if( file->error/100 == 2 && file->len <= 0 )
	    {
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
		  if (if_range != file->etag) {
		    // ETag has changed.
		    skip = 1;
		  }
		} else {
		  //  Needs strict equality according to RFC 7233
		  array(int) since_info = Roxen.parse_since(if_range);
		  if (!since_info || (since_info[0] != file->last_modified)) {
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

	    MY_TRACE_LEAVE ("Using entry from protocol cache");
	    cache_status["protcache"] = 1;

	    if (!refresh) {
	      // No need to refresh the cached entry, so we just send it,
	      // disconnect the cookie jar, and are done.
	      if (objectp(cookies)) {
		// Disconnect the cookie jar just before sending the reply.
		real_cookies = cookies = ~cookies;
	      }
	      TIMER_END(cache_lookup);
	      low_send_result(full_headers, d, sizeof(d));
	      return;
	    }
	    // Create a new RequestID for sending the cached response,
	    // so that it won't interfere with this one when it finishes.
	    // We need to copy lots of stuff to keep the log functions happy.
	    RequestID id = clone_me();
	    id->hrtime = hrtime;
	    id->my_fd = my_fd;
	    id->file = file;
	    id->kept_alive = kept_alive;
	    id->cache_status = cache_status + (<>);
	    id->eval_status = eval_status + (<>);
	    id->output_charset = output_charset;
	    id->input_charset = input_charset;
	    id->auth = auth;
	    id->throttle = throttle + ([]);
	    id->throttler = throttler;
	    conf->connection_add( id, connection_stats );
	    TIMER_END(cache_lookup);
	    id->low_send_result(full_headers, d, sizeof(d));

	    method = "GET";
	    remoteaddr = "127.0.0.1";
	    host = 0;
	    my_fd = 0;
	    misc->connection = "close";
	    misc->is_spci_refresh = 1;
	    
	    MY_TRACE_ENTER (
	      sprintf("Starting refresh of stale entry "
		      "(%d seconds past refresh time)", refresh - 1));
	    cache_status["protcache"] = 0;
	    cache_status["refresh"] = 1;
	    cache_status["stale"] = 0;
	    MY_TRACE_LEAVE("");
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
    queue_time = gethrtime();
    queue_length = roxen.handle_queue_length();
    roxen.handle(handle_request_from_queue);
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

  if (objectp(cookies)) {
    c->cookies = c->CookieJar(real_cookies + ([]));
  } else if (cookies) {
    c->cookies = c->real_cookies = real_cookies + ([]);
  } else {
    c->cookies = c->real_cookies = 0;
  }
  c->request_headers = request_headers + ([]);
  c->my_fd = 0;
  c->prot = prot;
  c->clientprot = clientprot;
  c->method = method;

// realfile virtfile   // Should not be copied.
  c->rest_query = rest_query;
  c->raw = raw;
  c->raw_bytes = raw_bytes;
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
  else if((predef::time(1) - time) > 4800) {
    // FIXME: Hardcoded timeout of 80 minutes above.
    if (my_fd->linger) my_fd->linger(0);
    end();
  }
}

protected void create(object f, object c, object cc)
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
  hrtime = 0;

  if ( le && strlen( le ) ) {
    REQUEST_WERR(sprintf("HTTP: %d bytes left over.\n", sizeof(le)));
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
