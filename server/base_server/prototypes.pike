// This file is part of Roxen WebServer.
// Copyright © 2001, Roxen IS.

#include <stat.h>
#include <config.h>
#include <module.h>
#include <variables.h>
#include <module_constants.h>
constant cvs_version="$Id: prototypes.pike,v 1.61 2003/06/11 15:46:41 grubba Exp $";

class Variable
{
  constant is_variable = 1;
  constant type = "Basic";

  string get_warnings();
  int get_flags();
  void set_flags( int flags );
  int check_visibility( RequestID id,
                        int more_mode,
                        int expert_mode,
                        int devel_mode,
                        int initial,
                        int|void variable_in_cfif );
  void set_invisibility_check_callback( function(RequestID,Variable:int) cb );
  function(Variable:void) get_changed_callback( );
  void set_changed_callback( function(Variable:void) cb );
  void add_changed_callback( function(Variable:void) cb );
  function(RequestID,Variable:int) get_invisibility_check_callback() ;
  string doc(  );
  string name(  );
  string type_hint(  );
  mixed default_value();
  void set_warning( string to );
  int set( mixed to );
  int low_set( mixed to );  
  mixed query();
  int is_defaulted();
  array(string|mixed) verify_set( mixed new_value );
  mapping(string:string) get_form_vars( RequestID id );
  mixed transform_from_form( string what );
  void set_from_form( RequestID id );
  string path();
  void set_path( string to );
  string render_form( RequestID id, void|mapping additional_args );
  string render_view( RequestID id );
}

class BasicDefvar
{
  mapping(string:Variable)  variables=([]);
  Variable getvar( string name );
  int deflocaledoc( string locale, string variable,
                    string name, string doc, mapping|void translate );
  void set(string var, mixed value);
  int killvar(string var);
  void setvars( mapping (string:mixed) vars );
  Variable defvar(string var, mixed value, 
                  mapping|string|void|object name,
                  int|void type, 
                  mapping|string|void|object doc_str, 
                  mixed|void misc,
                  int|function|void not_in_config,
                  mapping|void option_translations);
  mixed query(string|void var, int|void ok);
  void definvisvar(string name, mixed value, int type, array|void misc);
}



class StringFile( string data, mixed|void _st )
{
  int offset;

  string _sprintf()
  {
    return "StringFile("+strlen(data)+","+offset+")";
  }

  string read(int nbytes)
  {
    if(!nbytes)
    {
      offset = strlen(data);
      return data;
    }
    string d = data[offset..offset+nbytes-1];
    offset += strlen(d);
    return d;
  }

  array stat()
  {
    if( _st ) return (array)_st;
    return ({ 0, strlen(data), time(), time(), time(), 0, 0, 0 });
  }

  void write(mixed ... args)
  {
    throw( ({ "File not open for write\n", backtrace() }) );
  }

  void seek(int to)
  {
    offset = to;
  }
}

class ModuleInfo
{
  string sname;
  string filename;

  int last_checked;
  int type, multiple_copies;
  int|string locked;
  mapping(Configuration:int) config_locked;
  
  string get_name();
  string get_description();
  RoxenModule instance( object conf, void|int silent );
  void save();
  void update_with( RoxenModule mod, string what );
  int init_module( string what );
  int rec_find_module( string what, string dir );
  int find_module( string sn );
  int check (void|int force);
}

class ModuleCopies
{
  mapping copies = ([]);
  mixed `[](mixed q )
  {
    return copies[q];
  }
  mixed `[]=(mixed q,mixed w )
  {
    return copies[q]=w;
  }
  array _indices()
  {
    return indices(copies);
  }
  array _values()
  {
    return values(copies);
  }
  string _sprintf( ) { return "ModuleCopies("+sizeof(copies)+")"; }
}

class Configuration
{
  inherit BasicDefvar;
  constant is_configuration = 1;
  mapping enabled_modules = ([]);
  mapping(string:array(int)) error_log=([]);

#ifdef PROFILE
  mapping profile_map = ([]);
#endif

  class Priority
  {
    string _sprintf()
    {
      return "Priority()";
    }

    array (RoxenModule) url_modules = ({ });
    array (RoxenModule) logger_modules = ({ });
    array (RoxenModule) location_modules = ({ });
    array (RoxenModule) filter_modules = ({ });
    array (RoxenModule) last_modules = ({ });
    array (RoxenModule) first_modules = ({ });
    mapping (string:array(RoxenModule)) file_extension_modules = ([ ]);
    mapping (RoxenModule:multiset(string)) provider_modules = ([ ]);
  }

  class DataCache
  {
    int current_size, max_size, max_file_size;
    int hits, misses;
    void flush();
    void expire_entry( string url );
    void set( string url, string data, mapping meta, int expire );
    array(string|mapping(string:mixed)) get( string url );
    void init_from_variables( );
  };

  array(Priority) allocate_pris();

  object      throttler;
  RoxenModule types_module;
  RoxenModule dir_module;
  function    types_fun;

  string name;
  int inited;

  // Protocol specific statistics.
  int requests, sent, hsent, received;

  function(string:int) log_function;
  DataCache datacache;
  
  int get_config_id();
  string get_doc_for( string region, string variable );
  string query_internal_location(RoxenModule|void mod);
  string query_name();
  string comment();
  void unregister_urls();
  void stop(void|int asynch);
  string|array(string) type_from_filename( string file, int|void to,
					   string|void myext );

  string get_url();

