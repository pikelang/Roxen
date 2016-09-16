// This file is part of Roxen WebServer.
// Copyright © 2001 - 2009, Roxen IS.

#include <stat.h>
#include <config.h>
#include <module.h>
#include <module_constants.h>
constant cvs_version="$Id$";

#ifdef DAV_DEBUG
#define DAV_WERROR(X...)	werror(X)
#else /* !DAV_DEBUG */
#define DAV_WERROR(X...)
#endif /* DAV_DEBUG */

#ifdef VARY_DEBUG
#define VARY_WERROR(X...)	werror("VARY: " + X)
#else
#define VARY_WERROR(X...)
#endif /* VARY_DEBUG */

// To avoid reference cycles. Set to the Roxen module object by
// roxenloader.pike.
object Roxen;

// Externally visible identifiers in this file that shouldn't be added
// as global constants by roxenloader.pike.
constant ignore_identifiers = (<
  "cvs_version", "Roxen", "ignore_identifiers"
>);

protected class Variable
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

  void set_blocking()
  {
  }
}

class ModuleInfo
{
  string sname;
  string filename;

  int last_checked;
  int type, multiple_copies;
  array(string) locked;
  mapping(Configuration:int) config_locked;
  
  string get_name();
  string get_description();
  RoxenModule instance( object conf, void|int silent );
  void save();
  void update_with( RoxenModule mod, string what ); // NOTE: Throws strings.
  int init_module( string what );
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
  string _sprintf (int flag)
  {
    return flag == 'O' && ("ModuleCopies("+sizeof(copies)+")");
  }
}

// Simulate an import of useful stuff from Parser.XML.Tree.
protected constant SimpleNode = Parser.XML.Tree.SimpleNode;
protected constant SimpleRootNode = Parser.XML.Tree.SimpleRootNode;
protected constant SimpleHeaderNode = Parser.XML.Tree.SimpleHeaderNode;
protected constant SimpleTextNode = Parser.XML.Tree.SimpleTextNode;
protected constant SimpleElementNode = Parser.XML.Tree.SimpleElementNode;

//! @appears DAVLock
//!
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

  protected void create(string locktoken, string path, int(0..1) recursive,
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
      expiry_time = time() + expiry_delta;
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

  //! @ignore
  DECLARE_OBJ_COUNT;
  //! @endignore

  protected string _sprintf (int flag)
  {
    return flag == 'O' &&
      sprintf ("DAVLock(%O on %O, %s, %s%s)" + OBJ_COUNT, locktoken, path,
	       recursive ? "rec" : "norec",
	       lockscope == "DAV:exclusive" ? "excl" :
	       lockscope == "DAV:shared" ? "shared" :
	       sprintf ("%O", lockscope),
	       locktype == "DAV:write" ? "" : sprintf (", %O", locktype));
  }
}

//! @appears Configuration
//! Configuration information for a site.
//! @seealso
//!   @[configuration]
class Configuration
{
  inherit BasicDefvar;
  constant is_configuration = 1;
  mapping(string:int(1..1)) enabled_modules = ([]);
  mapping(string:array(int)) error_log=([]);

  // The Configration logger class - allows overrides of the SocketLogger if needed.
  class ConfigurationLogger {
    inherit Logger.SocketLogger;
  }

  // Logger instance for this configuration.
  object json_logger;

#ifdef PROFILE
  mapping(string:array(int)) profile_map = ([]);
#endif

  class DataCache
  {
    void flush();
    void expire_entry(string url, RequestID id);
    void set(string url, string data, mapping meta, int expire, RequestID id);
    array(string|mapping(string:mixed)) get(string url, RequestID id);
    void init_from_variables( );
  };

  object      throttler;
  RoxenModule types_module;
  RoxenModule dir_module;
  function    types_fun;

  string name;
  int inited;

  // Protocol specific statistics.
  int requests, sent, hsent, received;

  int request_num_runs_001s;
  int request_num_runs_005s;
  int request_num_runs_015s;
  int request_num_runs_05s;
  int request_num_runs_1s;
  int request_num_runs_5s;
  int request_num_runs_15s;
  int request_acc_time;
  int handle_num_runs_001s;
  int handle_num_runs_005s;
  int handle_num_runs_015s;
  int handle_num_runs_05s;
  int handle_num_runs_1s;
  int handle_num_runs_5s;
  int handle_num_runs_15s;
  int handle_acc_time;
  int queue_num_runs_001s;
  int queue_num_runs_005s;
  int queue_num_runs_015s;
  int queue_num_runs_05s;
  int queue_num_runs_1s;
  int queue_num_runs_5s;
  int queue_num_runs_15s;
  int queue_acc_time;

  void add_module_pre_callback (string mod_name, string func,
				function(RoxenModule,mixed...:void) cb);
  void delete_module_pre_callback (string mod_name, string func,
				   function(RoxenModule,mixed...:void) cb);
  void add_module_post_callback (string mod_name, string func,
				function(RoxenModule,mixed...:void) cb);
  void delete_module_post_callback (string mod_name, string func,
				    function(RoxenModule,mixed...:void) cb);
  //! These functions add or delete callbacks which are called before
  //! or after specific functions in @[RoxenModule] instances. In
  //! particular this can be used to add callbacks to call before or
  //! after @[RoxenModule.start] in specific modules.
  //!
  //! A callback is never added multiple times on the same callback
  //! list. Callbacks in destructed objects are automatically pruned
  //! from the callback lists.
  //!
  //! @param mod_name
  //! The base identifier (i.e. without the @expr{"#n"@} part) of the
  //! module that the callback should be registered for. If it is zero
  //! then the callback is called for any module in the configuration.
  //! This is a string to be able to register callbacks for modules
  //! that are not yet loaded.
  //!
  //! @param func
  //! The function in the module to register the callback for. The
  //! only supported functions are currently @expr{"start"@} and
  //! @expr{"stop"@}.
  //!
  //! @param cb
  //! The callback to add or delete from the callback list. If a
  //! callback is deleted then @[mod_name] and @[func] must be the
  //! same as when it was registered.
  //!
  //! The callback get the @[RoxenModule] instance as the first
  //! argument. The remaining arguments are the same as the
  //! corresponding function in @[RoxenModule] gets called with.
  //!
  //! Note that post callbacks won't get called if the real
  //! @[RoxenModule] function failed with an exception.

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
  string get_host();

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
  int start(int num);
  void save_me();
  int save_one( RoxenModule o );
  RoxenModule reload_module( string modname );
  RoxenModule enable_module( string modname, RoxenModule|void me, 
                             ModuleInfo|void moduleinfo, 
                             int|void nostart,
                             int|void nosave );
  void call_start_callbacks( RoxenModule me, 
                             ModuleInfo moduleinfo, 
			     ModuleCopies module,
			     void|int newly_added);
  void call_low_start_callbacks( RoxenModule me, 
                                 ModuleInfo moduleinfo, 
                                 ModuleCopies module );
  int disable_module( string modname, int|void nodest );
  int add_modules( array(string) mods, int|void now );
  RoxenModule find_module(string name);
#if ROXEN_COMPAT < 2.2
  Sql.Sql sql_cache_get(string what);
  Sql.Sql sql_connect(string db, void|string charset);
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

  //! @ignore
  DECLARE_OBJ_COUNT;
  //! @endignore

