// This is a roxen pike module. Copyright © 1999 - 2009, Roxen IS.
//
// $Id$

#include <roxen.h>
#include <config.h>
#include <version.h>
#include <module.h>
#include <stat.h>
#define roxen roxenp()

#ifdef HTTP_DEBUG
# define HTTP_WERR(X) report_debug("HTTP: "+X+"\n");
#else
# define HTTP_WERR(X)
#endif

// Tell Pike.count_memory this is global.
constant pike_cycle_depth = 0;

// Error handling tools

enum OnError {
  THROW_INTERNAL = 0,	//! Throw a generic error.
  THROW_RXML,		//! Throw an RXML run error.
  LOG_ERROR,		//! Log the error and return @expr{0@} (zero).
  RETURN_ZERO,		//! Return @expr{0@} (zero).
};
//! Flags to control the error handling in various functions taking an
//! argument of this type.
//!
//! Typical use is as an argument to a function that in turn
//! calls @[raise_err()] in order to handle an error.
//!
//! @note
//!   This covers only specific types of errors that the function might
//!   generate. Other errors might throw internal exceptions or return
//!   zero. See the function docs.
//!
//! @seealso
//!   @[raise_err()]

int(0..0) raise_err (OnError on_error, sprintf_format msg,
		     sprintf_args... args)
//! Trig an error according to @[on_error].
//!
//! Typical use is as an expression in a @expr{return@} statement.
//!
//! @param on_error
//!   Method to signal the error:
//!   @int
//!     @value THROW_INTERNAL
//!       Throw a generic exception (@expr{"internal server error"@}).
//!       Use this for error conditions that never should
//!       happen if the code is correct. This is the default.
//!   
//!     @value THROW_RXML
//!       Throw the error as a RXML run error.
//!       Convenient in rxml tag implementations.
//!   
//!     @value LOG_ERROR
//!       Print a message using @[report_error] and
//!       return @expr{0@} (zero).
//!   
//!     @value RETURN_ZERO
//!       Just return @expr{0@} (zero).
//!   @endint
//!
//! @param msg
//!   Error message.
//!
//! @param args
//!   @[sprintf()] parameters for @[msg] (if any).
//!
//! @returns
//!   If the function returns, it will always be the
//!   value @expr{0@} (zero).
//!
//! @seealso
//!   @[OnError]
{
  switch(on_error) {
    case LOG_ERROR: report_error(msg, @args); break;
    case RETURN_ZERO: break;
    case THROW_RXML: RXML.run_error(msg, @args);
    default: error(msg, @args);
  }
  return 0;
}


// Thunks to be able to access the cache from here, since this module
// is compiled and instantiated before cache.pike.
function cache_lookup =
  lambda (mixed... args) {
    return (cache_lookup = all_constants()["cache_lookup"]) (@args);
  };
function cache_set =
  lambda (mixed... args) {
    return (cache_set = all_constants()["cache_set"]) (@args);
  };
function cache_remove =
  lambda (mixed... args) {
    return (cache_remove = all_constants()["cache_remove"]) (@args);
  };

object|array(object) parse_xml_tmpl( string ttag, string itag,
				     string xml_file,
				     string|void ident )
{
  string tmpl;
  array(mapping) data = ({});

  Parser.HTML p = Parser.HTML();

  object apply_template( mapping data )
  {
    Parser.HTML p = Parser.HTML();
    p->ignore_tags( 1 );
    p->_set_entity_callback( lambda( Parser.HTML p, string ent )
			     {
			       string enc = "none";
			       sscanf( ent, "&%s;", ent );
			       sscanf( ent, "%s:%s", ent, enc );
			       sscanf( ent, "_.%s", ent );
			       switch( enc )
			       {
				 case "none":
				   return data[ ent ];
				 case "int":
				   return (string)(int)data[ ent ];
				 case "float":
				   return (string)(float)data[ ent ];
				 case "string":
				 default:
				   return sprintf("%O", data[ent] );
			       }
			     } );
    string code = p->feed( tmpl )->finish()->read();
    p = 0;			// To avoid trampoline garbage.
    return compile_string( code, xml_file )();
  };

  
  p->xml_tag_syntax( 2 );
  p->add_quote_tag ("!--", "", "--");
  p->add_container( ttag,
		    lambda( Parser.HTML p, mapping m, string c )
		    {
		      tmpl = c;
		    } );
  p->add_container( itag,
		    lambda( Parser.HTML p, mapping m, string c )
		    {
		      string current_tag;
		      mapping row = m;
		      void got_tag( Parser.HTML p, string c )
		      {
			sscanf( c, "<%s>", c );
			if( c[0] == '/' )
			  current_tag = 0;
			else
			  current_tag = c;
		      };

		      void got_data( Parser.HTML p, string c )
		      {
			if( current_tag )
			  if( row[current_tag] )
			    row[current_tag] += html_decode_string(c);
			  else
			    row[current_tag] = html_decode_string(c);
		      };
		       
		      p = Parser.HTML( );
		      p->xml_tag_syntax( 2 );
		      p->add_quote_tag ("!--", "", "--")
			->_set_tag_callback( got_tag )
			->_set_data_callback( got_data )
			->feed( c )
			->finish();
		      data += ({ row });
		      p = 0;	// To avoid trampoline garbage.
		    } )
    ->feed( Stdio.read_file( xml_file ) )
    ->finish();

  p = 0;			// To avoid trampoline garbage.

  if( ident )
  {
    foreach( data, mapping m )
      if( m->ident == ident )
	return apply_template( m );
    return 0;
  }
  return map( data, apply_template );
}

object|array(object) parse_box_xml( string xml_file, string|void ident )
{
  return parse_xml_tmpl( "template", "box", xml_file, ident );
}

int ip_to_int(string ip)
{
  int res;
  foreach(((ip/".") + ({ "0", "0", "0" }))[..3], string num)
    res = (res<<8) | (int)num;
  return res;
}

string http_roxen_config_cookie(string from)
{
  return "RoxenConfig="+http_encode_cookie(from)
    +"; expires=" + http_date (3600*24*365*2 + time (1)) + "; path=/";
}

string http_roxen_id_cookie(void|string unique_id)
{
  return "RoxenUserID=" + (unique_id || roxen->create_unique_id()) + "; expires=" +
    http_date (3600*24*365*2 + time (1)) + "; path=/";
}

protected mapping(string:function(string, RequestID:string)) cookie_callbacks =
  ([]);
protected class CookieChecker(string cookie)
{
  string `()(string path, RequestID id)
  {
    if (!id->real_cookies) {
      id->init_cookies();
    }
    // Note: Access the real_cookies directly to avoid registering callbacks.
    return id->real_cookies[cookie];
  }
  string _sprintf(int c)
  {
    return c == 'O' && sprintf("CookieChecker(%O)", cookie);
  }
}
function(string, RequestID:string) get_cookie_callback(string cookie)
{
  function(string, RequestID:string) cb = cookie_callbacks[cookie];
  if (cb) return cb;
  cb = CookieChecker(cookie);
  return cookie_callbacks[cookie] = cb;
}

protected mapping(string:function(string, RequestID:string)) lang_callbacks = ([ ]);

protected class LangChecker(multiset(string) known_langs, string header,
			    string extra)
{
  string `()(string path, RequestID id)
  {
    string proto_key = "";

    switch (header) {
    case "accept-language":
      //  Make sure the Accept-Language header has been parsed for this request
      PrefLanguages pl = id->misc->pref_languages;
      if (!pl) {
	id->init_pref_languages();
	pl = id->misc->pref_languages;
      }
      proto_key = filter(pl->get_languages(), known_langs) * ",";
      break;

    case "cookie":
      if (!id->real_cookies)
	id->init_cookies();
      
      //  Avoid cookie jar tracking
      if (string cookie_val = id->real_cookies[extra]) {
	if (known_langs[cookie_val])
	  proto_key = cookie_val;
      }
      break;
    }
    
    return proto_key;
  }
  
  string _sprintf(int c)
  {
    return (c == 'O') && sprintf("LangChecker(%O,%O,%O)",
				 indices(known_langs) * "+", header, extra);
  }
}

function(string, RequestID:string) get_lang_vary_cb(multiset(string) known_langs,
						    string header, string extra)
{
  string key = sort(indices(known_langs)) * "+" + "|" + header + "|" + extra;
  return
    lang_callbacks[key] ||
    (lang_callbacks[key] = LangChecker(known_langs, header, extra));
}

//! Return id->remoteaddr.
//!
//! Useful to use with @[RequestID()->register_vary_callback()].
string get_remoteaddr(string ignored, RequestID id)
{
  return id->remoteaddr;
}

// These five functions are questionable, but rather widely used.
string msectos(int t)
{
  if(t<1000) // One sec.
  {
    return sprintf("0.%02d sec", t/10);
  } else if(t<6000) {  // One minute
    return sprintf("%d.%02d sec", t/1000, (t%1000 + 5) / 10);
  } else if(t<3600000) { // One hour
    return sprintf("%d:%02d m:s", t/60000,  (t%60000)/1000);
  }
  return sprintf("%d:%02d h:m", t/3600000, (t%3600000)/60000);
}

string decode_mode(int m)
{
  string s;
  s="";

  if(S_ISLNK(m))  s += "Symbolic link";
  else if(S_ISREG(m))  s += "File";
  else if(S_ISDIR(m))  s += "Dir";
  else if(S_ISSOCK(m)) s += "Socket";
  else if(S_ISFIFO(m)) s += "FIFO";
  else if((m&0xf000)==0xd000) s+="Door";
  else if(S_ISBLK(m))  s += "Device";
  else if(S_ISCHR(m))  s += "Special";
  else s+= "Unknown";

  s+=", ";

  if(S_ISREG(m) || S_ISDIR(m))
  {
    s+="<tt>";
    if(m&S_IRUSR) s+="r"; else s+="-";
    if(m&S_IWUSR) s+="w"; else s+="-";
    if(m&S_IXUSR) s+="x"; else s+="-";

    if(m&S_IRGRP) s+="r"; else s+="-";
    if(m&S_IWGRP) s+="w"; else s+="-";
    if(m&S_IXGRP) s+="x"; else s+="-";

    if(m&S_IROTH) s+="r"; else s+="-";
    if(m&S_IWOTH) s+="w"; else s+="-";
    if(m&S_IXOTH) s+="x"; else s+="-";
    s+="</tt>";
  } else {
    s+="--";
  }
  return s;
}

mapping(string:mixed) add_http_header(mapping(string:mixed) to,
				      string name, string value)
//! Adds a header @[name] with value @[value] to the header style
//! mapping @[to] (which commonly is @tt{id->defines[" _extra_heads"]@})
//! if no header with that value already exist.
//!
//! @note
//! This function doesn't notify the RXML p-code cache, which makes it
//! inappropriate to use for updating @tt{id->defines[" _extra_heads"]@}
//! in RXML tags (which has been its primary use). Use
//! @[RequestID.add_response_header] instead.
{
  if(to[name]) {
    if(arrayp(to[name])) {
      if (search(to[name], value) == -1)
	to[name] += ({ value });
    } else {
      if (to[name] != value)
	to[name] = ({ to[name], value });
    }
  }
  else
    to[name] = value;
  return to;
}

mapping(string:mixed) merge_http_headers (mapping(string:mixed) a,
					  mapping(string:mixed) b)
//! Merges two response header mappings as if @[add_http_header] was
//! called for @[a] with every header in @[b], except that it isn't
//! destructive on @[a].
{
  mapping(string:mixed) res = a ^ b;
  foreach (a & b; string name;) {
    string|array(string) a_val = a[name], b_val = b[name];
    if (a_val == b_val)
      // Shortcut for the string case (usually). This also ensures
      // that same-string values don't become arrays with a single
      // element.
      res[name] = a_val;
    else {
      if (!arrayp (a_val)) a_val = ({a_val});
      if (!arrayp (b_val)) b_val = ({b_val});
      res[name] = a_val | b_val;
    }
  }
  return res;
}

int is_mysql_keyword( string name )
//! Return true if the argument is a mysql keyword.
//! Not in DBManager due to recursive module dependencies.
{
  return (<
      "action", "add", "aggregate", "all", "alter", "after", "and", "as",
      "asc", "avg", "avg_row_length", "auto_increment", "between", "bigint",
      "bit", "binary", "blob", "bool", "both", "by", "cascade", "case",
      "char", "character", "change", "check", "checksum", "column",
      "columns", "comment", "constraint", "create", "cross", "current_date",
      "current_time", "current_timestamp", "data", "database", "databases",
      "date", "datetime", "day", "day_hour", "day_minute", "day_second",
      "dayofmonth", "dayofweek", "dayofyear", "dec", "decimal", "default",
      "delayed", "delay_key_write", "delete", "desc", "describe", "distinct",
      "distinctrow", "double", "drop", "end", "else", "escape", "escaped",
      "enclosed", "enum", "explain", "exists", "fields", "file", "first",
      "float", "float4", "float8", "flush", "foreign", "from", "for", "full",
      "function", "global", "grant", "grants", "group", "having", "heap",
      "high_priority", "hour", "hour_minute", "hour_second", "hosts",
      "identified", "ignore", "in", "index", "infile", "inner", "insert",
      "insert_id", "int", "integer", "interval", "int1", "int2", "int3",
      "int4", "int8", "into", "if", "is", "isam", "join", "key", "keys",
      "kill", "last_insert_id", "leading", "left", "length", "like",
      "lines", "limit", "load", "local", "lock", "logs", "long", "longblob",
      "longtext", "low_priority", "max", "max_rows", "match", "mediumblob",
      "mediumtext", "mediumint", "middleint", "min_rows", "minute",
      "minute_second", "modify", "month", "monthname", "myisam", "natural",
      "numeric", "no", "not", "null", "on", "optimize", "option",
      "optionally", "or", "order", "outer", "outfile", "pack_keys",
      "partial", "password", "precision", "primary", "procedure", "process",
      "processlist", "privileges", "read", "real", "references", "reload",
      "regexp", "rename", "replace", "restrict", "returns", "revoke",
      "rlike", "row", "rows", "second", "select", "set", "show", "shutdown",
      "smallint", "soname", "sql_big_tables", "sql_big_selects",
      "sql_low_priority_updates", "sql_log_off", "sql_log_update",
      "sql_select_limit", "sql_small_result", "sql_big_result",
      "sql_warnings", "straight_join", "starting", "status", "string",
      "table", "tables", "temporary", "terminated", "text", "then", "time",
      "timestamp", "tinyblob", "tinytext", "tinyint", "trailing", "to",
      "type", "use", "using", "unique", "unlock", "unsigned", "update",
      "usage", "values", "varchar", "variables", "varying", "varbinary",
      "with", "write", "when", "where", "year", "year_month", "zerofill",      
  >)[ name ];
}

string short_name(string|Configuration long_name)
//! Given either a long name or a Configuration object, return a short
//! (no longer than 20 characters) identifier.
//!
//! This function also does Unicode normalization and removes all
//! 'non-character' characters from the name. The string is then
//! utf8-encoded.
{
  string id;
  if( objectp( long_name ) )
  {
    if( !long_name->name )
      error("Illegal first argument to short_name.\n"
	    "Expected Configuration object or string\n");
    long_name = long_name->name;
  }

  id = Unicode.split_words_and_normalize( lower_case(long_name) )*"_";
  
  if( strlen( id ) > 20 )
    id = (id[..16]+"_"+hash(id)->digits(36))[..19];

  if( !strlen( id ) )
    id = hash(long_name)->digits(36);

  if( is_mysql_keyword( id ) )
    return "x"+id[..19];

  while( strlen(string_to_utf8( id )) > 20 )
    id = id[..strlen(id)-2];

  return string_to_utf8( id );
}

int _match(string w, array (string) a)
{
  if(!stringp(w)) // Internal request..
    return -1;
  foreach(a, string q)
    if(stringp(q) && strlen(q) && glob(q, w))
      return 1;
}


string canonicalize_http_header (string header)
//! Returns the given http header on the canonical capitalization form
//! as given in RFC 2616. E.g. @expr{"content-type"@} or
//! @expr{"CONTENT-TYPE"@} is returned as @expr{"Content-Type"@}.
//! Returns zero if the given string isn't a known http header.
//!
//! @seealso
//! @[RequestID.add_response_header]
{
  return ([
    // RFC 2616 section 4.5: General Header Fields
    "cache-control":		"Cache-Control",
    "connection":		"Connection",
    "date":			"Date",
    "pragma":			"Pragma",
    "trailer":			"Trailer",
    "transfer-encoding":	"Transfer-Encoding",
    "upgrade":			"Upgrade",
    "via":			"Via",
    "warning":			"Warning",
    // RFC 2616 section 5.3: Request Header Fields
    "accept":			"Accept",
    "accept-charset":		"Accept-Charset",
    "accept-encoding":		"Accept-Encoding",
    "accept-language":		"Accept-Language",
    "authorization":		"Authorization",
    "expect":			"Expect",
    "from":			"From",
    "host":			"Host",
    "if-match":			"If-Match",
    "if-modified-since":	"If-Modified-Since",
    "if-none-match":		"If-None-Match",
    "if-range":			"If-Range",
    "if-unmodified-since":	"If-Unmodified-Since",
    "max-forwards":		"Max-Forwards",
    "proxy-authorization":	"Proxy-Authorization",
    "range":			"Range",
    "referer":			"Referer",
    "te":			"TE",
    "user-agent":		"User-Agent",
    // RFC 2616 section 6.2: Response Header Fields
    "accept-ranges":		"Accept-Ranges",
    "age":			"Age",
    "etag":			"ETag",
    "location":			"Location",
    "proxy-authenticate":	"Proxy-Authenticate",
    "retry-after":		"Retry-After",
    "server":			"Server",
    "vary":			"Vary",
    "www-authenticate":		"WWW-Authenticate",
    // RFC 2616 section 7.1: Entity Header Fields
    "allow":			"Allow",
    "content-encoding":		"Content-Encoding",
    "content-language":		"Content-Language",
    "content-length":		"Content-Length",
    "content-location":		"Content-Location",
    "content-md5":		"Content-MD5",
    "content-range":		"Content-Range",
    "content-type":		"Content-Type",
    "expires":			"Expires",
    "last-modified":		"Last-Modified",
    // The obsolete RFC 2068 defined this header for compatibility (19.7.1.1).
    "keep-alive":		"Keep-Alive",
    // RFC 2965
    "cookie":			"Cookie",
    "cookie2":			"Cookie2",
    "set-cookie2":		"Set-Cookie2",
  ])[lower_case (header)];
}

mapping(string:mixed) http_low_answer( int status_code, string data )
//! Return a result mapping with the specified HTTP status code and
//! data. @[data] is sent as the content of the response and is
//! tagged as text/html.
//!
//! @note
//! The constants in @[Protocols.HTTP] can be used for status codes.
{
  if(!data) data="";
  HTTP_WERR("Return code "+status_code+" ("+data+")");
  return
    ([
      "error" : status_code,
      "data"  : data,
      "len"   : strlen( data ),
      "type"  : "text/html",
      ]);
}

mapping(string:mixed) http_status (int status_code,
				   void|string message, mixed... args)
//! Return a response mapping with the specified HTTP status code and
//! optional message. As opposed to @[http_low_answer], the message is
//! raw text which can be included in more types of responses, e.g.
//! inside multistatus responses in WebDAV. The message may contain
//! line feeds ('\n') and ISO-8859-1 characters in the ranges 32..126
//! and 128..255. Line feeds are converted to spaces if the response
//! format doesn't allow them.
//!
//! If @[args] is given, @[message] is taken as an @[sprintf] style
//! format which is applied to them.
{
  if (message) {
    if (sizeof (args)) message = sprintf (message, @args);
    HTTP_WERR ("Return status " + status_code + " " + message);
    return (["error": status_code, "rettext": message]);
  }
  else {
    HTTP_WERR ("Return status " + status_code);
    return (["error": status_code]);
  }
}

mapping(string:mixed) http_method_not_allowed (
  string allowed_methods, void|string message, mixed... args)
//! Make a HTTP 405 method not allowed response with the required
//! Allow header containing @[allowed_methods], which is a comma
//! separated list of HTTP methods, e.g. @expr{"GET, HEAD"@}.
{
  mapping(string:mixed) response =
    http_status (Protocols.HTTP.HTTP_METHOD_INVALID, message, @args);
  response->extra_heads = (["Allow": allowed_methods]);
  return response;
}

//! Returns a response mapping indicating that the module or script
//! will take over the rest of the handling of the request. This
//! aborts the request chain and leaves you in control for as long as
//! you wish.
//!
//! Typically, you'll want to return the control again by sending a
//! new result mapping to @[RequestID.send_result()], but should you
//! want to glue together request headers and close the socket on your
//! own, you are free to do so. The method @[RequestID.connection()]
//! gives you the Stdio.File object for the current client connection.
  mapping(string:mixed) http_pipe_in_progress()
{
  HTTP_WERR("Pipe in progress");
  return ([ "file":-1, "pipe":1, ]);
}

mapping(string:mixed) http_rxml_answer( string rxml, RequestID id,
					void|Stdio.File file,
					void|string type )
//! Convenience functions to use in Roxen modules. When you just want
//! to return a string of data, with an optional type, this is the
//! easiest way to do it if you don't want to worry about the internal
//! roxen structures.
{
  rxml = 
       ([function(string,RequestID,Stdio.File:string)]id->conf->parse_rxml)
       (rxml, id, file);
  HTTP_WERR("RXML answer ("+(type||"text/html")+")");
  return (["data":rxml,
	   "type":(type||"text/html"),
	   "stat":id->misc->defines[" _stat"],
	   "error":id->misc->defines[" _error"],
	   "rettext":id->misc->defines[" _rettext"],
	   "extra_heads":id->misc->defines[" _extra_heads"],
	   ]);
}


mapping(string:mixed) http_try_again( float delay )
//! Causes the request to be retried in @[delay] seconds.
{
  return ([ "try_again_later":delay ]);
}

protected class Delayer
{
  RequestID id;
  int resumed;

  void resume( )
  {
    if( resumed )
      return;
    remove_call_out( resume );
    resumed = 1;
    if( !id )
      error("Cannot resume request -- connection close\n");
    roxenp()->handle( id->handle_request );
    id = 0; // free the reference.
  }

  void create( RequestID _id, float max_delay )
  {
    id = _id;
    if( max_delay && max_delay > 0.0 )
      call_out( resume, max_delay );
  }
}

array(object|mapping) http_try_resume( RequestID id, float|void max_delay )
//! Returns an object and a return mapping.
//! Call 'retry' in the object to resume the request.
//! Please note that this will cause your callback to be called again.
//! An optional maximum delay time can be specified.
//!
//! @example
//! void first_try( RequestID id )
//! {
//!   if( !id->misc->has_logged_in )
//!   {
//!     [object key, mapping result] = Roxen.http_try_resume( id, 10.0 );
//!     void do_the_work( )
//!     {
//!        id->misc->have_logged_in = "no";
//!        if( connect_to_slow_id_host_and_get_login( id ) )
//!          id->misc->have_logged_in = "yes";
//!        key->resume();
//!     };
//!     thread_create( do_the_work, key );
//!     return result;
//!   }
//! }
{
  Delayer delay = Delayer( id, max_delay );
  return ({delay, ([ "try_again_later":delay ]) });
}

mapping(string:mixed) http_string_answer(string text, string|void type)
//! Generates a result mapping with the given text as the request body
//! with a content type of `type' (or "text/html" if none was given).
{
  HTTP_WERR("String answer ("+(type||"text/html")+")");
  return ([ "data":text, "type":(type||"text/html") ]);
}

mapping(string:mixed) http_file_answer(Stdio.File text,
				       string|void type, void|int len)
//! Generate a result mapping with the given (open) file object as the
//! request body, the content type defaults to text/html if none is
//! given, and the length to the length of the file object.
{
  HTTP_WERR("file answer ("+(type||"text/html")+")");
  return ([ "file":text, "type":(type||"text/html"), "len":len ]);
}

protected constant months = ({ "Jan", "Feb", "Mar", "Apr", "May", "Jun",
			       "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" });
