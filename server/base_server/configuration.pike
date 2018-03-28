// This file is part of Roxen WebServer.
// Copyright © 1996 - 2009, Roxen IS.
//

// @appears Configuration
//! A site's main configuration

constant cvs_version = "$Id$";
#include <module.h>
#include <module_constants.h>
#include <roxen.h>
#include <request_trace.h>
#include <timers.h>

#define CATCH(P,X) do{mixed e;if(e=catch{X;})report_error("While "+P+"\n"+describe_backtrace(e));}while(0)

// Tell Pike.count_memory this is global.
constant pike_cycle_depth = 0;

// --- Locale defines ---
//<locale-token project="roxen_start">   LOC_S  </locale-token>
//<locale-token project="roxen_config">  LOC_C  </locale-token>
//<locale-token project="roxen_message"> LOC_M  </locale-token>
//<locale-token project="roxen_config"> DLOCALE </locale-token>
#define LOC_S(X,Y)  _STR_LOCALE("roxen_start",X,Y)
#define LOC_C(X,Y)  _STR_LOCALE("roxen_config",X,Y)
#define LOC_M(X,Y)  _STR_LOCALE("roxen_message",X,Y)
#define DLOCALE(X,Y) _DEF_LOCALE("roxen_config",X,Y)

#ifdef THROTTLING_DEBUG
#undef THROTTLING_DEBUG
#define THROTTLING_DEBUG(X) report_debug("Throttling: "+X+"\n")
#else
#define THROTTLING_DEBUG(X)
#endif

#ifdef REQUEST_DEBUG
# define REQUEST_WERR(X) report_debug("CONFIG: "+X+"\n")
#else
# define REQUEST_WERR(X)
#endif


#ifdef AVERAGE_PROFILING

#if !constant(gethrvtime)
#define gethrvtime()	gethrtime()
#endif /* !constant(gethrvtime) */

class ProfStack
{
  array current_stack = ({});

  void enter( string k, RequestID id )
  {
    current_stack += ({ ({ k, gethrtime(), gethrvtime() }) });
  }
  
  void leave( string k, RequestID id )
  {
    int t0 = gethrtime();
    int t1 = gethrvtime();

    if( !sizeof(current_stack ) )
    {
//       report_error("Popping out of profiling stack\n");
      return;
    }
      
    int i = sizeof( current_stack )-1;
    while( current_stack[ i ][0] != k && i >= 0 ) i--;

    if(i < 0 )
    {
      return;
    }
    void low_leave( int i )
    {
      int tt = t0-current_stack[i][1];
      int ttv = t1-current_stack[i][2];

      if( i > 0 ) // Do not count child time in parent.
      {
	current_stack[i-1][1]+=tt+gethrtime()-t0;
	current_stack[i-1][2]+=ttv+gethrvtime()-t1;
      }
      current_stack = current_stack[..i-1];
      add_prof_entry( id, k, tt, ttv );
    };

    if( i != sizeof( current_stack )-1 )
    {
      for( int j = sizeof( current_stack )-1; j>=i; j-- )
	low_leave( j );
      return;
    }
    low_leave( i );
  }
}

class ProfInfo( string url )
{
  mapping data = ([]);
  void add( string k, int h, int hrv )
  {
    if( !data[k] )
      data[k] = ({ h, hrv, 1 });
    else
    {
      data[k][0]+=h;
      data[k][1]+=hrv;
      data[k][2]++;
    }
  }

  array summarize_table( )
  {
    array table = ({});
    int n, t, v;
    foreach( indices( data ), string k  )
      table += ({ ({ k,
		     sprintf( "%d", (n=data[k][2]) ),
		     sprintf("%5.2f",(t=data[k][0])/1000000.0),
		     sprintf("%5.2f", (v=data[k][1])/1000000.0),
		     sprintf("%8.2f", t/n/1000.0),
		     sprintf("%8.2f",v/n/1000.0), }) });
    sort( (array(float))column(table,2), table );
    return reverse(table);
  }

  void dump( )
  {
    write( "\n"+url+": \n" );
    ADT.Table.table t = ADT.Table.table( summarize_table(),
					 ({ "What", "Calls",
					    "Time", "CPU",
					    "t/call(ms)", "cpu/call(ms)" }));

    write( ADT.Table.ASCII.encode( t )+"\n" );

  }
}

mapping profiling_info = ([]);

void debug_write_prof( )
{
  foreach( sort( indices( profiling_info ) ), string p )
    profiling_info[p]->dump();
}

void add_prof_entry( RequestID id, string k, int hr, int hrv )
{
  string l = id->not_query;
//   if( has_prefix( k, "find_internal" ) ) l = dirname(l);
  if( has_prefix( l, query_internal_location() ) )
    l = dirname( l ); // enough, really. 

  if( !profiling_info[l] )
    profiling_info[l] = ProfInfo(l);

  profiling_info[l]->add( k, hr, hrv );
}

void avg_prof_enter( string name, string type, RequestID id )
{
  if( !id->misc->prof_stack )
    id->misc->prof_stack = ProfStack();
  id->misc->prof_stack->enter( name+":"+type,id );
}
void avg_prof_leave( string name, string type, RequestID id )
{
  if( !id->misc->prof_stack ) id->misc->prof_stack = ProfStack();
  id->misc->prof_stack->leave( name+":"+type,id );
}
#endif


/* A configuration.. */
inherit Configuration;
inherit "basic_defvar";

protected mapping(RequestID:mapping) current_connections =
  set_weak_flag( ([ ]), 1 );

void connection_add( RequestID id, mapping data )
//! Add a connection. The data mapping can contain things such as
//! currently sent bytes.
//!
//! See protocols/http.pike and slowpipe.pike for more information.
//!
//! You are not in any way forced to use this method from your
//! protocol module. The information is only used for debug purposes
//! in the configuration interface.
//!
//! You have to keep a reference to the mapping on your own, none is
//! kept by the configuration object.
{
  current_connections[id] = data;
}

mapping connection_drop( RequestID id )
//! Remove a connection from the list of currently active connections.
//! Returns the mapping previously added with connection_add, if any.
{
  return m_delete( current_connections, id );
}

mapping(RequestID:mapping) connection_get( )
//! Return all currently active connections.
{
  return current_connections;
}

// It's nice to have the name when the rest of __INIT executes.
string name = roxen->bootstrap_info->get();

//! The hierarchal cache used for the HTTP protocol cache.
class DataCache
{
  protected typedef array(string|mapping(string:mixed))|string|
		    function(string, RequestID:string|int) EntryType;

  mapping(string:EntryType) cache = ([]);

  int current_size;
  int max_size;
  int max_file_size;

  int hits, misses;

  void flush()
  {
#ifndef RAM_CACHE_NO_RELOAD_FLUSH
    current_size = 0;
    cache = ([]);
#endif
  }

  // Heuristic to calculate the entry size. Besides the data itself,
  // we add the size of the key. Even though it's a shared string we
  // can pretty much assume it has no other permanent refs. 128 is a
  // constant penalty that accounts for the keypair in the mapping and
  // that leaf entries are stored in arrays.
#define CALC_ENTRY_SIZE(key, data) (sizeof (data) + sizeof (key) + 128)

  // Expire a single entry.
  protected void really_low_expire_entry(string key)
  {
    EntryType e = m_delete(cache, key);
    if (arrayp(e)) {
      current_size -= CALC_ENTRY_SIZE (key, e[0]);
      if (e[1]->co_handle) {
	remove_call_out(e[1]->co_handle);
      }
      if (CacheKey cachekey = e[1]->key) {
	destruct (cachekey);
      }
    }
  }

  // NOTE: Avoid using this function if possible! O(n)
  protected int low_expire_entry(string key_prefix)
  {
    if (!key_prefix) return 0;
    if (arrayp(cache[key_prefix])) {
      // Leaf node. No need to loop.
      really_low_expire_entry(key_prefix);
      return 1;
    }
    // Inner node. Find all its children.
    int res = 0;
    foreach(indices(cache); int ind; string key) {
      if (!key) continue;
      if (has_prefix(key, key_prefix)) {
	really_low_expire_entry(key);
	res++;
      }
    }
    return res;
  }

  void expire_entry(string key_prefix, RequestID|void id)
  {
    if (!id) {
      low_expire_entry(key_prefix);
      return;
    }
    string url = key_prefix;
    sscanf(url, "%[^\0]", url);
    while(1) {
      EntryType val;
      if (arrayp(val = cache[key_prefix])) {
	current_size -= CALC_ENTRY_SIZE (key_prefix, val[0]);
	m_delete(cache, key_prefix);
	return;
      }
      if (!val) {
	return;
      }

      string|array(string) key_frag;
      if (stringp(val)) {
	key_frag = id->request_headers[val];
      } else {
	key_frag = val(url, id);
      }
      if (key_frag)
	// Avoid spoofing if key_frag happens to contain "\0\0".
	key_frag = replace (key_frag, "\0", "\0\1");
      else key_frag = "";
      key_prefix += "\0\0" + key_frag;
    }
  }

  //! Clear ~1/10th of the cache.
  protected void clear_some_cache()
  {
    // FIXME: Use an iterator to avoid indices() here.
    array(string) q = indices(cache);
    if(!sizeof(q))
    {
      current_size=0;
      return;
    }

    // The following code should be ~O(n * log(n)).
    sort(q);
    for(int i = 0; i < sizeof(q)/10; i++) {
      int r = random(sizeof(q));
      string key_prefix = q[r = random(sizeof(q))];
      if (!key_prefix) continue;
      for(;r < sizeof(q); r++,i++) {
	if (!q[r]) continue;
	if (!has_prefix(q[r], key_prefix)) break;
	really_low_expire_entry(q[r]);
	q[r] = 0;
      }
    }
  }

  void set(string url, string data, mapping meta, int expire, RequestID id)
  {
    int entry_size = CALC_ENTRY_SIZE (url, data);

    if( entry_size > max_file_size ) {
      // NOTE: There's a possibility of a stale entry remaining in the
      //       cache until it expires, rather than being replaced here.
      SIMPLE_TRACE_ENTER (this, "Result of size %d is too large "
			  "to store in the protocol cache (limit %d)",
			  entry_size, max_file_size);
      SIMPLE_TRACE_LEAVE ("");
      return;
    }

    SIMPLE_TRACE_ENTER (this, "Storing result of size %d in the protocol cache "
			"using key %O (expire in %ds)",
			entry_size, url, expire);
    string key = url;

    foreach(id->misc->vary_cb_order || ({}),
	    string|function(string, RequestID: string|int) vary_cb) {
      array(string|mapping(string:mixed))|string|
	function(string, RequestID:string|int) old = cache[key];
      if (old && (old != vary_cb)) {
	SIMPLE_TRACE_ENTER (this, "Registering vary cb %O - conflicts with "
			    "existing entry %s, old entry expired",
			    vary_cb,
			    (arrayp (old) ? "of size " + sizeof (old[0]) :
			     sprintf ("%O", old)));
	low_expire_entry(key);
	SIMPLE_TRACE_LEAVE ("");
      }
      cache[key] = vary_cb;

      SIMPLE_TRACE_ENTER (this, "Registering vary cb %O", vary_cb);

      string key_frag;
      if (stringp(vary_cb)) {
	string|array(string) header = id->request_headers[vary_cb];
	if (arrayp(header)) key_frag = header * ",";
	else key_frag = header;
      } else {
	int|string frag = vary_cb(url, id);
	if (intp(frag) && frag) {
	  key_frag = frag->digits(256);
	} else {
	  key_frag = frag;
	}
      }

      SIMPLE_TRACE_LEAVE ("Vary cb resolved to key fragment %O",
			  key_frag || "");

      if (key_frag)
	// Avoid spoofing if key_frag happens to contain "\0\0".
	key_frag = replace (key_frag, "\0", "\0\1");
      else key_frag = "";
      key += "\0\0" + key_frag;
    }

    array(string|mapping(string:mixed))|string|
      function(string, RequestID:string) old = cache[key];
    if (old) {
      SIMPLE_TRACE_LEAVE ("Entry conflicts with existing entry %s, "
			  "old entry expired",
			  (arrayp (old) ? "of size " + sizeof (old[0]) :
			   sprintf ("%O", old)));
      low_expire_entry(key);
    }
    else
      SIMPLE_TRACE_LEAVE ("");

    current_size += entry_size;
    cache[key] = ({ data, meta });

    // Only the actual cache entry is expired.
    // FIXME: This could lead to lots and lots of call outs.. :P
    meta->co_handle = call_out(really_low_expire_entry, expire, key);
    int n;
    while( (current_size > max_size) && (n++<10))
      clear_some_cache();
  }
  
  array(string|mapping(string:mixed)) get(string url, RequestID id)
  {
    SIMPLE_TRACE_ENTER (this, "Looking up entry for %O in the protocol cache",
			url);

    array(string|mapping(string:mixed))|string|
      function(string, RequestID:string|int) res;
    string key = url;
    while(1) {
      id->misc->protcache_cost++;
      if (arrayp(res = cache[key])) {
	hits++;
	SIMPLE_TRACE_LEAVE ("Found entry of size %d", sizeof (res[0]));
	return [array(string|mapping(string:mixed))]res;
      }
      if (!res) {
	misses++;
	SIMPLE_TRACE_LEAVE ("Found no entry");
	return UNDEFINED;
      }

      SIMPLE_TRACE_ENTER (this, "Found vary cb %O", res);

      string key_frag;
      if (stringp(res)) {
	string|array(string) header = id->request_headers[res];
	if (arrayp(header)) key_frag = header * ",";
	else key_frag = header;
      } else {
	int|string frag = res(url, id);
	if (intp(frag) && frag) {
	  key_frag = frag->digits(256);
	} else {
	  key_frag = frag;
	}
      }

      SIMPLE_TRACE_LEAVE ("Vary cb resolved to key fragment %O",
			  key_frag || "");

      if (key_frag)
	// Avoid spoofing if key_frag happens to contain "\0\0".
	key_frag = replace (key_frag, "\0", "\0\1");
      else key_frag = "";
      key += "\0\0" + key_frag;
    };
  }

  void init_from_variables( )
  {
    max_size = query( "data_cache_size" ) * 1024;
    max_file_size = query( "data_cache_file_max_size" ) * 1024;
    if( max_size < max_file_size )
      max_size += max_file_size;
    int n;
    while( (current_size > max_size) && (n++<10))
      clear_some_cache();
  }

  protected void create()
  {
    init_from_variables();
  }
}

#include "rxml.pike";
constant    store = roxen.store;
constant    retrieve = roxen.retrieve;
constant    remove = roxen.remove;

int config_id;
int get_config_id() 
{
  if(config_id) return config_id;
  for(int i=sizeof(roxen->configurations); i;)
    if(roxen->configurations[--i]->name==name) return config_id=i;
}

string get_doc_for( string region, string variable )
{
  RoxenModule module;
  if(variable[0] == '_')
    return 0;
  if((int)reverse(region))
    return 0;
  if(module = find_module( region ))
  {
    if(module->variables[variable])
      return module->variables[variable]->name()+
        "\n"+module->variables[ variable ]->doc();
  }
  if(variables[ variable ])
    return variables[variable]->name()+
      "\n"+variables[ variable ]->doc();
}

string query_internal_location(RoxenModule|void mod)
{
  return internal_location+(mod?replace(otomod[mod]||"", "#", "!")+"/":"");
}

string query_name()
{
  if(strlen(query("name")))
    return query("name");
  return name;
}

string comment()
{
  return query("comment");
}

private float cached_compat_level;

float compat_level()
{
  if (cached_compat_level == 0.0)
    cached_compat_level = (float) query ("compat_level");
  return cached_compat_level;
}

/* A 'pri' is one of the ten priority objects. Each one holds a list
 * of modules for that priority. They are all merged into one list for
 * performance reasons later on.
 */

array (Priority) allocate_pris()
{
  return allocate(10, Priority)();
}

array(int) query_oid()
{
  return SNMP.RIS_OID_WEBSERVER + ({ 2 });
}

//! @returns
//!   Returns an array with two elements:
//!   @array
//!     @elem array(int) oid
//!
//!     @elem array(int) oid_suffix
//!   @endarray
array(int) generate_module_oid_segment(RoxenModule me)
{
  string s = otomod[me];
  array(string) a = s/"#";
  return ({ sizeof(a[0]), @((array(int))a[0]), ((int)a[1]) + 1 });
}

ADT.Trie generate_module_mib(array(int) oid,
			     array(int) oid_suffix,
			     RoxenModule me,
			     ModuleInfo moduleinfo,
			     ModuleCopies module)
{
  array(int) segment = generate_module_oid_segment(me);
  return SNMP.SimpleMIB(oid,
			oid_suffix + segment,
			({
			  UNDEFINED,
			  SNMP.Integer(segment[-1], "moduleCopy"),
			  SNMP.String(otomod[me],
				      "moduleIdentifier"),
			  SNMP.Integer(moduleinfo->type,
				       "moduleType"),
			  SNMP.String(me->cvs_version || "",
				      "moduleVersion"),
			}));
}

// Cache some configuration variables.
private int sub_req_limit = 30;
private string internal_location = "/_internal/";

#ifdef HTTP_COMPRESSION
int(0..1) http_compr_enabled;
mapping(string:int) http_compr_main_mimes = ([]);
mapping(string:int) http_compr_exact_mimes = ([]);
int http_compr_minlen;
int http_compr_maxlen;
int(0..1) http_compr_dynamic_reqs;
Thread.Local gz_file_pool = Thread.Local();
#endif

int handler_queue_timeout;

// The logging format used. This will probably move to the above
// mentioned module in the future.
private mapping (int|string:string) log_format = ([]);

// A list of priority objects
array (Priority) pri = allocate_pris();

mapping modules = ([]);
//! All enabled modules in this site.
//! The format is "module":{ "copies":([ num:instance, ... ]) }

mapping (RoxenModule:string) otomod = ([]);
//! A mapping from the module objects to module names

int module_set_counter = 1;
//! Incremented whenever the set of enabled modules changes, or if a
//! module is reloaded.

mapping(string:int) counters = ([]);

// Caches to speed up the handling of the module search.
// They are all sorted in priority order, and created by the functions
// below.
private array (function) url_module_cache, last_module_cache;
private array (function) logger_module_cache, first_module_cache;
private array (function) filter_module_cache;
private array (array (string|function)) location_module_cache;
private mapping (string:array (function)) file_extension_module_cache=([]);
private mapping (string:array (RoxenModule)) provider_module_cache=([]);
private array (RoxenModule) auth_module_cache, userdb_module_cache;


void unregister_urls()
{
  foreach( registered_urls + failed_urls, string url )
    roxen.unregister_url(url, this_object());
  registered_urls = ({});
}

private void safe_stop_module (RoxenModule mod, string desc)
{
  if (mixed err = catch (mod && mod->stop &&
			 call_module_func_with_cbs (mod, "stop", 0)))
    report_error ("While stopping " + desc + ": " + describe_backtrace (err));
}

private Thread.Mutex stop_all_modules_mutex = Thread.Mutex();

private void do_stop_all_modules (Thread.MutexKey stop_lock)
{
  mapping(RoxenModule:string) allmods = otomod + ([]);

  if (types_module) {
    safe_stop_module (types_module, "type module");
    m_delete (allmods, types_module);
  }

  if (dir_module) {
    safe_stop_module (dir_module, "directory module");
    m_delete (allmods, dir_module);
  }

  for(int i=0; i<10; i++)
    if (Priority p = pri[i]) {
#define STOP_MODULES(MODS, DESC)					\
      foreach(MODS, RoxenModule m)					\
        if (allmods[m]) {						\
	  safe_stop_module (m, DESC);					\
	  m_delete (allmods, m);					\
	}
      STOP_MODULES (p->url_modules, "url module");
      STOP_MODULES (p->logger_modules, "logging module");
      STOP_MODULES (p->filter_modules, "filter module");
      STOP_MODULES (p->location_modules, "location module");
      STOP_MODULES (p->last_modules, "last module");
      STOP_MODULES (p->first_modules, "first module");
      STOP_MODULES (indices (p->provider_modules), "provider module");
    }

  if (mixed err = catch {
    if (object m = log_function && function_object (log_function)) {
      destruct (m);
      allmods[m] = 0;
    }
  }) report_error ("While stopping the logger: " + describe_backtrace (err));

  STOP_MODULES(indices (allmods), "unclassified module");
#undef STOP_MODULES

  destruct (stop_lock);
}

void stop (void|int asynch)
//! Unregisters the urls and calls stop in all modules. Uses a handler
//! thread to lessen the impact if a module hangs. Doesn't wait for
//! all modules to finish if @[asynch] is nonzero.
{
  if (Thread.MutexKey lock = stop_all_modules_mutex->trylock()) {
#ifdef SNMP_AGENT
    if(query("snmp_process") && objectp(roxen->snmpagent)) {
      roxen->snmpagent->vs_stop_trap(get_config_id());
      roxen->snmpagent->del_virtserv(get_config_id());
    }
#endif

    unregister_urls();

    if (roxen.handler_threads_on_hold())
      // Run do_stop_all_modules synchronously if there are no handler
      // threads running (typically during the RoxenTest_help self test).
      do_stop_all_modules (lock);
    else
      // Seems meaningless to queue this in a handler thread and then
      // just wait for it below if asynch isn't set - could just as
      // well do the work in this thread then. But now isn't a good
      // moment to mess around with it. /mast
      roxen.handle (do_stop_all_modules, lock);
  }

  if (!asynch) stop_all_modules_mutex->lock (1);
}

string|array(string) type_from_filename( string file, int|void to,
					 string|void myext )
{
  array(string)|string tmp;
  if(!types_fun)
    return to?({ "application/octet-stream", 0 }):"application/octet-stream";

  string ext = lower_case(myext || Roxen.extension(file));

  if(tmp = types_fun(ext))
  {
    // FIXME: Ought to support several levels of "strip".
    if (tmp[0] == "strip")
    {
      array(string) tmp2 = file/".";
      string nx;
      if (sizeof(tmp2) > 2)
	nx = lower_case(tmp2[-2]);
      tmp[0] = (nx && types_fun(nx)) || types_fun("default") ||
	"application/octet-stream";
    }
  } else if (!(tmp = types_fun("default"))) {
    tmp = ({ "application/octet-stream", 0 });
  }
  return to?tmp:tmp[0];
}

array (RoxenModule) get_providers(string provides)
//! Returns an array with all provider modules that provides "provides".
{
  // This cache is cleared in the invalidate_cache() call.
  if(!provider_module_cache[provides])
  {
    int i;
    provider_module_cache[provides]  = ({ });
    for(i = 9; i >= 0; i--)
    {
      array(RoxenModule) modules = indices(pri[i]->provider_modules);
      array(string) module_identifiers = modules->module_identifier();
      sort(module_identifiers, modules);
      foreach(modules, RoxenModule d)
	if(pri[i]->provider_modules[ d ][ provides ])
	  provider_module_cache[provides] += ({ d });
    }
  }
  return provider_module_cache[provides];
}

RoxenModule get_provider(string provides)
//! Returns the first provider module that provides "provides".
{
  array (RoxenModule) prov = get_providers(provides);
  if(sizeof(prov))
    return prov[0];
  return 0;
}

array(mixed) map_providers(string provides, string fun, mixed ... args)
//! Maps the function "fun" over all matching provider modules.
{
  array (RoxenModule) prov = get_providers(provides);
  mixed error;
  array a=({ });
  mixed m;
  foreach(prov, RoxenModule mod)
  {
    if(!objectp(mod))
      continue;
    if(functionp(mod[fun]))
      error = catch(m=mod[fun](@args));
    if(error) {
      report_debug("Error in map_providers(): " + describe_backtrace(error));
    }
    else
      a += ({ m });
    error = 0;
  }
  return a;
}

mixed call_provider(string provides, string fun, mixed ... args)
//! Maps the function "fun" over all matching provider modules and
//! returns the first positive response.
{
  foreach(get_providers(provides), RoxenModule mod)
  {
    function f;
    if(objectp(mod) && functionp(f = mod[fun])) {
      mixed ret;
      if (ret = f(@args)) {
	return ret;
      }
    }
  }
}

