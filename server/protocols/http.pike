// This is a roxen protocol module.
// Modified by Francesco Chemolli to add throttling capabilities.
// Copyright © 1996 - 2000, Roxen IS.

constant cvs_version = "$Id: http.pike,v 1.239 2000/08/13 03:08:27 per Exp $";
// #define REQUEST_DEBUG
#define MAGIC_ERROR

#undef OLD_RXML_COMPAT

#ifdef MAGIC_ERROR
inherit "highlight_pike";
#endif

// HTTP protocol module.
#include <config.h>

// #define DO_TIMER

#ifdef DO_TIMER
static int global_timer, global_total_timer;
#  define ITIMER()  write("\n\n\n");global_total_timer = global_timer = gethrtime();
#  define TIMER(X) do {int x=gethrtime()-global_timer; \
                       int y=gethrtime()-global_total_timer; \
                       write( "%20s ... %1.1fms / %1.1fms\n",X,x/1000.0,y/1000.0 );\
                       global_timer = gethrtime(); } while(0);
#else
#  define ITIMER()
#  define TIMER(X)
#endif

#ifdef PROFILE
#define HRTIME() gethrtime()
#define HRSEC(X) ((int)((X)*1000000))
#define SECHR(X) ((X)/(float)1000000)
int req_time = HRTIME();
#endif

#ifdef ID_OBJ_DEBUG
Debug.ObjectMarker __marker = Debug.ObjectMarker (this_object());
#endif

#ifdef REQUEST_DEBUG
int footime, bartime;
#define REQUEST_WERR(X) bartime = gethrtime()-footime; werror("%s (%d)\n", (X), bartime);footime=gethrtime()
#else
#define REQUEST_WERR(X)
#endif

#ifdef FD_DEBUG
#define MARK_FD(X) catch{REQUEST_WERR(X); mark_fd(my_fd->query_fd(), (X)+" "+remoteaddr);}
#else
#define MARK_FD(X) REQUEST_WERR(X)
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
constant _time           = predef::time;

private static array(string) cache;
private static int wanted_data, have_data;

object conf;
object port_obj;

#include <roxen.h>
#include <module.h>
#include <variables.h>

int time;
string raw_url;
int do_not_disconnect;
mapping (string:string) variables       = ([ ]);
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
mapping (string:string) cookies         = ([ ]);
mapping (string:string) request_headers = ([ ]);
mapping (string:string) client_var      = ([ ]);

multiset (string) prestate  = (< >);
multiset (string) config    = (< >);
multiset (string) supports  = (< >);
multiset (string) pragma    = (< >);

string remoteaddr, host;

array  (string) client;
array  (string) referer;

mapping file;

object my_fd; /* The client. */

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
array(string) output_charset = ({});
string input_charset;

void set_output_charset( string|function to, int|void mode )
{
  if( search( output_charset, to ) != -1 ) // Already done.
    return;

  switch( mode )
  {
   case 0: // Really set.
     output_charset = ({ to });
     break;

   case 1: // Only set if not already set.
     if( !sizeof( output_charset ) )
       output_charset = ({ to });
     break;

   case 2: // Join.
     output_charset |= ({ to });
     break;
  }
}

string charset_name( function|string what )
{
  switch( f )
  {
   case string_to_unicode:   return "ISO10646-1";
   case string_to_utf8:      return "UTF-8";
   default:                  return upper_case((string)what);
  }
}

function charset_function( function|string what )
{
  switch( f )
  {
   case "ISO-10646-1":
   case "ISO10646-1":
   case string_to_unicode:
     return string_to_unicode;
   case "UTF-8":
   case string_to_utf8:
     return string_to_utf8;
   default:
     return Roxen._charset_decoder( Locale.Charset.encoder( (string)what ) )->decode;
  }
}

static array(string) join_charset( string old,
                                   function|string add,
                                   function|void oldcodec)
{
  switch( old&&upper_case(old) )
  {
   case 0:
     return ({ charset_name( add ), charset_function( add ) });
   case "ISO10646-1":
   case "UTF-8":
     return ({ old, oldcodec }); // Everything goes here. :-)
   case "ISO-2022":
     return ({ old, oldcodec }); // Not really true, but how to know this?
   default:
     // Not true, but there is no easy way to add charsets yet...
     return ({ charset_name( add ), charset_function( add ) });
  }
}

static array(string) output_encode( string what )
{
  string charset;
  function encoder;

  foreach( output_charset, string|function f )
    [charset,encoder] = join_charset( charset, f, encoder );


  if( !encoder )
    if( String.width( what ) > 8 )
    {
      charset = "UTF-8";
      encoder = string_to_utf8;
    }
  if( encoder )
    what = encoder( what );
  return ({ charset, what });
}

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
  if(stringp(decoder))
    decoder = Roxen._charset_decoder(Locale.Charset.decoder(decoder))->decode;

  if( misc->request_charset_decoded )
    return;

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
  if( auth )
  {
    auth = map( auth, lambda( mixed q ) {
                        if( stringp( q ) )
                          return safe_decoder( q );
                        return q;
                      } );
    rawauth = safe_decoder( rawauth );
    realauth = safe_decoder( realauth );
  }
  if( since )
    since = safe_decoder( since );

  decode_map( variables, decoder );
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