  array (RoxenModule) get_providers(string provides);
  RoxenModule get_provider(string provides);
  array(mixed) map_providers(string provides, string fun, mixed ... args);
  mixed call_provider(string provides, string fun, mixed ... args);
  array(function) file_extension_modules(string ext);
  array(function) url_modules();
  mapping api_functions(void|RequestID id);
  array(function) logger_modules();
  array(function) last_modules();
  array(function) first_modules();
  array location_modules();
  array(function) filter_modules();
  void init_log_file();
  int|mapping check_security(function|object a, RequestID id, void|int slevel);
  void invalidate_cache();
  void clear_memory_caches();
  string examine_return_mapping(mapping m);
  mapping|int(-1..0) low_get_file(RequestID id, int|void no_magic);
  mapping get_file(RequestID id, int|void no_magic, int|void internal_get);
  array(string) find_dir(string file, RequestID id, void|int(0..1) verbose);
  array(int)|object(Stdio.Stat) stat_file(string file, RequestID id);
  array open_file(string fname, string mode, RequestID id, void|int ig);
  mapping(string:array(mixed)) find_dir_stat(string file, RequestID id);
  array access(string file, RequestID id);
  string real_file(string file, RequestID id);
  int|string try_get_file(string s, RequestID id,
                          int|void status, int|void nocache,
                          int|void not_internal, mapping|void result_mapping);
  int(0..1) is_file(string virt_path, RequestID id, int(0..1)|void internal);
  void start(int num);
  void save_me();
  int save_one( RoxenModule o );
  RoxenModule reload_module( string modname );
  RoxenModule enable_module( string modname, RoxenModule|void me, 
                             ModuleInfo|void moduleinfo, 
                             int|void nostart,
                             int|void nosave );
  void call_start_callbacks( RoxenModule me, 
                             ModuleInfo moduleinfo, 
                             ModuleCopies module );
  void call_low_start_callbacks( RoxenModule me, 
                                 ModuleInfo moduleinfo, 
                                 ModuleCopies module );
  int disable_module( string modname, int|void nodest );
  int add_modules( array(string) mods, int|void now );
  RoxenModule find_module(string name);
#if ROXEN_COMPAT < 2.2
  Sql.Sql sql_cache_get(string what);
  Sql.Sql sql_connect(string db);
#endif
  void enable_all_modules();
  void low_init(void|int modules_already_enabled);


  string parse_rxml(string what, RequestID id,
                    void|Stdio.File file,
                    void|mapping defines );
  void add_parse_module (RoxenModule mod);
  void remove_parse_module (RoxenModule mod);

  string real_file(string a, RequestID b);


  mapping authenticate_throw( RequestID id, string realm,
			      UserDB|void database,
			      AuthModule|void method);
  User authenticate( RequestID id,
		     UserDB|void database,
		     AuthModule|void method );

  array(AuthModule) auth_modules();
  array(UserDB) user_databases();

  AuthModule find_auth_module( string name );
  UserDB find_user_database( string name );
  
  static string _sprintf( )
  {
    return "Configuration("+name+")";
  }
}

//! @appears Protocol
class Protocol 
{
  inherit BasicDefvar;

  constant name = "unknown";
  //! Name used for internal identification.

  constant prot_name = "unknown";
  //! Name of the protocol as seen in the protocol part of a url.

  constant supports_ipless = 0;
  constant requesthandlerfile = "";
  constant default_port = 4711;

  int bound;
  int refs;

  program requesthandler;

  string path;
  int port;
  string ip;
  array(string) sorted_urls = ({});
  mapping(string:mapping) urls = ([]);
  mapping(Configuration:mapping) conf_data = ([]);

  void ref(string url, mapping data);
  void unref(string url);
  Configuration find_configuration_for_url( string url, RequestID id, 
                                            int|void no_default );
  string get_key();
  void save();
  void restore();
};


class FakedVariables( mapping real_variables )
{
  static array _indices()
  {
    return indices( real_variables );
  }

  static array _values()
  {
    return map( _indices(), `[] );
  }

  static mixed fix_value( mixed what )
  {
    if( !what ) return what;
    if( !arrayp(what) ) return what; // huh

    if( sizeof( what ) == 1 )
      return what[0];
    return what*"\0";
  }

  static mixed `[]( string ind ) {
    return fix_value( real_variables[ ind ] );
  }

  static mixed `->(string ind ) {
    return `[]( ind );
  }

  static mixed `[]=( string ind, mixed what ) {
    real_variables[ ind ] = ({ what });
    return what;
  }

  static mixed `->=(string ind, mixed what ) {
    return `[]=( ind,what );
  }

  static mixed _m_delete( mixed what ) {
//     report_debug(" _m_delete( %O )\n", what );
    return fix_value( m_delete( real_variables, what ) );
  }

  static int _equal( mixed what ) {
    return `==(what);
  }

  static int `==( mixed what ) {
    if( mappingp( what ) && (real_variables == what) )
      return 1;
  }

  static string _sprintf( int f )
  {
    switch( f )
    {
      case 'O':
	return sprintf( "FakedVariables(%O)", real_variables );
      default:
	return sprintf( sprintf("%%%c", f ), real_variables );
    }
  }

  static this_program `|( mapping what )
  {
    foreach( indices(what), string q )`[]=( q,what[q] );
    return this_object();
  }

  static this_program `+=( mapping what )
  {
    foreach( indices(what), string q )`[]=( q,what[q] );
    return this_object();
  }

  static this_program `+( mapping what )
  {
    foreach( indices(what), string q )`[]=( q,what[q] );
    return this_object();
  }

  static mapping cast(string to)
  {
    if (to[..6]=="mapping")
    {
       array v=indices(real_variables);
       return mkmapping(v,map(v,`[]));
    }	  
	  
    error("can't cast to %O\n",to);
  }
}