array (function) file_extension_modules(string ext)
{
  if(!file_extension_module_cache[ext = lower_case(ext)])
  {
    int i;
    file_extension_module_cache[ext]  = ({ });
    for(i=9; i>=0; i--)
    {
      array(RoxenModule) d;
      RoxenModule p;
      if(d = pri[i]->file_extension_modules[ext])
	foreach(d, p)
	  file_extension_module_cache[ext] += ({ p->handle_file_extension });
    }
  }
  return file_extension_module_cache[ext];
}

array (function) url_modules()
{
  if(!url_module_cache)
  {
    int i;
    url_module_cache=({ });
    for(i=9; i>=0; i--)
    {
      array(RoxenModule) d;
      RoxenModule p;
      if(d=pri[i]->url_modules)
	foreach(d, p)
	  url_module_cache += ({ p->remap_url });
    }
  }
  return url_module_cache;
}

protected mapping api_module_cache = ([]);
mapping api_functions(void|RequestID id)
{
  return api_module_cache+([]);
}

array (function) logger_modules()
{
  if(!logger_module_cache)
  {
    int i;
    logger_module_cache=({ });
    for(i=9; i>=0; i--)
    {
      array(RoxenModule) d;
      RoxenModule p;
      if(d=pri[i]->logger_modules)
	foreach(d, p)
	  if(p->log)
	    logger_module_cache += ({ p->log });
    }
  }
  return logger_module_cache;
}

array (function) last_modules()
{
  if(!last_module_cache)
  {
    int i;
    last_module_cache=({ });
    for(i=9; i>=0; i--)
    {
      array(RoxenModule) d;
      RoxenModule p;
      if(d=pri[i]->last_modules)
	foreach(d, p)
	  if(p->last_resort)
	    last_module_cache += ({ p->last_resort });
    }
  }
  return last_module_cache;
}

protected mixed strip_fork_information(RequestID id)
{
  if (uname()->sysname == "Darwin") {
    //  Look for Mac OS X special filenames that are used access files in
    //  magic ways:
    //
    //    foo.txt/..namedfork/data     (same as foo.txt)
    //    foo.txt/..namedfork/rsrc     (resource fork of foo.txt)
    //    foo.txt/rsrc                 (resource fork of foo.txt)
    //    .DS_Store                    (Finder info file with catalog data)
    if (has_value(id->not_query, "..namedfork/") ||
	has_suffix(id->not_query, "/rsrc") ||
	has_value(lower_case(id->not_query), ".ds_store"))
      //  Skip elaborate error page since we get these e.g. for WebDAV
      //  mounts in OS X Finder.
      return Roxen.http_string_answer("No such file", "text/plain");
  }
  
  array a = id->not_query/"::";
  //  FIX: Must not subtract ":" chars since it breaks proper URL:s,
  //  e.g. "/internal-roxen-colorbar:x,y,z" and several others.
  //  id->not_query = a[0]-":";
  id->not_query = a[0];
  id->misc->fork_information = a[1..];
  return 0;
}

array (function) first_modules()
{
  if(!first_module_cache)
  {
    int i;
    first_module_cache = ({ });
    
    //  Add special fork handlers on Windows and Mac OS X
    if (
#ifdef __NT__
	1 ||
#endif
	uname()->sysname == "Darwin") {
      first_module_cache= ({
	strip_fork_information,	// Always first!
      });
    }
    
    for(i=9; i>=0; i--)
    {
      array(RoxenModule) d; RoxenModule p;
      if(d=pri[i]->first_modules) {
	foreach(d, p) {
	  if(p->first_try) {
	    first_module_cache += ({ p->first_try });
	  }
	}
      }
    }
  }

  return first_module_cache;
}

void set_userdb_module_cache( array to )
// Used by the config_filesystem.pike module to enforce the usage of
// the config userdb module, for now.
{
  userdb_module_cache = to;	
}

array(UserDB) user_databases()
{
  if( userdb_module_cache )
    return userdb_module_cache;
  array tmp = ({});
  foreach( values( modules ), mapping m )
    foreach( values(m->copies), RoxenModule mo )
      if( mo->module_type & MODULE_USERDB )
	tmp += ({ ({ mo->query( "_priority" ), mo }) });

  sort( tmp );
//   tmp += ({ ({ 0, roxen->config_userdb_module }) });
  return userdb_module_cache = reverse(column(tmp,1));
}

array(AuthModule) auth_modules()
{
  if( auth_module_cache )
    return auth_module_cache;
  array tmp = ({});
  foreach( values( modules ), mapping m )
    foreach( values(m->copies), RoxenModule mo )
      if( mo->module_type & MODULE_AUTH )
	tmp += ({ ({ mo->query( "_priority" ), mo }) });
  sort( tmp );
  return auth_module_cache = reverse(column(tmp,1));
}

array location_modules()
//! Return an array of all location modules the request should be
//! mapped through, by order of priority.
{
  if(!location_module_cache)
  {
    int i;
    array new_location_module_cache=({ });
    for(i=9; i>=0; i--)
    {
      array(RoxenModule) d;
      RoxenModule p;
      if(d=pri[i]->location_modules) {
	array level_find_files = ({});
	array level_locations = ({});
	foreach(d, p) {
	  string location;
	  // FIXME: Should there be a catch() here?
	  if(p->find_file && (location = p->query_location())) {
	    level_find_files += ({ p->find_file });
	    level_locations += ({ location });
	  }
	}
	sort(map(level_locations, sizeof), level_locations, level_find_files);
	int j;
	for (j = sizeof(level_locations); j--;) {
	  // Order after longest path first.
	  new_location_module_cache += ({ ({ level_locations[j],
					     level_find_files[j] }) });
	}
      }
    }
    location_module_cache = new_location_module_cache;
  }
  return location_module_cache;
}

array(function) filter_modules()
{
  if(!filter_module_cache)
  {
    int i;
    filter_module_cache=({ });
    for(i=9; i>=0; i--)
    {
      array(RoxenModule) d;
      RoxenModule p;
      if(d=pri[i]->filter_modules)
	foreach(d, p)
	  if(p->filter)
	    filter_module_cache+=({ p->filter });
    }
  }
  return filter_module_cache;
}


void init_log_file()
{
  if(log_function)
  {
    // Free the old one.
    destruct(function_object(log_function));
    log_function = 0;
  }
  // Only try to open the log file if logging is enabled!!
  if(query("Log"))
  {
    string logfile = query("LogFile");
    if(strlen(logfile))
      log_function = roxen.LogFile(logfile, query("LogFileCompressor"))->write;
  }
}

private void parse_log_formats()
{
  array foo=query("LogFormat")/"\n";
  log_format = ([]);
  foreach(foo; int i; string b)
    if(strlen(b) && b[0] != '#') {
      if (sscanf (b, "%d:%*[\t ]%s", int status, b))
	log_format[status] = b;
      else if (sscanf (b, "*:%*[\t ]%s", b))
	log_format[0] = b;
      else if (sscanf (b, "%[-_.#a-zA-Z0-9*]/%[-_.#a-zA-Z0-9*]:%*[\t ]%s",
		       string facility, string action, b) >= 2)
	log_format[facility + "/" + action] = b;
      else
	// Ought to be an error when the variable is set, but that's
	// not entirely backward compatible.
	report_warning ("Unrecognized format on line %d "
			"in log format setting: %O\n", i + 1, b);
    }
}

void log(mapping file, RequestID request_id)
{
  // Call all logging functions
  array(function) log_funs = logger_module_cache||logger_modules();
  if (sizeof(log_funs)) {
    request_id->init_cookies(1);
    foreach(log_funs, function f)
      if( f( request_id, file ) )
	return;
  }

  if( !log_function ) 
    return; // No file is open for logging.

  if(do_not_log_patterns && 
     Roxen._match(request_id->remoteaddr, do_not_log_patterns))
    return;

  string form;
  if(!(form=log_format[(int) file->error]))
    form = log_format[0];
  if(!form) return;

  roxen.run_log_format( form, log_function, request_id, file );
}

void log_event (string facility, string action, string resource,
		void|mapping(string:mixed) info)
//! Log an event.
//!
//! This function is primarily intended for logging arbitrary internal
//! events for performance monitoring purposes. The events are sent to
//! the access log, where they typically are formatted in a CommonLog
//! lookalike format.
//!
//! The intention is to extend this function to be able to collect
//! statistics of these events for polling by e.g. SNMP.
//!
//! @param facility
//!   An identifier for the module or subsystem that the event comes
//!   from. This defaults to the module identifier returned by
//!   @[RoxenModule.module_local_id] when the @[RoxenModule.log_event]
//!   wrapper is used. It should be unique within the configuration.
//!   Valid characters are @expr{[-_.#a-zA-Z0-9]@} but the first
//!   character has to be alphanumeric.
//!
//! @param action
//!   An identifier for the specific event within the facility. Should
//!   be enumerable. Valid characters are @expr{[-_.#a-zA-Z0-9]@}.
//!
//! @param resource
//!   Identifies the resource that the event acts on. Pass zero if a
//!   resource isn't applicable.
//!
//!   If applicable, this is the path within the virtual file system
//!   of the module, beginning with a "@expr{/@}".
//!
//!   Otherwise it is some other string, not beginning with
//!   "@expr{/@}", that has a format suitable for describing the
//!   resource handled by the facility, e.g. "@expr{pclass:17@}".
//!
//!   This string should preferably contain URI valid chars only, but
//!   other chars are allowed and will be encoded if necessary.
//!
//! @param info
//!   An optional mapping containing arbitrary info about the event.
//!   The entries here can be accessed as @expr{$@} format specifiers
//!   in the @expr{LogFormat@} configuration variable.
//!
//!   The values must be castable to strings. The strings should
//!   preferably contain URI valid chars only, but other chars are
//!   allowed and will be encoded if necessary.
//!
//!   The strings should preferably never be empty. If a string might
//!   be, it should be documented in the doc blurb for the
//!   @expr{LogFormat@} configuration variable.
//!
//!   Most but not all of the predefined format specifiers can be
//!   overridden this way, but if any is overridden it should map very
//!   closely to the syntax and semantics of the original.
//!
//!   Note that "@expr{_@}" cannot be used in names in the indices
//!   here since the log formatter code replaces "@expr{_@}" with
//!   "@expr{-@}" before doing lookups.
//!
//! @note
//! Events should be documented in the doc blurb for the
//! @expr{LogFormat@} configuration variable.
{
  // Currently this bypasses logger modules. Might change in the future.

  if( !log_function ) 
    return; // No file is open for logging.

  if(do_not_log_patterns &&
     Roxen._match("0.0.0.0", do_not_log_patterns))
    return;

  sscanf (facility, "%[^#]", string modname);

  if (string format =
      log_format[facility + "/" + action] ||
      log_format[facility + "/*"] ||
      // Also try without the module copy number if the facility
      // appears to be a module identifier.
      modname != "" && (log_format[modname + "/" + action] ||
			log_format[modname + "/*"]) ||
      log_format["*/*"])
    roxen.run_log_event_format (format, log_function,
				facility, action, resource || "-", info);
}

array(string) userinfo(string u, RequestID|void id)
//! @note
//!   DEPRECATED COMPATIBILITY FUNCTION
//! 
//! Fetches user information from the authentication module by calling
//! its userinfo() method. Returns zero if no auth module was present.
//!
//! Note that you should always supply id if it's possible, some user
//! databases require it (such as the htaccess database)
{
  User uid;
  foreach( user_databases(), UserDB m )
    if( uid = m->find_user( u ) )
      return uid->compat_userinfo();
}

array(string) userlist(RequestID|void id)
//! @note
//!   DEPRECATED COMPATIBILITY FUNCTION
//! 
//! Fetches the full list of valid usernames from the authentication
//! module by calling its userlist() method. Returns zero if no auth
//! module was present.
//!
//! Note that you should always supply id if it's possible, some user
//! databases require it (such as the htaccess database)
{
  array(string) list = ({});
  foreach( user_databases(), UserDB m )
    list |= m->list_users(id);
  return list;
}

array(string) user_from_uid(int u, RequestID|void id)
//! @note
//!   DEPRECATED COMPATIBILITY FUNCTION
//! 
//! Return the user data for id u from the authentication module. The
//! id parameter might be left out if FTP. Returns zero if no auth
//! module was present.
//!
//! Note that you should always supply id if it's possible, some user
//! databases require it (such as the htaccess database)
{
  User uid;
  foreach( user_databases(), UserDB m )
    if( uid = m->find_user_from_uid( u,id ) )
      return uid->compat_userinfo();
}

UserDB find_user_database( string name )
//! Given a user database name, returns it if it exists in this
//! configuration, otherwise returns 0.
{
  foreach( user_databases(), UserDB m )
    if( m->name == name )
      return m;
}

AuthModule find_auth_module( string name )
//! Given a authentication method name, returns it if it exists in
//! this configuration, otherwise returns 0.
{
  foreach( auth_modules(), AuthModule m )
    if( m->name == name )
      return m;
}

User authenticate( RequestID id, UserDB|void database)
//! Try to authenticate the request with users from the specified user
//! database. If no @[database] is specified, all datbases in the
//! current configuration are searched in priority order.
//!
//! The return value is the autenticated user.
//! id->misc->authenticated_user is always set to the return value.
{
  User u;
  if (!zero_type (u = id->misc->authenticated_user))
    return u;
  foreach( auth_modules(), AuthModule method )
    if( u = method->authenticate( id, database ) )
      return id->misc->authenticated_user = u;
}

mapping authenticate_throw( RequestID id, string realm,
			    UserDB|void database)
//! Returns a reply mapping, similar to @[Roxen.http_rxml_reply] with
//! friends. If no @[database] is specified, all databases in the
//! current configuration are searched in priority order.
{
  mapping m;
  foreach( auth_modules(), AuthModule method )
    if( m  = method->authenticate_throw( id, realm, database ) )
      return m;
}

User find_user( string user, RequestID|void id )
//! Tries to find the specified user in the currently available user
//! databases. If id is specified, this function defaults to the
//! database that the currently authenticated user came from, if any.
//!
//! The other user databases are processed in priority order
//!
//! Note that you should always supply id if it's possible, some user
//! databases require it (such as the htaccess database)
{
  User uid;

  if( id && id->misc->authenticated_user
      && ( uid = id->misc->authenticated_user->database->find_user(user,id)))
    return uid;
  
  foreach( user_databases(), UserDB m )
    if( uid = m->find_user( user,id ) )
      return uid;
}

array(string) list_users(RequestID|void id)
//! Fetches the full list of valid usernames from the authentication
//! modules by calling the list-users() methods.
//!
//! Note that you should always supply id if it's possible, some user
//! databases require it (such as the htaccess database)
{
  array(string) list = ({});
  foreach( user_databases(), UserDB m )
    list |= m->list_users(id);
  return list;
}

array(string) list_groups(RequestID|void id)
//! Fetches the full list of valid groupnames from the authentication
//! modules by calling the list-users() methods.
//!
//! Note that you should always supply id if it's possible, some user
//! databases require it (such as the htaccess database)
{
  array(string) list = ({});
  foreach( user_databases(), UserDB m )
    list |= m->list_groups(id);
  return list;
}



Group find_group( string group, RequestID|void id )
//! Tries to find the specified group in the currently available user
//! databases. If id is specified, this function defaults to the
//! database that the currently authenticated user came from, if any.
//!
//! The other user databases are processed in priority order
//!
//! Note that you should always supply id if it's possible, some user
//! databases require it (such as the htaccess database)
{
  Group uid;

  if( id && id->misc->authenticated_user
      && ( uid = id->misc->authenticated_user->database->find_group( group ) ))
    return uid;
  
  foreach( user_databases(), UserDB m )
    if( uid = m->find_group( group,id ) )
      return uid;
}


string last_modified_by(Stdio.File file, RequestID id)
{
  Stat s;
  int uid;
  array u;

  if(objectp(file)) s=file->stat();
  if(!s || sizeof(s)<5) return "A. Nonymous";
  uid=s[5];
  u=user_from_uid(uid, id);
  if(u) return u[0];
  return "A. Nonymous";
}




// Some clients does _not_ handle the magic 'internal-gopher-...'.
// So, lets do it here instead.
private mapping internal_gopher_image(string from)
{
  sscanf(from, "%s.gif", from);
  sscanf(from, "%s.jpg", from);
  from -= ".";
  // Disallow "internal-gopher-..", it won't really do much harm, but a list of
  // all files in '..' might be retrieved (that is, the actual directory
  // file was sent to the browser)
  Stdio.File f = lopen("roxen-images/dir/"+from+".gif","r");
  if (f) 
    return (["file":f, "type":"image/gif", "stat":f->stat(),]);
  else
    return 0;
  // File not found.
}

#ifdef MODULE_LEVEL_SECURITY
private mapping(RoxenModule:array) security_level_cache = set_weak_flag (([]), 1);

int|mapping check_security(function|RoxenModule a, RequestID id,
			   void|int slevel)
{
  array seclevels;
  // NOTE:
  //   ip_ok and auth_ok are three-state variables.
  //   Valid contents for them are:
  //     0  Unknown state -- No such restriction encountered yet.
  //     1  May be bad -- Restriction encountered, and test failed.
  //    ~0  OK -- Test passed.

  if (RoxenModule mod = Roxen.get_owning_module (a)) {
    // Only store the module objects in the cache and not `a' directly
    // since it can be (in) an object that is very short lived.
    if (!(seclevels = security_level_cache[mod])) {
      if(mod->query_seclevels)
	seclevels = ({
	  mod->query_seclevels(),
	  mod->query("_seclvl"),
	});
      else
	seclevels = ({0,0});
      security_level_cache[mod] = seclevels;
    }
  }
  else
    seclevels = ({0,0});

  if(slevel && (seclevels[1] > slevel)) // "Trustlevel" to low.
    // Regarding memory cache: This won't have any impact, since it's
    // always the same, regardless of the client requesting the file.
    return 1;

  mixed err;
  if( function(RequestID:int|mapping) f = seclevels[0] )
    // And here we don't have to take notice of the RAM-cache either,
    // since the security patterns themselves does that.
    //
    // All patterns that varies depending on the client must use
    // NOCACHE(), to force the request to be uncached.
    //
    err=catch { return f( id ); };
  else
    return 0; // Ok if there are no patterns.

  report_error("check_security(): %s:\n%s\n",
	       LOC_M(39, "Error during module security check"),
	       describe_backtrace(err));

  return 1;
}
#endif
// Empty all the caches above.
void invalidate_cache()
{
  last_module_cache = 0;
  filter_module_cache = 0;
  userdb_module_cache = 0;
  auth_module_cache = 0;
  first_module_cache = 0;
  url_module_cache = 0;
  location_module_cache = 0;
  logger_module_cache = 0;
  file_extension_module_cache = ([]);
  provider_module_cache = ([]);
#ifdef MODULE_LEVEL_SECURITY
  security_level_cache = set_weak_flag (([ ]), 1);
#endif
}

// Empty all the caches above AND the ones in the loaded modules.
void clear_memory_caches()
{
  invalidate_cache();
  foreach(indices(otomod), RoxenModule m)
    if (m && m->clear_memory_caches)
      if (mixed err = catch( m->clear_memory_caches() ))
	report_error("clear_memory_caches() "+
		     LOC_M(40, "failed for module %O:\n%s\n"),
		     otomod[m], describe_backtrace(err));
}

//  Returns tuple < image, mime-type >
protected array(string) draw_saturation_bar(int hue,int brightness, int where,
					    int small_version)
{
  Image.Image bar =
    small_version ? Image.Image(16, 128) : Image.Image(30, 256);
  
  for(int i=0;i<128;i++)
  {
    int j = i * 2;
    array color = hsv_to_rgb(hue, 255 - j, brightness);
    if (small_version) {
      bar->line(0, i, 15, i, @color);
    } else {
      bar->line(0, j, 29, j, @color);
      bar->line(0, j + 1,29, j + 1, @color);
    }
  }

  if (where >= 0 && where <= 255) {
    where = 255 - where;
    int hilite = (brightness > 128) ? 0 : 255;
    if (small_version)
      bar->line(0, where / 2, 15, where / 2, hilite, hilite, hilite);
    else
      bar->line(0, where, 29, where, hilite, hilite, hilite);
  }
  
#if constant(Image.JPEG) && constant(Image.JPEG.encode)
  return ({ Image.JPEG.encode(bar), "image/jpeg" });
#else
  return ({ Image.PNG.encode(bar), "image/png" });
#endif
}


#if constant(Image.GIF) && constant(Image.PNG)
array(mapping) spinner_data = 0;

//  Returns tuple < image, mime type >
protected array(string) draw_spinner(string bgcolor)
{
  //  Parse color
  array color = parse_color(bgcolor);
  
  //  Load all spinner PNGs
  if (!spinner_data) {
    array(mapping) temp_spinner_data = ({ });
    for (int i = 0; i < 12; i++) {
      string src = lopen("roxen-images/spinner" + i + ".png", "r")->read();
      temp_spinner_data += ({ Image.PNG._decode(src) });
    }
    spinner_data = temp_spinner_data;
  }
  
  //  Create non-transparent Image object for each frame
  array(Image.Image) frames = ({ });
  foreach(spinner_data, mapping data) {
    Image.Image frame = Image.Image(17, 17, @color);
    frame->paste_mask(data->image, data->alpha);
    frames += ({ frame });
  }
  
  //  Create animated GIF using colortable based on first frame (all of
  //  them have the same set of colors)
  Image.Colortable colors = Image.Colortable(frames[0]);
  string res = Image.GIF.header_block(17, 17, colors);
  foreach(frames, Image.Image frame)
    res += Image.GIF.render_block(frame, colors, 0, 0, 0, 1);
  res +=
    Image.GIF.netscape_loop_block(0) +
    Image.GIF.end_block();
  
  return ({ res, "image/gif" });
}
#endif


// Inspired by the internal-gopher-... thingie, this is the images
// from the administration interface. :-)
private mapping internal_roxen_image( string from, RequestID id )
{
  sscanf(from, "%s.gif", from);
  sscanf(from, "%s.jpg", from);
  sscanf(from, "%s.xcf", from);
  sscanf(from, "%s.png", from);

#if constant(Image.GIF) && constant(Image.PNG)
  //  Animated spinner image
  if (has_prefix(from, "spinner-")) {
    array(string) spinner = draw_spinner(from[8..]);
    return ([ "data" : spinner[0],
	      "type" : spinner[1],
	      "stat" : ({ 0, 0, 0, 900000000, 0, 0, 0 }) ]);
  }
#endif

  // Automatically generated colorbar. Used by wizard code...
  int hue,bright,w;
  string colorbar;
  if(sscanf(from, "%s:%d,%d,%d", colorbar, hue, bright,w)==4) {
    array bar = draw_saturation_bar(hue, bright, w,
				    colorbar == "colorbar-small");
    return Roxen.http_string_answer(bar[0], bar[1]);
  }

  Stdio.File f;

  if( !id->misc->internal_get )
    if(f = lopen("roxen-images/"+from+".gif", "r"))
      return (["file":f, "type":"image/gif", "stat":f->stat()]);

  if(f = lopen("roxen-images/"+from+".png", "r"))
    return (["file":f, "type":"image/png", "stat":f->stat()]);

  if(f = lopen("roxen-images/"+from+".jpg", "r"))
    return (["file":f, "type":"image/jpeg", "stat":f->stat()]);

  if(f = lopen("roxen-images/"+from+".xcf", "r"))
    return (["file":f, "type":"image/x-gimp-image", "stat":f->stat()]);

  if(f = lopen("roxen-images/"+from+".gif", "r"))
    return (["file":f, "type":"image/gif", "stat":f->stat()]);
  // File not found.
  return 0;
}


mapping (mixed:function|int) locks = ([]);

#ifdef THREADS
// import Thread;

mapping locked = ([]), thread_safe = ([]);

