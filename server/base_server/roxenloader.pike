// Roxen bootstrap program. Copyright © 1996 - 2000, Roxen IS.
#define LocaleString Locale.DeferredLocale|string

//#pragma strict_types

// Sets up the roxen environment. Including custom functions like spawne().

#define CATCH(P,X) do{mixed e;if(e=catch{X;})report_error("While "+P+"\n"+describe_backtrace(e));}while(0)

#include <stat.h>
#include <config.h>
//
// NOTE:
//	This file uses replace_master(). This implies that the
//	master() efun when used in this file will return the old
//	master and not the new one.
//
private static __builtin.__master new_master;

constant s = spider;

#define werror roxen_perror

constant cvs_version="$Id$";

int pid = getpid();
Stdio.File stderr = Stdio.File("stderr");

#ifdef __NT__
mapping uname()
{
  return ([ 
	   "machine":"NT",
	   "release":"unknown",
	   "sysname":"NT",
	   "nodename":gethostname(),
	   "version":"unknown",
	   ]);
}
#endif

mapping(int:string) pwn=([]);
string pw_name(int uid)
{
#if !constant(getpwuid)
  return "uid #"+uid;
#else
  if(pwn[uid]) return pwn[uid];
  return pwn[uid]=([array(string)]getpwuid(uid)||((""+uid)/":"))[0];
#endif
}

#if !constant(getppid)
int getppid()
{
  return -1;
}
#endif

#if efun(syslog)
#define  LOG_CONS   (1<<0)
#define  LOG_NDELAY (1<<1)
#define  LOG_PERROR (1<<2)
#define  LOG_PID    (1<<3)

#define  LOG_AUTH    (1<<0)
#define  LOG_AUTHPRIV (1<<1)
#define  LOG_CRON    (1<<2)
#define  LOG_DAEMON  (1<<3)
#define  LOG_KERN    (1<<4)
#define  LOG_LOCAL  (1<<5)
#define  LOG_LOCAL1  (1<<6)
#define  LOG_LOCAL2  (1<<7)
#define  LOG_LOCAL3  (1<<8)
#define  LOG_LOCAL4  (1<<9)
#define  LOG_LOCAL5  (1<<10)
#define  LOG_LOCAL6  (1<<11)
#define  LOG_LOCAL7  (1<<12)
#define  LOG_LPR     (1<<13)
#define  LOG_MAIL    (1<<14)
#define  LOG_NEWS    (1<<15)
#define  LOG_SYSLOG  (1<<16)
#define  LOG_USER    (1<<17)
#define  LOG_UUCP    (1<<18)

#define  LOG_EMERG   (1<<0)
#define  LOG_ALERT   (1<<1)
#define  LOG_CRIT    (1<<2)
#define  LOG_ERR     (1<<3)
#define  LOG_WARNING (1<<4)
#define  LOG_NOTICE  (1<<5)
#define  LOG_INFO    (1<<6)
#define  LOG_DEBUG   (1<<7)
int use_syslog, loggingfield;
#endif

/*
 * Some efuns used by Roxen
 */

static int last_was_change;
int roxen_started = time();
float roxen_started_flt = time(time());
string short_time()
{
  if( last_was_change>0 )
    switch( last_was_change-- )
    {
     default:
       return "          : ";
     case 5:
       float up = time(roxen_started)-roxen_started_flt;
       if( up > 3600 )
       {
         return sprintf( "%2dd%2dh%2dm : ",
                       (int)up/216000,
                       (((int)up/3600)%24),
                       ((int)up/60)%60);
       }
       return sprintf( "%2dm%4.1fs  : ",((int)up/60)%60, up%60 );
    }
  mapping l = localtime( time( ) );
  string ct =  sprintf("%2d:%02d:%02d  : ", l->hour, l->min, l->sec );
  last_was_change=5;
  return ct;
}

string possibly_encode( string what )
{
  if( catch {
    if( String.width( what ) > 8 )
      return string_to_utf8( what );
  } )
    return string_to_utf8( what );
  return what;
}

static int last_was_nl;
// Used to print error/debug messages
void roxen_perror(string format, mixed ... args)
{
  if(sizeof(args))
    format=sprintf(format,@args);

  // "Delayed newlines": End a message with \b and start the next one
  // with \b to make them continue on the same line. If another
  // message gets in between, it still gets written on a new line.
  int delayed_nl;
  if (format == "\b") format = "";
  else if (sizeof (format)) {
    if (format[0] == '\b') {
      if (last_was_nl == -1) last_was_nl = 0;
      format = format[1..];
    }
    if (format[-1] == '\b') {
      delayed_nl = 1;
      format = format[..sizeof(format)-2];
    }
  }

  if (!last_was_nl && (format != "")) {
    // Continuation line.
    int i = search(format, "\n");

    if (i == -1) {
      stderr->write(possibly_encode(format));
      format = "";
      if (delayed_nl) last_was_nl = -1;
    } else {
      stderr->write(possibly_encode(format[..i]));
      format = format[i+1..];
      last_was_nl = 1;
    }
  }

  if (sizeof(format)) {
#if efun(syslog)
    if(use_syslog && (loggingfield&LOG_DEBUG))
      foreach(format/"\n"-({""}), string message)
	syslog(LOG_DEBUG, replace(message+"\n", "%", "%%"));
#endif

    if (last_was_nl == -1) stderr->write("\n");
    last_was_nl = format[-1] == '\n';

    array(string) a = format/"\n";
    int i;

    a = map( a, possibly_encode );

    for(i=0; i < sizeof(a)-1; i++) {
      stderr->write(short_time() + a[i] + "\n");
    }
    if (!last_was_nl) {
      stderr->write(short_time() + a[-1]);
    }
  }

  if (delayed_nl) last_was_nl = -1;
}