  protected string _sprintf (int flag)
  {
    return flag == 'O' && ("Configuration("+name+")" + OBJ_COUNT);
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
  // FIXME: _get_iterator()

  protected array _indices()
  {
    return indices( real_variables );
  }

  protected array _values()
  {
    return map( _indices(), `[] );
  }

  protected mixed fix_value( mixed what )
  {
    if( !what ) return what;
    if( !arrayp(what) ) return what; // huh

    if( sizeof( what ) == 1 )
      return what[0];
    return what*"\0";
  }

  protected mixed `[]( string ind ) {
    return fix_value( real_variables[ ind ] );
  }

  protected mixed `->(string ind ) {
    return `[]( ind );
  }

  protected mixed `[]=( string ind, mixed what ) {
    real_variables[ ind ] = ({ what });
    return what;
  }

  protected mixed `->=(string ind, mixed what ) {
    return `[]=( ind,what );
  }

  protected mixed _m_delete( mixed what ) {
//     report_debug(" _m_delete( %O )\n", what );
    return fix_value( m_delete( real_variables, what ) );
  }

  protected int _equal( mixed what ) {
    return `==(what);
  }

  protected int `==( mixed what ) {
    if( mappingp( what ) && (real_variables == what) )
      return 1;
  }

  //! @ignore
  DECLARE_OBJ_COUNT;
  //! @endignore

  protected string _sprintf( int f )
  {
    switch( f )
    {
      case 'O':
	return sprintf( "FakedVariables(%O)" + OBJ_COUNT, real_variables );
      default:
	return sprintf( sprintf("%%%c", f ), real_variables );
    }
  }

  protected this_program `|( mapping what )
  {
    foreach( indices(what), string q )`[]=( q,what[q] );
    return this_object();
  }

  protected this_program `+=( mapping what )
  {
    foreach( indices(what), string q )`[]=( q,what[q] );
    return this_object();
  }

  protected this_program `+( mapping what )
  {
    foreach( indices(what), string q )`[]=( q,what[q] );
    return this_object();
  }

  protected mapping cast(string to)
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
  //  array(string) subtags=({});
  array(string) languages=({});
  array(float) qualities=({});

  //  Default action for delayed vary handling is to depend on the
  //  Accept-Language header since that is init_pref_languages() uses.
  //  If Preferred Language Analyzer is loaded it will update this array
  //  based on what request properties it bases its language decision on.
  //  Only when the request processing completes will we know all language
  //  forks and can then install a vary callback.
  array(array(string|array)) delayed_vary_actions =
    ({ ({ "accept-language", 0 }) });
  multiset(string) known_langs = (< >);
  
  protected string _sprintf(int c, mapping|void attrs)
  {
    return c == 'O' && sprintf("PrefLanguages(%O)", get_languages());
  }

  void register_known_language_forks(multiset(string) langs, void|RequestID id)
  {
    //  Accumulate all known languages for this page. If the entry is
    //  placed in the protocol cache we will be able to construct a vary
    //  callback that can determine a proper cache key.
    known_langs |= langs;

    //  If caller provides the current RequestID we can also propagate
    //  the language set in the parent request.
    if (RequestID parent_id = id && id->misc->orig) {
      PrefLanguages parent_pl = parent_id->misc->pref_languages;
      parent_pl->register_known_language_forks(langs, parent_id);
    }
  }

  multiset(string) get_known_language_forks()
  {
    return known_langs;
  }
  
  void finalize_delayed_vary(RequestID id)
  {
    //  No point in installing protocol cache arbitration when the requested
    //  page isn't multilingual.
    if (sizeof(known_langs) < 2)
      return;
    
    VARY_WERROR("finalize_delayed_vary: actions: %O\n", delayed_vary_actions);
    foreach (delayed_vary_actions, array(string|array(string)) item) {
      function cb;
      switch (item[0]) {
      case "accept-language":
	cb = Roxen->get_lang_vary_cb(known_langs, "accept-language");
	id->register_vary_callback("accept-language", cb);
	break;
	
      case "cookie":
	string lang_cookie = item[1];
	cb = Roxen->get_lang_vary_cb(known_langs, "cookie", lang_cookie);
	id->register_vary_callback("cookie", cb);
	break;
	
      case "host":
	id->register_vary_callback("host");
	break;
	
      case "variable":
      case "prestate":
      case "path":
	//  All three are implicitly managed in the protocol cache since
	//  they are part of the page URL.
	break;
      }

      //  Don't depend on further properties as soon as one of the known
      //  languages have appeared (since that language will be the one
      //  shown in the page).
      if (array(string) property_langs = item[-1]) {
	foreach (property_langs, string lang)
	  if (known_langs[lang])
	    return;
      }
    }
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
    array(string) s=reverse(languages)-({""}) /*, u=({})*/;
    
    if(!decoded) {
      q=({});
      s=Array.map(s, lambda(string x) {
		       float n=1.0;
		       string sub="";
		       sscanf(lower_case(x), "%s;q=%f", x, n);
		       if(n==0.0) return "";
		       sscanf(x, "%s-%s", x, sub);
		       if(x == "" ) return "";
		       q+=({n});
		       //  u+=({sub});
		       return x;
		     });
      s-=({""});
      decoded=1;
    }
    else
      q=reverse(qualities);

    sort(q, s /*, u */);
    languages=reverse(s);
    qualities=reverse(q);
    //  subtags=reverse(u);

    //  Remove duplicate entries caused by varying subtags
    multiset(string) known_langs = (< >);
    for (int i = 0; i < sizeof(languages); i++) {
      string l = languages[i];
      if (known_langs[l]) {
	languages[i] = 0;
	qualities[i] = 0;
      } else {
	known_langs[l] = 1;
      }
    }
    languages -= ({ 0 });
    qualities -= ({ 0 });
    
    sorted=1;
  }
}


typedef function(object,mixed...:void) CacheActivationCB;
typedef function(object,mixed...:void) CacheDestructionCB;

class CacheKey
//! @appears CacheKey
//!
//! Used as @expr{id->misc->cachekey@}. Every request that might be
//! cacheable has an instance, and the protocol cache which stores the
//! result of the request checks that this object still exists before
//! using the cache entry. Thus other subsystems that provide data to
//! the result can keep track of this object and use
//! @[roxen.invalidate] on it whenever they change state in a way that
//! invalidates the previous result.
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
//! @[destruct] is traditionally used on cache keys to invalidate
//! them. That is no longer recommended since it doesn't allow
//! @[TristateCacheKey] to operate correctly. Nowadays
//! @[roxen.invalidate] should always be used, regardless whether it's
//! a tristate cache key or not.
//!
//! @note
//! These objects can be destructed asynchronously; all accesses for
//! things inside them have to rely on the interpreter lock, and code
//! can never assume that @expr{id->misc->cachekey@} exists to begin
//! with.
{
#ifdef ID_CACHEKEY_DEBUG
  RoxenDebug.ObjectMarker __marker = RoxenDebug.ObjectMarker (this);
#else
  //! @ignore
  DECLARE_OBJ_COUNT;
  //! @endignore
#endif

  protected array(array(CacheActivationCB|array)) activation_cbs;
  // Functions to call when the cache key is activated, i.e. stored
  // together with some result in a cache. Zero when the key already
  // is active.

  protected array(array(CacheDestructionCB|array)) destruction_cbs;
  // Functions to call when the cache key is destructed.

  protected void create (void|int activate_immediately)
  {
    if (!activate_immediately) activation_cbs = ({});
    destruction_cbs = ({});
  }

  protected void destroy()
  {
    foreach (destruction_cbs, [CacheDestructionCB cb, int remove_at_activation,
			       array args]) {
      if (cb) cb (this, @args);
    }

#if 0
    if (activation_cbs)
      werror ("%O: activation list size at destroy: %d\n",
	      this, sizeof (activation_cbs));
#endif
  }

  void add_destruction_cb (CacheDestructionCB cb, int remove_at_activation,
			   mixed... args)
  //! Register a callback that will be called when this cache key is
  //! destructed. If @[remove_at_activation] is set, the callback will
  //! be removed when this key is activated. Also, attempts to add
  //! callbacks with the @[remove_at_activation] flag set when the key
  //! is already active will be silently ignored. See also
  //! @[add_activation_cb].
  {
    if (activation_cbs || !remove_at_activation)
      destruction_cbs += ({({ cb, remove_at_activation, args })});
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
  //! @[cb] should also be prepared to get a destruct key that isn't a
  //! @[CacheKey] as first argument - see @[merge_activation_list].
  //!
  //! @note
  //! Take care to avoid cyclic refs when the activation callback is
  //! registered. This object should e.g. not be among @[args], and
  //! @[cb] should not be a lambda that contains references to this
  //! object.
  {
    // vvv Relying on the interpreter lock from here.
    if (this && activation_cbs) {
      activation_cbs += ({({cb, args})});
      // ^^^ Relying on the interpreter lock to here.
    }
    else {
#if 0
      werror ("Key %O already active - calling %O(%{%O, %})\n", this, cb, args);
#endif
      cb (this, @args);
    }
  }

  void add_activation_list (array(array(CacheActivationCB|array)) cbs)
  // For internal use by merge_activation_list.
  {
    // vvv Relying on the interpreter lock from here.
    if (this && activation_cbs) {
      activation_cbs += cbs;
      // ^^^ Relying on the interpreter lock to here.
    }
    else
      foreach (cbs, [CacheActivationCB cb, array args]) {
#if 0
	werror ("Key %O already active - calling %O(%{%O, %})\n",
		this, cb, args);
#endif
	cb (this, @args);
      }
  }

  int merge_activation_list (object merge_target)
  //! Merges the activation list in this key into @[merge_target].
  //!
  //! If @[merge_target] already is active or if it isn't capable of
  //! delayed activation then our activation list is executed for it
  //! right away. If this key already is active then zero is returned
  //! and nothing is done.
  {
    // vvv Relying on the interpreter lock from here.
    if (array(array(CacheActivationCB|array)) cbs = this && activation_cbs) {
      if (objectp (merge_target) && merge_target->add_activation_list) {
	merge_target->add_activation_list (cbs);
	// ^^^ Relying on the interpreter lock up to this call.
      }
      else
	foreach (cbs, [CacheActivationCB cb, array args]) {
#if 0
	  werror ("Merge from %O - activating key %O: Calling %O(%{%O, %})\n",
		  this, merge_target, cb, args);
#endif
	  cb (merge_target, @args);
	}
      return 1;
    }
    return 0;
  }

  int activate()
  //! Activate the cache key. This must be called when the key is
  //! stored in a cache. Return nonzero if any callbacks got called.
  {
    // vvv Relying on the interpreter lock from here.
    if (array(array(CacheActivationCB|array)) cbs = this && activation_cbs) {
      activation_cbs = 0;
      // ^^^ Relying on the interpreter lock to here.

      array _destruction_cbs = destruction_cbs;
      // Remove destruction callbacks set to be removed at activation.
      _destruction_cbs = filter (_destruction_cbs,
				lambda (array(CacheDestructionCB|int|array) arg)
				{
				  return !arg[1];
				});
      if (this) destruction_cbs = _destruction_cbs;

      foreach (cbs, [CacheActivationCB cb, array args]) {
#if 0
	werror ("Activating key %O: Calling %O(%{%O, %})\n", this, cb, args);
#endif
	cb (this, @args);
      }
      return sizeof (cbs);
    }
    return 0;
  }

  int activated()
  //! Returns nonzero iff the key is activated.
  {
    return this &&
      // Relying on the interpreter lock here.
      !activation_cbs;
  }

  int activate_if_necessary()
  // Activate the key only if any activation cbs are installed. This
  // is a kludge to play safe in situations early in the request path
  // where we don't want to activate the key and where there aren't
  // any outstanding callbacks in the common case with a direct
  // request but might still be in the recursive case. Ignore if you
  // can.
  {
    // vvv Relying on the interpreter lock from here.
    if (array(array(CacheActivationCB|array)) cbs = this && activation_cbs) {
      if (sizeof (cbs)) {
	activation_cbs = 0;
	// ^^^ Relying on the interpreter lock to here.
	foreach (cbs, [CacheActivationCB cb, array args]) {
#if 0
	  werror ("Activating key %O: Calling %O(%{%O, %})\n", this, cb, args);
#endif
	  cb (this, @args);
	}
	return 1;
      }
    }
    return 0;
  }

  protected string _sprintf (int flag)
  {
    return flag == 'O' &&
      sprintf ("%s(%s)%s",
	       function_name (object_program (this)) || "CacheKey",
	       activation_cbs ? "inactive" : "active",
#ifdef ID_CACHEKEY_DEBUG
	       __marker ? "[" + __marker->count + "]" : "",
#else
	       OBJ_COUNT
#endif
	      );
  }
}

class TristateCacheKey
//! @appears TristateCacheKey
//!
//! This is a variant of @[CacheKey] that adds a third state called
//! "invalid" or "stale". The semantics of that is that the cache will
//! continue to send the cached result for a stale cache entry until
//! it get destructed, but the cache should trig an update to replace
//! the cache entry as soon as possible. This is useful in cases where
//! response times are more important than correctness.
//!
//! Subsystems that rely on valid data may use @[roxen.invalidp()] to
//! check whether the cache entry is stale or not.
//!
//! As with the basic @[CacheKey], @[roxen.invalidate()] should be
//! used to force a cache key into the stale state.
{
  inherit CacheKey;

  protected int flags;

  int invalidp()
  //! Return nonzero if this cache key has been invalidated.
  //!
  //! Don't call directly - use @[roxen.invalidp] instead. That one
  //! deals properly with destruct races.
  //!
  //! @note
  //!   If this function does not exist, the key is assumed
  //!   to be valid for as long as it hasn't been destructed.
  //!
  //! @seealso
  //!   @[roxen.invalidp()], @[invalidate()]
  {
    // DANGER HIGH HAZARD AREA: Exceptions in this function will go unseen.
    return flags;
  }

  void invalidate()
  //! Mark this cache key as invalid/stale.
  //!
  //! @note
  //!   If this function does not exist, invalidation is done
  //!   by destructing the cache key.
  //!
  //! @seealso
  //!   @[roxen.invalidate()], @[invalidp()]
  {
    // DANGER HIGH HAZARD AREA: Exceptions in this function will go unseen.
    flags = 1;
  }
}

class ProtocolCacheKey
//! @appears ProtocolCacheKey
//!
//! The cache key used by the protocol cache.
{
  inherit TristateCacheKey;
}

//  Kludge for resolver problems
protected function _charset_decoder_func;

// This is a somewhat simplistic regexp that doesn't handle
// quoted-string parameter values correctly. It's only used on content
// types so we know wide strings aren't a problem.
protected Regexp ct_charset_search = Regexp (";[ \t\n\r]*charset=");

// Logger class for requests. Intended to have a parent logger in
// the parent request or its configuration.
class RequestJSONLogger {
  inherit Logger.BaseJSONLogger;
  string request_uuid;

  mapping merge_defaults(mapping msg) {
    // We always want the hrtime from the request as well as the thread id.
    msg = msg + ([
      // We want the current hrtime, not the start of the request...
      "hrtime"    : gethrtime(),
    ]);

    msg->rid = request_uuid;

    return ::merge_defaults(msg);
  }

  //! Default parameter mapping and a parent logger object.
  //!
  //! The @[parent_logger] object is used to pass any log messages
  //! injected into this logger up the chain. By default, this logger
  //! does not log at it's own level if a parent logger is given. Instead,
  //! it will simply add its defaults and pass the complete log entry up
  //! to the parent which is then responsible for handling the actual logging.
  void create(void|string logger_name, void|mapping|function defaults,
              void|object parent_logger, void|string request_uuid) {
    ::create (logger_name, defaults, parent_logger);
    this_program::request_uuid = request_uuid;
  }
}

class RequestID
//! @appears RequestID
//! The request information object contains all request-local information and
//! server as the vessel for most forms of intercommunication between modules,
//! scripts, RXML and so on. It gets passed round to almost all API callbacks
//! worth mentioning. A RequestID object is born when an incoming request is
//! encountered, and its life expectancy is short, as it dies again when the
//! request has passed through all levels of the module type calling sequence.
{
#ifdef ID_OBJ_DEBUG
  RoxenDebug.ObjectMarker __marker = RoxenDebug.ObjectMarker (this);
#else
  //! @ignore
  DECLARE_OBJ_COUNT;
  //! @endignore
#endif

  // Generator for unique request UUIDs on the fly.
  protected string _request_uuid;
  string `request_uuid() {
    return _request_uuid || (_request_uuid = Standards.UUID.make_version4()->str());
  };
  void `request_uuid=(mixed v) {
    _request_uuid = (string)v;
  };

  protected Configuration _conf;
  Configuration `conf() {
    return _conf;
  }

  void `conf=(Configuration c) {
    if (!json_logger->parent_logger && c)
      json_logger->parent_logger = c->json_logger;
    _conf = c;
  }

  RequestJSONLogger json_logger = RequestJSONLogger("server/handler", UNDEFINED,
                                                    UNDEFINED, request_uuid);

  Protocol port_obj;
  //! The port object this request came from.

  int time;
  //! Time of the request, standard unix time (seconds since the epoch; 1970).

  int hrtime;
  //! Time of the start of the request, as returned by @[gethrtime].

  string raw_url;
  //! The nonparsed, nontouched, non-* URL requested by the client.
  //! Hence, this path is unlike @[not_query] and @[virtfile] not
  //! relative to the server URL and must be used in conjunction with
  //! the former to generate absolute paths within the server. Be
  //! aware that this string will contain any URL variables present in
  //! the request as well as the file path, and it is not decoded from
  //! the transport encoding.

  int do_not_disconnect;
  //! Typically 0, meaning the channel to the client will be disconnected upon
  //! finishing the request and the RequestID object destroyed with it.

  mapping (string:array) real_variables;
  //! Form variables submitted by the client browser, as found in the
  //! @expr{form@} scope in RXML.
  //!
  //! Both query (as found in the query part of the URL) and POST
  //! (submitted in the request body from a form response) variables
  //! share this scope. If the same variable occurs in both then the
  //! value(s) from the query part are appended to those from the POST
  //! response.
  //!
  //! The indices are the variable names. The values contain the
  //! variable value(s) for each variable. The variable values are
  //! stored in arrays to make it possible to hold more than one value
  //! for a variable. These arrays are never empty.
  //!
  //! All data (names and values) have been decoded from the transport
  //! encoding (i.e. @expr{%XX@} style escapes and the charset
  //! according to @[input_charset] have been decoded). See
  //! @[decode_query_charset] for details.
  //!
  //! @note
  //! This mapping is often changed internally to produce an updated
  //! set of variables that is passed back to the client.
  //!
  //! @seealso
  //! @[rest_query], @expr{misc->post_variables@}

  mapping(string:mixed)|FakedVariables variables;
  //! @decl mapping(string:mixed) variables;
  //!
  //! The variables mapping is more or less identical to the
  //! real_variables maping, but each variable can only have one
  //! value, if the form variable was sent multiple times from the
  //! client (this happens, as an example, if you have checkbox
  //! variables with the same name but different values), the values
  //! will be separated with \0 (the null character) in this mapping.
  
  mapping misc;			// Note that non-string indices are ok.
  //! This mapping contains miscellaneous non-standardized information, and
  //! is the typical location to store away your own request-local data for
  //! passing between modules et cetera. Be sure to use a key unique to your
  //! own application.
  //!
  //! If a subrequest (a.k.a. "fake" request) is generated within
  //! another request then the subrequest receives a copy (created
  //! with @[copy_value]) of this mapping. I.e. the subrequest sees
  //! any data put here by the parent request, but changes made in the
  //! subrequest won't affect the parent.
  //!
  //! These are some of the defined entries:
  //! @mapping
  //!   @member int "cacheable"
  //!     Time in seconds that the request is cacheable. Use
  //!     @[get_max_cache()], @[lower_max_cache()],
  //!     @[raise_max_cache()], @[set_max_cache()] or one of the cache
  //!     macros to access. This setting both controls the maximum
  //!     cache time in the protocol cache and the timestamp returned
  //!     in the @expr{Expires@} header (an @expr{"expires"@} entry in
  //!     the result mapping will override it, though).
  //!   @member mapping(mixed:int) "local_cacheable"
  //!     If this mapping exists, each value in it will be modified by
  //!     @[set_max_cache], @[lower_max_cache] and @[raise_max_cache]
  //!     in the same way they modify @expr{misc->cacheable@}. It's
  //!     used to track cache time changes during specific parts of
  //!     the request.
  //!   @member array(function) "_cachecallbacks"
  //!     Callbacks to verify that the cache entry is valid.
  //!   @member CacheKey "cachekey"
  //!     @[CacheKey] for the request.
  //!   @member multiset(string) "client_connection"
  //!     Parsed request header "Connection".
  //!   @member string "content-type"
  //!     Alias for @expr{@[request_header]["content-type"]@}, the
  //!     content type of the request. (Note the dash instead of
  //!     underscore in the field name.)
  //!   @member string "content_type_type"
  //!     The content type itself from the @expr{Content-Type@} header
  //!     of the request, i.e. without any parameters. It has been
  //!     lowercased and whitespace stripped, so it's on a canonical
  //!     form like e.g. @expr{"image/jpeg"@}.
  //!   @member string "content_type_params"
  //!     The parameters from the @expr{Content-Type@} header of the
  //!     request, if any. Whitespace preceding the first parameter
  //!     have been removed, but otherwise it remains unchanged.
  //!   @member array "cookies"
  //!     Empty array. Obsolete entry.
  //!   @member string "connection"
  //!     Protocol connection mode. Typically @tt{"keep-alive"@} or
  //!     @tt{"close"@}.
  //!   @member int "defaulted_conf"
  //!     If set, then the url-to-configuration resolution failed to
  //!     find a good configuration based on the interface, port, host
  //!     header, and port path prefix. The value is an integer
  //!     showing the "badness" of the fallback configuration chosen:
  //!     @int
  //!       @value 1
  //!         The host, port and path prefix didn't match among the
  //!         urls registered for the interface the request was
  //!         received on, but a match was found among the urls
  //!         registered on an ANY interface for the same port number.
  //!       @value 2
  //!         One of the configurations on the receiving port (c.f.
  //!         @[port_obj]) had the "Default site" flag set and was
  //!         therefore chosen.
  //!       @value 3
  //!         One of the configurations in the server had the "Default
  //!         site" flag set and was therefore chosen, regardless of
  //!         the ports it has open.
  //!       @value 4
  //!         No configuration with the "Default site" flag set was
  //!         found, so the one with the least specific url on the
  //!         receiving port was chosen.
  //!     @endint
  //!   @member mapping(string:mixed) "defines"
  //!     RXML macros.
  //!   @member int(100..) "error_code"
  //!     Result error code unless specified elsewhere.
  //!   @member string "etag"
  //!     Entity tag for the request. If the request is cacheable in
  //!     the protocol cache one will be generated if not already present.
  //!   @member array(string) "files"
  //!     Multipart/form-data variables that have an associated filename.
  //!   @member string "host"
  //!     The host header, exactly as read from the request. Since it
  //!     isn't normalized, it's useful in e.g. redirects so that the
  //!     client doesn't falsely conclude that the redirect has
  //!     switched server (c.f. @[url_base]).
  //!   @member string "hostname"
  //!     Normalized hostname from the host header. The normalization
  //!     means it's lowercased, and if it's an IPv6 address then it's
  //!     converted to the basic @tt{x:x:x:x:x:x:x:x@} form (using
  //!     @[Protocols.IPv6.normalize_addr_basic]).
  //!   @member int "last_modified"
  //!     Time stamp for when the request was last modified.
  //!   @member int "len"
  //!     Length in bytes of the data section of the request.
  //!   @member int "_log_cheat_addition"
  //!     Value to add to @expr{file->len@} to get the length
  //!     to report in the access log.
  //!   @member mapping(string:string|array(string)) "moreheads"
  //!     If this exists, it contains headers to send in the response.
  //!     It overrides automatically calculated headers and headers
  //!     given in a response mapping (as returned by e.g.
  //!     @[RoxenModule.find_file]). Although http headers are case
  //!     insensitive, the header names in this mapping are not. All
  //!     names should follow the capitalization forms used in RFC
  //!     2616 (c.f. @[Roxen.canonicalize_http_header]). See
  //!     @[add_response_header()] for more details.
  //!   @member int(1..1) "no_proto_cache"
  //!     Flag indicating that the result should not be cached in
  //!     the protocol cache.
  //!   @member RequestID "orig"
  //!     Originating @[RequestID] for recursive requests.
  //!   @member int "port"
  //!     Port number from the canonicalized host header.
  //!
  //!     Note that this may differ from the actual port number
  //!     (available in @[port_obj->port]) if eg the server is
  //!     found behind a load balancing proxy. cf [bug 7385].
  //!   @member array(array(string|int)) forwarded
  //!     Parsed @expr{"Forwarded"@} header (@rfc{7239@}).
  //!     If the client sent no forwarded headers, any @expr{"x-forwarded-*"@}
  //!     headers that it sent are used instead.
  //!
  //!     Each entry is on the format returned by @[MIME.tokenize()], and
  //!     corresponds to one @b{Forwarded@} field.
  //!   @member PrefLanguages "pref_languages"
  //!     Language preferences for the request.
  //!   @member mapping(string:array(string)) "post_variables"
  //!     For POST requests, these are the variables parsed from the
  //!     request body. It is undefined otherwise.
  //!   @member mapping(string:array(MIME.Message)) "post_parts"
  //!     For multipart/form-data POST requests, this holds the MIME
  //!     message object for each part. It is undefined otherwise.
  //!   @member array "proxyauth"
  //!     Decoded proxy authentication information.
  //!   @member string "range"
  //!     Byte range information.
  //!   @member string "site_prefix_path"
  //!     Site path prefix.
  //!   @member Stat "stat"
  //!     File status information for the request.
  //!   @member multiset(string) "vary"
  //!     Contains the active set of vary headers. Please use
  //!     @[register_vary_callback()] to alter. All header names here
  //!     should be lowercase to avoid problems with duplicates.
  //!   @member array(string|function(string, RequestID:string)) @
  //!           "vary_cb_order"
  //!     Contains the cache lookup callback functions relevant to the
  //!     request so far in order. See @[register_vary_callback()] for
  //!     details.
  //!   @member mapping(string:multiset(function(string, RequestID:string))| @
  //!                          int(1..1)) "vary_cb_set"
  //!     Same content as @tt{"vary_cb_order"@} above, but only used to
  //!     speed up some lookups. For internal use only.
  //! @endmapping

  mapping connection_misc = ([]); // Note that non-string indices are ok.
  //! This mapping contains miscellaneous non-standardized information, and
  //! is the typical location to store away your own connection-local data
  //! for passing between requests on the same connection et cetera. Be sure
  //! to use a key unique to your own application.

  //! Contains the current set of cookies.
  //!
  //! @note
  //!   DON'T touch!
  //!
  //! @seealso
  //!   @[cookies]
  mapping(string:string) real_cookies;

  //! Wrapper that calls @[register_vary_callback()] as appropriate when
  //! cookies are accessed.
  //!
  //! @note
  //!   Uses the parent pointer to access @[register_vary_callback()] and
  //!   will thus update the original @[RequestID] object even if copied
  //!   to a cloned @[RequestID]. This is a feature.
  //!
  //! @seealso
  //!   @[cookies], @[register_vary_callback()], @[Roxen.get_cookie_callback()]
  class CookieJar
  {
    //! Contains the set of cookies that have been zapped in some way.
    protected mapping(string:string) eaten = ([]);


    // cf RFC 6265.
    protected void create(string|array(string)|mapping(string:string)|void
			  contents)
    {
      VARY_WERROR("Initiating cookie jar.\n");
      real_cookies = ([]);

      if(!contents)
	return;

      if (mappingp(contents)) {
	real_cookies = contents;
	return;
      }

      array tmp = arrayp(contents) ? contents : ({ contents});
  
      foreach(tmp, string cookieheader) {
	foreach(cookieheader/";", string c)
	{
	  array(string) pair = c/"=";
	  if (sizeof(pair) < 2) continue;
	  string name = String.trim_whites(pair[0]);
	  string value = String.trim_whites(pair[1..]*"=");
	  if (has_prefix(value, "\"") && has_suffix(value, "\""))
	    value = value[1..sizeof(value)-2];
	  catch {
	    value=_Roxen.http_decode_string(value);
	  };
	  catch {
	    name=_Roxen.http_decode_string(name);
	  };
	  real_cookies[ name ]=value;
	  
#ifdef OLD_RXML_CONFIG
	  // FIXME: Really ought to register this one...
	  if( (name == "RoxenConfig") && strlen(value) )
	    config =  mkmultiset( value/"," );
#endif
	}
      }
    }
    protected string `->(string cookie)
    {
      if (supports && zero_type(eaten[cookie])) {
	VARY_WERROR("Looking at cookie %O from %s\n",
		   cookie, describe_backtrace(({backtrace()[-2]})));
	register_vary_callback("cookie", Roxen->get_cookie_callback(cookie));
      }
      return real_cookies[cookie];
    }
    protected string `[](mixed cookie)
    {
      if (stringp(cookie)) {
	return `->(cookie);
      }
      return UNDEFINED;
    }
    protected string `->=(string cookie, string value)
    {
      if (zero_type(eaten[cookie])) {
	eaten[cookie] = real_cookies[cookie];
      }
      return real_cookies[cookie] = value;
    }
    protected string `[]=(mixed cookie, string value)
    {
      // FIXME: Warn if not string?
      return `->=(cookie, value);
    }
    protected string _m_delete(string cookie)
    {
      // FIXME: Warn if not string?
      if (zero_type(eaten[cookie])) {
	eaten[cookie] = real_cookies[cookie];
      }
      return m_delete(real_cookies, cookie);
    }
    protected array(string) _indices()
    {
      register_vary_callback("cookie");
      return indices(real_cookies);
    }
    protected array(string) _values()
    {
      register_vary_callback("cookie");
      return values(real_cookies);
    }
    protected int _sizeof()
    {
      register_vary_callback("cookie");
      return sizeof(real_cookies);
    }
    protected mapping(string:string) `+(mapping(string:string) other)
    {
      register_vary_callback("cookie");
      return real_cookies + other;
    }
    protected mapping(string:string) ``+(mapping(string:string) other)
    {
      register_vary_callback("cookie");
      return other + real_cookies;
    }

    //! Used to retrieve the original set of cookies at
    //! protocol cache store time.
    protected mapping(string:string) `~()
    {
      VARY_WERROR("Disconnecting cookie jar.\n");
      return real_cookies + eaten;
    }

    //! @ignore
    DECLARE_OBJ_COUNT;
    //! @endignore

    protected string _sprintf(int fmt)
    {
      return fmt == 'O' && sprintf("CookieJar(%O)" + OBJ_COUNT,
				   RequestID::this && real_cookies);
    }

    string encode_json(int flags) {
      return Standards.JSON.encode(real_cookies);
    }
  }

  CookieJar|mapping(string:string) cookies;
  //! The indices and values map to the names and values of the cookies sent
  //! by the client for the requested page. All data (names and values) are
  //! decoded from their possible transport encoding.
  //!
  //! @note
  //!   Used to be a plain mapping in Roxen 4.0 and earlier. It now
  //!   has a wrapper that registers dependencies on the various cookies.
  //! @note
  //!   The wrapper is removed, and the contents partially restored at
  //!   request send time.

  //! Call to initialize the cookies.
  //!
  //! Typically called from callbacks installed with
  //! @[register_vary_callback()] to ensure @[cookies] is initialized.
  void init_cookies(int|void no_cookie_jar)
  {
    if (!cookies) {
      cookies = CookieJar(request_headers["cookie"]);
      if (no_cookie_jar) {
	// Disable the cookie jar -- Called from log()?
	real_cookies = cookies = ~cookies;
      }
    }
  }

  void init_pref_languages()
  //! Call to initialize @expr{@[misc]->pref_languages@}.
  //!
  //! Typically called from callbacks installed with
  //! @[register_vary_callback()] to ensure
  //! @expr{@[misc]->pref_languages@} is initialized.
  {
    if (!misc->pref_languages) {
      misc->pref_languages=PrefLanguages();
      if (string|array(string) contents = request_headers[ "accept-language" ])
      {
	if( !arrayp( contents ) )
	  contents = (contents-" ")/",";
	else
	  contents =
	    Array.flatten( map( map( contents, `-, " " ), `/, "," ))-({""});
	misc->pref_languages->languages=contents;
	misc["accept-language"] = contents;
      }
    }
  }

  mapping (string:array(string)|string) request_headers;
  //! Indices and values map to the names and values of all HTTP
  //! headers sent with the request, with lowercased header names.
  //! Here is where you look for the "user-agent" header, the
  //! "referer" [sic!] header and similar interesting data provided by
  //! the client.

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
  //!
  //! The transport encoding has been decoded (i.e. any @expr{%XX@}
  //! escapes and the charset according to @[input_charset]).

  multiset(string) config;
  //! Much like prestates, the id->config multiset is typically used for
  //! boolean information of state supplied by the client. The config state,
  //! however, is hidden in a client-side cookie treated specially by roxen,
  //! namely the <tt>RoxenConfig</tt> cookie.
  //!
  //! The transport encoding has been decoded (i.e. any @expr{%XX@}
  //! escapes and the charset according to @[input_charset]).

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
  //!
  //! The transport encoding has been decoded (i.e. any @expr{%XX@}
  //! escapes and the charset according to @[input_charset]). The
  //! pieces have then been concatenated together again in the same
  //! order, separated by @expr{"&"@}.

  string raw;
  //! The raw, untouched request in its entirety.
  //!
  //! @seealso
  //! @[raw_url]

  string query;
  //! The query part (i.e. all characters after the first question
  //! mark) of the requested URL.
  //!
  //! The transport encoding has been decoded (i.e. any @expr{%XX@}
  //! escapes and the charset according to @[input_charset]).

  string not_query;
  //! The path to the requested resource that is below the virtual
  //! server's mountpoint. I.e. for a typical server registering a URL
  //! with no ending path component, @[not_query] will contain the
  //! full path.
  //!
  //! @[not_query] usually begins with @expr{"/"@} but that is not
  //! guaranteed since it's taken from the request line. It has
  //! however been simplified so it is guaranteed to not contain any
  //! @expr{"."@} or @expr{".."@} segments.
  //!
  //! The transport encoding has been decoded (i.e. any @expr{%XX@}
  //! escapes and the charset according to @[input_charset]).

  string input_charset;
  //! The charset that was used to decode @[prestate], @[config],
  //! @[query], @[not_query], @[rest_query], and the variable bindings
  //! in @[real_variables].
  //!
  //! It is zero if they were not successfully charset decoded. That
  //! is effectively the same as if the charset was ISO-8859-1.
  //!
  //! @seealso
  //! @[decode_query_charset]

  string extra_extension;

  string data = "";
  //! The raw request body, containing non-decoded post variables et cetera.
  //!
  //! @note
  //!   In versions of Roxen prior to 5.0.505 this variable could sometimes
  //!   contain @expr{0@}, which should be regarded as equvivalent to
  //!   @expr{""@}.
  //!
  //! @note
  //!   If the amount of request data is unknown (ie @expr{misc->len@}
  //!   is @expr{0x7fffffff@}), then additional data can be retrieved
  //!   from @[connection()]. This is typically the case with eg STOR
  //!   (aka PUT) and the ftp protocol.

  string leftovers = "";
  //! Raw data belonging to the next request.
  //!
  //! @note
  //!   In versions of Roxen prior to 5.0.505 this variable could sometimes
  //!   contain @expr{0@}, which should be regarded as equvivalent to
  //!   @expr{""@}.

  string rawauth, realauth; // Used by many modules, so let's keep this.
  string since;

  string remoteaddr;
  //! The client's IP address.

  string host;
  //! The client's hostname, if resolved.

  multiset(string) cache_status = (<>);
  //! Contains the caches that were hit when the request was served.
  //! See the docstring for @tt{$cache-status@} in the @tt{LogFormat@}
  //! global variable for known values, but note that the multiset
  //! never actually contains the value @expr{"nocache"@}; it's only written
  //! when the multiset is empty.

  multiset(string) eval_status = (<>);
  //! Contains the content evaluators that were hit when the request
  //! was served. See the docstring for @tt{$eval-status@} in the
  //! @tt{LogFormat@} global variable for known values.

  object root_id;
  //! @decl RequestID root_id;
  //!   The root id object directly associated with the request - remains
  //!   the same for all id objects generated by <insert href> tags and
  //!   similar conditions that invoke @[clone_me()]. Points to itself
  //!   in the root id object.

  // Internal but not protected. The time variables have double use:
  // At the start of the timed period they are set to the starting
  // point in time, at the end they are changed to the elapsed time.
  int queue_length, queue_time, handle_time, handle_vtime;

  protected void create(Stdio.File fd, Protocol port, Configuration conf){}
  void send(string|object what, int|void len){}

  protected SimpleNode xml_data;	// XML data for the request.

  SimpleNode get_xml_data()
  {
    if (!data || !sizeof(data)) return 0;
    if (xml_data) return xml_data;
    // FIXME: Probably ought to check that the content-type for
    //        the request is text/xml.
    DAV_WERROR("Parsing XML data: %O\n", data);
    return xml_data =
      Parser.XML.Tree.simple_parse_input(data,
					 0,
					 Parser.XML.Tree.PARSE_ENABLE_NAMESPACES);
  }

  //! Get a string describing the link layer protocol for the request.
  //!
  //! @returns
  //!   Currently returns one of
  //!   @string
  //!     @value "-"
  //!       Unknown. Typically an internal request or the connection has
  //!       been closed.
  //!     @value "TCP/IP"
  //!       Standard TCP/IP connection.
  //!     @value "SSL/3.0"
  //!       Secure Socket Layer version 3.0.
  //!     @value "TLS/1.0"
  //!       Transport Layer Security version 1.0.
  //!     @value "TLS/1.1"
  //!       Transport Layer Security version 1.1.
  //!     @value "TLS/1.2"
  //!       Transport Layer Security version 1.2.
  //!   @endstring
  //!
  //! @note
  //!   This is the value logged by the log-format @tt{$link-layer@}.
  //!
  //! @note
  //!   More versions of TLS may become supported, in which case they
  //!   will get corresponding results from this function.
  //!
  //! @seealso
  //!   @[query_cipher_suite()]
  string query_link_layer()
  {
    if (!my_fd) return "-";
    if (!my_fd->query_version) return "TCP/IP";
    return replace(SSL.Constants.fmt_version(my_fd->query_version()), " ", "/");
  }

  //! Get a string describing the TLS cipher suite used for the request.
  //!
  //! @returns
  //!   Returns either
  //!   @string
  //!     @value "-"
  //!       None. Either the connection doesn't use SSL/TLS, or the
  //!       handshaking hasn't completed yet.
  //!     @value "TLS_*"
  //!     @value "SSL_*"
  //!       A symbol from the table of cipher suites in @[SSL.Constants].
  //!       These are typically the same as the symbols in the corresponding
  //!       RFCs, but with only the "TLS_"/"SSL_" prefix being upper case.
  //!   @endstring
  //!
  //! @note
  //!   This is the value logged by the log-format @tt{$cipher-suite@}.
  //!
  //! @seealso
  //!   @[query_link_layer()]
  string query_cipher_suite()
  {
    if (!my_fd || !my_fd->query_suite) return "-";
    int suite = my_fd->query_suite();
    if (!suite) return "-";
    return SSL.Constants.fmt_cipher_suite(suite);
  }

  // Parsed if-header for the request.
  protected mapping(string:array(array(array(string)))) if_data;

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

  int get_max_cache()
  //! Returns the maximum cacheable time in seconds. See
  //! @expr{@[misc]->cacheable@}.
  {
    return misc->cacheable;
  }

  int lower_max_cache (int seconds)
  //! Lowers the maximum cacheable time to @[seconds] if it currently
  //! has a higher value. Returns the old value. See
  //! @expr{@[misc]->cacheable@}.
  {
    if (mapping(mixed:int) lc = misc->local_cacheable)
      foreach (lc; mixed ind; int old)
	if (seconds < old)
	  lc[ind] = seconds;

    int old = misc->cacheable;
    if (seconds < old) {
      object/*(RXML.Context)*/ ctx = RXML_CONTEXT;
      if (ctx && ctx->id == this)
	ctx->set_id_misc ("cacheable", seconds);
      else
	misc->cacheable = seconds;

#ifdef DEBUG_CACHEABLE
      object frame = backtrace()[-2];
      report_debug ("%s:%d: Lower cacheable to %d (was %d)\n",
		    frame[0], frame[1], seconds, old);
#endif
    }

#ifdef DEBUG_CACHEABLE
    else {
      object frame = backtrace()[-2];
      report_debug ("%s:%d: Not lowering cacheable to %d (is %d)\n",
		    frame[0], frame[1], seconds, old);
    }
#endif

    return old;
  }

  int raise_max_cache (int seconds)
  //! Raises the maximum cacheable time to @[seconds] if it currently
  //! has a lower value. Returns the old value. See
  //! @expr{@[misc]->cacheable@}.
  {
    if (mapping(mixed:int) lc = misc->local_cacheable)
      foreach (lc; mixed ind; int old)
	if (seconds > old)
	  lc[ind] = seconds;

    int old = misc->cacheable;
    if (seconds > old) {
      object/*(RXML.Context)*/ ctx = RXML_CONTEXT;
      if (ctx && ctx->id == this)
	ctx->set_id_misc ("cacheable", seconds);
      else
	misc->cacheable = seconds;

#ifdef DEBUG_CACHEABLE
      object frame = backtrace()[-2];
      report_debug ("%s:%d: Raise cacheable to %d (was %d)\n",
		    frame[0], frame[1], seconds, old);
#endif
    }

#ifdef DEBUG_CACHEABLE
    else {
      object frame = backtrace()[-2];
      report_debug ("%s:%d: Not raising cacheable to %d (is %d)\n",
		    frame[0], frame[1], seconds, old);
    }
#endif

    return old;
  }

  int set_max_cache( int seconds )
  //! Sets the maximum cacheable time to @[seconds]. Returns the old
  //! value. See @expr{@[misc]->cacheable@}.
  {
    if (mapping(mixed:int) lc = misc->local_cacheable)
      foreach (lc; mixed ind;)
	lc[ind] = seconds;

    int old = misc->cacheable;
    if (seconds != old) {
      object/*(RXML.Context)*/ ctx = RXML_CONTEXT;
      if (ctx && ctx->id == this)
	ctx->set_id_misc ("cacheable", seconds);
      else
	misc->cacheable = seconds;
    }

#ifdef DEBUG_CACHEABLE
    object frame = backtrace()[-2];
    report_debug ("%s:%d: Set cacheable to %d (was %d)\n",
		  frame[0], frame[1], seconds, old);
#endif

    return old;
  }

  //! Register that the result was dependant on the request header
  //! specified by @[vary], and/or a callback @[cb] that generates
  //! a key that can be used as a decision variable.
  //!
  //! The headers registred in @[vary] during the requests parsing
  //! will be used to generate the vary header (RFC 2068 14.43) for
  //! the result.
  //!
  //! @param vary
  //!   Either a (lower-case) string that specifies the name of
  //!   a request header, or @tt{0@} (zero) which specifies that
  //!   it doesn't depend on a header, but something else (eg
  //!   the IP-number of the client (and thus will generate a
  //!   @tt{"*"@} vary header.
  //!
  //! @param cb
  //!   This function will be called at request time with the
  //!   path of the request, and the @[RequestID]. It should
  //!   return a key fragment (either a string or an integer). If
  //!   @[cb] is not specified, it will default to a function that
  //!   returns the value of the request header specified by @[vary].
  //!
  //! @note
  //!   The order of calls to @[register_vary_callback()] is significant
  //!   since it will be used to create a decision tree.
  //!
  //!   Note also that the function @[cb] should be fast, and avoid
  //!   excessive lengths in the returned key, to keep down on
  //!   perfomance issues.
  //!
  //!   Caveat! The callback function gets called very early in
  //!   the request processing, so not all fields in the @[RequestID]
  //!   object may be valid yet.
  //!
  //! @seealso
  //!   @[NOCACHE()], @[propagate_vary_callbacks()]
  void register_vary_callback(string|void vary,
			      function(string, RequestID: string|int)|void cb)
  {
    if (!(vary || cb)) {
      error("Vary: At least one of the arguments MUST be specified.\n");
    }
    // Don't generate a vary header for the Host header.
    if (vary != "host") {
      if (!misc->vary) {
	misc->vary = (< vary || "*" >);
      } else {
	misc->vary[vary || "*"] = 1;
      }
    }
    if (!misc->vary_cb_set) {
      misc->vary_cb_set = cb ? ([vary: (<cb>)]) : ([vary: 1]);
      misc->vary_cb_order = ({ cb || vary });
      VARY_WERROR("register_vary_callback(%O, %O)\n", vary, cb);
      return;
    }
    if (multiset(function(string,RequestID:string|int))|int(1..1) old =
	misc->vary_cb_set[vary]) {
      if (old == 1) {
	// The full header has already been registred.
	VARY_WERROR("register_vary_callback(%O, %O) Full header\n", vary, cb);
	return;
      }
      else if (old[cb]) {
	// Already registred.
	VARY_WERROR("register_vary_callback(%O, %O) Duplicate\n", vary, cb);
	return;
      }
      else if (!cb) {
	// Registering full header now - remove all callbacks.
	misc->vary_cb_order = misc->vary_cb_order - (array) old + ({vary});
	misc->vary_cb_set[vary] = 1;
	VARY_WERROR("register_vary_callback(%O, 0) Removed old cbs\n", vary);
	return;
      }
      old[cb] = 1;
    }
    else
      misc->vary_cb_set[vary] = cb ? (<cb>) : 1;
    misc->vary_cb_order += ({ cb || vary });
    VARY_WERROR("register_vary_callback(%O, %O)\n", vary, cb);
  }

  void unregister_vary_callback (string vary,
				 void|function(string,RequestID:string|int) cb)
  //! Unregisters a dependency on a request header or a specific vary
  //! callback. @[vary] and @[cb] should be the same arguments that
  //! were previously passed to @[register_vary_callback]. If @[cb] is
  //! zero then all callbacks registered for the @[vary] header are
  //! unregistered.
  //!
  //! @note
  //!   Try to avoid this function. It's ugly practice.
  //!
  //! @seealso
  //!   @[register_vary_callback()]
  {
    if (misc->vary)
      misc->vary[vary || "*"] = 0;
    if (!misc->vary_cb_set) {
      VARY_WERROR ("unregister_vary_callback (%O, %O) "
		   "Got no vary registrations\n", vary, cb);
      return;
    }
    if (multiset(function(string,RequestID:string|int))|int(1..1) old =
	misc->vary_cb_set[vary]) {
      if (multisetp (old)) {
	if (cb) {
	  if (old[cb]) {
	    misc->vary_cb_order -= ({cb});
	    old[cb] = 0;
	    if (!sizeof (old)) m_delete (misc->vary_cb_set, vary);
	    VARY_WERROR ("unregister_vary_callback (%O, %O) "
			 "Removed callback\n", vary, cb);
	  }
	  else {
	    VARY_WERROR ("unregister_vary_callback (%O, %O) "
			 "Callback wasn't registered\n", vary, cb);
	  }
	}
	else {
	  misc->vary_cb_order -= (array) old;
	  m_delete (misc->vary_cb_set, vary);
	  VARY_WERROR ("unregister_vary_callback (%O, 0) "
		       "Removed %d callbacks\n", vary, sizeof (old));
	}
      }
      else {
	if (cb) {
	  VARY_WERROR ("unregister_vary_callback (%O, %O) "
		       "Callback wasn't registered\n", vary, cb);
	}
	else {
	  misc->vary_cb_order -= ({vary});
	  m_delete (misc->vary_cb_set, vary);
	  VARY_WERROR ("unregister_vary_callback (%O, 0) "
		       "Removed header\n", vary);
	}
      }
    }
  }

  //! Propagate vary callbacks from another @[RequestID] object.
  //!
  //! This function is typically used when a subrequest has
  //! been performed to propagate vary callbacks from the
  //! subrequest to the present request.
  //!
  //! @seealso
  //!   @[register_vary_callback()]
  void propagate_vary_callbacks(RequestID id)
  {
    VARY_WERROR("Propagating vary information from %O to %O...\n",
		id, this_object());
    if (id->misc->vary) {
      mapping(function(string,RequestID:string|int):multiset(string))
	reverse_cb_set;
      foreach(id->misc->vary_cb_order || ({}),
	      string|function(string, RequestID: string|int)|object vary_cb) {
	if (stringp(vary_cb)) {
	  VARY_WERROR("Propagating vary header %O.\n", vary_cb);
	  register_vary_callback(vary_cb);
	} else if (objectp(vary_cb) && vary_cb->cookie) {
	  // Update indirectly via the CookieJar.
	  VARY_WERROR("Propagating cookie %O.\n", vary_cb->cookie);
	  mixed ignored = cookies[vary_cb->cookie];
	} else {
	  if (!reverse_cb_set) {
	    // This gets complicated...
	    // Build a reverse lookup from callback to the headers.
	    VARY_WERROR("Building reverse vary lookup.\n");
	    reverse_cb_set = ([]);
	    foreach(id->misc->vary_cb_set || ([]); string vary;
		    multiset(function(string,RequestID:string|int))|
		    int(1..1) cb_info) {
	      if (multisetp(cb_info)) {
		foreach(cb_info;
			function(string,RequestID:string|int) cb;) {
		  if (reverse_cb_set[cb]) {
		    reverse_cb_set[cb][vary] = 1;
		  } else {
		    reverse_cb_set[cb] = (< vary >);
		  }
		}
	      }
	    }
	  }
	  VARY_WERROR("Propagating generic vary callback: %O (headers: %O)\n",
		      vary_cb, reverse_cb_set[vary_cb]);
	  foreach(reverse_cb_set[vary_cb] || (< 0 >); string vary;) {
	    register_vary_callback(vary, vary_cb);
	  }
	}
      }
    }
    VARY_WERROR("Propagation of vary information from %O to %O complete.\n",
		id, this_object());
  }

  protected array(object) threadbound_session_objects;

  void add_threadbound_session_object (object obj)
  //! This can be used to register some kind of session object (e.g. a
  //! mutex lock) which will have the same lifetime as this request in
  //! the current thread. I.e. @[obj] will be destructed when a
  //! handler thread is done with this request, or when this object is
  //! destructed, whichever comes first.
  //!
  //! @[obj] is destructed even if a handler thread is aborted due to
  //! an exception. It is not an error if @[obj] already is destructed
  //! when the lifetime ends.
  //!
  //! @note
  //! If you want to be able to retrieve @[obj] later, put it into
  //! @[misc] too.
  {
    if (threadbound_session_objects)
      threadbound_session_objects += ({obj});
    else
      threadbound_session_objects = ({obj});
  }

  int remove_threadbound_session_object (object obj)
  //! Removes an object which has earlier been passed to
  //! @[add_threadbound_session_object].
  //!
  //! @returns
  //! 1 if @[obj] was among the threadbound session objects, zero
  //! otherwise.
  {
    if (!threadbound_session_objects)
      return 0;
    int s = sizeof (threadbound_session_objects);
    threadbound_session_objects -= ({obj});
    return sizeof (threadbound_session_objects) != s;
  }

  void destruct_threadbound_session_objects()
  //! Explicitly destructs all objects registered with
  //! @[add_threadbound_session_object]. Should normally only be used
  //! internally.
  {
    if (array(object) objs = this && threadbound_session_objects) {
      threadbound_session_objects = 0;
      foreach (objs, object obj) {
	if (mixed err = catch {
	    if (obj)
	      // Relying on the interpreter lock here.
	      destruct (obj);
	  })
	  master()->handle_error (err);
      }
    }
  }

  protected string cached_url_base;

  string url_base()
  //! Returns the base part of the URL, i.e. what should be added in
  //! front of a path in the virtual filesystem to get the absolute
  //! URL to the page. The returned string ends with a "/", or is ""
  //! if no server base could be found.
  //!
  //! This function gets the correct host for protocols that handles
  //! IP-less hosts.
  {
    if (!cached_url_base) {
      string host;
      string scheme;

      // We're looking at the forwarded header...
      register_vary_callback("forwarded");

      // First look at the forwarded header.
      if (misc->forwarded) {
      got_both:
	foreach(misc->forwarded, array(int|string) entry) {
	  foreach(entry/ ({ ';' }), array(int|string) forwarded_pair) {
	    if ((sizeof(forwarded_pair) != 3) ||
		(forwarded_pair[1] != '=') ||
		!stringp(forwarded_pair[0]) ||
		!stringp(forwarded_pair[2])) continue;
	    switch(lower_case(forwarded_pair[0])) {
	    case "proto":
	      if (scheme) continue;
	      scheme = lower_case(forwarded_pair[2]);
	      if (host) break got_both;
	      break;
	    case "host":
	      if (host) continue;
	      host = forwarded_pair[2];
	      if (scheme) break got_both;
	      break;
	    }
	  }
	}
      }

      // Second look at the host header in the request.
      if (!host) {
	// We're looking at the host header...
	register_vary_callback("host");
	host = misc->host;
      }

      // Then try the port object.
      if (!scheme) {
	scheme = port_obj->prot_name;
      }
      if (!host) {
	mapping(string:mixed) conf_data = port_obj->conf_data[conf];
	if (conf_data) {
	  host = conf_data->hostname;
	  if (host == "*")
	    // Use the hostname in the configuration url.
	    // Fall back to the numeric ip.
	    host = conf->get_host() || port_obj->ip;
	  if (port_obj->port != port_obj->default_port) {
	    host += ":" + port_obj->port;
	  }
	}
      } else {
	string host_no_port;
	int port;

	if (has_prefix(host, "[")) {
	  //  IPv6
	  sscanf(host, "[%s]:%d", host_no_port, port);
	} else {
	  sscanf(host, "%[^:]:%d", host_no_port, port);
	}
	if (port == ([ "http":80, "https":443 ])[scheme]) {
	  // Default port.
	  port = 0;
	  host = host_no_port;
	}
      }

      if (host) {
	cached_url_base = scheme + "://" + host;
      }

      // Then try the configuration url.
      else if (conf && sizeof (host = conf->get_url()))
	cached_url_base = host[..sizeof(host) - 2]; // Remove trailing '/'.

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
  //! overridden, instead another (duplicate) header line with
  //! @[value] will be sent in the response, after the old one(s).
  //! However, if a header with the same name and value already exists
  //! then another one isn't added.
  //!
  //! @note
  //! If used from within an RXML parse session, this function will
  //! ensure that the new header is registered properly in the RXML
  //! p-code cache. That's the primary reason to used it instead of
  //! adding the header directly to
  //! @tt{misc->defines[" _extra_heads"]@} and/or @tt{misc->moreheads@}.
  //!
  //! @note
  //! Although case is insignificant in http header names, it is
  //! significant here. @[name] should always follow the
  //! capitalization used in RFC 2616. Use
  //! @[Roxen.canonicalize_http_header] if necessary.
  //!
  //! @seealso
  //! @[set_response_header], @[add_or_set_response_header],
  //! @[get_response_headers], @[remove_response_headers]
  {
    mapping(string:string|array(string)) hdrs = misc->moreheads;
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
    object /*(RXML.Context)*/ ctx;
    if (misc->defines && misc->defines[" _extra_heads"] &&
	(ctx = RXML_CONTEXT))
      ctx->set_var (name, cur_val, "header");
    else
      hdrs[name] = cur_val;
  }

  void set_response_header (string name, string value)
  //! Sets the header @[name] to the value @[value] to be sent in the
  //! http response. If an existing header with the same name exists,
  //! its value(s) will be overridden. This is useful for headers like
  //! @expr{"Expire-Time"@}, otherwise @[add_response_header] is
  //! typically a better choice.
  //!
  //! @note
  //! If used from within an RXML parse session, this function will
  //! ensure that the new header is registered properly in the RXML
  //! p-code cache. That's the primary reason to used it instead of
  //! adding the header directly to
  //! @tt{misc->defines[" _extra_heads"]@} or @tt{misc->moreheads@}.
  //!
  //! @note
  //! Although case is insignificant in http header names, it is
  //! significant here. @[name] should always follow the
  //! capitalization used in RFC 2616. Use
  //! @[Roxen.canonicalize_http_header] if necessary.
  //!
  //! @seealso
  //! @[add_or_set_response_header], @[get_response_headers],
  //! @[remove_response_headers]
  {
    if (!misc->moreheads) misc->moreheads = ([]);
    misc->moreheads[name] = value;
    object/*(RXML.Context)*/ ctx;
    if (misc->defines && misc->defines[" _extra_heads"] &&
	(ctx = RXML_CONTEXT))
      ctx->signal_var_change (name, "header", value);
  }

  void add_or_set_response_header (string name, string value)
  //! Calls either @[add_response_header] or @[set_response_header] as
  //! appropriate for the specific header: If a header is known to
  //! allow multiple values (from RFC 2616) then
  //! @[add_response_header] is called to add another value to it,
  //! otherwise @[set_response_header] is called to override the old
  //! value if there is any.
  {
    if ((["Accept-Ranges": 1,
	  "Allow": 1,
	  "Cache-Control": 1,
	  "Connection": 1,
	  "Content-Encoding": 1,
	  "Content-Language": 1,
	  "Pragma": 1,
	  "Proxy-Authenticate": 1,
	  "Set-Cookie": 1,
	  "Trailer": 1,
	  "Transfer-Encoding": 1,
	  "Upgrade": 1,
	  "Vary": 1,
	  "Via": 1,
	  "Warning": 1,
	  "WWW-Authenticate": 1,
	])[name])
      add_response_header (name, value);
    else
      set_response_header (name, value);
  }

  protected constant http_nontoken_chars = ([
    0:1, 1:1, 2:1, 3:1, 4:1, 5:1, 6:1, 7:1, 8:1, 9:1, 10:1, 11:1, 12:1, 13:1,
    14:1, 15:1, 16:1, 17:1, 18:1, 19:1, 20:1, 21:1, 22:1, 23:1, 24:1, 25:1,
    26:1, 27:1, 28:1, 29:1, 30:1, 31:1, '(':1, ')':1, '<':1, '>':1, '@':1,
    ',':1, ';':1, ':':1, '\\':1, '"':1, '/':1, '[':1, ']':1, '?':1, '=':1,
    '{':1, '}':1, ' ':1, '\t':1]);

#define MATCH_TOKEN_PREFIX(VAL, PREFIX)					\
  (VAL == PREFIX ||							\
   has_prefix (VAL, PREFIX) && http_nontoken_chars[VAL[sizeof (PREFIX)]])

  array(string) get_response_headers (string name, void|string value_prefix)
  //! Returns the values of all headers with the given @[name] in the
  //! set of headers that are to be sent in the response.
  //!
  //! If @[value_prefix] is given then it must match a prefix of the
  //! header value up to a token boundary for the value to be
  //! returned.
  //!
  //! @returns
  //! Returns an array containing the matching values (zero or more).
  //!
  //! @note
  //! This function only searches through headers in
  //! @tt{misc->defines[" _extra_heads"]@} and @tt{misc->moreheads@},
  //! i.e. headers that have been set using @[add_response_header] or
  //! @[set_response_header].
  {
    mapping(string:string|array(string)) hdrs = misc->moreheads;
    if (hdrs) {
      if (array(string)|string cur_val = hdrs[name]) {
	if (!value_prefix)
	  return arrayp (cur_val) ? cur_val : ({cur_val});
	else {
	  if (arrayp (cur_val)) {
	    array(string) res = ({});
	    foreach (cur_val, string val)
	      if (MATCH_TOKEN_PREFIX (val, value_prefix))
		res += ({val});
	    return res;
	  }
	  else
	    if (MATCH_TOKEN_PREFIX (cur_val, value_prefix))
	      return ({cur_val});
	}
      }
    }

    return ({});
  }

  int remove_response_headers (string name, void|string value_prefix)
  //! Removes a header with the given @[name] from the set of headers
  //! that are to be sent in the response.
  //!
  //! If @[value_prefix] is given then it must match a prefix of the
  //! header value up to a token boundary for the header to be
  //! removed, otherwise all headers with the given name are removed.
  //!
  //! @returns
  //! Returns nonzero if at least one header was removed.
  //!
  //! @note
  //! This function only removes headers in
  //! @tt{misc->defines[" _extra_heads"]@} and/or @tt{misc->moreheads@},
  //! i.e. headers that have been set using @[add_response_header] or
  //! @[set_response_header]. It's possible that a matching header
  //! gets sent anyway if it gets added later or through other means
  //! (e.g. through @tt{"extra_heads"@} in a response mapping).
  {
    int removed;

    mapping(string:string|array(string)) hdrs = misc->moreheads;
    if (hdrs) {
      if (array(string)|string cur_val = hdrs[name]) {
	if (!value_prefix) {
	  m_delete (hdrs, name);
	  removed = 1;
	}
	else {
	  if (arrayp (cur_val)) {
	    foreach (cur_val; int i; string val)
	      if (MATCH_TOKEN_PREFIX (val, value_prefix)) {
		cur_val[i] = 0;
		removed = 1;
	      }
	    cur_val -= ({0});
	    if (sizeof (cur_val)) hdrs[name] = cur_val;
	    else m_delete (hdrs, name);
	  }
	  else
	    if (MATCH_TOKEN_PREFIX (cur_val, value_prefix)) {
	      m_delete (hdrs, name);
	      removed = 1;
	    }
	}
      }
    }

    return removed;
  }

  protected MultiStatus multi_status;

  MultiStatus get_multi_status()
  //! Returns a @[MultiStatus] object that will be used to produce a
  //! 207 Multi-Status response (RFC 2518 10.2). It's only consulted
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

  void set_output_charset( string|function to, int|void mode )
  {
#ifdef DEBUG
    if (stringp (to))
      // This will throw an error if the charset is invalid.
      Charset.encoder (to);
#endif

    if (object/*(RXML.Context)*/ ctx = RXML_CONTEXT)
      ctx->add_p_code_callback ("set_output_charset", to, mode);

    if( has_value (output_charset, to) ) // Already done.
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
	if (sizeof (output_charset) &&
	    (!stringp (to) || !stringp (output_charset[0])))
	  error ("Can't join charsets with functions (%O with %O).\n",
		 to, output_charset[0]);
	output_charset += ({ to });
	break;
    }
  }

  string|function(string:string) get_output_charset()
  {
    string charset;
    function(string:string) encoder;
    foreach( output_charset, string|function f )
      [charset,encoder] = join_charset(charset, f, encoder, 0);
    return charset || encoder;
  }
  
  protected string charset_name(function|string what)
  {
    if (what == string_to_unicode) return "ISO10646-1";
    if (what == string_to_utf8) return "UTF-8";
    return upper_case((string) what);
  }

  protected function charset_function(function|string what, int allow_entities)
  {
    if (functionp(what)) return what;
    switch (what) {
    case "ISO-10646-1":
    case "ISO10646-1":
      return string_to_unicode;
      
    case "UTF-8":
      return string_to_utf8;
      
    default:
      //  Use entity fallback if content type allows it
      function fallback_func =
	allow_entities &&
	lambda(string char) {
	  return sprintf("&#x%x;", char[0]);
	};
	
      _charset_decoder_func =
	_charset_decoder_func || Roxen->_charset_decoder;
      return
	_charset_decoder_func(Charset.encoder((string) what, "", fallback_func))
	->decode;
    }
  }
  
  protected array(string) join_charset(string old,
				       function|string add,
				       function oldcodec,
				       int allow_entities)
  {
    switch (old && upper_case(old)) {
    case 0:
    case "ISO8859-1":
    case "ISO-8859-1":
      return ({ charset_name(add), charset_function(add, allow_entities) });
    case "ISO10646-1":
    case "UTF-8":
      return ({ old, oldcodec }); // Everything goes here. :-)
    case "ISO-2022":
      return ({ old, oldcodec }); // Not really true, but how to know this?
    default:
      // Not true, but there is no easy way to add charsets yet...
#if 1
      // The safe choice.
      return ({"UTF-8", string_to_utf8});
#else
      return ({ charset_name(add), charset_function(add, allow_entities) });
#endif
    }
  }
  
  array replace_charset_placeholder(string charset, string what, int allow_entities) {
    // If we allow entities we also replace the automatic charset placeholder with the charset in use
    if(allow_entities && charset)
      what = replace(what, Roxen->magic_charset_variable_placeholder, charset);
    return ({ charset, what });
  } 
  
  array(string) output_encode(string what, int|void allow_entities,
			      string|void force_charset)
  {
    //  Performance optimization for unneeded ISO-8859-1 recoding of
    //  strings which already are narrow.
    if (String.width(what) == 8) {
      if (force_charset) {
	if (upper_case(force_charset) == "ISO-8859-1")
	  return replace_charset_placeholder("ISO-8859-1", what, allow_entities);
      } else {
	if (sizeof(output_charset) == 1 &&
	    upper_case(output_charset[0]) == "ISO-8859-1")
	  return replace_charset_placeholder("ISO-8859-1", what, allow_entities);
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
      return replace_charset_placeholder( charset, what, allow_entities );
    } else
      return ({
	0,
	Charset.encoder((force_charset / "=")[-1])->feed(what)->drain()
      });
  }

  void split_query_vars (string query_vars, mapping(string:array(string)) vars)
  {
    array(string) rests = ({});

    foreach (query_vars / "&", string v) {
      if(sscanf(v, "%s=%s", string a, string b) == 2)
      {
	a = _Roxen.http_decode_string(replace(a, "+", " "));
	b = _Roxen.http_decode_string(replace(b, "+", " "));
	vars[ a ] += ({ b });
      } else
	rests += ({_Roxen.http_decode_string( v )});
    }

    if (sizeof (rests)) {
      string rest = rests * "&";
#ifdef ENABLE_IDIOTIC_STUPID_STANDARD
      // This comes from http.pike with the illustrious comment "IDIOTIC
      // STUPID STANDARD". I fail to find any standard that says
      // anything about this, so nowadays it's disabled by default.
      // /mast
      rest=replace(rest, "+", "\000");
#endif
      vars[""] = ({rest});
    }
  }

  string decode_query_charset (string path,
			       mapping(string:array(string)) vars,
			       string decode_charset)
  //! Decodes the charset encoding of a query.
  //!
  //! @[path] is the path part of the query. It is returned after
  //! decoding. @[vars] contains the query variables, and they are
  //! assigned to @[real_variables] after decoding. Both @[path] and
  //! @[vars] are assumed to be transport decoded already.
  //!
  //! If @[decode_charset] is a string, it defines a charset to decode
  //! with after the transport encoding has been removed. The string
  //! can be on the combined form understood by
  //! @[Roxen.get_decoder_for_client_charset].
  //!
  //! If @[decode_charset] has the special value @expr{"magic"@} then
  //! the function will look for a variable tuple with
  //! @expr{magic_roxen_automatic_charset_variable@} and use
  //! heuristics on that to figure out the character set that
  //! @[query_string] has been encoded with. See the RXML tag
  //! @expr{<roxen-automatic-charset-variable>@} and
  //! @[Roxen.get_client_charset].
  //!
  //! If @[decode_charset] has the special value
  //! @expr{"roxen-http-default"@} then the function will first try
  //! the @expr{"magic"@} method above, and if the special variable is
  //! not found it tries to UTF-8 decode. If there is a decode failure
  //! then it is ignored and no charset decoding is done (meaning that
  //! the original charset is effectively assumed to be ISO-8859-1).
  //! As the name suggests, this is the default method used on
  //! incoming requests by the http protocol module.
  //!
  //! The variable @[input_charset] is set to the charset successfully
  //! used if @[decode_charset] was given. The charset decoding uses
  //! an all-or-nothing approach - if there is an error decoding any
  //! string then no string is decoded. If the function throws an
  //! error due to a decode failure then @[real_variables] remain
  //! unchanged.
  //!
  //! @note
  //! Using @expr{"utf-8"@} as @[decode_charset] reverses the URI
  //! encoding produced by @[Roxen.http_encode_url] for eight bit and
  //! wider chars. That is compliant with the IRI standard (RFC 3987)
  //! and HTML 4.01 (appendix B.2.1).
  {
  do_decode_charset:
    if (decode_charset == "roxen-http-default") {
      array(string) magic = vars->magic_roxen_automatic_charset_variable;
      decode_charset = magic && Roxen->get_client_charset (magic[0]);
      function(string:string) decoder = decode_charset ?
	Roxen->get_decoder_for_client_charset (decode_charset) :
	utf8_to_string;

      mapping(string:array(string)) decoded_vars = ([]);
      if (mixed err = catch {
	  path = decoder (path);
	  foreach (vars; string var; array(string) vals) {
	    if (vars[var + ".mimetype"])
	      // Don't decode the value if it has a mime type (which
	      // we assume comes from a multipart/form-data POST).
	      decoded_vars[decoder (var)] = vals;
	    else
	      decoded_vars[decoder (var)] = map (vals, decoder);
	  }
	}) {
#ifdef DEBUG
	if (decode_charset)
	  report_debug ("Failed to decode query %O using charset %O derived "
			"from magic_roxen_automatic_charset_variable %O: %s",
			raw_url, decode_charset, magic[0],
			describe_error (err));
#if 0
	else
	  report_debug ("Failed to decode query %O using UTF-8: %s",
			raw_url, describe_error (err));
#endif
#endif
      }
      else {
	vars = decoded_vars;
	input_charset = decode_charset || "utf-8"; // Set this after we're done.
      }
    }

    else if (decode_charset) {
      if (decode_charset == "magic") {
	array(string) magic = vars->magic_roxen_automatic_charset_variable;
	decode_charset = magic && Roxen->get_client_charset (magic[0]);
	if (!decode_charset)
	  break do_decode_charset;
      }

      function(string:string) decoder =
	Roxen->get_decoder_for_client_charset (decode_charset);
      path = decoder (path);

      mapping(string:array(string)) decoded_vars = ([]);
      foreach (vars; string var; array(string) vals) {
	if (vars[var + ".mimetype"])
	  // Don't decode the value if it has a mime type (which we
	  // assume comes from a multipart/form-data POST).
	  decoded_vars[decoder (var)] = vals;
	else
	  decoded_vars[decoder (var)] = map (vals, decoder);
      }
      vars = decoded_vars;
      input_charset = decode_charset; // Set this after we're done.
    }

    if (sizeof (real_variables))
      foreach (vars; string var; array(string) vals)
	real_variables[var] += vals;
    else {
      real_variables = vars;
      // Must fix the mapping in FakedVariables too.
      variables = FakedVariables (vars);
    }

    return path;
  }

  string scan_for_query( string f )
  {
    if(sscanf(f,"%s?%s", f, query) == 2) {
      mapping(string:array(string)) vars = ([]);
      split_query_vars (query, vars);
      f = decode_query_charset (_Roxen.http_decode_string (f), vars, 0);
    }
    return f;
  }

  string get_response_content_type (mapping file,
				    void|int(1..1) destructive)
  {
    string|array(string) type = file->type;
    if (mappingp (file->extra_heads) && file->extra_heads["Content-Type"]) {
      type = file->extra_heads["Content-Type"];
      if (destructive) m_delete (file->extra_heads, "Content-Type");
    }
    if (mappingp (misc->moreheads) && misc->moreheads["Content-Type"]) {
      type = misc->moreheads["Content-Type"];
      if (destructive) m_delete (misc->moreheads, "Content-Type");
    }
    if (arrayp (type)) type = type[0];

    return type || "text/plain";
  }

  mapping(string:string|array(string)) make_response_headers (
    mapping(string:mixed) file)
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
      if(!file->stat && file->file->stat)
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

    string type = get_response_content_type (file, 1);

    mapping(string:string) heads = ([]);

    //  Collect info about language forks and their protocol cache callbacks
    //  and Vary header effects.
    if (PrefLanguages pl = misc->pref_languages)
      pl->finalize_delayed_vary(this);
    
    if( !zero_type(misc->cacheable) &&
	(misc->cacheable != INITIAL_CACHEABLE) ) {
      if (!misc->cacheable) {
	// It expired a year ago.
	heads["Expires"] = Roxen->http_date( predef::time(1)-31557600 );
	// Force the vary header generated below to be "*".
	misc->vary = (< "*" >);
	VARY_WERROR("Not cacheable. Force vary *.\n");
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

    //  Only process output encoding if no "; charset=" suffix is available.
    if (!ct_charset_search->match (type)) {
      string charset;

      if( stringp(file->data) ) {
	if (file->charset)
	  // Join to be on the safe side.
	  set_output_charset (file->charset, 2);

	if (sizeof (output_charset) || (String.width(file->data) > 8))
	{
	  sscanf (type, "%[-!#$%&´*+./0-9A-Z^_`a-z{|}~]", string ct);
	  int allow_entities =
	    (ct == "text/xml") ||
	    (ct == "text/html") ||
	    (ct == "application/xml") ||
	    sscanf(ct, "application/%*s+xml%*c") == 1;
	  [charset, file->data] = output_encode( file->data, allow_entities );
	}
      }
      