mixed _lock(object|function f)
{
  Thread.MutexKey key;
  function|int l;
  TIMER_START(module_lock);
  if (functionp(f)) {
    f = function_object(f);
  }
  if (l = locks[f])
  {
    if (l != -1)
    {
      // Allow recursive locks.
      catch{
	// report_debug("lock %O\n", f);
	locked[f]++;
	key = l();
      };
    } else
      thread_safe[f]++;
  } else if (f->thread_safe) {
    locks[f]=-1;
    thread_safe[f]++;
  } else {
    if (!locks[f])
    {
      // Needed to avoid race-condition.
      l = Thread.Mutex()->lock;
      if (!locks[f]) {
	locks[f]=l;
      }
    }
    // report_debug("lock %O\n", f);
    locked[f]++;
    key = l();
  }
  TIMER_END(module_lock);
  return key;
}

#define LOCK(X) key=_lock(X)
#define UNLOCK() do{key=0;}while(0)
#else
#define LOCK(X)
#define UNLOCK()
#endif

string examine_return_mapping(mapping m)
{
   string res;

   if (m->extra_heads)
      m->extra_heads=mkmapping(Array.map(indices(m->extra_heads),
					 lower_case),
			       values(m->extra_heads));
   else
      m->extra_heads=([]);

   switch (m->error||200)
   {
      case 302: // redirect
	 if (m->extra_heads &&
	     (m->extra_heads->location))
	   res = sprintf("Returned redirect to %O ", m->extra_heads->location);
	 else
	   res = "Returned redirect, but no location header. ";
	 break;

      case 401:
	 if (m->extra_heads["www-authenticate"])
	   res = sprintf("Returned authentication failed: %O ",
			 m->extra_heads["www-authenticate"]);
	 else
	   res = "Returned authentication failed. ";
	 break;

      case 200:
	 // NB: Note the setting of extra_heads above.
	 if (sizeof(m) <= 1) {
	   res = "Returned multi status. ";
	   break;
	 }
	 res = "Returned ok. ";
	 break;

      default:
	 res = sprintf("Returned %O. ", m->error);
   }

   if (!zero_type(m->len))
      if (m->len<0)
	 res += "No data ";
      else
	 res += sprintf("%O bytes ", m->len);
   else if (stringp(m->data))
     res += sprintf("%d bytes ", strlen(m->data));
   else if (objectp(m->file))
      if (catch {
	 Stat a=m->file->stat();
	 res += sprintf("%O bytes ", a[1]-m->file->tell());
      })
	res += "? bytes ";

   if (m->data) res += "(static)";
   else if (m->file) res += "(open file)";

   if (stringp(m->extra_heads["content-type"]) ||
       stringp(m->type)) {
      res += sprintf(" of %O", m->type||m->extra_heads["content-type"]);
   }

   return res;
}

//! Find all applicable locks for this user on @[path].
mapping(string:DAVLock) find_locks(string path, int(-1..1) recursive,
				   int(0..1) exclude_shared, RequestID id)
{
  SIMPLE_TRACE_ENTER(0, "find_locks(%O, %O, %O, X)",
		     path, recursive, exclude_shared);
  mapping(string:DAVLock) locks = ([]);

  foreach(location_module_cache||location_modules(),
	  [string loc, function func])
  {
    SIMPLE_TRACE_ENTER(function_object(func),
		       "Finding locks in %O.", loc);
    string subpath;
    if (has_prefix(path, loc)) {
      // path == loc + subpath.
      subpath = path[sizeof(loc)..];
    } else if (recursive && has_prefix(loc, path)) {
      // loc == path + ignored.
      subpath = "/";
    } else {
      // Does not apply to this location module.
      TRACE_LEAVE("Skip this module.");
      continue;
    }
    TRACE_ENTER(sprintf("subpath: %O", subpath),
		function_object(func)->find_locks);
    mapping(string:DAVLock) sub_locks =
      function_object(func)->find_locks(subpath, recursive,
					exclude_shared, id);
    TRACE_LEAVE("");
    if (sub_locks) {
      SIMPLE_TRACE_LEAVE("Got some locks: %O", sub_locks);
      locks |= sub_locks;
    } else {
      TRACE_LEAVE("Got no locks.");
    }
  }
  SIMPLE_TRACE_LEAVE("Returning %O", locks);
  return locks;
}

//! Check that all locks that apply to @[path] for the user the request
//! is authenticated as have been mentioned in the if-header.
//!
//! WARNING: This function has some design issues and will very likely
//! get a different interface. Compatibility is NOT guaranteed.
//!
//! @param path
//!   Normalized path below the filesystem location.
//!
//! @param recursive
//!   If @expr{1@} also check recursively under @[path] for locks.
//!
//! @returns
//!   Returns one of
//!   @mixed
//!     @type int(0..0)
//!       Zero if not locked, or all locks were mentioned.
//!     @type mapping(zero:zero)
//!       An empty mapping if @[recursive] was true and there
//!       were unmentioned locks on paths with @[path] as a prefix.
//!       The missing locks are registered in the multistatus for
//!       the @[id] object.
//!     @type mapping(string:mixed)
//!       A @[Protocols.HTTP.DAV_LOCKED] error status in all other cases.
//!   @endmixed
//!
//! @note
//! @[DAVLock] objects may be created if the filesystem has some
//! persistent storage of them. The default implementation does not
//! store locks persistently.
mapping(string:mixed)|int(-1..0) check_locks(string path,
					     int(0..1) recursive,
					     RequestID id)
{
  TRACE_ENTER(sprintf("check_locks(%O, %d, X)", path, recursive), this);

  mapping(string:DAVLock) locks = find_locks(path, recursive, 0, id);
  // Common case.
  if (!sizeof(locks)) {
    TRACE_LEAVE ("Got no locks.");
    return 0;
  }

  mapping(string:array(array(array(string)))) if_data = id->get_if_data();
  if (if_data) {
    foreach(if_data[0], array(array(string)) tokens) {
      m_delete(locks, tokens[0][1]);
    }

    if (!sizeof(locks)) {
      TRACE_LEAVE ("All locks unlocked.");
      return 0;
    }
  }

  // path = id->not_query;
  if (!has_suffix(path, "/")) path += "/";
  mapping(string:mixed) ret =
    Roxen.http_dav_error(Protocols.HTTP.DAV_LOCKED, "lock-token-submitted");
  foreach(locks;;DAVLock lock) {
    TRACE_ENTER(sprintf("Checking lock %O against %O.", lock, path), 0);
    if (has_prefix(path, lock->path)) {
      TRACE_LEAVE("Direct lock.");
      TRACE_LEAVE("Locked.");
      return ret;
    }
    if (lock->is_file) {
      id->set_status_for_path(lock->path[..<1], ret);
    } else {
      id->set_status_for_path(lock->path, ret);
    }
    TRACE_LEAVE("Added to multi status.");
  }
  TRACE_LEAVE("Multi status.");
  return ([]);
}

protected multiset(DAVLock) active_locks = (<>);

//! Unlock the lock represented by @[lock] on @[path].
//!
//! @returns
//!   Returns a result-mapping on error, and @expr{0@} (zero) on success.
mapping(string:mixed) unlock_file(string path, DAVLock lock, RequestID id)
{
  // Canonicalize path.
  if (!has_suffix(path, "/")) path+="/";

  foreach(location_module_cache||location_modules(),
	  [string loc, function func])
  {
    if (has_prefix(path, loc)) {
      // path == loc + subpath.
      mapping(string:mixed) ret =
	function_object(func)->unlock_file(path[sizeof(loc)..], lock, id);

      // FIXME: Semantics for partial unlocking?
      if (ret) return ret;
    } else if (lock->recursive && has_prefix(loc, path)) {
      // loc == path + ignored.
      mapping(string:mixed) ret =
	function_object(func)->unlock_file("/", lock, id);

      // FIXME: Semantics for partial unlocking?
      if (ret) return ret;
    }
    if (function_object(func)->webdav_opaque) break;
  }
  active_locks[lock] = 0;
  // destruct(lock);
  return 0;
}

//! Force expiration of any locks that have timed out.
int expire_locks(RequestID id)
{
  int t = time(1);
  int min_time = 0x7fffffff;
  foreach(active_locks; DAVLock lock;) {
    if (lock->expiry_time) {
      if (lock->expiry_time < t) {
	unlock_file(lock->path, lock, id);
      } else if (lock->expiry_time < min_time) {
	min_time = lock->expiry_time;
      }
    }
  }
  return min_time - t;
}

mixed expire_lock_loop_handle;

protected void expire_lock_loop()
{
  int t = expire_locks(0);	// NOTE: Called with RequestID 0!

  if (sizeof(active_locks)) {
    t = max (t, 1); // Wait at least one second before the next run.
    t = min (t, 3600); // Expire locks at least once every hour.

    if (expire_lock_loop_handle)
      remove_call_out (expire_lock_loop_handle);

    expire_lock_loop_handle = roxen.background_run(t, expire_lock_loop);
  }
}

//! Refresh a lock.
//!
//! Update the expiry time for the lock.
void refresh_lock(DAVLock lock)
{
  if (lock->expiry_delta) {
    // Use time() instead of time(1) to avoid expiring the lock too
    // early if the returned time is old. Probably unlikely, but
    // anyways.
    lock->expiry_time = lock->expiry_delta + time();
  }
}

//! Attempt to lock @[path].
//!
//! @param path
//!   Path to lock.
//!
//! @param locktype
//!   Type of lock (currently only @expr{"DAV:write"@} is defined).
//!
//! @param lockscope
//!   Scope of lock either @expr{"DAV:exclusive"@} or
//!   @expr{"DAV:shared"@}.
//!
//! @param expiry_delta
//!   Idle time in seconds before the lock expires. @expr{0@} (zero)
//!   means no expiry.
//!
//! @returns
//!   Returns a result mapping on failure,
//!   and the resulting @[DAVLock] on success.
mapping(string:mixed)|DAVLock lock_file(string path,
					int(0..1) recursive,
					string lockscope,
					string locktype,
					int(0..) expiry_delta,
					array(Parser.XML.Tree.Node) owner,
					RequestID id)
{
  TRACE_ENTER(sprintf("%O(%O, %O, %O, %O, %O, %O, %O)",
		      this_function, path, recursive, lockscope,
		      locktype, expiry_delta, owner, id), 0);

  int is_file;

  // Canonicalize path.
  if (!has_suffix(path, "/")) {
    path+="/";
    is_file = 1;
  }

  // FIXME: Race conditions!

  int fail;

  // First check if there's already some lock on the path that prevents
  // us from locking it.
  mapping(string:DAVLock) locks = find_locks(path, recursive, 0, id);

  foreach(locks; string lock_token; DAVLock lock) {
    TRACE_ENTER(sprintf("Checking lock %O...\n", lock), 0);
    if ((lock->lockscope == "DAV:exclusive") ||
	(lockscope == "DAV:exclusive")) {
      TRACE_LEAVE("Locked.");
      id->set_status_for_path(lock->path, 423, "Locked");
      fail = 1;
    }
    TRACE_LEAVE("Shared.");
  }

  if (fail) {
    TRACE_LEAVE("Fail.");
    return ([]);
  }

  // Create the new lock.

  string locktoken = "opaquelocktoken:" + roxen->new_uuid_string();
  DAVLock lock = DAVLock(locktoken, path, recursive, lockscope, locktype,
			 expiry_delta, owner);
  lock->is_file = is_file;
  foreach(location_module_cache||location_modules(),
	  [string loc, function func])
  {
    string subpath;
    if (has_prefix(path, loc)) {
      // path == loc + subpath.
      subpath = path[sizeof(loc)..];
    } else if (recursive && has_prefix(loc, path)) {
      // loc == path + ignored.
      subpath = "/";
    } else {
      // Does not apply to this location module.
      continue;
    }

    TRACE_ENTER(sprintf("Calling %O->lock_file(%O, %O, %O)...",
			function_object(func), subpath, lock, id), 0);
    mapping(string:mixed) lock_error =
      function_object(func)->lock_file(subpath, lock, id);
    if (lock_error) {
      // Failure. Unlock the new lock.
      foreach(location_module_cache||location_modules(),
	      [string loc2, function func2])
      {
	if (has_prefix(path, loc2)) {
	  // path == loc2 + subpath.
	  mapping(string:mixed) ret =
	    function_object(func2)->unlock_file(path[sizeof(loc2)..],
						lock, id);
	} else if (recursive && has_prefix(loc2, path)) {
	  // loc2 == path + ignored.
	  mapping(string:mixed) ret =
	    function_object(func2)->unlock_file("/", lock, id);
	}
	if (func == func2) break;
      }
      // destruct(lock);
      TRACE_LEAVE(sprintf("Lock error: %O", lock_error));
      return lock_error;
    }
    TRACE_LEAVE("Ok.");
    if (function_object(func)->webdav_opaque) break;
  }

  if (expiry_delta) {
    // Lock with timeout.
    // FIXME: Race-conditions.
    if (!sizeof(active_locks)) {
      // Start the lock expiration loop.
      active_locks[lock] = 1;
      expire_lock_loop();
    } else {
      active_locks[lock] = 1;
    }
  }

  // Success.
  TRACE_LEAVE("Success.");
  return lock;
}

//! Returns the value of the specified property, or an error code
//! mapping.
//!
//! @note
//!   Returning a string is shorthand for returning an array
//!   with a single text node.
//!
//! @seealso
//!   @[query_property_set()]
string|array(Parser.XML.Tree.SimpleNode)|mapping(string:mixed)
  query_property(string path, string prop_name, RequestID id)
{
  foreach(location_module_cache||location_modules(),
	  [string loc, function func])
  {
    if (!has_prefix(path, loc)) {
      // Does not apply to this location module.
      continue;
    }

    // path == loc + subpath.
    string subpath = path[sizeof(loc)..];

    string|array(Parser.XML.Tree.SimpleNode)|mapping(string:mixed) res =
      function_object(func)->query_property(subpath, prop_name, id);
    if (mappingp(res) && (res->error == 404)) {
      // Not found in this module; try the next.
      continue;
    }
    return res;
  }
  return Roxen.http_status(Protocols.HTTP.HTTP_NOT_FOUND, "No such property.");
}

mapping|int(-1..0) low_get_file(RequestID id, int|void no_magic)
//! The function that actually tries to find the data requested. All
//! modules except last and filter type modules are mapped, in order,
//! and the first one that returns a suitable response is used. If
//! `no_magic' is set to one, the internal magic roxen images and the
//! @[find_internal()] callbacks will be ignored.
//!
//! The return values 0 (no such file) and -1 (the data is a
//! directory) are only returned when `no_magic' was set to 1;
//! otherwise a result mapping is always generated.
{
#ifdef MODULE_LEVEL_SECURITY
  int slevel;
#endif

#ifdef THREADS
  Thread.MutexKey key;
#endif

  id->not_query = VFS.normalize_path( id->not_query );

  TRACE_ENTER(sprintf("Request for %s", id->not_query), 0);

  string file=id->not_query;
  string loc;
  function funp;
  mixed tmp, tmp2;
  mapping|object(Stdio.File)|int fid;

  if(!no_magic)
  {
    TIMER_START(internal_magic);
#ifndef NO_INTERNAL_HACK
    // Find internal-foo-bar images
    // min length == 17 (/internal-roxen-?..)
    // This will save some time indeed.
    string type;
    if(sizeof(file) > 17 &&
#if ROXEN_COMPAT <= 2.1
       (file[0] == '/') &&
       sscanf(file, "%*s/internal-%s-%[^/]", type, loc) == 3
#else
       sscanf(file, "/internal-%s-%[^/]", type, loc) == 2
#endif
       ) {
      switch(type) {
       case "roxen":
	//  Mark all /internal-roxen-* as cacheable even though the user might be
	//  authenticated (which normally disables protocol-level caching).
	RAISE_CACHE(60 * 60 * 24 * 365);  //  1 year
	PROTO_CACHE();
	id->set_response_header("Cache-Control", "public, max-age=31536000");
	
	TRACE_LEAVE("Magic internal roxen image");
        if(loc=="unit" || loc=="pixel-of-destiny")
	{
	  TIMER_END(internal_magic);
	  return (["data":"GIF89a\1\0\1\0\200ÿ\0ÀÀÀ\0\0\0!ù\4\1\0\0\0\0,"
		   "\0\0\0\0\1\0\1\0\0\1\1""2\0;",
		   "type":"image/gif",
		   "stat": ({0, 0, 0, 900000000, 0, 0, 0})]);
	}
	if(has_prefix(loc, "pixel-"))
	{
	  TIMER_END(internal_magic);
	  return (["data":sprintf("GIF89a\1\0\1\0\200\0\0\0\0\0%c%c%c,\0\0\0"
				  "\0\1\0\1\0\0\2\2L\1\0;",
				  @parse_color(loc[6..])),
		   "type":"image/gif",
		   "stat": ({0, 0, 0, 900000000, 0, 0, 0})]);
	}
	TIMER_END(internal_magic);
	return internal_roxen_image(loc, id);

       case "gopher":
	TRACE_LEAVE("Magic internal gopher image");
	TIMER_END(internal_magic);
	return internal_gopher_image(loc);
      }
    }
#endif

    // Locate internal location resources.
    if(has_prefix(file, internal_location))
    {
      TRACE_ENTER("Magic internal module location", 0);
      RoxenModule module;
      string name, rest;
      function find_internal;
      if(2==sscanf(file[strlen(internal_location)..], "%s/%s", name, rest) &&
	 (module = find_module(replace(name, "!", "#"))) &&
	 (find_internal = module->find_internal))
      {
#ifdef MODULE_LEVEL_SECURITY
	if(tmp2 = check_security(find_internal, id, slevel))
	  if(intp(tmp2))
	  {
	    TRACE_LEAVE("Permission to access module denied.");
	    find_internal = 0;
	  } else {
	    TRACE_LEAVE("");
	    TRACE_LEAVE("Request denied.");
	    TIMER_END(internal_magic);
	    return tmp2;
	  }
#endif
	if(find_internal)
	{
	  TRACE_ENTER("Calling find_internal()...", find_internal);
	  PROF_ENTER("find_internal","location");
	  LOCK(find_internal);
	  fid=find_internal( rest, id );
	  UNLOCK();
	  //TRACE_LEAVE(sprintf("find_internal has returned %O", fid));
	  TRACE_LEAVE("");
	  PROF_LEAVE("find_internal","location");
	  if(fid)
	  {
	    if(mappingp(fid))
	    {
	      TRACE_LEAVE("");
	      TRACE_LEAVE(examine_return_mapping(fid));
	      TIMER_END(internal_magic);
	      return fid;
	    }
	    else
	    {
#ifdef MODULE_LEVEL_SECURITY
	      int oslevel = slevel;
	      array slca;
	      if(slca = security_level_cache[ Roxen.get_owning_module (find_internal) ])
		slevel = slca[1];
	      // security_level_cache from
	      // check_security
	      id->misc->seclevel = slevel;
#endif
	      if(objectp(fid))
		TRACE_LEAVE("Returned open filedescriptor. "
#ifdef MODULE_LEVEL_SECURITY
			    +(slevel != oslevel?
			      sprintf(" The security level is now %d.", slevel):"")
#endif
			    );
	      else
		TRACE_LEAVE("Returned directory indicator."
#ifdef MODULE_LEVEL_SECURITY
			    +(oslevel != slevel?
			      sprintf(" The security level is now %d.", slevel):"")
#endif
			    );
	    }
	  } else
	    TRACE_LEAVE("");
	} else
	  TRACE_LEAVE("");
      } else
	TRACE_LEAVE("");
    }
    TIMER_END(internal_magic);
  }

  // Well, this just _might_ be somewhat over-optimized, since it is
  // quite unreadable, but, you cannot win them all..
  if(!fid)
  {
#ifdef URL_MODULES
  // Map URL-modules
    TIMER_START(url_modules);
    foreach(url_module_cache||url_modules(), funp)
    {
      PROF_ENTER(Roxen.get_owning_module(funp)->module_name,"url module");
      LOCK(funp);
      TRACE_ENTER("URL module", funp);
      tmp=funp( id, file );
      UNLOCK();
      PROF_LEAVE(Roxen.get_owning_module(funp)->module_name,"url module");

      if(mappingp(tmp))
      {
	TRACE_LEAVE("");
	TRACE_LEAVE("Returning data");
	TIMER_END(url_modules);
	return tmp;
      }
      if(objectp( tmp ))
      {
	mixed err;

	id->misc->get_file_nest++;
	err = catch {
	  if( id->misc->get_file_nest < 20 )
	    tmp = (id->conf || this_object())->low_get_file( tmp, no_magic );
	  else
	  {
	    TRACE_LEAVE("Too deep recursion");
	    error("Too deep recursion in roxen::get_file() while mapping "
		  +file+".\n");
	  }
	};
	id->misc->get_file_nest = 0;
	if(err) throw(err);
	TRACE_LEAVE("");
	TRACE_LEAVE("Returning data");
	TIMER_END(url_modules);
	return tmp;
      }
      TRACE_LEAVE("");
      TIMER_END(url_modules);
    }
#endif

    TIMER_START(location_modules);
    foreach(location_module_cache||location_modules(), tmp)
    {
      loc = tmp[0];
      if(has_prefix(file, loc))
      {
	TRACE_ENTER(sprintf("Location module [%s] ", loc), tmp[1]);
#ifdef MODULE_LEVEL_SECURITY
	if(tmp2 = check_security(tmp[1], id, slevel))
	  if(intp(tmp2))
	  {
	    TRACE_LEAVE("Permission to access module denied.");
	    continue;
	  } else {
	    TRACE_LEAVE("");
	    TRACE_LEAVE("Request denied.");
	    TIMER_END(location_modules);
	    return tmp2;
	  }
#endif
	PROF_ENTER(Roxen.get_owning_module(tmp[1])->module_name,"location");
	TRACE_ENTER("Calling find_file()...", 0);
	LOCK(tmp[1]);
	fid=tmp[1]( file[ strlen(loc) .. ] + id->extra_extension, id);
	UNLOCK();
	TRACE_LEAVE("");
	PROF_LEAVE(Roxen.get_owning_module(tmp[1])->module_name,"location");
	if(fid)
	{
	  id->virtfile = loc;

	  if(mappingp(fid))
	  {
	    TRACE_LEAVE(""); // Location module [...]
	    TRACE_LEAVE(examine_return_mapping(fid));
	    TIMER_END(location_modules);
	    return fid;
	  }
	  else
	  {
#ifdef MODULE_LEVEL_SECURITY
	    int oslevel = slevel;
	    array slca;
	    if(slca = security_level_cache[ Roxen.get_owning_module (tmp[1]) ])
	      slevel = slca[1];
	    // security_level_cache from
	    // check_security
	    id->misc->seclevel = slevel;
#endif
	    if(objectp(fid))
	      TRACE_LEAVE("Returned open filedescriptor."
#ifdef MODULE_LEVEL_SECURITY
			  +(slevel != oslevel?
			    sprintf(" The security level is now %d.", slevel):"")
#endif

			  );
	    else
	      TRACE_LEAVE("Returned directory indicator."
#ifdef MODULE_LEVEL_SECURITY
			  +(oslevel != slevel?
			    sprintf(" The security level is now %d.", slevel):"")
#endif
			  );
	    break;
	  }
	} else
	  TRACE_LEAVE("");
      } else if(strlen(loc)-1==strlen(file) && file+"/" == loc) {
	// This one is here to allow accesses to /local, even if
	// the mountpoint is /local/. It will slow things down, but...

	TRACE_ENTER("Automatic redirect to location_module.", tmp[1]);
	TRACE_LEAVE("");
	TRACE_LEAVE("Returning data");

	// Keep query (if any).
	// FIXME: Should probably keep config <foo>
	string new_query = Roxen.http_encode_invalids(id->not_query) + "/" +
	  (id->query?("?"+id->query):"");
	new_query=Roxen.add_pre_state(new_query, id->prestate);

	TIMER_END(location_modules);
	return Roxen.http_redirect(new_query, id);
      }
    }
    TIMER_END(location_modules);
  }

  if(fid == -1)
  {
    if(no_magic)
    {
      TRACE_LEAVE("No magic requested. Returning -1.");
      return -1;
    }
    TIMER_START(directory_module);
    if(dir_module)
    {
      PROF_ENTER(dir_module->module_name,"directory");
      LOCK(dir_module);
      TRACE_ENTER("Directory module", dir_module);
      fid = dir_module->parse_directory(id);
      TRACE_LEAVE("");
      UNLOCK();
      PROF_LEAVE(dir_module->module_name,"directory");
    }
    else
    {
      TRACE_LEAVE("No directory module. Returning 'no such file'");
      return 0;
    }
    TIMER_END(directory_module);
    if(mappingp(fid))
    {
      TRACE_LEAVE("Returning data");
      return (mapping)fid;
    }
  }

  // Map the file extensions, but only if there is a file...
  TIMER_START(extension_module);
  if(objectp(fid) &&
     (tmp = file_extension_modules(loc =
				   lower_case(Roxen.extension(id->not_query,
							      id)))))
  {
    foreach(tmp, funp)
    {
      TRACE_ENTER(sprintf("Extension module [%s] ", loc), funp);
#ifdef MODULE_LEVEL_SECURITY
      if(tmp=check_security(funp, id, slevel))
	if(intp(tmp))
	{
	  TRACE_LEAVE("Permission to access module denied.");
	  continue;
	}
	else
	{
	  TRACE_LEAVE("");
	  TRACE_LEAVE("Permission denied");
	  TIMER_END(extension_module);
	  return tmp;
	}
#endif
      PROF_ENTER(Roxen.get_owning_module(funp)->module_name,"ext");
      LOCK(funp);
      tmp=funp(fid, loc, id);
      UNLOCK();
      PROF_LEAVE(Roxen.get_owning_module(funp)->module_name,"ext");
      if(tmp)
      {
	if(!objectp(tmp))
	{
	  TRACE_LEAVE("");
	  TRACE_LEAVE("Returning data");
	  TIMER_END(extension_module);
	  return tmp;
	}
	if(fid && tmp != fid)
	  destruct(fid);
	TRACE_LEAVE("Returned new open file");
	fid = tmp;
	break;
      } else
	TRACE_LEAVE("");
    }
  }
  TIMER_END(extension_module);

  if(objectp(fid))
  {
    TIMER_START(content_type_module);
    if(stringp(id->extension)) {
      id->not_query += id->extension;
      loc = lower_case(Roxen.extension(id->not_query, id));
    }
    TRACE_ENTER("Content-type mapping module", types_module);
    tmp=type_from_filename(id->not_query, 1, loc);
    TRACE_LEAVE(tmp?sprintf("Returned type %O %s.", tmp[0], tmp[1]||"")
		: "Missing type.");
    if(tmp)
    {
      TRACE_LEAVE("");
      TIMER_END(content_type_module);
      return ([ "file":fid, "type":tmp[0], "encoding":tmp[1] ]);
    }
    TRACE_LEAVE("");
    TIMER_END(content_type_module);
    return ([ "file":fid, ]);
  }

  if(!fid)
    TRACE_LEAVE("Returned 'no such file'.");
  else
    TRACE_LEAVE("Returning data");
  return fid;
}

