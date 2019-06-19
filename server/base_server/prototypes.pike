#include <stat.h>
#include <config.h>
constant cvs_version="$Id$";

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
                  LocaleString|void name,
                  int|void type,
                  LocaleString|void doc_str,
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
  string _sprintf( ) { return "ModuleCopies()"; }
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

#define CATCH(P,X) do{mixed e;if(e=catch{X;})report_error("While "+P+"\n"+describe_backtrace(e));}while(0)
    array(RoxenModule) stop()
    {
      foreach(url_modules, RoxenModule m)
        CATCH("stopping url modules",m->stop && m->stop());
      foreach(logger_modules, RoxenModule m)
        CATCH("stopping logging modules",m->stop && m->stop());
      foreach(filter_modules, RoxenModule m)
        CATCH("stopping filter modules",m->stop && m->stop());
      foreach(location_modules, RoxenModule m)
        CATCH("stopping location modules",m->stop && m->stop());
      foreach(last_modules, RoxenModule m)
        CATCH("stopping last modules",m->stop && m->stop());
      foreach(first_modules, RoxenModule m)
        CATCH("stopping first modules",m->stop && m->stop());
      foreach(indices(provider_modules), RoxenModule m)
        CATCH("stopping provider modules",m->stop && m->stop());
      return url_modules + logger_modules + filter_modules + location_modules +
	last_modules + first_modules + indices (provider_modules);
    }
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
  RoxenModule auth_module;
  RoxenModule dir_module;
  function    types_fun;
  function    auth_fun;

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
  void stop();
  string type_from_filename( string file, int|void to, string|void myext );

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
  array(int)|Stat stat_file(string file, RequestID id);
  array open_file(string fname, string mode, RequestID id, void|int ig);
  mapping(string:array(mixed)) find_dir_stat(string file, RequestID id);
  array access(string file, RequestID id);
  string real_file(string file, RequestID id);
  int|string try_get_file(string s, RequestID id,
                          int|void status, int|void nocache,
                          int|void not_internal);
  int(0..1) is_file(string virt_path, RequestID id);
  void start(int num);
  void save_me();
  int save_one( RoxenModule o );
  RoxenModule reload_module( string modname );
  RoxenModule enable_module( string modname, RoxenModule|void me, 
                             ModuleInfo|void moduleinfo, 
                             int|void nostart );
  void call_start_callbacks( RoxenModule me, 
                             ModuleInfo moduleinfo, 
                             ModuleCopies module );
  void call_low_start_callbacks( RoxenModule me, 
                                 ModuleInfo moduleinfo, 
                                 ModuleCopies module );
  int disable_module( string modname, int|void nodest );
  int add_modules( array(string) mods, int|void now );
  RoxenModule find_module(string name);
  Sql.sql sql_cache_get(string what);
  Sql.sql sql_connect(string db);
  void enable_all_modules();
  void low_init(void|int modules_already_enabled);


  string parse_rxml(string what, RequestID id,
                    void|Stdio.File file,
                    void|mapping defines );
  void add_parse_module (RoxenModule mod);
  void remove_parse_module (RoxenModule mod);

  string real_file(string a, RequestID b);

  static string _sprintf( )
  {
    return "Configuration("+name+")";
  }
}

class Protocol 
{
  inherit BasicDefvar;
  constant name = "unknown";
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

  
  void ref(string url, mapping data);
  void unref(string url);
  Configuration find_configuration_for_url( string url, RequestID id, 
                                            int|void no_default );
  string get_key();
  void save();
  void restore();
};


class RequestID
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

  mapping (string:mixed) real_variables;

  mapping (string:string) variables;
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

  mapping (string:mixed) misc;
  //! This mapping contains miscellaneous non-standardized information, and
  //! is the typical location to store away your own request-local data for
  //! passing between modules et cetera. Be sure to use a key unique to your
  //! own application.

  mapping (string:string) cookies;
  //! The indices and values map to the names and values of the cookies sent
  //! by the client for the requested page. All data (names and values) are
  //! decoded from their possible transport encoding.

  mapping (string:string) request_headers;
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
  array (int|string) auth;
  string rawauth;
  string realauth;
  string since;

  string remoteaddr;
  //! The client's IP address.

  string host;
  //! The client's hostname, if resolved.

  static void create(Stdio.File fd, Protocol port, Configuration conf){}
  void send(string|object what, int|void len){}

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

          if(variables[ a ])
            variables[ a ] +=  "\0" + b;
          else
            variables[ a ] = b;
        } else
          if(strlen( rest_query ))
            rest_query += "&" + _Roxen.http_decode_string( v );
          else
            rest_query = _Roxen.http_decode_string( v );
      rest_query=replace(rest_query, "+", "\000");
    }
    return f;
  }

  void end(string|void s, int|void keepit){}
  void ready_to_receive(){}
  void send_result(mapping|void result){}
  RequestID clone_me()
  {
    object c,t;
    c=object_program(t=this_object())(0, port_obj, conf);

    // c->first = first;
    c->port_obj = port_obj;
    c->conf = conf;
    c->time = time;
    c->raw_url = raw_url;
    c->variables = copy_value(variables);
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


class RoxenModule
{
  inherit BasicDefvar;
  constant is_module = 1;
  constant module_type = 0;
  constant module_unique = 1;
  string|mapping(string:string) module_name;
  string|mapping(string:string) module_doc;

  array(int|string|mapping) register_module();
  string file_name_and_stuff();

  void start(void|int num, void|object conf);

  string query_internal_location();
  string query_location();
  string query_provides();
  array query_seclevels();
  array(int)|Stat stat_file(string f, RequestID id);
  array(String) find_dir(string f, RequestID id);
  mapping(string:array(mixed)) find_dir_stat(string f, RequestID id);
  string real_file(string f, RequestID id);
  void save();
  mapping api_functions();
  mapping query_tag_callers();
  mapping query_container_callers();

  string info(object conf);
  string comment();
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
