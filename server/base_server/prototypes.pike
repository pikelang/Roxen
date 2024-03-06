// This file is part of Roxen WebServer.
// Copyright � 2001, Roxen IS.

#include <stat.h>
#include <config.h>
#include <module.h>
#include <variables.h>
#include <module_constants.h>
constant cvs_version="$Id$";

#ifdef DAV_DEBUG
#define DAV_WERROR(X...)	werror(X)
#else /* !DAV_DEBUG */
#define DAV_WERROR(X...)
#endif /* DAV_DEBUG */

// To avoid reference cycles. Set to the Roxen module object by
// roxenloader.pike.
object Roxen;

// Externally visible identifiers in this file that shouldn't be added
// as global constants by roxenloader.pike.
constant ignore_identifiers = (<
  "cvs_version", "Roxen", "ignore_identifiers"
>);

static class Variable
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

  protected string _sprintf()
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
  protected string _sprintf( ) { return "ModuleCopies("+sizeof(copies)+")"; }
}

// Simulate an import of useful stuff from Parser.XML.Tree.
static constant SimpleNode = Parser.XML.Tree.SimpleNode;
static constant SimpleRootNode = Parser.XML.Tree.SimpleRootNode;
static constant SimpleHeaderNode = Parser.XML.Tree.SimpleHeaderNode;
static constant SimpleTextNode = Parser.XML.Tree.SimpleTextNode;
static constant SimpleElementNode = Parser.XML.Tree.SimpleElementNode;

//! Container for information about an outstanding DAV lock. No field
//! except @[owner] may change after the object has been created since
//! filesystem modules might store this info persistently.
//!
//! @note
//! @[DAVLock] objects might be shared between filesystems but not
//! between configurations.
class DAVLock
{
  string locktoken;
  //! The lock token given to the client. It may be zero in case there
  //! only is knowledge that a lock exists but the lock instance has
  //! been forgotten. This can happen in a filesystem that has some
  //! way of recording locks but doesn't store the DAV lock tokens.

  string path;
  //! Canonical absolute path to the locked resource. Always ends with
  //! a @expr{"/"@}.

  int(0..1) recursive;
  //! @expr{1@} if the lock applies to all resources under @[path],
  //! @expr{0@} if it applies to @[path] only.

  string|SimpleNode lockscope;
  //! The lock scope (RFC 2518 12.7). As a special case, if it only is
  //! an empty element without attributes then the element name is
  //! stored as a string.
  //!
  //! @note
  //! RFC 2518 specifies the lock scopes @expr{"DAV:exclusive"@} and
  //! @expr{"DAV:shared"@}.

  string|SimpleNode locktype;
  //! The lock type (RFC 2518 12.8). As a special case, if it only is
  //! an empty element without attributes then the element name is
  //! stored as a string.
  //!
  //! @note
  //! RFC 2518 only specifies the lock type @expr{"DAV:write"@}.

  int(0..) expiry_delta;
  //! Idle time before this lock expires.
  //!
  //! As a special case, if the value is @expr{0@} (zero), the lock
  //! has infinite duration.

  array(SimpleNode) owner;
  //! The owner identification (RFC 2518 12.10), or zero if unknown.
  //! More precisely, it's the children of the @expr{"DAV:owner"@}
  //! element.
  //!
  //! @[RoxenModule.lock_file] may set this if it's zero, otherwise
  //! it shouldn't change.

  int(0..) expiry_time;
  //! Absolute time when this lock expires.
  //!
  //! As a special case, if the value is @expr{0@} (zero), the lock
  //! has infinite duration.

  static void create(string locktoken, string path, int(0..1) recursive,
		     string|SimpleNode lockscope, string|SimpleNode locktype,
		     int(0..) expiry_delta, array(SimpleNode) owner)
  {
    DAVLock::locktoken = locktoken;
    DAVLock::path = path;
    DAVLock::recursive = recursive;
    DAVLock::lockscope = lockscope;
    DAVLock::locktype = locktype;
    DAVLock::expiry_delta = expiry_delta;
    DAVLock::owner = owner;
    if (expiry_delta) {
      if (expiry_delta < 0) error("Negative expiry delta!\n");
      expiry_time = time(0) + expiry_delta;
    }
  }

  //! Returns a DAV:activelock @[Parser.XML.Tree.SimpleNode] structure
  //! describing the lock.
  SimpleNode get_xml()
  {
    SimpleElementNode res = SimpleElementNode("DAV:activelock", ([]))->
      add_child(SimpleElementNode("DAV:locktype", ([]))->
		add_child(stringp(locktype)?
			  SimpleElementNode(locktype, ([])):locktype))->
      add_child(SimpleElementNode("DAV:lockscope", ([]))->
		add_child(stringp(lockscope)?
			  SimpleElementNode(lockscope, ([])):lockscope))->
      add_child(SimpleElementNode("DAV:depth", ([]))->
		add_child(recursive?
			  SimpleTextNode("Infinity"):SimpleTextNode("0")));

    if (owner) {
      SimpleElementNode node;
      res->add_child(node = SimpleElementNode("DAV:owner", ([])));
      node->replace_children(owner);
    }

    if (expiry_delta) {
      res->add_child(SimpleElementNode("DAV:timeout", ([]))->
		     add_child(SimpleTextNode(sprintf("Second-%d",
						      expiry_delta))));
    } else {
      res->add_child(SimpleElementNode("DAV:timeout", ([]))->
		     add_child(SimpleTextNode("Infinite")));
    }

    res->add_child(SimpleElementNode("DAV:locktoken", ([]))->
		   add_child(SimpleElementNode("DAV:href", ([]))->
			     add_child(SimpleTextNode(locktoken))));

    return res;
  }