#define TRY_FIRST_MODULES(FILE, RECURSE_CALL) do {			\
    TIMER_START(first_modules);						\
    foreach(first_module_cache||first_modules(), function funp)		\
    {									\
      TRACE_ENTER ("First try module", funp);				\
      if(FILE = funp( id )) {						\
	TRACE_LEAVE ("Got response");					\
	break;								\
      }									\
      TRACE_LEAVE ("No response");					\
      if(id->conf != this_object()) {					\
	TRACE_ENTER (sprintf ("Configuration changed to %O - "		\
			      "redirecting", id->conf), 0);		\
	TRACE_LEAVE ("");						\
	TIMER_END (first_modules);					\
	TIMER_END (handle_request);					\
	return id->conf->RECURSE_CALL;					\
      }									\
    }									\
    TIMER_END(first_modules);						\
  } while (0)

#define TRY_LAST_MODULES(FILE, RECURSE_CALL) do {			\
    mixed ret;								\
    TIMER_START(last_modules);						\
    foreach(last_module_cache||last_modules(), function funp) {		\
      TRACE_ENTER ("Last try module", funp);				\
      if(ret = funp(id)) {						\
	if (ret == 1) {							\
	  TRACE_LEAVE ("Request rewritten - try again");		\
	  TIMER_END(last_modules);					\
	  TIMER_END(handle_request);					\
	  return RECURSE_CALL;						\
	}								\
	TRACE_LEAVE ("Got response");					\
	break;								\
      }									\
      TRACE_LEAVE ("No response");					\
    }									\
    FILE = ret;								\
    TIMER_END(last_modules);						\
  } while (0)

mixed handle_request( RequestID id, void|int recurse_count)
{
  mixed file;
  REQUEST_WERR("handle_request()");

  if (recurse_count > 50) {
    TRACE_ENTER ("Looped " + recurse_count +
		 " times in internal redirects - giving up", 0);
    TRACE_LEAVE ("");
    return 0;
  }

  TIMER_START(handle_request);
  TRY_FIRST_MODULES (file, handle_request (id, recurse_count + 1));
  if(!mappingp(file) && !mappingp(file = get_file(id)))
    TRY_LAST_MODULES (file, handle_request(id, recurse_count + 1));
  TIMER_END(handle_request);

  REQUEST_WERR("handle_request(): Done");
  MERGE_TIMERS(roxen);
  return file;
}

mapping|int get_file(RequestID id, int|void no_magic, int|void internal_get)
//! Return a result mapping for the id object at hand, mapping all
//! modules, including the filter modules. This function is mostly a
//! wrapper for @[low_get_file()].
{
  TIMER_START(get_file);
  int orig_internal_get = id->misc->internal_get;
  id->misc->internal_get = internal_get;
  RequestID root_id = id->root_id || id;
  root_id->misc->_request_depth++;
  if(sub_req_limit && root_id->misc->_request_depth > sub_req_limit)
    error("Subrequest limit reached. (Possibly an insertion loop.)");

  mapping|int res;
  mapping res2;
  function tmp;
  res = low_get_file(id, no_magic);
  TIMER_END(get_file);

  // finally map all filter type modules.
  // Filter modules are like TYPE_LAST modules, but they get called
  // for _all_ files.
  TIMER_START(filter_modules);
  foreach(filter_module_cache||filter_modules(), tmp)
  {
    TRACE_ENTER("Filter module", tmp);
    PROF_ENTER(Roxen.get_owning_module(tmp)->module_name,"filter");
    if(res2=tmp(res,id))
    {
      if(mappingp(res) && res->file && (res2->file != res->file))
	destruct(res->file);
      TRACE_LEAVE("Rewrote result.");
      res=res2;
    } else
      TRACE_LEAVE("");
    PROF_LEAVE(Roxen.get_owning_module(tmp)->module_name,"filter");
  }
  TIMER_END(filter_modules);

  root_id->misc->_request_depth--;
  id->misc->internal_get = orig_internal_get;
  return res;
}

array(string) find_dir(string file, RequestID id, void|int(0..1) verbose)
{
  array dir;
  TRACE_ENTER(sprintf("List directory %O.", file), 0);

  if(!sizeof (file) || file[0] != '/')
    file = "/" + file;

#ifdef URL_MODULES
#ifdef THREADS
  Thread.MutexKey key;
#endif
  // Map URL-modules
  foreach(url_modules(), function funp)
  {
    string of = id->not_query;
    id->not_query = file;
    LOCK(funp);
    TRACE_ENTER("URL module", funp);
    mixed remap=funp( id, file );
    UNLOCK();

    if(mappingp( remap ))
    {
      id->not_query=of;
      TRACE_LEAVE("Returned 'No thanks'.");
      TRACE_LEAVE("");
      return 0;
    }
    if(objectp( remap ))
    {
      mixed err;
      id->misc->find_dir_nest++;

      TRACE_LEAVE("Recursing");
      file = id->not_query;
      err = catch {
	if( id->misc->find_dir_nest < 20 )
	  dir = (id->conf || this_object())->find_dir( file, id );
	else
	  error("Too deep recursion in roxen::find_dir() while mapping "
		+file+".\n");
      };
      id->misc->find_dir_nest = 0;
      TRACE_LEAVE("");
      if(err)
	throw(err);
      TRACE_LEAVE("Returning result from URL module.");
      return dir;
    }
    TRACE_LEAVE("Returned 'Continue normal processing'.");
    id->not_query=of;
  }
#endif /* URL_MODULES */

  array | mapping d;
  array(string) locks=({});
  RoxenModule mod;
  string loc;
  foreach(location_modules(), array tmp)
  {
    loc = tmp[0];
    if(!search(file, loc)) {
      /* file == loc + subpath */
      TRACE_ENTER(sprintf("Location module [%s] ", loc), tmp[1]);
#ifdef MODULE_LEVEL_SECURITY
      if(check_security(tmp[1], id)) {
	TRACE_LEAVE("Permission denied");
	continue;
      }
#endif
      mod=function_object(tmp[1]);
      if(d=mod->find_dir(file[strlen(loc)..], id))
      {
	if(mappingp(d))
	{
	  if(d->files) {
	    TRACE_LEAVE("Got exclusive directory.");
	    TRACE_LEAVE(sprintf("Returning list of %d files.", sizeof(d->files)));
	    return d->files;
	  } else
	    TRACE_LEAVE("");
	} else {
	  TRACE_LEAVE("Got files.");
	  if(!dir) dir=({ });
	  dir |= d;
	}
      }
      else {
	if(verbose && mod->list_lock_files)
	  locks |= mod->list_lock_files();
	TRACE_LEAVE("");
      }
    } else if((search(loc, file)==0) && (loc[strlen(file)-1]=='/') &&
	      (loc[0]==loc[-1]) && (loc[-1]=='/') &&
	      (function_object(tmp[1])->stat_file(".", id))) {
      /* loc == file + "/" + subpath + "/"
       * and stat_file(".") returns non-zero.
       */
      TRACE_ENTER(sprintf("Location module [%s] ", loc), tmp[1]);
      loc=loc[strlen(file)..];
      sscanf(loc, "%s/", loc);
      if (dir) {
	dir |= ({ loc });
      } else {
	dir = ({ loc });
      }
      TRACE_LEAVE("Added module mountpoint.");
    }
  }
  if(!dir) return verbose ? ({0})+locks : ([])[0];
  if(sizeof(dir))
  {
    TRACE_LEAVE(sprintf("Returning list of %d files.", sizeof(dir)));
    return dir;
  }
  TRACE_LEAVE("Returning 'No such directory'.");
  return 0;
}

// Stat a virtual file.

array(int)|Stat stat_file(string file, RequestID id)
{
  mixed s, tmp;
#ifdef THREADS
  Thread.MutexKey key;
#endif
  TRACE_ENTER(sprintf("Stat file %O.", file), 0);

  file=replace(file, "//", "/"); // "//" is really "/" here...

  if (has_prefix(file, internal_location)) {
    TRACE_LEAVE("");
    return 0;
  }
  
#ifdef URL_MODULES
  // Map URL-modules
  string of = id->not_query;
  id->not_query = file;
  foreach(url_module_cache||url_modules(), function funp)
  {
    TRACE_ENTER("URL module", funp);
    LOCK(funp);
    tmp=funp( id, file );
    UNLOCK();

    if (tmp) {
      if(mappingp( tmp )) {
	id->not_query = of;
	TRACE_LEAVE("");
	TRACE_LEAVE("Returned 'No thanks'.");
	return 0;
      }
      if(objectp( tmp ))
      {
	mixed err;
	id->misc->stat_file_nest++;
	TRACE_LEAVE("Recursing");
	err = catch {
	    if( id->misc->stat_file_nest < 20 )
	      tmp = (id->conf || this_object())->stat_file(id->not_query, id );
	    else
	      error("Too deep recursion in roxen::stat_file() while mapping "
		    +file+".\n");
	  };
	id->not_query = of;
	id->misc->stat_file_nest = 0;
	if(err)
	  throw(err);
	TRACE_LEAVE("");
	TRACE_LEAVE("Returning data");
	return tmp;
      }
    }
    TRACE_LEAVE("");
  }
  id->not_query = of;
#endif

  // Map location-modules.
  foreach(location_module_cache||location_modules(),
	  [string loc, function fun]) {
    if((file == loc) || ((file+"/")==loc))
    {
      TRACE_ENTER(sprintf("Location module [%s] ", loc), fun);
      TRACE_LEAVE("Exact match.");
      TRACE_LEAVE("");
      return Stdio.Stat(({ 0775, -3, 0, 0, 0, 0, 0 }));
    }
    if(has_prefix(file, loc))
    {
      TRACE_ENTER(sprintf("Location module [%s] ", loc), fun);
#ifdef MODULE_LEVEL_SECURITY
      if(check_security(fun, id)) {
	TRACE_LEAVE("");
	TRACE_LEAVE("Permission denied");
	continue;
      }
#endif
      if(s=function_object(fun)->stat_file(file[strlen(loc)..], id))
      {
	TRACE_LEAVE("");
	TRACE_LEAVE("Stat ok.");
	return s;
      }
      TRACE_LEAVE("");
    }
  }
  TRACE_LEAVE("Returned 'no such file'.");
}

mapping error_file( RequestID id )
{
  mapping res;
  // Avoid recursion in 404 messages.
  if (id->root_id->misc->generate_file_not_found ||
      //  The most popular 404 request ever? Skip the fancy error page.
      id->not_query == "/favicon.ico") {
    res = Roxen.http_string_answer("No such file", "text/plain");
    res->error = 404;
  } else {
    id->root_id->misc->generate_file_not_found = 1;
    string data = "<return code='404' />" + query("ZNoSuchFile");
#if ROXEN_COMPAT <= 2.1
    data = replace(data,({"$File", "$Me"}),
		   ({"&page.virtfile;", "&roxen.server;"}));
#endif
    res = Roxen.http_rxml_answer( data, id, 0, "text/html" );
    id->root_id->misc->generate_file_not_found = 0;
  }
  NOCACHE();
  return res;
}

mapping auth_failed_file( RequestID id, string message )
{
  // Avoid recursion in 401 messages. This could occur if the 401
  // messages used files that also cause access denied.
  if(id->root_id->misc->generate_auth_failed)
    return Roxen.http_low_answer(401, "<title>Access Denied</title>"
				 "<h2 align=center>Access Denied</h2>");
  id->root_id->misc->generate_auth_failed = 1;
  
  string data = "<return code='401' />" + query("ZAuthFailed");
  NOCACHE();
  mapping res = Roxen.http_rxml_answer( data, id, 0, "text/html" );
  id->root_id->misc->generate_auth_failed = 0;
  return res;
}

// this is not as trivial as it sounds. Consider gtext. :-)
array open_file(string fname, string mode, RequestID id, void|int internal_get,
		void|int recurse_count)
{
  mapping|int(0..1) file;
  string oq = id->not_query;

  if( id->conf && (id->conf != this_object()) )
    return id->conf->open_file( fname, mode, id, internal_get, recurse_count );

  if (recurse_count > 50) {
    TRACE_ENTER ("Looped " + recurse_count +
		 " times in internal redirects - giving up", 0);
    TRACE_LEAVE ("");
  }

  else {
    Configuration oc = id->conf;
    id->not_query = fname;
    TRY_FIRST_MODULES (file, open_file (fname, mode, id,
					internal_get, recurse_count + 1));
    fname = id->not_query;

    if(search(mode, "R")!=-1) //  raw (as in not parsed..)
    {
      string f;
      mode -= "R";
      if(f = real_file(fname, id))
      {
	// report_debug("opening "+fname+" in raw mode.\n");
	return ({ open(f, mode), ([]) });
      }
      // return ({ 0, (["error":302]) });
    }

    if(mode!="r") {
      id->not_query = oq;
      return ({ 0, (["error":501, "data":"Not implemented." ]) });
    }

    if(!file)
    {
      file = get_file( id, 0, internal_get );
      if(!file)
	TRY_LAST_MODULES (file, open_file (id->not_query, mode, id,
					   internal_get, recurse_count + 1));
    }
  }

  if(!mappingp(file))
  {
    if(id->misc->error_code)
      file = Roxen.http_low_answer(id->misc->error_code, "Failed" );
    else if(id->method!="GET"&&id->method != "HEAD"&&id->method!="POST")
      file = Roxen.http_low_answer(501, "Not implemented.");
    else
      file = error_file( id );

    id->not_query = oq;

    return ({ 0, file });
  }

  if( file->data )
  {
    file->file = StringFile(file->data);
    m_delete(file, "data");
  }
  id->not_query = oq;
  return ({ file->file || StringFile(""), file });
}


mapping(string:array(mixed)) find_dir_stat(string file, RequestID id)
{
  string loc;
  mapping(string:array(mixed)) dir = ([]);
  mixed d, tmp;


  file=replace(file, "//", "/");

  if(!sizeof (file) || file[0] != '/')
    file = "/" + file;

  // FIXME: Should I append a "/" to file if missing?

  TRACE_ENTER(sprintf("Request for directory and stat's \"%s\".", file), 0);

#ifdef URL_MODULES
#ifdef THREADS
  Thread.MutexKey key;
#endif
  // Map URL-modules
  foreach(url_modules(), function funp)
  {
    string of = id->not_query;
    id->not_query = file;
    LOCK(funp);
    TRACE_ENTER("URL module", funp);
    tmp=funp( id, file );
    UNLOCK();

    if(mappingp( tmp ))
    {
      id->not_query=of;
#ifdef MODULE_DEBUG
      report_debug("conf->find_dir_stat(\"%s\"): url_module returned mapping:%O\n",
		  file, tmp);
#endif /* MODULE_DEBUG */
      TRACE_LEAVE("Returned mapping.");
      TRACE_LEAVE("");
      return 0;
    }
    if(objectp( tmp ))
    {
      mixed err;
      id->misc->find_dir_stat_nest++;

      file = id->not_query;
      err = catch {
	if( id->misc->find_dir_stat_nest < 20 )
	  tmp = (id->conf || this_object())->find_dir_stat( file, id );
	else {
	  TRACE_LEAVE("Too deep recursion");
	  error("Too deep recursion in roxen::find_dir_stat() while mapping "
		+file+".\n");
	}
      };
      id->misc->find_dir_stat_nest = 0;
      if(err)
	throw(err);
#ifdef MODULE_DEBUG
      report_debug("conf->find_dir_stat(\"%s\"): url_module returned object:\n",
		  file);
#endif /* MODULE_DEBUG */
      TRACE_LEAVE("Returned object.");
      TRACE_LEAVE("Returning it.");
      return tmp;	// FIXME: Return 0 instead?
    }
    id->not_query=of;
    TRACE_LEAVE("");
  }
#endif /* URL_MODULES */

  foreach(location_modules(), tmp)
  {
    loc = tmp[0];

    TRACE_ENTER(sprintf("Location module [%s] ", loc), 0);
    /* Note that only new entries are added. */
    if(!search(file, loc))
    {
      /* file == loc + subpath */
#ifdef MODULE_LEVEL_SECURITY
      if(check_security(tmp[1], id)) {
	TRACE_LEAVE("Security check failed.");
	continue;
      }
#endif
      RoxenModule c = function_object(tmp[1]);
      string f = file[strlen(loc)..];
      if (c->find_dir_stat) {
	SIMPLE_TRACE_ENTER(c, "Calling find_dir_stat().");
	if (d = c->find_dir_stat(f, id)) {
	  SIMPLE_TRACE_LEAVE("Returned mapping with %d entries.", sizeof (d));
	  dir = d | dir;
	}
	else
	  SIMPLE_TRACE_LEAVE("Returned zero.");
      } else {
	SIMPLE_TRACE_ENTER(c, "Calling find_dir().");
	if(d = c->find_dir(f, id)) {
	  SIMPLE_TRACE_LEAVE("Returned array with %d entries.", sizeof (d));
	  dir = mkmapping(d, Array.map(d, lambda(string fn)
					  {
					    return c->stat_file(f + fn, id);
					  })) | dir;
	}
	else
	  SIMPLE_TRACE_LEAVE("Returned zero.");
      }
    } else if(search(loc, file)==0 && loc[strlen(file)-1]=='/' &&
	      (loc[0]==loc[-1]) && loc[-1]=='/' &&
	      (function_object(tmp[1])->stat_file(".", id))) {
      /* loc == file + "/" + subpath + "/"
       * and stat_file(".") returns non-zero.
       */
      TRACE_ENTER(sprintf("The file %O is on the path to the mountpoint %O.",
			  file, loc), 0);
      loc=loc[strlen(file)..];
      sscanf(loc, "%s/", loc);
      if (!dir[loc]) {
	dir[loc] = ({ 0775, -3, 0, 0, 0, 0, 0 });
      }
      TRACE_LEAVE("");
    }
    TRACE_LEAVE("");
  }
  if(sizeof(dir))
    return dir;
}


// Access a virtual file?

array access(string file, RequestID id)
{
  string loc;
  array s, tmp;

  file=replace(file, "//", "/"); // "//" is really "/" here...

  // Map location-modules.
  foreach(location_modules(), tmp)
  {
    loc = tmp[0];
    if((file+"/")==loc) {
#ifdef MODULE_LEVEL_SECURITY
      if(check_security(tmp[1], id)) continue;
#endif
      if(s=function_object(tmp[1])->access("", id))
	return s;
    } else if(!search(file, loc)) {
#ifdef MODULE_LEVEL_SECURITY
      if(check_security(tmp[1], id)) continue;
#endif
      if(s=function_object(tmp[1])->access(file[strlen(loc)..], id))
	return s;
    }
  }
  return 0;
}

string real_file(string file, RequestID id)
//! Return the _real_ filename of a virtual file, if any.
{
  string loc;
  string s;
  array tmp;
  file=replace(file, "//", "/"); // "//" is really "/" here...

  if(!id) error("No id passed to real_file");

  // Map location-modules.
  foreach(location_modules(), tmp)
  {
    loc = tmp[0];
    if(!search(file, loc))
    {
#ifdef MODULE_LEVEL_SECURITY
      if(check_security(tmp[1], id)) continue;
#endif
      if(s=function_object(tmp[1])->real_file(file[strlen(loc)..], id))
	return s;
    }
  }
}

array(int)|Stat try_stat_file(string s, RequestID id, int|void not_internal)
{
  RequestID fake_id;
  array(int)|Stat res;

  if(!objectp(id))
    error("No ID passed to 'try_stat_file'\n");

  // id->misc->common is here for compatibility; it's better to use
  // id->root_id->misc.
  if ( !id->misc )
    id->misc = ([]);

  fake_id = make_fake_id(s, id);

  fake_id->misc->internal_get = !not_internal;
  fake_id->method = "GET";

  res = stat_file(fake_id->not_query, fake_id);

  destruct (fake_id);
  return res;
}

protected RequestID make_fake_id (string s, RequestID id)
{
  RequestID fake_id;

  // id->misc->common is here for compatibility; it's better to use
  // id->root_id->misc.
  if ( !id->misc->common )
    id->misc->common = ([]);

  fake_id = id->clone_me();

  fake_id->misc->common = id->misc->common;
  fake_id->conf = this_object();

  fake_id->raw_url=s;

  if (fake_id->scan_for_query)
    // FIXME: If we're using e.g. ftp this doesn't exist. But the
    // right solution might be that clone_me() in an ftp id object
    // returns a vanilla (i.e. http) id instead when this function is
    // used.
    s = fake_id->scan_for_query (s);

  s = http_decode_string(s);

  s = Roxen.fix_relative (s, id);

  // s is sent to Unix API's that take NUL-terminated strings...
  if (search(s, "\0") != -1)
    sscanf(s, "%s\0", s);

  fake_id->not_query=s;

  return fake_id;
}

int|string try_get_file(string s, RequestID id,
			int|void stat_only, int|void nocache,
			int|void not_internal,
			mapping|void result_mapping)