// Make a directory hierachy
int mkdirhier(string from, int|void mode)
{
  int r = 1;
  from = roxen_path( from + "x" ); // "x" keeps roxen_path from stripping trailing '/'.
  array(string) f=(from/"/");
  string b="";


  foreach(f[0..sizeof(f)-2], string a)
  {
    if (query_num_arg() > 1) {
      mkdir(b+a, mode);
#if constant(chmod)
      Stat stat = file_stat (b + a, 1);
      if (stat && stat[0] & ~mode)
	// Race here. Not much we can do about it at this point. :\
	catch (chmod (b+a, stat[0] & mode));
#endif
    }
    else mkdir(b+a);
    b+=a+"/";
  }
  if(!r)
    return (file_stat(from)||({0,0}))[1] == -2;
  return 1;
}

// Help function used by low_spawne()
mapping make_mapping(array(string) f)
{
  mapping foo=([ ]);
  string s, a, b;
  foreach(f, s)
  {
    sscanf(s, "%s=%s", a, b);
    foo[a]=b;
  }
  return foo;
}

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
  mapping(string:mixed) extra_statistics = ([]);
  mapping(string:mixed) misc = ([]);	// Even more statistics.
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

class _roxen {

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


// Roxen itself
_roxen roxen;

// The function used to report notices/debug/errors etc.
function(string, int|void, int|void, void|mixed ...:void) nwrite;


/*
 * Code to get global configuration variable values from Roxen.
 */

mixed query(string arg)
{
  if(!roxen)
    error("No roxen object!\n");
  return roxen->query( arg );
}

// used for debug messages. Sent to the administration interface and STDERR.
void init_logger()
{
#if efun(syslog)
  int res;
  use_syslog = !! (query("LogA") == "syslog");

  switch(query("LogST"))
  {
   case "Daemon":    res = LOG_DAEMON;    break;
   case "Local 0":   res = LOG_LOCAL;     break;
   case "Local 1":   res = LOG_LOCAL1;    break;
   case "Local 2":   res = LOG_LOCAL2;    break;
   case "Local 3":   res = LOG_LOCAL3;    break;
   case "Local 4":   res = LOG_LOCAL4;    break;
   case "Local 5":   res = LOG_LOCAL5;    break;
   case "Local 6":   res = LOG_LOCAL6;    break;
   case "Local 7":   res = LOG_LOCAL7;    break;
   case "User":      res = LOG_USER;      break;
  }

  loggingfield=0;
  switch(query("LogWH"))
  { /* Fallthrouh intentional */
   case "All":
    loggingfield = loggingfield | LOG_INFO | LOG_NOTICE;
   case "Debug":
    loggingfield = loggingfield | LOG_DEBUG;
   case "Warnings":
    loggingfield = loggingfield | LOG_WARNING;
   case "Errors":
    loggingfield = loggingfield | LOG_ERR;
   case "Fatal":
    loggingfield = loggingfield | LOG_EMERG;
  }

  closelog();
  openlog([string]query("LogNA"),
	  ([int]query("LogSP")*LOG_PID)|([int]query("LogCO")*LOG_CONS),
          res);
#endif
}

void report_debug(string message, mixed ... foo)
//! Print a debug message in the server's debug log.
//! Shares argument prototype with <ref>sprintf()</ref>.
{
  if( sizeof( foo ) )
    message = sprintf((string)message, @foo );
  roxen_perror( message );
}


array(object) find_module_and_conf_for_log( array(array) q )
{
  object conf, mod;
  for( int i = sizeof (q); i-- > 0; )
  {
    if(!functionp([function]q[i][2]))
      continue;
    object o = function_object( [function]q[i][2] );
    if(!o) 
      continue;
    if( o->is_module ) {
      if( !mod ) mod = o;
      if (!conf && functionp (mod->my_configuration))
	conf = ([function(void:object)]mod->my_configuration)();
    }
    if( o->is_configuration ) {
      if( !conf ) conf = o;
    }
    if( conf )
      break;
  }
  return ({ mod,conf });
}


#define MC @find_module_and_conf_for_log(backtrace())

void report_warning(LocaleString message, mixed ... foo)
//! Report a warning message, that will show up in the server's debug log and
//! in the event logs, along with the yellow exclamation mark warning sign.
//! Shares argument prototype with <ref>sprintf()</ref>.
{
  if( sizeof( foo ) ) message = sprintf((string)message, @foo );
  nwrite(message,0,2,MC);
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_WARNING))
    foreach(message/"\n", message)
      syslog(LOG_WARNING, replace(message+"\n", "%", "%%"));