  static string _sprintf (int flag)
  {
    return flag == 'O' &&
      sprintf ("DAVLock(%O on %O, %s, %s%s)", locktoken, path,
	       recursive ? "rec" : "norec",
	       lockscope == "DAV:exclusive" ? "excl" :
	       lockscope == "DAV:shared" ? "shared" :
	       sprintf ("%O", lockscope),
	       locktype == "DAV:write" ? "" : sprintf (", %O", locktype));
  }
}

//! Configuration information for a site.
class Configuration
{
  inherit BasicDefvar;
  constant is_configuration = 1;
  mapping enabled_modules = ([]);
  mapping(string:array(int)) error_log=([]);

#ifdef PROFILE
  mapping(string:array(int)) profile_map = ([]);
#endif

  class Priority
  {
    protected string _sprintf()
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
  multiset(DAVLock) find_locks(string path, int(0..1) recursive,
			       int(0..1) exclude_shared, RequestID id);
  DAVLock|LockFlag check_locks(string path, int(0..1) recursive, RequestID id);
  mapping(string:mixed) unlock_file(string path, DAVLock lock, RequestID|int(0..0) id);
  int expire_locks(RequestID id);
  void refresh_lock(DAVLock lock);
  mapping(string:mixed)|DAVLock lock_file(string path,
					  int(0..1) recursive,
					  string lockscope,
					  string locktype,
					  int(0..) expiry_delta,
					  array(Parser.XML.Tree.Node) owner,
					  RequestID id);
  mapping|int(-1..0) low_get_file(RequestID id, int|void no_magic);
  mapping get_file(RequestID id, int|void no_magic, int|void internal_get);
  array(string) find_dir(string file, RequestID id, void|int(0..1) verbose);
  array(int)|object(Stdio.Stat) stat_file(string file, RequestID id);
  array open_file(string fname, string mode, RequestID id, void|int ig, void|int rc);
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