//! Convenience function used in quite a lot of modules. Tries to read
//! a file into memory, and then returns the resulting string.
//!
//! NOTE: A 'file' can be a cgi script, which will be executed,
//! resulting in a horrible delay.
//!
//! Unless the not_internal flag is set, this tries to get an external
//! or internal file. Here "internal" means a file that never should be
//! sent directly as a request response. E.g. an internal redirect to a
//! different file is still considered "external" since its contents is
//! sent directly to the client. Internal requests are recognized by
//! the id->misc->internal_get flag being non-zero.
{
  string res;
  RequestID fake_id = make_fake_id (s, id);
  mapping m;

  fake_id->misc->internal_get = !not_internal;
  fake_id->method = "GET";

  array a = open_file( fake_id->not_query, "r", fake_id, !not_internal );

  m = a[1];

  // Propagate vary callbacks from the subrequest.
  id->propagate_vary_callbacks(fake_id);

  if (result_mapping) {
    foreach(indices(m), string i)
      result_mapping[i] = m[i];
    if (string|function(string:string) charset = fake_id->get_output_charset())
      // Note that a "charset" field currently isn't supported very
      // much in a response mapping. In particular, the http protocol
      // module doesn't look at it.
      //
      // Maybe we should read in the result and decode it using this
      // charset instead, just like we do in the m->raw case below.
      result_mapping->charset = charset;
    result_mapping->last_modified = fake_id->misc->last_modified;
  }

  if(a[0]) {
    m->file = a[0];
  }
  else {
    destruct (fake_id);
    return 0;
  }

  CACHE( fake_id->misc->cacheable );
  destruct (fake_id);

  // Allow 2* and 3* error codes, not only a few specific ones.
  if (!(< 0,2,3 >)[m->error/100]) return 0;

  if(stat_only) return 1;

  if(m->data)
    res = m->data;
  else
    res="";

  if( objectp(m->file) )
  {
    res += m->file->read();
    if (m->file) {
      // Some wrappers may destruct themselves in read()...
      destruct(m->file);
    }
  }

  if(m->raw) {
    if (compat_level() > 5.0)
      res = Roxen.parse_http_response (res, result_mapping, 0, "from " + s);
    else {
      // This function used to simply toss the headers and return the
      // data as-is, losing the content type and charset. Need to be
      // bug compatible with the lack of charset handling, since
      // callers might be compensating. (The old code also deleted all
      // CR's in the whole body, regardless of content type(!), but we
      // don't have to be bug compatible with that at least.)
      sscanf (res, "%*s\r\n\r\n%s", res) ||
	sscanf (res, "%*s\n\n%s", res) ||
	sscanf (res, "%*s\r\n%s", res) ||
	sscanf (res, "%*s\n%s", res);
    }
  }

  return res;
}

mapping(string:string) try_get_headers(string s, RequestID id,
				       int|void not_internal)
//! Like @[try_get_file] but performs a HEAD request and only returns
//! the response headers. Note that the returned headers are as they
//! would be in a formatted response by the http protocol module,
//! which is completely different from a response mapping.
{
  RequestID fake_id = make_fake_id (s, id);
  mapping m;

  fake_id->misc->internal_get = !not_internal;
  fake_id->method = "HEAD";

  array a = open_file( s, "r", fake_id, !not_internal );
  if(a && a[1]) {
    if (a[0]) a[0]->close();
    m = a[1];
  }
  else {
    destruct (fake_id);
    return 0;
  }

  CACHE( fake_id->misc->cacheable );

  if (!m->raw)
    m = fake_id->make_response_headers (m);

  else {
    Roxen.HeaderParser hp = Roxen.HeaderParser();
    array res;

    if(m->data)
      res = hp->feed (m->data);

    if (!res && objectp(m->file))
    {
      hp->feed (m->file->read());
      if (m->file) {
	// Some wrappers may destruct themselves in read()...
	destruct(m->file);
      }
    }

    m = res && res[2];
  }

  destruct (fake_id);
  return m;
}

mapping(string:mixed) try_put_file(string path, string data, RequestID id)
{
  TIMER_START(try_put_file);

  // id->misc->common is here for compatibility; it's better to use
  // id->root_id->misc.
  if ( !id->misc )
    id->misc = ([]);

  RequestID fake_id = make_fake_id(path, id);
  
  fake_id->root_id->misc->_request_depth++;
  if(sub_req_limit && fake_id->root_id->misc->_request_depth > sub_req_limit)
    error("Subrequest limit reached. (Possibly an insertion loop.)");

  fake_id->method = "PUT";
  fake_id->data = data;
  fake_id->misc->len = sizeof(data);
  fake_id->misc->internal_get = 1;

  mapping(string:mixed) res = low_get_file(fake_id, 1);
  TIMER_END(try_put_file);
  return res;
}

int(0..1) is_file(string virt_path, RequestID id, int(0..1)|void internal)
//! Is @[virt_path] a file in our virtual filesystem? If @[internal] is
//! set, internal files is "visible" as well.
{
  if(internal) {
    int(0..1) was_internal = id->misc->internal_get;
    id->misc->internal_get = 1;
    int(0..1) res = !!stat_file(virt_path, id);
    if(!was_internal)
      m_delete(id->misc, "internal_get");
    return res;
  }
  if(stat_file(virt_path, id) ||
     has_suffix(virt_path, "/internal-roxen-unit"))
    return 1;
  string f = (virt_path/"/")[-1];
  if( sscanf(f, "internal-roxen-%s", f) ) {
    if(internal_roxen_image(f, id) ||
       has_prefix(f, "pixel-"))
      return 1;
    return 0;
  }
  if( sscanf(f, "internal-gopher-%s", f) &&
      internal_gopher_image(f) )
    return 1;
  return 0;
}

array registered_urls = ({}), failed_urls = ({ });
array do_not_log_patterns = 0;
int start(int num)
{
  fix_my_url();

#if 0
  report_debug(sprintf("configuration:start():\n"
		       "  registered_urls: ({ %{%O, %}})\n"
		       "  failed_urls:     ({ %{%O, %}})\n"
		       "  URLs:            ({ %{%O, %}})\n",
		       registered_urls,
		       failed_urls,
		       query("URLs")));
#endif /* 0 */

  // Note: This is run as root if roxen is started as root
  foreach( (registered_urls-query("URLs"))+failed_urls, string url )
  {
    registered_urls -= ({ url });
    roxen.unregister_url(url, this_object());
  }

  failed_urls = ({ });

  foreach( (query( "URLs" )-registered_urls), string url )
  {
    if( roxen.register_url( url, this_object() ) )
      registered_urls += ({ url });
    else
      failed_urls += ({ url });
  }
  if( !datacache )
    datacache = DataCache( );
  else
    datacache->init_from_variables();

  parse_log_formats();
  init_log_file();
  do_not_log_patterns = query("NoLog");
  if(!sizeof(do_not_log_patterns))
    do_not_log_patterns = 0;

  if( query("throttle") )
  {
    if( !throttler )
      throttler=.throttler();
    throttler->throttle(query("throttle_fill_rate"),
                        query("throttle_bucket_depth"),
                        query("throttle_min_grant"),
                        query("throttle_max_grant"));
  }
  else if( throttler )
  {
    // This is done to give old connections more bandwidth.
    throttler->throttle( 1000000000, 1000000000, // 800Mbit.
			 1024, 65536 );
    // and new connections does not even have to care.
    throttler = 0;
  }

#ifdef SNMP_AGENT
  if(query("snmp_process") && objectp(roxen->snmpagent))
      roxen->snmpagent->add_virtserv(get_config_id());
#endif

  foreach(registered_urls, string url) {
    mapping(string:string|Configuration|Protocol) port_info = roxen.urls[url];

    foreach((port_info && port_info->ports) || ({}), Protocol prot) {
      if ((prot->prot_name != "snmp") || (!prot->mib)) {
	continue;
      }

      string path = port_info->path || "";
      if (has_prefix(path, "/")) {
	path = path[1..];
      }
      if (has_suffix(path, "/")) {
	path = path[..sizeof(path)-2];
      }
    
      array(int) oid_suffix = ({ sizeof(path), @((array(int))path) });

      ADT.Trie mib =
	SNMP.SimpleMIB(query_oid(), oid_suffix,
		       ({
			 UNDEFINED,
			 UNDEFINED,
			 SNMP.String(query_name, "siteName"),
			 SNMP.String(comment, "siteComment"),
			 SNMP.Counter64(lambda() { return sent; },
					"sent"),
			 SNMP.Counter64(lambda() { return received; },
					"received"),
			 SNMP.Counter64(lambda() { return hsent; },
					"sentHeaders"),
			 SNMP.Counter64(lambda() { return requests; },
					"numRequests"),
			 UNDEFINED,	// NOTE: Reserved for modules!
			 ({
			   UNDEFINED,
			   ({
			     UNDEFINED,
			     ({
			       UNDEFINED,
			       SNMP.Counter(lambda()
					    { return request_acc_time/10000; },
				 "requestTime",
				 "Accumulated total request time "
				 "in centiseconds."),
			     }),
			     ({
			       UNDEFINED,
			       SNMP.Counter(lambda() { return requests; },
					    "requestNumRuns",
					    "Total number of request runs."),
			       SNMP.Counter(lambda() { return request_num_runs_001s; },
					    "requestNumRuns001s",
					    "Number of request runs longer than 0.01 seconds."),
			       SNMP.Counter(lambda() { return request_num_runs_005s; },
					    "requestNumRuns005s",
					    "Number of request runs longer than 0.05 seconds."),
			       SNMP.Counter(lambda() { return request_num_runs_015s; },
					    "requestNumRuns015s",
					    "Number of request runs longer than 0.15 seconds."),
			       SNMP.Counter(lambda() { return request_num_runs_05s; },
					    "requestNumRuns05s",
					    "Number of request runs longer than 0.5 seconds."),
			       SNMP.Counter(lambda() { return request_num_runs_1s; },
					    "requestNumRuns1s",
					    "Number of request runs longer than 1 second."),
			       SNMP.Counter(lambda() { return request_num_runs_5s; },
					    "requestNumRuns5s",
					    "Number of request runs longer than 5 seconds."),
			       SNMP.Counter(lambda() { return request_num_runs_15s; },
					    "requestNumRuns15s",
					    "Number of request runs longer than 15 seconds."),
			     }),
			   }),
			   ({
			     UNDEFINED,
			     ({
			       UNDEFINED,
			       SNMP.Counter(lambda()
					    { return handle_acc_time/10000; },
				 "handleTime",
				 "Accumulated total handle time "
			       "in centiseconds."),
			     }),
			     ({
			       UNDEFINED,
			       SNMP.Counter(lambda() { return requests; },
					    "handleNumRuns",
					    "Total number of handle runs."),
			       SNMP.Counter(lambda() { return handle_num_runs_001s; },
					    "handleNumRuns001s",
					    "Number of handle runs longer than 0.01 seconds."),
			       SNMP.Counter(lambda() { return handle_num_runs_005s; },
					    "handleNumRuns005s",
					    "Number of handle runs longer than 0.05 seconds."),
			       SNMP.Counter(lambda() { return handle_num_runs_015s; },
					    "handleNumRuns015s",
					    "Number of handle runs longer than 0.15 seconds."),
			       SNMP.Counter(lambda() { return handle_num_runs_05s; },
					    "handleNumRuns05s",
					    "Number of handle runs longer than 0.5 seconds."),
			       SNMP.Counter(lambda() { return handle_num_runs_1s; },
					    "handleNumRuns1s",
					    "Number of handle runs longer than 1 second."),
			       SNMP.Counter(lambda() { return handle_num_runs_5s; },
					    "handleNumRuns5s",
					    "Number of handle runs longer than 5 seconds."),
			       SNMP.Counter(lambda() { return handle_num_runs_15s; },
					    "handleNumRuns15s",
					    "Number of handle runs longer than 15 seconds."),
			     }),
			   }),
			   ({
			     UNDEFINED,
			     ({
			       UNDEFINED,
			       SNMP.Counter(lambda()
					    { return queue_acc_time/10000; },
				 "queueTime",
				 "Accumulated total queue time "
				 "in centiseconds."),
			     }),
			     ({
			       UNDEFINED,
			       SNMP.Counter(lambda() { return requests; },
					    "queueNumRuns",
					    "Total number of queue runs."),
			       SNMP.Counter(lambda() { return queue_num_runs_001s; },
					    "queueNumRuns001s",
					    "Number of queue runs longer than 0.01 seconds."),
			       SNMP.Counter(lambda() { return queue_num_runs_005s; },
					    "queueNumRuns005s",
					    "Number of queue runs longer than 0.05 seconds."),
			       SNMP.Counter(lambda() { return queue_num_runs_015s; },
					    "queueNumRuns015s",
					    "Number of queue runs longer than 0.15 seconds."),
			       SNMP.Counter(lambda() { return queue_num_runs_05s; },
					    "queueNumRuns05s",
					    "Number of queue runs longer than 0.5 seconds."),
			       SNMP.Counter(lambda() { return queue_num_runs_1s; },
					    "queueNumRuns1s",
					    "Number of queue runs longer than 1 second."),
			       SNMP.Counter(lambda() { return queue_num_runs_5s; },
					    "queueNumRuns5s",
					    "Number of queue runs longer than 5 seconds."),
			       SNMP.Counter(lambda() { return queue_num_runs_15s; },
					    "queueNumRuns15s",
					    "Number of queue runs longer than 15 seconds."),
			     }),
			   })
			 }),
			 ({
			   UNDEFINED,
			   SNMP.Counter(lambda()
					{ return datacache->hits + datacache->misses; },
			     "protCacheLookups",
			     "Number of protocol cache lookups."),
			   SNMP.Counter(lambda()
					{ return datacache->hits; },
			     "protCacheHits",
			     "Number of protocol cache hits."),
			   SNMP.Counter(lambda()
					{ return datacache->misses; },
			     "protCacheMisses",
			     "Number of protocol cache misses."),
			   SNMP.Gauge(lambda()
				      { return sizeof(datacache->cache); },
			     "protCacheEntries",
			     "Number of protocol cache entries."),
			   SNMP.Gauge(lambda()
				      { return datacache->max_size/1024; },
			     "protCacheMaxSize",
			     "Maximum size of protocol cache in KiB."),
			   SNMP.Gauge(lambda()
				      { return datacache->current_size/1024; },
			     "protCacheCurrSize",
			     "Current size of protocol cache in KiB."),
			 })
		       }));
      SNMP.set_owner(mib, this_object());
      prot->mib->merge(mib);
    }
  }

  if (retrieve ("EnabledModules", this)["config_filesystem#0"])
    return 1;			// Signal that this is the admin UI config.
  return 0;
}

// ([func: ([mod_name: ({cb, cb, ...})])])
protected mapping(string:
		  mapping(string:
			  array(function(RoxenModule,mixed...:void))))
  module_pre_callbacks = ([]), module_post_callbacks = ([]);

void add_module_pre_callback (string mod_name, string func,
			      function(RoxenModule,mixed...:void) cb)
{
  ASSERT_IF_DEBUG ((<"start", "stop">)[func]);
  mapping(string:array(function(RoxenModule,mixed...:void))) func_cbs =
    module_pre_callbacks[func] || (module_pre_callbacks[func] = ([]));
  if (func_cbs[mod_name] && has_value (func_cbs[mod_name], cb))
    return;
  func_cbs[mod_name] += ({cb});
}

void delete_module_pre_callback (string mod_name, string func,
				 function(RoxenModule,mixed...:void) cb)
{
  if (mapping(string:array(function(RoxenModule,mixed...:void))) func_cbs =
      module_pre_callbacks[func])
    if (func_cbs[mod_name])
      func_cbs[mod_name] -= ({cb});
}

void add_module_post_callback (string mod_name, string func,
			       function(RoxenModule,mixed...:void) cb)
{
  ASSERT_IF_DEBUG ((<"start", "stop">)[func]);
  mapping(string:array(function(RoxenModule,mixed...:void))) func_cbs =
    module_post_callbacks[func] || (module_post_callbacks[func] = ([]));
  if (func_cbs[mod_name] && has_value (func_cbs[mod_name], cb))
    return;
  func_cbs[mod_name] += ({cb});
}

void delete_module_post_callback (string mod_name, string func,
				  function(RoxenModule,mixed...:void) cb)
{
  if (mapping(string:array(function(RoxenModule,mixed...:void))) func_cbs =
      module_post_callbacks[func])
    if (func_cbs[mod_name])
      func_cbs[mod_name] -= ({cb});
}

void call_module_func_with_cbs (RoxenModule mod, string func, mixed... args)
{
  string mod_name;

  if (mapping(string:array(function(RoxenModule,mixed...:void))) func_cbs =
      module_pre_callbacks[func]) {
    sscanf (mod->module_local_id(), "%[^#]", mod_name);
    array(function(RoxenModule,mixed...:void)) cbs;
    if (array(function(RoxenModule,mixed...:void)) a = func_cbs[mod_name]) {
      func_cbs[mod_name] = (a -= ({0}));
      cbs = a;
    }
    if (array(function(RoxenModule,mixed...:void)) a = func_cbs[0]) {
      func_cbs[0] = (a -= ({0}));
      if (cbs) cbs += a; else cbs = a;
    }
    if (cbs) {
      foreach (cbs, function(RoxenModule,mixed...:void) cb) {
#ifdef MODULE_CB_DEBUG
	werror ("Calling callback before %O->%s: %O\n", mod, func, cb);
#endif
	if (mixed err = catch (cb (mod, @args)))
	  report_error ("Error calling callback %O before %O->%s:\n%s\n",
			cb, mod, func, describe_backtrace (err));
      }
    }
  }

  // Exceptions thrown here are the responsibility of the caller.
#ifdef MODULE_CB_DEBUG
  werror ("Calling %O->%s (%s)\n", mod, func,
	  map (args, lambda (mixed arg)
		       {return sprintf ("%O", arg);}) * ", ");
#endif
  mod[func] (@args);

  if (mapping(string:array(function(RoxenModule,mixed...:void))) func_cbs =
      module_post_callbacks[func]) {
    if (!mod_name)
      sscanf (otomod[mod] || mod->module_local_id(), "%[^#]", mod_name);
    array(function(RoxenModule,mixed...:void)) cbs;
    if (array(function(RoxenModule,mixed...:void)) a = func_cbs[mod_name]) {
      func_cbs[mod_name] = (a -= ({0}));
      cbs = a;
    }
    if (array(function(RoxenModule,mixed...:void)) a = func_cbs[0]) {
      func_cbs[0] = (a -= ({0}));
      if (cbs) cbs += a; else cbs = a;
    }
    if (cbs) {
      foreach (cbs, function(RoxenModule,mixed...:void) cb) {
#ifdef MODULE_CB_DEBUG
	werror ("Calling callback after %O->%s: %O\n", mod, func, cb);
#endif
	if (mixed err = catch (cb (mod, @args)))
	  report_error ("Error calling callback %O after %O->%s:\n%s\n",
			cb, mod, func, describe_backtrace (err));
      }
    }
  }
}

void save_me()
{
  save_one( 0 );
}

void save(int|void all)
//! Save this configuration. If all is included, save all configuration
//! global variables as well, otherwise only all module variables.
{
  if(all)
  {
    store("spider#0", variables, 0, this_object());
    start(2);
  }

  store( "EnabledModules", enabled_modules, 1, this_object());
  foreach(indices(modules), string modname)
  {
    foreach(indices(modules[modname]->copies), int i)
    {
      RoxenModule mod = modules[modname]->copies[i];
      store(modname+"#"+i, mod->query(), 0, this);
      if (mixed err = mod->start && catch {
	  call_module_func_with_cbs (mod, "start", 2, this, 0);
	})
	report_error("Error calling start in module.\n%s",
		     describe_backtrace (err));
    }
  }
  invalidate_cache();
}

int save_one( RoxenModule o )
//! Save all variables in a given module.
{
  if(!o)
  {
    store("spider#0", variables, 0, this_object());
    start(2);
    return 1;
  }
  string q = otomod[ o ];
  if( !q )
    error("Invalid module");

  store(q, o->query(), 0, this_object());
  invalidate_cache();
  mixed error;
  if( o->start &&
      (error = catch( call_module_func_with_cbs (o, "start", 2, this, 0) )) )
  {
    if( objectp(error ) )
      error = (array)error;
    if( sizeof(error)>1 && arrayp( error[1] ) )
    {
      int i;
      for( i = 0; i<sizeof( error[1] ); i++ )
	if( error[1][i][2] == save_one )
	  break;
      error[1] = error[1][i+1..];
    }
    if( o->report_error )
      o->report_error( "Call to start failed.\n"+describe_backtrace( error ) );
    else
      report_error( "Call to start failed.\n"+describe_backtrace( error ));
  }
  invalidate_cache();
  return 1;
}

RoxenModule reload_module( string modname )
{
  RoxenModule old_module = find_module( modname );
  sscanf (modname, "%s#%d", string base_modname, int mod_copy);
  ModuleInfo mi = roxen.find_module( base_modname );

  if( !old_module ) return 0;

  // Temporarily shift out of the rxml parsing context if we're inside
  // any (e.g. due to delayed loading from inside the admin
  // interface).
  RXML.Context old_ctx = RXML.get_context();
  RXML.set_context (0);
  mixed err = catch {

      master()->clear_compilation_failures();

      if( !old_module->not_a_module )
      {
	save_one( old_module );
	master()->refresh_inherit( object_program( old_module ) );
	master()->refresh( object_program( old_module ), 1 );
      }

      array old_error_log = (array) old_module->error_log;

      RoxenModule nm;

      // Load up a new instance.
      nm = mi->instance( this_object(), 0, mod_copy);
      // If this is a faked module, let's call it a failure.
      if (nm->module_is_disabled)
	report_notice (LOC_C(1047, "Module is disabled") + "\n");
      else if( nm->not_a_module )
      {
	old_module->report_error(LOC_C(385,"Reload failed")+"\n");
	RXML.set_context (old_ctx);
	return old_module;
      }

      disable_module( modname, nm );
      destruct( old_module ); 

      mixed err = catch {
	  mi->update_with( nm,0 ); // This is sort of nessesary...
	};
      if (err)
	if (stringp (err)) {
	  // Error from the register_module call. We can't enable the old
	  // module now, and I don't dare changing the order so that
	  // register_module starts to get called before the old module is
	  // destructed. /mast
	  report_error (err);
	  report_error(LOC_C(385,"Reload failed")+"\n");
	  RXML.set_context (old_ctx);
	  return 0;			// Use a placeholder module instead?
	}
	else
	  throw (err);
      enable_module( modname, nm, mi );

      foreach (old_error_log, [string msg, array(int) times])
	nm->error_log[msg] += times;

      nm->report_notice(LOC_C(11, "Reloaded %s.")+"\n", mi->get_name());
      RXML.set_context (old_ctx);
      return nm;

    };
  RXML.set_context (old_ctx);
  throw (err);
}

void reload_all_modules()
{
  if (!inited)
    enable_all_modules();
  else {
    foreach (enabled_modules; string modname;)
      reload_module (modname);
  }
}

#ifdef THREADS
Thread.Mutex enable_modules_mutex = Thread.Mutex();
#define MODULE_LOCK(TYPE) \
  Thread.MutexKey enable_modules_lock = enable_modules_mutex->lock (TYPE)
#else
#define MODULE_LOCK(TYPE)
#endif

protected int enable_module_batch_msgs;