#endif
}

void report_notice(LocaleString message, mixed ... foo)
//! Report a status message of some sort for the server's debug log and event
//! logs, along with the blue informational notification sign. Shares argument
//! prototype with <ref>sprintf()</ref>.
{
  if( sizeof( foo ) ) message = sprintf((string)message, @foo );
  nwrite(message,0,1,MC);
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_NOTICE))
    foreach(message/"\n", message)
      syslog(LOG_NOTICE, replace(message+"\n", "%", "%%"));
#endif
}

void report_error(LocaleString message, mixed ... foo)
//! Report an error message, that will show up in the server's debug log and
//! in the event logs, along with the red exclamation mark sign. Shares
//! argument prototype with <ref>sprintf()</ref>.
{
  if( sizeof( foo ) ) message = sprintf((string)message, @foo );
  nwrite(message,0,3,MC);
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_ERR))
    foreach(message/"\n", message)
      syslog(LOG_ERR, replace(message+"\n", "%", "%%"));
#endif
}

// Print a fatal error message
void report_fatal(string message, mixed ... foo)
{
  if( sizeof( foo ) ) message = sprintf((string)message, @foo );
  nwrite(message,0,3,MC);
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_EMERG))
    foreach(message/"\n", message)
      syslog(LOG_EMERG, replace(message+"\n", "%", "%%"));
#endif
}

// Pipe open
string popen(string s, void|mapping env, int|void uid, int|void gid)
{
  Stdio.File f = Stdio.File();
  Stdio.File p = f->pipe(Stdio.PROP_IPC);

  if(!p)
    error("Popen failed. (couldn't create pipe)\n");

  mapping(string:mixed) opts = ([
    "env": (env || getenv()),
    "stdout":p,
  ]);

  if (!getuid()) {
    switch(query_num_arg()) {
    case 4:
      opts->gid = gid;
    case 3:
      opts->uid = uid;
      break;
    }
  }
  opts->noinitgroups = 1;
  object proc;
#if defined(__NT__) || defined(__amigaos__)
  proc = Process.create_process(Process.split_quoted_string(s), opts);
#else /* !__NT||__amigaos__ */
  proc = Process.create_process( ({"/bin/sh", "-c", s}), opts );
#endif /* __NT__ || __amigaos__ */
  p->close();
  destruct(p);

  if (proc)
  {
    string t = f->read(0x7fffffff);
    f->close();
    destruct(f);
    return t;
  }
  f->close();
  destruct(f);
  return 0;
}

// Create a process
object spawne(string s, array(string) args, mapping|array env, object stdin,
	      object stdout, object stderr, void|string wd,
	      void|array (int) uid)
{
  int u, g;
  if(uid) { u = uid[0]; g = uid[1]; }
#if efun(geteuid)
  else { u=geteuid(); g=getegid(); }
#endif
  return Process.create_process(({ s }) + (args || ({})), ([
    "toggle_uid":1,
    "stdin":stdin,
    "stdout":stdout,
    "stderr":stderr,
    "cwd":wd,
    "env":env,
    "uid":u,
    "gid":g,
  ]));
}