      //  Only declare charset if we have exact knowledge of it. We cannot
      //  provide a default for other requests since e.g. Firefox will
      //  complain if it receives a charset=ISO-8859-1 header for text data
      //  that starts with a UTF-8 BOM.
      if (charset)
	type += "; charset=" + charset;
    }

    if (stringp (file->data)) {
      if (String.width(file->data) > 8) {
	// Invalid charset header!
	// DWIM!
	eval_status["bad-charset"] = 1;
	file->data = string_to_utf8(file->data);
	type = (type/";")[0] + "; charset=utf-8";
      }
      file->len = sizeof (file->data);
    }

    heads["Content-Type"] = type;

#ifndef DISABLE_BYTE_RANGES
    heads["Accept-Ranges"] = "bytes";
#endif
    heads["Server"] = replace(roxenp()->version(), " ", "_");
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
	(file->len < conf->datacache->get_cache_stats()->max_file_size)) {
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
	sprintf("\"%s\"", String.string2hex(Crypto.MD5.hash(data)));
    }
#endif /* RAM_CACHE */

    if (misc->vary && sizeof(misc->vary)) {
      // Generate a vary header.
      VARY_WERROR("Full set: %s\n", ((array)misc->vary) * ", ");
      if (!supports->vary) {
	// Broken support for vary.
	heads->Vary = "User-Agent";
#ifndef DISABLE_VARY_EXPIRES_FALLBACK
	// It expired a year ago.
	heads->Expires = Roxen->http_date(predef::time(1)-31557600);
#endif /* !DISABLE_VARY_EXPIRES_FALLBACK */
	VARY_WERROR("Vary not supported by the browser.\n");
      } else if (misc->vary["*"]) {
	// Depends on non-headers.
	heads->Vary = "*";
      } else {
	heads->Vary = ((array)misc->vary) * ", ";
      }
    }

    // Note: The following will cause headers with the same names to
    // be replaced rather than added to. That's not always what one
    // wants, but otoh it's not clear in which order to merge them
    // either.

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

    if (objectp(cookies)) {
      c->cookies = c->CookieJar(real_cookies + ([]));
    } else if (cookies) {
      c->cookies = c->real_cookies = (real_cookies||([])) + ([]);
    } else {
      c->cookies = c->real_cookies = 0;
    }
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

    c->json_logger = json_logger->child();
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

  protected void destroy()
  {
    destruct_threadbound_session_objects();
  }

  string _sprintf (int flag)
  {
    return flag == 'O' && ("RequestID(" + (raw_url||"") + ")"
#ifdef ID_OBJ_DEBUG
			   + (__marker ? "[" + __marker->count + "]" : "")
#else
			   + OBJ_COUNT
#endif
			  );
  }
}