RoxenModule enable_module( string modname, RoxenModule|void me, 
                           ModuleInfo|void moduleinfo, 
                           int|void nostart, int|void nosave )
{
  MODULE_LOCK (2);
  int id;
  ModuleCopies module;
  mixed err;
  int module_type;

  if( forcibly_added[modname] == 2 )
    return search(otomod, modname);
  
  if( datacache ) datacache->flush();

  if( sscanf(modname, "%s#%d", modname, id ) != 2 )
    while( modules[ modname ] && modules[ modname ][ id ] )
      id++;

#ifdef DEBUG
  if (mixed init_info = roxen->bootstrap_info->get())
    if (arrayp (init_info))
      error ("Invalid recursive call to enable_module while enabling %O/%s.\n",
	     init_info[0], init_info[1]);
#endif

#ifdef MODULE_DEBUG
  int start_time = gethrtime();
#endif

  if( !moduleinfo )
  {
    moduleinfo = roxen->find_module( modname );

    if (!moduleinfo)
    {
      report_warning("Failed to load %s. The module probably "
                     "doesn't exist in the module path.\n", modname);
      got_no_delayed_load = -1;
      return 0;
    }
  }

  string descr = moduleinfo->get_name() + (id ? " copy " + (id + 1) : "");
  //  sscanf(descr, "%*s: %s", descr);

#ifdef MODULE_DEBUG
  if (enable_module_batch_msgs)
    report_debug(" %-43s... \b", descr );
  else
    report_debug("Enabling " + descr + "\n");
#endif

  module = modules[ modname ];

  if(!module)
    modules[ modname ] = module = ModuleCopies();

  if( !me )
  {
    if(err = catch(me = moduleinfo->instance(this_object(), 0, id)))
    {
#ifdef MODULE_DEBUG
      if (enable_module_batch_msgs) report_debug("\bERROR\n");
      if (err != "") {
#endif
	string bt=describe_backtrace(err);
	report_error("enable_module(): " +
		     LOC_M(41, "Error while initiating module copy of %s%s"),
		     moduleinfo->get_name(), (bt ? ":\n"+bt : "\n"));
#ifdef MODULE_DEBUG
      }
#endif
      got_no_delayed_load = -1;
      return module[id];
    }
  }

  if(module[id] && module[id] != me)
  {
    // Don't know when this happens, because reload_module has already
    // called disable_module on the old instance.
    if( module[id]->stop ) {
      if (err = catch( call_module_func_with_cbs (module[id], "stop", me) )) {
	string bt=describe_backtrace(err);
	report_error("disable_module(): " +
		     LOC_M(44, "Error while disabling module %s%s"),
		     descr, (bt ? ":\n"+bt : "\n"));
      }
    }
  }

  me->set_configuration( this_object() );

  module_type = moduleinfo->type;
  if (module_type & MODULE_TYPE_MASK)
  {
    if(!(module_type & MODULE_CONFIG))
    {
      if (err = catch {
	me->defvar("_priority", 5, DLOCALE(12, "Priority"), TYPE_INT_LIST,
		   DLOCALE(13, "The priority of the module. 9 is highest and 0 is lowest."
		   " Modules with the same priority can be assumed to be "
		   "called in random order."),
		   ({0, 1, 2, 3, 4, 5, 6, 7, 8, 9}));
      }) {
	throw(err);
      }
    }

#ifdef MODULE_LEVEL_SECURITY
    if( (module_type & ~(MODULE_LOGGER|MODULE_PROVIDER|MODULE_USERDB)) != 0 )
    {
//       me->defvar("_sec_group", "user", DLOCALE(14, "Security: Realm"), 
// 		 TYPE_STRING,
// 		 DLOCALE(15, "The realm to use when requesting password from the "
// 			 "client. Usually used as an informative message to the "
// 			 "user."));
      
      me->defvar("_seclevels", "", DLOCALE(16, "Security: Patterns"), 
		 TYPE_TEXT_FIELD,
		 DLOCALE(245,
			 "The syntax is:\n"
			 " \n<dl>"
			 "  <dt><b>userdb</b> <i>userdatabase module</i></dt>\n"
			 "  <dd> Select a non-default userdatabase module. The default is to "
			 " search all modules. The userdatabase module config_userdb is always "
			 " present, and contains the configuration users</dd>\n"
			 "<dt><b>authmethod</b> <i>authentication module</i></dt>\n"
			 "<dd>Select a non-default authentication method.</dd>"
			 "<dt><b>realm</b> <i>realm name</i></dt>\n"
			 "<dd>The realm is used when user authentication info is requested</dd>"
			 "</dl>\n"
			 "  Below, CMD is one of 'allow' and 'deny'\n"
			 " <dl>\n"
			 "  <dt>CMD <b>ip</b>=<i>ip/bits</i>  [return]<br />\n"
			 "  CMD <b>ip</b>=<i>ip:mask</i>  [return] <br />\n"
			 "  CMD <b>ip</b>=<i>pattern[,pattern,...]</i>  [return] <br /></dt>\n"
			 "  <dd>Match the remote IP-address.</dd>\n"
			 " \n"
			 "  <dt>CMD <b>user</b>=<i>name[,name,...]</i>  [return]</dt>\n"
			 "  <dd>Requires an authenticated user. If the user name 'any' is used, any "
			 "valid user will be OK; if the user name 'ANY' is used, "
			 "a valid user is preferred, but not required. "
			 "Otherwise, one of the listed users is required.</dd>"
			 "  <dt>CMD <b>group</b>=<i>name[,name,...]</i> [return]</dt>\n"
			 "<dd>Requires an authenticated user with a group. If the group name "
			 " 'any' is used, any valid group will be OK. Otherwise, one of the "
			 "listed groups are required.</dd>\n"
			 " \n"
			 "<dt>CMD <b>dns</b>=<i>pattern[,pattern,...]</i>           [return]</dt>\n"
			 "<dd>Require one of the specified DNS domain-names</dd>"
			 " \n"
			 "<dt>CMD <b>time</b>=<i>HH:mm-HH:mm</i>   [return]</dt>\n"
			 "<dd>Only allow access to the module from the first time to the "
			 " second each day. Both times should be specified in 24-hour "
			 " HH:mm format.</dd>\n"
			 "<dt>CMD <b>day</b>=<i>day[,day,...]</i> [return]</dt>\n"
			 "<dd>Only allow access during certain days. Day is either a numerical "
			 "    value (Monday=1, Sunday=7) or a string (monday, tuesday etc)</dd>"
			 "</dl><p>\n"
			 "  pattern is always a glob pattern (* = any characters, ? = any character).\n"
			 "</p><p>\n"
			 "  return means that reaching this command results in immediate\n"
			 "  return, only useful for 'allow'.</p>\n"
			 " \n"
			 " <p>'deny' always implies a return, no futher testing is done if a\n"
			 " 'deny' match.</p>\n"));

      if(!(module_type & MODULE_PROXY))
      {
	me->defvar("_seclvl",  0, DLOCALE(18, "Security: Security level"), 
		   TYPE_INT,
		   DLOCALE(305, "The modules security level is used to determine if a "
		   " request should be handled by the module."
		   "\n<p><h2>Security level vs Trust level</h2>"
		   " Each module has a configurable <i>security level</i>."
		   " Each request has an assigned trust level. Higher"
		   " <i>trust levels</i> grants access to modules with higher"
		   " <i>security levels</i>."
		   "\n<p><h2>Definitions</h2><ul>"
		   " <li>A requests initial trust level is infinitely high.</li>"
		   " <li> A request will only be handled by a module if its"
		   "     <i>trust level</i> is higher or equal to the"
		   "     <i>security level</i> of the module.</li>"
		   " <li> Each time the request is handled by a module the"
		   "     <i>trust level</i> of the request will be set to the"
		   "      lower of its <i>trust level</i> and the modules"
	           "     <i>security level</i>, <i>unless</i> the security "
	           "        level of the module is 0, which is a special "
	           "        case and means that no change should be made.</li>"
		   " </ul></p>"
		   "\n<p><h2>Example</h2>"
		   " Modules:<ul>"
		   " <li>  User filesystem, <i>security level</i> 1</li>"
		   " <li>  Filesystem module, <i>security level</i> 3</li>"
		   " <li>  CGI module, <i>security level</i> 2</li>"
		   " </ul></p>"
		   "\n<p>A request handled by \"User filesystem\" is assigned"
		   " a <i>trust level</i> of one after the <i>security"
		   " level</i> of that module. That request can then not be"
		   " handled by the \"CGI module\" since that module has a"
		   " higher <i>security level</i> than the requests trust"
		   " level.</p>"
		   "\n<p>On the other hand, a request handled by the the"
		   " \"Filesystem module\" could later be handled by the"
		   " \"CGI module\".</p>"));

      } else {
	me->definvisvar("_seclvl", -10, TYPE_INT); /* A very low one */
      }
    }
#endif
  } else {
    me->defvar("_priority", 0, "", TYPE_INT, "", 0, 1);
  }

  if (!module[id])
    counters[moduleinfo->counter]++;

  module[ id ] = me;
  otomod[ me ] = modname+"#"+id;
  module_set_counter++;

  // Below we may have recursive calls to this function. They may
  // occur already in setvars due to e.g. automatic dependencies in
  // Variable.ModuleChoice.

  mapping(string:mixed) stored_vars = retrieve(modname + "#" + id, this_object());
  int has_stored_vars = sizeof (stored_vars); // A little ugly, but it suffices.
  me->setvars(stored_vars);

  if (me->not_a_module) nostart = 1;

  if(!nostart) call_start_callbacks( me, moduleinfo, module );

#ifdef MODULE_DEBUG
  if (enable_module_batch_msgs) {
    if(moduleinfo->config_locked[this_object()])
      report_debug("\bLocked %6.1fms\n", (gethrtime()-start_time)/1000.0);
    else if (me->not_a_module)
      report_debug("\bN/A %6.1fms\n", (gethrtime()-start_time)/1000.0);
    else
      report_debug("\bOK %6.1fms\n", (gethrtime()-start_time)/1000.0);
  }
#else
  if(moduleinfo->config_locked[this_object()])
    report_error("   Error: \"%s\" not loaded (license restriction).\n",
		 moduleinfo->get_name());
  else if (me->not_a_module)
    report_debug("   Note: \"%s\" not available.\n", moduleinfo->get_name());
#endif
  if( !enabled_modules[modname+"#"+id] )
  {
    enabled_modules[modname+"#"+id] = 1;
    if(!nosave)
      store( "EnabledModules", enabled_modules, 1, this_object());
  }

  if (!has_stored_vars && !nosave)
    store (modname + "#" + id, me->query(), 0, this_object());

  if( me->no_delayed_load && got_no_delayed_load >= 0 )
    got_no_delayed_load = 1;

  return me;
}

void call_start_callbacks( RoxenModule me, 
                           ModuleInfo moduleinfo, 
			   ModuleCopies module,
			   void|int newly_added)
{
  call_low_start_callbacks(  me, moduleinfo, module );
  call_high_start_callbacks (me, moduleinfo, newly_added);
}

void call_low_start_callbacks( RoxenModule me, 
			       ModuleInfo moduleinfo, 
			       ModuleCopies module )
{
  if(!me) return;
  if(!moduleinfo) return;
  if(!module) return;

  int module_type = moduleinfo->type, pr;
  mixed err;
  if (err = catch(pr = me->query("_priority")))
  {
#ifdef MODULE_DEBUG
    if (enable_module_batch_msgs) report_debug("\bERROR\n");
#endif
    string bt=describe_backtrace(err);
    report_error(LOC_M(41, "Error while initiating module copy of %s%s"),
			moduleinfo->get_name(), (bt ? ":\n"+bt : "\n"));
    pr = 3;
  }

  api_module_cache |= me->api_functions();

  if(module_type & MODULE_EXTENSION)
  {
    report_error("%s is an MODULE_EXTENSION, that type is no "
		 "longer available.\nPlease notify the modules writer.\n"
		 "Suitable replacement types include MODULE_FIRST and "
		 " MODULE_LAST.\n", moduleinfo->get_name());
  }

  if(module_type & MODULE_FILE_EXTENSION)
    if (err = catch {
      array arr = me->query_file_extensions();
      if (arrayp(arr))
      {
	string foo;
	foreach( me->query_file_extensions(), foo )
	  if(pri[pr]->file_extension_modules[foo = lower_case(foo)] )
	    pri[pr]->file_extension_modules[foo] += ({me});
	  else
	    pri[pr]->file_extension_modules[foo] = ({me});
      }
    }) {
#ifdef MODULE_DEBUG
      if (enable_module_batch_msgs) report_debug("\bERROR\n");
#endif
      string bt=describe_backtrace(err);
      report_error(LOC_M(41, "Error while initiating module copy of %s%s"),
		   moduleinfo->get_name(), (bt ? ":\n"+bt : "\n"));
      got_no_delayed_load = -1;
    }

  if(module_type & MODULE_PROVIDER)
    if (err = catch
    {
      mixed provs = me->query_provides ? me->query_provides() : ({});
      if(stringp(provs))
	provs = (< provs >);
      if(arrayp(provs))
	provs = mkmultiset(provs);
      if (multisetp(provs)) {
	pri[pr]->provider_modules [ me ] = provs;
      }
    }) {
#ifdef MODULE_DEBUG
      if (enable_module_batch_msgs) report_debug("\bERROR\n");
#endif
      string bt=describe_backtrace(err);
      report_error(LOC_M(41, "Error while initiating module copy of %s%s"),
		   moduleinfo->get_name(), (bt ? ":\n"+bt : "\n"));
      got_no_delayed_load = -1;
    }

  if(module_type & MODULE_TYPES)
  {
    types_module = me;
    types_fun = me->type_from_extension;
  }

  if(module_type & MODULE_TAG)
    add_parse_module( me );

  if(module_type & MODULE_DIRECTORIES)
    if (me->parse_directory)
      dir_module = me;

  if(module_type & MODULE_LOCATION)
    pri[pr]->location_modules += ({ me });

  if(module_type & MODULE_LOGGER)
    pri[pr]->logger_modules += ({ me });

  if(module_type & MODULE_URL)
    pri[pr]->url_modules += ({ me });

  if(module_type & MODULE_LAST)
    pri[pr]->last_modules += ({ me });

  if(module_type & MODULE_FILTER)
    pri[pr]->filter_modules += ({ me });

  if(module_type & MODULE_FIRST)
    pri[pr]->first_modules += ({ me });

  foreach(registered_urls, string url) {
    mapping(string:string|Configuration|Protocol) port_info = roxen.urls[url];

    foreach((port_info && port_info->ports) || ({}), Protocol prot) {
      if ((prot->prot_name != "snmp") || (!prot->mib)) {
	continue;
      }

      string path = port_info->path || "";
      if (has_prefix(path, "/")) {
	path = path[1..];
      }
      if (has_suffix(path, "/")) {
	path = path[..sizeof(path)-2];
      }
    
      array(int) oid_suffix = ({ sizeof(path), @((array(int))path) });

      ADT.Trie sub_mib = generate_module_mib(query_oid() + ({ 8, 1 }),
					     oid_suffix, me, moduleinfo, module);
      SNMP.set_owner(sub_mib, this_object(), me);

      prot->mib->merge(sub_mib);

      if (me->query_snmp_mib) {
	array(int) segment = generate_module_oid_segment(me);
	sub_mib = me->query_snmp_mib(query_oid() + ({ 8, 2 }) +
				     segment[..sizeof(segment)-2],
				     oid_suffix + ({ segment[-1] }));
	SNMP.set_owner(sub_mib, this_object(), me);
	prot->mib->merge(sub_mib);
      }
    }
  }

  invalidate_cache();
}

void call_high_start_callbacks (RoxenModule me, ModuleInfo moduleinfo,
				void|int newly_added)
{
  // This is icky, but I don't know if it's safe to remove. /mast
  if(!me) return;
  if(!moduleinfo) return;

  mixed err;
  if((me->start) &&
     (err = catch( call_module_func_with_cbs (me, "start",
					      0, this, newly_added) ) ) )
  {
#ifdef MODULE_DEBUG
    if (enable_module_batch_msgs) 
      report_debug("\bERROR\n");
#endif
    string bt=describe_backtrace(err);
    report_error(LOC_M(41, "Error while initiating module copy of %s%s"),
			moduleinfo->get_name(), (bt ? ":\n"+bt : "\n"));
    got_no_delayed_load = -1;
  }
  if( inited && me->ready_to_receive_requests )
    if( mixed q = catch( me->ready_to_receive_requests( this_object() ) ) ) 
    {
#ifdef MODULE_DEBUG
      if (enable_module_batch_msgs) report_debug("\bERROR\n");
#endif
      report_error( "While calling ready_to_receive_requests:\n"+
		    describe_backtrace( q ) );
      got_no_delayed_load = -1;
    }
}

// Called from the administration interface.
string check_variable(string name, mixed value)
{
  switch(name)
  {
//    case "MyWorldLocation":
//     if(strlen(value)<7 || value[-1] != '/' ||
//        !(sscanf(value,"%*s://%*s/")==2))
//       return LOCALE->url_format();
//     return 0;
  case "MyWorldLocation":
  case "URLs":
    fix_my_url();
    return 0;
//    case "throttle":
//      // There was code here to sett the throttling. That's not a
//      // good idea. Moved to start. The code now also avoids
//      // creating new throttle objects each time a value is changed.
//    case "throttle_fill_rate":
//    case "throttle_bucket_depth":
//    case "throttle_min_grant":
//    case "throttle_max_grant":
//      return 0;
#ifdef SNMP_AGENT
  case "snmp_process":
    if (objectp(roxen->snmpagent)) {
      int cid = get_config_id();
      value ? roxen->snmpagent->add_virtserv(cid) : roxen->snmpagent->del_virtserv(cid);
    }
    return 0;
#endif
  }
}

void module_changed( ModuleInfo moduleinfo,
		     RoxenModule me  )
{
  clean_up_for_module( moduleinfo, me );
  call_low_start_callbacks( me,
			    moduleinfo,
			    modules[ moduleinfo->sname ] );
}

void clean_up_for_module( ModuleInfo moduleinfo,
			  RoxenModule me )
{
  int pr;
  if(moduleinfo->type & MODULE_FILE_EXTENSION)
  {
    string foo;
    for(pr=0; pr<10; pr++)
      foreach( indices (pri[pr]->file_extension_modules), foo )
	pri[pr]->file_extension_modules[foo]-=({me});
  }

  if(moduleinfo->type & MODULE_PROVIDER) {
    for(pr=0; pr<10; pr++)
      m_delete(pri[pr]->provider_modules, me);
  }

  if(moduleinfo->type & MODULE_TYPES)
  {
    types_module = 0;
    types_fun = 0;
  }

  if(moduleinfo->type & MODULE_TAG)
    remove_parse_module( me );

  if( moduleinfo->type & MODULE_DIRECTORIES )
    dir_module = 0;

  if( moduleinfo->type & MODULE_LOCATION )
    for(pr=0; pr<10; pr++)
     pri[pr]->location_modules -= ({ me });

  if( moduleinfo->type & MODULE_URL )
    for(pr=0; pr<10; pr++)
      pri[pr]->url_modules -= ({ me });

  if( moduleinfo->type & MODULE_LAST )
    for(pr=0; pr<10; pr++)
      pri[pr]->last_modules -= ({ me });

  if( moduleinfo->type & MODULE_FILTER )
    for(pr=0; pr<10; pr++)
      pri[pr]->filter_modules -= ({ me });

  if( moduleinfo->type & MODULE_FIRST ) {
    for(pr=0; pr<10; pr++)
      pri[pr]->first_modules -= ({ me });
  }

  if( moduleinfo->type & MODULE_LOGGER )
    for(pr=0; pr<10; pr++)
      pri[pr]->logger_modules -= ({ me });

  foreach(registered_urls, string url) {
    mapping(string:string|Configuration|Protocol) port_info = roxen.urls[url];
    foreach((port_info && port_info->ports) || ({}), Protocol prot) {
      if ((prot->prot_name != "snmp") || (!prot->mib)) {
	continue;
      }

      SNMP.remove_owned(prot->mib, this_object(), me);
    }
  }
}

int disable_module( string modname, void|RoxenModule new_instance )
{
  MODULE_LOCK (2);
  RoxenModule me;
  int id;
  sscanf(modname, "%s#%d", modname, id );

  if( datacache ) datacache->flush();

  ModuleInfo moduleinfo =  roxen.find_module( modname );
  mapping module = modules[ modname ];
  string descr = moduleinfo->get_name() + (id ? " copy " + (id + 1) : "");

  if(!module)
  {
    report_error("disable_module(): " +
		 LOC_M(42, "Failed to disable module:\n"
			"No module by that name: \"%s\".\n"), modname);
    return 0;
  }

  me = module[id];
  m_delete(module->copies, id);
  module_set_counter++;

  if(!sizeof(module->copies))
    m_delete( modules, modname );

  if (moduleinfo->counter) {
    counters[moduleinfo->counter]--;
  }

  invalidate_cache();

  if(!me)
  {
    report_error("disable_module(): " +
		 LOC_M(43, "Failed to disable module \"%s\".\n"),
		 descr);
    return 0;
  }

  if(me->stop)
    if (mixed err = catch (
	  call_module_func_with_cbs (me, "stop", new_instance)
	)) {
      string bt=describe_backtrace(err);
      report_error("disable_module(): " +
		   LOC_M(44, "Error while disabling module %s%s"),
		   descr, (bt ? ":\n"+bt : "\n"));
    }

#ifdef MODULE_DEBUG
  report_debug("Disabling "+descr+"\n");
#endif

  clean_up_for_module( moduleinfo, me );

  if( !new_instance )
  {
    // Not a reload, so it's being dropped.
    m_delete( enabled_modules, modname + "#" + id );
    m_delete( forcibly_added, modname + "#" + id );
    store( "EnabledModules",enabled_modules, 1, this_object());
    destruct(me);
  }
  return 1;
}

RoxenModule find_module(string name)
//! Return the module corresponding to the name (eg "rxmlparse",
//! "rxmlparse#0" or "filesystem#1") or zero, if there was no such
//! module. The string is on the same format as the one returned by
//! @[RoxenModule.module_local_id].
{
  int id;
  sscanf(name, "%s#%d", name, id);
  if(modules[name])
    return modules[name]->copies[id];
  return 0;
}

mapping forcibly_added = ([]);
int add_modules( array(string) mods, int|void now )
{
#ifdef MODULE_DEBUG
  int wr;
#endif
  foreach (mods, string mod)
  {
    sscanf( mod, "%s#", mod );
    if( ((now && !modules[ mod ]) ||
         !enabled_modules[ mod+"#0" ] )
        && !forcibly_added[ mod+"#0" ])
    {
#ifdef MODULE_DEBUG
      if( !wr++ )
	if (enable_module_batch_msgs)
	  report_debug("\b[ adding req module" + (sizeof (mods) > 1 ? "s" : "") + "\n");
	else
	  report_debug("Adding required module" + (sizeof (mods) > 1 ? "s" : "") + "\n");
#endif
      forcibly_added[ mod+"#0" ] = 1;
      enable_module( mod+"#0" );
      forcibly_added[ mod+"#0" ] = 2;
    }
  }
#ifdef MODULE_DEBUG
  if( wr && enable_module_batch_msgs )
    report_debug("] \b");
#endif
}

#if ROXEN_COMPAT < 2.2
// BEGIN SQL

mapping(string:string) sql_urls = ([]);

constant sql_cache_get = DBManager.sql_cache_get;

Sql.Sql sql_connect(string db, void|string charset)
{
  if (sql_urls[db])
    return sql_cache_get(sql_urls[db], 0, charset);
  else
    return sql_cache_get(db, 0, charset);
}

// END SQL
#endif

protected string my_url, my_host;

void fix_my_url()
{
  my_url = query ("MyWorldLocation");
  if (!sizeof (my_url) &&
      !(my_url = Roxen.get_world (query ("URLs"))))
    // Probably no port configured. The empty string is used as a
    // flag; there shouldn't be any bad fallback here.
    my_url = "";
  else
    if (!has_suffix (my_url, "/")) my_url += "/";

  if (sscanf (my_url, "%*s://[%s]", string hostv6) == 2 ||
      sscanf (my_url, "%*s://%[^:/]", string hostv4) == 2)
    my_host = hostv6 ? "[" + hostv6 + "]" : hostv4;
  else
    my_host = 0;
}

//! Returns some URL for accessing the configuration. (Should be
//! used instead of querying MyWorldLocation directly.)
string get_url() {return my_url;}

//! Returns the host part of the URL returned by @[get_url]. Returns
//! zero when @[get_url] cannot return any useful value (i.e. it
//! returns the empty string).
string get_host() {return my_host;}

array after_init_hooks = ({});
mixed add_init_hook( mixed what )
{
  if( inited )
    call_out( what, 0, this_object() );
  else
    after_init_hooks |= ({ what });
}