protected constant days = ({ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" });

string log_date(int t) {
  mapping(string:int) lt = localtime(t);
  return(sprintf("%04d-%02d-%02d",
		 1900+lt->year,lt->mon+1, lt->mday));
}
 
string log_time(int t) {
  mapping(string:int) lt = localtime(t);
  return(sprintf("%02d:%02d:%02d",
		 lt->hour, lt->min, lt->sec));
}

// CERN date formatter. Note similar code in LogFormat in roxen.pike.

protected int chd_lt;
protected string chd_lf;

string cern_http_date(int t)
//! Return a date, formated to be used in the common log format
{
  if( t == chd_lt )
    // Interpreter lock assumed here.
    return chd_lf;

  string c;
  mapping(string:int) lt = localtime(t);
  int tzh = lt->timezone/3600;
  if(tzh > 0)
    c="-";
  else {
    tzh = -tzh;
    c="+";
  }

  c = sprintf("%02d/%s/%04d:%02d:%02d:%02d %s%02d00",
	      lt->mday, months[lt->mon], 1900+lt->year,
	      lt->hour, lt->min, lt->sec, c, tzh);

  chd_lt = t;
  // Interpreter lock assumed here.
  chd_lf = c;

  return c;
}

constant http_status_messages = ([
  100:"Continue",
  101:"Switching Protocols",
  102:"Processing",

  200:"OK",
  201:"Created",		// URI follows
  202:"Accepted",
  203:"Non-Authoritative Information",	// Provisional Information
  204:"No Content",
  205:"Reset Content",
  206:"Partial Content",	// Byte Ranges
  207:"Multi-Status",
  226:"IM Used",		// RFC 3229

  300:"Multiple Choices",	// Moved
  301:"Moved Permanently",	// Permanent Relocation
  302:"Found",
  303:"See Other",
  304:"Not Modified",
  305:"Use Proxy",
  // RFC 2616 10.3.7: 306 not used but reserved.
  307:"Temporary Redirect",

  400:"Bad Request",
  401:"Unauthorized",		// Access denied
  402:"Payment Required",
  403:"Forbidden",
  404:"Not Found",		// No such file or directory
  405:"Method Not Allowed",
  406:"Not Acceptable",
  407:"Proxy Authentication Required", // Proxy authorization needed
  408:"Request Timeout",
  409:"Conflict",
  410:"Gone",			// This document is no more. It has gone to meet its creator. It is gone. It will not be back. Give up. I promise. There is no such file or directory.",
  411:"Length Required",
  412:"Precondition Failed",
  413:"Request Entity Too Large",
  414:"Request-URI Too Long",
  415:"Unsupported Media Type",
  416:"Requested Range Not Satisfiable",
  417:"Expectation Failed",
  418:"I'm a teapot",
  // FIXME: What is 419?
  420:"Server temporarily unavailable",
  421:"Server shutting down at operator request",
  422:"Unprocessable Entity",
  423:"Locked",
  424:"Failed Dependency",

  500:"Internal Server Error.",
  501:"Not Implemented",
  502:"Bad Gateway",		// Gateway Timeout
  503:"Service Unavailable",
  504:"Gateway Timeout",
  505:"HTTP Version Not Supported",
  506:"Variant Also Negotiates",
  507:"Insufficient Storage",
]);

string http_status_message (int status_code)
//! Returns the standard message that corresponds to the given HTTP
//! status code.
{
  return http_status_messages[status_code];
}

string http_date( mixed t )
//! Returns a http_date, as specified by the HTTP-protocol standard.
//! This is used for logging as well as the Last-Modified and Time
//! headers in the reply.
{
  mapping(string:int) l = gmtime( (int)t );
  return(sprintf("%s, %02d %s %04d %02d:%02d:%02d GMT",
		 days[l->wday], l->mday, months[l->mon], 1900+l->year,
		 l->hour, l->min, l->sec));
}

string parse_http_response (string response,
			    void|mapping(string:mixed) response_map,
			    void|mapping(string:string) headers,
			    void|int|string on_error)
//! Parses a raw http response and converts it to a response mapping
//! suitable to return from @[RoxenModule.find_file] etc.
//!
//! The charset, if any is found, is used to decode the body. If a
//! charset isn't found in the Content-Type header, some heuristics is
//! used on the body to try to find one.
//!
//! @param response
//!   The raw http response message, starting with formatted headers
//!   that are terminated by an empty line.
//!
//! @param response_map
//!   If this is set, it's filled in as a response mapping. The body
//!   of the response is included in @expr{@[response_map]->data@}.
//!
//! @param headers
//!   If this is set, it's filled in with all the http headers from
//!   the response. The indices are lowercased, but otherwise the
//!   headers aren't processed much (see also @[_Roxen.HeaderParser]).
//!
//! @param on_error
//!   What to do if a parse error occurs. Throws a normal error if
//!   zero, throws an RXML run error if 1, or ignores it and tries to
//!   recover if -1. If it's a string then it's logged in the debug
//!   log with the string inserted to explain the context.
//!
//! @returns
//! Returns the body of the response message, with charset decoded if
//! applicable.
{
  array parsed = Roxen.HeaderParser()->feed (response);
  if (!parsed) {
    string err_msg = "Could not find http headers.\n";
    if (stringp (on_error))
      werror ("Error parsing http response%s: %s",
	      on_error != "" ? " " + on_error : "", err_msg);
    else if (on_error == 0)
      error (err_msg);
    else if (on_error == 1)
      RXML.run_error (err_msg);
    return response;
  }

  mapping(string:string) hdr = parsed[2];
  if (headers)
    foreach (hdr; string name; string val)
      headers[name] = val;

  return low_parse_http_response (hdr, parsed[0], response_map, on_error);
}

string low_parse_http_response (mapping(string:string) headers,
				string body,
				void|mapping(string:mixed) response_map,
				void|int|string on_error,
				void|int(0..1) ignore_unknown_ce)
//! Similar to @[parse_http_response], but takes a http response
//! message that has been split into headers in @[headers] and the
//! message body in @[body].
//!
//! The indices in @[headers] are assumed to be in lower case.
//!
//! @param ignore_unknown_ce
//!   If set, unknown Content-Encoding headers will be ignored and
//!   parsing will continue on the verbatim body data.
{
  string err_msg;

proc: {
    if (response_map) {
      if (string lm = headers["last-modified"])
	// Let's just ignore parse errors in the date.
	response_map->last_modified = parse_since (lm)[0];
    }

    string type, subtype, charset;

    if (string ct = headers["content-type"]) {
      // Use the MIME module to parse the Content-Type header. It
      // doesn't need the data.
      MIME.Message m = MIME.Message ("", (["content-type": ct]), 0, 1);
      type = m->type;
      subtype = m->subtype;
      charset = m->charset;
      if (charset == "us-ascii" && !has_value (lower_case (ct), "us-ascii"))
	// MIME.Message is a bit too "convenient" and defaults to
	// "us-ascii" if no charset is specified.
	charset = 0;
      if (response_map)
	response_map->type = type + "/" + subtype;
    }

    if (string ce = headers["content-encoding"]) {
      switch(lower_case(ce)) {
      case "gzip":
	{
	  Stdio.FakeFile f = Stdio.FakeFile(body, "rb");
	  Gz.File gz = Gz.File(f, "rb");
	  body = gz->read();
	}
	break;
      case "deflate":
	body = Gz.inflate(-15)->inflate(body);
	break;
      default:
	if (!ignore_unknown_ce) {
	  err_msg = sprintf("Content-Encoding %O not supported.\n", ce);
	  break proc;
	}
      }
    }

    if (!charset) {
      // Guess the charset from the content. Adapted from insert#href,
      // insert#cached-href and SiteBuilder.pmod.
      if (type == "text" ||
	  (type == "application" &&
	   (subtype == "xml" || has_prefix (subtype || "", "xml-")))) {

	if (subtype == "html") {
	  Parser.HTML parser = Parser.HTML();
	  parser->case_insensitive_tag(1);
	  parser->lazy_entity_end(1);
	  parser->ignore_unknown(1);
	  parser->match_tag(0);
	  parser->add_quote_tag ("!--", "", "--");
	  parser->add_tag (
	    "meta",
	    lambda (Parser.HTML p, mapping m)
	    {
	      string val = m->content;
	      if(val && m["http-equiv"] &&
		 lower_case(m["http-equiv"]) == "content-type") {
		MIME.Message m =
		  MIME.Message ("", (["content-type": val]), 0, 1);
		charset = m->charset;
		if (charset == "us-ascii" &&
		    !has_value (lower_case (val), "us-ascii"))
		  charset = 0;
		throw (0);	// Done.
	      }
	    });
	  if (mixed err = catch (parser->finish (body))) {
	    err_msg = describe_error (err);
	    break proc;
	  }
	}

	else if (subtype == "xml" || has_prefix (subtype || "", "xml-")) {
	  // Look for BOM, then an xml header. The BOM is stripped off
	  // since we use it to decode the data here.
	  if (sscanf (body, "\xef\xbb\xbf%s", body))
	    charset = "utf-8";
	  else if (sscanf (body, "\xfe\xff%s", body))
	    charset = "utf-16";
	  else if (sscanf (body, "\xff\xfe\x00\x00%s", body))
	    charset = "utf-32le";
	  else if (sscanf (body, "\xff\xfe%s", body))
	    charset = "utf-16le";
	  else if (sscanf (body, "\x00\x00\xfe\xff%s", body))
	    charset = "utf-32";

	  else if (sizeof(body) > 6 &&
		   has_prefix(body, "<?xml") &&
		   Parser.XML.isspace(body[5]) &&
		   sscanf(body, "<?%s?>", string hdr)) {
	    hdr += "?";
	    if (sscanf(lower_case(hdr), "%*sencoding=%s%*[\n\r\t ?]",
		       string xml_enc) == 3)
	      charset = xml_enc - "'" - "\"";
	  }
	}
      }
    }

    // FIXME: Parse away BOM in xml documents also when the charset
    // already is known.

    if (charset) {
      Locale.Charset.Decoder decoder;
      if (mixed err = catch (decoder = Locale.Charset.decoder (charset))) {
	err_msg = sprintf ("Unrecognized charset %q.\n", charset);
	break proc;
      }
      if (mixed err = catch (body = decoder->feed (body)->drain())) {
	if (objectp (err) && err->is_charset_decode_error) {
	  err_msg = describe_error (err);
	  break proc;
	}
	throw (err);
      }
    }

    if (response_map)
      response_map->data = body;

    return body;
  }

  // Get here on error.
  if (stringp (on_error))
    werror ("Error parsing http response%s: %s",
	    on_error != "" ? " " + on_error : "", err_msg);
  else if (on_error == 0)
    error (err_msg);
  else if (on_error == 1)
    RXML.run_error ("Error parsing http response: " + err_msg);

  return body;
}

//! Returns a timestamp formatted according to ISO 8601 Date and Time
//! RFC 2518 23.2. No fraction, UTC only.
string iso8601_date_time(int ts, int|void ns)
{
  mapping(string:int) gmt = gmtime(ts);
  if (zero_type(ns)) {
    return sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ",
		   1900 + gmt->year, gmt->mon+1, gmt->mday,
		   gmt->hour, gmt->min, gmt->sec);
  }
  return sprintf("%04d-%02d-%02dT%02d:%02d:%02d.%09dZ",
		 1900 + gmt->year, gmt->mon+1, gmt->mday,
		 gmt->hour, gmt->min, gmt->sec, ns);
}

#if !defined (MODULE_DEBUG) ||						\
  defined (ENABLE_INHERENTLY_BROKEN_HTTP_ENCODE_STRING_FUNCTION)
// Since http_encode_string is broken by design we don't define it in
// module debug mode, so that modules still using it can be detected
// easily during compilation. If you for some reason choose to
// disregard the STRONG deprecation of this function, then you can use
// the other define above to always enable it.
string http_encode_string(string f)
//! Encode dangerous characters in a string so that it can be used as
//! a URL. Specifically, nul, space, tab, newline, linefeed, %, ' and
//! " are quoted.
//!
//! @note
//! This function is STRONGLY deprecated since using it almost
//! invariably leads to incorrect encoding: It doesn't encode URI
//! special chars like "/", ":", "?" etc, presumably with the
//! intention to be used on an entire URI string. Still, since it
//! encodes "%", that URI string can't contain any prior encoded chars
//! from the URI component strings. Thus, the result is that "%"
//! easily gets incorrectly double-encoded with this function.
//!
//! Either use @[http_encode_url] to encode the URI component strings
//! before they are pasted together to the complete URI, or use
//! @[http_encode_invalids] on the complete URI to only encode any
//! chars that can't occur raw in the HTTP protocol.
{
  return replace(f, ({ "\000", " ", "\t", "\n", "\r", "%", "'", "\"" }),
		 ({"%00", "%20", "%09", "%0A", "%0D", "%25", "%27", "%22"}));
}
#endif

string http_encode_invalids (string f)
//! Encode dangerous chars to be included as a URL in an HTTP message
//! or header field. This includes control chars, space and the quote
//! chars @expr{'@} and @expr{"@}. Note that chars allowed in a quoted
//! string (RFC 2616 section 2.2) are not encoded. This function may
//! be used on a complete URI since it doesn't encode any URI special
//! chars, including the escape char @expr{%@}.
//!
//! @note
//! Eight bit chars and wider are encoded using UTF-8 followed by http
//! escaping, as mandated by RFC 3987, section 3.1 and appendix B.2 in
//! the HTML 4.01 standard
//! (http://www.w3.org/TR/html4/appendix/notes.html#non-ascii-chars).
//! (It should work regardless of the charset used in the XML document
//! the URL might be inserted into.)
//!
//! @seealso
//! @[http_encode_url]
{
  return replace (
    string_to_utf8 (f), ({
      // Encode all chars outside the set of reserved characters
      // (RFC 3986, section 2.2) and unreserved chars (section 2.3).
      //
      // Control chars
      "\000", "\001", "\002", "\003", "\004", "\005", "\006", "\007",
      "\010", "\011", "\012", "\013", "\014", "\015", "\016", "\017",
      "\020", "\021", "\022", "\023", "\024", "\025", "\026", "\027",
      "\030", "\031", "\032", "\033", "\034", "\035", "\036", "\037",
      "\177",
      // Others
      " ", "\"",
      // Encoded by legacy (presumably since it's used to delimit
      // attributes in xml). The single quote is valid but may be
      // escaped without changing its meaning in URI's according to
      // RFC 2396 section 2.3. FIXME: In the successor RFC 3986 it is
      // however part of the reserved set and ought therefore not be
      // encoded.
      "'",
      // FIXME: The following chars are invalid according to RFC 3986,
      // but can we add them without compatibility woes?
      //"<", ">", "\\", "^", "`", "{", "|", "}",
      // All eight bit chars (this is fast with the current replace()
      // implementation).
      "\200", "\201", "\202", "\203", "\204", "\205", "\206", "\207",
      "\210", "\211", "\212", "\213", "\214", "\215", "\216", "\217",
      "\220", "\221", "\222", "\223", "\224", "\225", "\226", "\227",
      "\230", "\231", "\232", "\233", "\234", "\235", "\236", "\237",
      "\240", "\241", "\242", "\243", "\244", "\245", "\246", "\247",
      "\250", "\251", "\252", "\253", "\254", "\255", "\256", "\257",
      "\260", "\261", "\262", "\263", "\264", "\265", "\266", "\267",
      "\270", "\271", "\272", "\273", "\274", "\275", "\276", "\277",
      "\300", "\301", "\302", "\303", "\304", "\305", "\306", "\307",
      "\310", "\311", "\312", "\313", "\314", "\315", "\316", "\317",
      "\320", "\321", "\322", "\323", "\324", "\325", "\326", "\327",
      "\330", "\331", "\332", "\333", "\334", "\335", "\336", "\337",
      "\340", "\341", "\342", "\343", "\344", "\345", "\346", "\347",
      "\350", "\351", "\352", "\353", "\354", "\355", "\356", "\357",
      "\360", "\361", "\362", "\363", "\364", "\365", "\366", "\367",
      "\370", "\371", "\372", "\373", "\374", "\375", "\376", "\377",
    }),
    ({
      "%00", "%01", "%02", "%03", "%04", "%05", "%06", "%07",
      "%08", "%09", "%0A", "%0B", "%0C", "%0D", "%0E", "%0F",
      "%10", "%11", "%12", "%13", "%14", "%15", "%16", "%17",
      "%18", "%19", "%1A", "%1B", "%1C", "%1D", "%1E", "%1F",
      "%7F",
      "%20", "%22",
      "%27",
      "%80", "%81", "%82", "%83", "%84", "%85", "%86", "%87",
      "%88", "%89", "%8A", "%8B", "%8C", "%8D", "%8E", "%8F",
      "%90", "%91", "%92", "%93", "%94", "%95", "%96", "%97",
      "%98", "%99", "%9A", "%9B", "%9C", "%9D", "%9E", "%9F",
      "%A0", "%A1", "%A2", "%A3", "%A4", "%A5", "%A6", "%A7",
      "%A8", "%A9", "%AA", "%AB", "%AC", "%AD", "%AE", "%AF",
      "%B0", "%B1", "%B2", "%B3", "%B4", "%B5", "%B6", "%B7",
      "%B8", "%B9", "%BA", "%BB", "%BC", "%BD", "%BE", "%BF",
      "%C0", "%C1", "%C2", "%C3", "%C4", "%C5", "%C6", "%C7",
      "%C8", "%C9", "%CA", "%CB", "%CC", "%CD", "%CE", "%CF",
      "%D0", "%D1", "%D2", "%D3", "%D4", "%D5", "%D6", "%D7",
      "%D8", "%D9", "%DA", "%DB", "%DC", "%DD", "%DE", "%DF",
      "%E0", "%E1", "%E2", "%E3", "%E4", "%E5", "%E6", "%E7",
      "%E8", "%E9", "%EA", "%EB", "%EC", "%ED", "%EE", "%EF",
      "%F0", "%F1", "%F2", "%F3", "%F4", "%F5", "%F6", "%F7",
      "%F8", "%F9", "%FA", "%FB", "%FC", "%FD", "%FE", "%FF",
    }));
}

string http_encode_cookie(string f)
//! Encode dangerous characters in a string so that it can be used as
//! the value string or name string in a cookie.
//!
//! @note
//! This encodes with the same kind of %-escapes as
//! @[http_encode_url], and that isn't an encoding specified by the
//! cookie RFC 2965. It works because there is a nonstandard decoding
//! of %-escapes in the Roxen HTTP protocol module.
{
  // FIXME: There are numerous invalid chars that this doesn't encode,
  // e.g. 8 bit and wide chars.
  return replace(
    f, ({
      "\000", "\001", "\002", "\003", "\004", "\005", "\006", "\007",
      "\010", "\011", "\012", "\013", "\014", "\015", "\016", "\017",
      "\020", "\021", "\022", "\023", "\024", "\025", "\026", "\027",
      "\030", "\031", "\032", "\033", "\034", "\035", "\036", "\037",
      "\177",
      "=", ",", ";", "%",
    }), ({
      "%00", "%01", "%02", "%03", "%04", "%05", "%06", "%07",
      "%08", "%09", "%0A", "%0B", "%0C", "%0D", "%0E", "%0F",
      "%10", "%11", "%12", "%13", "%14", "%15", "%16", "%17",
      "%18", "%19", "%1A", "%1B", "%1C", "%1D", "%1E", "%1F",
      "%7F",
      "%3D", "%2C", "%3B", "%25",
    }));
}

string http_encode_url (string f)
//! Encode any string to be used as a component part in a URI. This
//! means that all URI reserved and excluded characters are escaped,
//! i.e. everything except @expr{A-Z@}, @expr{a-z@}, @expr{0-9@},
//! @expr{-@}, @expr{.@}, @expr{_@}, and @expr{~@} (see RFC 3986
//! section 2.3).
//!
//! @note
//! Eight bit chars and wider are encoded using UTF-8 followed by http
//! escaping, as mandated by RFC 3987, section 3.1 and appendix B.2 in
//! the HTML 4.01 standard
//! (http://www.w3.org/TR/html4/appendix/notes.html#non-ascii-chars).
//! (It should work regardless of the charset used in the XML document
//! the URL might be inserted into.)
//!
//! @seealso
//! @[http_encode_invalids]
{
  return replace (
    string_to_utf8 (f), ({
      // Control chars
      "\000", "\001", "\002", "\003", "\004", "\005", "\006", "\007",
      "\010", "\011", "\012", "\013", "\014", "\015", "\016", "\017",
      "\020", "\021", "\022", "\023", "\024", "\025", "\026", "\027",
      "\030", "\031", "\032", "\033", "\034", "\035", "\036", "\037",
      "\177",
      // RFC 3986, section 2.2, gen-delims
      ":", "/", "?", "#", "[", "]", "@",
      // RFC 3986, section 2.2, sub-delims
      "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "=",
      // Others outside the unreserved chars (RFC 3986, section 2.2)
      " ", "\"", "%", "<", ">", "\\", "^", "`", "{", "|", "}",
      // Compat note: "!", "(", ")" and "*" were not encoded in 4.5
      // and earlier since they were part of the unreserved set in the
      // superseded URI RFC 2396.
      // All eight bit chars (this is fast with the current replace()
      // implementation).
      "\200", "\201", "\202", "\203", "\204", "\205", "\206", "\207",
      "\210", "\211", "\212", "\213", "\214", "\215", "\216", "\217",
      "\220", "\221", "\222", "\223", "\224", "\225", "\226", "\227",
      "\230", "\231", "\232", "\233", "\234", "\235", "\236", "\237",
      "\240", "\241", "\242", "\243", "\244", "\245", "\246", "\247",
      "\250", "\251", "\252", "\253", "\254", "\255", "\256", "\257",
      "\260", "\261", "\262", "\263", "\264", "\265", "\266", "\267",
      "\270", "\271", "\272", "\273", "\274", "\275", "\276", "\277",
      "\300", "\301", "\302", "\303", "\304", "\305", "\306", "\307",
      "\310", "\311", "\312", "\313", "\314", "\315", "\316", "\317",
      "\320", "\321", "\322", "\323", "\324", "\325", "\326", "\327",
      "\330", "\331", "\332", "\333", "\334", "\335", "\336", "\337",
      "\340", "\341", "\342", "\343", "\344", "\345", "\346", "\347",
      "\350", "\351", "\352", "\353", "\354", "\355", "\356", "\357",
      "\360", "\361", "\362", "\363", "\364", "\365", "\366", "\367",
      "\370", "\371", "\372", "\373", "\374", "\375", "\376", "\377",
    }),
    ({
      "%00", "%01", "%02", "%03", "%04", "%05", "%06", "%07",
      "%08", "%09", "%0A", "%0B", "%0C", "%0D", "%0E", "%0F",
      "%10", "%11", "%12", "%13", "%14", "%15", "%16", "%17",
      "%18", "%19", "%1A", "%1B", "%1C", "%1D", "%1E", "%1F",
      "%7F",
      "%3A", "%2F", "%3F", "%23", "%5B", "%5D", "%40",
      "%21","%24","%26","%27","%28","%29","%2A","%2B","%2C","%3B","%3D",
      "%20","%22","%25","%3C","%3E","%5C","%5E","%60","%7B","%7C","%7D",
      "%80", "%81", "%82", "%83", "%84", "%85", "%86", "%87",
      "%88", "%89", "%8A", "%8B", "%8C", "%8D", "%8E", "%8F",
      "%90", "%91", "%92", "%93", "%94", "%95", "%96", "%97",
      "%98", "%99", "%9A", "%9B", "%9C", "%9D", "%9E", "%9F",
      "%A0", "%A1", "%A2", "%A3", "%A4", "%A5", "%A6", "%A7",
      "%A8", "%A9", "%AA", "%AB", "%AC", "%AD", "%AE", "%AF",
      "%B0", "%B1", "%B2", "%B3", "%B4", "%B5", "%B6", "%B7",
      "%B8", "%B9", "%BA", "%BB", "%BC", "%BD", "%BE", "%BF",
      "%C0", "%C1", "%C2", "%C3", "%C4", "%C5", "%C6", "%C7",
      "%C8", "%C9", "%CA", "%CB", "%CC", "%CD", "%CE", "%CF",
      "%D0", "%D1", "%D2", "%D3", "%D4", "%D5", "%D6", "%D7",
      "%D8", "%D9", "%DA", "%DB", "%DC", "%DD", "%DE", "%DF",
      "%E0", "%E1", "%E2", "%E3", "%E4", "%E5", "%E6", "%E7",
      "%E8", "%E9", "%EA", "%EB", "%EC", "%ED", "%EE", "%EF",
      "%F0", "%F1", "%F2", "%F3", "%F4", "%F5", "%F6", "%F7",
      "%F8", "%F9", "%FA", "%FB", "%FC", "%FD", "%FE", "%FF",
    }));
}

//! Compatibility alias for @[http_encode_url].
string correctly_http_encode_url(string f) {
  return http_encode_url (f);
}

string add_pre_state( string url, multiset state )
//! Adds the provided states as prestates to the provided url.
{
#ifdef MODULE_DEBUG
  if(!url)
    error("URL needed for add_pre_state()\n");
#endif
  if(!state || !sizeof(state))
    return url;
  string base;
  if (sscanf (url, "%s://%[^/]%s", base, string host, url) == 3)
    base += "://" + host;
  else
    base = "";
  if(strlen(url)>5 && (url[1] == '(' || url[1] == '<'))
    return base + url;
  return base + "/(" + sort(indices(state)) * "," + ")" + url ;
}

string make_absolute_url (string url, RequestID|void id,
			  multiset|void prestates, mapping|void variables)
//! Returns an absolute URL built from the components: If @[url] is a
//! virtual (possibly relative) path, the current @[RequestID] object
//! must be supplied in @[id] to resolve the absolute URL.
//!
//! If no @[prestates] are provided, the current prestates in @[id]
//! are added to the URL, provided @[url] is a local absolute or
//! relative URL.
//!
//! If @[variables] is given it's a mapping containing variables that
//! should be appended to the URL. Each index is a variable name and
//! the value can be a string or an array, in which case a separate
//! variable binding is added for each string in the array. That means
//! that e.g. @[RequestID.real_variables] can be used as @[variables].
//!
//! @[url] is encoded using @[http_encode_invalids] so it may contain
//! eight bit chars and wider. All variable names and values in
//! @[variables] are thoroughly encoded using @[http_encode_url] so
//! they should not be encoded in any way to begin with.
{
  // If the URL is a local relative URL we make it absolute.
  url = fix_relative(url, id);
  
  // Add protocol and host to local absolute URLs.
  if (has_prefix (url, "/")) {
    if(id) {
      Standards.URI uri = Standards.URI(id->url_base());

      // Handle proxies
      string xf_proto = id->request_headers["x-forwarded-proto"];
      string xf_host = id->request_headers["x-forwarded-host"];

      if (xf_proto && xf_host) {
	uri = Standards.URI(xf_proto + "://" + xf_host + uri->path);
      }
      else if (xf_host) {
	uri = Standards.URI(uri->scheme + "://" + xf_host + uri->path);
      }
      else if (xf_proto) {
	uri = Standards.URI(xf_proto + "://" + uri->host + ":" + uri->port + uri->path);
      }

      url = (string)uri + url[1..];
      if (!prestates) prestates = id->prestate;
    }
    else {
      // Ok, no domain present in the URL and no ID object given.
      // Perhaps one should dare throw an error here, but since most
      // UA can handle the redirect it is nicer no to.
    }
  }

  if(prestates && sizeof(prestates))
    url = add_pre_state (url, prestates);

  if( String.width( url )>8 && !has_value( url, "?" ) )
    url += "?magic_roxen_automatic_charset_variable="+
      magic_charset_variable_value;

  url = http_encode_invalids (url);
  if (variables) {
    string concat_char = has_value (url, "?") ? "&" : "?";
    foreach (indices (variables), string var) {
      var = http_encode_url (var);
      mixed val = variables[var];
      if (stringp (val)) {
	url += concat_char + var + "=" + http_encode_url (val);
	concat_char = "&";
      }
      else if (arrayp (val))
	foreach (val, mixed part)
	  if (stringp (part)) {
	    url += concat_char + var + "=" + http_encode_url (part);
	    concat_char = "&";
	  }
    }
  }

  return url;
}

mapping http_redirect( string url, RequestID|void id, multiset|void prestates,
		       mapping|void variables, void|int http_code)
//! Returns a http-redirect message to the specified URL. The absolute
//! URL that is required for the @expr{Location@} header is built from
//! the given components using @[make_absolute_url]. See that function
//! for details.
//!
//! If @[http_code] is nonzero, it specifies the http status code to
//! use in the response. It's @[Protocols.HTTP.HTTP_FOUND] (i.e. 302)
//! by default.
{
  // If we don't get any URL we don't know what to do.
  // But we do!  /per
  if(!url)
    url = "";

  url = make_absolute_url (url, id, prestates, variables);

  HTTP_WERR("Redirect -> "+url);

  return http_status( http_code || Protocols.HTTP.HTTP_FOUND,
		      "Redirect to " + html_encode_string(url))
    + ([ "extra_heads":([ "Location":url ]) ]);
}

mapping http_stream(Stdio.File from)
//! Returns a result mapping where the data returned to the client
//! will be streamed raw from the given Stdio.File object, instead of
//! being packaged by roxen. In other words, it's entirely up to you
//! to make sure what you send is HTTP data.
{
  return ([ "raw":1, "file":from, "len":-1, ]);
}

mapping(string:mixed) http_digest_required(mapping(string:string) challenge,
					   string|void message)
//! Generates a result mapping that instructs the browser to
//! authenticate the user using Digest authentication (see RFC 2617
//! section 3).
//!
//! The optional message is the message body that the client typically
//! shows the user if he or she decides to abort the authentication
//! request.
{
  if(!message)
    message = "<h1>Authentication failed.\n</h1>";
  HTTP_WERR(sprintf("Auth required (%O)", challenge));
  string digest_challenge = "";
  foreach(challenge; string key; string val) {
    // FIXME: This doesn't work with all Digest directives. E.g. the
    // algorithm gets incorrectly quoted.
    digest_challenge += sprintf(" %s=%O", key, val);
  }
  return http_low_answer(401, message)
    + ([ "extra_heads":([ "WWW-Authenticate":"Digest"+digest_challenge,]),]);
}

mapping(string:mixed) http_auth_required(string realm, string|void message,
					 void|RequestID id)
//! Generates a result mapping that instructs the browser to
//! authenticate the user using Basic authentication (see RFC 2617
//! section 2). @[realm] is the name of the realm on the server, which
//! will typically end up in the browser's prompt for a name and
//! password (e.g. "Enter username for @i{realm@} at @i{hostname@}:").
//!
//! The optional message is the message body that the client typically
//! shows the user if he or she decides to abort the authentication
//! request.
{
  HTTP_WERR("Auth required ("+realm+")");
  if (id) {
    return id->conf->auth_failed_file( id, message )
      + ([ "extra_heads":([ "WWW-Authenticate":
			    sprintf ("Basic realm=%O", realm)])]);
  }
  if(!message)
    message = "<h1>Authentication failed.</h1>";
  return http_low_answer(401, message)
    + ([ "extra_heads":([ "WWW-Authenticate":
			  sprintf ("Basic realm=%O", realm)])]);
}

mapping(string:mixed) http_proxy_auth_required(string realm,
					       void|string message)
//! Similar to @[http_auth_required], but returns a 407
//! Proxy-Authenticate header (see RFC 2616 section 14.33).
{
  if(!message)
    message = "<h1>Proxy authentication failed.</h1>";
  return http_low_answer(407, message)
    + ([ "extra_heads":([ "Proxy-Authenticate":
			  sprintf ("Basic realm=%O", realm)])]);
}


// --- From the old 'roxenlib' file -------------------------------

string extract_query(string from)
{
  if(!from) return "";
  if(sscanf(from, "%*s?%s%*[ \t\n]", from))
    return (from/"\r")[0];
  return "";
}

protected string mk_env_var_name(string name)
{
  name = replace(name, " ", "_");
  string res = "";
  do {
    string ok_part="";
    sscanf(name, "%[A-Za-z0-9_]%s", ok_part, name);
    res += ok_part;
    if (sizeof(name)) {
      res += "_";
      name = name[1..];
    }
  } while (sizeof(name));
  return res;
}

mapping build_env_vars(string f, RequestID id, string path_info)
//! Generate a mapping with environment variables suitable for use
//! with CGI-scripts or SSI scripts etc.
//!
//! @mapping
//!   @member string REQUEST_URI
//!     URI requested by the user.
//!   @member string REDIRECT_URL
//!     Target of the first internal redirect.
//!   @member string INDEX
//!   @member string SCRIPT_NAME
//!   @member string PATH_INFO
//!   @member string PATH_TRANSLATED
//!   @member string DOCUMENT_NAME
//!   @member string DOCUMENT_URI
//!   @member string LAST_MODIFIED
//!   @member string SCRIPT_FILENAME
//!   @member string DOCUMENT_ROOT
//!   @member string HTTP_HOST
//!   @member string HTTP_PROXY_CONNECTION
//!   @member string HTTP_ACCEPT
//!   @member string HTTP_COOKIE
//!   @member string HTTP_PRAGMA
//!   @member string HTTP_CONNECTION
//!   @member string HTTP_USER_AGENT
//!   @member string HTTP_REFERER
//!   @member string REMOTE_ADDR
//!   @member string REMOTE_HOST
//!   @member string REMOTE_PORT
//!   @member string QUERY_STRING
//!   @member string REMOTE_USER
//!   @member string ROXEN_AUTHENTICATED
//!   @member string CONTENT_TYPE
//!   @member string CONTENT_LENGTH
//!   @member string REQUEST_METHOD
//!   @member string SERVER_PORT
//! @endmapping
{
  string addr=id->remoteaddr || "Internal";
  mapping(string:string) new = ([]);

  if(id->query && strlen(id->query))
    new->INDEX=id->query;

  if(path_info && strlen(path_info))
  {
    if(path_info[0] != '/')
      path_info = "/" + path_info;

    // Kludge
    if ( ([mapping(string:mixed)]id->misc)->path_info == path_info ) {
      // Already extracted
      new["SCRIPT_NAME"]=id->not_query;
    } else {
      new["SCRIPT_NAME"]=
	id->not_query[0..strlen([string]id->not_query)-strlen(path_info)-1];
    }
    new["PATH_INFO"]=path_info;


    // FIXME: Consider looping over the splitted path.
    string trailer = "";
    while(1)
    {
      // Fix PATH_TRANSLATED correctly.
      string translated_base = id->conf->real_file(path_info, id);
      if (translated_base)
      {
	new["PATH_TRANSLATED"] = combine_path_unix(translated_base, trailer);
	break;
      }
      array(string) tmp = path_info/"/" - ({""});
      if(!sizeof(tmp))
	break;
      path_info = "/" + (tmp[..sizeof(tmp)-2]) * "/";
      trailer = tmp[-1] + "/" + trailer;
    }
  } else
    new["SCRIPT_NAME"]=id->not_query;

  // Find the original request.
  RequestID tmpid = id;
  RequestID previd;
  while(tmpid->misc->orig) {
    // internal get
    tmpid = (previd = tmpid)->misc->orig;
  }

  // The original URL.
  new["REQUEST_URI"] =
    tmpid->misc->redirected_raw_url || tmpid->raw_url;

  if(tmpid->misc->is_redirected || previd) {
    // Destination of the first internal redirect.
    if (tmpid->misc->redirected_to) {
      new["REDIRECT_URL"] =
	Roxen.http_encode_invalids(tmpid->misc->redirected_to);
    } else if (previd) {
      new["REDIRECT_URL"] = previd->raw_url;
    }
    new["REDIRECT_STATUS"] = "200";
  }

  // Begin "SSI" vars.
  array(string) tmps;
  if(sizeof(tmps = tmpid->not_query/"/" - ({""})))
    new["DOCUMENT_NAME"]=tmps[-1];

  new["DOCUMENT_URI"]= tmpid->not_query;

  Stat tmpi;
  string real_file=tmpid->conf->real_file(tmpid->not_query||"", tmpid);
  if (real_file) {
    if(stringp(real_file)) {
      if ((tmpi = file_stat(real_file)) &&
	  sizeof(tmpi)) {
	new["LAST_MODIFIED"]=http_date(tmpi[3]);
      }
    } else {
      // Extra paranoia.
      report_error(sprintf("real_file(%O, %O) returned %O\n",
			   tmpid->not_query||"", tmpid, real_file));
    }
  }

  // End SSI vars.


  if(string tmp = id->conf->real_file(new["SCRIPT_NAME"], id))
    new["SCRIPT_FILENAME"] = tmp;

  if(string tmp = id->conf->real_file("/", id))
    new["DOCUMENT_ROOT"] = tmp;

  if(!new["PATH_TRANSLATED"])
    m_delete(new, "PATH_TRANSLATED");
  else if(new["PATH_INFO"][-1] != '/' && new["PATH_TRANSLATED"][-1] == '/')
    new["PATH_TRANSLATED"] =
      new["PATH_TRANSLATED"][0..strlen(new["PATH_TRANSLATED"])-2];

  // HTTP_ style variables:

  mapping hdrs;

  if ((hdrs = id->request_headers)) {
    foreach(indices(hdrs) - ({ "authorization", "proxy-authorization",
			       "security-scheme", }), string h) {
      string hh = "HTTP_" + replace(upper_case(h),
				    ({ " ", "-", "\0", "=" }),
				    ({ "_", "_", "", "_" }));

      new[mk_env_var_name(hh)] = replace(hdrs[h], ({ "\0" }), ({ "" }));
    }
    if (!new["HTTP_HOST"]) {
      if(objectp(id->my_fd) && id->my_fd->query_address(1))
	new["HTTP_HOST"] = replace(id->my_fd->query_address(1)," ",":");
    }
  } else {
    if(id->misc->host)
      new["HTTP_HOST"]=id->misc->host;
    else if(objectp(id->my_fd) && id->my_fd->query_address(1))
      new["HTTP_HOST"]=replace(id->my_fd->query_address(1)," ",":");
    if(id->misc["proxy-connection"])
      new["HTTP_PROXY_CONNECTION"]=id->misc["proxy-connection"];
    if(id->misc->accept) {
      if (arrayp(id->misc->accept)) {
	new["HTTP_ACCEPT"]=id->misc->accept*", ";
      } else {
	new["HTTP_ACCEPT"]=(string)id->misc->accept;
      }
    }

    if(id->misc->cookies)
      new["HTTP_COOKIE"] = id->misc->cookies;

    if(sizeof(id->pragma))
      new["HTTP_PRAGMA"]=indices(id->pragma)*", ";

    if(stringp(id->misc->connection))
      new["HTTP_CONNECTION"]=id->misc->connection;

    new["HTTP_USER_AGENT"] = id->client*" ";

    if(id->referer && sizeof(id->referer))
      new["HTTP_REFERER"] = id->referer*"";
  }

  new["REMOTE_ADDR"]=addr;

  if(roxen->quick_ip_to_host(addr) != addr)
    new["REMOTE_HOST"]=roxen->quick_ip_to_host(addr);

  catch {
    if(id->my_fd)
      new["REMOTE_PORT"] = (id->my_fd->query_address()/" ")[1];
  };

  if (id->query && sizeof(id->query)) {
    new["QUERY_STRING"] = id->query;
  }

  if(id->realauth)
    new["REMOTE_USER"] = (id->realauth / ":")[0];
  if( User u = id->conf->authenticate( id ) )
    new["ROXEN_AUTHENTICATED"] = u->name();
  // User is valid with the Roxen userdb.

  if(id->data && strlen(id->data))
  {
    if(id->misc["content-type"])
      new["CONTENT_TYPE"]=id->misc["content-type"];
    else
      new["CONTENT_TYPE"]="application/x-www-form-urlencoded";
    new["CONTENT_LENGTH"]=(string)strlen(id->data);
  }

  if(id->query && strlen(id->query))
    new["INDEX"]=id->query;

  new["REQUEST_METHOD"]=id->method||"GET";
  new["SERVER_PORT"] = id->my_fd?
    ((id->my_fd->query_address(1)||"foo unknown")/" ")[1]: "Internal";

  // Protect against execution of arbitrary code in broken bash.
  foreach(new; string e; string v) {
    if (has_prefix(v, "() {")) {
      report_warning("ENV: Function definition in environment variable:\n"
		     "ENV: %O=%O\n",
		     e, v);
      new[e] = " " + v;
    }
  }

  return new;
}

mapping build_roxen_env_vars(RequestID id)
//! Generate a mapping with additional environment variables suitable
//! for use with CGI-scripts or SSI scripts etc. These variables are
//! roxen extensions and not defined in any standard document.
//! Specifically:
//! @pre{
//! For each cookie:          COOKIE_cookiename=cookievalue
//! For each variable:        VAR_variablename=variablevalue
//!                           (Where the null character is encoded as "#")
//! For each variable:        QUERY_variablename=variablevalue
//!                           (Where the null character is encoded as " ")
//! For each 'prestate':      PRESTATE_x=true
//! For each 'config':        CONFIG_x=true
//! For each 'supports' flag: SUPPORTS_x=true
//! @}
//!
//! @mapping
//!   @member string ROXEN_USER_ID
//!     The unique ID for that client, if available.
//!   @member string COOKIES
//!     A space delimitered list of all the cookies names.
//!   @member string CONFIGS
//!     A space delimitered list of all config flags.
//!   @member string VARIABLES
//!     A space delimitered list of all variable names.
//!   @member string PRESTATES
//!     A space delimitered list of all prestates.
//!   @member string SUPPORTS
//!     A space delimitered list of all support flags.
//! @endmapping
{
  mapping(string:string) new = ([]);
  string tmp;

  if(id->cookies->RoxenUserID)
    new["ROXEN_USER_ID"]=id->cookies->RoxenUserID;

  new["COOKIES"] = "";
  foreach(indices(id->cookies), tmp)
    {
      new["COOKIE_"+mk_env_var_name(tmp)] = id->cookies[tmp];
      new["COOKIES"]+= mk_env_var_name(tmp)+" ";
    }

  foreach(indices(id->config), tmp)
    {
      tmp = mk_env_var_name(tmp);
      new["CONFIG_"+tmp]="true";
      if(new["CONFIGS"])
	new["CONFIGS"] += " " + tmp;
      else
	new["CONFIGS"] = tmp;
    }

  foreach(indices(id->variables), tmp)
  {
    string name = mk_env_var_name(tmp);
    if (mixed value = id->variables[tmp])
      if (!catch (value = (string) value) && (sizeof(value) < 8192)) {
	// Some shells/OS's don't like LARGE environment variables
	new["QUERY_"+name] = replace(value,"\000"," ");
	new["VAR_"+name] = replace(value,"\000","#");
      }
    // Is it correct to record the names for variables with no values here? /mast
    if(new["VARIABLES"])
      new["VARIABLES"]+= " " + name;
    else
      new["VARIABLES"]= name;
  }

  foreach(indices(id->prestate), tmp)
  {
    tmp = mk_env_var_name(tmp);
    new["PRESTATE_"+tmp]="true";
    if(new["PRESTATES"])
      new["PRESTATES"] += " " + tmp;
    else
      new["PRESTATES"] = tmp;
  }

  foreach(indices(id->supports), tmp)
  {
    tmp = mk_env_var_name(tmp-",");
    new["SUPPORTS_"+tmp]="true";
    if (new["SUPPORTS"])
      new["SUPPORTS"] += " " + tmp;
    else
      new["SUPPORTS"] = tmp;
  }

  // Protect against execution of arbitrary code in broken bash.
  foreach(new; string e; string v) {
    if (has_prefix(v, "() {")) {
      report_warning("ENV: Function definition in environment variable:\n"
		     "ENV: %O=%O\n",
		     e, v);
      new[e] = " " + v;
    }
  }

  return new;
}

string strip_config(string from)
//! Remove all 'config' data from the given (local) URL.
{
  sscanf(from, "/<%*s>%s", from);
  return from;
}

string strip_prestate(string from)
//! Remove all 'prestate' data from the given (local) URL.
{
  sscanf(from, "/(%*s)%s", from);
  return from;
}

string parse_rxml(string what, RequestID id )
//! Parse the given string as RXML and return the result. This
//! function inherits the current RXML evaluation context if there is
//! any, otherwise a new context is created.
//!
//! @note
//! Try to avoid using this function to parse recursively; the RXML
//! module provides several ways to accomplish that. If there's code
//! that recurses directly then several RXML features, like p-code
//! compilation, streaming operation and continuations, won't work in
//! that part of the RXML code.
{
  if(!objectp(id)) error("No id passed to parse_rxml\n");
  return id->conf->parse_rxml( what, id );
}

array(string|RXML.PCode) compile_rxml (string what, RequestID id)
//! Evaluates and compiles the given string as RXML. Returns an array
//! where the first element is the result of the evaluation and the
//! second is the p-code object that contains the compiled RXML tree.
//! It can be re-evaluated by e.g. @[Roxen.eval_p_code]. This function
//! initiates a new context for the evaluation, so it won't recurse in
//! the currently ongoing RXML evaluation, if any.
{
  RXML.Parser parser = get_rxml_parser (id, 0, 1);
  parser->write_end (what);
  array(string|RXML.PCode) res = ({parser->eval(), parser->p_code});
  res[1]->finish();
  //parser->type->give_back (parser); // RXML.PXml is not resettable anyway.
  return res;
}

mixed eval_p_code (RXML.PCode p_code, RequestID id)
//! Evaluates the given p-code object and returns the result. This
//! function initiates a new context for the evaluation, so it won't
//! recurse in the currently ongoing RXML evaluation, if any.
//!
//! @note
//! The caller should first check with @[p_code->is_stale] that the
//! p-code isn't stale, i.e. that none of the tag sets used in it have
//! changed since it was created. If that's the case it isn't safe to
//! evaluate the p-code, so it should be discarded and perhaps
//! replaced with a new one retrieved by @[RXML.string_to_p_code] or
//! generated from source. See also @[RXML.RenewablePCode], which
//! never can become stale.
{
  return p_code->eval (p_code->new_context (id));
}

RXML.Parser get_rxml_parser (RequestID id, void|RXML.Type type, void|int make_p_code)
//! Returns a parser object for parsing and evaluating a string as
//! RXML in a new context. @[type] may be used to set the top level
//! type to parse. It defaults to the standard type and parser for
//! RXML code.
//!
//! If @[make_p_code] is nonzero, the parser is initialized with an
//! @[RXML.PCode] object to collect p-code during the evaluation. When
//! the parser is finished, the p-code is available in the variable
//! @[RXML.Parser.p_code]. The p-code itself is not finished, though;
//! @[RXML.PCode.finished] should be called in it before use to
//! compact it, although that isn't mandatory.
{
  RXML.Parser parser = id->conf->rxml_tag_set->get_parser (
    type || id->conf->default_content_type, id, make_p_code);
  parser->recover_errors = 1;
  if (make_p_code) parser->p_code->recover_errors = 1;
  return parser;
}

protected int(0..0) return_zero() {return 0;}

protected Parser.HTML xml_parser =
  lambda() {
    Parser.HTML p = Parser.HTML();
    p->lazy_entity_end (1);
    p->match_tag (0);
    p->xml_tag_syntax (3);
    p->add_quote_tag ("!--", return_zero, "--");
    p->add_quote_tag ("![CDATA[", return_zero, "]]");
    p->add_quote_tag ("?", return_zero, "?");
    return p;
  }();

Parser.HTML get_xml_parser()
//! Returns a @[Parser.HTML] initialized for parsing XML. It has all
//! the flags set properly for XML syntax and have callbacks to ignore
//! comments, CDATA blocks and unknown PI tags, but it has no
//! registered tags and doesn't decode any entities.
{
  return xml_parser->clone();
}

constant iso88591
=([ "&nbsp;":   " ",
    "&iexcl;":  "Ў",
    "&cent;":   "ў",
    "&pound;":  "Ј",
    "&curren;": "¤",
    "&yen;":    "Ґ",
    "&brvbar;": "¦",
    "&sect;":   "§",
    "&uml;":    "Ё",
    "&copy;":   "©",
    "&ordf;":   "Є",
    "&laquo;":  "«",
    "&not;":    "¬",
    "&shy;":    "­",
    "&reg;":    "®",
    "&macr;":   "Ї",
    "&deg;":    "°",
    "&plusmn;": "±",
    "&sup2;":   "І",
    "&sup3;":   "і",
    "&acute;":  "ґ",
    "&micro;":  "µ",
    "&para;":   "¶",
    "&middot;": "·",
    "&cedil;":  "ё",
    "&sup1;":   "№",
    "&ordm;":   "є",
    "&raquo;":  "»",
    "&frac14;": "ј",
    "&frac12;": "Ѕ",
    "&frac34;": "ѕ",
    "&iquest;": "ї",
    "&Agrave;": "А",
    "&Aacute;": "Б",
    "&Acirc;":  "В",
    "&Atilde;": "Г",
    "&Auml;":   "Д",
    "&Aring;":  "Е",
    "&AElig;":  "Ж",
    "&Ccedil;": "З",
    "&Egrave;": "И",
    "&Eacute;": "Й",
    "&Ecirc;":  "К",
    "&Euml;":   "Л",
    "&Igrave;": "М",
    "&Iacute;": "Н",
    "&Icirc;":  "О",
    "&Iuml;":   "П",
    "&ETH;":    "Р",
    "&Ntilde;": "С",
    "&Ograve;": "Т",
    "&Oacute;": "У",
    "&Ocirc;":  "Ф",
    "&Otilde;": "Х",
    "&Ouml;":   "Ц",
    "&times;":  "Ч",
    "&Oslash;": "Ш",
    "&Ugrave;": "Щ",
    "&Uacute;": "Ъ",
    "&Ucirc;":  "Ы",
    "&Uuml;":   "Ь",
    "&Yacute;": "Э",
    "&THORN;":  "Ю",
    "&szlig;":  "Я",
    "&agrave;": "а",
    "&aacute;": "б",
    "&acirc;":  "в",
    "&atilde;": "г",
    "&auml;":   "д",
    "&aring;":  "е",
    "&aelig;":  "ж",
    "&ccedil;": "з",
    "&egrave;": "и",
    "&eacute;": "й",
    "&ecirc;":  "к",
    "&euml;":   "л",
    "&igrave;": "м",
    "&iacute;": "н",
    "&icirc;":  "о",
    "&iuml;":   "п",
    "&eth;":    "р",
    "&ntilde;": "с",
    "&ograve;": "т",
    "&oacute;": "у",
    "&ocirc;":  "ф",
    "&otilde;": "х",
    "&ouml;":   "ц",
    "&divide;": "ч",
    "&oslash;": "ш",
    "&ugrave;": "щ",
    "&uacute;": "ъ",
    "&ucirc;":  "ы",
    "&uuml;":   "ь",
    "&yacute;": "э",
    "&thorn;":  "ю",
    "&yuml;":   "я",
]);

constant international
=([ "&OElig;":  "\x0152",
    "&oelig;":  "\x0153",
    "&Scaron;": "\x0160",
    "&scaron;": "\x0161",
    "&Yuml;":   "\x0178",
    "&circ;":   "\x02C6",
    "&tilde;":  "\x02DC",
    "&ensp;":   "\x2002",
    "&emsp;":   "\x2003",
    "&thinsp;": "\x2009",
    "&zwnj;":   "\x200C",
    "&zwj;":    "\x200D",
    "&lrm;":    "\x200E",
    "&rlm;":    "\x200F",
    "&ndash;":  "\x2013",
    "&mdash;":  "\x2014",
    "&lsquo;":  "\x2018",
    "&rsquo;":  "\x2019",
    "&sbquo;":  "\x201A",
    "&ldquo;":  "\x201C",
    "&rdquo;":  "\x201D",
    "&bdquo;":  "\x201E",
    "&dagger;": "\x2020",
    "&Dagger;": "\x2021",
    "&permil;": "\x2030",
    "&lsaquo;": "\x2039",
    "&rsaquo;": "\x203A",
    "&euro;":   "\x20AC",
]);

constant symbols
=([ "&fnof;":     "\x0192",
    "&thetasym;": "\x03D1",
    "&upsih;":    "\x03D2",
    "&piv;":      "\x03D6",
    "&bull;":     "\x2022",
    "&hellip;":   "\x2026",
    "&prime;":    "\x2032",
    "&Prime;":    "\x2033",
    "&oline;":    "\x203E",
    "&frasl;":    "\x2044",
    "&weierp;":   "\x2118",
    "&image;":    "\x2111",
    "&real;":     "\x211C",
    "&trade;":    "\x2122",
    "&alefsym;":  "\x2135",
    "&larr;":     "\x2190",
    "&uarr;":     "\x2191",
    "&rarr;":     "\x2192",
    "&darr;":     "\x2193",
    "&harr;":     "\x2194",
    "&crarr;":    "\x21B5",
    "&lArr;":     "\x21D0",
    "&uArr;":     "\x21D1",
    "&rArr;":     "\x21D2",
    "&dArr;":     "\x21D3",
    "&hArr;":     "\x21D4",
    "&forall;":   "\x2200",
    "&part;":     "\x2202",
    "&exist;":    "\x2203",
    "&empty;":    "\x2205",
    "&nabla;":    "\x2207",
    "&isin;":     "\x2208",
    "&notin;":    "\x2209",
    "&ni;":       "\x220B",
    "&prod;":     "\x220F",
    "&sum;":      "\x2211",
    "&minus;":    "\x2212",
    "&lowast;":   "\x2217",
    "&radic;":    "\x221A",
    "&prop;":     "\x221D",
    "&infin;":    "\x221E",
    "&ang;":      "\x2220",
    "&and;":      "\x2227",
    "&or;":       "\x2228",
    "&cap;":      "\x2229",
    "&cup;":      "\x222A",
    "&int;":      "\x222B",
    "&there4;":   "\x2234",
    "&sim;":      "\x223C",
    "&cong;":     "\x2245",
    "&asymp;":    "\x2248",
    "&ne;":       "\x2260",
    "&equiv;":    "\x2261",
    "&le;":       "\x2264",
    "&ge;":       "\x2265",
    "&sub;":      "\x2282",
    "&sup;":      "\x2283",
    "&nsub;":     "\x2284",
    "&sube;":     "\x2286",
    "&supe;":     "\x2287",
    "&oplus;":    "\x2295",
    "&otimes;":   "\x2297",
    "&perp;":     "\x22A5",
    "&sdot;":     "\x22C5",
    "&lceil;":    "\x2308",
    "&rceil;":    "\x2309",
    "&lfloor;":   "\x230A",
    "&rfloor;":   "\x230B",
    "&lang;":     "\x2329",
    "&rang;":     "\x232A",
    "&loz;":      "\x25CA",
    "&spades;":   "\x2660",
    "&clubs;":    "\x2663",
    "&hearts;":   "\x2665",
    "&diams;":    "\x2666",
]);

constant greek
= ([ "&Alpha;":   "\x391",
     "&Beta;":    "\x392",
     "&Gamma;":   "\x393",
     "&Delta;":   "\x394",
     "&Epsilon;": "\x395",
     "&Zeta;":    "\x396",
     "&Eta;":     "\x397",
     "&Theta;":   "\x398",
     "&Iota;":    "\x399",
     "&Kappa;":   "\x39A",
     "&Lambda;":  "\x39B",
     "&Mu;":      "\x39C",
     "&Nu;":      "\x39D",
     "&Xi;":      "\x39E",
     "&Omicron;": "\x39F",
     "&Pi;":      "\x3A0",
     "&Rho;":     "\x3A1",
     "&Sigma;":   "\x3A3",
     "&Tau;":     "\x3A4",
     "&Upsilon;": "\x3A5",
     "&Phi;":     "\x3A6",
     "&Chi;":     "\x3A7",
     "&Psi;":     "\x3A8",
     "&Omega;":   "\x3A9",
     "&alpha;":   "\x3B1",
     "&beta;":    "\x3B2",
     "&gamma;":   "\x3B3",
     "&delta;":   "\x3B4",
     "&epsilon;": "\x3B5",
     "&zeta;":    "\x3B6",
     "&eta;":     "\x3B7",
     "&theta;":   "\x3B8",
     "&iota;":    "\x3B9",
     "&kappa;":   "\x3BA",
     "&lambda;":  "\x3BB",
     "&mu;":      "\x3BC",
     "&nu;":      "\x3BD",
     "&xi;":      "\x3BE",
     "&omicron;": "\x3BF",
     "&pi;":      "\x3C0",
     "&rho;":     "\x3C1",
     "&sigmaf;":  "\x3C2",
     "&sigma;":   "\x3C3",
     "&tau;":     "\x3C4",
     "&upsilon;": "\x3C5",
     "&phi;":     "\x3C6",
     "&chi;":     "\x3C7",
     "&psi;":     "\x3C8",
     "&omega;":   "\x3C9",
]);

constant replace_entities = indices( iso88591 ) +
  indices( international ) +
  indices( symbols ) +
  indices( greek ) +
  ({"&lt;","&gt;","&amp;","&quot;","&apos;","&#x22;","&#34;","&#39;","&#0;"});

constant replace_values = values( iso88591 ) +
  values( international ) +
  values( symbols ) +
  values( greek ) +
  ({"<",">","&","\"","\'","\"","\"","\'","\000"});

constant safe_characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"/"";
constant empty_strings = ({""})*sizeof(safe_characters);

//! Returns 1 if @[in] is nonempty and only contains alphanumerical
//! characters (a-z, A-Z and 0-9). Otherwise returns 0.
int(0..1) is_safe_string(string in)
{
  return strlen(in) && !strlen(replace(in, safe_characters, empty_strings));
}

string make_entity( string q )
{
  return "&"+q+";";
}

string make_tag_attributes(mapping(string:string) in,
			   void|int preserve_roxen_entities)
{
  if (!in || !sizeof(in))
    return "";

  //  Special quoting which leaves Roxen entities (e.g. &page.path;)
  //  unescaped.
  string quote_fn(string text)
  {
    string out = "";
    int pos = 0;
    while ((pos = search(text, "&")) >= 0) {
      if ((sscanf(text[pos..], "&%[^ <>;&];", string entity) == 1) &&
	  search(entity, ".") >= 0) {
	out += html_encode_string(text[..pos - 1]) + "&" + entity + ";";
	text = text[pos + strlen(entity) + 2..];
      } else {
	out += html_encode_string(text[..pos]);
	text = text[pos + 1..];
      }
    }
    return out + html_encode_string(text);
  };
  
  string res = "";
  array(string) sorted_attrs = sort(indices(in));
  if (preserve_roxen_entities) {
    foreach(sorted_attrs, string a)
      res += " " + a + "=\"" + quote_fn((string) in[a]) + "\"";
  } else {
    foreach(sorted_attrs, string a)
      res += " " + a + "=\"" + html_encode_string((string) in[a]) + "\"";
  }
  return res;
}

string make_tag(string name, mapping(string:string) args, void|int xml,
		void|int preserve_roxen_entities)
//! Returns an empty element tag @[name], with the tag arguments dictated
//! by the mapping @[args]. If the flag @[xml] is set, slash character will
//! be added in the end of the tag. Use RXML.t_xml->format_tag(name, args)
//! instead.
{
  string attrs = make_tag_attributes(args, preserve_roxen_entities);
  return "<" + name + attrs + (xml ? " /" : "" ) + ">";
}

string make_container(string name, mapping(string:string) args, string content,
		      void|int preserve_roxen_entities)
//! Returns a container tag @[name] encasing the string @[content], with
//! the tag arguments dictated by the mapping @[args]. Use
//! RXML.t_xml->format_tag(name, args, content) instead.
{
  if(args["/"]=="/") m_delete(args, "/");
  return make_tag(name, args, 0,
		  preserve_roxen_entities) + content + "</" + name + ">";
}

string add_config( string url, array config, multiset prestate )
{
  if(!sizeof(config))
    return url;
  if(strlen(url)>5 && (url[1] == '(' || url[1] == '<'))
    return url;
  return "/<" + config * "," + ">" + add_pre_state(url, prestate);
}

string extension( string f, RequestID|void id)
{
  string ext, key;
  if(!f || !strlen(f)) return "";
  if(!id || !(ext = [string]id->misc[key="_ext_"+f])) {
    sscanf(reverse(f), "%s.%*s", ext);
    if(!ext) ext = "";
    else {
      ext = lower_case(reverse(ext));
      if(sizeof (ext) && (ext[-1] == '~' || ext[-1] == '#'))
        ext = ext[..strlen(ext)-2];
    }
    if(id) id->misc[key]=ext;
  }
  return ext;
}

int(0..1) backup_extension( string f )
  //! Determines if the provided filename indicates
  //! that the file is a backup file.
{
  if(!strlen(f))
    return 1;
  return (f[-1] == '#' || f[-1] == '~' || f[0..1]==".#"
	  || (f[-1] == 'd' && sscanf(f, "%*s.old"))
	  || (f[-1] == 'k' && sscanf(f, "%*s.bak")));
}

array(string) win_drive_prefix(string path)
//! Splits path into ({ prefix, path }) array. Prefix is "" for paths on
//! non-Windows systems or when no proper drive prefix is found.
{
#ifdef __NT__
  string prefix;
  if (sscanf(path, "\\\\%s%*[\\/]%s", prefix, string path_end) == 3) {
    return ({ "\\\\" + prefix, "/" + path_end });
  } else if (sscanf(path, "%1s:%s", prefix, path) == 2) {
    return ({ prefix + ":", path });
  }
#endif
  return ({ "", path });
}

string simplify_path(string file)
//! This one will remove .././ etc. in the path. The returned value
//! will be a canonic representation of the given path.
{
  // Faster for most cases since "//", "./" or "../" rarely exists.
  if(!strlen(file) || (!has_value(file, "./") && (file[-1] != '.') &&
		       !has_value (file, "//")))
    return file;

  int relative, got_slashdot_suffix;

  [string prefix, file] = win_drive_prefix(file);

  if (!has_prefix (file, "/"))
    relative = 1;

  // The following used to test for "//" at the end (thus replacing
  // that too with "/."). That must be some kind of old confusion
  // (dates back to at least roxenlib.pike 1.1 from 11 Nov 1996).
  // /mast
  if (has_suffix (file, "/."))
    got_slashdot_suffix = 1;

  file=combine_path("/", file);

  if(got_slashdot_suffix) file += "/.";
  if(relative) return prefix + file[1..];

  return prefix + file;
}

string short_date(int timestamp)
//! Returns a short date string from a time-int
{
  int date = time(1);

  if(ctime(date)[20..23] != ctime(timestamp)[20..23])
    return ctime(timestamp)[4..9] +" "+ ctime(timestamp)[20..23];

  return ctime(timestamp)[4..9] +" "+ ctime(timestamp)[11..15];
}

string int2roman(int m)
  //! Converts the provided integer to a roman integer (i.e. a string).
{
  string res="";
  if (m>10000000||m<0) return "que";
  while (m>999) { res+="M"; m-=1000; }
  if (m>899) { res+="CM"; m-=900; }
  else if (m>499) { res+="D"; m-=500; }
  else if (m>399) { res+="CD"; m-=400; }
  while (m>99) { res+="C"; m-=100; }
  if (m>89) { res+="XC"; m-=90; }
  else if (m>49) { res+="L"; m-=50; }
  else if (m>39) { res+="XL"; m-=40; }
  while (m>9) { res+="X"; m-=10; }
  if (m>8) return res+"IX";
  else if (m>4) { res+="V"; m-=5; }
  else if (m>3) return res+"IV";
  while (m) { res+="I"; m--; }
  return res;
}

string number2string(int n, mapping m, array|function names)
{
  string s;
  switch (m->type)
  {
  case "string":
     if (functionp(names)) {
       s=([function(int:string)]names)(n);
       break;
     }
     if (n<0 || n>=sizeof(names))
       s="";
     else
       s=([array(string)]names)[n];
     break;
  case "roman":
    s=int2roman(n);
    break;
  default:
    return (string)n;
  }

  switch(m["case"]) {
    case "lower": return lower_case(s);
    case "upper": return upper_case(s);
    case "capitalize": return capitalize(s);
  }

#ifdef old_rxml_compat
  if (m->lower) return lower_case(s);
  if (m->upper) return upper_case(s);
  if (m->cap||m->capitalize) return capitalize(s);
#endif

  return s;
}

string image_from_type( string t )
  //! Returns an internal-gopher icon link that corresponds to the
  //! provided MIME-type, e.g. "internal-gopher-image" for "image/gif".
{
  if(t)
  {
    sscanf(t, "%s/", t);
    switch(t)
    {
     case "audio":
     case "sound":
      return "internal-gopher-sound";
     case "image":
      return "internal-gopher-image";
     case "application":
      return "internal-gopher-binary";
     case "text":
      return "internal-gopher-text";
    }
  }
  return "internal-gopher-unknown";
}

protected constant size_suffix =
  ({ "B", "kB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB" });

string sizetostring( int|float size )
  //! Returns the size as a memory size string with suffix,
  //! e.g. 43210 is converted into "42.2 kB". To be correct
  //! to the latest standards it should really read "42.2 KiB",
  //! but we have chosen to keep the old notation for a while.
  //! The function knows about the quantifiers kilo, mega, giga,
  //! tera, peta, exa, zetta and yotta.
{
  int neg = size < 0;
  int|float abs_size = abs (size);

  if (abs_size < 1024) {
    if (intp (size))
      return size + " " + size_suffix[0];
    return size < 10.0 ?
      sprintf ("%.2f %s", size, size_suffix[0]) :
      sprintf ("%.0f %s", size, size_suffix[0]);
  }

  float s = (float) abs_size;
  size=0;
  while( s >= 1024.0 )
  {
    s /= 1024.0;
    if (++size == sizeof (size_suffix) - 1) break;
  }
  if (neg) s = -s;
  return sprintf("%.1f %s", s, size_suffix[ size ]);
}

string format_hrtime (int hrtime, void|int pad)
//! Returns a nicely formatted string for a time lapse value expressed
//! in microseconds. If @[pad] is nonzero then the value is formatted
//! right justified in a fixed-length string.
{
  if (hrtime < 1000000)
    return sprintf (pad ? "%7.3f ms" : "%.3f ms", hrtime / 1e3);
  else if (hrtime < 60 * 1000000)
    return sprintf (pad ? "%8.3f s" : "%.3f s", hrtime / 1e6);
  else if (hrtime < 60 * 60 * 1000000)
    return sprintf (pad ? "%3d:%02d min" : "%d:%02d min",
		    hrtime / (60 * 1000000), (hrtime / 1000000) % 60);
  else
    return sprintf (pad ? "%4d:%02d:%02d" : "%d:%02d:%02d",
		    hrtime / (60 * 60 * 1000000),
		    (hrtime / (60 * 1000000)) % 60,
		    (hrtime / 1000000) % 60);
}

string html_decode_string(LocaleString str)
//! Decodes `str', opposite to @[html_encode_string()].
{
  return replace((string)str, replace_entities, replace_values);
}

string html_encode_tag_value(LocaleString str)
//! Encodes `str' for use as a value in an html tag.
{
  // '<' is not allowed in attribute values in XML 1.0.
  return "\"" + replace((string)str, ({"&", "\"", "<"}), ({"&amp;", "&quot;", "&lt;"})) + "\"";
}

protected string my_sprintf(int prefix, string f, int arg)
//! Filter prefix option in format string if prefix = 0.
{
  if(!prefix && sscanf(f, "%%%*d%s", string format) == 2)
    f = "%" + format;
  return sprintf(f, arg);
}

string strftime(string fmt, int t,
		void|string lang, void|function language, void|RequestID id)
//! Encodes the time `t' according to the format string `fmt'.
{
  if(!sizeof(fmt)) return "";
  mapping lt = localtime(t);
  fmt=replace(fmt, "%%", "\0");
  array(string) a = fmt/"%";
  string res = a[0];
  mapping(string:string) m = (["type":"string"]);
  
  foreach(a[1..], string key) {
    int(0..1) prefix = 1;
    int(0..1) alternative_numbers = 0;
    int(0..1) alternative_form = 0;
    while (sizeof(key)) {
      switch(key[0]) {
	// Flags.
      case '!':	// Inhibit numerical padding (Pike).
	prefix = 0;
	key = key[1..];
	continue;
      case 'E':	// Locale-dependent alternative form.
	alternative_form = 1;
	key = key[1..];
	continue;
      case 'O':	// Locale-dependent alternative numeric representation.
	alternative_numbers = 1;
	key = key[1..];
	continue;

	// Formats.
      case 'a':	// Abbreviated weekday name
	if (language)
	  res += number2string(lt->wday+1,m,language(lang,"short_day",id));
	else
	  res += ({ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" })[lt->wday];
	break;
      case 'A':	// Weekday name
	if (language)
	  res += number2string(lt->wday+1,m,language(lang,"day",id));
	else
	  res += ({ "Sunday", "Monday", "Tuesday", "Wednesday",
		    "Thursday", "Friday", "Saturday" })[lt->wday];
	break;
      case 'b':	// Abbreviated month name
      case 'h':	// Abbreviated month name
	if (language)
	  res += number2string(lt->mon+1,m,language(lang,"short_month",id));
	else
	  res += ({ "Jan", "Feb", "Mar", "Apr", "May", "Jun",
		    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" })[lt->mon];
	break;
      case 'B':	// Month name
	if (language) {
	  if (alternative_form) {
	    res += number2string(lt->mon+1,m,language(lang,"numbered_month",id));
	  } else {
	    res += number2string(lt->mon+1,m,language(lang,"month",id));
	  }
	} else
	  res += ({ "January", "February", "March", "April", "May", "June",
		    "July", "August", "September", "October", "November", "December" })[lt->mon];
	break;
      case 'c':	// Date and time
	// FIXME: Should be preferred date and time for the locale.
	res += strftime(sprintf("%%a %%b %02d  %02d:%02d:%02d %04d",
				lt->mday, lt->hour, lt->min, lt->sec, 1900 + lt->year), t);
	break;
      case 'C':	// Century number; 0-prefix
	res += my_sprintf(prefix, "%02d", 19 + lt->year/100);
	break;
      case 'd':	// Day of month [1,31]; 0-prefix
	res += my_sprintf(prefix, "%02d", lt->mday);
	break;
      case 'D':	// Date as %m/%d/%y
	res += strftime("%m/%d/%y", t);
	break;
      case 'e':	// Day of month [1,31]; space-prefix
	res += my_sprintf(prefix, "%2d", lt->mday);
	break;
      case 'F':	// ISO 8601 date %Y-%m-%d
	res += sprintf("%04d-%02d-%02d",
		       1900 + lt->year, lt->mon + 1, lt->mday);
	break;
      case 'G':	// Year for the ISO 8601 week containing the day.
	{
	  int wday = (lt->wday + 1)%7;	// ISO 8601 weekday number.
	  if ((wday - lt->yday) >= 4) {
	    // The day belongs to the last week of the previous year.
	    res += my_sprintf(prefix, "%04d", 1899 + lt->year);
	  } else if ((lt->mon == 11) && ((lt->mday - wday) >= 29)) {
	    // The day belongs to the first week of the next year.
	    res += my_sprintf(prefix, "%04d", 1901 + lt->year);
	  } else {
	    res += my_sprintf(prefix, "%04d", 1900 + lt->year);
	  }
	}
	break;
      case 'g':	// Short year for the ISO 8601 week containing the day.
	{
	  int wday = (lt->wday + 1)%7;	// ISO 8601 weekday number.
	  if ((wday - lt->yday) >= 4) {
	    // The day belongs to the last week of the previous year.
	    res += my_sprintf(prefix, "%02d", (99 + lt->year) % 100);
	  } else if ((lt->mon == 11) && ((lt->mday - wday) >= 29)) {
	    // The day belongs to the first week of the next year.
	    res += my_sprintf(prefix, "%02d", (1 + lt->year) % 100);
	  } else {
	    res += my_sprintf(prefix, "%02d", (lt->year) % 100);
	  }
	}
	break;
      case 'H':	// Hour (24-hour clock) [0,23]; 0-prefix
	res += my_sprintf(prefix, "%02d", lt->hour);
	break;
      case 'I':	// Hour (12-hour clock) [1,12]; 0-prefix
	res += my_sprintf(prefix, "%02d", 1 + (lt->hour + 11)%12);
	break;
      case 'j':	// Day number of year [1,366]; 0-prefix
	res += my_sprintf(prefix, "%03d", lt->yday);
	break;
      case 'k':	// Hour (24-hour clock) [0,23]; space-prefix
	res += my_sprintf(prefix, "%2d", lt->hour);
	break;
      case 'l':	// Hour (12-hour clock) [1,12]; space-prefix
	res += my_sprintf(prefix, "%2d", 1 + (lt->hour + 11)%12);
	break;
      case 'm':	// Month number [1,12]; 0-prefix
	res += my_sprintf(prefix, "%02d", lt->mon + 1);
	break;
      case 'M':	// Minute [00,59]; 0-prefix
	res += my_sprintf(prefix, "%02d", lt->min);
	break;
      case 'n':	// Newline
	res += "\n";
	break;
      case 'p':	// a.m. or p.m.
	res += lt->hour<12 ? "a.m." : "p.m.";
	break;
      case 'P':	// am or pm
	res += lt->hour<12 ? "am" : "pm";
	break;
      case 'r':	// Time in 12-hour clock format with %p
	res += strftime("%I:%M:%S %p", t);
	break;
      case 'R':	// Time as %H:%M
	res += sprintf("%02d:%02d", lt->hour, lt->min);
	break;
      case 's':	// Seconds since epoch.
	res += my_sprintf(prefix, "%d", t);
	break;
      case 'S':	// Seconds [00,61]; 0-prefix
	res += my_sprintf(prefix, "%02d", lt->sec);
	break;
      case 't':	// Tab
	res += "\t";
	break;
      case 'T':	// Time as %H:%M:%S
      case 'X':	// FIXME: Time in locale preferred format.
	res += sprintf("%02d:%02d:%02d", lt->hour, lt->min, lt->sec);
	break;
      case 'u':	// Weekday as a decimal number [1,7], Monday == 1
	res += my_sprintf(prefix, "%d", 1 + ((lt->wday + 6) % 7));
	break;
      case 'U':	// Week number of current year [00,53]; 0-prefix
		// Sunday is first day of week.
	res += my_sprintf(prefix, "%02d", 1 + (lt->yday - lt->wday)/ 7);
	break;
      case 'V':	// ISO week number of the year as a decimal number [01,53]; 0-prefix
	res += my_sprintf(prefix, "%02d", Calendar.ISO.Second(t)->week_no());
	break;
      case 'w':	// Weekday as a decimal number [0,6], Sunday == 0
	res += my_sprintf(prefix, "%d", lt->wday);
	break;
      case 'W':	// Week number of year as a decimal number [00,53],
		// with Monday as the first day of week 1; 0-prefix
	res += my_sprintf(prefix, "%02d", ((lt->yday+(5+lt->wday)%7)/7));
	break;
      case 'x':	// Date
		// FIXME: Locale preferred date format.
	res += strftime("%a %b %d %Y", t);
	break;
      case 'y':	// Year [00,99]; 0-prefix
	res += my_sprintf(prefix, "%02d", lt->year % 100);
	break;
      case 'Y':	// Year [0000.9999]; 0-prefix
	res += my_sprintf(prefix, "%04d", 1900 + lt->year);
	break;
      case 'z':	// Time zone as hour offset from UTC.
		// Needed for RFC822 dates.
	{
	  int minutes = lt->timezone/60;
	  int hours = minutes/60;
	  minutes -= hours * 60;
	  res += my_sprintf(prefix, "%+05d%", hours*100 + minutes);
	}
	break;
      case 'Z':	// FIXME: Time zone name or abbreviation, or no bytes if
		// no time zone information exists
	break;
      }
      res+=key[1..];
      break;
    }
  }
  return replace(res, "\0", "%");
}

RoxenModule get_module (string modname)
//! Resolves a string as returned by get_modname to a module object if
//! one exists.
{
  string cname, mname;
  int mid = 0;

  if (sscanf (modname, "%s/%s", cname, mname) != 2 ||
      !sizeof (cname) || !sizeof(mname)) return 0;
  sscanf (mname, "%s#%d", mname, mid);

  if (Configuration conf = roxen->get_configuration (cname))
    if (mapping moddata = conf->modules[mname])
      return moddata->copies[mid];

  return 0;
}

string get_modname (RoxenModule module)
//! Returns a string uniquely identifying the given module on the form
//! `<config name>/<module short name>#<copy>'.
{
  return module && module->module_identifier();
}

string get_modfullname (RoxenModule module)
//! This determines the full module (human-readable) name in
//! approximately the same way as the config UI. Note that the
//! returned string is text/html.
{
  if (module) {
    string|mapping(string:string)|Locale.DeferredLocale name = 0;
    if (module->query)
      catch {
	mixed res = module->query ("_name");
	if (res) name = (string) res;
      };
    if (!(name && sizeof (name)) && module->query_name)
      name = module->query_name();
    if (!(name && sizeof (name))) {
      name = [string]module->register_module()[1];
      sscanf (module->module_local_id(), "%*s#%d", int mod_copy);
      if (mod_copy) name += " # " + mod_copy;
    }
    if (mappingp (name))
      name = name->standard;
    return (string) name;
  }
  else return 0;
}

protected constant xml_invalid_mappings = ([
  "\0":"\22000",  "\1":"\22001",
  "\2":"\22002",  "\3":"\22003",
  "\4":"\22004",  "\5":"\22005",
  "\6":"\22006",  "\7":"\22007",
  "\b":"\22010",  "\13":"\22013",
  "\14":"\22014", "\16":"\22016",
  "\17":"\22017", "\20":"\22020",
  "\21":"\22021", "\22":"\22022",
  "\23":"\22023", "\24":"\22024",
  "\25":"\22025", "\26":"\22026",
  "\27":"\22027", "\30":"\22030",
  "\31":"\22031", "\32":"\22032",
  "\33":"\22033", "\34":"\22034",
  "\35":"\22035", "\36":"\22036",
  "\37":"\22037", "\177":"\22041",
  "\xFFFE":"", "\xFFFF":"" // Invalid unicode chars in XML!
]);

string encode_xml_invalids(string s)
//! Remap control characters not valid in XML-documents to their
//! corresponding printable code points (@tt{U2400 - U2421@}).
{
  return replace(s, xml_invalid_mappings);
}

//! Encode a single segment of @[roxen_encode()].
//!
//! See @[roxen_encode()] for details.
protected string low_roxen_encode(string val, string encoding)
{
  switch (encoding) {
   case "":
   case "none":
     return val;

   case "utf8":
   case "utf-8":
     return string_to_utf8(val);

   case "-utf8":
   case "-utf-8":
    if( catch {
	return utf8_to_string(val);
      })
      RXML.run_error("Cannot decode utf-8 string. Bad data.\n");

   case "utf16":
   case "utf16be":
     return Locale.Charset.encoder("utf16be")->feed(val)->drain();

   case "utf16le":
     return Locale.Charset.encoder("utf16le")->feed(val)->drain();

  case "hex":
    if(String.width(val) > 8)
      RXML.run_error(  "Cannot hex encode wide characters.\n" );
    return String.string2hex(val);

  case "-hex":
    if( catch {
	return String.hex2string(val);
      })
      RXML.run_error("Cannot decode hex string. Bad data.\n");

   case "base64":
   case "base-64":
   case "b64":
     return MIME.encode_base64(val);

   case "-base64":
   case "-base-64":
   case "-b64":
     if( catch {
	 return MIME.decode_base64(val);
       })
       RXML.run_error("Cannot decode base64 string. Bad data.\n");

   
  case "md5":
  case "sha1":
  case "sha256":
    if (String.width(val) > 8)
      RXML.run_error("Cannot hash wide characters.\n");
    return Crypto[upper_case(encoding)]->hash(val);
    
   case "quotedprintable":
   case "quoted-printable":
   case "qp":
     return MIME.encode_qp(val);

   case "http":
     return http_encode_invalids (val);

   case "cookie":
     return http_encode_cookie (val);

   case "url":
     return http_encode_url (val);

   case "wml-url":
     // Note: In 4.0 and earlier, this encoding was ambiguous since 8
     // bit strings were %-encoded according to the ISO 8859-1 charset
     // while wider strings first were UTF-8 encoded and then
     // %-encoded. Although unlikely, it might be possible that the
     // old ambiguous encoding is the one mandated by the WAP/WML
     // standard - I haven't been able to verify it. /mast
     return http_encode_url(val);

   case "html":
     return html_encode_string (val);
   case "-html":
     //  Can't use html_decode_string() which doesn't understand numerical
     //  entities.
     return RXML.TXml()->decode_charrefs(val);

   case "invalids":
   case "xmlinvalids":
   case "xml-invalids":
     return encode_xml_invalids(val);

   case "wml":
     return replace(html_encode_string(val), "$", "$$");

   case "dtag":
     // This is left for compatibility...
     return replace (val, "\"", "\"'\"'\"");

   case "stag":
     // This is left for compatibility
     return replace(val, "'", "'\"'\"'");

   case "pike":
     return replace (val,
		    ({ "\"", "\\", "\n" }),
		    ({ "\\\"", "\\\\", "\\n" }));

   case "json":
#if constant (Standards.JSON.escape_string)
     return Standards.JSON.escape_string (val);
#else
     // Simpler variant for compat with older pikes.
     return replace(val,
		   ({ "\"",   "\\",   "/",   "\b",
		      "\f",   "\n",   "\r",  "\t",
		      "\u2028",       "\u2029", }),
		   ({ "\\\"", "\\\\", "\\/", "\\b",
		      "\\f",  "\\n",  "\\r", "\\t",
		      "\\u2028",      "\\u2029", }));
#endif

   case "js":
   case "javascript":
     return replace (val,
		    ({ "\b", "\014", "\n", "\r", "\t", "\\",
		       "'", "\"",
		       "\u2028", "\u2029",
		       "</", "<!--"}),
		    ({ "\\b", "\\f", "\\n", "\\r", "\\t", "\\\\",
		       "\\'", "\\\"",
		       "\\u2028", "\\u2029",
		       "<\\/", "<\\!--" }));

   case "mysql":
     // Note: Quotes the single-quote (') in traditional sql-style,
     //       for maximum compatibility with other sql databases.
     return replace (val,
		    ({ "\"", "'", "\\" }),
		    ({ "\\\"" , "''", "\\\\" }) );

   case "sql":
   case "oracle":
     return replace (val, "'", "''");

  case "bytea":
    return replace (val,
		    ({ "'", "\\", "\0", "&" }),
		    ({ "\\'", "\\\\\\\\", "\\\\000", "\\\\046" }) );

   case "csv":
     if (sizeof(val) &&
	 ((<' ', '\t'>)[val[0]] || (<' ', '\t'>)[val[-1]] ||
	  has_value(val, ",") || has_value(val, ";") ||
	  has_value(val, "\"") || has_value(val, "\n"))) {
       return "\"" + replace(val, "\"", "\"\"") + "\"";
     }
     return val;

   case "mysql-dtag":
     // This is left for compatibility
     return replace (val,
		    ({ "\"", "'", "\\" }),
		    ({ "\\\"'\"'\"", "\\'", "\\\\" }));

   case "mysql-pike":
     return replace (val,
		    ({ "\"", "'", "\\", "\n" }),
		    ({ "\\\\\\\"", "\\\\'",
		       "\\\\\\\\", "\\n" }) );

   case "sql-dtag":
   case "oracle-dtag":
     // This is left for compatibility
     return replace (val,
		    ({ "'", "\"" }),
		    ({ "''", "\"'\"'\"" }) );

   default:
     // Unknown encoding. Let the caller decide what to do with it.
     return 0;
  }
}

//! Quote strings in a multitude of ways. Used primarily by entity quoting.
//!
//! The @[encoding] string is split on @expr{"."@}, and encoded in order.
//!
//! The segments in the split @[encoding] string can be any of
//! the following:
//! @string
//!   @value ""
//!   @value "none"
//!     No encoding.
//!
//!   @value "utf8"
//!   @value "utf-8"
//!     UTF-8 encoding. C.f. @[string_to_utf8].
//!
//!   @value "-utf8"
//!   @value "-utf-8"
//!     UTF-8 decoding. C.f. @[utf8_to_string].
//!
//!   @value "utf16"
//!   @value "utf16be"
//!     (Big endian) UTF-16 encoding. C.f. @[Locale.Charset], encoder
//!     @expr{"utf16be"@}.
//!
//!   @value "utf16le"
//!     Little endian UTF-16 encoding. C.f. @[Locale.Charset], encoder
//!     @expr{"utf16le"@}.
//!
//!   @value "hex"
//!     Hexadecimal encoding, e.g. @expr{"foo"@} is encoded to
//!     @expr{"666f6f"@}. Requires octet (i.e. non-wide) strings.
//!     C.f. @[String.string2hex].
//!
//!   @value "-hex"
//!     Hexadecimal decoding, e.g. @expr{"666f6f"@} is decoded to
//!     @expr{"foo"@}.
//!     C.f. @[String.hex2string].
//!
//!   @value "base64"
//!   @value "base-64"
//!   @value "b64"
//!     Base-64 MIME encoding. Requires octet (i.e. non-wide) strings.
//!     C.f. @[MIME.encode_base64].
//!
//!   @value "-base64"
//!   @value "-base-64"
//!   @value "-b64"
//!     Base-64 MIME decoding.
//!     C.f. @[MIME.decode_base64].
//!
//!   @value "md5"
//!   @value "sha1"
//!   @value "sha256"
//!     Message digest using supplied hash algorithm. Requires octet
//!     (i.e. non-wide) strings. Note that the result is a binary string
//!     so apply e.g. hex encoding afterward to get a printable value.
//!     C.f. @[Crypto.MD5.hash], @[Crypto.SHA1.hash] and
//!     @[Crypto.SHA256.hash].
//!
//!   @value "quotedprintable"
//!   @value "quoted-printable"
//!   @value "qp"
//!     Quoted-Printable MIME encoding. Requires octet (i.e. non-wide)
//!     strings. C.f. @[MIME.encode_qp].
//!
//!   @value "http"
//!     HTTP encoding (i.e. using @expr{%xx@} style escapes) of
//!     characters that never can occur verbatim in URLs. Other
//!     URL-special chars, including @expr{%@}, are not encoded. 8-bit
//!     and wider chars are encoded according to the IRI standard (RFC
//!     3987). C.f. @[Roxen.http_encode_invalids].
//!
//!   @value "url"
//!     Similar to the @expr{"http"@} encoding, but encodes all URI
//!     reserved and excluded chars, that otherwise could have special
//!     meaning; see RFC 3986. This includes @expr{:@}, @expr{/@},
//!     @expr{%@}, and quote chars. C.f. @[Roxen.http_encode_url].
//!
//!   @value "cookie"
//!     Nonstandard HTTP-style encoding for cookie values. The Roxen
//!     HTTP protocol module automatically decodes incoming cookies
//!     using this encoding, so by using this for @expr{Set-Cookie@}
//!     headers etc you will get back the original value in the
//!     @expr{cookie@} scope. Note that @[Roxen.set_cookie] and the
//!     RXML @expr{<set-cookie>@} tag already does this encoding for
//!     you. C.f. @[Roxen.http_encode_cookie].
//!
//!   @value "html"
//!     HTML encoding, for generic text in html documents. This means
//!     encoding chars like @expr{<@}, @expr{&@}, and quotes using
//!     character reference entities.
//!
//!   @value "-html"
//!     HTML decoding of entities (literals and decimal/hexadecimal
//!     representations).
//!
//!   @value "wml"
//!     HTML encoding, and doubling of any @tt{$@}'s.
//!
//!   @value "csv"
//!     CSV (Comma Separated Values) encoding. Properly quotes all
//!     separator characters in CSV records (comma, semicolon, double-quotes
//!     leading spaces and newlines).
//!
//!   @value "pike"
//!     Pike string quoting, for use in e.g. the @tt{<pike></pike>@}
//!     tag. This means backslash escapes for chars that cannot occur
//!     verbatim in Pike string literals.
//!
//!   @value "json"
//!     JSON string quoting. Similar to the @expr{"js"@} quoting,
//!     but keeps strictly to RFC 4627.
//!
//!   @value "js"
//!   @value "javascript"
//!     Javascript string quoting, i.e. using backslash escapes for
//!     @expr{"@}, @expr{\@}, and more.
//!
//!     For safe use inside @tt{<script>@} elements, it quotes some
//!     additional character sequences:
//!
//!     @ul
//!     @item
//!       @tt{</@} is quoted as @tt{<\/@} according to appendix B.3.2
//!       in the HTML 4.01 spec.
//!     @item
//!       @tt{<!--@} is quoted as @tt{<\!--@} according to 4.3.1.2 in
//!       the HTML 5 spec.
//!     @endul
//!
//!     Both are harmless in Javascript string literals in other
//!     contexts.
//!
//!   @value "mysql"
//!     MySQL quoting. This also means backslash escapes, except the
//!     @expr{'@} character which is quoted in SQL style as
//!     @expr{''@}.
//!
//!   @value "sql"
//!   @value "oracle"
//!     SQL/Oracle quoting, i.e. @expr{'@} is encoded as @expr{''@}.
//!
//!     NOTE: Do NOT use this quoting method when creating
//!           sql-queries intended for MySQL!
//!
//!   @value "bytea"
//!     PostgreSQL quoting for BYTEA (binary) values.
//!
//!   @value "mysql-pike"
//!     Compat. MySQL quoting followed by Pike string quoting.
//!     Equvivalent to using @expr{"mysql.pike"@}.
//!
//!   @value "wml-url"
//!     Compat alias for @expr{"url"@}.
//!
//!   @value "dtag"
//!   @value "stag"
//!     Compat. @expr{"dtag"@} encodes @expr{"@} as @expr{"'"'"@}, and
//!     @expr{"stag"@} encodes @expr{'@} as @expr{'"'"'@}. They were
//!     used frequently before rxml 2.0 to quote rxml attributes, but
//!     are no longer necessary.
//!
//!   @value "mysql-dtag"
//!   @value "sql-dtag"
//!   @value "oracle-dtag"
//!     Compat. Same as @expr{"mysql.dtag"@}, @expr{"sql.dtag"@}, and
//!     @expr{"oracle.dtag@}, respectively.
//! @endstring
//!
//! Returns zero if the encoding isn't recognized.
//!
//! @example
//!   UTF8-encode a string for use in a Mysql query in an HTML page:
//!   @expr{roxen_encode(val, "utf8.mysql.html")@}.
string roxen_encode(string val, string encoding)
{
  foreach(encoding/".", string enc) {
    if (!(val = low_roxen_encode(val, enc)))
      return 0;
  }
  return val;
}

string fix_relative( string file, RequestID|void id )
//! Using @expr{@[id]->not_query@}, turns a relative (or already
//! absolute) virtual path into an absolute virtual path, i.e. one
//! rooted at the virtual server's root directory. The returned path
//! is simplified to not contain any @expr{"."@} or @expr{".."@}
//! segments.
{
  Standards.URI uri = Standards.URI("://");
  if (id) {
    uri = Standards.URI(id->not_query, uri);
  }
  uri = Standards.URI(file, uri);
  uri->path = (uri->combine_uri_path("", uri->path)/"/" - ({ ".." })) * "/";  
  string res = sprintf("%s", uri);
  // +(id->misc->path_info?id->misc->path_info:"");
  if (has_prefix(res, "://") && !has_prefix(file, "://") &&
      (!id || !has_prefix(id->not_query, "://"))) {
    // No scheme.
    if (!has_prefix(file, "//") &&
	(!id || !has_prefix(id->not_query, "//"))) {
      // No host.
      return res[sizeof("://")..];
    }
    return res[1..];
  }
  return res;
}

Stdio.File open_log_file( string logfile )
  //! Opens a log file with the provided name, but
  //! with %y, %m, %d and %h replaced with year, month
  //! day and hour. 
{
  mapping m = localtime(time(1));
  m->year += 1900;	// Adjust for years being counted since 1900
  m->mon++;		// Adjust for months being counted 0-11
  if(m->mon < 10) m->mon = "0"+m->mon;
  if(m->mday < 10) m->mday = "0"+m->mday;
  if(m->hour < 10) m->hour = "0"+m->hour;
  logfile = replace(logfile,({"%d","%m","%y","%h" }),
                    ({ (string)m->mday, (string)(m->mon),
                       (string)(m->year),(string)m->hour,}));
  if(strlen(logfile))
  {
    Stdio.File lf=Stdio.File( logfile, "wac");
    if(!lf)
    {
      mkdirhier(logfile);
      if(!(lf=Stdio.File( logfile, "wac")))
      {
        report_error("Failed to open logfile. ("+logfile+"): "
                     + strerror( errno() )+"\n");
        return 0;
      }
    }
    return lf;
  }
  return Stdio.stderr;
}

string tagtime(int t, mapping(string:string) m, RequestID id,
	       function(string, string,
			object:function(int, mapping(string:string):string)) language)
  //! A rather complex function used as presentation function by
  //! several RXML tags. It takes a unix-time integer and a mapping
  //! with formating instructions and returns a string representation
  //! of that time. See the documentation of the date tag.
{
  string res;

  if (m->adjust) t+=(int)m->adjust;

  string lang;
  if(id && id->misc->defines && id->misc->defines->theme_language)
    lang=id->misc->defines->theme_language;
  if(m->lang) lang=m->lang;

  if(m->strftime)
    return strftime(m->strftime, t, lang, language, id);

  if (m->part)
  {
    string sp;
    if(m->type == "ordered")
    {
      m->type="string";
      sp = "ordered";
    }

    switch (m->part)
    {
     case "year":
      return number2string(localtime(t)->year+1900,m,
			   language(lang, sp||"number",id));
     case "month":
      return number2string(localtime(t)->mon+1,m,
			   language(lang, sp||"month",id));
     case "week":
      return number2string(Calendar.ISO.Second(t)->week_no(),
			   m, language(lang, sp||"number",id));
     case "beat":
       //FIXME This should be done inside Calendar.
       mapping lt=gmtime(t);
       int secs=3600;
       secs+=lt->hour*3600;
       secs+=lt->min*60;
       secs+=lt->sec;
       secs%=24*3600;
       float beats=secs/86.4;
       if(!sp) return sprintf("@%03d",(int)beats);
       return number2string((int)beats,m,
                            language(lang, sp||"number",id));

     case "day":
     case "wday":
      return number2string(localtime(t)->wday+1,m,
			   language(lang, sp||"day",id));
     case "date":
     case "mday":
      return number2string(localtime(t)->mday,m,
			   language(lang, sp||"number",id));
     case "hour":
      return number2string(localtime(t)->hour,m,
			   language(lang, sp||"number",id));

     case "min":  // Not part of RXML 2.0
     case "minute":
      return number2string(localtime(t)->min,m,
			   language(lang, sp||"number",id));
     case "sec":  // Not part of RXML 2.0
     case "second":
      return number2string(localtime(t)->sec,m,
			   language(lang, sp||"number",id));
     case "seconds":
      return number2string(t,m,
			   language(lang, sp||"number",id));
     case "yday":
      return number2string(localtime(t)->yday,m,
			   language(lang, sp||"number",id));
     default: return "";
    }
  }
  else if(m->type) {
    switch(m->type)
    {
     case "unix":
       return (string)t;
     case "iso":
      mapping eris=localtime(t);
      if(m->date)
	return sprintf("%d-%02d-%02d",
		       (eris->year+1900), eris->mon+1, eris->mday);
      if(m->time)
	return sprintf("%02d:%02d:%02d", eris->hour, eris->min, eris->sec);

      return sprintf("%d-%02d-%02dT%02d:%02d:%02d",
		     (eris->year+1900), eris->mon+1, eris->mday,
		     eris->hour, eris->min, eris->sec);

     case "http":
       return http_date (t);

     case "discordian":
#if constant (spider.discdate)
      array(string) not=spider.discdate(t);
      res=not[0];
      if(m->year)
	res += " in the YOLD of "+not[1];
      if(m->holiday && not[2])
	res += ". Celebrate "+not[2];
      return res;
#else
      return "Discordian date support disabled";
#endif
     case "stardate":
#if constant (spider.stardate)
      return (string)spider.stardate(t, (int)m->prec||1);
#else
      return "Stardate support disabled";
#endif
    }
  }

  res=language(lang, "date", id)(t,m);

  if(m["case"])
    switch(lower_case(m["case"]))
    {
     case "upper":      return upper_case(res);
     case "lower":      return lower_case(res);
     case "capitalize": return capitalize(res);
    }

#ifdef old_rxml_compat
  // Not part of RXML 2.0
  if (m->upper) {
    res=upper_case(res);
    report_warning("Old RXML in "+(id->query||id->not_query)+
      ", contains upper attribute in a tag. Use case=\"upper\" instead.");
  }
  if (m->lower) {
    res=lower_case(res);
    report_warning("Old RXML in "+(id->query||id->not_query)+
      ", contains lower attribute in a tag. Use case=\"lower\" instead.");
  }
  if (m->cap||m->capitalize) {
    res=capitalize(res);
    report_warning("Old RXML in "+(id->query||id->not_query)+
      ", contains capitalize or cap attribute in a tag. Use case=\"capitalize\" instead.");
  }
#endif
  return res;
}

int time_dequantifier(mapping m, void|int t )
  //! Calculates an integer with how many seconds a mapping
  //! that maps from time units to an integer can be collapsed to.
  //! E.g. (["minutes":"2"]) results in 120.
  //! Valid units are seconds, minutes, beats, hours, days, weeks,
  //! months and years.
{
  int initial = t;
  if (m->seconds) t+=(int)(m->seconds);
  if (m->minutes) t+=(int)(m->minutes)*60;
  if (m->beats)   t+=(int)((float)(m->beats)*86.4);
  if (m->hours)   t+=(int)(m->hours)*3600;
  if (m->days) {
    int days = (int)m->days;
    if(initial) {
      if(days<0)
	t = (Calendar.ISO.Second("unix", t) -
	     Calendar.ISO.Day()*abs(days))->unix_time();
      else
	t = (Calendar.ISO.Second("unix", t) +
	     Calendar.ISO.Day()*days)->unix_time();
    }
    else
      t+=days*24*3600;
  }
  if (m->weeks) {
    int weeks = (int)m->weeks;
    if(initial) {
      if(weeks<0)
	t = (Calendar.ISO.Second("unix", t) -
	     Calendar.ISO.Week()*abs(weeks))->unix_time();
      else
	t = (Calendar.ISO.Second("unix", t) +
	     Calendar.ISO.Week()*weeks)->unix_time();
    }
    else
      t+=weeks*604800;
  }
  if (m->months) {
    int mon = (int)m->months;
    if(initial) {
      if(mon<0)
	t = (Calendar.ISO.Second("unix", t) -
	     Calendar.ISO.Month()*abs(mon))->unix_time();
      else
	t = (Calendar.ISO.Second("unix", t) +
	     Calendar.ISO.Month()*mon)->unix_time();
    }
    else
      t+=(int)(mon*24*3600*30.436849);
  }
  if (m->years) {
    int year = (int)m->years;
    if(initial) {
      if(year<0)
	t = (Calendar.ISO.Second("unix", t) -
	     Calendar.ISO.Year()*abs(year))->unix_time();
      else
	t = (Calendar.ISO.Second("unix", t) +
	     Calendar.ISO.Year()*(int)m->years)->unix_time();
    }
    else
      t+=(int)((float)(m->years)*3600*24*365.242190);
  }
  return (int)t;
}

//! This function is typically used to conveniently calculate
//! timeout values for eg the @[roxen.ArgCache] and @[roxen.ImageCache].
//!
//! It's similar to @[time_dequantifier()], but returns time relative
//! to @expr{time(1)@}, and modifies the argument mapping @[args]
//! destructively.
//!
//! @returns
//!   Returns @[UNDEFINED] if no timeout was specified, and seconds
//!   since @expr{time(1)@} otherwise.
int timeout_dequantifier(mapping args)
{
  int res = UNDEFINED;

  if (args["unix-time"]) {
    // "unix-time" isn't handled by time_dequantifier().
    res = (int)args["unix-time"] - time(1);
  }

  res = time_dequantifier(args, res);

  if (!zero_type(res)) {
    foreach(({ "unix-time", "seconds", "minutes", "beats", "hours",
	       "days", "weeks", "months", "years" }), string arg) {
      m_delete(args, arg);
    }
  }
  return res;
}

class _charset_decoder(object cs)
{
  string decode(string what)
  {
    return cs->clear()->feed(what)->drain();
  }
}

protected class CharsetDecoderWrapper
{
  protected object decoder;
  string charset;

  protected void create (string cs)
  {
    // Would be nice if it was possible to get the canonical charset
    // name back from Locale.Charset so we could use that instead in
    // the client_charset_decoders cache mapping.
    decoder = Locale.Charset.decoder (charset = cs);
  }

  string decode (string what)
  {
    object d = decoder;
    // Relying on the interpreter lock here.
    decoder = 0;
    if (d) d->clear();
    else d = Locale.Charset.decoder (charset);
    string res = d->feed (what)->drain();
    decoder = d;
    return res;
  }
}

protected multiset(string) charset_warned_for = (<>);

constant magic_charset_variable_placeholder = "__MaGIC_RoxEn_Actual___charseT";
constant magic_charset_variable_value = "едц&#x829f;@" + magic_charset_variable_placeholder;

protected mapping(string:function(string:string)) client_charset_decoders = ([
  "http": http_decode_string,
  "html": Parser.parse_html_entities,
  "utf-8": utf8_to_string,
  "utf-16": unicode_to_string,
]);

protected function(string:string) make_composite_decoder (
  function(string:string) outer, function(string:string) inner)
{
  // This is put in a separate function to minimize the size of the
  // dynamic frame for this lambda.
  return lambda (string what) {
	   return outer (inner (what));
	 };
}

function(string:string) get_decoder_for_client_charset (string charset)
//! Returns a decoder function for the given charset, which is on the
//! form returned by @[get_client_charset].
{
  if (function(string:string) dec = client_charset_decoders[charset])
    // This always succeeds to look up the special values "http" and "html".
    return dec;

  if (sscanf (charset, "%s|%s", string outer_cs, string inner_cs)) {
    function(string:string) outer = client_charset_decoders[outer_cs];
    if (!outer)
      outer = client_charset_decoders[outer_cs] =
	CharsetDecoderWrapper (outer_cs)->decode;
    return client_charset_decoders[charset] =
      make_composite_decoder (outer, get_decoder_for_client_charset (inner_cs));
  }

  return client_charset_decoders[charset] =
    CharsetDecoderWrapper (charset)->decode;
}

string get_client_charset (string едц)
//! Returns charset used by the client, given the clients encoding of
//! the string @[magic_charset_variable_value]. See the
//! @expr{<roxen-automatic-charset-variable>@} RXML tag.
//!
//! The return value is usually a charset name, but it can also be any
//! of:
//!
//! @dl
//!   @item "http"
//!     It was URI-encoded (i.e. using @expr{%XX@} style escapes).
//!   @item "html"
//!     It was encoded using HTML character entities.
//! @enddl
//!
//! Furthermore, some cases of double encodings are also detected. In
//! these cases the returned string is a list of the charset names or
//! values described above, separated by @expr{"|"@}, starting with
//! the encoding that was used first.
//!
//! @seealso
//! @[get_client_charset_decoder], @[get_decoder_for_client_charset]
{
  //  If the first character is "%" the whole request is most likely double
  //  encoded. We'll undo the decoding by combining the charset decoder with
  //  http_decode_string().
  if (has_prefix(едц, "%") && !has_prefix(едц, "%%")) {
    report_notice("Warning: Double HTTP encoding detected: %s\n", едц);
    string cs = get_client_charset (http_decode_string(едц));
    if (cs) {
      return cs + "|http";
    } else {
      return "http";
    }
  }

  // Netscape and Safari seem to send "?" for characters that can't be
  // represented by the current character set while IE encodes those
  // characters as entities, while Opera uses "\201" or "?x829f;"...
  string test = едц;
  sscanf (test, "%s\0", test);
  string test2 = test;
  sscanf (test2, "%s@%s", test2, string charset);
  test2 = replace(test2, ({ "\201",  "?x829f;", }), ({ "?", "?", }));

  test = replace(test2,
		 ({ "&aring;", "&#229;", "&#xe5;",
		    "&auml;", "&#228;", "&#xe4;",
		    "&ouml;", "&#246;", "&#xf6;",
		    "&#33439;","&#x829f;", }),
		 ({ "?", "?", "?",
		    "?", "?", "?",
		    "?", "?", "?",
		    "?", "?", }));
  
  switch( test ) {
  case "edv":
  case "edv?":
    report_notice( "Warning: Non 8-bit safe client detected.\n");
    return 0;

  case "едц?":
    if (test2 != test)
      return "html";
    // FALL_THROUGH
  case "едц":
    return "iso-8859-1";
    
  case "\33-Aедц":
  case "\33-A\345\344\366\33$Bgl":
    return "iso-2022-jp";
    
  case "+AOUA5AD2-":
  case "+AOUA5AD2gp8-":
    return "utf-7";
     
  case "ГҐГ¤Г¶?":
    if (test != test2) {
      return "html|utf-8";
    }
    // FALL_THROUGH
  case "ГҐГ¤Г¶":
  case "ГҐГ¤":
  case "ГҐГ¤Г¶\350\212\237":
  case "\357\277\275\357\277\275\357\277\275\350\212\237":
    return "utf-8";

  case "\214\212\232?":
    if (test != test2) {
      return "html|mac";
    }
    // FALL_THROUGH
  case "\214\212\232":
    return "mac";
    
  case "\0е\0д\0ц":
  case "\0е\0д\0ц\202\237":
     return "utf-16";
     
  case "\344\214":
  case "???\344\214":
  case "\217\206H\217\206B\217\206r\344\214": // Netscape sends this (?!)
    return "shift_jis";
  }

  // If the actual charset is valid, return a decoder for that charset
  if (charset)
    catch {
      get_decoder_for_client_charset (charset);
      return charset;
    };
  
  if (!charset_warned_for[test] && (sizeof(charset_warned_for) < 256)) {
    charset_warned_for[test] = 1;
    report_warning( "Unable to find charset decoder for %O "
		    "(vector %O, charset %O).\n",
		    едц, test, charset);
  }
}

function(string:string) get_client_charset_decoder( string едц,
						    RequestID|void id )
//! Returns a decoder for the client's charset, given the clients
//! encoding of the string @[magic_charset_variable_value]. See the
//! @expr{<roxen-automatic-charset-variable>@} RXML tag.
//!
//! @seealso
//! @[get_client_charset]
{
  string charset = get_client_charset (едц);

  if (function(string|function:void) f = id && id->set_output_charset)
    switch (charset) {
      case "iso-2022-jp":		f ("iso-2022"); break;
      case "utf-7":			f ("utf-7"); break;
      case "html|utf-8": case "utf-8":	f ("utf-8"); break;
      case "html|mac": case "mac":	f ("mac"); break;
      case "utf-16":			f (string_to_unicode); break;
      case "shift_jis":			f ("shift_jis"); break;
    }

  return get_decoder_for_client_charset (charset);
}


// Low-level C-roxen optimization functions.
inherit _Roxen;

// This symbol is added by roxenloader if an old _Roxen.make_http_headers()
// is detected.
#if constant(HAVE_OLD__Roxen_make_http_headers)
string make_http_headers(mapping(string:string|array(string)) heads,
			 int(0..1)|void no_terminator)
{
  string res = ::make_http_headers(heads);
  if (no_terminator) {
    // Remove the terminating CRLF.
    return res[..sizeof(res)-3];
  }
  return res;
}
#endif /* constant(HAVE_OLD__Roxen_make_http_headers) */

/*
 * TODO:
 *
 * o Quota: Fix support for the index file.
 *
 */

#ifdef QUOTA_DEBUG
#define QD_WRITE(X)	report_debug(X)
#else /* !QUOTA_DEBUG */
#define QD_WRITE(X)
#endif /* QUOTA_DEBUG */


class QuotaDB
{
#if constant(thread_create)
  object(Thread.Mutex) lock = Thread.Mutex();
#define LOCK()		mixed key__; catch { key__ = lock->lock(); }
#define UNLOCK()	do { if (key__) destruct(key__); } while(0)
#else /* !constant(thread_create) */
#define LOCK()
#define UNLOCK()
#endif /* constant(thread_create) */

  constant READ_BUF_SIZE = 256;
  constant CACHE_SIZE_LIMIT = 512;

  string base;

  object catalog_file;
  object data_file;

  mapping(string:int) new_entries_cache = ([]);
  mapping(string:object) active_objects = ([]);

  array(int) index;
  array(string) index_acc;
  int acc_scale;

  int next_offset;

  protected class QuotaEntry
  {
    string name;
    int data_offset;

    protected int usage;
    protected int quota;

    protected void store()
    {
      LOCK();

      QD_WRITE(sprintf("QuotaEntry::store(): Usage for %O is now %O(%O)\n",
		       name, usage, quota));

      data_file->seek(data_offset);
      data_file->write(sprintf("%4c", usage));

      UNLOCK();
    }

    protected void read()
    {
      LOCK();

      data_file->seek(data_offset);
      string s = data_file->read(4);

      usage = 0;
      sscanf(s, "%4c", usage);

      if (usage < 0) {
	// No negative usage.
	usage = 0;
      }

      QD_WRITE(sprintf("QuotaEntry::read(): Usage for %O is %O(%O)\n",
		       name, usage, quota));

      UNLOCK();
    }

    void create(string n, int d_o, int q)
    {
      QD_WRITE(sprintf("QuotaEntry(%O, %O, %O)\n", n, d_o, q));

      name = n;
      data_offset = d_o;
      quota = q;

      read();
    }

    int check_quota(string uri, int amount)
    {
      QD_WRITE(sprintf("QuotaEntry::check_quota(%O, %O): usage:%d(%d)\n",
		       uri, amount, usage, quota));

      if (!quota) {
	// No quota at all.
	return 0;
      }

      if (amount == 0x7fffffff) {
	// Workaround for FTP.
	return 1;
      }

      return(usage + amount <= quota);
    }

    int allocate(string uri, int amount)
    {
      QD_WRITE(sprintf("QuotaEntry::allocate(%O, %O): usage:%d => %d(%d)\n",
		       uri, amount, usage, usage + amount, quota));

      usage += amount;

      if (usage < 0) {
	// No negative usage...
	usage = 0;
      }

      store();

      return(usage <= quota);
    }

    int deallocate(string uri, int amount)
    {
      return(allocate(uri, -amount));
    }

    int get_usage(string uri)
    {
      return usage;
    }

    void set_usage(string uri, int amount)
    {
      usage = amount;

      store();
    }
  }

  protected object read_entry(int offset, int|void quota)
  {
    QD_WRITE(sprintf("QuotaDB::read_entry(%O, %O)\n", offset, quota));

    catalog_file->seek(offset);

    string data = catalog_file->read(READ_BUF_SIZE);

    if (data == "") {
      QD_WRITE(sprintf("QuotaDB::read_entry(%O, %O): At EOF\n",
		       offset, quota));

      return 0;
    }

    int len;
    int data_offset;
    string key;

    sscanf(data[..7], "%4c%4c", len, data_offset);
    if (len > sizeof(data)) {
      key = data[8..] + catalog_file->read(len - sizeof(data));

      len -= 8;

      if (sizeof(key) != len) {
	error(sprintf("Failed to read catalog entry at offset %d.\n"
		      "len: %d, sizeof(key):%d\n",
		      offset, len, sizeof(key)));
      }
    } else {
      key = data[8..len-1];
      catalog_file->seek(offset + 8 + sizeof(key));
    }

    return QuotaEntry(key, data_offset, quota);
  }

  protected Stdio.File open(string fname, int|void create_new)
  {
    Stdio.File f = Stdio.File();
    string mode = create_new?"rwc":"rw";

    if (!f->open(fname, mode)) {
      error(sprintf("Failed to open quota file %O.\n", fname));
    }
    if (f->try_lock && !f->try_lock()) {
      error(sprintf("Failed to lock quota file %O.\n", fname));
    }
    return(f);
  }

  protected void init_index_acc()
  {
    /* Set up the index accellerator.
     * sizeof(index_acc) ~ sqrt(sizeof(index))
     */
    acc_scale = 1;
    if (sizeof(index)) {
      int i = sizeof(index)/2;

      while (i) {
	i /= 4;
	acc_scale *= 2;
      }
    }
    index_acc = allocate((sizeof(index) + acc_scale -1)/acc_scale);

    QD_WRITE(sprintf("QuotaDB()::init_index_acc(): "
		     "sizeof(index):%d, sizeof(index_acc):%d acc_scale:%d\n",
		     sizeof(index), sizeof(index_acc), acc_scale));
  }

  void rebuild_index()
  {
    array(string) new_keys = sort(indices(new_entries_cache));

    int prev;
    array(int) new_index = ({});

    foreach(new_keys, string key) {
      QD_WRITE(sprintf("QuotaDB::rebuild_index(): key:%O lo:0 hi:%d\n",
		       key, sizeof(index_acc)));

      int lo;
      int hi = sizeof(index_acc);
      if (hi) {
	do {
	  // Loop invariants:
	  //   hi is an element > key.
	  //   lo-1 is an element < key.

	  int probe = (lo + hi)/2;

	  QD_WRITE(sprintf("QuotaDB::rebuild_index(): acc: "
			   "key:%O lo:%d probe:%d hi:%d\n",
			   key, lo, probe, hi));

	  if (!index_acc[probe]) {
	    object e = read_entry(index[probe * acc_scale]);

	    index_acc[probe] = e->name;
	  }
	  if (index_acc[probe] < key) {
	    lo = probe + 1;
	  } else if (index_acc[probe] > key) {
	    hi = probe;
	  } else {
	    /* Found */
	    // Shouldn't happen...
	    break;
	  }
	} while(lo < hi);

	if (lo < hi) {
	  // Found...
	  // Shouldn't happen, but...
	  // Skip to the next key...
	  continue;
	}
	if (hi) {
	  hi *= acc_scale;
	  lo = hi - acc_scale;

	  if (hi > sizeof(index)) {
	    hi = sizeof(index);
	  }

	  do {
	    // Same loop invariants as above.

	    int probe = (lo + hi)/2;

	    QD_WRITE(sprintf("QuotaDB::rebuild_index(): "
			     "key:%O lo:%d probe:%d hi:%d\n",
			     key, lo, probe, hi));
	    
	    object e = read_entry(index[probe]);
	    if (e->name < key) {
	      lo = probe + 1;
	    } else if (e->name > key) {
	      hi = probe;
	    } else {
	      /* Found */
	      // Shouldn't happen...
	      break;
	    }
	  } while (lo < hi);
	  if (lo < hi) {
	    // Found...
	    // Shouldn't happen, but...
	    // Skip to the next key...
	    continue;
	  }
	}
	new_index += index[prev..hi-1] + ({ new_entries_cache[key] });
	prev = hi;
      } else {
	new_index += ({ new_entries_cache[key] });
      }
    }

    // Add the trailing elements...
    new_index += index[prev..];

    QD_WRITE("Index rebuilt.\n");

    LOCK();

    object index_file = open(base + ".index.new", 1);
    string to_write = sprintf("%@4c", new_index);
    if (index_file->write(to_write) != sizeof(to_write)) {
      index_file->close();
      rm(base + ".index.new");
    } else {
      mv(base + ".index.new", base + ".index");
    }

    index = new_index;
    init_index_acc();

    UNLOCK();

    foreach(new_keys, string key) {
      m_delete(new_entries_cache, key);
    }
  }

  protected object low_lookup(string key, int quota)
  {
    QD_WRITE(sprintf("QuotaDB::low_lookup(%O, %O)\n", key, quota));

    int cat_offset;

    if (!zero_type(cat_offset = new_entries_cache[key])) {
      QD_WRITE(sprintf("QuotaDB::low_lookup(%O, %O): "
		       "Found in new entries cache.\n", key, quota));
      return read_entry(cat_offset, quota);
    }

    /* Try the index file. */

    /* First use the accellerated index. */
    int lo;
    int hi = sizeof(index_acc);
    if (hi) {
      do {
	// Loop invariants:
	//   hi is an element that is > key.
	//   lo-1 is an element that is < key.
	int probe = (lo + hi)/2;

	QD_WRITE(sprintf("QuotaDB:low_lookup(%O): "
			 "In acc: lo:%d, probe:%d, hi:%d\n",
			 key, lo, probe, hi));

	if (!index_acc[probe]) {
	  object e = read_entry(index[probe * acc_scale], quota);

	  index_acc[probe] = e->name;

	  if (key == e->name) {
	    /* Found in e */
	    QD_WRITE(sprintf("QuotaDB:low_lookup(%O): In acc: Found at %d\n",
			     key, probe * acc_scale));
	    return e;
	  }
	}
	if (index_acc[probe] < key) {
	  lo = probe + 1;
	} else if (index_acc[probe] > key) {
	  hi = probe;
	} else {
	  /* Found */
	  QD_WRITE(sprintf("QuotaDB:low_lookup(%O): In acc: Found at %d\n",
			   key, probe * acc_scale));
	  return read_entry(index[probe * acc_scale], quota);
	}
      } while(lo < hi);
      // At this point hi is the first element that is > key.
      // Not in the accellerated index.

      if (hi) {
	// Go to disk

	hi *= acc_scale;
	lo = hi - acc_scale;

	if (hi > sizeof(index)) {
	  hi = sizeof(index);
	}

	do {
	  // Same loop invariant as above.

	  int probe = (lo + hi)/2;

	  QD_WRITE(sprintf("QuotaDB:low_lookup(%O): lo:%d, probe:%d, hi:%d\n",
			   key, lo, probe, hi));

	  object e = read_entry(index[probe], quota);
	
	  if (e->name < key) {
	    lo = probe + 1;
	  } else if (e->name > key) {
	    hi = probe;
	  } else {
	    /* Found */
	    QD_WRITE(sprintf("QuotaDB:low_lookup(%O): Found at %d\n",
			     key, probe));
	    return e;
	  }
	} while (lo < hi);
      }
    }

    QD_WRITE(sprintf("QuotaDB::low_lookup(%O): Not found\n", key));

    return 0;
  }

  object lookup(string key, int quota)
  {
    QD_WRITE(sprintf("QuotaDB::lookup(%O, %O)\n", key, quota));

    LOCK();

    object res;

    if (res = active_objects[key]) {
      QD_WRITE(sprintf("QuotaDB::lookup(%O, %O): User in active objects.\n",
		       key, quota));

      return res;
    }
    if (res = low_lookup(key, quota)) {
      active_objects[key] = res;

      return res;
    }

    QD_WRITE(sprintf("QuotaDB::lookup(%O, %O): New user.\n", key, quota));

    // Search to EOF.
    data_file->seek(-1);
    data_file->read(1);

    catalog_file->seek(next_offset);

    // We should now be at EOF.

    int data_offset = data_file->tell();

    // Initialize.
    if (data_file->write(sprintf("%4c", 0)) != 4) {
      error(sprintf("write() failed for quota data file!\n"));
    }
    string entry = sprintf("%4c%4c%s", sizeof(key)+8, data_offset, key);

    if (catalog_file->write(entry) != sizeof(entry)) {
      error(sprintf("write() failed for quota catalog file!\n"));
    }

    new_entries_cache[key] = next_offset;
    next_offset = catalog_file->tell();

    if (sizeof(new_entries_cache) > CACHE_SIZE_LIMIT) {
      rebuild_index();
    }

    // low_lookup will always succeed at this point.
    return low_lookup(key, quota);
  }

  void create(string base_name, int|void create_new)
  {
    base = base_name;

    catalog_file = open(base_name + ".cat", create_new);
    data_file = open(base_name + ".data", create_new);
    object index_file = open(base_name + ".index", 1);

    set_weak_flag(active_objects, 1);

    /* Initialize the new_entries table. */
    array index_st = index_file->stat();
    if (!index_st || !sizeof(index_st)) {
      error(sprintf("stat() failed for quota index file!\n"));
    }
    array data_st = data_file->stat();
    if (!data_st || !sizeof(data_st)) {
      error(sprintf("stat() failed for quota data file!\n"));
    }
    if (index_st[1] < 0) {
      error("quota index file isn't a regular file!\n");
    }
    if (data_st[1] < 0) {
      error("quota data file isn't a regular file!\n");
    }
    if (data_st[1] < index_st[1]) {
      error("quota data file is shorter than the index file!\n");
    }
    if (index_st[1] & 3) {
      error("quota index file has odd length!\n");
    }
    if (data_st[1] & 3) {
      error("quota data file has odd length!\n");
    }

    /* Read the index, and find the last entry in the catalog file.
     */
    int i;
    array(string) index_str = index_file->read()/4;
    index = allocate(sizeof(index_str));

    if (sizeof(index_str) && (sizeof(index_str[-1]) != 4)) {
      error("Truncated read of the index file!\n");
    }

    foreach(index_str, string offset_str) {
      int offset;
      sscanf(offset_str, "%4c", offset);
      index[i++] = offset;
      if (offset > next_offset) {
	next_offset = offset;
      }
    }

    init_index_acc();

    if (sizeof(index)) {
      /* Skip past the last entry in the catalog file */
      mixed entry = read_entry(next_offset);
      next_offset = catalog_file->tell();
    }

    if (index_st[1] < data_st[1]) {
      /* Put everything else in the new_entries_cache */
      while (mixed entry = read_entry(next_offset)) {
	new_entries_cache[entry->name] = next_offset;
	next_offset = catalog_file->tell();
      }

      /* Clean up the index. */
      rebuild_index();
    }
  }
}


#define CTX()   
class EScope(string scope)
{
  void delete( string var )
  {
    RXML.Context ctx = RXML.get_context( );  
    ctx->delete_var( var, scope );
  }

  string name()
  {
    RXML.Context ctx = RXML.get_context( );  
    return scope == "_" ? ctx->current_scope() : scope;
  }

  protected mixed `[]( string what )
  {
    // NB: This function may be called by eg master()->describe_object()
    //     with symbols such as "is_resolv_dirnode", in contexts where
    //     the scope doesn't exist. cf [bug 6451].
    RXML.Context ctx = RXML.get_context( );
    return ctx->scopes[scope || "_"] && ctx->get_var( what, scope );
  }

  protected mixed `->( string what )
  {
    return `[]( what );
  }

  protected mixed `[]=( string what, mixed nval )
  {
    RXML.Context ctx = RXML.get_context( );  
    ctx->set_var( what, nval, scope );
    return nval;
  }

  protected mixed `->=( string what, mixed nval )
  {
    return `[]=( what, nval );
  }

  protected array(string) _indices( )
  {
    RXML.Context ctx = RXML.get_context( );  
    return ctx->list_var( scope );
  } 

  protected array(string) _values( )
  {
    RXML.Context ctx = RXML.get_context( );  
    return map( ctx->list_var( scope ), `[] );
  }
}

class SRestore
{
  mapping osc = ([]);
  void destroy()
  {
    foreach( indices( osc ), string o ) 
      add_constant( o, osc[o] );
    add_constant( "roxen", roxenp() );
  }
}

SRestore add_scope_constants( string|void name, function|void add_constant )
{
  SRestore res = SRestore();
  mapping ac = all_constants();
  if(!add_constant)
    add_constant = predef::add_constant;
  if(!name) name = "";
  if( RXML.get_context() )
  {
    foreach( RXML.get_context()->list_scopes()|({"_"}), string scope )
    {
      if( add_constant == predef::add_constant )
	res->osc[ name+scope ] = ac[ name+scope ];
      add_constant( name+scope, EScope( scope ) );
    }
  }
  return res;
}

//! A mapping suitable for Parser.HTML.add_entities to initialize it
//! to transform the standard character reference entities.
mapping(string:string) parser_charref_table =
  lambda () {
    mapping(string:string) table = ([]);
    for (int i = 0; i < sizeof (replace_entities); i++) {
      string chref = replace_entities[i];
      table[chref[1..sizeof (chref) - 2]] = replace_values[i];
    }
    return table;
  }();

//! The inverse mapping to parser_charref_table.
mapping(string:string) inverse_charref_table =
  lambda () {
    mapping(string:string) table = ([]);
    for (int i = 0; i < sizeof (replace_entities); i++) {
      string chref = replace_entities[i];
      table[replace_values[i]] = chref[1..sizeof (chref) - 2];
    }
    return table;
  }();

string decode_charref (string chref)
//! Decodes a character reference entity either on symbolic or numeric
//! form. Returns zero if the reference isn't recognized.
{
  if (sizeof (chref) <= 2 || chref[0] != '&' || chref[-1] != ';') return 0;
  if (chref[1] != '#') return parser_charref_table[chref[1..sizeof (chref) - 2]];
  if (sscanf (chref,
	      (<'x', 'X'>)[chref[2]] ? "&%*2s%x;%*c" : "&%*c%d;%*c",
	      int c) == 2)
    catch {return (string) ({c});};
  return 0;
}

string|program safe_compile( string code )
{
  program ret;
  roxenloader.LowErrorContainer ec = roxenloader.LowErrorContainer();
  roxenloader.push_compile_error_handler( ec );
  catch(ret = compile_string( code ));
  roxenloader.pop_compile_error_handler( );
  if( !ret ) return ec->get();
  return ret;
}

string encode_charref (string char)
//! Encodes a character to a character reference entity. The symbolic
//! form is preferred over the numeric. The decimal variety of the
//! numeric form is used (since it's understood better than the
//! hexadecimal form by at least Netscape 4).
{
  if (string chref = inverse_charref_table[char]) return "&" + chref + ";";
  return sprintf ("&#%d;", char[0]);
}


// RXML complementary stuff shared between configurations.

class ScopeRequestHeader {
  inherit RXML.Scope;

  mixed `[] (string var, void|RXML.Context c, void|string scope, void|RXML.Type type) {
    string|array(string) val = (c || RXML_CONTEXT)->id->request_headers[var];
    if(!val)
      return RXML.nil;
    if(type)
    {
      if(arrayp(val) && type->subtype_of (RXML.t_any_text))
	val *= "\0";
      return type->encode(val);
    }
    return val;
  }

  array(string) _indices(void|RXML.Context c) {
    return indices((c || RXML_CONTEXT)->id->request_headers);
  }

  array(string) _values(void|RXML.Context c) {
    return values((c || RXML_CONTEXT)->id->request_headers);
  }

  string _sprintf (int flag)
  {
    return flag == 'O' && "RXML.Scope(request-header)";
  }
}

class ScopeRoxen {
  inherit RXML.Scope;

  string pike_version=predef::version();
  int ssl_strength=0;

#if constant(SSL)
  void create() {
    ssl_strength=40;
#if constant(SSL.constants.CIPHER_des)
    if(SSL.constants.CIPHER_algorithms[SSL.constants.CIPHER_des])
      ssl_strength=128;
    if(SSL.constants.CIPHER_algorithms[SSL.constants.CIPHER_3des])
      ssl_strength=168;
#endif /* !constant(SSL.constants.CIPHER_des) */
  }
#endif

  mixed `[] (string var, void|RXML.Context c, void|string scope, void|RXML.Type type) {
    if (!c) c = RXML_CONTEXT;
    
    mixed val = c->misc->scope_roxen[var];
    if(!zero_type(val))
    {
      if (objectp(val) && val->rxml_var_eval) return val;
      return ENCODE_RXML_TEXT(val, type);
    }
    
    switch(var)
    {
     case "nodename":
       return uname()->nodename;
     case "uptime":
       c->id->lower_max_cache (1);
       return ENCODE_RXML_INT(time(1)-roxenp()->start_time, type);
     case "uptime-days":
       c->id->lower_max_cache (3600 * 2);
       return ENCODE_RXML_INT((time(1)-roxenp()->start_time)/3600/24, type);
     case "uptime-hours":
       c->id->lower_max_cache (1800);
       return ENCODE_RXML_INT((time(1)-roxenp()->start_time)/3600, type);
     case "uptime-minutes":
       c->id->lower_max_cache (60);
       return ENCODE_RXML_INT((time(1)-roxenp()->start_time)/60, type);
     case "hits-per-minute":
       c->id->lower_max_cache (2);
       // FIXME: Use float here instead?
       return ENCODE_RXML_INT(c->id->conf->requests / ((time(1)-roxenp()->start_time)/60 + 1),
			      type);
     case "hits":
       c->id->set_max_cache (0);
       return ENCODE_RXML_INT(c->id->conf->requests, type);
     case "sent-mb":
       c->id->lower_max_cache (10);
       // FIXME: Use float here instead?
       return ENCODE_RXML_TEXT(sprintf("%1.2f",c->id->conf->sent / (1024.0*1024.0)), type);
     case "sent":
       c->id->set_max_cache (0);
       return ENCODE_RXML_INT(c->id->conf->sent, type);
     case "sent-per-minute":
       c->id->lower_max_cache (2);
       return ENCODE_RXML_INT(c->id->conf->sent / ((time(1)-roxenp()->start_time)/60 || 1),
			      type);
     case "sent-kbit-per-second":
       c->id->lower_max_cache (2);
       // FIXME: Use float here instead?
       return ENCODE_RXML_TEXT(sprintf("%1.2f",((c->id->conf->sent*8)/1024.0/
						(time(1)-roxenp()->start_time || 1))),
			       type);
     case "ssl-strength":
       return ENCODE_RXML_INT(ssl_strength, type);
     case "pike-version":
       return ENCODE_RXML_TEXT(pike_version, type);
     case "version":
       return ENCODE_RXML_TEXT(roxenp()->version(), type);
     case "base-version":
       return ENCODE_RXML_TEXT(roxen_ver, type);
     case "build":
       return ENCODE_RXML_TEXT(roxen_build, type);
     case "dist-version":
       return ENCODE_RXML_TEXT(roxen_dist_version, type);
     case "dist-os":
       return ENCODE_RXML_TEXT(roxen_dist_os, type);
     case "product-name":
       return ENCODE_RXML_TEXT(roxen_product_name, type);     
     case "time":
       c->id->lower_max_cache (1);
       return ENCODE_RXML_INT(time(),  type);
     case "server":
       return ENCODE_RXML_TEXT (c->id->url_base(), type);
      case "domain": {
	//  Handle hosts and adresses including IPv6 format
	Standards.URI u = Standards.URI(c->id->url_base());
	string tmp = u && u->host;
	if (tmp && has_value(tmp, ":"))
	  tmp = "[" + tmp + "]";
	return ENCODE_RXML_TEXT(tmp || "", type);
      }
     case "locale":
       c->id->set_max_cache (0);
       return ENCODE_RXML_TEXT(roxenp()->locale->get(), type);
     case "path":
       return ENCODE_RXML_TEXT(c->id->misc->site_prefix_path, type);
     case "unique-id":
       return ENCODE_RXML_TEXT(roxenp()->create_unique_id(), type);

     case "license-type": {
       object key = c->id->conf->getvar("license")->get_key();
       return ENCODE_RXML_TEXT(key?key->type():"none", type);
     }
     case "license-warnings": {
       object key = c->id->conf->getvar("license")->get_key();
       return ENCODE_RXML_TEXT(key?sizeof(key->get_warnings()):0, type);
     }

    case "auto-charset-variable":
      return ENCODE_RXML_TEXT("magic_roxen_automatic_charset_variable", type);
    case "auto-charset-value":
      return ENCODE_RXML_TEXT(magic_charset_variable_value, type);

    case "null":
      // Note that we don't need to check compat_level < 5.2 and
      // return compat_5_1_null here, since this constant didn't exist
      // prior to 5.2.
      return Val->null;
    case "true":
      return Val->true;
    case "false":
      return Val->false;
    }
    
    return RXML.nil;
  }

  mixed `[]= (string var, mixed val, void|RXML.Context c, 
	      void|string scope_name) {
    if (!c) c = RXML_CONTEXT;
    return c->misc->scope_roxen[var]=val;
  }

  array(string) _indices(void|RXML.Context c) {
    if (!c) c = RXML_CONTEXT;
    return
      Array.uniq(indices(c->misc->scope_roxen) +
		 ({ "uptime", "uptime-days", "uptime-hours", "uptime-minutes",
		    "hits-per-minute", "hits", "sent-mb", "sent", "unique-id",
		    "sent-per-minute", "sent-kbit-per-second", "ssl-strength",
		    "pike-version", "version", "time", "server", "domain",
		    "locale", "path", "auto-charset-variable",
		    "auto-charset-value" }) );
  }

  void _m_delete (string var, void|RXML.Context c, void|string scope_name) {
    if (!c) c = RXML_CONTEXT;
    predef::m_delete(c->misc->scope_roxen, var);
  }

  string _sprintf (int flag) { return flag == 'O' && "RXML.Scope(roxen)"; }
}

int get_ssl_strength(string ignored, RequestID id)
{
  if (!id->my_fd || !id->my_fd->get_peer_certificate_info ||
      !id->my_fd->query_connection())
    return 0;
  return id->my_fd->query_connection()->session->cipher_spec->key_bits;
}

class ScopePage {
  inherit RXML.Scope;
  constant converter=(["fgcolor":"fgcolor", "bgcolor":"bgcolor",
		       "theme-bgcolor":"theme_bgcolor", "theme-fgcolor":"theme_fgcolor",
		       "theme-language":"theme_language"]);

  mixed `[] (string var, void|RXML.Context c, void|string scope, void|RXML.Type type) {
    if (!c) c = RXML_CONTEXT;
    
    mixed val;
    if(converter[var])
      val = c->misc[converter[var]];
    else
      val = c->misc->scope_page[var];
    if(!zero_type(val))
    {
      if (objectp (val) && val->rxml_var_eval)
	return val;
      return ENCODE_RXML_TEXT(val, type);
    }
    
    switch (var) {
      case "pathinfo": return ENCODE_RXML_TEXT(c->id->misc->path_info, type);
      case "realfile": return ENCODE_RXML_TEXT(c->id->realfile, type);
      case "virtroot": return ENCODE_RXML_TEXT(c->id->virtfile, type);
      case "mountpoint":
	string s = c->id->virtfile || "";
	return ENCODE_RXML_TEXT(s[sizeof(s)-1..sizeof(s)-1] == "/"? s[..sizeof(s)-2]: s, type); 
      case "virtfile": // Fallthrough from deprecated name.
      case "path": return ENCODE_RXML_TEXT(c->id->not_query, type);
      case "query": return ENCODE_RXML_TEXT(c->id->query, type);
      case "url": return ENCODE_RXML_TEXT(c->id->raw_url, type);
      case "last-true": return ENCODE_RXML_INT(c->misc[" _ok"], type);
      case "language": return ENCODE_RXML_TEXT(c->misc->language, type);
      case "scope": return ENCODE_RXML_TEXT(c->current_scope(), type);
      case "filesize": return ENCODE_RXML_INT(c->misc[" _stat"]?
					      c->misc[" _stat"][1]:-4, type);
      case "self": return ENCODE_RXML_TEXT( (c->id->not_query/"/")[-1], type);
      case "ssl-strength":
	c->id->register_vary_callback("host", get_ssl_strength);
	return ENCODE_RXML_INT(get_ssl_strength("", c->id), type);
      case "dir":
	array parts = c->id->not_query/"/";
	return ENCODE_RXML_TEXT( parts[..sizeof(parts)-2]*"/"+"/", type);
      case "counter":
	return ENCODE_RXML_INT(++c->misc->internal_counter, type);
    }
    
    return RXML.nil;
  }

  mixed `[]= (string var, mixed val, void|RXML.Context c, void|string scope_name) {
    if (!c) c = RXML_CONTEXT;
    switch (var) {
      case "pathinfo": return c->id->misc->path_info = val;
    }
    if(converter[var])
      return c->misc[converter[var]]=val;
    return c->misc->scope_page[var]=val;
  }

  array(string) _indices(void|RXML.Context c) {
    if (!c) c = RXML_CONTEXT;
    array ind=indices(c->misc->scope_page) +
      ({ "pathinfo", "realfile", "virtroot", "mountpoint", "virtfile", "path", "query",
	 "url", "last-true", "language", "scope", "filesize", "self",
	 "ssl-strength", "dir", "counter" });
    foreach(indices(converter), string def)
      if(c->misc[converter[def]]) ind+=({def});
    return Array.uniq(ind);
  }

  void _m_delete (string var, void|RXML.Context c, void|string scope_name) {
    if (!c) c = RXML_CONTEXT;
    switch (var) {
      case "pathinfo":
	predef::m_delete (c->id->misc, "pathinfo");
	return;
    }
    if(converter[var]) {
      if(var[0..4]=="theme")
	predef::m_delete(c->misc, converter[var]);
      else
	::_m_delete(var, c, scope_name);
      return;
    }
    predef::m_delete(c->misc->scope_page, var);
  }

  string _sprintf (int flag) { return flag == 'O' && "RXML.Scope(page)"; }
}

class ScopeCookie {
  inherit RXML.Scope;

  mixed `[] (string var, void|RXML.Context c, void|string scope, void|RXML.Type type) {
    if (!c) c = RXML_CONTEXT;
    if (c->id->conf->compat_level() < 5.0)
      c->id->set_max_cache (0);
    return ENCODE_RXML_TEXT(c->id->cookies[var], type);
  }

  mixed `[]= (string var, mixed val, void|RXML.Context c, void|string scope_name) {
    if (mixed err = catch (val = (string) val || ""))
      RXML.parse_error ("Cannot set cookies of type %t.\n", val);
    if (!c) c = RXML_CONTEXT;
    if(c->id->cookies[var]!=val) {
      // Note: We should not use c->set_var here to propagate the
      // change event, since this code is called by it. It's also
      // called dynamically to install the p-coded changes in the
      // cookie scope, so we don't use c->id->add_response_header
      // below.
      c->id->cookies[var]=val;
      add_http_header(c->misc[" _extra_heads"], "Set-Cookie", http_encode_cookie(var)+
		      "="+http_encode_cookie( val )+
		      "; expires="+http_date(time(1)+(3600*24*365*2))+"; path=/");
    }
    return val;
  }

  array(string) _indices(void|RXML.Context c) {
    if (!c) c = RXML_CONTEXT;
    if (c->id->conf->compat_level() < 5.0)
      c->id->set_max_cache (0);
    return indices(c->id->cookies);
  }

  void _m_delete (string var, void|RXML.Context c, void|string scope_name) {
    if (!c) c = RXML_CONTEXT;
    if(!c->id->cookies[var]) return;
    // Note: The same applies here as in `[]= above.
    predef::m_delete(c->id->cookies, var);
    add_http_header(c->misc[" _extra_heads"], "Set-Cookie",
		    http_encode_cookie(var)+"=; expires=Thu, 01-Jan-70 00:00:01 GMT; path=/");
  }

  string _sprintf (int flag) { return flag == 'O' && "RXML.Scope(Cookie)"; }
}

RXML.Scope scope_request_header=ScopeRequestHeader();
RXML.Scope scope_roxen=ScopeRoxen();
RXML.Scope scope_page=ScopePage();
RXML.Scope scope_cookie=ScopeCookie();

class ScopeModVar
{
  class Modules( mapping module, string sname )
  {
    class ModVars( RoxenModule mod ) 
    {
      class Var(object var )
      {
	inherit RXML.Value;
	mixed cast( string type )
	{
	  switch( type )
	  {
	    case "string": return (string)var->query();
	    case "int": return (int)var->query();
	    case "float": return (float)var->query();
	    case "array": return (array)var->query();
	  }
	}


    	mixed rxml_var_eval( RXML.Context ctx, string vn, string scp,
			    void|RXML.Type type )
	{
	  mixed res = var->query();
	  if( type )
	    res = type->encode( res );
	  return res;
	}
      }

      mixed cast( string type )
      {
	switch( type )
	{
	  case "string":
	    return roxenp()->find_module( sname ) ?
	      roxenp()->find_module( sname )->get_name() : sname;
	}
      }

      array _indices()
      {
	mapping m = mod->getvars();
	return sort( filter( indices(m),
			     lambda(string n) {
			       return m[n]->get_flags()&VAR_PUBLIC;
			     } ) );
      }


      mixed `[]( string what )
      {
	object var;
	if( (var = mod->getvar( what )) )
	{
	  if( (var->get_flags() & VAR_PUBLIC) )
	    return Var( var );
	  else
	    RXML.parse_error("The variable "+what+" is not public\n");
	} else
	  RXML.parse_error("The variable "+what+" does not exist\n");
      }
    }

    mixed cast( string type )
    {
      switch( type )
      {
	case "string":
	  return roxenp()->find_module( sname ) ?
	    roxenp()->find_module( sname )->get_name() : sname;
      }
    }

    array _indices()
    {
      return sort(indices( module ));
    }

    
    mixed `[]( string what )
    {
      mixed mod;
      if( (mod = (int)what) )
	if( (mod = module[ mod-1 ]) )
	  return ModVars( module[mod-1] );
// 	else
// 	  RXML.parse_error("The module copy #"+mod+
// 			   " does not exist for this module\n");
      return ModVars( values( module )[0] )[ what ];
    }
  }
  
  mixed `[]( string what, void|RXML.Context ctx )
  {
    if( what == "global" )
      return Modules( ([ 0:roxenp() ]), "roxen" );
    if (!ctx) ctx = RXML_CONTEXT;
    if( what == "site" )
      return Modules( ([ 0: ctx->id->conf ]), "site" );
    if( !ctx->id->conf->modules[ what ] )
      RXML.parse_error("The module "+what+" does not exist\n");
    return Modules( ctx->id->conf->modules[ what ], what );
  }

  array _indices (void|RXML.Context ctx)
  {
    return ({ "global", "site" }) +
      sort(indices((ctx || RXML_CONTEXT)->id->conf->modules));
  }
}

ScopeModVar scope_modvar = ScopeModVar();

class FormScope
{
  inherit RXML.Scope;

  mixed `[]=( string index, mixed newval, void|RXML.Context ctx )
  {
    if(!ctx) ctx = RXML_CONTEXT;
    if( arrayp( newval ) )
      ctx->id->real_variables[ index ] = newval;
    else
      ctx->id->real_variables[ index ] = ({ newval });
    return newval;
  }

  mixed `[] (string what, void|RXML.Context ctx,
	     void|string scope_name, void|RXML.Type type)
  {
    if (!ctx) ctx = RXML_CONTEXT;
    mapping variables = ctx->id->real_variables;
    if( zero_type(variables[what]) ) return RXML.nil;
    mixed q = variables[ what ];
    if( arrayp(q) && sizeof( q ) == 1 )
      q = q[0];
    if (type && !(objectp (q) && q->rxml_var_eval)) {
      if (arrayp(q) && type->subtype_of (RXML.t_any_text))
	q *= "\0";
      return type->encode (q);
    }
    else return q;
  }

  void _m_delete (string var, void|RXML.Context ctx, void|string scope_name)
  {
    if (!ctx) ctx = RXML_CONTEXT;
    predef::m_delete (ctx->id->real_variables, var);
  }

  array _indices( void|RXML.Context ctx )
  {
    if(!ctx) ctx = RXML_CONTEXT;
    return indices( ctx->id->real_variables );
  }
}

FormScope scope_form = FormScope();

RXML.TagSet entities_tag_set = class
// This tag set always has the lowest priority.
{
  inherit RXML.TagSet;

  void entities_prepare_context (RXML.Context c) {
    c->add_scope("request-header", scope_request_header);
    c->misc->scope_roxen=([]);
    c->add_scope("roxen",scope_roxen);
    c->misc->scope_page=([]);
    c->add_scope("page",scope_page);
    c->add_scope("cookie", scope_cookie);
    c->add_scope("modvar", scope_modvar);
    c->add_scope("form", scope_form );
    c->add_scope("client", c->id->client_var);
    c->add_scope("var", ([]) );
  }


  void create()
  {
    ::create (0, "entities_tag_set");
    prepare_context = entities_prepare_context;
    // Note: No string entities are replaced when the result type for
    // the parser is t_xml or t_html.
    add_string_entities (parser_charref_table);
  }
}();


constant monthnum=(["Jan":0, "Feb":1, "Mar":2, "Apr":3, "May":4, "Jun":5,
		    "Jul":6, "Aug":7, "Sep":8, "Oct":9, "Nov":10, "Dec":11,
		    "jan":0, "feb":1, "mar":2, "apr":3, "may":4, "jun":5,
		    "jul":6, "aug":7, "sep":8, "oct":9, "nov":10, "dec":11,]);

#define MAX_SINCE_CACHE 16384
protected mapping(string:int) since_cache=([ ]);
array(int) parse_since(string date)
{
  if(!date || sizeof(date)<14) return({0,-1});
  int t=0, length = -1;

#if constant(mktime)
  string dat=lower_case(date);
  sscanf(dat+"; length=", "%*s, %s; length=%d", dat, length);

  if(!(t=since_cache[dat])) {
    int day, year = -1, month, hour, minute, second;
    string m;
    if((sscanf(dat, "%d-%d-%d %d:%d:%d", year, month, day, hour, minute, second)>2) ||
       (sscanf(dat, "%d-%d-%dT%d:%d:%d", year, month, day, hour, minute, second)>2))
    {
      // ISO-format.
    } else if(sscanf(dat, "%d-%s-%d %d:%d:%d", day, m, year, hour, minute, second)>2)
    {
      month=monthnum[m];
    } else if(!(int)dat) {
      sscanf(dat, "%*[^ ] %s %d %d:%d:%d %d", m, day, hour, minute, second, year);
      month=monthnum[m];
    } else {
      sscanf(dat, "%d %s %d %d:%d:%d", day, m, year, hour, minute, second);
      month=monthnum[m];
    }

    if(year >= 0) {
      // Fudge year to be localtime et al compatible.
      if (year < 60) {
	// Assume year 0 - 59 is really year 2000 - 2059.
	// Can't people stop using two digit years?
	year += 100;
      } else if (year >= 1900) {
	year -= 1900;
      }
      catch {
	t = mktime(second, minute, hour, day, month, year, 0, 0);
      };
    } else {
      report_debug("Could not parse \""+date+"\" to a time int.");
    }

    if (sizeof(since_cache) > MAX_SINCE_CACHE)
      since_cache = ([]);
    since_cache[dat]=t;
  }
#endif /* constant(mktime) */
  return ({ t, length });
}

// OBSOLETED by parse_since()
int is_modified(string a, int t, void|int len)
{
  array vals=parse_since(a);
  if(len && len!=vals[1]) return 0;
  if(vals[0]<t) return 0;
  return 1;
}

//! Converts the @[date] string into a posix time integer
//! by calling @[parse_since]. Returns -1 upon failure.
int httpdate_to_time(string date)
{
  return parse_since(date)[0]||-1;
}

void set_cookie( RequestID id,
                 string name, 
                 string value, 
                 int|void expire_time_delta, 
                 string|void domain, 
                 int(1..1)|string|void path,
                 string|void secure,
                 string|void httponly)
//! Set the cookie specified by @[name] to @[value]. Adds a Set-Cookie
//! header in the response that will be made from @[id].
//!
//! @param expire_time_delta
//! If the expire_time_delta variable is -1, the cookie is set to
//! expire five years in the future. -2 will set the expiration time to
//! posix time 1 and add the argument Max-Age, set to 0. If expire_time_delta
//! is 0 or ommited, no expire information is sent to the client. This
//! usualy results in the cookie being kept until the browser is exited.
//!
//! @param path
//! A path argument will always be added to the Set-Cookie header unless
//! @[path] is 1. It will otherwise be set to the provided string, or ""
//! if no string is provided.
{
  if( expire_time_delta == -1 )
    expire_time_delta = (3600*(24*365*5));
  string cookie = (http_encode_cookie( name )+"="+
                   http_encode_cookie( value ));

  if( expire_time_delta == -2 )
    cookie += "; expires="+http_date(1)+"; Max-Age=0";
  else if( expire_time_delta )
    cookie += "; expires="+http_date( expire_time_delta+time(1) );

  if( domain ) cookie += "; domain="+http_encode_cookie( domain );
  if( path!=1 ) cookie += "; path="+http_encode_cookie( path||"" );
  if( secure ) cookie += "; secure";
  if( httponly ) cookie += "; HttpOnly";
  id->add_response_header ("Set-Cookie", cookie);
}

void remove_cookie( RequestID id,
                    string name,
                    string value,
                    string|void domain,
                    string|void path )
//! Remove the cookie specified by 'name'.
//! Sends a Set-Cookie header with an expire time of 00:00 1/1 1970.
//! The domain and path arguments are optional.
{
  set_cookie( id, name, value, -2, domain, path );
}

void add_cache_stat_callback( RequestID id, string file, int mtime )
{
  while( id->misc->orig )
    id = id->misc->orig;
  if( !id->misc->_cachecallbacks )  return;
  id->misc->_cachecallbacks += ({ lambda( RequestID id, object key ) {
				    Stat st = file_stat( file );
				    if( !st || (st[ST_MTIME] != mtime) )
				    {
				      destruct( key );
				      return 0;
				    }
				    return 1;
				  } });
}

void add_cache_callback( RequestID id,function(RequestID,object:int) callback )
//! The request id object is not yet fully initialized in this callback.
//! The only valid fields are raw_url and request_headers.
//! The second argument is the cache key. Destroying it will enforce
//! exiration of the entry from the data cache.
{
  while( id->misc->orig )
    id = id->misc->orig;
  if( !id->misc->_cachecallbacks )  return;
  id->misc->_cachecallbacks |= ({ callback });
}

string get_server_url(Configuration c)
//! Returns a URL that the given configuration answers on. This is
//! just a wrapper around @[Configuration.get_url]; that one can just
//! as well be used directly instead.
//!
//! @note
//! If there is a @[RequestID] object available, you probably want to
//! call @[RequestID.url_base] in it instead, since that function also
//! takes into account information sent by the client and the port the
//! request came from. (It's often faster too.)
{
  return c->get_url();
}

#ifndef NO_DNS
private array(string) local_addrs;
#endif

string get_world(array(string) urls) {
  if(!sizeof(urls)) return 0;

  string url = urls[0];
  mapping(string:Standards.URI) uris = ([ ]);
  foreach (urls, string u)
    uris[u] = Standards.URI(u);
  
  foreach( ({"http:","https:","ftp:"}), string p)
    foreach(urls, string u)
      if (has_prefix(u, p)) {
	uris[u]->fragment = 0;
	url = (string) uris[u];
	uris[url] = uris[u];
	break;
      }
  
  Standards.URI uri = uris[url];
  string server = uri->host;
  if (server == "::")
    server = "*";
  if (!has_value(server, "*")) return (string)uri;

  // The host part of the URL is a glob.
  // Lets find some suitable hostnames and IPs to match it against.

  array hosts=({ gethostname() });

#ifndef NO_DNS
  array dns;
  catch(dns=roxen->gethostbyname(hosts[0]));
  if(dns && sizeof(dns))
    hosts+=dns[2]+dns[1];
  if (!local_addrs) {
    string ifconfig =
      Process.locate_binary(({ "/sbin", "/usr/sbin", "/bin", "/usr/bin",
			       "/etc" }), "ifconfig");
    local_addrs = dns[1];
    if (ifconfig) {
      foreach(Process.run(({ ifconfig, "-a" }),
			  ([ "env":getenv() +
			     ([
			       // Make sure the output is not affected
			       // by the locale. cf [bug 5898].
			       "LC_ALL":"C",
			       "LANG":"C",
			     ])]))->stdout/"\n", string line) {
	int i;

	// We need to parse lines with the following formats:
	//
	// IPv4:
	//   inet 127.0.0.1			Solaris, MacOS X.
	//   inet addr:127.0.0.1		Linux.
	//
	// IPv6:
	//   inet6 ::1				MacOS X.
	//   inet6 ::1/128			Solaris.
	//   inet6 addr: ::1/128		Linux, note the space!
	//   inet6 fe80::ffff/10		Solaris.
	//   inet6 fe80::ffff%en0		MacOS X, note the suffix!
	//   inet6 addr: fe80::ffff/64		Linux, note the space!
	while ((i = search(line, "inet")) >= 0) {
	  line = line[i..];
	  string addr;
	  if (has_prefix(line, "inet ")) {
	    line = line[5..];
	  } else if (has_prefix(line, "inet6 ")) {
	    line = line[6..];
	  }
	  if (has_prefix(line, "addr: ")) {
	    line = line[6..];
	  } else if (has_prefix(line, "addr:")) {
	    line = line[5..];
	  }
	  sscanf(line, "%[^ ]%s", addr, line);
	  if (addr && sizeof(addr)) {
	    addr = (addr/"/")[0];	// We don't care about the prefix bits.
	    addr = (addr/"%")[0];	// MacOS X.
	    local_addrs += ({ addr });
	  }
	}
      }
      local_addrs = Array.uniq(local_addrs);
    }
    foreach(local_addrs, string addr) {
      //  Shortcut some known aliases to avoid lengthy waits if DNS cannot
      //  resolve them.
      if (addr == "127.0.0.1" || addr == "::1" || addr == "fe80::1") {
	if (addr != "fe80::1")
	  hosts += ({ "localhost" });
	break;
      }
      
      if ((dns = Protocols.DNS.gethostbyaddr(addr)) && sizeof(dns)) {
	if (dns[0]) {
	  hosts += ({ dns[0] });
	}
	hosts += dns[1] + ({ addr });
	if ((sizeof(dns[2]) != 1) || (dns[2][0] != addr)) {
	  hosts += dns[2];
	}
      }
    }
    hosts = Array.uniq(hosts);
    // werror("Hosts: %O\n", hosts);
  }
#endif /* !NO_DNS */

  foreach(hosts, string host)
    if (glob(server, host)) {
      uri->host = host;
      break;
    }
  return (string) uri;
}

RoxenModule get_owning_module (object|function thing)
//! Tries to find out which module the thing belongs to, if any. The
//! thing can be e.g. a module object, a Tag object or a simple_tag
//! callback.
{
  if (functionp (thing))
    thing = function_object (thing);
  if (objectp (thing))
  {
    if (thing->is_module)
      return thing;
    object o = [object]thing;
    while (object parent =
	   functionp (object_program (o)) &&
	   function_object (object_program (o)))
    {
      // FIXME: This way of finding the module for a tag is ugly.
      if (parent->is_module)
	return parent;
      o = parent;
    }

    // So. No such luck. Now we have a problem. This hack finds the
    // owning module of simple_tag and simple_pi_tag objects.
    if( thing->_do_return )
      return get_owning_module( thing->_do_return );
  }
  return 0;
}

Configuration get_owning_config (object|function thing)
//! Tries to find out which configuration the thing belongs to, if
//! any. The thing can be e.g. a config or module object, a Tag object
//! or a simple_tag callback.
{
  if (RoxenModule mod = get_owning_module (thing))
    return mod->my_configuration();
  if (functionp (thing)) thing = function_object (thing);
  if (objectp (thing)) {
    if (thing->is_configuration) return thing;
    if (object parent =
	functionp (object_program (thing)) &&
	function_object (object_program (thing))) {
      // This is mainly for finding tags defined in rxml.pike.
      if (parent->is_configuration) return parent;
    }
  }
  return 0;
}

// A slightly modified Array.dwim_sort_func used as emits sort
// function.
protected int dwim_compare(string a0,string b0)
{
  string a2="",b2="";
  int a1,b1;
  sscanf(a0,"%[^0-9]%d%s",a0,a1,a2);
  sscanf(b0,"%[^0-9]%d%s",b0,b1,b2);
  if (a0>b0) return 1;
  if (a0<b0) return -1;
  if (a1>b1) return 1;
  if (a1<b1) return -1;
  if (a2==b2) return 0;
  return dwim_compare(a2,b2);
}

protected int strict_compare (mixed a, mixed b)
// This one does a more strict compare than dwim_compare. It only
// tries to convert values from strings to floats or ints if they are
// formatted exactly as floats or ints. That since there still are
// places where floats and ints are represented as strings (e.g. in
// sql query results). Then it compares the values with `<.
//
// This more closely resembles how 2.1 and earlier compared values.
{
  if (stringp (a)) {
    if (sscanf (a, "%d%*[ \t]%*c", int i) == 2) a = i;
    else if (sscanf (a, "%f%*[ \t]%*c", float f) == 2) a = f;
  }
  if (stringp (b)) {
    if (sscanf (b, "%d%*[ \t]%*c", int i) == 2) b = i;
    else if (sscanf (b, "%f%*[ \t]%*c", float f) == 2) b = f;
  }

  int res;
  if (mixed err = catch (res = b < a)) {
    // Assume we got a "cannot compare different types" error.
    // Compare the types instead.
    a = sprintf ("%t", a);
    b = sprintf ("%t", b);
    res = b < a;
  }
  if (res)
    return 1;
  else if (a < b)
    return -1;
  else
    return 0;
}

array(mapping(string:mixed)|object) rxml_emit_sort (
  array(mapping(string:mixed)|object) dataset, string sort_spec,
  void|float compat_level)
//! Implements the sorting used by @expr{<emit sort=...>@}. @[dataset]
//! is the data to sort, and @[sort_spec] is the sort order on the
//! form specified by the @expr{sort@} attribute to @expr{<emit>@}.
{
  array(string) raw_fields = (sort_spec - " ")/"," - ({ "" });

  class FieldData {
    string name;
    int order, string_cast, lcase;
    function(mixed,mixed:int) compare;
    mapping value_cache = ([]);
  };

  array(FieldData) fields = allocate (sizeof (raw_fields));

  for (int idx = 0; idx < sizeof (raw_fields); idx++) {
    string raw_field = raw_fields[idx];
    FieldData field = fields[idx] = FieldData();
    int i;

  field_flag_scan:
    for (i = 0; i < sizeof (raw_field); i++)
      switch (raw_field[i]) {
	case '-':
	  if (field->order) break field_flag_scan;
	  field->order = '-';
	  break;
	case '+':
	  if (field->order) break field_flag_scan;
	  field->order = '+';
	  break;
	case '*':
	  if (compat_level && compat_level > 2.2) {
	    if (field->compare) break field_flag_scan;
	    field->compare = strict_compare;
	  }
	  break;
	case '^':
	  if (compat_level && compat_level > 3.3) {
	    if (field->lcase) break field_flag_scan;
	    field->lcase = 1;
	  }
	  break;
	  // Fall through.
	default:
	  break field_flag_scan;
      }
    field->name = raw_field[i..];

    if (!field->compare) {
      if (compat_level && compat_level > 2.1) {
	field->compare = dwim_compare;
	field->string_cast = 1;
      }
      else
	field->compare = strict_compare;
    }
  }

  RXML.Context ctx;

  return Array.sort_array (
    dataset,
    lambda (mapping(string:mixed)|object ma, mapping(string:mixed)|object mb)
    {
      foreach (fields, FieldData field) {
	string name = field->name;
	int string_cast = field->string_cast, lcase = field->lcase;
	mapping value_cache = field->value_cache;
	mixed a = ma[name], b = mb[name];
	int eval_a = objectp (a) && a->rxml_var_eval;
	int eval_b = objectp (b) && b->rxml_var_eval;

	if (string_cast || lcase || eval_a) {
	  mixed v = value_cache[a];
	  if (zero_type (v)) {
	    if (eval_a) {
	      if (!ctx) ctx = RXML_CONTEXT;
	      v = a->rxml_const_eval ? a->rxml_const_eval (ctx, name, "") :
		a->rxml_var_eval (ctx, name, "", RXML.t_text);
	    }
	    else v = a;
	    if (string_cast) v = RXML.t_string->encode (v);
	    if (lcase && stringp (v)) v = lower_case (v);
	    value_cache[a] = v;
	  }
	  a = v;
	}

	if (string_cast || lcase || eval_b) {
	  mixed v = value_cache[b];
	  if (zero_type (v)) {
	    if (eval_b) {
	      if (!ctx) ctx = RXML_CONTEXT;
	      v = b->rxml_const_eval ? b->rxml_const_eval (ctx, name, "") :
		b->rxml_var_eval (ctx, name, "", RXML.t_text);
	    }
	    else v = b;
	    if (string_cast) v = RXML.t_string->encode (v);
	    if (lcase && stringp (v)) v = lower_case (v);
	    value_cache[b] = v;
	  }
	  b = v;
	}

	int tmp;
	switch (field->order) {
	  case '-': tmp = field->compare (b, a); break;
	  default:
	  case '+': tmp = field->compare (a, b); break;
	}
	if (tmp > 0)
	  return 1;
	else if (tmp < 0)
	  return 0;
      }
      return 0;
    });
}

class True
//! Type for @[Roxen.true]. Do not create more instances of this.
{
  // Val.true is replaced by this by create() in roxen.pike.
  inherit Val.True;

  mixed rxml_var_eval (RXML.Context ctx, string var, string scope_name,
		       void|RXML.Type type)
  {
    if (!type)
      return this;
    if (type->subtype_of (RXML.t_num))
      return type->encode (1);
    // Don't try type->encode(this) since we've inherited a cast
    // function that we don't wish the rxml parser to use - it should
    // be an error if this object is used in non-numeric contexts.
    if (type != RXML.t_any)
      RXML.parse_error ("Cannot convert %O to type %s.\n", this, type->name);
    return this;
  }

  protected string _sprintf (int flag) {return flag == 'O' && "Roxen.true";}
}

True true = True();
//! Roxen replacement for @[Val.true] that adds rxml type conversions:
//! It's true in boolean tests and yields 1 or 1.0, as appropriate, in
//! a numeric context.

class False
//! Type for @[Roxen.false]. Do not create more instances of this.
{
  // Val.false is replaced by this by create() in roxen.pike.
  inherit Val.False;

  constant is_rxml_null_value = 1;

  mixed rxml_var_eval (RXML.Context ctx, string var, string scope_name,
		       void|RXML.Type type)
  {
    if (!type)
      return this;
    if (type->subtype_of (RXML.t_num))
      return type->encode (0);
    // Don't try type->encode(this) since we've inherited a cast
    // function that we don't wish the rxml parser to use - it should
    // be an error if this object is used in non-numeric contexts.
    if (type != RXML.t_any)
      RXML.parse_error ("Cannot convert %O to type %s.\n", this, type->name);
    return this;
  }

  protected string _sprintf (int flag) {return flag == 'O' && "Roxen.false";}
}

False false = False();
//! Roxen replacement for @[Val.false] that adds rxml type
//! conversions: It's false in boolean tests, and yields 0 or 0.0, as
//! appropriate, in a numeric context.

class Null
{
  // Val.null is replaced by this by create() in roxen.pike.
  inherit Val.Null;

  constant is_rxml_null_value = 1;

  mixed rxml_var_eval (RXML.Context ctx, string var, string scope_name,
		       void|RXML.Type type)
  {
    if (!type)
      return this;
    if (type->string_type)
      // A bit inconsistent with the true/false values, but compatible
      // with the old sql_null value and how sql NULLs behaved prior
      // to it when they produced UNDEFINED.
      return "";
    if (type->subtype_of (RXML.t_num))
      return type->encode (0);
    return type->encode (this);
  }

  protected string _sprintf (int flag) {return flag == 'O' && "Roxen.null";}
}

Null null = Null();
//! Roxen replacement for @[Val.null] that adds rxml type conversions:
//! It's false in boolean tests, yields "" in a string context and 0
//! or 0.0, as appropriate, in a numeric context.

constant SqlNull = Null;
Val.Null sql_null;
// Compat aliases. sql_null is initialized in create() in roxen.pike.

class Compat51Null
// Null object for compat_level < 5.2. Also inherits RXML.Nil, which
// among other things allows casting to empty values of various types.
{
  inherit Null;
  inherit RXML.Nil;

  protected string _sprintf (int flag)
  {
    return flag == 'O' && "Roxen.compat_5_1_null";
  }
}

Compat51Null compat_5_1_null = Compat51Null();


#ifdef REQUEST_TRACE
protected string trace_msg (mapping id_misc, string msg,
			    string|int name_or_time, int enter)
{
  array(string) lines = msg / "\n";
  if (lines[-1] == "") lines = lines[..<1];

  if (sizeof (lines)) {
#if TOSTR (REQUEST_TRACE) == "TIMES"
    string byline = sprintf ("%*s%c %s",
			     id_misc->trace_level + 1, "",
			     enter ? '>' : '<',
			     lines[-1]);
#else
    string byline = sprintf ("%*s%s",
			     id_misc->trace_level + 1, "",
			     lines[-1]);
#endif

    string info;
    if (stringp (name_or_time))
      info = name_or_time;
    else if (name_or_time >= 0)
      info = "time: " + format_hrtime (name_or_time, sizeof (byline) <= 40);
    if (info)
      byline = sprintf ("%-40s  %s", byline, info);

    report_debug (map (lines[..<1],
		       lambda (string s) {
			 return sprintf ("%s%*s%s\n", id_misc->trace_id_prefix,
					 id_misc->trace_level + 1, "", s);
		       }) * "" +
		  id_misc->trace_id_prefix +
		  byline +
		  "\n");
  }
}

void trace_enter (RequestID id, string msg, object|function thing,
		  int timestamp)
{
  if (id) {
    // Replying on the interpreter lock here. Necessary since requests
    // can finish and be destructed asynchronously which typically
    // leads to races in the TRACE_LEAVE calls in low_get_file.
    mapping id_misc = id->misc;

    if (function(string,mixed,int:void) trace_enter =
	[function(string,mixed,int:void)] id_misc->trace_enter)
      trace_enter (msg, thing, timestamp);

    if (zero_type (id_misc->trace_level)) {
      id_misc->trace_id_prefix = ({"%%", "##", "||", "**", "@@", "$$", "&&"})[
	all_constants()->id_trace_level_rotate_counter++ % 7];
#ifdef ID_OBJ_DEBUG
      report_debug ("%s%s %O: Request handled by: %O\n",
		    id_misc->trace_id_prefix, id_misc->trace_id_prefix[..0],
		    id, id && id->conf);
#else
      report_debug ("%s%s Request handled by: %O\n",
		    id_misc->trace_id_prefix, id_misc->trace_id_prefix[..0],
		    id->conf);
#endif
    }

    string name;
    if (thing) {
      name = get_modfullname (get_owning_module (thing));
      if (name)
	name = "mod: " + name;
      else if (Configuration conf = get_owning_config (thing))
	name = "conf: " + conf->query_name();
      else
	name = sprintf ("obj: %O", thing);
    }
    else name = "";

    trace_msg (id_misc, msg, name, 1);
    int l = ++id_misc->trace_level;

#if TOSTR (REQUEST_TRACE) == "TIMES"
    array(int) tt = id_misc->trace_times;
    array(string) tm = id_misc->trace_msgs;
    if (!tt) {
      tt = id_misc->trace_times = allocate (10);
      tm = id_misc->trace_msgs = allocate (10);
    }
    else if (sizeof (tt) <= l) {
      tt = (id_misc->trace_times += allocate (sizeof (tt)));
      tm = (id_misc->trace_msgs += allocate (sizeof (tm)));
    }
    tt[l] = timestamp - id_misc->trace_overhead;
    sscanf (msg, "%[^\n]", tm[l]);
#endif
  }
}

void trace_leave (RequestID id, string desc, void|int timestamp)
{
  if (id) {
    // Replying on the interpreter lock here. Necessary since requests
    // can finish and be destructed asynchronously which typically
    // leads to races in the TRACE_LEAVE calls in low_get_file.
    mapping id_misc = id->misc;

    string msg = desc;
    string|int name_or_time = "";
#if TOSTR (REQUEST_TRACE) == "TIMES"
    if (int l = id_misc->trace_level) {
      if (array(int) tt = id_misc->trace_times)
	if (sizeof (tt) > l) {
	  name_or_time = timestamp - id_misc->trace_overhead - tt[l];
	  if (desc == "") msg = id_misc->trace_msgs[l];
	}
      id_misc->trace_level--;
    }
#else
    if (id_misc->trace_level) id_misc->trace_level--;
#endif

    if (sizeof (msg)) trace_msg (id_misc, msg, name_or_time, 0);

    if (function(string,int:void) trace_leave =
	[function(string:void)] id_misc->trace_leave)
      trace_leave (desc, timestamp);
  }
}
#endif

private inline string ns_color(array (int) col)
{
  if(!arrayp(col)||sizeof(col)!=3)
    return "#000000";
  return sprintf("#%02x%02x%02x", col[0],col[1],col[2]);
}

int(0..1) init_wiretap_stack (mapping(string:string) args, RequestID id, int(0..1) colormode)
{
  mapping(string:mixed) ctx_misc = RXML_CONTEXT->misc;
  int changed=0;
  mixed cols=(args->bgcolor||args->text||args->link||args->alink||args->vlink);

#define FIX(Y,Z,X) do{ \
  if(!args->Y || args->Y==""){ \
    ctx_misc[X]=Z; \
    if(cols){ \
      args->Y=Z; \
      changed=1; \
    } \
  } \
  else{ \
    ctx_misc[X]=args->Y; \
    if(colormode&&args->Y[0]!='#'){ \
      args->Y=ns_color(parse_color(args->Y)); \
      changed=1; \
    } \
  } \
}while(0)

  //FIXME: These values are not up to date

  FIX(text,   "#000000","fgcolor");
  FIX(link,   "#0000ee","link");
  FIX(alink,  "#ff0000","alink");
  FIX(vlink,  "#551a8b","vlink");

  if(id->client_var && has_value(id->client_var->fullname||"","windows"))
  {
    FIX(bgcolor,"#c0c0c0","bgcolor");
  } else {
    FIX(bgcolor,"#ffffff","bgcolor");
  }

  ctx_misc->wiretap_stack = ({});

#ifdef WIRETAP_TRACE
  report_debug ("Init wiretap stack for %O: "
		"fgcolor=%O, bgcolor=%O, link=%O, alink=%O, vlink=%O\n",
		id, ctx_misc->fgcolor, ctx_misc->bgcolor,
		ctx_misc->alink, ctx_misc->alink, ctx_misc->vlink);
#endif

  return changed;
}

int(0..1) push_color (string tagname, mapping(string:string) args,
		      RequestID id, void|int colormode)
{
  mapping(string:mixed) ctx_misc = RXML_CONTEXT->misc;
  int changed;
  if(!ctx_misc->wiretap_stack)
    init_wiretap_stack (([]), id, colormode);

  ctx_misc->wiretap_stack +=
    ({ ({ tagname, ctx_misc->fgcolor, ctx_misc->bgcolor }) });

#undef FIX
#define FIX(X,Y) if(args->X && args->X!=""){ \
  ctx_misc->Y=args->X; \
  if(colormode && args->X[0]!='#'){ \
    args->X=ns_color(parse_color(args->X)); \
    changed = 1; \
  } \
}

  FIX(bgcolor,bgcolor);
  FIX(color,fgcolor);
  FIX(text,fgcolor);
#undef FIX

#ifdef WIRETAP_TRACE
  report_debug ("%*sPush wiretap stack for %O: tag=%O, fgcolor=%O, bgcolor=%O\n",
		sizeof (ctx_misc->wiretap_stack) * 2, "", id, tagname,
		ctx_misc->fgcolor, ctx_misc->bgcolor);
#endif

  return changed;
}

void pop_color (string tagname, RequestID id)
{
  mapping(string:mixed) ctx_misc = RXML_CONTEXT->misc;
  array c = ctx_misc->wiretap_stack;
  if(c && sizeof(c)) {
    int i;

    for(i=0; i<sizeof(c); i++)
      if(c[-i-1][0]==tagname)
      {
	ctx_misc->fgcolor = c[-i-1][1];
	ctx_misc->bgcolor = c[-i-1][2];
	break;
      }

    ctx_misc->wiretap_stack = c[..sizeof(c)-i-2];

#ifdef WIRETAP_TRACE
  report_debug ("%*sPop wiretap stack for %O: tag=%O, fgcolor=%O, bgcolor=%O\n",
		sizeof (c) * 2, "", id, tagname,
		ctx_misc->fgcolor, ctx_misc->bgcolor);
#endif
  }
}

#if constant(Standards.X509)

string generate_self_signed_certificate(string common_name,
					Crypto.Sign|void key)
{
  int key_size = 4096;	// Ought to be safe for a few years.

  if (!key) {
    key = Crypto.RSA();
    key->generate_key(key_size, Crypto.Random.random_string);
  }

  string key_type = key->name();
  if (has_prefix(key_type, "ECDSA") ||
      has_suffix(key_type, "ECDSA")) {
    key_type = "ECDSA";
  }

  string key_pem =
    Standards.PEM.build(key_type + " PRIVATE KEY",
			Standards.PKCS[key_type].private_key(key));

  // These are the fields used by testca.pem.
  array(mapping(string:object)) name = ({
    ([ "organizationName":
       Standards.ASN1.Types.PrintableString("Roxen IS")
    ]),
    ([ "organizationUnitName":
       Standards.ASN1.Types.PrintableString("Automatic certificate")
    ]),
    ([ "commonName":
       (Standards.ASN1.Types.asn1_printable_valid(common_name)?
	Standards.ASN1.Types.PrintableString:
	Standards.ASN1.Types.BrokenTeletexString)(common_name)
    ]),
  });

  int ttl = 3652;	// 10 years.

  /* Create a plain X.509 v3 certificate, with just default extensions. */
  string cert =
    Standards.X509.make_selfsigned_certificate(key, 24 * 3600 * ttl, name);

  return Standards.PEM.build("CERTIFICATE", cert) + key_pem;
}

#else
// NB: Several of the Tools.PEM and Tools.X509 APIs below
//     have been deprecated in Pike 8.0.
#pragma no_deprecation_warnings

string generate_self_signed_certificate(string common_name, Crypto.RSA|void rsa)
{
  int key_size = 4096;	// Ought to be safe for a few years.

  if (!rsa) {
    rsa = Crypto.RSA();
    rsa->generate_key(key_size, Crypto.Random.random_string);
  }

  string key = Tools.PEM.simple_build_pem ("RSA PRIVATE KEY",
					   Standards.PKCS.RSA.private_key(rsa));

  // These are the fields used by testca.pem.
  array(mapping(string:object)) name = ({
    ([ "organizationName":
       Standards.ASN1.Types.asn1_printable_string("Roxen IS")
    ]),
    ([ "organizationUnitName":
       Standards.ASN1.Types.asn1_printable_string("Automatic certificate")
    ]),
    ([ "commonName":
       (Standards.ASN1.Types.asn1_printable_valid(common_name)?
	Standards.ASN1.Types.asn1_printable_string:
	Standards.ASN1.Types.asn1_broken_teletex_string)(common_name)
    ]),
  });

  int ttl = 3652;	// 10 years.

  /* Create a plain X.509 v1 certificate, without any extensions */
  string cert = Tools.X509.make_selfsigned_rsa_certificate
    (rsa, 24 * 3600 * ttl, name);

  return Tools.PEM.simple_build_pem("CERTIFICATE", cert) + key;
}

#pragma deprecation_warnings
#endif /* Standards.X509 */

class LogPipe
//! The write end of a pipe that will log to the debug log. Use
//! @[get_log_pipe] to create an instance.
{
  inherit Stdio.File;

  protected string prefix = "";
  protected string line_buf = "";

  protected void read_cb (Stdio.File read_end, string data)
  {
    line_buf += data;
    while (sscanf (line_buf, "%[^\n]%*c%s", string line, string rest) == 3) {
      werror (prefix + line + "\n");
      line_buf = rest;
    }
  }

  protected void close_cb (Stdio.File read_end)
  {
    if (line_buf != "")
      werror (prefix + line_buf + "\n");
    read_end->set_read_callback (0);
    read_end->set_close_callback (0);
    read_end->set_id (0);
  }

  protected void log_pipe_read_thread (Stdio.File read_end)
  {
    roxen->name_thread(this_thread(), "Log pipe");
    while (1) {
      string data = read_end->read (1024, 1);
      if (!data || data == "") break;
      read_cb (read_end, data);
    }
    close_cb (read_end);
    roxen->name_thread(this_thread(), 0);
  }

  protected void create (Stdio.File read_end, Stdio.File write_end,
			 int use_read_thread)
  {
#if constant(thread_create)
    if (use_read_thread)
      thread_create (log_pipe_read_thread, read_end);
    else
#endif
    {
      read_end->set_nonblocking (read_cb, 0, close_cb);
      read_end->set_id (read_end);
    }
    assign (write_end);
  }

  void set_prefix (string prefix)
  //! Sets a string that will be prefixed to each line that is logged
  //! via this pipe.
  {
    LogPipe::prefix = prefix;
  }
}

LogPipe get_log_pipe()
//! Returns a pipe suitable to bind to @expr{"stdout"@} and
//! @expr{"stderr"@} in a @[Process.Process] call to get the
//! output from the created process into the debug log. The log data
//! is line buffered to avoid mixing output from different processes
//! on the same line.
//!
//! @note
//! Don't forget to close the returned pipe after the call to
//! @[Process.Process]. Otherwise the pipe will remain intact
//! after the process has exited and you'll get an fd leak.
//!
//! @note
//! The standard backend is used (when possible) to echo the data that
//! arrives on the pipe. If it's hung then data that arrives on the
//! pipe won't show in the debug log.
{
  Stdio.File read_end = Stdio.File();
  Stdio.File write_end;
  int use_read_thread;
  if (catch (write_end =
	     read_end->pipe (Stdio.PROP_IPC|Stdio.PROP_NONBLOCK))) {
    // Some OS'es (notably Windows) can't create a nonblocking
    // interprocess pipe.
    read_end = Stdio.File();
    write_end = read_end->pipe (Stdio.PROP_IPC);
    use_read_thread = 1;
#if 0
    report_debug ("Using read thread with a blocking pipe for logging.\n");
#endif
  }
  if (!write_end) error ("Failed to create pipe: %s\n",
			 strerror (read_end->errno()));
  return LogPipe (read_end, write_end, use_read_thread);
}

constant DecodeError = Locale.Charset.DecodeError;
constant EncodeError = Locale.Charset.EncodeError;

mapping(string:int) get_memusage()
//! Returns a mapping of the memory used by the Roxen process.
//!
//! @returns
//!   @mapping
//!     @member string "resident"
//!       Resident memory in KiB.
//!     @member string "virtual"
//!       Virtual memory in KiB.
//!   @endmapping
//!
//! @note
//!   Uses the @tt{ps@} binary in unix and @tt{wmic@} on Windows.
//! @note
//!   Is a bit expensive on Windows.
{
  constant default_value = ([ "virtual":0, "resident":0 ]);
  string res;
#ifdef __NT__
  constant divisor = 1024;
  if(mixed err = catch { 
      res = Process.run( ({ "wmic", "process", "where",
			    "ProcessId=" + (string)getpid(),
			    "get", "ProcessId,VirtualSize,WorkingSetSize" }) )->stdout;
    })
  {
#ifdef MODULE_DEBUG
    werror("The wmic command failed with: %O\n", describe_backtrace(err));
#endif
    return default_value;
  }
#else
  constant divisor = 1;
  string ps_location =
    Process.locate_binary( ({ "/sbin", "/usr/sbin", "/bin", "/usr/bin" }), "ps");
  if(!ps_location)
    return default_value;
  
  if(mixed err = catch { 
      res = Process.run( ({ ps_location, "-o", "pid,vsz,rss",
			    (string)getpid() }) )->stdout;
    })
  {
#ifdef MODULE_DEBUG
    werror("The ps command failed with: %O\n", describe_backtrace(err));
#endif
    return default_value;
  }
#endif
  array rows = (res / "\n") - ({ "" });
  if(sizeof(rows) < 2)
    return default_value;
  
  array values = (rows[1]/" ") - ({ "" });
  if(sizeof(values) < 3)
    return default_value;
  
  return ([ "virtual": (int)values[1]/divisor, "resident": (int)values[2]/divisor ]);
}

string lookup_real_path_case_insens (string path, void|int no_warn,
				     void|string charset)
//! Looks up the given path case insensitively to a path in the real
//! file system. I.e. all segments in @[path] that exist in the file
//! system when matched case insensitively are converted to the same
//! case they have when listed by @[get_dir]. Segments that don't
//! exist are kept as-is.
//!
//! If a segment ambiguously matches several entries in a directory
//! then it and all remaining segments are returned as-is. A warning
//! is also logged in this case, unless @[no_warn] is nonzero.
//!
//! The given path is assumed to be absolute, and it is normalized
//! with @[combine_path] before being checked. The returned paths
//! always have "/" as directory separators. If there is a trailing
//! slash then it is kept intact.
//!
//! If @[charset] is set then charset conversion is done: @[path] is
//! assumed to be a (possibly wide) unicode string, and @[charset] is
//! taken as the charset used in the file system. The returned path is
//! a unicode string as well. If @[charset] isn't specified then no
//! charset conversion is done anywhere, which means that @[path] must
//! have the same charset as the file system, and the case insensitive
//! comparisons only work in as far as @[lower_case] does the right
//! thing with that charset.
//!
//! If @[charset] is given then it's assumed to be a charset accepted
//! by @[Locale.Charset]. If there are charset conversion errors in
//! @[path] or in the file system then those paths are treated as
//! nonexisting.
//!
//! @note
//! Existing paths are cached without any time limit, but the cached
//! paths are always verified to still exist before being reused. Thus
//! the only overcaching effect that can occur is if the underlying
//! file system is case insensitive and some path segment only has
//! changed in case.
{
  ASSERT_IF_DEBUG (is_absolute_path (path));

  string cache_name = "case_insens_paths";

  function(string:string) encode, decode;
  switch (charset) {
    case 0:
      break;
    case "utf8":
    case "utf-8":
      encode = string_to_utf8;
      decode = utf8_to_string;
      cache_name += ":utf8";
      break;
    default:
      Locale.Charset.Encoder enc = Locale.Charset.encoder (charset);
      Locale.Charset.Decoder dec = Locale.Charset.decoder (charset);
      encode = lambda (string in) {return enc->feed (in)->drain();};
      decode = lambda (string in) {return dec->feed (in)->drain();};
      cache_name += ":" + enc->charset;
      break;
  }

  string dec_path, enc_path;
  int nonexist;

  void recur (string path)
  {
    string lc_path = lower_case (path);

    dec_path = cache_lookup (cache_name, lc_path);
    if (dec_path) {
    check_cached: {
	if (!encode)
	  enc_path = dec_path;
	else if (mixed err = catch (enc_path = encode (dec_path))) {
	  if (!objectp (err) || !err->is_charset_encode_error)
	    throw (err);
	  break check_cached;
	}
	if (Stdio.exist (enc_path)) {
	  //werror ("path %O -> %O (cached)\n", path, dec_path);
	  return;
	}
      }
      cache_remove (cache_name, lc_path);
    }

    dec_path = dirname (path);
    if (dec_path == "" || dec_path == path) { // At root.
      if (!encode)
	enc_path = dec_path;
      else if (mixed err = catch (enc_path = encode (dec_path))) {
	if (!objectp (err) || !err->is_charset_encode_error)
	  throw (err);
      }
      return;
    }
    recur (dec_path);

    if (!nonexist) {
      // FIXME: Note that get_dir on windows accepts and returns
      // unicode paths, so the following isn't correct there. The
      // charset handling in the file system interface on windows is
      // inconsistent however, since most other functions do not
      // accept neither wide strings nor strings encoded with any
      // charset. This applies at least up to pike 7.8.589.
    search_dir:
      if (array(string) dir_list = get_dir (enc_path)) {
	string lc_name = basename (lc_path);
	string dec_name, enc_name;

	foreach (dir_list, string enc_ent) {
	  string dec_ent;
	  if (!decode)
	    dec_ent = enc_ent;
	  else if (mixed err = catch (dec_ent = decode (enc_ent))) {
	    if (decode != utf8_to_string)
	      // utf8_to_string doesn't throw Locale.Charset.DecodeErrors.
	      if (!objectp (err) || !err->is_charset_decode_error)
		throw (err);
	    // Ignore file system paths that we cannot decode.
	    //werror ("path ignore in %O: %O\n", enc_path, enc_ent);
	    continue;
	  }

	  if (lower_case (dec_ent) == lc_name) {
	    if (dec_name) {
	      if (!no_warn)
		report_warning ("Ambiguous path %q matches both %q and %q "
				"in %q.\n", path, dec_name, dec_ent, dec_path);
	      break search_dir;
	    }
	    dec_name = dec_ent;
	    enc_name = enc_ent;
	  }
	}

	if (dec_name) {
	  dec_path = combine_path_unix (dec_path, dec_name);
	  enc_path = combine_path (enc_path, enc_name);
	  //werror ("path %O -> %O/%O\n", path, dec_path, enc_path);
	  cache_set (cache_name, lc_path, dec_path);
	  return;
	}
      }

      nonexist = 1;
    }

    // Nonexisting file or dir - keep the case in that part. enc_path
    // won't be used anymore when nonexist gets set, so no need to
    // update it.
    dec_path = combine_path_unix (dec_path, basename (path));
    //werror ("path %O -> %O (nonexisting)\n", path, dec_path);
    return;
  };

  path = combine_path (path);
  if (has_suffix (path, "/") || has_suffix (path, "\\")) {
    recur (path[..<1]);
    dec_path += "/";
  }
  else
    recur (path);

  encode = decode = 0;		// Avoid garbage.

  return dec_path;
}
