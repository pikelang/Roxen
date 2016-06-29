// This is a roxen pike module. Copyright © 1999 - 2004, Roxen IS.
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
		    } )
    ->feed( Stdio.read_file( xml_file ) )
    ->finish();

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

string http_roxen_id_cookie( void|object /* Protocol */ port_obj )
{
  return "RoxenUserID=" + get_roxen_ip_prefix( port_obj ) +
    roxen->create_unique_id() + "; expires=" +
    http_date (3600*24*365*2 + time (1)) + "; path=/";
}

// Returns a prefix based on the ip address (or not implemented other
// string that identifies this site or server).
string get_roxen_ip_prefix( void|object/* Protocol */ port_obj ) {
  string ip = port_obj && port_obj->ip;
  if( ip && sizeof(ip) ) {
    if( has_value( ip, ":" ) ) {
      // IP v6
      ip = (ip / "/")[0];
      return reverse( ip / ":") * ":";
    }
    return reverse( ip / ".") * ".";
  }
  return "0.0.0.0";
}

static mapping(string:function(string, RequestID:string)) cookie_callbacks =
  ([]);
static class CookieChecker(string cookie)
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

mapping add_http_header(mapping to, string name, string value)
//! Adds a header @[name] with value @[value] to the header style
//! mapping @[to] (which commonly is @tt{id->misc[" _extra_heads"]@})
//! if no header with that value already exist.
//!
//! @note
//! This function doesn't notify the RXML p-code cache, which makes it
//! inappropriate to use for updating @tt{id->misc[" _extra_heads"]@}
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
  response->extra_heads = (["allow": allowed_methods]);
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

static class Delayer
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

