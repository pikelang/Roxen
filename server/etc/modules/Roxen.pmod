// This is a roxen pike module. Copyright � 1999 - 2001, Roxen IS.
//
// $Id$

#include <roxen.h>
#include <config.h>
#include <version.h>
#include <module.h>
#include <variables.h>
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

string http_roxen_id_cookie()
{
  return "RoxenUserID=" + roxen->create_unique_id() + "; expires=" +
    http_date (3600*24*365*2 + time (1)) + "; path=/";
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
    id = id[..strlen(id)-1];

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


// --- From the old 'http' file ---------------------------------

mapping http_low_answer( int errno, string data )
//! Return a result mapping with the error and data specified. The
//! error is infact the status response, so '200' is HTTP Document
//! follows, and 500 Internal Server error, etc.
{
  if(!data) data="";
  HTTP_WERR("Return code "+errno+" ("+data+")");
  return
    ([
      "error" : errno,
      "data"  : data,
      "len"   : strlen( data ),
      "type"  : "text/html",
      ]);
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
mapping http_pipe_in_progress()
{
  HTTP_WERR("Pipe in progress");
  return ([ "file":-1, "pipe":1, ]);
}

mapping http_rxml_answer( string rxml, RequestID id,
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


mapping http_try_again( float delay )
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
  return ({delay, ([ "try_again":delay ]) });
}

mapping http_string_answer(string text, string|void type)
//! Generates a result mapping with the given text as the request body
//! with a content type of `type' (or "text/html" if none was given).
{
  HTTP_WERR("String answer ("+(type||"text/html")+")");
  return ([ "data":text, "type":(type||"text/html") ]);
}

mapping http_file_answer(Stdio.File text, string|void type, void|int len)
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


static int chd_lt;
static string chd_lf;

string cern_http_date(int t)
//! Return a date, formated to be used in the common log format
{
  if( t == chd_lt ) return chd_lf;

  string c;
  mapping(string:int) lt = localtime(t);
  int tzh = lt->timezone/3600 - lt->isdst;
  if(tzh > 0)
    c="-";
  else {
    tzh = -tzh;
    c="+";
  }
  chd_lt = t;
  return(chd_lf=sprintf("%02d/%s/%04d:%02d:%02d:%02d %s%02d00",
		 lt->mday, months[lt->mon], 1900+lt->year,
		 lt->hour, lt->min, lt->sec, c, tzh));
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

string http_encode_string(string f)
//! Encode dangerous characters in a string so that it can be used as
//! a URL. Specifically, nul, space, tab, newline, linefeed, %, ' and
//! " are quoted.
{
  return replace(f, ({ "\000", " ", "\t", "\n", "\r", "%", "'", "\"" }),
		 ({"%00", "%20", "%09", "%0a", "%0d", "%25", "%27", "%22"}));
}

string http_encode_cookie(string f)
//! Encode dangerous characters in a string so that it can be used as
//! the value string or name string in a cookie.
{
  return replace(f, ({ "=", ",", ";", "%" }), ({ "%3d", "%2c", "%3b", "%25"}));
}

string http_encode_url (string f)
//! Encodes any string to be used as a literal in a URL. This means
//! that in addition to the characters encoded by
//! @[http_encode_string], it encodes all URL special characters, i.e.
//! /, #, ?, & etc.
{
  return replace (f, ({"\000", " ", "\t", "\n", "\r", "%", "'", "\"", "#",
		       "&", "?", "=", "/", ":", "+"}),
		  ({"%00", "%20", "%09", "%0a", "%0d", "%25", "%27", "%22", "%23",
		    "%26", "%3f", "%3d", "%2f", "%3a", "%2b"}));

}

//! Encodes any string to be used as a literal in a URL. This function
//! quotes all reserved and forbidden characters, including eight bit
//! characters. If the string is a wide string a UTF-8 conversion is
//! made.
string correctly_http_encode_url(string f) {
  if(String.width(f)>8)
    f = string_to_utf8(f);
  return map(f/1, lambda(string in) {
    int c = in[0];
    // if(c>255) return sprintf("%%u%04x", c);
    if( c<33 || c>126 ||
	(< '"', '#', '%', '&', '\'', '+',
	   '<', '>', '?', '/', ':', ';',
	   '@', ',', '$', '=' >)[c] )
      return sprintf("%%%02x", c);
    return in;
  } ) * "";
}

string add_pre_state( string url, multiset state )
//! Adds the provided states as prestates to the provided url.
{
  if(!url)
    error("URL needed for add_pre_state()\n");
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

mapping http_redirect( string url, RequestID|void id, multiset|void prestates,
		       mapping|void variables)
//! Simply returns a http-redirect message to the specified URL. If
//! the url parameter is just a virtual (possibly relative) path, the
//! current id object must be supplied to resolve the destination URL.
//! If no prestates are provided, the current prestates in the request
//! id object will be added to the URL, if the url is a local absolute
//! or relative URL.
//!
//! If @[variables] is given it's a mapping containing variables that
//! should be appended to the URL. Each index is a variable name and
//! the value can be a string or an array, in which case a separate
//! variable binding is added for each string in the array. That means
//! that e.g. @[RequestID.real_variables] can be used as @[variables].
{
  // If we don't get any URL we don't know what to do.
  // But we do!  /per
  if(!url)
    url = "";

  // If the URL is a local relative URL we make it absolute.
  if(!has_value(url, "://") && (!strlen(url) || url[0] != '/') )
    url = fix_relative(url, id);
  
  // Add protocol and host to local absolute URLs.
  if(strlen(url) && url[0]=='/') {
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
    url += "?magic_roxen_automatic_charset_variable=���";

  url = http_encode_string (url);
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

  HTTP_WERR("Redirect -> "+url);

  return http_low_answer( 302, "Redirect to "+url)
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

mapping http_auth_required(string realm, string|void message)
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
  HTTP_WERR("Auth required ("+realm+")");
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
    message = "<h1>Proxy authentication failed.\n</h1>";
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
  RequestID tmpid;

  if(id->query && strlen(id->query))
    new->INDEX=id->query;

  if(path_info && strlen(path_info))
  {
    string t, t2;
    if(path_info[0] != '/')
      path_info = "/" + path_info;

    t = t2 = "";

    // Kludge
    if ( ([mapping(string:mixed)]id->misc)->path_info == path_info ) {
      // Already extracted
      new["SCRIPT_NAME"]=id->not_query;
    } else {
      new["SCRIPT_NAME"]=
	id->not_query[0..strlen([string]id->not_query)-strlen(path_info)-1];
    }
    new["PATH_INFO"]=path_info;


    while(1)
    {
      // Fix PATH_TRANSLATED correctly.
      t2 = id->conf->real_file(path_info, id);
      if(t2)
      {
	new["PATH_TRANSLATED"] = t2 + t;
	break;
      }
      array(string) tmp = path_info/"/" - ({""});
      if(!sizeof(tmp))
	break;
      path_info = "/" + (tmp[0..sizeof(tmp)-2]) * "/";
      t = tmp[-1] +"/" + t;
    }
  } else
    new["SCRIPT_NAME"]=id->not_query;
  tmpid = id;
  while(tmpid->misc->orig)
    // internal get
    tmpid = tmpid->misc->orig;

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
			       "security-scheme", "proxy" }), string h) {
      string hh = "HTTP_" + replace(upper_case(h),
				    ({ " ", "-", "\0", "=" }),
				    ({ "_", "_", "", "_" }));

      hh = mk_env_var_name(hh);
      if (hh == "HTTP_PROXY") continue;	// Protect against httpoxy.
      new[hh] = replace(hdrs[h], ({ "\0" }), ({ "" }));
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
    while(
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
=([ "&nbsp;":   "�",
    "&iexcl;":  "�",
    "&cent;":   "�",
    "&pound;":  "�",
    "&curren;": "�",
    "&yen;":    "�",
    "&brvbar;": "�",
    "&sect;":   "�",
    "&uml;":    "�",
    "&copy;":   "�",
    "&ordf;":   "�",
    "&laquo;":  "�",
    "&not;":    "�",
    "&shy;":    "�",
    "&reg;":    "�",
    "&macr;":   "�",
    "&deg;":    "�",
    "&plusmn;": "�",
    "&sup2;":   "�",
    "&sup3;":   "�",
    "&acute;":  "�",
    "&micro;":  "�",
    "&para;":   "�",
    "&middot;": "�",
    "&cedil;":  "�",
    "&sup1;":   "�",
    "&ordm;":   "�",
    "&raquo;":  "�",
    "&frac14;": "�",
    "&frac12;": "�",
    "&frac34;": "�",
    "&iquest;": "�",
    "&Agrave;": "�",
    "&Aacute;": "�",
    "&Acirc;":  "�",
    "&Atilde;": "�",
    "&Auml;":   "�",
    "&Aring;":  "�",
    "&AElig;":  "�",
    "&Ccedil;": "�",
    "&Egrave;": "�",
    "&Eacute;": "�",
    "&Ecirc;":  "�",
    "&Euml;":   "�",
    "&Igrave;": "�",
    "&Iacute;": "�",
    "&Icirc;":  "�",
    "&Iuml;":   "�",
    "&ETH;":    "�",
    "&Ntilde;": "�",
    "&Ograve;": "�",
    "&Oacute;": "�",
    "&Ocirc;":  "�",
    "&Otilde;": "�",
    "&Ouml;":   "�",
    "&times;":  "�",
    "&Oslash;": "�",
    "&Ugrave;": "�",
    "&Uacute;": "�",
    "&Ucirc;":  "�",
    "&Uuml;":   "�",
    "&Yacute;": "�",
    "&THORN;":  "�",
    "&szlig;":  "�",
    "&agrave;": "�",
    "&aacute;": "�",
    "&acirc;":  "�",
    "&atilde;": "�",
    "&auml;":   "�",
    "&aring;":  "�",
    "&aelig;":  "�",
    "&ccedil;": "�",
    "&egrave;": "�",
    "&eacute;": "�",
    "&ecirc;":  "�",
    "&euml;":   "�",
    "&igrave;": "�",
    "&iacute;": "�",
    "&icirc;":  "�",
    "&iuml;":   "�",
    "&eth;":    "�",
    "&ntilde;": "�",
    "&ograve;": "�",
    "&oacute;": "�",
    "&ocirc;":  "�",
    "&otilde;": "�",
    "&ouml;":   "�",
    "&divide;": "�",
    "&oslash;": "�",
    "&ugrave;": "�",
    "&uacute;": "�",
    "&ucirc;":  "�",
    "&uuml;":   "�",
    "&yacute;": "�",
    "&thorn;":  "�",
    "&yuml;":   "�",
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

  int t2,t1;

  [string prefix, file] = win_drive_prefix(file);

  if(file[0] != '/')
    t2 = 1;

  if(strlen(file) > 1
     && file[-2]=='/'
     && ((file[-1] == '/') || (file[-1]=='.'))
	)
    t1=1;

  file=combine_path("/", file);

  if(t1) file += "/.";
  if(t2) return prefix + file[1..];

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

string strftime(string fmt, int t)
//! Encodes the time `t' according to the format string `fmt'.
{
  if(!sizeof(fmt)) return "";
  mapping lt = localtime(t);
  fmt=replace(fmt, "%%", "\0");
  array(string) a = fmt/"%";
  string res = a[0];

  foreach(a[1..], string key) {
    if(key=="") continue;
    switch(key[0]) {
    case 'a':	// Abbreviated weekday name
      res += ({ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" })[lt->wday];
      break;
    case 'A':	// Weekday name
      res += ({ "Sunday", "Monday", "Tuesday", "Wednesday",
		"Thursday", "Friday", "Saturday" })[lt->wday];
      break;
    case 'b':	// Abbreviated month name
    case 'h':	// Abbreviated month name
      res += ({ "Jan", "Feb", "Mar", "Apr", "May", "Jun",
		"Jul", "Aug", "Sep", "Oct", "Nov", "Dec" })[lt->mon];
      break;
    case 'B':	// Month name
      res += ({ "January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December" })[lt->mon];
      break;
    case 'c':	// Date and time
      res += strftime(sprintf("%%a %%b %02d  %02d:%02d:%02d %04d",
			      lt->mday, lt->hour, lt->min, lt->sec, 1900 + lt->year), t);
      break;
    case 'C':	// Century number; 0-prefix
      res += sprintf("%02d", 19 + lt->year/100);
      break;
    case 'd':	// Day of month [1,31]; 0-prefix
      res += sprintf("%02d", lt->mday);
      break;
    case 'D':	// Date as %m/%d/%y
      res += strftime("%m/%d/%y", t);
      break;
    case 'e':	// Day of month [1,31]; space-prefix
      res += sprintf("%2d", lt->mday);
      break;
    case 'E':
    case 'O':
      key = key[1..]; // No support for E or O extension.
      break;
    case 'H':	// Hour (24-hour clock) [0,23]; 0-prefix
      res += sprintf("%02d", lt->hour);
      break;
    case 'I':	// Hour (12-hour clock) [1,12]; 0-prefix
      res += sprintf("%02d", 1 + (lt->hour + 11)%12);
      break;
    case 'j':	// Day number of year [1,366]; 0-prefix
      res += sprintf("%03d", lt->yday);
      break;
    case 'k':	// Hour (24-hour clock) [0,23]; space-prefix
      res += sprintf("%2d", lt->hour);
      break;
    case 'l':	// Hour (12-hour clock) [1,12]; space-prefix
      res += sprintf("%2d", 1 + (lt->hour + 11)%12);
      break;
    case 'm':	// Month number [1,12]; 0-prefix
      res += sprintf("%02d", lt->mon + 1);
      break;
    case 'M':	// Minute [00,59]; 0-prefix
      res += sprintf("%02d", lt->min);
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
      res += sprintf("%02d", lt->sec);
      break;
    case 't':	// Tab
      res += "\t";
      break;
    case 'T':	// Time as %H:%M:%S
    case 'X':
      res += sprintf("%02d:%02d:%02d", lt->hour, lt->min, lt->sec);
      break;
    case 'u':	// Weekday as a decimal number [1,7], Sunday == 1
      res += sprintf("%d", lt->wday + 1);
      break;
    case 'w':	// Weekday as a decimal number [0,6], Sunday == 0
      res += sprintf("%d", lt->wday);
      break;
    case 'x':	// Date
      res += strftime("%a %b %d %Y", t);
      break;
    case 'y':	// Year [00,99]; 0-prefix
      res += sprintf("%02d", lt->year % 100);
      break;
    case 'Y':	// Year [0000.9999]; 0-prefix
      res += sprintf("%04d", 1900 + lt->year);
      break;

    case 'U':	// Week number of year as a decimal number [00,53],
		// with Sunday as the first day of week 1; 0-prefix
      res += sprintf("%02d", ((lt->yday-1+lt->wday)/7));
      break;
    case 'V':	// ISO week number of the year as a decimal number [01,53]; 0-prefix
      res += sprintf("%02d", Calendar.ISO.Second(t)->week_no());
      break;
    case 'W':	// Week number of year as a decimal number [00,53],
		// with Monday as the first day of week 1; 0-prefix
      res += sprintf("%02d", ((lt->yday+(5+lt->wday)%7)/7));
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

string roxen_encode( string val, string encoding )
//! Quote strings in a multitude of ways. Used primarily by entity quoting.
//! The encoding string can be any of the following:
//! none   - No encoding
//! http   - HTTP encoding
//! cookie - HTTP cookie encoding
//! url    - HTTP encoding, including special characters in URL:s
//! html   - HTML encofing, for generic text in html documents.
//! pike   - Pike string quoting, for use in e.g. the <pike></pike> tag.
//! js     - Javascript string quoting.
//! mysql  - MySQL quoting.
//! oracle - Oracle quoting.
//! mysql-pike - MySQL quoting followed by Pike string quoting.
{
  switch (encoding) {
   case "":
   case "none":
     return val;

   case "http":
     return http_encode_string (val);

   case "cookie":
     return http_encode_cookie (val);

   case "url":
     return http_encode_url (val);

   case "wml-url":
     return correctly_http_encode_url(val);

   case "html":
     return html_encode_string (val);

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

string fix_relative( string file, RequestID id )
//! Turns a relative (or already absolute) virtual path into an
//! absolute virtual path, that is, one rooted at the virtual server's
//! root directory. The returned path is @[simplify_path()]:ed.
{
  string path = id->not_query;
  if( !search( file, "http:" ) )
    return file;

  [string prefix, file] = win_drive_prefix(file);

  // +(id->misc->path_info?id->misc->path_info:"");
  if(file != "" && file[0] == '/')
    ;
  else if(file != "" && file[0] == '#')
    file = path + file;
  else
    file = dirname(path) + "/" +  file;
  return simplify_path(prefix + file);
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
  if(id->misc->defines->theme_language) lang=id->misc->defines->theme_language;
  if(m->lang) lang=m->lang;

  if(m->strftime)
    return strftime(m->strftime, t);

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
  if (m->days)    t+=(int)(m->days)*86400;
  if (m->weeks)   t+=(int)(m->weeks)*604800;
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

static multiset(string) charset_warned_for = (<>);

function get_client_charset_decoder( string ���, RequestID|void id )
  //! Returns a decoder for the clients charset, given the clients
  //! encoding of the string "���&#x829f;".
  //! See the roxen-automatic-charset-variable tag.
{
  // Netscape seems to send "?" for characters that can't be represented
  // by the current character set while IE encodes those characters
  // as entities, while Opera uses "\201" or "?x829f;"...
  string test = replace((���/"\0")[0],
			({ "&aring;", "&#229;", "&#xe5;",
			   "&auml;", "&#228;", "&#xe4;",
			   "&ouml;", "&#246;", "&#xf6;",
			   "&#33439;","&#x829f;", "\201", "?x829f;" }),
			({ "?", "?", "?",
			   "?", "?", "?",
			   "?", "?", "?",
			   "?", "?", "?", "?" }));
			
  switch( test ) {
  case "edv":
  case "edv?":
    report_notice( "Warning: Non 8-bit safe client detected (%s)",
		   (id?id->client*" ":"unknown client"));
    return 0;

  case "���":
  case "���?":
    return 0;
    
  case "\33-A���":
  case "\33-A\345\344\366\33$Bgl":
    id && id->set_output_charset && id->set_output_charset( "iso-2022" );
    return _charset_decoder(Locale.Charset.decoder("iso-2022-jp"))->decode;
    
  case "+AOUA5AD2-":
  case "+AOUA5AD2gp8-":
    id && id->set_output_charset && id->set_output_charset( "utf-7" );
     return _charset_decoder(Locale.Charset.decoder("utf-7"))->decode;
     
  case "åäö":
  case "åäö?":
  case "åä":
  case "åäö\350\212\237":
    id && id->set_output_charset && id->set_output_charset( "utf-8" );
    return utf8_to_string;

  case "\214\212\232":
  case "\214\212\232?":
    id && id->set_output_charset && id->set_output_charset( "mac" );
    return _charset_decoder( Locale.Charset.decoder( "mac" ) )->decode;
    
  case "\0�\0�\0�":
  case "\0�\0�\0�\202\237":
     id&&id->set_output_charset&&id->set_output_charset(string_to_unicode);
     return unicode_to_string;
     
  case "\344\214":
  case "???\344\214":
  case "\217\206H\217\206B\217\206r\344\214": // Netscape sends this (?!)
    id && id->set_output_charset && id->set_output_charset( "shift_jis" );
    return _charset_decoder(Locale.Charset.decoder("shift_jis"))->decode;
  }
  if (!charset_warned_for[test] && (sizeof(charset_warned_for) < 256)) {
    charset_warned_for[test] = 1;
    report_warning( "Unable to find charset decoder for %O, vector: %O\n",
		    ���, test);
  }
}


// Low-level C-roxen optimization functions.
inherit _Roxen;

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
#define CACHE(id,X) ([mapping(string:mixed)]id->misc)->cacheable=min(([mapping(string:mixed)]id->misc)->cacheable,X)
#define NOCACHE(id) ([mapping(string:mixed)]id->misc)->cacheable=0


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

#if !constant(set_weak_flag)
    static int refs;

    void add_ref()
    {
      refs++;
    }

    void free_ref()
    {
      if (!(--refs)) {
	destruct();
      }
    }
  }

  static class QuotaProxy
  {
    static object(QuotaEntry) master;

    function(string, int:int) check_quota;
    function(string, int:int) allocate;
    function(string, int:int) deallocate;
    function(string, int:void) set_usage;
    function(string:int) get_usage;

    void create(object(QuotaEntry) m)
    {
      master = m;
      master->add_ref();
      check_quota = master->check_quota;
      allocate = master->allocate;
      deallocate = master->deallocate;
      set_usage = master->set_usage;
      get_usage = master->get_usage;
    }

    void destroy()
    {
      master->free_ref();
    }
#endif /* !constant(set_weak_flag) */
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

#if constant(set_weak_flag)
      return res;
#else /* !constant(set_weak_flag) */
      return QuotaProxy(res);
#endif /* constant(set_weak_flag) */
    }
    if (res = low_lookup(key, quota)) {
      active_objects[key] = res;

#if constant(set_weak_flag)
      return res;
#else /* !constant(set_weak_flag) */
      return QuotaProxy(res);
#endif /* constant(set_weak_flag) */
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

#if constant(set_weak_flag)
    set_weak_flag(active_objects, 1);
#endif /* constant(set_weak_flag) */

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
    switch(var)
    {
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
    }
    mixed val = c->misc->scope_roxen[var];
    if (zero_type(val)) return RXML.nil;
    if (objectp(val) && val->rxml_var_eval) return val;
    return ENCODE_RXML_TEXT(val, type);
  }

  mixed `[]= (string var, mixed val, void|RXML.Context c, 
	      void|string scope_name) {
    if (!c) c = RXML_CONTEXT;
    return c->misc->scope_roxen[var]=val;
  }

  array(string) _indices(void|RXML.Context c) {
    if (!c) c = RXML_CONTEXT;
    return indices(c->misc->scope_roxen) +
      ({ "uptime", "uptime-days", "uptime-hours", "uptime-minutes",
	 "hits-per-minute", "hits", "sent-mb", "sent", "unique-id",
	 "sent-per-minute", "sent-kbit-per-second", "ssl-strength",
	 "pike-version", "version", "time", "server", "domain",
	 "locale", "path" });
  }

  void _m_delete (string var, void|RXML.Context c, void|string scope_name) {
    if (!c) c = RXML_CONTEXT;
    predef::m_delete(c->misc->scope_roxen, var);
  }

  string _sprintf() { return "RXML.Scope(roxen)"; }
}

class ScopePage {
  inherit RXML.Scope;
  constant converter=(["fgcolor":"fgcolor", "bgcolor":"bgcolor",
		       "theme-bgcolor":"theme_bgcolor", "theme-fgcolor":"theme_fgcolor",
		       "theme-language":"theme_language"]);

  mixed `[] (string var, void|RXML.Context c, void|string scope, void|RXML.Type type) {
    if (!c) c = RXML_CONTEXT;
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
	c->id->misc->cacheable = 0;
	if (!c->id->my_fd || !c->id->my_fd->session) return ENCODE_RXML_INT(0, type);
	return ENCODE_RXML_INT(c->id->my_fd->session->cipher_spec->key_bits, type);
      case "dir":
	array parts = c->id->not_query/"/";
	return ENCODE_RXML_TEXT( parts[..sizeof(parts)-2]*"/"+"/", type);
      case "counter":
	return ENCODE_RXML_INT(++c->misc->internal_counter, type);
    }
    mixed val;
    if(converter[var])
      val = c->misc[converter[var]];
    else
      val = c->misc->scope_page[var];
    if( zero_type(val) ) return RXML.nil;
    if (objectp (val) && val->rxml_var_eval) return val;
    return ENCODE_RXML_TEXT(val, type);
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
    return ind + ({"pathinfo"});
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

  string _sprintf() { return "RXML.Scope(page)"; }
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

  string _sprintf() { return "RXML.Scope(Cookie)"; }
}

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

  void prepare_context (RXML.Context c) {
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
  if( expire_time_delta )
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
static string trace_msg (RequestID id, string msg, string name)
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
			 return sprintf ("%s%*s%s\n", id->misc->trace_id_prefix,
					 id->misc->trace_level + 1, "", s);
		       }) * "",
		  id->misc->trace_id_prefix,
		  sprintf ("%*s%s", id->misc->trace_level + 1, "", lines[-1]),
		  name);
}

void trace_enter (RequestID id, string msg, object|function thing)
{
  if (!id->misc->trace_level) {
    id->misc->trace_id_prefix = ({"%%", "##", "��", "**", "@@", "$$", "��"})[
      all_constants()->id_trace_level_rotate_counter++ % 7];
#ifdef ID_OBJ_DEBUG
    report_debug ("%s%s %O: Request handled by: %O\n",
		  id->misc->trace_id_prefix, id->misc->trace_id_prefix[..0],
		  id, id->conf);
#else
    report_debug ("%s%s Request handled by: %O\n",
		  id->misc->trace_id_prefix, id->misc->trace_id_prefix[..0],
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

  trace_msg (id, msg, name);
  id->misc->trace_level++;

  if(function(string,mixed ...:void) _trace_enter =
     [function(string,mixed ...:void)]([mapping(string:mixed)]id->misc)->trace_enter)
    _trace_enter (msg, thing);
}

void trace_leave (RequestID id, string desc)
{
  if (id->misc->trace_level) id->misc->trace_level--;

  if (sizeof (desc)) trace_msg (id, desc, "");

  if(function(string:void) _trace_leave =
     [function(string:void)]([mapping(string:mixed)]id->misc)->trace_leave)
    _trace_leave (desc);
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