void end(string|void a,int|void b);

object pipe;

//used values: throttle->doit=0|1 to enable it
//             throttle->rate the rate
//             throttle->fixed if it's not to be touched again
mapping throttle=([]);

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
  if (!conf || !conf->query("req_throttle"))
    throttle->doit=0;
  if(!pipe) {
    if (throttle->doit || (conf && conf->throttler)) {
      pipe=roxen->slowpipe();
    } else {
      pipe=roxen->fastpipe();
    }
  }
  if (throttle->doit) { //we are sure that pipe is really a slowpipe.
    throttle->rate=max(throttle->rate,
             conf->query("req_throttle_min")); //if conf=0 => throttle=0
    pipe->throttle(throttle->rate,
                   (int)(throttle->rate*conf->query("req_throttle_depth_mult")),
                   0);
    THROTTLING_DEBUG("throtting request at "+throttle->rate);
  }
  if (conf && conf->throttler) {
    pipe->assign_throttler(conf->throttler);
  }
}


void send (string|object what, int|void len)
{
  REQUEST_WERR(sprintf("send(%O, %O)\n", what, len));

  if(!what) return;
  if(!pipe) setup_pipe();
  if(!pipe) return;
  if(stringp(what))  pipe->write(what);
  else               pipe->input(what,len);
}