//! @appears MultiStatusStatus
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

  string _sprintf (int flag)
  {
    return flag == 'O' &&
      sprintf ("MultiStatusStatus(%d,%O)", http_code, message);
  }
}

private SimpleElementNode ok_status_node =
  SimpleElementNode("DAV:status", ([]))->add_child(SimpleTextNode("HTTP/1.1 200 OK"));

//! @appears MultiStatusPropStat
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

  string _sprintf (int flag)
  {
    return flag == 'O' && sprintf ("MultiStatusPropStat(%O)", properties);
  }
}

//! @appears MultiStatusNode
typedef MultiStatusStatus|MultiStatusPropStat MultiStatusNode;

//! @appears MultiStatus
class MultiStatus
{
  protected mapping(string:MultiStatusNode) status_set = ([]);

  protected mapping(string:string) args = ([
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
    // Encode the hrefs because some clients (eg MacOS X) assume that
    // they are proper URLs (eg including fragment).
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

  //! MultiStatus with a fix prefix.
  //!
  //! This object acts as a proxy for its parent.
  class Prefixed (protected string href_prefix)
  {
    //! Get the parent @[MultiStatus] object.
    MultiStatus get_multi_status() {return MultiStatus::this;}

    //! Add a property for a path.
    //!
    //! @note
    //!   Note that the segments of the path will be
    //!   encoded with @[Roxen.http_encode_url()].
    void add_property(string path, string prop_name,
		      void|int(0..0)|string|array(SimpleNode)|SimpleNode|
		      MultiStatusStatus|mapping(string:mixed) prop_value)
    {
      path = map(path/"/", Roxen->http_encode_url)*"/";
      MultiStatus::add_property(href_prefix + path, prop_name, prop_value);
    }

    //! Add a status for a path.
    //!
    //! @note
    //!   Note that the segments of the path will be
    //!   encoded with @[Roxen.http_encode_url()].
    void add_status (string path, int status_code,
		     void|string message, mixed... args)
    {
      path = map(path/"/", Roxen->http_encode_url)*"/";
      MultiStatus::add_status (href_prefix + path, status_code, message, @args);
    }

    //!
    void add_namespace (string namespace)
    {
      MultiStatus::add_namespace (namespace);
    }

    //!
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
protected class PropertySet
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
  //! Fail if the destination exists. Corresponds to an Overwrite
  //! header with the value "F" (RFC 2518 9.6).
  NEVER_OVERWRITE = -1,

  //! If the source and destination are directories, overwrite the
  //! properties only. If the source and destination are files,
  //! overwrite the file along with the properties. Otherwise fail if
  //! the destination exists.
  MAYBE_OVERWRITE = 0,

  //! If the destination exists then delete it recursively before
  //! writing the new content. Corresponds to an Overwrite header with
  //! the value "T" (RFC 2518 9.6).
  DO_OVERWRITE = 1,
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

//! @appears RoxenModule
//! The Roxen module interface.
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

  void start (void|int variable_save, void|Configuration conf,
	      void|int newly_added);
  //! This function is called both when a module is loaded
  //! (@[variable_save] is 0) and when its variables are saved after a
  //! change (@[variable_save] is 2).
  //!
  //! @[newly_added] is 1 if the module is being added by the
  //! administrator through the admin interface (implies that
  //! @[variable_save] is 0). It's zero if the module is loaded
  //! normally, i.e. as a result of an entry in the server
  //! configuration file.
  //!
  //! @[conf] is the configuration that the module instance belongs
  //! to, i.e. the same as the return value from @[my_configuration].
  //!
  //! @note
  //! A module can't assume that it has been loaded before in this
  //! server configuration just because @[newly_added] is zero. The
  //! administrator might for instance have edited the configuration
  //! file directly.

  void stop (void|RoxenModule new_instance);
  //! This function is called when a running module is stopped either
  //! because it's being dropped or reloaded in the admin interface,
  //! or the server is being shut down orderly.
  //!
  //! If the module is being stopped because of a reload then
  //! @[new_instance] is the new module instance that is replacing
  //! this one. Note that @[new_instance] is not properly initialized
  //! at this stage; among other things its @[start] function has not
  //! yet been run.

  void ready_to_receive_requests (void|Configuration conf);
  //! This function is called after all modules in a configuration
  //! have been loaded and @[start]ed. If a function is added later on
  //! it's called directly after @[start].
  //!
  //! When a configuration is loaded on server start, this function is
  //! still called before the handler threads are started.
  //!
  //! @[conf] is the configuration that the module instance belongs
  //! to, i.e. the same as the return value from @[my_configuration].
  //!
  //! @note
  //! This function is intended for things that can't be done in
  //! @[start] because all modules might not be loaded by then, e.g.
  //! for starting crawlers. There is no well defined order between
  //! calls to @[ready_to_receive_requests], so its usefulness
  //! diminishes the more modules that use it. In other words, don't
  //! use unless you absolutely have to.
  //!
  //! Calls to @[module_dependencies] with the third @expr{now@}
  //! argument set is a better way to sequence module startups, but
  //! that requires that the depended modules don't (ab)use
  //! @[ready_to_receive_requests].

  string query_internal_location();
  string query_location();
  string|multiset(string) query_provides();
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
  mapping(string:mixed) recurse_find_properties(string path, string mode, int depth,
						RequestID id,
						multiset(string)|void filt);
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

protected mapping(string:function(void:void)) user_sql_inited = ([]);
protected Sql.Sql user_mysql;
protected void init_user_sql(string table)
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
protected Thread.Mutex mutex = Thread.Mutex();
#endif

//! @appears User
class User( UserDB database )
{
  protected string table;

  string name();
  //! The user (short) name

  string real_name();
  //! The real name of the user

  int password_authenticate(string password)
  //! Return 1 if the password is correct, 0 otherwise. The default
  //! implementation uses the crypted_password() method.
  {
    string c = crypted_password();
    return !sizeof(c) || verify_password(password, c);
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

  protected string module_name( RoxenModule module )
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