  static string _sprintf(int c, mapping|void attrs)
  {
    return sprintf("PrefLanguages(%O)", get_languages());
  }
  
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


typedef function(CacheKey,mixed...:void) CacheActivationCB;

class CacheKey
//! @appears CacheKey
//!
//! Used as @expr{id->misc->cachekey@}. Every request that might be
//! cacheable has an instance, and the protocol cache which store the
//! result of the request checks that this object still exists before
//! using the cache entry. Thus other subsystems that provide data to
//! the result can keep track of this object and destruct it whenever
//! they change state in a way that invalidates the previous result.
//!
//! Those data providers should however not store this object
//! directly, but instead call @[add_activation_cb]. That avoids
//! unnecessary garbage (see below).
//!
//! A cache implementation must call @[activate] before storing the
//! cache key. At that point the functions registered with
//! @[add_activation_cb] are called, and the key gets added in the
//! internal structures of the data providers. This avoids registering
//! cache keys for results that never get cached, which would
//! otherwise produce excessive amounts of garbage objects in those
//! internal structures. Note that other code might need to call
//! @[activate] to process the callbacks, so a key being active
//! doesn't necessarily mean it's used in a cache.
//!
//! @note
//! These objects can be destructed asynchronously; all accesses for
//! things inside them have to rely on the interpreter lock, and code
//! can never assume that @expr{id->misc->cachekey@} exists to begin
//! with. The wrapper functions in @[RequestID] handles all this.
{
#if ID_CACHEKEY_DEBUG
  RoxenDebug.ObjectMarker __marker = RoxenDebug.ObjectMarker (this);
#endif

  static array(array(CacheActivationCB|array)) activation_cbs;
  // Functions to call when the cache key is activated, i.e. stored
  // together with some result in a cache. Zero when the key already
  // is active.

  static void create (void|int activate_immediately)
  {
    if (!activate_immediately) activation_cbs = ({});
  }

  void add_activation_cb (CacheActivationCB cb, mixed... args)
  //! Register a callback that will be called if and when this cache
  //! key is used in a cache, i.e. is activated. The callback gets
  //! this object followed by @[args] as arguments and should do
  //! whatever bookkeeping necessary to keep track of the cache key so
  //! that it can be destructed.
  //!
  //! If this cache key already is active then @[cb] is called right
  //! away.
  //!
  //! The registered callbacks will be called in the same order they
  //! are added.
  //!
  //! @note
  //! Cache keys can be destructed at any time, and @[cb] might get
  //! called with an already destructed object.
  //!
  //! @note
  //! Take care to avoid cyclic refs when the activation callback is
  //! registered. This object should e.g. not be among @[args], and
  //! @[cb] should not be a lambda that contain a reference to this
  //! object.
  {
    // Relying on the interpreter lock here.
    if (activation_cbs)
      // Relying on the interpreter lock here too.
      activation_cbs += ({({cb, args})});
    else
      cb (this, @args);
  }

  void activate()
  //! Activate the cache key. This must be called when the key is
  //! stored in a cache.
  {
    // Relying on the interpreter lock here.
    if (array(array(CacheActivationCB|array)) cbs = activation_cbs) {
      // Relying on the interpreter lock here too.
      activation_cbs = 0;
      foreach (cbs, [CacheActivationCB cb, array args])
	cb (this, @args);
    }
  }

  int activated()
  //! Returns nonzero iff the key is activated.
  {
    // Relying on the interpreter lock here.
    return !activation_cbs;
  }

  void call_activation_cbs_only()
  // Call the collected activation callbacks without activating the
  // key. This is a kludge to play safe in situations early in the
  // request path where we don't want to activate the key and where
  // there aren't any outstanding callbacks in the common case with a
  // direct request but might still be in the recursive case. Ignore
  // if you can.
  {
    // Relying on the interpreter lock here.
    if (array(array(CacheActivationCB|array)) cbs = activation_cbs) {
      // Relying on the interpreter lock here too.
      activation_cbs = ({});
      foreach (cbs, [CacheActivationCB cb, array args])
	cb (this, @args);
    }
  }

  protected string _sprintf (int flag)
  {
    return flag == 'O' && ("CacheKey()"
#ifdef ID_CACHEKEY_DEBUG
			   + (__marker ? "[" + __marker->count + "]" : "")
#endif
			  );
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
#ifdef ID_OBJ_DEBUG
  RoxenDebug.ObjectMarker __marker = RoxenDebug.ObjectMarker (this);
#endif

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

  mapping (string:mixed) connection_misc;
  //! This mapping contains miscellaneous non-standardized information, and
  //! is the typical location to store away your own connection-local data
  //! for passing between requests on the same connection et cetera. Be sure
  //! to use a key unique to your own application.

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

  static SimpleNode xml_data;	// XML data for the request.

  SimpleNode get_xml_data()
  {
    if (!sizeof(data)) return 0;
    if (xml_data) return xml_data;
    // FIXME: Probably ought to check that the content-type for
    //        the request is text/xml.
    DAV_WERROR("Parsing XML data: %O\n", data);
    return xml_data =
      Parser.XML.Tree.simple_parse_input(data,
					 0,
					 Parser.XML.Tree.PARSE_ENABLE_NAMESPACES);
  }

  // Parsed if-header for the request.
  static mapping(string:array(array(array(string)))) if_data;

#ifdef IF_HEADER_DEBUG
#define IF_HDR_MSG(X...) werror (X)
#else
#define IF_HDR_MSG(X...)
#endif

  //! Parse an RFC 2518 9.4 "If Header".
  //!
  //! @note
  //!   For speed reasons the parsing is rather forgiving.
  //!
  //! @returns
  //!   Returns @expr{0@} (zero) if there was no if header, or
  //!   if parsing of the if header failed.
  //!   Returns a mapping from resource name to condition on success.
  //!
  //!   A condition is represented as an array of sub-conditions
  //!   (@tt{List@} in RFC 2518), where each sub-condition is an array
  //!   of tokens, and each token is an array of two elements, where
  //!   the first is one of the strings @expr{"not"@}, @expr{"etag"@},
  //!   or @expr{"key"@}, and the second is the value.
  //!
  //!   The resource @expr{0@} (zero) represents the default resource.
  mapping(string:array(array(array(string)))) get_if_data()
  {
    if (if_data) {
      IF_HDR_MSG ("get_if_data(): Returning cached result\n");
      return sizeof(if_data) && if_data;
    }

    if_data  = ([]);	// Negative caching.

    string raw_header;
    if (!(raw_header = request_headers->if)) {
      IF_HDR_MSG ("get_if_data(): No if header\n");
      return 0;
    }

    array(array(string|int|array(array(string)))) decoded_if =
      MIME.decode_words_tokenized_labled(raw_header);

#if 0
    IF_HDR_MSG("get_if_data(): decoded_if: %O\n", decoded_if);
#endif

    if (!sizeof(decoded_if)) {
      IF_HDR_MSG("Got only whitespace.\n");
      return 0;
    }

    mapping(string:array(array(array(string)))) res = ([ 0: ({}) ]);

    string tmp_resource;
    string resource;
    foreach(decoded_if, array(string|int|array(array(string))) symbol) {
      switch (symbol[0]) {
      case "special":
	switch(symbol[1]) {
	case '<': tmp_resource = ""; break;
	case '>': 
	  resource = tmp_resource;
	  tmp_resource = 0;
	  // Normalize.
	  // FIXME: Check that the protocol and server parts refer
	  //        to this server.
	  // FIXME: Support for servers mounted on subpaths.
	  catch { resource = Standards.URI(resource)->path; };
	  if (!sizeof(resource) || (resource[-1] != '/')) resource += "/";
	  if (!res[resource])
	    res[resource] = ({});
	  break;
	default:
	  if (tmp_resource) tmp_resource += sprintf("%c", symbol[1]);
	  break;
	}
	break;
      case "word":
      case "domain-literal":
	// Resource
	if (!tmp_resource) return 0;
	tmp_resource += symbol[1];
	break;
      case "comment":
	// Parenthesis expression.
	if (tmp_resource) {
	  // Inside a resource.
	  tmp_resource += "(" + symbol[1][0][0] + ")";
	  break;
	}
	array(array(string|int|array(array(string)))) sub_expr =
	  MIME.decode_words_tokenized_labled(symbol[1][0][0]);
	int i;
	array(array(string)) expr = ({});
	string tmp_key;
	for (i = 0; i < sizeof(sub_expr); i++) {
	  switch(sub_expr[i][0]) {
	  case "special":
	    switch(sub_expr[i][1]) {
	    case '<': tmp_key = ""; break;
	    case '>':
	      if (!tmp_key) {
		IF_HDR_MSG("No tmp_key.\n");
		return 0;
	      }
	      expr += ({ ({ "key", tmp_key }) });
	      tmp_key = 0;
	      break;
	    default:
	      if (tmp_key) tmp_key += sprintf("%c", sub_expr[i][1]);
	      break;
	    }
	    break;
	  case "domain-literal":
	    if (tmp_key) {
	      tmp_key += sub_expr[i][1];
	      break;
	    }
	    // entity-tag.
	    string etag = sub_expr[i][1];
	    // etag is usually something like "[\"some etag\"]" here.
	    sscanf(etag, "[%s]", etag);	// Remove brackets
	    expr += ({ ({ "etag", etag }) });
	    break;
	  case "word":
	    // State-token or Not.
	    if (tmp_key) {
	      tmp_key += sub_expr[i][1];
	      break;
	    }
	    if (lower_case(sub_expr[i][1]) == "not") {
	      // Not
	      expr += ({ ({ "not", 0 }) });
	      break;
	    }
	    IF_HDR_MSG("Word outside key: %O\n", sub_expr[i][1]);
	    report_debug("Syntax error in if-header: %O\n", raw_header);
	    return 0;
	  }
	}
	if (tmp_key) {
	  IF_HDR_MSG("Active tmp_key: %O\n", tmp_key);
	  report_debug("Syntax error in if-header: %O\n", raw_header);
	  return 0;
	}
	res[resource] += ({ expr });
	break;
      default:
	report_debug("Syntax error in if-header: %O\n", raw_header);
	return 0;
      }
    }
    if (tmp_resource) {
      IF_HDR_MSG("Active tmp_resource: %O\n", tmp_resource);
      report_debug("Syntax error in if-header: %O\n", raw_header);
      return 0;
    }
    IF_HDR_MSG("get_if_data(): Parsed if header: %s:\n"
	       "%O\n", raw_header, res);
    return if_data = res;
  }

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
  //! @tt{misc->defines["�_extra_heads"]@}.
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
  //! @tt{misc->defines["�_extra_heads"]@}.
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

  static MultiStatus multi_status;

  MultiStatus get_multi_status()
  //! Returns a @[MultiStatus] object that will be used to produce a
  //! 207 Multi-Status response (RFC 2518 10.2). It's only consultet
  //! if the result returned from @[RoxenModule.find_file] et al is an
  //! empty mapping.
  //!
  //! @note
  //! It's not necessarily safe to assume that there aren't any
  //! multi-status responses stored here already on entry to
  //! @[find_file] et al. C.f. @[multi_status_size].
  //!
  //! @seealso
  //! @[set_status_for_path]
  {
    if (!multi_status) multi_status = MultiStatus();
    return multi_status;
  }

  int multi_status_size()
  //! Returns the number responses that have been added to the
  //! @[MultiStatus] object returned by @[get_multi_status]. Useful to
  //! see whether a (part of a) recursive operation added any errors
  //! or other results.
  {
    return multi_status && multi_status->num_responses();
  }

  void set_status_for_path (string path, int status_code,
			    string|void message, mixed... args)
  //! Register a status to be included in the response that applies
  //! only for the given path. This is used for recursive operations
  //! that can yield different results for different encountered files
  //! or directories.
  //!
  //! The status is stored in the @[MultiStatus] object returned by
  //! @[get_multi_status].
  //!
  //! @param path
  //!   Absolute path in the configuration to which the status
  //!   applies. Note that filesystem modules need to prepend their
  //!   location to their internal paths.
  //!
  //! @param status_code
  //!   The HTTP status code.
  //!
  //! @param message
  //!   If given, it's a message to include in the response. The
  //!   message may contain line feeds ('\n') and ISO-8859-1
  //!   characters in the ranges 32..126 and 128..255. Line feeds are
  //!   converted to spaces if the response format doesn't allow them.
  //!
  //! @param args
  //!   If there are more arguments after @[message] then @[message]
  //!   is taken as an @[sprintf] style format string which is used to
  //!   format @[args].
  //!
  //! @seealso
  //! @[Roxen.http_status]
  {
    if (sizeof (args)) message = sprintf (message, @args);
    ASSERT_IF_DEBUG (has_prefix (path, "/"));
    get_multi_status()->add_status (url_base() + path[1..],
				    status_code, message);
  }

  void set_status_for_url (string url, int status_code,
			   string|void message, mixed... args)
  //! Register a status to be included in the response that applies
  //! only for the given URL. Similar to @[set_status_for_path], but
  //! takes a complete URL instead of an absolute path within the
  //! configuration.
  {
    if (sizeof (args)) message = sprintf (message, @args);
    get_multi_status()->add_status (url, status_code, message);
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
	  _charset_decoder_func || Roxen->_charset_decoder;
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

  mapping(string:string) make_response_headers (mapping(string:mixed) file)
  //! Make the response headers from a response mapping for this
  //! request. The headers associated with transfer modifications of
  //! the response, e.g. 206 Partial Content and 304 Not Modified, are
  //! not calculated here.
  //!
  //! @note
  //! Is destructive on @[file] and on various data in the request;
  //! should only be called once for a @[RequestID] instance.
  {
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
      if( !file->len && (fstat[1] >= 0) && file->file )
	file->len = fstat[1];
      if ( fstat[ST_MTIME] > misc->last_modified )
	misc->last_modified = fstat[ST_MTIME];
    }	

    if (!file->error)
      file->error = Protocols.HTTP.HTTP_OK;

    if(!file->type) file->type="text/plain";

    mapping(string:string) heads = ([]);

    if( !zero_type(misc->cacheable) &&
	(misc->cacheable != INITIAL_CACHEABLE) ) {
      if (!misc->cacheable) {
	// It expired a year ago.
	heads["Expires"] = Roxen->http_date( predef::time(1)-31557600 );
      } else
	heads["Expires"] = Roxen->http_date( predef::time(1)+misc->cacheable );
      if (misc->cacheable < INITIAL_CACHEABLE) {
	// Data with expiry is assumed to have been generated at the
	// same instant.
	misc->last_modified = predef::time(1);
      }
    }

    if (misc->last_modified)
      heads["Last-Modified"] = Roxen->http_date(misc->last_modified);

    {
      string charset="";
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
      heads["Content-Type"] = file->type + charset;
    }

    heads["Accept-Ranges"] = "bytes";
    heads["Server"] = replace(roxenp()->version(), " ", "�");
    if (file->error == 500) {
      // Internal server error.
      // Make sure the connection is closed to resync.
      heads["Connection"] = "close";
      misc->connection = "close";
    } else if( misc->connection )
      heads["Connection"] = misc->connection;

    if(file->encoding) heads["Content-Encoding"] = file->encoding;

    heads->Date = Roxen->http_date(predef::time(1));
    if(file->expires)
      heads->Expires = Roxen->http_date(file->expires);

    //if( file->len > 0 || (file->error != 200) )
    heads["Content-Length"] = (string)file->len;

    if (misc->etag)
      heads->ETag = misc->etag;

#ifdef RAM_CACHE
    if (!misc->etag && file->len &&
	(file->data || file->file) &&
	file->error == 200 && (<"HEAD", "GET">)[method] &&
	(file->len < conf->datacache->max_file_size)) {
      string data = "";
      if (file->file) {
	data = file->file->read(file->len);
	if (file->data && (sizeof(data) < file->len)) {
	  data += file->data[..file->len - (sizeof(data)+1)];
	}
	m_delete(file, "file");
      } else if (file->data) {
	data = file->data[..file->len - 1];
      }
      file->data = data;
      heads->ETag = misc->etag =
	sprintf("\"%s\"",
		Crypto.string_to_hex(Crypto.md5()->update(data)->digest()));
    }
#endif /* RAM_CACHE */

    if (misc->vary && sizeof(misc->vary)) {
      heads->Vary = ((array)misc->vary)*", ";
    }

    if(mappingp(file->extra_heads))
      heads |= file->extra_heads;

    if(mappingp(misc->moreheads))
      heads |= misc->moreheads;

    return heads;
  }

  void adjust_for_config_path( string p )
  {
    if( not_query )  not_query = not_query[ strlen(p).. ];
    raw_url = raw_url[ strlen(p).. ];
    misc->site_prefix_path = p;
  }

  void end(string|void s, int|void keepit){}
  void ready_to_receive(){}

  void send_result(mapping|void result)
  {
#ifdef DEBUG
    error ("send_result not overridden.\n");
#endif
  }

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

  protected string _sprintf (int flag)
  {
    return flag == 'O' && ("RequestID(" + (raw_url||"") + ")"
#ifdef ID_OBJ_DEBUG
			   + (__marker ? "[" + __marker->count + "]" : "")
#endif
			  );
  }
}

class MultiStatusStatus (int http_code, void|string message)
{
  constant is_status = 1;

  void build_response (SimpleElementNode response_node)
  {
    SimpleElementNode node = SimpleElementNode("DAV:status", ([]));
    response_node->add_child (node);
    // No use wasting space on a good message in the status node since
    // we have it in the responsedescription instead.
    node->add_child(SimpleTextNode(sprintf("HTTP/1.1 %d ", http_code)));

    if (message) {
      node = SimpleElementNode ("DAV:responsedescription", ([]));
      response_node->add_child (node);
      node->add_child (SimpleTextNode (message));
    }
  }

  int `== (mixed other)
  {
    return objectp (other) &&
      object_program (other) == this_program &&
      other->http_code == http_code &&
      other->message == message;
  }

  int __hash()
  {
    return http_code + (message && hash (message));
  }

  protected string _sprintf (int flag)
  {
    return flag == 'O' &&
      sprintf ("MultiStatusStatus(%d,%O)", http_code, message);
  }
}

private SimpleElementNode ok_status_node =
  SimpleElementNode("DAV:status", ([]))->add_child(SimpleTextNode("HTTP/1.1 200 OK"));

class MultiStatusPropStat
{
  constant is_prop_stat = 1;

  mapping(string:string|SimpleNode|array(SimpleNode)|MultiStatusStatus)
    properties = ([]);
  //! The property settings. Indexed on property name (with complete
  //! XML namespace). Values are:
  //!
  //! @mixed
  //!   @type array(SimpleNode)
  //!     The property value as a sequence of XML nodes. These nodes
  //!     are used as children to the property nodes in the DAV
  //!     protocol.
  //!   @type SimpleNode
  //!     Same as an array containing only this node.
  //!   @type string
  //!     Same as a single @[Parser.XML.Tree.SimpleTextNode] with this value.
  //!   @type int(0..0)
  //!     The property exists but has no value.
  //!   @type MultiStatusStatus
  //!     There was an error querying the property and this is the
  //!     status it generated instead of a value.
  //! @endmixed

  void build_response (SimpleElementNode response_node)
  {
    SimpleElementNode ok_prop_node = SimpleElementNode("DAV:prop", ([]));
    mapping(MultiStatusStatus:SimpleNode) prop_nodes = ([]);

    foreach (properties;
	     string prop_name;
	     string|SimpleNode|array(SimpleNode)|MultiStatusStatus value) {
      if (objectp (value) && value->is_status) {
	// Group together failed properties according to status codes.
	SimpleNode prop_node = prop_nodes[value];
	if (!prop_node)
	  prop_nodes[value] = prop_node = SimpleElementNode("DAV:prop", ([]));
	prop_node->add_child(SimpleElementNode(prop_name, ([])));
      }

      else {
	// The property is ok and has a value.

	string ms_type;
	// The DAV client in Windows XP Pro (at least) requires types
	// on the date fields to parse them correctly. The type system
	// is of course some MS goo.
	switch (prop_name) {
	  case "DAV:creationdate":     ms_type = "dateTime.tz"; break;
	  case "DAV:getlastmodified":  ms_type = "dateTime.rfc1123"; break;
	    // MS header - format unknown.
	    //case "DAV:lastaccessed": ms_type = "dateTime.tz"; break;
	}
	SimpleElementNode node =
	  SimpleElementNode(prop_name,
			    ms_type ?
			    ([ "urn:schemas-microsoft-com:datatypesdt":
			       ms_type ]) : ([]));
	ok_prop_node->add_child (node);

	if (arrayp (value))
	  node->replace_children (value);
	else if (stringp (value))
	  node->add_child(SimpleTextNode(value));
	else if (objectp (value))
	  node->add_child (value);
      }
    }

    if (ok_prop_node->count_children()) {
      SimpleElementNode propstat_node =
	SimpleElementNode("DAV:propstat", ([]));
      response_node->add_child (propstat_node);
      propstat_node->add_child (ok_prop_node);
      propstat_node->add_child (ok_status_node);
    }

    foreach (prop_nodes; MultiStatusStatus status; SimpleNode prop_node) {
      SimpleElementNode propstat_node =
	SimpleElementNode("DAV:propstat", ([]));
      response_node->add_child (propstat_node);
      propstat_node->add_child (prop_node);
      status->build_response (propstat_node);
    }
  }

  protected string _sprintf (int flag)
  {
    return flag == 'O' && sprintf ("MultiStatusPropStat(%O)", properties);
  }
}

typedef MultiStatusStatus|MultiStatusPropStat MultiStatusNode;

class MultiStatus
{
  static mapping(string:MultiStatusNode) status_set = ([]);

  static mapping(string:string) args = ([
    "xmlns:DAV": "DAV:",
    // MS namespace for data types; see comment in
    // XMLPropStatNode.add_property. Note: The XML parser in the
    // MS DAV client is broken and requires the break of the last
    // word "datatypesdt" to be exactly at this point.
    "xmlns:MS": "urn:schemas-microsoft-com:datatypes",
  ]);

  int num_responses()
  //! Returns the number of responses that have been added to this
  //! object.
  {
    return sizeof (status_set);
  }

  MultiStatusNode get_response (string href)
  //! Returns the response stored for @[href] if there is any.
  //!
  //! @returns
  //!   @mixed
  //!     @type MultiStatusStatus
  //!       There was some kind of error on @[href] and this is the
  //!       stored status. This type is preferably checked by testing
  //!       for a nonzero @expr{is_status@} member.
  //!     @type MultiStatusPropStat
  //!       A property query was successful on @[href] and the
  //!       returned object contains the results for some or all
  //!       properties. This type is preferably checked by testing for
  //!       a nonzero @expr{is_prop_stat@} member.
  //!   @endmixed
  {
    return status_set[href];
  }

  mapping(string:MultiStatusNode) get_responses_by_prefix (string href_prefix)
  //! Returns the stored responses for all URI:s that got
  //! @[href_prefix] as prefix. See @[get_response] for details about
  //! the response value.
  //!
  //! Prefixes are only matched at @expr{"/"@} boundaries, so
  //! @expr{"http://x.se/foo"@} is considered a prefix of
  //! @expr{"http://x.se/foo/bar"@} but not
  //! @expr{"http://x.se/foobar"@}. As a special case, the empty
  //! string as @[href_prefix] returns all stored responses.
  {
    if (href_prefix == "")
      return status_set + ([]);
    mapping(string:MultiStatusNode) result = ([]);
    if (!has_suffix (href_prefix, "/")) {
      if (MultiStatusNode stat = status_set[href_prefix])
	result[href_prefix] = stat;
      href_prefix += "/";
    }
    foreach (status_set; string href; MultiStatusNode stat)
      if (has_prefix (href, href_prefix))
	result[href] = stat;
    return result;
  }

  //! Add DAV:propstat information about the property @[prop_name] for
  //! the resource @[href].
  //!
  //! @param prop_value
  //!   Optional property value. It can be one of the following:
  //!   @mixed prop_value
  //!     @type void|int(0..0)
  //!       Operation performed ok, no value.
  //!     @type string|SimpleNode|array(SimpleNode)
  //!       Property has value @[prop_value].
  //!     @type MultiStatusStatus
  //!     @type mapping(string:mixed)
  //!       Operation failed as described by the mapping.
  //!   @endmixed
  void add_property(string href, string prop_name,
		    void|int(0..0)|string|array(SimpleNode)|SimpleNode|
		    MultiStatusStatus|mapping(string:mixed) prop_value)
  {
    MultiStatusPropStat prop_stat;
    if (MultiStatusNode stat = status_set[href])
      if (stat->is_prop_stat)
	// This will cause override of an existing MultiStatusStatus.
	// Presumably it came from another file system that is now
	// being hidden. Or is it better to keep the status node and
	// do nothing here instead?
	prop_stat = stat;
    if (!prop_stat)
      prop_stat = status_set[href] = MultiStatusPropStat();
    if (mappingp (prop_value))
      prop_value = MultiStatusStatus (prop_value->error, prop_value->rettext);
    prop_stat->properties[prop_name] = prop_value;
  }

  void add_status (string href, int status_code,
		   void|string message, mixed... args)
  //! Add a status for the specified url. The remaining arguments are
  //! the same as for @[Roxen.http_status].
  {
    if (sizeof (args)) message = sprintf (message, @args);
    if (!status_code) error("Bad status code!\n");
    status_set[href] = MultiStatusStatus (status_code, message);
  }

  void add_namespace (string namespace)
  //! Add a namespace to the generated @tt{<multistatus>@} element.
  //! Useful if several properties share a namespace.
  {
    int ns_count = 0;
    string ns_name;
    while (args[ns_name = "xmlns:NS" + ns_count]) {
      if (args[ns_name] == namespace) return;
      ns_count++;
    }
    args[ns_name] = namespace;
  }

  SimpleNode get_xml_node()
  {
    SimpleElementNode node;
    SimpleRootNode root = SimpleRootNode()->
      add_child(SimpleHeaderNode((["version": "1.0",
				   "encoding": "utf-8"])))->
      add_child(node = SimpleElementNode("DAV:multistatus", args));

    array(SimpleNode) response_xml = allocate(sizeof(status_set));
    int i;

    DAV_WERROR("Generating XML Nodes for status_set:%O\n",
	       status_set);

    // Sort this because some client (which one?) requires collections
    // to come before the entries they contain.
    foreach(sort(indices(status_set)), string href) {
      SimpleElementNode response_node =
	SimpleElementNode("DAV:response", ([]))->
	add_child(SimpleElementNode("DAV:href", ([]))->
		  add_child(SimpleTextNode(href)));
      response_xml[i++] = response_node;
      status_set[href]->build_response (response_node);
    }
    node->replace_children(response_xml);

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

  class Prefixed (static string href_prefix)
  {
    MultiStatus get_multi_status() {return MultiStatus::this;}
    void add_property(string path, string prop_name,
		      void|int(0..0)|string|array(SimpleNode)|SimpleNode|
		      MultiStatusStatus|mapping(string:mixed) prop_value)
    {
      MultiStatus::add_property(href_prefix + path, prop_name, prop_value);
    }
    void add_status (string path, int status_code,
		     void|string message, mixed... args)
    {
      MultiStatus::add_status (href_prefix + path, status_code, message, @args);
    }
    void add_namespace (string namespace)
    {
      MultiStatus::add_namespace (namespace);
    }
    MultiStatus.Prefixed prefix(string href_prefix) {
      return this_program (this_program::href_prefix + href_prefix);
    }
  }

  MultiStatus.Prefixed prefix (string href_prefix)
  //! Returns an object with the same @expr{add_*@} methods as this
  //! one except that @[href_prefix] is implicitly prepended to every
  //! path.
  {
    return Prefixed (href_prefix);
  }
}

// Only for protyping and breaking of circularities.
static class PropertySet
{
  string path;
  RequestID id;
  Stat get_stat();
  mapping(string:string) get_response_headers();
  multiset(string) query_all_properties();
  string|array(SimpleNode)|mapping(string:mixed)
    query_property(string prop_name);
  mapping(string:mixed) start();
  void unroll();
  void commit();
  mapping(string:mixed) set_property(string prop_name,
				     string|array(SimpleNode) value);
  mapping(string:mixed) set_dead_property(string prop_name,
					  array(SimpleNode) value);
  mapping(string:mixed) remove_property(string prop_name);
  mapping(string:mixed) find_properties(string mode,
					MultiStatus.Prefixed result,
					multiset(string)|void filt);
}

//! See @[RoxenModule.check_locks].
enum LockFlag {
  LOCK_NONE		= 0,
  LOCK_SHARED_BELOW	= 2,
  LOCK_SHARED_AT	= 3,
  LOCK_OWN_BELOW	= 4,
  LOCK_EXCL_BELOW	= 6,
  LOCK_EXCL_AT		= 7
};

//! How to handle an existing destination when files or directories
//! are moved or copied in a filesystem.
enum Overwrite {
  NEVER_OVERWRITE = -1,
  //! Fail if the destination exists. Corresponds to an Overwrite
  //! header with the value "F" (RFC 2518 9.6).

  MAYBE_OVERWRITE = 0,
  //! If the source and destination are directories, overwrite the
  //! properties only. If the source and destination are files,
  //! overwrite the file along with the properties. Otherwise fail if
  //! the destination exists.

  DO_OVERWRITE = 1,
  //! If the destination exists then delete it recursively before
  //! writing the new content. Corresponds to an Overwrite header with
  //! the value "T" (RFC 2518 9.6).
};

//! State of the DAV:propertybehavior.
//!
//! @mixed
//!   @type int(0..0)
//!     DAV:omit.
//!     Failure to copy a property does not cause the entire copy
//!     to fail.
//!   @type int(1..1)
//!     DAV:keepalive "*".
//!     All live properties must be kept alive.
//!   @type multiset(string)
//!     Set of properties to keep alive. Properties not in the set
//!     should be copied according to best effort. The properties are
//!     listed with complete namespaces.
//! @endmixed
typedef int(0..1)|multiset(string) PropertyBehavior;

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
  function(RequestID:int|mapping) query_seclevels();
  void set_status_for_path (string path, RequestID id, int status_code,
			    string|void message, mixed... args);
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

  PropertySet|mapping(string:mixed) query_property_set(string path, RequestID id);
  string|array(SimpleNode)|mapping(string:mixed)
    query_property(string path, string prop_name, RequestID id);
  void recurse_find_properties(string path, string mode, int depth,
			       RequestID id, multiset(string)|void filt);
  mapping(string:mixed) patch_properties(string path,
					 array(PatchPropertyCommand) instructions,
					 RequestID id);
  mapping(string:mixed) set_property (string path, string prop_name,
				      string|array(SimpleNode) value,
				      RequestID id);
  mapping(string:mixed) remove_property (string path, string prop_name,
					 RequestID id);

  string resource_id (string path, RequestID id);
  string|int authenticated_user_id (string path, RequestID id);
  multiset(DAVLock) find_locks(string path,
			       int(0..1) recursive,
			       int(0..1) exclude_shared,
			       RequestID id);
  DAVLock|LockFlag check_locks(string path,
			       int(0..1) recursive,
			       RequestID id);
  mapping(string:mixed) lock_file(string path,
				  DAVLock lock,
				  RequestID id);
  mapping(string:mixed) unlock_file (string path,
				     DAVLock lock,
				     RequestID id);
  mapping(string:mixed)|int(0..1) check_if_header(string relative_path,
						  int(0..1) recursive,
						  RequestID id);

  mapping(string:mixed)|int(-1..0)|Stdio.File find_file(string path,
							RequestID id);
  mapping(string:mixed) recurse_delete_files(string path,
					     RequestID id);
  mapping(string:mixed) make_collection(string path, RequestID id);
  mapping(string:mixed) recurse_copy_files(string source, string destination,
					   PropertyBehavior behavior,
					   Overwrite overwrite, RequestID id);
  mapping(string:mixed) recurse_move_files(string source, string destination,
					   PropertyBehavior behavior,
					   Overwrite overwrite, RequestID id);
}

class PatchPropertyCommand
{
  constant command = "";
  string property_name;
  mapping(string:mixed) execute(PropertySet context);
}

class _roxen
{
  mapping(string:object) variables;
  constant real_version = "";
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

  User find_user_from_uid( int uid, RequestID|void id )
  //! Find a user given a UID. The default implementation loops over
  //! list_users() and checks the uid() of each one.
  {
    User user;
    foreach( list_users(), string u )
      if( (user = find_user( u )) && (user->uid() == uid) )
	return user;
  }    

  Group find_group( string group, RequestID|void id )
  //! Find a group object given a group name.
  //! The default implementation returns 0.
  {
  }
  
  Group find_group_from_gid( int gid, RequestID|void id )
  //! Find a group given a GID. The default implementation loops over
  //! list_groups() and checks the gid() of each one.
  {
    Group group;
    foreach( list_groups(), string u )
      if( (group = find_group( u )) && (group->gid() == gid) )
	return group;
  }
  
  array(string) list_groups( RequestID|void id )
  //! Return a list of all groups handled by this database module.
  //! The default implementation returns the empty array.
  {
    return ({});
  }

  array(string) list_users( RequestID|void id );
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