void start_sender (function callback, mixed ... args)
{
  if (pipe) {
    MARK_FD("HTTP really handled, piping "+not_query);
#ifdef FD_DEBUG
    call_out(timer, 30, _time(1)); // Update FD with time...
#endif
    // FIXME: What about args?
    pipe->set_done_callback( callback );
    pipe->output(my_fd);
  } else {
    MARK_FD("HTTP really handled, pipe done");
    callback(@args);
  }
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

#ifdef OLD_RXML_COMPAT
private int really_set_config(array mod_config)
{
  string url, m;
  string base;
  if (conf)
    base = conf->query("MyWorldLocation");
  else
    base = "/";

  if(supports->cookies)
  {
    REQUEST_WERR("Setting cookie..\n");
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
		  + Roxen.http_roxen_config_cookie(indices(config) * ",") + "\r\n"
		 "Location: " + url + "\r\n"
		 "Content-Type: text/html\r\n"
		 "Content-Length: 0\r\n\r\n");
  } else {
    REQUEST_WERR("Setting {config} for user without Cookie support..\n");
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

    url = Roxen.add_pre_state(url, prestate);

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
  return 2;
}
#endif

private static mixed f, line;
private static int hstart;

class PrefLanguages {

  int decoded=0;
  int sorted=0;
  array(string) subtags=({});
  array(string) languages=({});
  array(float) qualities=({});

  array(string) get_languages() {
    sort_lang();
    return languages;
  }

  string get_language() {
    if(!languages || !sizeof(languages)) return 0;
    sort_lang();
    return languages[0];
  }

  array(float) get_qualities() {
    sort_lang();
    return qualities;
  }

  float get_quality() {
    if(!qualities || !sizeof(qualities)) return 0.0;
    sort_lang();
    return qualities[0];
  }

  void set_sorted(array(string) lang, void|array(float) q) {
    languages=lang;
    if(q && sizeof(q)==sizeof(lang))
      qualities=q;
    else
      qualities=({1.0})*sizeof(lang);
    sorted=1;
  }

  void sort_lang() {
    if(sorted && decoded) return;
    array(float) q;
    array(string) s=reverse(languages)-({""}), u=({});

    if(!decoded) {
      q=({});
      s=Array.map(s, lambda(string x) {
		       float n=1.0;
		       string sub="";
		       sscanf(lower_case(x), "%s;q=%f", x, n);
		       if(n==0.0) return "";
		       sscanf(x, "%s-%s", x, sub);
		       q+=({n});
		       u+=({sub});
		       return x;
		     });
      s-=({""});
      decoded=1;
    }
    else
      q=reverse(qualities);

    sort(q,s,u);
    languages=reverse(s);
    qualities=reverse(q);
    subtags=reverse(u);
    sorted=1;
  }
}
#if constant(Roxen.HeaderParser)
static Roxen.HeaderParser hp = Roxen.HeaderParser();
#endif
int last;
private int parse_got( string new_data )
{
  multiset (string) sup;
#ifdef OLD_RXML_COMPAT
  array mod_config;
  int config_in_url;
#endif
  string a, b, s="", linename, contents;
  mapping header_mapping = ([]);

#if constant(Roxen.HeaderParser)
  if( !method )
  {
    array res;
    if( catch { res  = hp->feed( new_data ); } )
      return 1;
    if( !res )
      return 0; // Not enough data;
    /* now in res:

    leftovers/data
     
    first line
    headers 
    */
    data = res[0];
    line = res[1];
    header_mapping = res[2];
  }
#else
  REQUEST_WERR(sprintf("HTTP: parse_got(%O)", raw));
  if (!method) {  // Haven't parsed the first line yet.
    int start;
    // We check for \n only if \r\n fails, since Netscape 4.5 sends
    // just a \n when doing a proxy-request.
    // example line:
    //   "CONNECT mikabran:443 HTTP/1.0\n"
    //   "User-Agent: Mozilla/4.5 [en] (X11; U; Linux 2.0.35 i586)"
    // Die Netscape, die! *grumble*
    // Luckily the solution below shouldn't ever cause any slowdowns
    //
    // Note by Neo:  Rewrote the sscanf code to use search with a memory.
    // The reason is that otherwise it's really, REALLY easy to lock up
    // a Roxen server by sending a request that either has no newlines at all
    // or has infinite sized headers. With this version, Roxen doesn't die but
    // it does suck up data ad finitum - a configurable max GET request size and
    // also a max GET+headers would be nice. 

    if((start = search(raw[last..], "\n")) == -1) {
      last = max(strlen(raw) - 3, 4);
      REQUEST_WERR(sprintf("HTTP: parse_got(%O): Not enough data.", raw));
      return 0;
    } else {
      start += last;
      last = 0;
      if(!start) {
	REQUEST_WERR(sprintf("HTTP: parse_got(%O): malformed request.", raw));
	return 1; // malformed request
      }
    }
    if (raw[start-1] == '\r') {
      line = raw[..start-2];
    } else {
      // Kludge for Netscape 4.5 sending bad requests.
      line = raw[..start-1];
    }
    if(strlen(line) < 4)
    {
      // Incorrect request actually - min possible (HTTP/0.9) is "GET /"
      // but need to support PING of course!

      REQUEST_WERR(sprintf("HTTP: parse_got(%O): Malformed request.", raw));
      return 1;
    }
#endif
    string trailer, trailer_trailer;

    switch(sscanf(line+" ", "%s %s %s %s %s",
		  method, f, clientprot, trailer, trailer_trailer))
    {
    case 5:
      // Stupid sscanf!
      if (trailer_trailer != "") {
	// Get rid of the extra space from the sscanf above.
	trailer += " " + trailer_trailer[..sizeof(trailer_trailer)-2];
      }
      /* FALL_THROUGH */
    case 4:
      // Got extra spaces in the URI.
      // All the extra stuff is now in the trailer.

      // Get rid of the extra space from the sscanf above.
      trailer = trailer[..sizeof(trailer) - 2];
      f += " " + clientprot;

      // Find the last space delimiter.
      int end;
      if (!(end = (search(reverse(trailer), " ") + 1))) {
        // Just one space in the URI.
        clientprot = trailer;
      } else {
        f += " " + trailer[..sizeof(trailer) - (end + 1)];
        clientprot = trailer[sizeof(trailer) - end ..];
      }
      /* FALL_THROUGH */
    case 3:
      // >= HTTP/1.0

      prot = clientprot;
      // method = upper_case(p1);
      if(!(< "HTTP/1.0", "HTTP/1.1" >)[prot]) {
	// We're nice here and assume HTTP even if the protocol
	// is something very weird.
	prot = "HTTP/1.1";
      }
      // Do we have all the headers?
      if ((end = search(raw[last..], "\r\n\r\n")) == -1) {
	// No, we still need more data.
	REQUEST_WERR("HTTP: parse_got(): Request is still not complete.");
	last = max(strlen(raw) - 5, 0);
	return 0;
      }
      end += last;
      last = 0;
      data = raw[end+4..];
      s = raw[sizeof(line)+2..end-1];
      // s now contains the unparsed headers.
      break;

    case 2:
      // HTTP/0.9
      clientprot = prot = "HTTP/0.9";
      if(method != "PING")
	method = "GET"; // 0.9 only supports get.
      s = data = ""; // no headers or extra data...
      break;

    case 1:
      // PING...
      if(method == "PING")
	break;
      // only PING is valid here.
      return 1;

    default:
      // Too many or too few entries ->  Hum.
      return 1;
    }
#if !constant(Roxen.HeaderParser)
  } 
  else 
  {
    // HTTP/1.0 or later
    // Check that the request is complete
    int end;
    if ((end = search(raw[last..], "\r\n\r\n")) == -1) {
      // No, we still need more data.
      REQUEST_WERR("HTTP: parse_got(): Request is still not complete.");
      last = max(strlen(raw) - 5, 0);
      return 0;
    }
    end += last;
    data = raw[end+4..];
    s = raw[sizeof(line)+2..end-1];
  }
#endif
  if(method == "PING") {
    my_fd->write("PONG\r\n");
    return 2;
  }
  REQUEST_WERR(sprintf("***** req line: %O", line));
  REQUEST_WERR(sprintf("***** headers:  %O", s));
  REQUEST_WERR(sprintf("***** data:     %O", data));
  raw_url    = f;
  time       = _time(1);
  // if(!data) data = "";
  REQUEST_WERR(sprintf("RAW_URL:%O", raw_url));

  if(!remoteaddr)
  {
    if(my_fd) {
      remoteaddr = my_fd->query_address();
      if(remoteaddr)
      	sscanf(remoteaddr, "%s %*s", remoteaddr);
    }
    if(!remoteaddr) {
      REQUEST_WERR("HTTP: parse_request(): No remote address.");
      end();
      return 2;
    }
  }

  REQUEST_WERR(sprintf("After Remote Addr:%O", f));

  f = scan_for_query( f );

  REQUEST_WERR(sprintf("After query scan:%O", f));

  f = http_decode_string( f );
  string prf = f[1..1];
#ifdef OLD_RXML_COMPAT
  if (prf == "<" && sscanf(f, "/<%s>/%s", a, f)==2)
  {
    config_in_url = 1;
    mod_config = (a/",");
    f = "/"+f;
  }
#endif

  REQUEST_WERR(sprintf("After cookie scan:%O", f));

  if (prf == "(" && (sscanf(f, "/(%s)/%s", a, f)==2) && strlen(a))
  {
    prestate = aggregate_multiset(@(a/","-({""})));
    f = "/"+f;
  }

  REQUEST_WERR(sprintf("After prestate scan:%O", f));

  not_query = Roxen.simplify_path(f);

  REQUEST_WERR(sprintf("After simplify_path == not_query:%O", not_query));

  request_headers = ([]);	// FIXME: KEEP-ALIVE?

  misc->pref_languages=PrefLanguages();

#if constant(Roxen.HeaderParser)
  foreach( (array)header_mapping, [string linename,contents] )
#else
  if(sizeof(s)) {
    //    sscanf(s, "%s\r\n\r\n%s", s, data);
    //     s = replace(s, "\n\t", ", ") - "\r";
    //     Handle rfc822 continuation lines and strip \r
    foreach(s/"\r\n" - ({""}), line)
    {
      //      REQUEST_WERR(sprintf("Header :%s", line));
      //      linename=contents=0;

      if(sscanf(line, "%s:%*[ \t]%s", linename, contents) == 3)
#endif
      {
      	REQUEST_WERR(sprintf("Header-sscanf :%s", linename));
#if !constant(Roxen.HeaderParser)
      	linename=lower_case(linename);
      	REQUEST_WERR(sprintf("lower-case :%s", linename));
#endif

      	request_headers[linename] = contents;
        if( arrayp( contents ) ) contents *= ", ";
        switch (linename) 
        {
         case "content-length":
           misc->len = (int)contents;
           break;

         case "authorization":
           rawauth = contents;
           break;

         case "proxy-authorization":
           array y;
           y = contents / " ";
           if(sizeof(y) < 2)
             break;
           y[1] = decode(y[1]);
           misc->proxyauth=y;
           break;

         case "pragma":
           pragma|=aggregate_multiset(@replace(contents, " ", "")/ ",");
           break;

         case "user-agent":
           if(!client || !client_var->Fullname)
           {
             sscanf(contents, "%s via", contents);
             client_var->Fullname=contents;
             client = contents/" " - ({ "" });
           }
           break;

         case "referer":
           referer = contents/" ";
           break;

         case "extension":
#ifdef DEBUG
           werror("Client extension: "+contents+"\n");
#endif
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

         case "connection":
         case "content-type":
           misc[linename] = lower_case(contents);
           break;

         case "accept-encoding":
           foreach((contents-" ")/",", string e) {
             if (lower_case(e) == "gzip") {
               supports["autogunzip"] = 1;
             }
           }
         case "accept":
         case "accept-charset":
         case "session-id":
         case "message-id":
         case "from":
           if(misc[linename])
             misc[linename] += (contents-" ") / ",";
           else
             misc[linename] = (contents-" ") / ",";
           break;

         case "accept-language":
           array alang=(contents-" ") / ",";
           if(misc["accept-language"])
             misc["accept-language"] += alang;
           else
             misc["accept-language"] = alang;
           misc->pref_languages->languages=misc["accept-language"];
           break;

         case "cookie": /* This header is quite heavily parsed */
           string c;
           misc->cookies = contents;
           if (!sizeof(contents)) {
             // Needed for the new Pike 0.6
             break;
           }
           foreach(((contents/";") - ({""})), c)
           {
             string name, value;
             while(sizeof(c) && c[0]==' ') c=c[1..];
             if(sscanf(c, "%s=%s", name, value) == 2)
             {
               value=http_decode_string(value);
               name=http_decode_string(name);
               cookies[ name ]=value;
#ifdef OLD_RXML_CONFIG
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
#endif
             }
           }
           break;

         case "host":
         case "proxy-connection":
         case "security-scheme":
         case "via":
         case "cache-control":
         case "negotiate":
         case "forwarded":
         case "new-uri":
           misc[linename]=contents;
           break;

         case "proxy-by":
         case "proxy-maintainer":
         case "proxy-software":
         case "mime-version":
           break;

         case "if-modified-since":
           since=contents;
           break;
        }
      }
#if !constant(Roxen.HeaderParser)
    }
#endif
    if(misc->len && method == "POST")
    {
      if(!data) data="";
      int l = misc->len;
      wanted_data=l;
      have_data=strlen(data);
	
      if(strlen(data) < l)
      {
        REQUEST_WERR("HTTP: parse_request(): More data needed in POST.");
        return 0;
      }
      leftovers = data[l+2..];
      data = data[..l+1];
	
      switch(lower_case((((misc["content-type"]||"")+";")/";")[0]-" "))
      {
       default: // Normal form data.
         string v;
         if(l < 200000)
         {
           foreach(replace(data,
                           ({ "\n", "\r", "+" }),
                           ({ "", "", " "}))/"&", v)
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
             if(variables[part->disp_params->name])
               variables[part->disp_params->name] += "\0" + part->getdata();
             else
               variables[part->disp_params->name] = part->getdata();
           }
         }
         break;
      }
    }
#if !constant(Roxen.HeaderParser)
  }
#endif
  REQUEST_WERR("HTTP: parse_got(): after header scan");
#ifndef DISABLE_SUPPORTS
  if(!client) {
    client = ({ "unknown" });
    array s_and_v = find_supports_and_vars("", supports);
    supports = s_and_v[0];
    client_var = s_and_v[1];
  }
  else {
    if( !client_var->Fullname )
      client_var->Fullname = "unknown";
    client_var->fullname=lower_case(client_var->Fullname);
    array s_and_v = find_supports_and_vars(client_var->fullname, supports, client_var);
    supports = s_and_v[0];
    client_var = s_and_v[1];
  }

  if ( client_var->charset && client_var->charset  != "iso-8859-1" )
  {
    set_output_charset( client_var->charset );
    input_charset = client_var->charset;
  }
#else
  supports = (< "images", "gifinline", "forms", "mailto">);
#endif
  REQUEST_WERR("HTTP: parse_got(): supports");
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
#ifdef OLD_RXML_COMPAT
  if(config_in_url) {
    REQUEST_WERR("HTTP: parse_got(): config_in_url");
    return really_set_config( mod_config );
  }
#endif
  if(!supports->cookies)
    config = prestate;
  else
    if(port_obj->query("set_cookie")
       && !cookies->RoxenUserID && strlen(not_query)
       && not_query[0]=='/' && method!="PUT")
    {
      if (!(port_obj->query("set_cookie_only_once") &&
	    cache_lookup("hosts_for_cookie",remoteaddr))) {
	misc->moreheads = ([ "Set-Cookie":Roxen.http_roxen_id_cookie(), ]);
      }
      if (port_obj->query("set_cookie_only_once"))
	cache_set("hosts_for_cookie",remoteaddr,1);
    }
  return 3;	// Done.
}