// Start a new Pike process with the same configuration as the current one
object spawn_pike(array(string) args, void|string wd, object|void stdin,
		  object|void stdout, object|void stderr)
{
  return Process.create_process(
#ifndef __NT__
    ({getcwd()+"/start",
#else /* __NT__ */
    ({getcwd()+"/bin/roxen.exe","-once","-silent",
#endif /* __NT__ */
      "--cd",wd,
      "--quiet","--program"})+args,
      (["toggle_uid":1,
	"stdin":stdin,
	"stdout":stdout,
	"stderr":stderr]));
}


// Add a few cache control related efuns
static private void initiate_cache()
{
  object cache;
  cache=((program)"base_server/cache")();

  add_constant("http_decode_string", _Roxen.http_decode_string );
  add_constant("Stat", Stat);
  add_constant("cache_set",    cache->cache_set);
  add_constant("cache_lookup", cache->cache_lookup);
  add_constant("cache_remove", cache->cache_remove);
  add_constant("cache_expire", cache->cache_expire);
  add_constant("cache_clear",  cache->cache_expire);
  add_constant("cache_indices",cache->cache_indices);
}

class _error_handler {
  void compile_error(string a,int b,string c);
  void compile_warning(string a,int b,string c);
}

array(_error_handler) compile_error_handlers = ({});
void push_compile_error_handler( _error_handler q )
{
  if( q->do_not_push )
  {
    master()->set_inhibit_compile_errors( q );
    compile_error_handlers = ({0})+compile_error_handlers;
  }
  else
    compile_error_handlers = ({q})+compile_error_handlers;
}

void pop_compile_error_handler()
{
  if( !sizeof( compile_error_handlers ) )
  {
    master()->set_inhibit_compile_errors(0);
    return;
  }
  compile_error_handlers = compile_error_handlers[1..];
}

class LowErrorContainer
{
  string d;
  string errors="", warnings="";
  constant do_not_push = 0;
  string get()
  {
    return errors;
  }
  string get_warnings()
  {
    return warnings;
  }
  void got_error(string file, int line, string err, int|void is_warning)
  {
    if (file[..sizeof(d)-1] == d) {
      file = file[sizeof(d)..];
    }
    if( is_warning)
      warnings+= sprintf("%s:%s\t%s\n", file, line ? (string) line : "-", err);
    else
      errors += sprintf("%s:%s\t%s\n", file, line ? (string) line : "-", err);
  }
  void compile_error(string file, int line, string err)
  {
    got_error(file, line, "Error: " + err);
  }
  void compile_warning(string file, int line, string err)
  {
    got_error(file, line, "Warning: " + err, 1);
  }
  void create()
  {
    d = getcwd();
    if (sizeof(d) && (d[-1] != '/') && (d[-1] != '\\'))
      d += "/";
  }
}

class ErrorContainer
{
  inherit LowErrorContainer;
  constant do_not_push = 1;
  void compile_error(string file, int line, string err)
  {
    if( sizeof(compile_error_handlers) )
      (compile_error_handlers-({0}))->compile_error( file,line, err );
    ::compile_error(file,line,err);
  }
  void compile_warning(string file, int line, string err)
  {
    if( sizeof(compile_error_handlers) )
      (compile_error_handlers-({0}))->compile_warning( file,line, err );
    ::compile_warning(file,line,err);
  }
}

// Don't allow cd() unless we are in a forked child.
class restricted_cd
{
  int locked_pid = getpid();
  int `()(string path)
  {
    if (locked_pid == getpid()) {
      throw(({ "Use of cd() is restricted.\n", backtrace() }));
    }
    return cd(path);
  }
}

// Fallback efuns.
#if !constant(getuid)
int getuid(){ return 17; }
int getgid(){ return 42; }
#endif
#if !efun(gethrtime)
int gethrtime()
{
  return (time()*1000);
}
#endif

// Load Roxen for real
object(_roxen) really_load_roxen()
{
  int start_time = gethrtime();
  report_debug("Loading roxen ... ");
  object(_roxen) res;
  mixed err = catch {
    res =[object(_roxen)]((program)"base_server/roxen.pike")();
  };
  if (err) 
  {
    report_debug("ERROR\n");
    werror (describe_backtrace (err));
    throw(err);
  }
  report_debug("Done [%.1fms]\n",
	       (gethrtime()-start_time)/1000.0);

  res->start_time = start_time;
  res->boot_time = start_time;
  nwrite = res->nwrite;
  return res;
}

// Debug function to trace calls to destruct().
#ifdef TRACE_DESTRUCT
void trace_destruct(mixed x)
{
  report_debug("DESTRUCT(%O)\n%s\n",
               x, describe_backtrace(backtrace())):
  destruct(x);
}
#endif /* TRACE_DESTRUCT */

// Set up efuns and load Roxen.
void load_roxen()
{
//   new_master->resolv("Roxen");
  add_constant("cd", restricted_cd());
#ifdef TRACE_DESTRUCT
  add_constant("destruct", trace_destruct);
#endif /* TRACE_DESTRUCT */
#if !constant(getppid)
  add_constant("getppid", getppid);
#endif
#if !constant(getuid)
  add_constant("getuid", getuid);
  add_constant("getgid", getgid);
#endif
#if !constant(gethostname)
  add_constant("gethostname", lambda() { return "localhost"; });
#endif

#ifndef OLD_PARSE_HTML
  // Temporary kludge to get wide string rxml parsing.
  add_constant("parse_html", parse_html);
  add_constant("parse_html_lines", parse_html_lines);
#endif

  roxen = really_load_roxen();
}


#ifndef OLD_PARSE_HTML

static int|string|array(string) compat_call_tag (
  Parser.HTML p, string str, mixed... extra)
{
  string name = lower_case (p->tag_name());
  if (string|function tag = p->m_tags[name])
    if (stringp (tag)) return ({[string]tag});
    else return ([function(string,mapping,mixed...:string|array(string))]tag) (name, p->tag_args(), @extra);
  else if (string|function container = p->m_containers[name])
    // A container has been added.
    p->add_container (name, compat_call_container);
  return 1;
}

static int|string|array(string) compat_call_container (
  Parser.HTML p, mapping(string:string) args, string content, mixed... extra)
{
  string name = lower_case (p->tag_name());
  if (string|function container = p->m_containers[name])
    if (stringp (container)) return ({container});
    else return container (name, args, content, @extra);
  else
    // The container has disappeared from the mapping.
    p->add_container (name, 0);
  return 1;
}

class ParseHtmlCompat
{
  inherit Parser.HTML;

  mapping(string:string|function) m_tags, m_containers;

  void create (mapping(string:string|function) tags,
	       mapping(string:string|function) containers,
	       mixed... extra)
  {
    m_tags = tags;
    m_containers = containers;
    add_containers (mkmapping (indices (m_containers),
			       ({compat_call_container}) * sizeof (m_containers)));
    _set_tag_callback (compat_call_tag);
    set_extra (@extra);
    case_insensitive_tag (1);
    lazy_entity_end (1);
    match_tag (0);
    ignore_unknown (1);
  }
}

string parse_html (string data, mapping tags, mapping containers,
		   mixed... args)
{
  return ParseHtmlCompat (tags, containers, @args)->finish (data)->read();
}

static int|string|array(string) compat_call_tag_lines (
  Parser.HTML p, string str, mixed... extra)
{
  string name = lower_case (p->tag_name());
  if (string|function tag = p->m_tags[name])
    if (stringp (tag)) return ({tag});
    else return tag (name, p->tag_args(), p->at_line(), @extra);
  else if (string|function container = p->m_containers[name])
    // A container has been added.
    p->add_container (name, compat_call_container_lines);
  return 1;
}

static int|string|array(string) compat_call_container_lines (
  Parser.HTML p, mapping(string:string) args, string content, mixed... extra)
{
  string name = lower_case (p->tag_name());
  if (string|function container = p->m_containers[name])
    if (stringp (container)) return ({container});
    else return container (name, args, content, p->at_line(), @extra);
  else
    // The container has disappeared from the mapping.
    p->add_container (name, 0);
  return 1;
}

class ParseHtmlLinesCompat
{
  inherit Parser.HTML;

  mapping(string:string|function) m_tags, m_containers;

  void create (mapping(string:string|function) tags,
	       mapping(string:string|function) containers,
	       mixed... extra)
  {
    m_tags = tags;
    m_containers = containers;
    add_containers (mkmapping (indices (m_containers),
			       ({compat_call_container_lines}) * sizeof (m_containers)));
    _set_tag_callback (compat_call_tag_lines);
    set_extra (@extra);
    case_insensitive_tag (1);
    lazy_entity_end (1);
    match_tag (0);
    ignore_unknown (1);
  }
}

string parse_html_lines (string data, mapping tags, mapping containers,
			 mixed... args)
{
  return ParseHtmlLinesCompat (tags, containers, @args)->finish (data)->read();
}

#endif

static local mapping fd_marks = ([]);
mixed mark_fd( int fd, string|void with )
{
  if(!with)
    return fd_marks[ fd ];
  fd_marks[fd] = with;
}

// Code to trace fd usage.
#ifdef FD_DEBUG
class mf
{
  inherit Stdio.File;

  mixed open(string what, string mode)
  {
    int res;
    res = ::open(what,mode);
    if(res)
    {
      string file;
      int line;
      sscanf(((describe_backtrace(backtrace())/"\n")[2]-(getcwd()+"/")),
	     "%*s line %d in %s", line, file);
      mark_fd(query_fd(), file+":"+line+" open(\""+ what+"\", "+mode+")");
    }
    return res;
  }

  void destroy()
  {
    catch { mark_fd(query_fd(),"CLOSED"); };
  }

  int close(string|void what)
  {
    destroy();
    if (what) {
      return ::close(what);
    }
    return ::close();
  }
}
#else
constant mf = Stdio.File;
#endif

#include "../etc/include/version.h"
string roxen_version()
{
  return __roxen_version__+"."+__roxen_build__;
}

string roxen_path( string filename )
{
  filename = replace( filename, ({"$VVARDIR","$LOCALDIR"}),
                      ({"$VARDIR/"+roxen_version(),
                        getenv ("LOCALDIR") || "../local"}) );
  if( roxen )
    filename = replace( filename, 
                        "$LOGDIR", 
                        [string]roxen->query("logdirprefix") );
  else
    if( search( filename, "$LOGDIR" ) != -1 )
      roxen_perror("Warning: mkdirhier with $LOGDIR before variable is available\n");
  filename = replace( filename, "$VARDIR", getenv ("VARDIR") || "../var" );
#ifdef __NT__
  while( strlen(filename) && filename[-1] == '/' )
    filename = filename[..strlen(filename)-2];
#endif
  return filename;
}

int rm( string filename )
{
  return predef::rm( roxen_path(filename) );
}

array(string) r_get_dir( string path )
{
  return predef::get_dir( roxen_path( path ) );
}

int mv( string f1, string f2 )
{
  return predef::mv( roxen_path(f1), roxen_path( f2 ) );
}

Stat file_stat( string filename, int|void slinks )
{
  return predef::file_stat( roxen_path(filename), slinks );
}

object|void open(string filename, string mode, int|void perm)
{
#ifdef FD_DEBUG
  mf o;
#else
  Stdio.File o;
#endif
  o=mf();
  filename = roxen_path( filename );
  if(!(o->open(filename, mode, perm||0666))) {
    // EAGAIN, ENOMEM, ENFILE, EMFILE, EAGAIN(FreeBSD)
    if ((< 11, 12, 23, 24, 35 >)[o->errno()]) {
      // Let's see if the garbage-collector can free some fd's
      gc();
      // Retry...
      if(!(o->open(filename, mode, perm||0666))) {
	destruct(o);
	return;
      }
    } else {
      destruct(o);
      return;
    }
  }

  // FIXME: Might want to stat() here to check that we don't open
  // devices...
  return o;
}

object|void lopen(string filename, string mode, int|void perm)
{
  object o;
  if( filename[0] != '/' )
    o = open( "../local/"+filename, mode, perm );
  if( !o )
    o = open( filename, mode, perm );
  return o;
}

// Make a $PATH-style string
string make_path(string ... from)
{
  return map(from, lambda(string a, string b) {
    return (a[0]=='/')?combine_path("/",a):combine_path(b,a);
    //return combine_path(b,a);
  }, getcwd())*":";
}

void write_current_time()
{
  if( !roxen )
  {
    call_out( write_current_time, 10 );
    return;
  }
  int t = time(1);
  mapping lt = localtime(t);
  report_debug("\n** "+sprintf("%02d-%02d-%02d %02d:%02d", lt->year+1900,
			       lt->mon+1, lt->mday, lt->hour, lt->min)+
               "   pid: "+pid+"   ppid: "+getppid()+
#if efun(geteuid)
	       (geteuid()!=getuid()?"   euid: "+pw_name(geteuid()):"")+
#endif
               "   uid: "+pw_name(getuid())+"\n\n");
  call_out( write_current_time, 3600 - t % 3600 );
}

void paranoia_throw(mixed err)
{
  if ((arrayp(err) && ((sizeof([array]err) < 2) || !stringp(([array]err)[0]) ||
		       !arrayp(([array]err)[1]) ||
		       !(arrayp(([array(array)]err)[1][0])||stringp(([array(array)]err)[1][0])))) ||
      (!arrayp(err) && (!objectp(err) || !([object]err)->is_generic_error))) {
    report_debug(sprintf("Warning: throwing non-error: %O\n"
			 "From: %s\n",
			 err, describe_backtrace(backtrace())));
  }
  throw(err);
}

// Roxen bootstrap code.
int main(int argc, array(string) argv)
{
  call_out( do_main_wrapper, 0, argc, argv );
  // Get rid of the _main and main() backtrace elements..
  return -1;
}

// Wrapper to make sure we die if loading fails.
void do_main_wrapper(int argc, array(string) argv)
{
  mixed err = catch {
    do_main(argc, argv);
    return;
  };
  catch {
    if (err) {
      werror(sprintf("Roxen loader failed:\n"
                     "%s\n", describe_backtrace(err)));
    }
  };
  exit(1);
}

LocaleString da_String_type;
void do_main( int argc, array(string) argv )
{
  array(string) hider = argv;
  argv = 0;

#ifdef SECURITY
#if !constant(__builtin.security.Creds)
  report_debug(
#"
------ FATAL ----------------------------------------------------
SECURITY defined (the internal security system in roxen), but
the pike binary has not been compiled --with-security. This makes
it impossible for roxen to have any internal security at all.
-----------------------------------------------------------------
");
  exit(-1);
#endif
#endif

  if( (-1&0xffffffff) < 0 )
  {
    report_debug(
#"
------- WARNING -----------------------------------------------
Roxen 2.0 requires bignum support in pike.
Please recompile pike with gmp / bignum support to run Roxen.

It might still be possible to start roxen, but the 
functionality will be affected, and stange errors might occurr.
---------------------------------------------------------------

");
  }

#ifdef NOT_INSTALLED
    report_debug(
#"
------- WARNING -----------------------------------------------
You are running with an un-installed pike binary.

Please note that this is unsupported, and might stop working at
any time, since some things are done differently in uninstalled
pikes, as an example the module search paths are different, and
some environment variables are ignored.
---------------------------------------------------------------

");
#endif

#if __VERSION__ < 7.1
  report_debug(
#"


******************************************************
Roxen 2.2 requires pike 7.1.
Please install a newer version of Pike.
******************************************************


");
  _exit(0); /* 0 means stop start script looping */
#endif /* __VERSION__ < 7.1 */

  int start_time = gethrtime();
  string path = make_path("base_server", "etc/include", ".");
  last_was_nl = 1;
  report_debug("-"*58+"\n"+version()+", Roxen WebServer "+roxen_version()+"\n");
//   report_debug("Roxen loader version "+(cvs_version/" ")[2]+"\n");
  master()->putenv("PIKE_INCLUDE_PATH", path);
  foreach(path/":", string p) {
    add_include_path(p);
    add_program_path(p);
  }
  add_module_path( "etc/modules" );
  add_module_path( "../local/pike_modules" );

#ifdef INTERNAL_ERROR_DEBUG
  add_constant("throw", paranoia_throw);
#endif /* INTERNAL_ERROR_DEBUG */

  add_constant( "mark_fd", mark_fd );

  add_constant( "LocaleString", typeof(da_String_type) );
  
  mixed err;

  add_constant("open", open);
  add_constant("roxen_path", roxen_path);
  add_constant("roxen_version", roxen_version);
  add_constant("lopen", lopen);
  add_constant("report_notice", report_notice);
  add_constant("report_debug", report_debug);
  add_constant("report_warning", report_warning);
  add_constant("report_error", report_error);
  add_constant("report_fatal", report_fatal);
  add_constant("perror",roxen_perror);
  add_constant("werror",roxen_perror);
  add_constant("roxen_perror",roxen_perror);
  add_constant("roxenp", lambda() { return roxen; });
  add_constant( "ST_MTIME", ST_MTIME );
  add_constant( "ST_CTIME", ST_CTIME );
  add_constant( "ST_SIZE",  ST_SIZE );
  add_constant("mkdirhier", mkdirhier);

#ifdef __NT__
  add_constant( "uname", uname );
  add_constant( "getuid", lambda(){ return 0; } );
  add_constant( "getgid", lambda(){ return 0; } );
  add_constant( "geteuid", lambda(){ return 0; } );
  add_constant( "getegid", lambda(){ return 0; } );
#endif

  if (err = catch {
    replace_master(new_master=[object(__builtin.__master)](((program)"etc/roxen_master.pike")()));
  }) {
    werror("Initialization of Roxen's master failed:\n"
	   "%s\n", describe_backtrace(err));
    exit(1);
  }

//   add_constant("open_db", open_db);
  add_constant("r_rm", rm);
  add_constant("r_mv", mv);
  add_constant("r_get_dir", r_get_dir);
  add_constant("r_file_stat", file_stat);
  add_constant("roxenloader", this_object());
  add_constant("ErrorContainer", ErrorContainer);
#if constant( Gz.inflate )
  add_constant("grbz",lambda(string d){return Gz.inflate()->inflate(d);});
#else
  add_constant("grbz",lambda(string d){return d;});
  report_debug(
#"
------- WARNING -----------------------------------------
The Gz (zlib) module is not available.
The default builtin font will not be available.
To get zlib support, install zlib from
ftp://ftp.freesoftware.com/pub/infozip/zlib/zlib.html
and recompile pike, after removing the file 'config.cache'
----------------------------------------------------------

");
#endif

  add_constant("spawne",spawne);
  add_constant("spawn_pike",spawn_pike);
  add_constant("popen",popen);
  add_constant("roxen_popen",popen);
  add_constant("init_logger", init_logger);
  add_constant("capitalize",
               lambda(string s){return upper_case(s[0..0])+s[1..];});

  // It's currently tricky to test for Image.TTF correctly with a
  // preprocessor directive, so let's add a constant for it.
#if constant (Image.TTF)
  if (sizeof (indices (Image.TTF)))
  {
    add_constant ("has_Image_TTF", 1);
    add_constant( "Image.TTF", Image.TTF );
    // We can load the builtin font.
    add_constant("__rbf", "font_handlers/rbf" );
  }
#else
  report_debug(
#"
------- WARNING ----------------------------------------------
The Image.TTF (freeetype) module is not available.
True Type fonts and the default font  will not be available.
To get TTF support, download a Freetype 1 package from

http://freetype.sourceforge.net/download.html#freetype1

Install it, and then remove config.cache in pike and recompile.
If this was a binary release of Roxen, there should be no need
to recompile the pike binary, since the one included should
already have the FreeType interface module, installing the 
library should be enough.
--------------------------------------------------------------

" );
#endif

  if( search( hider, "--long-error-file-names" ) != -1 )
  {
    hider -= ({ "--long-error-file-names" });
    argc = sizeof(hider);
    new_master->long_file_names = 1;
    new_master->putenv("LONG_PIKE_ERRORS", "yup");
  }

  // These are here to allow dumping of roxen.pike to a .o file.
  report_debug("Loading pike modules ... ");

  function  nm_resolv = new_master->resolv;
  int t = gethrtime();
  
  add_constant( "Regexp", nm_resolv("Regexp") );
//   add_constant( "Stdio.File", nm_resolv("Stdio.File") );
  add_constant( "Stdio.UDP", nm_resolv("Stdio.UDP") );
  add_constant( "Stdio.Port", nm_resolv("Stdio.Port") );
  add_constant( "Stdio.read_bytes", nm_resolv("Stdio.read_bytes") );
  add_constant( "Stdio.read_file", nm_resolv("Stdio.read_file") );
  add_constant( "Stdio.sendfile", nm_resolv("Stdio.sendfile") );
  add_constant( "Stdio.stderr", nm_resolv("Stdio.stderr") );
  add_constant( "Stdio.stderr", nm_resolv("Stdio.stderr") );
  add_constant( "Stdio.stdin", nm_resolv("Stdio.stdin") );
  add_constant( "Stdio.stdin", nm_resolv("Stdio.stdin") );
  add_constant( "Stdio.stdout", nm_resolv("Stdio.stdout") );
  add_constant( "Stdio.stdout", nm_resolv("Stdio.stdout") );
  add_constant( "Stdio.write_file", nm_resolv("Stdio.write_file") );
#if constant(thread_create)
  add_constant( "Thread.Mutex", nm_resolv("Thread.Mutex") );
  add_constant( "Thread.Condition", nm_resolv("Thread.Condition") );
  add_constant( "Thread.Queue", nm_resolv("Thread.Queue") );
#endif

#if constant(SSL) && constant(SSL.sslfile)
  add_constant("SSL.sslfile", nm_resolv("SSL.sslfile") );
  add_constant("SSL.context", nm_resolv("SSL.context") );
  add_constant("Tools.PEM.pem_msg", nm_resolv("Tools.PEM.pem_msg") );
  add_constant("Crypto.randomness.reasonably_random",
               nm_resolv("Crypto.randomness.reasonably_random") );
  add_constant("Standards.PKCS.RSA.parse_private_key",
               nm_resolv("Standards.PKCS.RSA.parse_private_key"));
  add_constant("Crypto.rsa", Crypto.rsa );
  add_constant( "Tools.X509.decode_certificate",
                nm_resolv("Tools.X509.decode_certificate") );
  add_constant( "Standards.PKCS.DSA.parse_private_key",
                nm_resolv("Standards.PKCS.DSA.parse_private_key") );
  add_constant( "SSL.cipher.dh_parameters",
                nm_resolv("SSL.cipher.dh_parameters") );
#endif

#if constant(HTTPLoop.prog)
  add_constant( "HTTPLoop.prog", nm_resolv("HTTPLoop.prog") );
  add_constant( "HTTPLoop.Loop", nm_resolv("HTTPLoop.Loop") );
#endif

  add_constant( "hsv_to_rgb",  nm_resolv("Colors.hsv_to_rgb")  );
  add_constant( "rgb_to_hsv",  nm_resolv("Colors.rgb_to_hsv")  );
  add_constant( "parse_color", nm_resolv("Colors.parse_color") );
  add_constant( "color_name",  nm_resolv("Colors.color_name")  );
  add_constant( "colors",      nm_resolv("Colors")             );
  add_constant( "Process.create_process",
                nm_resolv("Process.create_process") );
  add_constant( "MIME.Message", nm_resolv("MIME.Message") );
  add_constant( "MIME.encode_base64", nm_resolv("MIME.encode_base64") );
  add_constant( "MIME.decode_base64", nm_resolv("MIME.decode_base64") );
  add_constant( "Image.Image", nm_resolv("Image.Image") );
  add_constant( "Image.Font", nm_resolv("Image.Font") );
  add_constant( "Image.Colortable", nm_resolv("Image.Colortable") );
  add_constant( "Image.Layer", nm_resolv("Image.Layer") );
  add_constant( "Image.lay", nm_resolv("Image.lay") );
  add_constant( "Image.Color", nm_resolv("Image.Color") );
#if constant(Image.GIF.encode)
  add_constant( "Image.GIF.encode", nm_resolv("Image.GIF.encode") );
  add_constant( "Image.GIF.encode_trans",
                nm_resolv("Image.GIF.encode_trans") );
#endif
  add_constant( "Image.Color.Color", nm_resolv("Image.Color.Color") );
  add_constant( "Image", nm_resolv("Image") );
  add_constant( "Locale", nm_resolv("Locale") );
  add_constant( "Locale.Charset", nm_resolv("Locale.Charset") );

  add_constant("Protocol",      Protocol );
  add_constant("Configuration", Configuration );
  add_constant("StringFile",    StringFile );
  add_constant("RequestID",     RequestID );
  add_constant("RoxenModule",   RoxenModule );
  add_constant("ModuleInfo",    ModuleInfo );
  add_constant("ModuleCopies",  ModuleCopies );

  report_debug("Done [%.1fms]\n", (gethrtime()-t)/1000.0);

  initiate_cache();
  load_roxen();

  int retval = roxen->main(argc,hider);
  report_debug("-- Total boot time %2.1f seconds ---------------------------\n",
	       (gethrtime()-start_time)/1000000.0);
  write_current_time();
  if( retval > -1 )
    exit( retval );
  return;
}