protected int got_no_delayed_load = 0;
// 0 -> enable delayed loading, 1 -> disable delayed loading,
// -1 -> don't change.

void fix_no_delayed_load_flag()
{
  if( got_no_delayed_load >= 0 &&
      query ("no_delayed_load") != got_no_delayed_load ) {
    set( "no_delayed_load", got_no_delayed_load );
    save_one( 0 );
  }
}

void enable_all_modules()
{
  MODULE_LOCK (0);

  // Temporarily shift out of the rxml parsing context if we're inside
  // any (e.g. due to delayed loading from inside the admin
  // interface).
  RXML.Context old_ctx = RXML.get_context();
  RXML.set_context (0);
  mixed err = catch {

      low_init( );
      fix_no_delayed_load_flag();

    };
  RXML.set_context (old_ctx);
  if (err) throw (err);
}

void low_init(void|int modules_already_enabled)
{
  if( inited )
    return; // already done

  int start_time = gethrtime();
  if (!modules_already_enabled)
    report_debug("\nEnabling all modules for "+query_name()+"... \n");

  if (!modules_already_enabled)
  {
    // Ugly kludge: We let enabled_modules lie about the set of currently
    //              enabled modules during the init, so that
    //              module_dependencies() doesn't perform duplicate work.
    enabled_modules = retrieve("EnabledModules", this_object());
//     roxenloader.LowErrorContainer ec = roxenloader.LowErrorContainer();
//     roxenloader.push_compile_error_handler( ec );

    array modules_to_process = sort(indices( enabled_modules ));
    string tmp_string;

    mixed err;
    forcibly_added = ([]);
    enable_module_batch_msgs = 1;
    foreach( modules_to_process, tmp_string )
    {
      if( !forcibly_added[ tmp_string ] )
	if(err = catch( enable_module( tmp_string, UNDEFINED, UNDEFINED,
				       UNDEFINED, 1)))
	{
	  report_error(LOC_M(45, "Failed to enable the module %s. Skipping.")
		       +"\n%s\n", tmp_string, describe_backtrace(err));
	  got_no_delayed_load = -1;
	}
    }
    enable_module_batch_msgs = 0;
//      roxenloader.pop_compile_error_handler();
    forcibly_added = ([]);
  }
    
  foreach( ({this_object()})+indices( otomod ), RoxenModule mod )
    if( mod->ready_to_receive_requests )
      if( mixed q = catch( mod->ready_to_receive_requests( this_object() ) ) ) {
        report_error( "While calling ready_to_receive_requests in "+
                      otomod[mod]+":\n"+
                      describe_backtrace( q ) );
	got_no_delayed_load = -1;
      }

  foreach( after_init_hooks, function q )
    if( mixed w = catch( q(this_object()) ) ) {
      report_error( "While calling after_init_hook %O:\n%s",
                    q,  describe_backtrace( w ) );
      got_no_delayed_load = -1;
    }

  after_init_hooks = ({});

  inited = 1;
  if (!modules_already_enabled)
    report_notice(LOC_S(4, "All modules for %s enabled in %3.1f seconds") +
		  "\n\n", query_name(), (gethrtime()-start_time)/1000000.0);

#ifdef SNMP_AGENT
  // Start trap after real virt.serv. loading
  if(query("snmp_process") && objectp(roxen->snmpagent))
    roxen->snmpagent->vs_start_trap(get_config_id());
#endif

}

DataCache datacache;