void disconnect()
{
  file = 0;
#ifdef REQUEST_DEBUG
  if (my_fd) MARK_FD("my_fd in HTTP disconnected?");
#endif
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
    string nid =
#ifdef FILE_PROFILE
      not_query
#else
      dirname(not_query)
#endif
      ;
    array p;
    if(!(p=conf->profile_map[nid]))
      p = conf->profile_map[nid] = ({0,0.0,0.0});
    p[0]++;
    p[1] += elapsed;
    if(elapsed > p[2]) p[2]=elapsed;
  }
#endif

  TIMER("end[1]");

#ifdef KEEP_ALIVE
  if(keepit && !file->raw
     && (misc->connection == "keep-alive" ||
	 (prot == "HTTP/1.1" && misc->connection != "close"))
     && my_fd)
  {
    // Now.. Transfer control to a new http-object. Reset all variables etc..
    object o = object_program(this_object())(0, 0, 0);
    o->remoteaddr = remoteaddr;
    o->supports = supports;
    o->host = host;
    o->client = client;
    o->conf = conf;
    MARK_FD("HTTP kept alive");
    object fd = my_fd;
    my_fd=0;
    if(s) leftovers += s;
    o->chain(fd,port_obj,leftovers);
    TIMER("end[2]");
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
  TIMER("end[3]");
  disconnect();
}