static constant months = ({ "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                            "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" });
static constant days = ({ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" });

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

static int chd_lt;
static string chd_lf;

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
#ifdef MODULE_DEBUG
  // We're being very naughty for now. This sucker gotta go! (Ought to
  // look at the compat level here, but it's kinda hard without an id
  // object.)
  error ("Switch to http_encode_url or http_encode_invalids!\n");
#endif
  return replace(f, ({ "\000", " ", "\t", "\n", "\r", "%", "'", "\"" }),
		 ({"%00", "%20", "%09", "%0A", "%0D", "%25", "%27", "%22"}));
}

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
//! @expr{-@}, @expr{.@}, @expr{_@}, and @expr{~@} (see RFC 2396
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
      url = id->url_base() + url[1..];
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
		       mapping|void variables)
//! Returns a http-redirect message to the specified URL. The absolute
//! URL that is required for the @expr{Location@} header is built from
//! the given components using @[make_absolute_url]. See that function
//! for details.
{
  // If we don't get any URL we don't know what to do.
  // But we do!  /per
  if(!url)
    url = "";

  url = make_absolute_url (url, id, prestates, variables);

  url = http_encode_invalids(url);

  HTTP_WERR("Redirect -> "+url);

  return http_status( 302, "Redirect to " + url)
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

mapping http_digest_required(mapping(string:string) challenge,
			     string|void message)
//! Generates a result mapping that will instruct the web browser that
//! the user needs to authorize himself before being allowed access.
//! `realm' is the name of the realm on the server, which will
//! typically end up in the browser's prompt for a name and password
//! (e g "Enter username for <i>realm</i> at <i>hostname</i>:"). The
//! optional message is the message body that the client typically
//! shows the user, should he decide not to authenticate himself, but
//! rather refraim from trying to authenticate himself.
//!
//! In HTTP terms, this sends a <tt>401 Auth Required</tt> response
//! with the header <tt>WWW-Authenticate: basic realm="`realm'"</tt>.
//! For more info, see RFC 2617.
{
  if(!message)
    message = "<h1>Authentication failed.\n</h1>";
  HTTP_WERR(sprintf("Auth required (%O)", challenge));
  string digest_challenge = "";
  foreach(challenge; string key; string val) {
    digest_challenge += sprintf(" %s=%O", key, val);
  }
  return http_low_answer(401, message)
    + ([ "extra_heads":([ "WWW-Authenticate":"Digest "+digest_challenge,]),]);
}

mapping http_auth_required(string realm, string|void message,
			   void|RequestID id)
//! Generates a result mapping that will instruct the web browser that
//! the user needs to authorize himself before being allowed access.
//! `realm' is the name of the realm on the server, which will
//! typically end up in the browser's prompt for a name and password
//! (e g "Enter username for <i>realm</i> at <i>hostname</i>:"). The
//! optional message is the message body that the client typically
//! shows the user, should he decide not to authenticate himself, but
//! rather refraim from trying to authenticate himself.
//!
//! In HTTP terms, this sends a <tt>401 Auth Required</tt> response
//! with the header <tt>WWW-Authenticate: basic realm="`realm'"</tt>.
//! For more info, see RFC 2617.
{
  HTTP_WERR("Auth required ("+realm+")");
  if (id) {
    return id->conf->auth_failed_file( id, message )
      + ([ "extra_heads":([ "WWW-Authenticate":"basic realm=\""+realm+"\"",]),]);
  }
  if(!message)
    message = "<h1>Authentication failed.</h1>";
  return http_low_answer(401, message)
    + ([ "extra_heads":([ "WWW-Authenticate":"basic realm=\""+realm+"\"",]),]);
}

mapping http_proxy_auth_required(string realm, void|string message)
//! Generates a result mapping that will instruct the client end that
//! it needs to authenticate itself before being allowed access.
//! `realm' is the name of the realm on the server, which will
//! typically end up in the browser's prompt for a name and password
//! (e g "Enter username for <i>realm</i> at <i>hostname</i>:"). The
//! optional message is the message body that the client typically
//! shows the user, should he decide not to authenticate himself, but
//! rather refraim from trying to authenticate himself.
//!
//! In HTTP terms, this sends a <tt>407 Proxy authentication
//! failed</tt> response with the header <tt>Proxy-Authenticate: basic
//! realm="`realm'"</tt>. For more info, see RFC 2617.
{
  if(!message)
    message = "<h1>Proxy authentication failed.</h1>";
  return http_low_answer(407, message)
    + ([ "extra_heads":([ "Proxy-Authenticate":"basic realm=\""+realm+"\"",]),]);
}


// --- From the old 'roxenlib' file -------------------------------

string extract_query(string from)
{
  if(!from) return "";
  if(sscanf(from, "%*s?%s%*[ \t\n]", from))
    return (from/"\r")[0];
  return "";
}

static string mk_env_var_name(string name)
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

static int(0..0) return_zero() {return 0;}

static Parser.HTML xml_parser =
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
  if (preserve_roxen_entities) {
    foreach(indices(in), string a)
      res += " " + a + "=\"" + quote_fn((string) in[a]) + "\"";
  } else {
    foreach(indices(in), string a)
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

#define  PREFIX ({ "bytes", "kb", "Mb", "Gb", "Tb", "Pb", "Eb", "Zb", "Yb" })
string sizetostring( int size )
  //! Returns the size as a memory size string with suffix,
  //! e.g. 43210 is converted into "42.2 kb". To be correct
  //! to the latest standards it should really read "42.2 KiB",
  //! but we have chosen to keep the old notation for a while.
  //! The function knows about the quantifiers kilo, mega, giga,
  //! tera, peta, exa, zetta and yotta.
{
  if(size<0) return "--------";
  float s = (float)size;
  size=0;

  if(s<1024.0) return (int)s+" bytes";
  while( s > 1024.0 )
  {
    s /= 1024.0;
    size ++;
  }
  return sprintf("%.1f %s", s, PREFIX[ size ]);
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

static string my_sprintf(int prefix, string f, int arg)
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
    if(key=="") continue;
    int(0..1) prefix = 1;
    if(key[0] == '!' && sizeof(key) > 1) {
      prefix = 0;
      key = key[1..];
    }
    switch(key[0]) {
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
      if (language)
	res += number2string(lt->mon+1,m,language(lang,"month",id));
      else
	res += ({ "January", "February", "March", "April", "May", "June",
		  "July", "August", "September", "October", "November", "December" })[lt->mon];
      break;
    case 'c':	// Date and time
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
    case 'E':
    case 'O':
      key = key[1..]; // No support for E or O extension.
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
    case 'r':	// Time in 12-hour clock format with %p
      res += strftime("%l:%M %p", t);
      break;
    case 'R':	// Time as %H:%M
      res += sprintf("%02d:%02d", lt->hour, lt->min);
      break;
    case 'S':	// Seconds [00,61]; 0-prefix
      res += my_sprintf(prefix, "%02d", lt->sec);
      break;
    case 't':	// Tab
      res += "\t";
      break;
    case 'T':	// Time as %H:%M:%S
    case 'X':
      res += sprintf("%02d:%02d:%02d", lt->hour, lt->min, lt->sec);
      break;
    case 'u':	// Weekday as a decimal number [1,7], Sunday == 1
      res += my_sprintf(prefix, "%d", lt->wday + 1);
      break;
    case 'w':	// Weekday as a decimal number [0,6], Sunday == 0
      res += my_sprintf(prefix, "%d", lt->wday);
      break;
    case 'x':	// Date
      res += strftime("%a %b %d %Y", t);
      break;
    case 'y':	// Year [00,99]; 0-prefix
      res += my_sprintf(prefix, "%02d", lt->year % 100);
      break;
    case 'Y':	// Year [0000.9999]; 0-prefix
      res += my_sprintf(prefix, "%04d", 1900 + lt->year);
      break;

    case 'U':	// Week number of year as a decimal number [00,53],
		// with Sunday as the first day of week 1; 0-prefix
      res += my_sprintf(prefix, "%02d", ((lt->yday-1+lt->wday)/7));
      break;
    case 'V':	// ISO week number of the year as a decimal number [01,53]; 0-prefix
      res += my_sprintf(prefix, "%02d", Calendar.ISO.Second(t)->week_no());
      break;
    case 'W':	// Week number of year as a decimal number [00,53],
		// with Monday as the first day of week 1; 0-prefix
      res += my_sprintf(prefix, "%02d", ((lt->yday+(5+lt->wday)%7)/7));
      break;
    case 'Z':	// FIXME: Time zone name or abbreviation, or no bytes if
		// no time zone information exists
    }
    res+=key[1..];
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
    if (!(name && sizeof (name)))
      name = [string]module->register_module()[1];
    if (mappingp (name))
      name = name->standard;
    return (string) name;
  }
  else return 0;
}

static constant xml_invalids = ((string)({
   0,  1,  2,  3,  4,  5,  6,  7,
   8,         11, 12,     14, 15,
  16, 17, 18, 19, 20, 21, 22, 23,
  24, 25, 26, 27, 28, 29, 30, 31,
      127
}))/"";

static constant xml_printables = ((string)({
  0x2400, 0x2401, 0x2402, 0x2403, 0x2404, 0x2405, 0x2406, 0x2407,
  0x2408,                 0x240b, 0x240c,         0x240e, 0x240f,
  0x2410, 0x2411, 0x2412, 0x2413, 0x2414, 0x2415, 0x2416, 0x2417,
  0x2418, 0x2419, 0x241a, 0x241b, 0x241c, 0x241d, 0x241e, 0x241f,
          0x2421,
}))/"";

string encode_xml_invalids(string s)
//! Remap control characters not valid in XML-documents to their
//! corresponding printable code points (@tt{U2400 - U2421@}).
{
  return replace(s, xml_invalids, xml_printables);
}

//! Encode a single segment of @[roxen_encode()].
//!
//! See @[roxen_encode()] for details.
static string low_roxen_encode(string val, string encoding)
{
  switch (encoding) {
   case "":
   case "none":
     return val;

   case "utf8":
   case "utf-8":
     return string_to_utf8(val);

   case "base64":
   case "base-64":
   case "b64":
     return MIME.encode_base64(val);

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
     return correctly_http_encode_url(val);

   case "html":
     return html_encode_string (val);

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

   case "js":
   case "javascript":
     return replace (val,
		    ({ "\b", "\014", "\n", "\r", "\t", "\\", "'", "\"" }),
		    ({ "\\b", "\\f", "\\n", "\\r", "\\t", "\\\\",
		       "\\'", "\\\"" }));

   case "mysql":
     return replace (val,
		    ({ "\"", "'", "\\" }),
		    ({ "\\\"" , "\\'", "\\\\" }) );

   case "sql":
   case "oracle":
     return replace (val, "'", "''");

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
//! The segments in the splitted @[encoding] string can be any of
//! the following:
//! @string
//!   @value ""
//!   @value "none"
//!     No encoding.
//!
//!   @value "utf8"
//!   @value "utf-8"
//!     UTF-8 encoding.
//!
//!   @value "base64"
//!   @value "base-64"
//!   @value "b64"
//!     Base-64 MIME encoding.
//!
//!   @value "quotedprintable"
//!   @value "quoted-printable"
//!   @value "qp"
//!     Quoted-Printable MIME encoding.
//!
//!   @value "http"
//!     HTTP encoding.
//!   @value "cookie"
//!     HTTP cookie encoding.
//!   @value "url"
//!     HTTP encoding, including special characters in URL:s.
//!   @value "wml-url"
//!     RFC-compliant HTTP URL encoding.
//!
//!   @value "html"
//!     HTML encoding, for generic text in html documents.
//!   @value "wml"
//!     HTML encoding, and doubling of any @tt{$@}'s.
//!
//!   @value "pike"
//!     Pike string quoting, for use in e.g. the @tt{<pike></pike>@} tag.
//!
//!   @value "js"
//!   @value "javascript"
//!     Javascript string quoting.
//!
//!   @value "mysql"
//!     MySQL quoting.
//!
//!   @value "sql"
//!   @value "oracle"
//!     SQL/Oracle quoting.
//!
//!   @value "mysql-pike"
//!     Compat.
//!     MySQL quoting followed by Pike string quoting.
//!     Equvivalent to using @expr{"mysql.pike"@}.
//!
//!   @value "dtag"
//!   @value "stag"
//!     Compat.
//!
//!   @value "mysql-dtag"
//!   @value "sql-dtag"
//!   @value "oracle-dtag"
//!     Compat.
//! @endstring
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

string fix_relative( string file, RequestID id )
//! Using @expr{@[id]->not_query@}, turns a relative (or already
//! absolute) virtual path into an absolute virtual path, i.e. one
//! rooted at the virtual server's root directory. The returned path
//! is simplified to not contain any @expr{"."@} or @expr{".."@}
//! segments.
{
  if (sscanf (file, "%[-+.a-zA-Z0-9]://%s", string prot, file) == 2)
    return prot + ":/" + combine_path ("/", file);

#if 0
  // This is immensely suspect considering we're dealing with virtual
  // paths here. /mast
  [string prefix, file] = win_drive_prefix(file);
#endif
  string path = id->not_query;

  // +(id->misc->path_info?id->misc->path_info:"");
  if (has_prefix (file, "/"))
    return /*prefix +*/ combine_path ("/", file);
  else if (has_prefix (file, "#"))
    return /*prefix +*/ combine_path ("/", path + file);
  else
    return /*prefix +*/ combine_path ("/", dirname (path), file);
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
#if efun(discdate)
      array(string) not=discdate(t);
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
#if efun(stardate)
      return (string)stardate(t, (int)m->prec||1);
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

class _charset_decoder(object cs)
{
  string decode(string what)
  {
    return cs->clear()->feed(what)->drain();
  }
}

static class CharsetDecoderWrapper
{
  static object decoder;
  string charset;

  static void create (string cs)
  {
    // Would be nice if it was possible to get the canonical charset
    // name back from Locale.Charset so we could use that instead in
    // the client_charset_decoders cache mapping.
    decoder = Locale.Charset.decoder (charset = cs);
    werror ("created %O from %O\n", decoder, cs);
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

static multiset(string) charset_warned_for = (<>);

constant magic_charset_variable_placeholder = "__MaGIC_RoxEn_Actual___charseT";
constant magic_charset_variable_value = "едц&#x829f;@" + magic_charset_variable_placeholder;

static mapping(string:function(string:string)) client_charset_decoders = ([
  "http": http_decode_string,
  "html": Parser.parse_html_entities,
  "utf-8": utf8_to_string,
  "utf-16": unicode_to_string,
]);

static function(string:string) make_composite_decoder (
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
  foreach(heads; string key; string|array(string) val) {
    if (has_value(key, "\n") || has_value(key, "\r") ||
	has_value(key, ":") || has_value(key, " ") || has_value(key, "\t")) {
      error("Invalid headername: %O (value: %O)\n", key, val);
    }
    if (stringp(val) && (has_value(val, "\n") || has_value(val, "\r"))) {
      error("Invalid value for header %O: %O\n", key, val);
    }
    if (arrayp(val)) {
      foreach(val, string v) {
	if (has_value(v, "\n") || has_value(v, "\r")) {
	  error("Invalid value for header %O: %O\n", key, val);
	}
      }
    }
  }
  return ::make_http_headers(heads, no_terminator);
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

#undef CACHE
#undef NOCACHE
#ifdef DEBUG_CACHEABLE
#define CACHE(id,seconds) do {                                                \
  int old_cacheable = ([mapping(string:mixed)]id->misc)->cacheable;           \
  ([mapping(string:mixed)]id->misc)->cacheable =                              \
    min(([mapping(string:mixed)]id->misc)->cacheable,seconds);                \
  report_debug("%s:%d lowered cacheable to %d (was: %d, now: %d)\n",          \
               __FILE__, __LINE__, seconds, old_cacheable,                    \
               ([mapping(string:mixed)]id->misc)->cacheable);                 \
} while(0)
#define NOCACHE(id) do {                                                      \
  int old_cacheable = ([mapping(string:mixed)]id->misc)->cacheable;           \
  ([mapping(string:mixed)]id->misc)->cacheable = 0;                           \
  report_debug("%s:%d set cacheable to 0 (was: %d)\n",                        \
               __FILE__, __LINE__, old_cacheable,                             \
               ([mapping(string:mixed)]id->misc)->cacheable);                 \
} while(0)
#else /* !DEBUG_CACHEABLE */
#define CACHE(id,X) ([mapping(string:mixed)]id->misc)->cacheable=min(([mapping(string:mixed)]id->misc)->cacheable,X)
#define NOCACHE(id) ([mapping(string:mixed)]id->misc)->cacheable=0
#endif /* DEBUG_CACHEABLE */


class QuotaDB
{
#if constant(create_thread)
  object(Thread.Mutex) lock = Thread.Mutex();
#define LOCK()		mixed key__; catch { key__ = lock->lock(); }
#define UNLOCK()	do { if (key__) destruct(key__); } while(0)
#else /* !constant(create_thread) */
#define LOCK()
#define UNLOCK()
#endif /* constant(create_thread) */

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

  static class QuotaEntry
  {
    string name;
    int data_offset;

    static int usage;
    static int quota;

    static void store()
    {
      LOCK();

      QD_WRITE(sprintf("QuotaEntry::store(): Usage for %O is now %O(%O)\n",
		       name, usage, quota));

      data_file->seek(data_offset);
      data_file->write(sprintf("%4c", usage));

      UNLOCK();
    }

    static void read()
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

  static object read_entry(int offset, int|void quota)
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

  static Stdio.File open(string fname, int|void create_new)
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

  static void init_index_acc()
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

  static object low_lookup(string key, int quota)
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

  static mixed `[]( string what )
  {
    RXML.Context ctx = RXML.get_context( );  
    return ctx->get_var( what, scope );
  }

  static mixed `->( string what )
  {
    return `[]( what );
  }

  static mixed `[]=( string what, mixed nval )
  {
    RXML.Context ctx = RXML.get_context( );  
    ctx->set_var( what, nval, scope );
    return nval;
  }

  static mixed `->=( string what, mixed nval )
  {
    return `[]=( what, nval );
  }

  static array(string) _indices( )
  {
    RXML.Context ctx = RXML.get_context( );  
    return ctx->list_var( scope );
  } 

  static array(string) _values( )
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
       CACHE(c->id,1);
       return ENCODE_RXML_INT(time(1)-roxenp()->start_time, type);
     case "uptime-days":
       CACHE(c->id,3600*2);
       return ENCODE_RXML_INT((time(1)-roxenp()->start_time)/3600/24, type);
     case "uptime-hours":
       CACHE(c->id,1800);
       return ENCODE_RXML_INT((time(1)-roxenp()->start_time)/3600, type);
     case "uptime-minutes":
       CACHE(c->id,60);
       return ENCODE_RXML_INT((time(1)-roxenp()->start_time)/60, type);
     case "hits-per-minute":
       CACHE(c->id,2);
       // FIXME: Use float here instead?
       return ENCODE_RXML_INT(c->id->conf->requests / ((time(1)-roxenp()->start_time)/60 + 1),
			      type);
     case "hits":
       NOCACHE(c->id);
       return ENCODE_RXML_INT(c->id->conf->requests, type);
     case "sent-mb":
       CACHE(c->id,10);
       // FIXME: Use float here instead?
       return ENCODE_RXML_TEXT(sprintf("%1.2f",c->id->conf->sent / (1024.0*1024.0)), type);
     case "sent":
       NOCACHE(c->id);
       return ENCODE_RXML_INT(c->id->conf->sent, type);
     case "sent-per-minute":
       CACHE(c->id,2);
       return ENCODE_RXML_INT(c->id->conf->sent / ((time(1)-roxenp()->start_time)/60 || 1),
			      type);
     case "sent-kbit-per-second":
       CACHE(c->id,2);
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
       return ENCODE_RXML_TEXT(__roxen_version__, type);
     case "build":
       return ENCODE_RXML_TEXT(__roxen_build__, type);
     case "dist-version":
       return ENCODE_RXML_TEXT(roxen_dist_version, type);
     case "product-name":
       return ENCODE_RXML_TEXT(roxen_product_name, type);     
     case "time":
       CACHE(c->id,1);
       return ENCODE_RXML_INT(time(),  type);
     case "server":
       return ENCODE_RXML_TEXT (c->id->url_base(), type);
     case "domain":
       sscanf(c->id->url_base(), "%*s://%[^:/]", string tmp);
       return ENCODE_RXML_TEXT(tmp, type);
     case "locale":
       NOCACHE(c->id);
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
  if (!id->my_fd || !id->my_fd->SSLConnection ||
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
    NOCACHE(c->id);
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
    NOCACHE(c->id);
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
static mapping(string:int) since_cache=([ ]);
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
    if(sscanf(dat, "%d-%s-%d %d:%d:%d", day, m, year, hour, minute, second)>2)
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
                 int(1..1)|string|void path )
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

string get_world(array(string) urls) {
  if(!sizeof(urls)) return 0;

  string url=urls[0];
  foreach( ({"http:","https:","ftp:"}), string p)
    foreach(urls, string u)
      if(u[0..sizeof(p)-1]==p) {
	Standards.URI ui = Standards.URI(u);
	ui->fragment=0;
	url=(string)ui;
	break;
      }

  string protocol, server, path="";
  int port;
  if(sscanf(url, "%s://%s:%d/%s", protocol, server, port, path)!=4 &&
     sscanf(url, "%s://%s:%d", protocol, server, port)!=3 &&
     sscanf(url, "%s://%s/%s", protocol, server, path)!=3 &&
     sscanf(url, "%s://%s", protocol, server)!=2 )
    return 0;

  array hosts=({ gethostname() }), dns;
#ifndef NO_DNS
  catch(dns=Protocols.DNS.client()->gethostbyname(hosts[0]));
  if(dns && sizeof(dns))
    hosts+=dns[2]+dns[1];
#endif /* !NO_DNS */

  foreach(hosts, string host)
    if(glob(server, host)) {
      server=host;
      break;
    }

  if(port) return sprintf("%s://%s:%d/%s", protocol, server, port, path);
  return sprintf("%s://%s/%s", protocol, server, path);
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

#ifdef REQUEST_TRACE
static string trace_msg (mapping id_misc, string msg, string name)
{
  msg = html_decode_string (
    Parser.HTML()->_set_tag_callback (lambda (object p, string s) {return "";})->
    finish (msg)->read());

  array(string) lines = msg / "\n";
  if (lines[-1] == "") lines = lines[..sizeof (lines) - 2];

  if (sizeof (lines))
    report_debug ("%s%s%-40s  %s\n",
		  map (lines[..sizeof (lines) - 2],
		       lambda (string s) {
			 return sprintf ("%s%*s%s\n", id_misc->trace_id_prefix,
					 id_misc->trace_level + 1, "", s);
		       }) * "",
		  id_misc->trace_id_prefix,
		  sprintf ("%*s%s", id_misc->trace_level + 1, "", lines[-1]),
		  name);
}

void trace_enter (RequestID id, string msg, object|function thing)
{
  if (id) {
    // Replying on the interpreter lock here. Necessary since requests
    // can finish and be destructed asynchronously which typically
    // leads to races in the TRACE_LEAVE calls in low_get_file.
    mapping id_misc = id->misc;

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
	name = "mod: " + html_decode_string (
	  Parser.HTML()->_set_tag_callback (lambda (object p, string s) {return "";})->
	  finish (name)->read());
      else if (Configuration conf = get_owning_config (thing))
	name = "conf: " + conf->query_name();
      else
	name = sprintf ("obj: %O", thing);
    }
    else name = "";

    trace_msg (id_misc, msg, name);
    id_misc->trace_level++;

    if(function(string,mixed ...:void) _trace_enter =
       [function(string,mixed ...:void)]id_misc->trace_enter)
      _trace_enter (msg, thing);
  }
}

void trace_leave (RequestID id, string desc)
{
  if (id) {
    // Replying on the interpreter lock here. Necessary since requests
    // can finish and be destructed asynchronously which typically
    // leads to races in the TRACE_LEAVE calls in low_get_file.
    mapping id_misc = id->misc;

    if (id_misc->trace_level) id_misc->trace_level--;

    if (sizeof (desc)) trace_msg (id_misc, desc, "");

    if(function(string:void) _trace_leave =
       [function(string:void)]id_misc->trace_leave)
      _trace_leave (desc);
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

class LogPipe
//! The write end of a pipe that will log to the debug log. Use
//! @[get_log_pipe] to create an instance.
{
  inherit Stdio.File;

  static string prefix = "";
  static string line_buf = "";

  static void read_cb (Stdio.File read_end, string data)
  {
    line_buf += data;
    while (sscanf (line_buf, "%[^\n]%*c%s", string line, string rest) == 3) {
      werror (prefix + line + "\n");
      line_buf = rest;
    }
  }

  static void close_cb (Stdio.File read_end)
  {
    if (line_buf != "")
      werror (prefix + line_buf + "\n");
    read_end->set_read_callback (0);
    read_end->set_close_callback (0);
    read_end->set_id (0);
  }

  static void log_pipe_read_thread (Stdio.File read_end)
  {
    while (1) {
      string data = read_end->read (1024, 1);
      if (!data || data == "") break;
      read_cb (read_end, data);
    }
    close_cb (read_end);
  }

  static void create (Stdio.File read_end, Stdio.File write_end,
		      int use_read_thread)
  {
    if (use_read_thread)
      thread_create (log_pipe_read_thread, read_end);
    else {
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
//! @expr{"stderr"@} in a @[Process.create_process] call to get the
//! output from the created process into the debug log. The log data
//! is line buffered to avoid mixing output from different processes
//! on the same line.
//!
//! @note
//! Don't forget to close the returned pipe after the call to
//! @[Process.create_process]. Otherwise the pipe will remain intact
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

#if constant (Locale.Charset.DecodeError)
constant DecodeError = Locale.Charset.DecodeError;
constant EncodeError = Locale.Charset.EncodeError;
#else

static string format_charset_err_msg (
  string intro, string err_str, int err_pos, string charset, string reason)
{
  if (err_pos < 0) {
    err_str = sizeof (err_str) > 43 ?
      sprintf ("%O...", err_str[..39]) : sprintf ("%O", err_str);
  }

  else {
    string pre_context = err_pos > 23 ?
      sprintf ("...%O", err_str[err_pos - 20..err_pos - 1]) :
      err_pos > 0 ?
      sprintf ("%O", err_str[..err_pos - 1]) :
      "";
    string post_context = err_pos < sizeof (err_str) - 24 ?
      sprintf ("%O...", err_str[err_pos + 1..err_pos + 20]) :
      err_pos + 1 < sizeof (err_str) ?
      sprintf ("%O", err_str[err_pos + 1..]) :
      "";
    err_str = sprintf ("%s[0x%x]%s",
		       pre_context, err_str[err_pos], post_context);
  }

  return intro + " " + err_str +
    (charset ? " using " + charset : "") +
    (reason ? ": " + reason : ".\n");
}

class CharsetDecodeError
//! Typed error thrown in some places when charset decoding fails.
{
#if constant (Error.Generic)
  inherit Error.Generic;
#else
  inherit __builtin.generic_error;
#endif
  constant error_type = "charset_decode";
  constant is_charset_decode_error = 1;

  string err_str;
  //! The string that failed to be decoded.

  int err_pos;
  //! The failing position in @[err_str] or @expr{-1@} if not known.

  string charset;
  //! The decoding charset (if known).

  static void create (string err_str, int err_pos, string charset,
		      void|string reason, void|array bt)
  {
    this_program::err_str = err_str;
    this_program::err_pos = err_pos;
    this_program::charset = charset;
    ::create (format_charset_err_msg ("Error decoding",
				      err_str, err_pos, charset, reason),
	      bt);
  }
}

class CharsetEncodeError
//! Typed error thrown in some places when charset encoding fails.
{
#if constant (Error.Generic)
  inherit Error.Generic;
#else
  inherit __builtin.generic_error;
#endif
  constant error_type = "charset_encode";
  constant is_charset_encode_error = 1;

  string err_str;
  //! The string that failed to be encoded.

  int err_pos;
  //! The failing position in @[err_str], -1 if not known.

  string charset;
  //! The encoding charset (if known).

  static void create (string err_str, int err_pos, string charset,
		      void|string reason, void|array bt)
  {
    this_program::err_str = err_str;
    this_program::err_pos = err_pos;
    this_program::charset = charset;
    ::create (format_charset_err_msg ("Error encoding",
				      err_str, err_pos, charset, reason),
	      bt);
  }
}

#endif	// !constant (Locale.Charset.DecodeError)