protected void create()
{
  if (!name) error ("Configuration name not set through bootstrap_info.\n");
//   int st = gethrtime();
  roxen.add_permission( "Site:"+name, LOC_C(306,"Site")+": "+name );

  // for now only these two. In the future there might be more variables.
  defvar( "data_cache_size", 131072, DLOCALE(274, "Cache:Cache size"),
          TYPE_INT| VAR_PUBLIC,
          DLOCALE(275, "The size of the data cache used to speed up requests "
                  "for commonly requested files, in KBytes"));

  defvar( "data_cache_file_max_size", 256, DLOCALE(276, "Cache:Max file size"),
          TYPE_INT | VAR_PUBLIC,
          DLOCALE(277, "The maximum size of a file that is to be considered for "
		  "the cache, in KBytes."));


  defvar("default_server", 0, DLOCALE(20, "Ports: Default site"),
	 TYPE_FLAG| VAR_PUBLIC,
	 DLOCALE(21, "If true, this site will be selected in preference of "
	 "other sites when virtual hosting is used and no host "
	 "header is supplied, or the supplied host header does not "
	 "match the address of any of the other servers.") );

  defvar("comment", "", DLOCALE(22, "Site comment"),
	 TYPE_TEXT_FIELD|VAR_MORE,
	 DLOCALE(23, "This text will be visible in the administration "
		 "interface, it can be quite useful to use as a memory helper."));

  defvar("name", "", DLOCALE(24, "Site name"),
	 TYPE_STRING|VAR_MORE| VAR_PUBLIC|VAR_NO_DEFAULT,
	 DLOCALE(25, "This is the name that will be used in the administration "
	 "interface. If this is left empty, the actual name of the "
	 "site will be used."));

  defvar("compat_level", Variable.StringChoice (
	   "", roxen.compat_levels, VAR_NO_DEFAULT,
	   DLOCALE(246, "Compatibility level"),
	   DLOCALE(386, #"\
<p>The compatibility level is used by different modules to select the
right behavior to remain compatible with earlier Roxen versions. When
a server configuration is created, this variable is set to the current
version. After that it's never changed automatically, thereby ensuring
that server configurations migrated from earlier Roxen versions is
kept at the right compatibility level.</p>

<p>This variable may be changed manually, but it's advisable to test
the site carefully afterwards. A reload of the whole server
configuration is required to propagate the change properly to all
modules.</p>

<p>Compatibility level notes:</p>

<ul>
  <li>2.4 also applies to the version commonly known as 3.2. That was
  the release of Roxen CMS which contained Roxen WebServer 2.4.</li>

  <li>2.5 corresponds to no released version. This compatibility level
  is only used to turn on some optimizations that have compatibility
  issues with 2.4, notably the optimization of cache static tags in
  the &lt;cache&gt; tag.</li>

  <li>There are no compatibility differences between 5.0 and 5.1, so
  those two compatibility levels can be used interchangeably.</li>
</ul>")));

  set ("compat_level", roxen.roxen_ver);
  // Note to developers: This setting can be accessed through
  // id->conf->query("compat_level") or similar, but observe that that
  // call is not entirely cheap. It's therefore advisable to put it in
  // a local variable if the compatibility level is to be tested
  // frequently. It's perfectly all right to do that in e.g. the
  // module start function, since the documentation explicitly states
  // that a reload of all modules is necessary to propagate a change
  // of the setting.

  defvar("Log", 1, DLOCALE(28, "Logging: Enabled"), 
	 TYPE_FLAG, DLOCALE(29, "Log requests"));

  defvar("LogFormat", #"\
# The default format follows the Combined Log Format, a slight
# extension of the Common Log Format - see
# http://httpd.apache.org/docs/1.3/logs.html#combined
*: $ip-number - $user [$cern-date] \"$method $full-resource $protocol\" $response $length \"$referrer\" \"$user-agent-raw\"

# The following line is an extension of the above that adds useful
# cache info. If you enable this you have to comment out or delete the
# line above.
#*: $ip-number - $user [$cern-date] \"$method $full-resource $protocol\" $response $length \"$referrer\" \"$user-agent-raw\" $cache-status $eval-status $request-time

# You might want to enable some of the following lines to get logging
# of various internal activities in the server. The formats below are
# somewhat similar to the Common Log Format standard, but they might
# still break external log analysis tools.

# To log commits and similar filesystem changes in a sitebuilder file system.
#sbfs/commit: 0.0.0.0 - - [$cern-date] \"$action $ac-userid:$workarea:$resource sbfs\" - - $commit-type
#sbfs/*: 0.0.0.0 - - [$cern-date] \"$action $ac-userid:$workarea:$resource sbfs\" - -

# Catch-all for internal log messages.
#*/*: 0.0.0.0 - - [$cern-date] \"$action $resource $facility\" - -",
	 DLOCALE(26, "Logging: Format"),
	 TYPE_TEXT_FIELD|VAR_MORE,
	 // FIXME: Undocumented: $cs-uri-stem, $cs-uri-query,
	 // $real-resource, $real-full-resource, $real-cs-uri-stem,

	 /* Removed doc for would-be $request-vtime.
<tr><td>$request-vtime</td>
    <td>The virtual time the request took (seconds). This measures the
    virtual time spent by the Roxen process. Note however that the
    accuracy is comparably low on many OS:es, typically much lower
    than $request-time. Also note that this isn't supported on all
    platforms.</td></tr>
	 */

	 DLOCALE(27, #"\
Describes the format to use for access logging. The log file can also
receive messages for various internal activities.

Empty lines and lines beginning with '<code>#</code>' are ignored.
Other lines describes how to log either an access or an internal
event.

<p>A line to format an access logging message is one of:</p>

<pre><i>&lt;response code&gt;</i>: <i>&lt;log format&gt;</i>
*: <i>&lt;log format&gt;</i>
</pre>

<p><i>&lt;response code&gt;</i> is an HTTP status code. The
corresponding <i>&lt;log format&gt;</i> is used for all responses
matching that code. It's described in more detail below. If
'<code>*</code>' is used instead of a response code then that line
matches all responses that aren't matched by any specific response
code line.</p>

<p>A line to format an event logging message is one of:</p>

<pre><i>&lt;facility&gt;</i>/<i>&lt;action&gt;</i>: <i>&lt;log format&gt;</i>
<i>&lt;facility&gt;</i>/*: <i>&lt;log format&gt;</i>
*/*: <i>&lt;log format&gt;</i>
</pre>

<p><i>&lt;facility&gt;</i> matches an identifier for the Roxen module
or subsystem that the event comes from. Facility identifiers always
starts with a character in <code>[a-zA-Z0-9]</code> and contains only
characters in <code>[-_.#a-zA-Z0-9]</code>. If '<code>*</code>' is
used instead of <i>&lt;facility&gt;</i> then that line matches all
facilities that aren't matched by any other line.</p>

<p><i>&lt;action&gt;</i> matches an identifier for a specific kind of
event logged by a facility. An action identifier contains only
characters in <code>[-_.#a-zA-Z0-9]</code>. '<code>*</code>' may be
used instead of an <i>&lt;action&gt;</i> to match all events logged by
a facility that aren't matched by any other line.</p>

<p><i>&lt;log format&gt;</i> consists of literal characters and the
special specifiers described below. All specifiers are not applicable
for all kinds of messages. If an unknown or inapplicable specifier is
encountered it typically expands to '<code>-</code>', but in some
cases it expands to a dummy value that is syntactically compatible
with what it usually expands to.</p>

<p>For compatibility, underscores ('_') may be used wherever
hyphens ('-') occur in the specifier names.</p>

<h3>Format specifiers for both access and event logging</h3>

<table class='hilite-1stcol'><tbody valign='top'>
<tr><td>\\n \\t \\r</td>
    <td>Insert a newline, tab or linefeed character, respectively.</td></tr>
<tr><td>$char(int)</td>
    <td>Insert the (1 byte) character specified by the integer. E.g.
    '<code>$char(36)</code>' inserts a literal '<code>$</code>'
    character.</td></tr>
<tr><td>$wchar(int)</td>
    <td>Insert the specified integer using 2 bytes in network byte
    order. Specify a negative integer to get the opposite (i.e. big
    endian) order.</td></tr>
<tr><td>$int(int)</td>
    <td>Insert the specified integer using 4 bytes in network byte
    order. Specify a negative integer to get the opposite (i.e. big
    endian) order.</td></tr>
<tr><td>$^</td>
    <td>Suppress newline at the end of the logentry.</td></tr>
<tr><td>$date</td>
    <td>Local date formatted like '<code>2001-01-17</code>'.</td></tr>
<tr><td>$time</td>
    <td>Local time formatted like '<code>13:00:00</code>'.</td></tr>
<tr><td>$cern-date</td>
    <td>Local date and time in CERN Common Log file format, i.e.
    like '<code>17/Jan/2001:13:00:00 +0200</code>'.</td></tr>
<tr><td>$utc-date</td>
    <td>UTC date formatted like '<code>2001-01-17</code>'.</td></tr>

<tr><td>$utc-time</td>
    <td>UTC time formatted like '<code>13:00:00</code>'.</td></tr>
<tr><td>$bin-date</td>
    <td>Unix time as a 32 bit integer in network byte order.</td></tr>
<tr><td>$resource</td>
    <td>Resource identifier. For events, this is either a path to a
    file (if it begins with '<code>/</code>') or some other kind of
    resource identifier (otherwise). It is '-' for events that don't
    act on any specific resource.</td></tr>
<tr><td>$server-uptime</td>
    <td>Server uptime in seconds.</td></tr>
<tr><td>$server-cputime</td>
    <td>Server cpu (user+system) time in milliseconds.</td></tr>
<tr><td>$server-usertime</td>
    <td>Server cpu user time in milliseconds.</td></tr>
<tr><td>$server-systime</td>
    <td>Server cpu system time in milliseconds.</td></tr>
</tbody></table>

<h3>Format specifiers for access logging</h3>

<table class='hilite-1stcol'><tbody valign='top'>
<tr><td>$host</td>
    <td>The remote host name, or ip number.</td></tr>
<tr><td>$vhost</td>
    <td>The Host request-header sent by the client, or '-' if none.</td></tr>
<tr><td>$ip-number</td>
    <td>The remote ip number.</td></tr>
<tr><td>$bin-ip-number</td>
    <td>The remote host ip as a binary integer number.</td></tr>
<tr><td>$xff</td>
    <td>The remote host name/ip taken from the X-Forwarded-For header, or
        '-' if none is provided. If multiple headers or multiple values are
        given the first value is logged; this should correspond to the
        originating computer.</td></tr>
<tr><td>$method</td>
    <td>Request method.</td></tr>
<tr><td>$full-resource</td>
    <td>Full requested resource, including any query fields.</td></tr>
<tr><td>$protocol</td>
    <td>The protocol used (normally HTTP/1.1).</td></tr>
<tr><td>$response</td>
    <td>The response code sent.</td></tr>
<tr><td>$bin-response</td>
    <td>The response code sent as a binary short number.</td></tr>
<tr><td>$length</td>
    <td>The length of the data section of the reply.</td></tr>
<tr><td>$bin-length</td>
    <td>Same, but as a 32 bit integer in network byte order.</td></tr>
<tr><td>$queue-length</td>
    <td>Number of jobs waiting to be processed by the handler threads
    at the time this request was added to the queue.</td></tr>
<tr><td>$queue-time</td>
    <td>Time in seconds that the request spent in the internal handler
    queue, waiting to be processed by a handler thread.</td></tr>
<tr><td>$handle-time</td>
    <td>Time in seconds spent processing the request in a handler
    thread. This measures the server processing time, excluding I/O
    and time spent in the handler queue. Note however that this
    measures real time, not virtual process time. I.e. if there are
    other handler threads or processes using the CPU then this might
    not accurately show the time that the Roxen server spent on the
    request. Also note that if a handler thread has to wait for
    responses from other servers then that wait time is included in
    this measurement.</td></tr>
<tr><td>$handle-cputime</td>
    <td>CPU time in seconds spent processing the request in a handler
    thread. Similar to $handle-time, but only includes the actual CPU
    time spent on this request only. Time spent waiting for responses
    from external server is not included here. Note that this time
    might have very low accuracy on some platforms. There are also
    platforms where this measurement isn't available at all, and in
    that case this fields expands to \"-\".</td></tr>
<tr><td>$request-time</td>
    <td>Time in seconds that the whole request took on the server
    side, including I/O time for receiving the request and sending the
    response. Note that this measures real time - see $handle-time for
    further discussion.</td></tr>
<tr><td>$etag</td>
    <td>The entity tag (aka ETag) header of the result.</td></tr>
<tr><td>$referrer</td>
    <td>The header 'referer' from the request, or '-'.</td></tr>
<tr><td>$referer</td>
    <td>Same as $referrer. Common misspelling kept for
    compatibility.</td></tr>
<tr><td>$user-agent</td>
    <td>The header 'User-Agent' from the request, or '-'.</td></tr>
<tr><td>$user-agent-raw</td>
    <td>Same, but spaces in the name are not encoded to %20.</td></tr>
<tr><td>$user</td>
    <td>The name of the user, if any is given using the HTTP basic
    authentication method.</td></tr>
<tr><td>$user-id</td>
    <td>A unique user ID, if cookies are supported, by the client,
    otherwise '0'.</td></tr>
<tr><td>$content-type</td>
    <td>Resource MIME type.</td></tr>
<tr><td>$cookies</td>
    <td>All cookies sent by the browser, separated by ';'.</td></tr>

<tr><td>$cache-status</td>
    <td>A comma separated list of words (containing no whitespace)
    that describes how the request got handled by various caches:

    <table class='hilite-1stcol'><tbody valign='top'>
    <tr><td>protcache</td>
	<td>The page is served from the HTTP protocol cache.</td></tr>
    <tr><td>protstore</td>
	<td>The page is stored in the HTTP protocol cache.</td></tr>
    <tr><td>stale</td>
	<td>There is a stale entry in the HTTP protocol cache. A
	refresh is underway in the background and the stale entry is
	sent in the meantime to avoid a long response time and server
	congestion.</td></tr>
    <tr><td>refresh</td>
	<td>This is the finishing of the background refresh request
	for the entry in the HTTP protocol cache.</td></tr>
    <tr><td>icachedraw</td>
	<td>A server-generated image had to be rendered from scratch.</td></tr>
    <tr><td>icacheram</td>
	<td>A server-generated image was found in the RAM cache.</td></tr>
    <tr><td>icachedisk</td>
	<td>A server-generated image was found in the disk cache (i.e. in
            the server's MySQL database).</td></tr>
    <tr><td>pcoderam</td>
	<td>A hit in the RXML p-code RAM cache.</td></tr>
    <tr><td>pcodedisk</td>
	<td>A hit in the RXML p-code persistent cache.</td></tr>
    <tr><td>pcodestore</td>
	<td>P-code is added to or updated in the persistent cache.</td></tr>
    <tr><td>pcodestorefailed</td>
	<td>An attempt to add or update p-code in the persistent cache
        failed (e.g. due to a race with another request).</td></tr>
    <tr><td>cachetag</td>
	<td>RXML was evaluated without any cache miss in any RXML
	&lt;cache&gt; tag. The &lt;nocache&gt; tag does not count as a
	miss.</td></tr>
    <tr><td>xsltcache</td>
	<td>There is a hit XSLT cache.</td></tr>
    <tr><td>nocache</td>
	<td>No hit in any known cache, and not added to the HTTP
	protocol cache.</td></tr>
    </tbody></table></td></tr>

<tr><td>$eval-status</td>
    <td>A comma separated list of words (containing no whitespace)
    that describes how the page has been evaluated:

    <table class='hilite-1stcol'><tbody valign='top'>
    <tr><td>xslt</td>
	<td>XSL transform.</td></tr>
    <tr><td>rxmlsrc</td>
	<td>RXML evaluated from source.</td></tr>
    <tr><td>rxmlpcode</td>
	<td>RXML evaluated from compiled p-code.</td></tr>
    </tbody></table></td></tr>

<tr><td>$protcache-cost</td>
    <td>The lookup depth in the HTTP protocol module low-level cache.</td></tr>
</tbody></table>

<h3>Event logging</h3>

<p>The known event logging facilities and modules are described
below.</p>

<dl>
<dt>Facility: roxen</dt>
    <dd><p>This is logging for systems in the Roxen WebServer core.
    For logging that is not related to any specific configuration, the
    configuration for the Administration Interface is used.</p>

    <p>The known events are:</p>

    <table class='hilite-1stcol'><tbody valign='top'>
    <tr><td>ram-cache-gc</td>
	<td>Logged after the RAM cache GC has run. $handle-time and
	$handle-cputime are set to the time the GC took (see
	descriptions above for details).</td></tr>
    <tr><td>ram-cache-rebase</td>
	<td>Logged when the RAM cache has performed a rebias of the
	priority queue values. Is a problem only if it starts to
	happen too often.</td></tr>
    </tbody></table></dd>

<dt>Facility: sbfs</dt>
    <dd><p>A SiteBuilder file system.</p>

    <p>The actions <code>commit</code>, <code>purge</code>,
    <code>mkdir</code>, <code>set-dir-md</code>, and
    <code>rmdir</code> are logged for file system changes except those
    in edit areas.</p>

    <p>The action <code>crawl-file</code> is logged for files that are
    crawled by the persistent cache crawler.</p>

    <p>The actions <code>file-change</code> and
    <code>dir-change-flat</code> are logged when external file and
    directory changes are detected (and this feature is enabled).</p>

    <p>These extra format specifiers are defined where applicable:</p>

    <table class='hilite-1stcol'><tbody valign='top'>
    <tr><td>$ac-userid</td>
	<td>The ID number of the AC identity whose edit area was used.
	Zero for the common view area.</td></tr>
    <tr><td>$workarea</td>
	<td>The unique tag for the work area. Empty for the main work
	area.</td></tr>
    <tr><td>$commit-type</td>
	<td>The type of file commit, one of <code>create</code>,
	<code>edit</code>, <code>delete</code>, and
	<code>undelete</code>.</td></tr>
    <tr><td>$revision</td>
	<td>The committed revision number, a dotted decimal.</td></tr>
    <tr><td>$comment</td>
	<td>The commit message.</td></tr>
    <tr><td>$request-time</td>
	<td>This is set for the action <code>crawl-file</code>. It's
	similar to <code>$request-time</code> for normal requests,
	except that it measures the whole time it took for the
	persistent cache crawler to process the page. That includes
	all crawled variants and the saving of the entry to the
	database.</td></tr>
    </tbody></table></dd>
</dl>"), 0, lambda(){ return !query("Log");});

  // Make the widget above a bit larger.
  getvar ("LogFormat")->rows = 20;
  getvar ("LogFormat")->cols = 80;

  // FIXME: Mention it is relative to getcwd(). Can not be localized in pike 7.0.
  defvar("LogFile", "$LOGDIR/"+Roxen.short_name(name)+"/Log",
	 DLOCALE(30, "Logging: Log file"), TYPE_FILE,
	 DLOCALE(31, "The log file. "
	 "A file name. Some substitutions will be done:"
	 "<pre>"
	 "%y    Year  (e.g. '1997')\n"
	 "%m    Month (e.g. '08')\n"
	 "%d    Date  (e.g. '10' for the tenth)\n"
	 "%h    Hour  (e.g. '00')\n"
	 "%H    Hostname\n"
	 "</pre>")
	 ,0, lambda(){ return !query("Log");});
  
  defvar("LogFileCompressor", "",
	 DLOCALE(258, "Logging: Compress log file"), TYPE_STRING,
	 DLOCALE(259, "Path to a program to compress log files, "
		 "e.g. <tt>/usr/bin/bzip2</tt> or <tt>/usr/bin/gzip</tt>. "
		 "<b>Note&nbsp;1:</b> The active log file is never compressed. "
		 "Log rotation needs to be used using the \"Log file\" "
		 "filename substitutions "
		 "(e.g. <tt>$LOGDIR/mysite/Log.%y-%m-%d</tt>). "
		 "<b>Note&nbsp;2:</b> Compression is limited to scanning files "
		 "with filename substitutions within a fixed directory (e.g. "
		 "<tt>$LOGDIR/mysite/Log.%y-%m-%d</tt>, "
		 "not <tt>$LOGDIR/mysite/%y/Log.%m-%d</tt>)."),
	 0, lambda(){ return !query("Log");});
  
  defvar("NoLog", ({ }),
	 DLOCALE(32, "Logging: No Logging for"), TYPE_STRING_LIST|VAR_MORE,
         DLOCALE(33, "Don't log requests from hosts with an IP number which "
		 "matches any of the patterns in this list. This also affects "
		 "the access counter log."), 
	 0, lambda(){ return !query("Log");});

  defvar("Domain", roxen.get_domain(), DLOCALE(34, "Domain"),
	 TYPE_STRING|VAR_PUBLIC|VAR_NO_DEFAULT,
	 DLOCALE(35, "The domain name of the server. The domain name is used "
	 "to generate default URLs, and to generate email addresses."));

  defvar("MyWorldLocation", "",
         DLOCALE(36, "Ports: Primary Server URL"), TYPE_URL|VAR_PUBLIC,
	 DLOCALE(37, #"\
This is the main server URL, where your start page is located. This
setting is for instance used as fallback to generate absolute URLs to
the server, but in most circumstances the URLs sent by the clients are
used. A URL is deduced from the first entry in 'URLs' if this is left
blank.

<p>Note that setting this doesn't make the server accessible; you must
also set 'URLs'."));
  
  defvar("URLs", 
         Variable.PortList( ({"http://*/#ip=;nobind=0;"}), VAR_INITIAL|VAR_NO_DEFAULT,
           DLOCALE(38, "Ports: URLs"),
	   DLOCALE(373, "Bind to these URLs. You can use '*' and '?' to perform"
		   " globbing (using any of these will default to binding to "
		   "all IP-numbers on your machine).  If you specify a IP# in "
		   "the field it will take precedence over the hostname.")));

  defvar("InternalLoc", internal_location,
	 DLOCALE(40, "Internal module resource mountpoint"),
	 TYPE_LOCATION|VAR_MORE,
         DLOCALE(41, "Some modules may want to create links to internal "
		 "resources. This setting configures an internally handled "
		 "location that can be used for such purposes.  Simply select "
		 "a location that you are not likely to use for regular "
		 "resources."))
    ->add_changed_callback(lambda(object v) { internal_location = v->query(); });
  
  defvar("SubRequestLimit", sub_req_limit,
	 "Subrequest depth limit",
	 TYPE_INT | VAR_MORE,
	 "A limit for the number of nested sub requests for each request. "
	 "This is intented to catch unintended infinite loops when for "
	 "example inserting files in RXML. 0 for no limit." )
    ->add_changed_callback(lambda(object v) { sub_req_limit = v->query(); });

  // Throttling-related variables

  defvar("throttle", 0,
         DLOCALE(42, "Throttling: Server; Enabled"),TYPE_FLAG,
	 DLOCALE(43, "If set, per-server bandwidth throttling will be enabled. "
		 "It will allow you to limit the total available bandwidth for "
		"this site.<br />Bandwidth is assigned using a Token Bucket. "
		"The principle under which it works is: for each byte we send we use a token. "
		"Tokens are added to a repository at a constant rate. When there's not enough, "
		"we can't transmit. When there's too many, they \"spill\" and are lost."));
  //TODO: move this explanation somewhere on the website and just put a link.

  defvar("throttle_fill_rate", 102400,
         DLOCALE(44, "Throttling: Server; Average available bandwidth"),
         TYPE_INT,
	 DLOCALE(45, "This is the average bandwidth available to this site in "
		"bytes/sec (the bucket \"fill rate\")."),
         0, arent_we_throttling_server);

  defvar("throttle_bucket_depth", 1024000,
         DLOCALE(46, "Throttling: Server; Bucket Depth"), TYPE_INT,
	 DLOCALE(47, "This is the maximum depth of the bucket. After a long enough period "
		"of inactivity, a request will get this many unthrottled bytes of data, before "
		"throttling kicks back in.<br>Set equal to the Fill Rate in order not to allow "
		"any data bursts. This value determines the length of the time over which the "
		"bandwidth is averaged."), 0, arent_we_throttling_server);

  defvar("throttle_min_grant", 1300,
         DLOCALE(48, "Throttling: Server; Minimum Grant"), TYPE_INT,
	 DLOCALE(49, "When the bandwidth availability is below this value, connections will "
		"be delayed rather than granted minimal amounts of bandwidth. The purpose "
		"is to avoid sending too small packets (which would increase the IP overhead)."),
         0, arent_we_throttling_server);

  defvar("throttle_max_grant", 14900,
         DLOCALE(50, "Throttling: Server; Maximum Grant"), TYPE_INT,
	 DLOCALE(51, "This is the maximum number of bytes assigned in a single request "
		"to a connection. Keeping this number low will share bandwidth more evenly "
		"among the pending connections, but keeping it too low will increase IP "
		"overhead and (marginally) CPU usage. You'll want to set it just a tiny "
		"bit lower than any integer multiple of your network's MTU (typically 1500 "
		"for ethernet)."), 0, arent_we_throttling_server);

  defvar("req_throttle", 0,
         DLOCALE(52, "Throttling: Request; Enabled"), TYPE_FLAG,
	 DLOCALE(53, "If set, per-request bandwidth throttling will be enabled.")
         );

  defvar("req_throttle_min", 1024,
         DLOCALE(54, "Throttling: Request; Minimum guarranteed bandwidth"),
         TYPE_INT,
	 DLOCALE(55, "The maximum bandwidth each connection (in bytes/sec) can use is determined "
		"combining a number of modules. But doing so can lead to too small "
		"or even negative bandwidths for particularly unlucky requests. This variable "
		"guarantees a minimum bandwidth for each request."),
         0, arent_we_throttling_request);

  defvar("req_throttle_depth_mult", 60.0,
         DLOCALE(56, "Throttling: Request; Bucket Depth Multiplier"),
         TYPE_FLOAT,
	 DLOCALE(57, "The average bandwidth available for each request will be determined by "
		"the modules combination. The bucket depth will be determined multiplying "
		"the rate by this factor."),
         0, arent_we_throttling_request);


  defvar("404-files", ({ "404.inc" }),
	 DLOCALE(307, "No such file message override files"),
	 TYPE_STRING_LIST|VAR_PUBLIC,
	 DLOCALE(308,
		 "If no file match a given resource all directories above the"
		 " wanted file is searched for one of the files in this list."
		 "<p>\n"
		 "As an example, if the file /foo/bar/not_there.html is "
		 "wanted, and this list contains the default value of 404.inc,"
		 " these files will be searched for, in this order:</p><br /> "
		 " /foo/bar/404.inc, /foo/404.inc and /404.inc."
		 "<p>\n"
		 "The inclusion file can access the form variables "
		 "form.orig-file and form.orig-url to identify the original "
		 "page that was requested.") );

  defvar("401-files", ({ }),
	 DLOCALE(411, "Authentication failed message override files"),
	 TYPE_STRING_LIST|VAR_PUBLIC,
	 DLOCALE(412,
		 "With each authentication required response this file is "
		 "sent and displayed if the authentication fails or the user "
		 "choose not to authenticate at all.<p>\n"
		 "The file is searched for in parent directories in the same "
		 "manner as the no such file message override files.") );

  defvar("license",
	 License.
	 LicenseVariable(getenv("ROXEN_LICENSEDIR") || "../license/", 
			 VAR_NO_DEFAULT, DLOCALE(39, "License file"),
			 DLOCALE(336, "The license file for this configuration."),
			 this_object()));

#ifdef HTTP_COMPRESSION
  defvar("http_compression_enabled", 1,
	 DLOCALE(1000, "Compression: Enable HTTP compression"),
	 TYPE_FLAG,
	 DLOCALE(1001, 
#"Whether to enable HTTP protocol compression. Many types of text
content (HTML, CSS, JavaScript etc.) can be compressed quite a lot, so
enabling HTTP compression may improve the visitors' perception of the
site's performance. It's however a trade-off between server processing
power and bandwidth. Requests that end up in the protocol cache will
be served in the compressed form directly from the protocol cache, so
for such requests the processing power overhead can be held relatively
low."))->add_changed_callback(lambda(object v) 
			      { http_compr_enabled = v->query(); });
  http_compr_enabled = query("http_compression_enabled");

  void set_mimetypes(array(string) mimetypes)
  {
    array main_mimes = ({});
    array exact_mimes = ({});

    foreach(mimetypes, string m) {
      if(has_suffix(m, "/*"))
	main_mimes += ({ m[..sizeof(m)-3] });
      else if(!has_value(m, "*"))
	exact_mimes += ({ m });
    }

    http_compr_exact_mimes = mkmapping(exact_mimes, 
				       ({ 1 }) * sizeof(exact_mimes));
    http_compr_main_mimes = mkmapping(main_mimes,
				      ({ 1 }) * sizeof(main_mimes));
  };
  defvar("http_compression_mimetypes", 
	 ({ "text/*", 
	    "application/javascript",
	    "application/x-javascript",
	    "application/json",
	    "application/xhtml+xml" }),
	 DLOCALE(1002, "Compression: Enabled MIME-types"),
	 TYPE_STRING_LIST,
	 DLOCALE(1003, "The MIME types for which to enable compression. The "
		 "forms \"maintype/*\" and \"maintype/subtype\" are allowed, "
		 "but globbing on the general form (such as "
		 "\"maintype/*subtype\") is not allowed and such globs will "
		 "be silently ignored."))
    ->add_changed_callback(lambda(object v) 
			   { set_mimetypes(v->query()); 
			   });
  set_mimetypes(query("http_compression_mimetypes"));

  defvar("http_compression_min_size", 1024,
	 DLOCALE(1004, "Compression: Minimum content size"),
	 TYPE_INT,
	 DLOCALE(1005, "The minimum file size for which to enable compression. "
		 "(It might not be worth it to compress a request if it can "
		 "fit into a single TCP/IP packet anyways.)"))
    ->add_changed_callback(lambda(object v) 
			   { http_compr_minlen = v->query(); });
  http_compr_minlen = query("http_compression_min_size");

  defvar("http_compression_max_size", 1048576,
	 DLOCALE(1006, "Compression: Maximum content size"),
	 TYPE_INT,
	 DLOCALE(1007, "The maximum file size for which to enable compression. "
		 "Note that the general protocol cache entry size limit "
		 "applies, so if the compression of dynamic requests is "
		 "disabled, files larger than the protocol cache maximum "
		 "file size setting will never be served compressed "
		 "regardless of this setting."))
    ->add_changed_callback(lambda(object v) 
			   { http_compr_maxlen = v->query(); });
  http_compr_maxlen = query("http_compression_max_size");

  Variable.Int comp_level = 
    Variable.Int(1, 0, DLOCALE(1008, "Compression: Compression level"),
		 DLOCALE(1009, "The compression level to use (integer between 1 "
			 "and 9). Higher number means more compression at the"
			 " cost of processing power and vice versa. You may "
			 "need to restart the server for this setting to "
			 "take effect."));
  comp_level->set_range(1, 9);
  defvar("http_compression_level", comp_level);
		 
  defvar("http_compression_dynamic_reqs", 1,
	 DLOCALE(1010, "Compression: Compress dynamic requests"),
	 TYPE_FLAG,
	 DLOCALE(1011, "If enabled, even requests that aren't cacheable in the "
		 "protocol cache will be compressed. If the site has many "
		 "lightweight requests that are not protocol cacheable, the "
		 "processing overhead may become relatively large with this "
		 "setting turned on."))
    ->add_changed_callback(lambda(object v) 
			   { http_compr_dynamic_reqs = v->query(); });
  http_compr_dynamic_reqs = query("http_compression_dynamic_reqs");
#endif  
  

  class NoSuchFileOverride
  {
    // compatibility with old config-files.
    inherit Variable.Variable;

    int check_visibility( RequestID id, int more_mode,
			  int expert_mode, int devel_mode,
			  int initial, int|void variable_in_cfif )
    {
      return 0;
    }

    void set( string newval )
    {
      if( search(newval,"emit source=values") == -1 )
	variables[ "404-message" ]->set( newval );
    }

    void create()
    {
      ::create(
#"<nooutput><emit source=values scope=ef variable='modvar.site.404-files'>
   <if not='' variable='ef.value is '>
     <set variable='var.base' value=''/>
     <emit source='path'>
       <append variable='var.base' value='/&_.name;'/>
       <set variable='var.404' value='&var.base;/&ef.value;'/>
       <if exists='&var.404;'>
         <set variable='var.errfile' from='var.404'/>
       </if>
     </emit>
   </if>
</emit>
</nooutput><if variable='var.errfile'><eval><insert file='&var.errfile;?orig-url=&page.url:url;&amp;orig-file=&page.virtfile:url;'/></eval></if><else><eval>&modvar.site.404-message:none;</eval></else>", 0, 0, 0 );
    }
  };
  
  defvar("ZNoSuchFile", NoSuchFileOverride() );

  defvar("404-message", #"<html>
<head>
  <title>404 - Page Not Found</title>
  <style>
    .msg  { font-family:    verdana, helvetica, arial, sans-serif;
            font-size:      12px;
            line-height:    160% }
    .url  { font-family:    georgia, times, serif;
            font-size:      18px;
            padding-top:    6px;
            padding-bottom: 20px }
    .info { font-family:    verdana, helvetica, arial, sans-serif;
            font-size:      10px;
            color:          #999999 }
  </style>
</head>
<body bgcolor='#f2f1eb' vlink='#2331d1' alink='#f6f6ff'
      leftmargin='0' rightmargin='0' topmargin='0' bottommargin='0'
      style='margin: 0; padding: 0'>

<table border='0' cellspacing='0' cellpadding='0' height='99%'>
  <colgroup>
    <col span='3' />
    <col width='356' />
    <col width='0*' />
  </colgroup>
  <tr>
    <td><img src='/internal-roxen-unit' height='30' /></td>
  </tr><tr>
    <td></td>
    <td><img src='/internal-roxen-404' /></td>
    <td><img src='/internal-roxen-unit' width='30' /></td>
    <td valign='bottom'><img src='/internal-roxen-page-not-found-2' /></td>
    <td></td>
  </tr><tr>
    <td><img src='/internal-roxen-unit' height='30' /></td>
  </tr><tr>
    <td colspan='3'></td>
    <td colspan='2'>
      <div class='msg'>Unable to retrieve</div>
      <div class='url'>&page.virtfile;</div>
    </td>
  </tr><tr>
    <td colspan='3'></td>
    <td width='356'>
      <div class='msg'>
        If you feel this is a configuration error, please contact
        the administrators of this server or the author of the
        <if referrer=''>
          <a href='&client.referrer;'>referring page</a>.
        </if><else>
          referring page.
        </else>
      </div>
    </td>
    <td>&nbsp;</td>
  </tr><tr valign='bottom' height='100%'>
    <td colspan='3'></td>
    <td>
      <img src='/internal-roxen-unit' height='20' />
      <table border='0' cellspacing='0' cellpadding='0'>
        <tr>
          <td><img src='/internal-roxen-roxen-mini.gif' /></td>
          <td class='info'>
            &nbsp;&nbsp;<b>&roxen.product-name;</b> <font color='#ffbe00'>|</font>
            version &roxen.dist-version;
          </td>
        </tr>
      </table>
      <img src='/internal-roxen-unit' height='15' />
    </td>
    <td></td>
  </tr>
</table>

</body>
</html>",
	 DLOCALE(58, "No such file message"),
	 TYPE_TEXT_FIELD|VAR_PUBLIC,
	 DLOCALE(59, "What to return when there is no resource or file "
		 "available at a certain location."));


  class AuthFailedOverride
  {
    // compatibility with old config-files.
    inherit Variable.Variable;

    int check_visibility( RequestID id, int more_mode,
			  int expert_mode, int devel_mode,
			  int initial, int|void variable_in_cfif )
    {
      return 0;
    }

    void set( string newval )
    {
      if( search(newval,"emit source=values") == -1 )
	variables[ "401-message" ]->set( newval );
    }

    void create()
    {
      ::create(
#"<nooutput><emit source=values scope=ef variable='modvar.site.401-files'>
   <if not='' variable='ef.value is '>
     <set variable='var.base' value=''/>
     <emit source='path'>
       <append variable='var.base' value='/&_.name;'/>
       <set variable='var.401' value='&var.base;/&ef.value;'/>
       <if exists='&var.401;'>
         <set variable='var.errfile' from='var.401'/>
       </if>
     </emit>
   </if>
</emit>
</nooutput><if variable='var.errfile'><eval><insert file='&var.errfile;?orig-url=&page.url:url;&amp;orig-file=&page.virtfile:url;'/></eval></if><else><eval>&modvar.site.401-message:none;</eval></else>", 0, 0, 0 );
    }
  };
  
  defvar("ZAuthFailed", AuthFailedOverride() );

  defvar("401-message", #"<html>
<head>
  <title>401 - Authentication Failed</title>
  <style>
    .msg  { font-family:    verdana, helvetica, arial, sans-serif;
            font-size:      12px;
            line-height:    160% }
    .url  { font-family:    georgia, times, serif;
            font-size:      18px;
            padding-top:    6px;
            padding-bottom: 20px }
    .info { font-family:    verdana, helvetica, arial, sans-serif;
            font-size:      10px;
            color:          #999999 }
  </style>
</head>
<body bgcolor='#f2f1eb' vlink='#2331d1' alink='#f6f6ff'
      leftmargin='0' rightmargin='0' topmargin='0' bottommargin='0'
      style='margin: 0; padding: 0'>

<table border='0' cellspacing='0' cellpadding='0' height='99%'>
  <colgroup>
    <col span='3' />
    <col width='356' />
    <col width='0*' />
  </colgroup>
  <tr>
    <td><img src='/internal-roxen-unit' height='30' /></td>
  </tr><tr>
    <td></td>
    <td><img src='/internal-roxen-401' /></td>
    <td><img src='/internal-roxen-unit' width='30' /></td>
    <td valign='bottom'><img src='/internal-roxen-authentication-failed' /></td>
    <td></td>
  </tr><tr>
    <td><img src='/internal-roxen-unit' height='30' /></td>
  </tr><tr>
    <td colspan='3'></td>
    <td colspan='2'>
      <div class='msg'>Unable to retrieve</div>
      <div class='url'>&page.virtfile;</div>
    </td>
  </tr><tr>
    <td colspan='3'></td>
    <td width='356'>
      <div class='msg'>
        If you feel this is a configuration error, please contact
        the administrators of this server or the author of the
        <if referrer=''>
          <a href='&client.referrer;'>referring page</a>.
        </if><else>
          referring page.
        </else>
      </div>
    </td>
    <td>&nbsp;</td>
  </tr><tr valign='bottom' height='100%'>
    <td colspan='3'></td>
    <td>
      <img src='/internal-roxen-unit' height='20' />
      <table border='0' cellspacing='0' cellpadding='0'>
        <tr>
          <td><img src='/internal-roxen-roxen-mini.gif' /></td>
          <td class='info'>
            &nbsp;&nbsp;<b>&roxen.product-name;</b> <font color='#ffbe00'>|</font>
            version &roxen.dist-version;
          </td>
        </tr>
      </table>
      <img src='/internal-roxen-unit' height='15' />
    </td>
    <td></td>
  </tr>
</table>

</body>
</html>",
	 DLOCALE(413, "Authentication failed message"),
	 TYPE_TEXT_FIELD|VAR_PUBLIC,
	 DLOCALE(420, "What to return when an authentication attempt failed."));

  if (!retrieve ("EnabledModules", this)["config_filesystem#0"]) {
    // Do not use a handler queue timeout of the administration
    // interface. You most probably don't want to get a 503 in your
    // face when you're trying to reconfigure an overloaded server...
    defvar("503-message", #"<html>
<head>
  <title>503 - Server Too Busy</title>
  <style>
    .header { font-family:  arial;
            font-size:      20px;
            line-height:    160% }
    .msg  { font-family:    verdana, helvetica, arial, sans-serif;
            font-size:      12px;
            line-height:    160% }
    .url  { font-family:    georgia, times, serif;
            font-size:      18px;
            padding-top:    6px;
            padding-bottom: 20px }
    .info { font-family:    verdana, helvetica, arial, sans-serif;
            font-size:      10px;
            color:          #999999 }
  </style>
</head>
<body bgcolor='#f2f1eb' vlink='#2331d1' alink='#f6f6ff'
      leftmargin='50' rightmargin='0' topmargin='50' bottommargin='0'
      style='margin: 0; padding: 0'>

<table border='0' cellspacing='0' cellpadding='0' height='99%'>
  <colgroup>
    <col span='3' />
    <col width='356' />
    <col width='0*' />
  </colgroup>
  <tr><td height='50'></td></tr>
  <tr>
    <td width='100'></td>
    <td>
      <div class='header'>503 &mdash; Server Too Busy</div>
    </td>
  </tr>
  <tr>
    <td></td>
    <td>
      <div class='msg'>Unable to retrieve</div>
      <div class='url'>&page.virtfile;</div>
    </td>
  </tr>
  <tr>
    <td></td>
    <td>
      <div class='msg'>
        The server is currently too busy to serve your request. Please try again in a few moments.
      </div>
    </td>
    <td>&nbsp;</td>
  </tr>
  <tr valign='bottom' height='100%'>
    <td></td>
    <td>
      <table border='0' cellspacing='0' cellpadding='0'>
        <tr>
          <td class='info'>
            &nbsp;&nbsp;<b>&roxen.product-name;</b> <font color='#ffbe00'>|</font>
            version &roxen.dist-version;
          </td>
        </tr>
      </table>
   </td>
   <td></td>
 </tr>
</table>

</body>
</html>",
	   DLOCALE(1048, "Server too busy message"),
	   TYPE_TEXT_FIELD|VAR_PUBLIC,
	   DLOCALE(1049, "What to return if the server is too busy. See also "
		   "\"Handler queue timeout\"."));

    defvar("handler_queue_timeout", 30,
	   DLOCALE(1050, "Handler queue timeout"),
	   TYPE_INT,
	   DLOCALE(1051, #"Requests that have been waiting this many seconds on
the handler queue will not be processed. Instead, a 503 error code and the
\"Server too busy message\" will be returned to the client. This may help the
server to cut down the queue length after spikes of heavy load."))
      ->add_changed_callback(lambda(object v)
			     { handler_queue_timeout = v->query(); });
    handler_queue_timeout = query("handler_queue_timeout");
  }

#ifdef SNMP_AGENT
  // SNMP stuffs
  defvar("snmp_process", 0,
         "SNMP: Enabled",TYPE_FLAG,
         "If set, per-server objects will be added to the SNMP agent database.",
          0, snmp_global_disabled);
  defvar("snmp_community", "public:ro",
         "SNMP: Community string", TYPE_STRING,
         "The community string and access level for manipulation on server "
                " specific objects.",
         0, snmp_disabled);
  defvar("snmp_traphosts", ({ }),
                 "SNMP: Trap host URLs", TYPE_STRING_LIST,
         "The remote nodes, where should be sent traps."
	 "<p>\n"
	 "The URL syntax is: snmptrap://community@hostname:portnumber"
	 "</p><br/>",
	 0, snmp_disabled);
#endif

  definvisvar( "no_delayed_load", 0, TYPE_FLAG|VAR_PUBLIC );

//   report_debug("[defvar: %.1fms] ", (gethrtime()-st)/1000.0 );
//   st = gethrtime();

  mapping(string:mixed) retrieved_vars = retrieve("spider#0", this_object());
  if (sizeof (retrieved_vars) && !retrieved_vars->compat_level)
    // Upgrading an older configuration; default to 2.1 compatibility level.
    set ("compat_level", "2.1");
  setvars( retrieved_vars );

//   report_debug("[restore: %.1fms] ", (gethrtime()-st)/1000.0 );

#ifdef SNMP_AGENT
  if (query("snmp_process")) {
    if(objectp(roxen()->snmpagent)) {
      int servid;
      servid = roxen()->snmpagent->add_virtserv(get_config_id());
      // todo: make invisible varibale and set it to this value for future reference
      // (support for per-reload persistence of server index?)
    } else
      report_error("SNMPagent: something gets wrong! The main agent is disabled!\n");
  }
#endif
}

protected int arent_we_throttling_server () {
  return !query("throttle");
}
protected int arent_we_throttling_request() {
  return !query("req_throttle");
}

#ifdef SNMP_AGENT
private int(0..1) snmp_disabled() {
  return (!snmp_global_disabled() && !query("snmp_process"));
}
private int(0..1) snmp_global_disabled() {
  return (!objectp(roxen->snmpagent));
}
#endif