static void do_timeout()
{
  // werror("do_timeout() called, time="+time+"; time()="+_time()+"\n");
  int elapsed = _time()-time;
  if(time && elapsed >= 30)
  {
    MARK_FD("HTTP timeout");
    // Do not under any circumstances send any data as a reply here.
    // This is an easy reason why: It breaks keep-alive totaly.
    // It is not a very good idea to do that, since it might be enabled
    // per deafult any century now..
    end("");
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
    id = f->read(1024);
    if(sscanf(id, "%*s$"+"Id: %*s,v %s ", id) == 3)
      return last_id=" (version "+id+")";
  };
  last_id = "";
  return "";
}

void add_id(mixed to)
{
  if (arrayp (to) && sizeof (to) >= 2 && arrayp (to[1]) ||
      objectp (to) && to->is_generic_error)
    foreach(to[1], array q)
      if(sizeof(q) && stringp(q[0])) {
	string id = get_id(q[0]);
	catch (q[0] += id);
      }
}

string link_to(string file, int line, string fun, int eid, int qq)
{
  if (!file || !line) return "<a>";
  if(file[0]!='/') file = combine_path(getcwd(), file);
  return ("<a href=\"/(old_error,find_file)/error/?"+
	  "file="+Roxen.http_encode_string(file)+
	  (fun ? "&fun="+Roxen.http_encode_string(fun) : "") +
	  "&off="+qq+
	  "&error="+eid+
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

string format_backtrace(int eid)
{
  [string msg, array(string) rxml_bt, array(array) bt,
   string raw_bt_descr, string raw_url, string raw] =
    roxen.query_var ("errors")[eid];

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
    foreach(reverse (bt), [string file, int line, string func, string descr])
      res += "<li value="+(q--)+">" +
	link_to (file, line, func, eid, q) +
	(file ? Roxen.html_encode_string (file) : "<i>Unknown program</i>") +
	(line ? ":" + line : "") +
	"</a>" + (file ? Roxen.html_encode_string (get_id (file)) : "") + ":<br />\n" +
	replace (Roxen.html_encode_string (descr),
		 ({"(", ")"}), ({"<b>(</b>", "<b>)</b>"})) +
	"</li>\n";
    res += "</ul>\n\n";
  }

  res += ("<p><b><a href=\"/(old_error,plain)/error/?error="+eid+"\">"
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

int store_error(mixed err)
{
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

  string cwd = getcwd() + "/";
  array bt;
  if (arrayp (err) && sizeof (err) >= 2 && arrayp (err[1]) ||
      objectp (err) && err->is_generic_error) {
    bt = ({});
    foreach (err[1], mixed ent) {
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
	    func = function_name(ent[2]);
	    if (!file)
	      catch {
		file = master()->describe_program (
		  object_program (function_object (ent[2])));
		if (file[..sizeof (cwd) - 1] == cwd) file = file[sizeof (cwd)..];
	      };
	  }
	  else if (stringp(ent[2])) func = ent[2];
	  else func ="unknown function";
	if (sizeof (ent) >= 4)
	  descr = func + "(" + master()->stupid_describe_comma_list (
	    ent[3..], master()->bt_max_string_len) + ")";
	else
	  descr = func + "()";
      }
      else if (stringp (ent)) descr = ent;
      else if (catch (descr = sprintf ("%O", ent)))
	descr = "???";
      bt += ({({file, line, func, descr})});
    }
  }

  add_id (err);
  e[id] = ({msg,rxml_bt,bt,describe_backtrace (err),raw_url,censor(raw)});
  return id;
}

array get_error(string eid)
{
  mapping e = roxen.query_var("errors");
  if(e) return e[(int)eid];
  return 0;
}


void internal_error(array err)
{
  array err2;
  if(port_obj->query("show_internals"))
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

void do_log()
{
  MARK_FD("HTTP logging"); // fd can be closed here
  TIMER("data sent");
  if(conf)
  {
    int len;
    if(pipe) file->len = pipe->bytes_sent();
    if(conf)
    {
      if(file->len > 0) conf->sent+=file->len;
      file->len += misc->_log_cheat_addition;
      conf->log(file, this_object());
    }
  }
  end(0,1);
  return;
}

#ifdef FD_DEBUG
void timer(int start)
{
  if(pipe) {
    // FIXME: Disconnect if no data has been sent for a long while
    //   (30min?)
    MARK_FD(sprintf("HTTP_piping_%d_%d_%d_%d_(%s)",
		    pipe->sent,
		    stringp(pipe->current_input) ?
		    strlen(pipe->current_input) : -1,
		    pipe->last_called,
		    _time(1) - start,
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


// Parse the range header itno multiple ranges.
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
  if (clientprot == "HTTP/1.1") {
    my_fd->write("HTTP/1.1 100 Continue\r\n");
  }
}

// Send the result.
void send_result(mapping|void result)
{
  array err;
  int tmp;
  mapping heads;
  string head_string;
  if (result)
    file = result;

  REQUEST_WERR(sprintf("HTTP: send_result(%O)", file));

  if(!mappingp(file))
  {
    if(misc->error_code)
      file = Roxen.http_low_answer(misc->error_code, errors[misc->error]);
    else if(err = catch {
      file = Roxen.http_low_answer(404,
				   Roxen.parse_rxml(
#ifdef OLD_RXML_COMPAT
						    replace(conf->query("ZNoSuchFile"),
							    ({"$File", "$Me"}),
							    ({ "&page.virtfile;",
							       conf->query("MyWorldLocation")
							    })),
#else
						    conf->query("ZNoSuchFile"),
#endif
						    this_object()));
    }) {
      INTERNAL_ERROR(err);
    }
  } else {
    if((file->file == -1) || file->leave_me)
    {
      if(do_not_disconnect) {
	file = 0;
	pipe = 0;
	return;
      }
      my_fd = 0;
      file = 0;
      return;
    }

    if(file->type == "raw")  file->raw = 1;
    else if(!file->type)     file->type="text/plain";
  }

  if(!file->raw)
  {
    heads = ([]);
    if( !file->len )
    {
      if(objectp(file->file))
	if(!file->stat && !(file->stat=misc->stat))
	  file->stat = (array(int))file->file->stat();
      array fstat;
      if(arrayp(fstat = file->stat))
      {
	if(file->file && !file->len)
	  file->len = fstat[1];

	if (fstat[3] > misc->last_modified) {
	  misc->last_modified = fstat[3];
	}

	if(prot != "HTTP/0.9" && !misc->is_dynamic) 
        {
          heads["Last-Modified"] = Roxen.http_date(misc->last_modified);

	  if(since)
	  {
	    /* ({ time, len }) */
	    array(int) since_info = Roxen.parse_since( since );
            if ( ((since_info[0] >= misc->last_modified) && 
                  ((since_info[1] == -1) || (since_info[1] == file->len)))
                 // actually ok, or...
                 || ((misc->cacheable>0) 
                     && (since_info[0] + misc->cacheable<= predef::time(1)))
                 // cacheable, and not enough time has passed.
                 )
	    {
	      file->error = 304;
	      file->file = 0;
	      file->data="";
	    }
	  }
	}
      }
    }
    if(prot != "HTTP/0.9") 
    {
      string h, charset="";

      if( stringp(file->data) )
      {
	if (file["type"][0..4] == "text/") 
        {
	  [charset,file->data] = output_encode( file->data );
	  if( charset )
	    charset = "; charset="+charset;
	  else
	    charset = "";
	}
        if(stringp(file->data))
          file->len = strlen(file->data);
      }
      heads["Content-type"] = file["type"]+charset;
      heads["Accept-Ranges"] = "bytes";
      heads["Server"] = replace(version(), " ", "·");
      heads["Connection"] = (misc->connection=="close" ? "close": "keep-alive");
//       heads["Date"] = Roxen.http_date(time),

      if(file->encoding)
	heads["Content-Encoding"] = file->encoding;

      if(!file->error)
	file->error=200;

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
      head_string = prot+" "+(file->rettext||errors[file->error])+"\r\n";
      if( file->len > 0 )  heads["Content-Length"] = (string)file->len;
      if( file->len <= 0 ) misc->connection = "close";
#if constant( Roxen.make_http_headers )
      head_string += Roxen.make_http_headers( heads );
#else
      foreach(indices(heads), h)
	if(arrayp(heads[h]))
	  foreach(heads[h], tmp)
	    head_string += h+": "+tmp+"\r\n";
	else
          head_string += h+": "+heads[h]+"\r\n";
      head_string += "\r\n";
#endif
      if(conf) conf->hsent += strlen(head_string);
    }
  }
  REQUEST_WERR(sprintf("Sending result for prot:%O, method:%O file:%O\n",
		       prot, method, file));

  MARK_FD("HTTP handled");

#ifdef KEEP_ALIVE
  if(!leftovers) leftovers = data||"";
#endif

  TIMER("send_result");
  if(method != "HEAD" && file->error != 304)
    // No data for these two...
  {
    if(my_fd->query_fd && my_fd->query_fd() >= 0 &&
       file->len > 0 && file->len < 4000)
    {
      // Ordinary connection, and a short file.
      // Just do a blocking write().
      my_fd->write(head_string);
      my_fd->write(file->file?file->file->read(file->len):
                   (file->data[..file->len-1]));
      do_log();
      return;
    }
    if(head_string)
      send(head_string);
    if(file->data && strlen(file->data))
      send(file->data, file->len);
    if(file->file)
      send(file->file, file->len);
  } else {
    if(head_string)
    {
      if(my_fd->query_fd && my_fd->query_fd() >= 0 &&
         file->len > 0 && file->len < 2000)
      {
        // Ordinary connection, and a short file.
        // Just do a blocking write().
        my_fd->write( head_string );
        do_log( );
        return;
      }
      send(head_string);
    }
    file->len = 1; // Keep those alive, please...
  }
  start_sender(do_log);
}


// Execute the request
void handle_request( )
{
  REQUEST_WERR("HTTP: handle_request()");
  TIMER("enter_handle");

#ifdef MAGIC_ERROR
  if(prestate->old_error)
  {
    array err = get_error(variables->error);
    if(err)
    {
      if(prestate->plain)
      {
	file = ([
	  "type":"text/plain",
	  "data":generate_bugreport( @err ),
	]);
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
          send_result();
          return;
	}
      }
    }
  }
#endif /* MAGIC_ERROR */

  remove_call_out(do_timeout);
  MARK_FD("HTTP handling request");

  array e;
  if(e= catch(file = conf->handle_request( this_object() )))
    INTERNAL_ERROR( e );
  
  TIMER("conf->handle_request");
  if( file->try_again_later )
  {
    call_out( handle_request, file->try_again_later );
    return;
  }
  send_result();
}

/* We got some data on a socket.
 * =================================================
 */
int processed;
void got_data(mixed fooid, string s)
{
  ITIMER();
  TIMER("got_data");
  if (mixed err = catch {

  int tmp;

  MARK_FD("HTTP got data");
  remove_call_out(do_timeout);
  call_out(do_timeout, 30); // Close down if we don't get more data
                         // within 30 seconds. Should be more than enough.
  time = _time(1); // Check is made towards this to make sure the object
  		  // is not killed prematurely.
  if(!raw)
    raw = s;
  else
    raw += s;
  if(wanted_data)
  {
    if(strlen(s) + have_data < wanted_data)
    {
      //      cache += ({ s });
      have_data += strlen(s);

      REQUEST_WERR("HTTP: We want more data.");
      return;
    }
  }

  if(strlen(raw)) 
    tmp = parse_got( s );

  TIMER("parse");

  switch(tmp)
  {
   case 0:
    //    if(this_object())
    //      cache = ({ s });		// More on the way.
    REQUEST_WERR("HTTP: Request needs more data.");
    return;

   case 1:
    REQUEST_WERR("HTTP: Stupid Client Error");
    end((prot||"HTTP/1.0")+" 500 Stupid Client Error\r\nContent-Length: 0\r\n\r\n");
    return;			// Stupid request.

   case 2:
    REQUEST_WERR("HTTP: Done");
    end();
    return;
  }

  mixed q;
  if( q = variables->magic_roxen_automatic_charset_variable )
    decode_charset_encoding( Roxen.get_client_charset_decoder( q,this_object() ) );
  if( input_charset )
    decode_charset_encoding( input_charset );

  TIMER("charset");

  if( !conf )
  {
    if (misc->host)
    {
      // FIXME: port_obj->name & port_obj->default_port are constant
      // consider caching them?
      conf = 
           port_obj->find_configuration_for_url(port_obj->name + "://" +
                                                misc->host +
                                                (search(misc->host, ":")<0?
                                                 (":"+port_obj->default_port):"") +
                                                not_query,
                                                this_object());
    }
    else
    {
      // No host header.
      // Fallback to using the first configuration bound to this port.
      conf = port_obj->mu || 
           (port_obj->mu = port_obj->urls[port_obj->sorted_urls[0]]->conf);
      misc->defaulted = 1;
      // Support delayed loading in this case too.
      if (!conf->inited) {
        conf->enable_all_modules();
      }
    }
  }

  TIMER("conf");

  if (rawauth)
  {
    /* Need to authenticate with the configuration */
    array(string) y = rawauth / " ";
    realauth = 0;
    auth = 0;
    if (sizeof(y) >= 2)
    {
      y[1] = MIME.decode_base64(y[1]);
      realauth = y[1];
      if (conf->auth_module)
        y = conf->auth_module->auth(y, this_object());
      auth = y;
    }
  }


  if( misc->proxyauth )
  {
    /* Need to authenticate with the configuration */
    if (sizeof(misc->proxyauth) >= 2)
    {
      //    misc->proxyauth[1] = MIME.decode_base64(misc->proxyauth[1]);
      if (conf->auth_module)
        misc->proxyauth
          = conf->auth_module->auth(misc->proxyauth,this_object() );
    }
  }

  conf->received += strlen(s);
  conf->requests++;

  REQUEST_WERR("HTTP: Calling roxen.handle().");

  my_fd->set_close_callback(0);
  my_fd->set_read_callback(0);
  processed=1;
  TIMER("pre_handle");
  roxen.handle(handle_request);
  })
  {
    report_error("Internal server error: " + describe_backtrace(err));
    my_fd->close();
    destruct (my_fd);
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

// c->first = first;
  c->port_obj = port_obj;
  c->conf = conf;
  c->time = time;
  c->raw_url = raw_url;
  c->variables = copy_value(variables);
  c->misc = copy_value(misc);
  c->misc->orig = t;

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
  else if((_time(1) - time) > 4800)
    end();
}

static void create(object f, object c, object cc)
{
  if(f)
  {
    MARK_FD("HTTP connection");
    f->set_read_callback(got_data);
    f->set_close_callback(end);
    my_fd = f;
    if( c ) port_obj = c;
    if( cc ) conf = cc;
    time = _time(1);
    call_out(do_timeout, 30);
    string q = f->read( 8192, 1 );
    if( q ) got_data( 0, q );
  }
}

void chain(object f, object c, string le)
{
  my_fd = f;
  port_obj = c;
  do_not_disconnect=-1;

  MARK_FD("Kept alive");
  if(strlen(le))
    // More to handle already.
    got_data(0,le);
  else
  {
    // If no pipelined data is available, call out...
    remove_call_out(do_timeout);
    call_out(do_timeout, 150);
    time = _time(1);
//     string q = f->read( 8192, 1 );
//     if( q ) got_data( 0, q );
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
      f->set_close_callback(end);
      f->set_read_callback(got_data);
    }
  }
}

string _sprintf( )
{
#ifdef ID_OBJ_DEBUG
  return "RequestID()" + (__marker ? "[" + __marker->count + "]" : "");
#else
  return "RequestID()";
#endif
}

Stdio.File connection( )
{
  return my_fd;
}

Configuration configuration()
{
  return conf;
}