class PrefLanguages
//! @appears PrefLanguages
//! Support for language preferences. This object is typically
//! accessed through @tt{id->misc->pref_languages@}.
{
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
    decoded=1;
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


//  Kludge for resolver problems
static function _charset_decoder_func;

class RequestID
//! @appears RequestID
//! The request information object contains all request-local information and
//! server as the vessel for most forms of intercommunication between modules,
//! scripts, RXML and so on. It gets passed round to almost all API callbacks
//! worth mentioning. A RequestID object is born when an incoming request is
//! encountered, and its life expectancy is short, as it dies again when the
//! request has passed through all levels of the <ref>module type calling
//! sequence</ref>.
{
  Configuration conf;

  Protocol port_obj;
  //! The port object this request came from.

  int time;
  //! Time of the request, standard unix time (seconds since the epoch; 1970).

  string raw_url;
  //! The nonparsed, nontouched, non-* URL requested by the client.
  //! Hence, this path is unlike <ref>not_query</ref> and
  //! <ref>virtfile</ref> not relative to the server URL and must be
  //! used in conjunction with the former to generate absolute paths
  //! within the server. Be aware that this string will contain any
  //! URL variables present in the request as well as the file path.

  int do_not_disconnect;
  //! Typically 0, meaning the channel to the client will be disconnected upon
  //! finishing the request and the RequestID object destroyed with it.

  mapping (string:array) real_variables;
  //! Form variables submitted by the client browser, as found in the
  //! <tt>form</tt> scope in RXML. Both query (as found in the query part of
  //! the URL) and POST (submitted in the request body) variables share this
  //! scope, with query variables having priority over POST ones. In other
  //! words, the query part of the URL overrides whatever variables are sent
  //! in the request body.
  //!
  //! The indices and values of this mapping map to the names and values of
  //! the variable names. All data (names and values) are decoded from their
  //! possible transport encoding.
  //!
  //! The value is always an array

  mapping(string:mixed)|FakedVariables variables;
  //! @decl mapping(string:mixed) variables;
  //!
  //! The variables mapping is more or less identical to the
  //! real_variables maping, but each variable can only have one
  //! value, if the form variable was sent multiple times from the
  //! client (this happens, as an example, if you have checkbox
  //! variables with the same name but different values), the values
  //! will be separated with \0 (the null character) in this mapping.
  
  mapping (string:mixed) misc;
  //! This mapping contains miscellaneous non-standardized information, and
  //! is the typical location to store away your own request-local data for
  //! passing between modules et cetera. Be sure to use a key unique to your
  //! own application.

  mapping (string:string) cookies;
  //! The indices and values map to the names and values of the cookies sent
  //! by the client for the requested page. All data (names and values) are
  //! decoded from their possible transport encoding.

  mapping (string:array(string)|string) request_headers;
  //! Indices and values map to the names and values of all HTTP headers sent
  //! with the request; all data has been transport decoded, and the header
  //! names are canonized (lowercased) on top of that. Here is where you look
  //! for the "user-agent" header, the "referer" [sic!] header and similar
  //! interesting data provided by the client.

  mapping (string:mixed) throttle;
  // ?

  mapping (string:mixed) client_var;
  //! The client scope; a mapping of various client-related variables, indices
  //! being the entity names and the values being their values respectively.

  multiset(string) prestate;
  //! A multiset of all prestates harvested from the URL. Prestates are boolean
  //! flags, who are introduced in an extra leading path segment of the URL
  //! path put within parentheses, as in <a
  //! href="http://docs.roxen.com/(tables)/">docs://www.roxen.com/(tables)/</a>,
  //! this rendering a prestate multiset <pi>(&lt; "tables" &gt;)</pi>.
  //!
  //! Prestates are mostly useful for debugging purposes, since prestates
  //! generally lead to multiple URLs for identical documents resulting in
  //! poor usage of browser/proxy caches and the like. See <ref>config</ref>.

  multiset(string) config;
  //! Much like prestates, the id->config multiset is typically used for
  //! boolean information of state supplied by the client. The config state,
  //! however, is hidden in a client-side cookie treated specially by roxen,
  //! namely the <tt>RoxenConfig</tt> cookie.

  multiset(string) supports;
  //! All flags set by the supports system.

  multiset(string) pragma;
  //! All pragmas (lower-cased for canonization) sent with the request. For
  //! real-world applications typically only <pi>pragma["no-cache"]</pi> is of
  //! any particular interest, this being sent when the user does a forced
  //! reload of the page.

  array(string) client;
  array(string) referer;

  Stdio.File my_fd;
  // Don't touch; use the returned file descriptor from connection() instead.

  string prot;
  //! The protocol used for the request, e g "FTP", "HTTP/1.0", "HTTP/1.1".
  //! (Se also <ref>clientprot</ref>.)

  string clientprot;
  //! The protocol the client wanted to use in the request. This may
  //! not be the same as <ref>prot</ref>, if the client wanted to talk
  //! a higher protocol version than the server supports to date.

  string method;
  //! The method used by the client in this request, e g "GET", "POST".

  string realfile;
  //! When the the requested resource is an actual file in the real
  //! filesystem, this is its path.

  string virtfile;
  //! The mountpoint of the location module that provided the requested file.
  //! Note that this is not accessable from location modules; you need to keep
  //! track of your mountpoint on your own using <ref>defvar()</ref> and
  //! <ref>query()</ref>. This mountpoint is relative to the server URL.

  string rest_query;
  //! The scraps and leftovers of the requested URL's query part after
  //! removing all variables (that is, all key=value pairs) from it.

  string raw;
  //! The raw, untouched request in its entirety.

  string query;
  //! The entire raw query part (all characters after the first question mark,
  //! '?') of the requested URL.

  string not_query;
  //! The part of the path segment of the requested URL that is below
  //! the virtual server's mountpoint. For a typical server
  //! registering a URL with no ending path component, not_query will
  //! contain all characters from the leading '/' to, but not
  //! including, the first question mark ('?') of the URL.

  string extra_extension;

  string data;
  //! The raw request body, containing non-decoded post variables et cetera.

  string leftovers;
  string rawauth, realauth; // Used by many modules, so let's keep this.
  string since;

  string remoteaddr;
  //! The client's IP address.

  string host;
  //! The client's hostname, if resolved.

  multiset(string) cache_status = (<>);
  //! Contains the caches that was hit when the request was served.
  //! See the docstring for @tt{$cache-status@} in the @tt{LogFormat@}
  //! global variable for known values, but note that the multiset
  //! actually never contains the value "nocache"; it's only written
  //! when the multiset is empty.

  object root_id;
  //! @decl RequestID root_id;
  //!   The root id object directly associated with the request - remains
  //!   the same for all id objects generated by <insert href> tags and
  //!   similar conditions that invoke @[clone_me()].

  static void create(Stdio.File fd, Protocol port, Configuration conf){}
  void send(string|object what, int|void len){}

#if constant(Parser.XML.Tree.XMLNSParser)
  static Parser.XML.Tree.Node xml_data;	// XML data for the request.

  Parser.XML.Tree.Node get_xml_data()
  {
    if (!sizeof(data)) return 0;
    if (xml_data) return xml_data;
    // FIXME: Probably ought to check that the content-type for
    //        the request is text/xml.
    return xml_data = Parser.XML.Tree.parse_input(data, 0, 0, 0, 1);
  }
#endif /* Parser.XML.Tree.XMLNSParser */

  static string cached_url_base;

  string url_base()
  //! Returns the base part of the URL, i.e. what should be added in
  //! front of a path in the virtual filesystem to get the absolute
  //! URL to the page. The returned string ends with a "/", or is ""
  //! if no server base could be found.
  //!
  //! This function gets the correct host for protocols that handles
  //! IP-less hosts.
  {
    // Note: Code duplication in protocols/http.pike.

    if (!cached_url_base) {
      string tmp;

      // First consult the port object.
      if (port_obj) {
	string host = port_obj->conf_data[conf]->hostname;
	if (host == "*" && conf && sizeof (host = conf->get_url()))
	  if (sscanf (host, "%*s://%[^:/]", host) < 2)
	    host = port_obj->ip;
	cached_url_base = port_obj->prot_name + "://" + host;
	if (port_obj->port != port_obj->default_port)
	  cached_url_base += ":" + port_obj->port;
      }

      // Then try the configuration url.
      else if (conf && sizeof (tmp = conf->get_url()))
	cached_url_base = tmp[..sizeof (tmp) - 2]; // Remove trailing '/'.

      // Lastly use a pathetic fallback. With this the produced urls
      // will still be relative, which has some chance of working.
      else return cached_url_base = "";

      if (string p = misc->site_prefix_path) cached_url_base += p;
      cached_url_base += "/";
    }
    return cached_url_base;
  }

  void add_response_header (string name, string value)
  //! Adds a header @[name] with the value @[value] to be sent in the
  //! http response. An existing header with the same name will not be
  //! overridden, instead another (duplicate) header line will be sent
  //! in the response.
  //!
  //! @note
  //! If used from within an RXML parse session, this function will
  //! ensure that the new header is registered properly in the RXML
  //! p-code cache. That's the primary reason to used it instead of
  //! adding the header directly to @tt{misc->moreheads@} or
  //! @tt{misc->defines[" _extra_heads"]@}.
  {
    mapping hdrs = misc->defines && misc->defines[" _extra_heads"] || misc->moreheads;
    if (!hdrs) hdrs = misc->moreheads = ([]);

    // Essentially Roxen.add_http_header inlined. Can't refer to it
    // from here due to the recursive resolver problems in Pike.
    array|string cur_val = hdrs[name];
    if(cur_val) {
      if(arrayp(cur_val)) {
	if (!has_value(cur_val, value))
	  cur_val += ({ value });
      } else {
	if (cur_val != value)
	  cur_val = ({ cur_val, value });
      }
    }
    else
      cur_val = value;

    if (hdrs == misc->moreheads)
      hdrs[name] = cur_val;
    else if (object/*(RXML.Context)*/ ctx = RXML_CONTEXT)
      ctx->set_var (name, cur_val, "header");
    else
      hdrs[name] = cur_val;
  }

  void set_response_header (string name, string value)
  //! Sets the header @[name] to the value @[value] to be sent in the
  //! http response. If an existing header with the same name exists,
  //! its value(s) will be overridden. This is useful for headers like
  //! "Expire-Time", otherwise @[add_response_header] is typically a
  //! better choice.
  //!
  //! @note
  //! If used from within an RXML parse session, this function will
  //! ensure that the new header is registered properly in the RXML
  //! p-code cache. That's the primary reason to used it instead of
  //! adding the header directly to @tt{misc->moreheads@} or
  //! @tt{misc->defines[" _extra_heads"]@}.
  {
    if (misc->defines && misc->defines[" _extra_heads"]) {
      misc->defines[" _extra_heads"][name] = value;
      if (object/*(RXML.Context)*/ ctx = RXML_CONTEXT)
	ctx->signal_var_change (name, "header");
    }
    else {
      if (!misc->moreheads) misc->moreheads = ([]);
      misc->moreheads[name] = value;
    }
  }


  //  Charset handling
  
  array(string) output_charset = ({});
  string input_charset;

  void set_output_charset( string|function to, int|void mode )
  {
    if (object/*(RXML.Context)*/ ctx = RXML_CONTEXT)
      ctx->add_p_code_callback ("set_output_charset", to, mode);

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

  static string charset_name(function|string what)
  {
    switch (what) {
    case string_to_unicode: return "ISO10646-1";
    case string_to_utf8:    return "UTF-8";
    default:                return upper_case((string) what);
    }
  }

  static function charset_function(function|string what, int allow_entities)
  {
    switch (what) {
    case "ISO-10646-1":
    case "ISO10646-1":
    case string_to_unicode:
      return string_to_unicode;
      
    case "UTF-8":
    case string_to_utf8:
      return string_to_utf8;
      
    default:
      catch {
	//  Use entity fallback if content type allows it
	function fallback_func =
	  allow_entities &&
	  lambda(string char) {
	    return sprintf("&#x%x;", char[0]);
	  };
	
	_charset_decoder_func =
	  _charset_decoder_func || master()->resolv("Roxen._charset_decoder");
	return
	  _charset_decoder_func(Locale.Charset.encoder((string) what, "",
						       fallback_func))
	  ->decode;
      };
    }
    return lambda(string what) { return what; };
  }
  
  static array(string) join_charset(string old,
				    function|string add,
				    function oldcodec,
				    int allow_entities)
  {
    switch (old && upper_case(old)) {
    case 0:
      return ({ charset_name(add), charset_function(add, allow_entities) });
    case "ISO10646-1":
    case "UTF-8":
      return ({ old, oldcodec }); // Everything goes here. :-)
    case "ISO-2022":
      return ({ old, oldcodec }); // Not really true, but how to know this?
    default:
      // Not true, but there is no easy way to add charsets yet...
      return ({ charset_name(add), charset_function(add, allow_entities) });
    }
  }
  
  array(string) output_encode(string what, int|void allow_entities,
			      string|void force_charset)
  {
    //  Performance optimization for unneeded ISO-8859-1 recoding of
    //  strings which already are narrow.
    if (String.width(what) == 8) {
      if (force_charset) {
	if (upper_case(force_charset) == "ISO-8859-1")
	  return ({ "ISO-8859-1", what });
      } else {
	if (sizeof(output_charset) == 1 &&
	    upper_case(output_charset[0]) == "ISO-8859-1")
	  return ({ "ISO-8859-1", what });
      }
    }
    
    if (!force_charset) {
      string charset;
      function encoder;
      
      foreach( output_charset, string|function f )
	[charset,encoder] = join_charset(charset, f, encoder, allow_entities);
      if (!encoder)
	if (String.width(what) > 8) {
	  charset = "UTF-8";
	  encoder = string_to_utf8;
	}
      if (encoder)
	what = encoder(what);
      return ({ charset, what });
    } else
      return ({
	0,
	Locale.Charset.encoder((force_charset / "=")[-1])->feed(what)->drain()
      });
  }


  string scan_for_query( string f )
  {
    if(sscanf(f,"%s?%s", f, query) == 2)
    {
      string v, a, b;

      foreach(query / "&", v)
	if(sscanf(v, "%s=%s", a, b) == 2)
	{
	  a = _Roxen.http_decode_string(replace(a, "+", " "));
	  b = _Roxen.http_decode_string(replace(b, "+", " "));
	  real_variables[ a ] += ({ b });
	} else
	  if(strlen( rest_query ))
	    rest_query += "&" + _Roxen.http_decode_string( v );
	  else
	    rest_query = _Roxen.http_decode_string( v );
      rest_query=replace(rest_query, "+", "\000");
    }
    return f;
  }

  void adjust_for_config_path( string p )
  {
    if( not_query )  not_query = not_query[ strlen(p).. ];
    raw_url = raw_url[ strlen(p).. ];
    misc->site_prefix_path = p;
  }

  void end(string|void s, int|void keepit){}
  void ready_to_receive(){}
  void send_result(mapping|void result){}
  RequestID clone_me()
  {
    object c,t;
    c=object_program(t=this_object())(0, port_obj, conf);

    c->port_obj = port_obj;
    c->conf = conf;
    c->root_id = root_id;
    c->time = time;
    c->raw_url = raw_url;

    c->real_variables = copy_value( real_variables );
    c->variables = FakedVariables( c->real_variables );
    c->misc = copy_value( misc );
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

    c->rest_query = rest_query;
    c->raw = raw;
    c->query = query;
    c->not_query = not_query;
    c->data = data;
    c->extra_extension = extra_extension;

    c->realauth = realauth;
    c->rawauth = rawauth;
    c->since = since;
    return c;
  }

  Stdio.File connection( )
  //! Returns the file descriptor used for the connection to the client.
  {
    return my_fd;
  }

  Configuration configuration()
  //! Returns the <ref>Configuration</ref> object of the virtual server that
  //! is handling the request.
  {
    return conf;
  }
}

#if constant(Parser.XML.Tree.XMLNSParser)

class XMLStatusNode
{
  inherit Parser.XML.Tree.Node;
  static void create(int|string code)
  {
    if (intp(code)) {
      code = sprintf("HTTP/1.1 %d %s", code,
		     errors[code]||"Unknown status");
    }
    ::create(Parser.XML.Tree.XML_ELEMENT,
	     "DAV:status", ([]), "", "DAV:status");
    add_child(Parser.XML.Tree.Node(Parser.XML.Tree.XML_TEXT,
				   "", 0, code));
  }
}

class XMLPropStatNode
{
  inherit Parser.XML.Tree.Node;

  static constant Node = Parser.XML.Tree.Node;

  static mapping(string:string|array(Node)|Node) properties = ([]);
  static multiset(string) descriptions = (<>);

  array(Node) get_children()
  {
    Node prop_node;
    foreach(::get_children(), Node n) {
      if ((n->get_node_type() == Parser.XML.Tree.XML_ELEMENT) &&
	  (n->get_full_name() == "DAV:prop")) {
	prop_node = n;
      }
    }
    prop_node->
      replace_children(map(indices(properties),
			   lambda(string prop_name) {
			     string|array(Node)|Node value =
			       properties[prop_name];
			     if (stringp(value)) {
			       value = Node(Parser.XML.Tree.XML_TEXT,
					    "", 0, value);
			     }
			     Node n = Node(Parser.XML.Tree.XML_ELEMENT,
					   prop_name, ([]), "", prop_name);
			     if (value) {
			       if (arrayp(value)) {
				 n->replace_children(value);
			       } else {
				 n->replace_children(({ value }));
			       }
			     }
			     return n;
			   }));
    if (sizeof(descriptions)) {
      Node n = Node(Parser.XML.Tree.XML_ELEMENT,
		    "DAV:responsedescription", ([]), "",
		    "DAV:responsedescription");
      n->add_child(Node(Parser.XML.Tree.XML_TEXT, "", 0,
			indices(descriptions)*"\n"));
      add_child(n);
    }
    return ::get_children();
  }

  void add_property(string prop_name, string|array(Node)|Node value)
  {
    properties[prop_name] = value;
  }

  void add_description(string description)
  {
    descriptions[description] = 1;
  }

  int http_code;

  static void create(int|void code)
  {
    http_code = code || 200;

    ::create(Parser.XML.Tree.XML_ELEMENT,
	     "DAV:propstat", ([]), "",
	     "DAV:propstat");
    add_child(Node(Parser.XML.Tree.XML_ELEMENT,
		   "DAV:prop", ([]), "",
		   "DAV:prop"));
    add_child(XMLStatusNode(http_code));
  }
}

class MultiStatus
{
  static constant Node = Parser.XML.Tree.Node;
  static mapping(string:array(Node)) status_set = ([]);

  void add_response(string href, Node response_node)
  {
    if (!status_set[href]) {
      status_set[href] = ({ response_node });
    } else {
      status_set[href] += ({ response_node });
    }
  }

  //! Add DAV:propstat information about the property @[prop_name] for
  //! the resource @[href].
  //!
  //! @param prop_value
  //!   Optional property value. It can be one of the following:
  //!   @mixed prop_value
  //!     @type void|int(0..0)
  //!       Operation performed ok, no value.
  //!     @type string|array(Node)|Node
  //!       Property has value @[prop_value].
  //!     @type mapping(string:mixed)
  //!       Operation failed as described by the mapping.
  //!   @endmixed
  void add_property(string href, string prop_name,
		    void|int(0..0)|string|array(Node)|Node|
		    mapping(string:mixed) prop_value)
  {
    array(XMLStatusNode) stat_nodes;
    XMLStatusNode stat_node;
    int code = mappingp(prop_value)?prop_value->error:200;

    werror("Adding property %O code:%O val:%O\n", prop_name, code, prop_value);
    if (!(stat_nodes = status_set[href])) {
      status_set[href] = ({ stat_node = XMLPropStatNode(code) });
    } else {
      foreach(stat_nodes, Node n) {
	if (n->http_code == code) {
	  stat_node = n;
	  break;
	}
      }
      if (!stat_node) {
	status_set[href] += ({ stat_node = XMLPropStatNode(code) });
      }
    }
    if (mappingp(prop_value)) {
      // FIXME: Add a global error description?
      stat_node->add_description(prop_value->data);
      prop_value = 0;
    }
    stat_node->add_property(prop_name, prop_value);
  }

  Node get_xml_node()
  {
    Node root =
      Parser.XML.Tree.parse_input("<?xml version='1.0' encoding='utf-8'?>\n"
				  "<DAV:multistatus xmlns:DAV='DAV:'>\n"
				  "</DAV:multistatus>");
    array(Node) response_xml = allocate(sizeof(status_set));
    int i;

    werror("Generating XML Nodes for status_set:%O\n",
	   status_set);

    foreach(status_set; string href; array(Node) responses) {
      Node href_node = Node(Parser.XML.Tree.XML_ELEMENT,
			    "DAV:href", ([]), "", "DAV:href");
      href_node->add_child(Node(Parser.XML.Tree.XML_TEXT, "", 0, href));
      (response_xml[i++] =
	Node(Parser.XML.Tree.XML_ELEMENT,
	     "DAV:response", ([]), "", "DAV:response"))->
	  replace_children(({href_node})+responses);
    }
    root->get_first_element("DAV:multistatus", 1)->
      replace_children(response_xml);
    return root;
  }

  mapping(string:mixed) http_answer()
  {
    string xml = get_xml_node()->render_xml();
    return ([
      "error": 207,
      "data": xml,
      "len": sizeof(xml),
      "type": "text/xml; charset=\"utf-8\"",
    ]);
  }

  class prefix(static string href_prefix) {
    void add_response(string href, Node response_node) {
      MultiStatus::add_response(href_prefix + href, response_node);
    }
    void add_property(string path, string prop_name,
		      void|int(0..0)|string|Node|mapping(string:mixed)
		      prop_value)
    {
      MultiStatus::add_property(href_prefix + path, prop_name, prop_value);
    }
    this_program prefix(string href_prefix) {
      return MultiStatus::prefix(this_program::href_prefix + href_prefix);
    }
    Node get_xml_node()
    {
      return MultiStatus::get_xml_node();
    }
    mapping(string:mixed) http_answer()
    {
      return MultiStatus::http_answer();
    }
  }
}

class PatchPropertyCommand
{
  string property_name;
  mapping(string:mixed) execute(string path, RoxenModule module, RequestID id);
}

#endif /* Parser.XML.Tree.XMLNSParser */

class RoxenModule
{
  inherit BasicDefvar;
  constant is_module = 1;
  constant module_type = 0;
  constant module_unique = 1;
  LocaleString module_name;
  LocaleString module_doc;

  string module_identifier();
  string module_local_id();

  array(int|string|mapping) register_module();
  string file_name_and_stuff();

  void start(void|int num, void|object conf);

  string query_internal_location();
  string query_location();
  string query_provides();
  array query_seclevels();
  array(int)|object(Stdio.Stat) stat_file(string f, RequestID id);
  array(string) find_dir(string f, RequestID id);
  mapping(string:array(mixed)) find_dir_stat(string f, RequestID id);
  string real_file(string f, RequestID id);
  void save();
  mapping api_functions();
  mapping query_tag_callers();
  mapping query_container_callers();

  string info(object conf);
  string comment();

  // Property handling stuff.
  multiset(string) query_all_properties(string path, RequestID id);
  string|array(Parser.XML.Tree.Node)|mapping(string:mixed)
    query_property(string path, string prop_name, RequestID id);
  mapping(string:mixed) set_property(string path, string prop_name,
				     string|array(Parser.XML.Tree.Node) value,
				     RequestID id);
  mapping(string:mixed) set_dead_property(string path, string prop_name,
					  array(Parser.XML.Tree.Node) value,
					  RequestID id);
  mapping(string:mixed) remove_property(string path, string prop_name,
					RequestID id);
  void find_properties(string path, string mode, MultiStatus result,
		       RequestID id, multiset(string)|void filt);
  void recurse_find_properties(string path, string mode, int depth,
			       MultiStatus result,
			       RequestID id, multiset(string)|void filt);
  void patch_property_start(string path, RequestID id);
  void patch_property_unroll(string path, RequestID id);
  void patch_property_commit(string path, RequestID id);
  void patch_properties(string path, array(PatchPropertyCommand) instructions,
			MultiStatus result, RequestID id);
  void recurse_patch_properties(string path, int depth,
				array(PatchPropertyCommand) instructions,
				MultiStatus result, RequestID id);
}

class _roxen
{
  mapping(string:object) variables;
  string real_version;
  object locale;
  int start_time;
  array(Configuration) configurations;

  mixed  query(string a);
  void   store(string a, mapping b, int c, object d);
  mapping(string:mixed) retrieve(string a, object b);
  void   remove(string a, object b);
  string version();
  void   dump(string a);
  void   nwrite(string a, int|void b, int|void c, void|mixed ... d);
  int    main(int a, array(string) b);
}

class AuthModule
//! @appears AuthModule
//! The interface an authentication module must implement
{
  inherit RoxenModule;
  constant module_type = MODULE_AUTH;
  constant thread_safe=1;

  constant name = "method name";
  
  User authenticate( RequestID id, UserDB db );
  //! Try to authenticate the request with users from the specified user
  //! database. If no @[db] is specified, all datbases in the current
  //! configuration are searched in order, then the configuration user
  //! database.

  mapping authenticate_throw( RequestID id, string realm, UserDB db );
  //! Returns a reply mapping, similar to @[Roxen.http_rxml_reply] with
  //! friends. If no @[db] is specified,  all datbases in the current
  //! configuration are searched in order, then the configuration user
  //! database.
}

static mapping(string:function(void:void)) user_sql_inited = ([]);
static Sql.Sql user_mysql;
static void init_user_sql(string table)
{
  string db = all_constants()->REPLICATE?"replicate":"local";
  if( !user_mysql )
    user_mysql = master()->resolv("DBManager.get")( db );
  if(catch(user_mysql->query( "SELECT module FROM "+
			      table+" WHERE module=''")))
  {
    user_mysql->query( "CREATE TABLE "+table+" "
		       " (module varchar(30) NOT NULL,  "
		       "  name   varchar(30) NOT NULL, "
		       "  user   varchar(30) NOT NULL, "
		       "  value  blob, "
		       "  raw    int not null, "
		       " INDEX foo (module,name,user))" );
    master()->resolv("DBManager.is_module_table")( 0, db, table,
 			       "Contains metadata about users. "
			       "Userdatabases can store information here "
			       "at the request of other modules, or they "
			       "can keep their own state in this table" );
  }
  user_sql_inited[ table ]=
    lambda(){user_mysql = master()->resolv("DBManager.get")( db );};
}

//! @appears Group
class Group( UserDB database )
{
  string name();
  //! The group name

  array(string) members()
  //! All users that are members of this group. The default
  //! implementation loops over all users handled by the user database
  //! and looks for users with the same gid as this group, or who is a
  //! member of it when the groups() method are called.
  {
    array res = ({});
    User uid;
    int id = gid();
    foreach( database->list_users(), string u )
      if( (uid = database->find_user( u )) &&
	  ((uid->gid() == id) || has_value(uid->groups(), name())))
	res += ({ u });
    return res;
  }
  
  int gid();
  //! A numerical GID, or -1 if not applicable


  int set_name( string new_name )  {    return 0;  }
  int set_gid( int new_gid )  {    return 0;  }
  int set_members( array(string) members ) {   return 0;  }
  //! Returns 1 if it was possible to set the variable.
  
}

#ifdef THREADS
static Thread.Mutex mutex = Thread.Mutex();
#endif

//! @appears User
class User( UserDB database )
{
  static string table;

  string name();
  //! The user (short) name

  string real_name();
  //! The real name of the user

  int password_authenticate(string password)
  //! Return 1 if the password is correct, 0 otherwise. The default
  //! implementation uses the crypted_password() method.
  {
    string c = crypted_password();
    return !sizeof(c) || crypt(password, c);
  }

  int uid();
  //! A numerical UID, or -1 if not applicable

  int gid();
  //! A numerical GID, or -1 if not applicable

  string shell();
  //! The shell, or 0 if not applicable
  
  string gecos()
  //! The gecos field, defaults to return the real name
  {
    return real_name();
  }

  string homedir();
  string crypted_password() { return "x"; }
  //! Used by compat_userinfo(). The default implementation returns "x"

  array(string) groups()
  //! Return all groups this user is a member in. The default
  //! implementation returns ({})
  {
    return ({});
  }

  int set_name(string name)               {}
  int set_real_name(string rname)         {}
  int set_uid(int uid)                    {}
  int set_gid(int gid)                    {}
  int set_shell(string shell)             {}
  int set_gecos(string gecos)             {}
  int set_homedir(string hodir)           {}
  int set_crypted_password(string passwd) {}
  int set_password(string passwd)         {}
  //! Returns 1 if it was possible to set the variable.
  
  array compat_userinfo( )
  //! Return a unix passwd compatible array with user information. The
  //! defualt implementation uses the other methods to assemble this
  //! information.
  //!
  //! Basically:
  //!  return ({ name(), crypted_password(),
  //!            uid(), gid(), gecos(), homedir(),
  //!	         shell() });
  {
    return ({name(),crypted_password(),uid(),gid(),gecos(),homedir(),shell()});
  }


#define INIT_SQL() do{ \
    if(!table) table = replace(database->my_configuration()->name," ","_")+"_user_variables"; \
    if(!user_sql_inited[ table ] )init_user_sql( table );else user_sql_inited[ table ](); \
  } while( 0 )


#ifdef THREADS
#define LOCK() mixed ___key = mutex->lock()
#else
#define LOCK()
#endif

  static string module_name( RoxenModule module )
  {
    if( !module )
      // NULL does not work together with indexes, but this is
      // not a valid modulename, so it's not a problem.
      return "'0'";
    else
      return replace("'"+user_mysql->quote(module->sname())+"'","%","%%");
  }
  
  mixed set_var( RoxenModule module, string index, mixed value )
  //! Set a specified variable in the user. If @[value] is a string,
  //! it's stored as is in the database, otherwise it's encoded using
  //! encode_value before it's stored. Returns the value.
  //!
  //! You can use 0 for the @[module] argument.
  //! 
  //! The default implementation stores the value in a mysql table
  //! '*_user_data' in the 'shared' database.
  //!
  //! Use @[get_var] to retrieve the value, and @[delete_var] to
  //! delete it.
  {
    delete_var( module, index );
    mixed oval = value;
    LOCK();
    INIT_SQL();
    int encoded;

    if( stringp( value ) )
      value = string_to_utf8( value );
    else
    {
      value = encode_value( value );
      encoded = 1;
    }

    user_mysql->query(
      "INSERT INTO "+table+" (module,name,user,value,raw) "
      "VALUES ("+module_name( module )+", %s, %s, %s, %d)",
        index, name(), value, encoded
    );
    return oval;
  }

  mixed get_var( RoxenModule module, string index )
  //! Return the value of a variable previously set with @[set_var]
  {
    array rows;
    LOCK();
    INIT_SQL();
    rows = user_mysql->query( "SELECT * FROM "+table+
			      " WHERE module="+module_name( module )
			      +" AND name=%s AND user=%s",
			      index, name() );
    if( !sizeof( rows ) )
      return 0;
    mapping m = rows[0];

    if( (int)m->raw )
      return decode_value( m->value );
    return utf8_to_string( m->value );
  }

  void delete_var( RoxenModule module, string index )
  //! Delete a variable previously created with @[set_var]
  {
    LOCK();
    INIT_SQL();
    user_mysql->query( "DELETE FROM "+table+" WHERE (module="+
		       module_name( module )+
		       " AND name=%s AND user=%s)", index, name() );
  }
#undef INIT_SQL
#undef LOCK
}

class UserDB
//! @appears UserDB
//! The interface a UserDB module must implement.
{
  inherit RoxenModule;
  constant module_type = MODULE_USERDB;
  constant thread_safe=1;

  constant name = "db name";

  User find_user( string s, RequestID|void id );
  //! Find a user

  User find_user_from_uid( int id )
  //! Find a user given a UID. The default implementation loops over
  //! list_users() and checks the uid() of each one.
  {
    User uid;
    foreach( list_users(), string u )
      if( (uid = find_user( u )) && (uid->uid() == id) )
	return uid;
  }    

  Group find_group( string group )
  //! Find a group object given a group name.
  //! The default implementation returns 0.
  {
  }
  
  Group find_group_from_gid( int id )
  //! Find a group given a GID. The default implementation loops over
  //! list_groups() and checks the gid() of each one.
  {
    Group uid;
    foreach( list_groups(), string u )
      if( (uid = find_group( u )) && (uid->gid() == id) )
	return uid;
  }
  
  array(string) list_groups( )
  //! Return a list of all groups handled by this database module.
  //! The default implementation returns the empty array.
  {
    return ({});
  }

  array(string) list_users( );
  //! Return a list of all users handled by this database module.

  User create_user( string s )
  //! Not necessarily implemented, as an example, it's not possible to
  //! create users in the system user database from Roxen WebServer.
  //! The default implementation returns 0.
  {
    return 0;
  }

  Group create_group( string s )
  //! Not necessarily implemented, as an example, it's not possible to
  //! create groups in the system user database from Roxen WebServer.
  //! The default implementation returns 0.
  {
    return 0;
  }
}

