// This file is part of Internet Server.
// Copyright � 1996 - 2001, Roxen IS.
//

// @appears Configuration
//! A site's main configuration

constant cvs_version = "$Id: configuration.pike,v 1.527 2002/06/18 16:45:41 nilsson Exp $";
#include <module.h>
#include <module_constants.h>
#include <roxen.h>
#include <request_trace.h>
#include <timers.h>

#define CATCH(P,X) do{mixed e;if(e=catch{X;})report_error("While "+P+"\n"+describe_backtrace(e));}while(0)

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
    foreach(data; string k; array value  )
      table += ({ ({ k,
		     sprintf( "%d", (n=value[2]) ),
		     sprintf("%5.2f",(t=value[0])/1000000.0),
		     sprintf("%5.2f", (v=value[1])/1000000.0),
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

static mapping(RequestID:mapping) current_connections =
  set_weak_flag( ([ ]), 1 );

void connection_add( RequestID id, mapping data )
//! Add a connection. The data mapping can contain things such as
//! currently sent bytes.
//!
//! See protocols/http.pike and slowpipe.pike for more information.
//!
//! You are not in any way forced to use this method from your
//! protocol module. The information is only used for debug purposes
//! in the administration interface.
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
  m_delete( current_connections, id );
}

mapping(RequestID:mapping) connection_get( )
//! Return all currently active connections.
{
  return current_connections;
}

// It's nice to have the name when the rest of __INIT executes.
string name = roxen->bootstrap_info->get();

// Trivial cache (actually, it's more or less identical to the 200+
// lines of C in HTTPLoop. But it does not have to bother with the
// fact that more than one thread can be active in it at once. Also,
// it does not have to delay free until all current connections using
// the cache entry is done...)
class DataCache
{
  mapping(string:array(string|mapping(string:mixed))) cache = ([]);

  int current_size;
  int max_size;
  int max_file_size;

  int hits, misses;

  void flush()
  {
    current_size = 0;
    cache = ([]);
  }

  static void clear_some_cache()
  {
    array q = indices( cache );
    if(!sizeof(q))
    {
      current_size=0;
      return;
    }
    for( int i = 0; i<sizeof( q )/10; i++ )
      expire_entry( q[random(sizeof(q))] );
  }

  void expire_entry( string url )
  {
    if( cache[ url ] )
    {
      current_size -= strlen(cache[url][0]);
      m_delete( cache, url );
    }
  }

  void set( string url, string data, mapping meta, int expire )
  {
    if( strlen( data ) > max_file_size ) return;
    call_out( expire_entry, expire, url );
    current_size += strlen( data );
    cache[url] = ({ data, meta });
    int n;
    while( (current_size > max_size) && (n++<10))
      clear_some_cache();
  }
  
  array(string|mapping(string:mixed)) get( string url )
  {
    mixed res;
    if( res = cache[ url ] )  
      hits++;
    else
      misses++;
    return res;
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

  static void create()
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
  return query("InternalLoc")+(mod?replace(otomod[mod]||"", "#", "!")+"/":"");
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

/* A 'pri' is one of the ten priority objects. Each one holds a list
 * of modules for that priority. They are all merged into one list for
 * performance reasons later on.
 */

array (Priority) allocate_pris()
{
  return allocate(10, Priority)();
}


// The logging format used. This will probably move to the above
// mentioned module in the future.
private mapping (int:string) log_format = ([]);

// A list of priority objects
array (Priority) pri = allocate_pris();

mapping modules = ([]);
//! All enabled modules in this site.
//! The format is "module":{ "copies":([ num:instance, ... ]) }

mapping (RoxenModule:string) otomod = ([]);
//! A mapping from the module objects to module names


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

private int num_modules = 0;
#ifdef THREADS
private Thread.Condition modules_stopped = Thread.Condition();
#endif
private void safe_stop_module (RoxenModule mod, string desc)
{
  if (mixed err = catch (mod && mod->stop && mod->stop()))
    report_error ("While stopping " + desc + ": " + describe_backtrace (err));
  if (!--num_modules)
#ifdef THREADS
    modules_stopped->signal()
#endif
      ;
}

void stop (void|int asynch)
//! Unregisters the urls and calls stop in all modules. Uses the
//! handler threads to lessen the impact if a module hangs. Doesn't
//! wait for all modules to finish if @[asynch] is nonzero.
{

#ifdef SNMP_AGENT
  if(query("snmp_process") && objectp(roxen->snmpagent)) {
    roxen->snmpagent->vs_stop_trap(get_config_id());
    roxen->snmpagent->del_virtserv(get_config_id());
  }
#endif

  unregister_urls();

  multiset allmods = mkmultiset (indices (otomod));
  num_modules = 17;

  if (types_module) {
    num_modules++;
    roxen.handle (safe_stop_module, types_module, "type module");
    allmods[types_module] = 0;
  }
  if (dir_module) {
    num_modules++;
    roxen.handle (safe_stop_module, dir_module, "directory module");
    allmods[dir_module] = 0;
  }
  for(int i=0; i<10; i++)
    if (Priority p = pri[i]) {
#define STOP_MODULES(MODS, DESC)					\
      foreach(MODS, RoxenModule m)					\
        if (allmods[m]) {						\
	  num_modules++;						\
	  roxen.handle (safe_stop_module, m, DESC);			\
	  allmods[m] = 0;						\
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

  if (!asynch) {
    num_modules -= 17;
    if (num_modules) {
#ifdef THREADS
      // Relying on the interpreter lock here.
      modules_stopped->wait();
#else
      error ("num_modules shouldn't be nonzero here when running nonthreaded.\n");
#endif
    }
  }
}

string type_from_filename( string file, int|void to, string|void myext )
{
  array(string)|string tmp;
  if(!types_fun)
    return to?({ "application/octet-stream", 0 }):"application/octet-stream";

  string ext = lower_case(myext || Roxen.extension(file));

  if(tmp = types_fun(ext))
  {
    mixed tmp2,nx;
    // FIXME: Ought to support several levels of "strip".
    if (tmp[0] == "strip")
    {
      tmp2=file/".";
      if (sizeof(tmp2) > 2)
	nx=tmp2[-2];
      if (nx && (tmp2 = types_fun(nx)))
	tmp[0] = tmp2[0];
      else if (tmp2 = types_fun("default"))
	tmp[0] = tmp2[0];
      else
	tmp[0] = "application/octet-stream";
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
      foreach(indices(pri[i]->provider_modules), RoxenModule d)
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

static mapping api_module_cache = ([]);
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

#ifdef __NT__
static mixed strip_fork_information(RequestID id)
{
  array a = id->not_query/"::";
  //  FIX: Must not subtract ":" chars since it breaks proper URL:s,
  //  e.g. "/internal-roxen-colorbar:x,y,z" and several others.
  //  id->not_query = a[0]-":";
  id->not_query = a[0];
  id->misc->fork_information = a[1..];
  return 0;
}
#endif /* __NT__ */

array (function) first_modules()
{
  if(!first_module_cache)
  {
    int i;
    first_module_cache=({
#ifdef __NT__
      strip_fork_information,	// Always first!
#endif /* __NT__ */
    });
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
      log_function = roxen.LogFile( logfile )->write;
  }
}

// Parse the logging format strings.
private inline string fix_logging(string s)
{
  sscanf(s, "%*[\t ]%s", s);
  return s;
}

private void parse_log_formats()
{
  string b;
  array foo=query("LogFormat")/"\n";
  foreach(foo, b)
    if(strlen(b) && b[0] != '#' && sizeof(b/":")>1)
      log_format[(int)(b/":")[0]] = fix_logging((b/":")[1..]*":");
}

void log(mapping file, RequestID request_id)
{
  // Call all logging functions
  foreach(logger_module_cache||logger_modules(), function f)
    if( f( request_id, file ) )
      return;

  if( !log_function ) 
    return; // No file is open for logging.

  if(do_not_log_patterns && 
     Roxen._match(request_id->remoteaddr, do_not_log_patterns))
    return;

  string form;
  if(!(form=log_format[file->error])) 
    form = log_format[0];
  if(!form) return;

  roxen.run_log_format( form, log_function, request_id, file );
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
      return uid->compat_userinfo(id);
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
  foreach( auth_modules(), AuthModule method )
    if( u = method->authenticate( id, database ) )
      return id->misc->authenticated_user = u;
}

mapping authenticate_throw( RequestID id, string realm,
			    UserDB|void database)
//! Returns a reply mapping, similar to @[Roxen.http_rxml_reply] with
//! friends. If no @[database] is specified, all datbases in the
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
  Stdio.File f = lopen("data/images/dir/"+from+".gif","r");
  if (f) 
    return (["file":f, "type":"image/gif", "stat":f->stat(),]);
  else
    return 0;
  // File not found.
}

private static int nest = 0;

#ifdef MODULE_LEVEL_SECURITY
private mapping misc_cache = set_weak_flag( ([]), 1 );

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

  if(!(seclevels = misc_cache[ a ]))
  {
    RoxenModule mod = Roxen.get_owning_module (a);
    if(mod && mod->query_seclevels)
      misc_cache[ a ] = seclevels = ({
	mod->query_seclevels(),
	mod->query("_seclvl"),
      });
    else
      misc_cache[ a ] = seclevels = ({0,0});
  }

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

  report_error("check_security(): Error during module security check:\n%s\n",
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
  misc_cache = ([ ]);
#endif
}

// Empty all the caches above AND the ones in the loaded modules.
void clear_memory_caches()
{
  invalidate_cache();
  foreach(otomod; RoxenModule m; string name)
    if (m && m->clear_memory_caches)
      if (mixed err = catch( m->clear_memory_caches() ))
	report_error("clear_memory_caches() failed for module %O:\n%s\n",
		     name, describe_backtrace(err));
}

//  Returns tuple < image, mime-type >
static array(string) draw_saturation_bar(int hue,int brightness, int where)
{
  Image.Image bar=Image.Image(30,256);

  for(int i=0;i<128;i++)
  {
    int j = i*2;
    bar->line(0,j,29,j,@hsv_to_rgb(hue,255-j,brightness));
    bar->line(0,j+1,29,j+1,@hsv_to_rgb(hue,255-j,brightness));
  }

  where = 255-where;
  bar->line(0,where,29,where, 255,255,255);

#if constant(Image.JPEG) && constant(Image.JPEG.encode)
  return ({ Image.JPEG.encode(bar), "image/jpeg" });
#else
  return ({ Image.PNG.encode(bar), "image/png" });
#endif
}


// Inspired by the internal-gopher-... thingie, this is the images
// from the administration interface. :-)
private mapping internal_roxen_image( string from, RequestID id )
{
  sscanf(from, "%s.gif", from);
  sscanf(from, "%s.jpg", from);
  sscanf(from, "%s.xcf", from);
  sscanf(from, "%s.png", from);

  // Automatically generated colorbar. Used by wizard code...
  int hue,bright,w;
  if(sscanf(from, "%*s:%d,%d,%d", hue, bright,w)==4) {
    array bar = draw_saturation_bar(hue, bright, w);
    return Roxen.http_string_answer(bar[0], bar[1]);
  }

  Stdio.File f;

  if( !id->misc->internal_get )
    if(f = lopen("data/images/"+from+".gif", "r"))
      return (["file":f, "type":"image/gif", "stat":f->stat()]);

  if(f = lopen("data/images/"+from+".png", "r"))
    return (["file":f, "type":"image/png", "stat":f->stat()]);

  if(f = lopen("data/images/"+from+".jpg", "r"))
    return (["file":f, "type":"image/jpeg", "stat":f->stat()]);

  if(f = lopen("data/images/"+from+".xcf", "r"))
    return (["file":f, "type":"image/x-gimp-image", "stat":f->stat()]);

  if(f = lopen("data/images/"+from+".gif", "r"))
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
	   res = sprintf("Returned redirect to %s ", m->extra_heads->location);
	 else
	   res = "Returned redirect, but no location header. ";
	 break;

      case 401:
	 if (m->extra_heads["www-authenticate"])
	   res = sprintf("Returned authentication failed: %s ",
			 m->extra_heads["www-authenticate"]);
	 else
	   res = "Returned authentication failed. ";
	 break;

      case 200:
	 res = "Returned ok. ";
	 break;

      default:
	 res = sprintf("Returned %d. ", m->error);
   }

   if (!zero_type(m->len))
      if (m->len<0)
	 res += "No data ";
      else
	 res += sprintf("%d bytes ", m->len);
   else if (stringp(m->data))
     res += sprintf("%d bytes ", strlen(m->data));
   else if (objectp(m->file))
      if (catch {
	 Stat a=m->file->stat();
	 res += sprintf("%d bytes ", a[1]-m->file->tell());
      })
	res += "? bytes ";

   if (m->data) res += "(static)";
   else if (m->file) res += "(open file)";

   if (stringp(m->extra_heads["content-type"]) ||
       stringp(m->type)) {
      res += sprintf(" of %s", m->type||m->extra_heads["content-type"]);
   }

   return res;
}

mapping|int(-1..0) low_get_file(RequestID id, int|void no_magic)
//! The function that actually tries to find the data requested. All
//! modules except last and filter type modules are mapped, in order,
//! and the first one that returns a suitable response is used. If
//! `no_magic' is set to one, the internal magic roxen images and the
//! <ref>find_internal()</ref> callbacks will be ignored.
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
	id->misc->cacheable = 9999;
	
	TRACE_LEAVE("Magic internal roxen image");
        if(loc=="unit" || loc=="pixel-of-destiny")
	{
	  TIMER_END(internal_magic);
	  return (["data":"GIF89a\1\0\1\0\200�\0���\0\0\0!�\4\1\0\0\0\0,"
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
    if(!search(file, query("InternalLoc")))
    {
      TRACE_ENTER("Magic internal module location", 0);
      RoxenModule module;
      string name, rest;
      function find_internal;
      if(2==sscanf(file[strlen(query("InternalLoc"))..], "%s/%s", name, rest) &&
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
	      slevel = misc_cache[ find_internal ][1];
	      // misc_cache from
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

	nest ++;
	err = catch {
	  if( nest < 20 )
	    tmp = (id->conf || this_object())->low_get_file( tmp, no_magic );
	  else
	  {
	    TRACE_LEAVE("Too deep recursion");
	    error("Too deep recursion in roxen::get_file() while mapping "
		  +file+".\n");
	  }
	};
	nest = 0;
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
      if(!search(file, loc))
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
	    TRACE_LEAVE("");
	    TRACE_LEAVE(examine_return_mapping(fid));
	    TIMER_END(location_modules);
	    return fid;
	  }
	  else
	  {
#ifdef MODULE_LEVEL_SECURITY
	    int oslevel = slevel;
	    slevel = misc_cache[ tmp[1] ][1];
	    // misc_cache from
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
	TRACE_LEAVE("Returning data");

	// Keep query (if any).
	// FIXME: Should probably keep config <foo>
	string new_query = Roxen.http_encode_string(id->not_query) + "/" +
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
    TRACE_LEAVE(tmp?sprintf("Returned type %s %s.", tmp[0], tmp[1]||"")
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

mixed handle_request( RequestID id  )
{
  function funp;
  mixed file;
  REQUEST_WERR("handle_request()");
  TIMER_START(handle_request);
  TIMER_START(first_modules);
  foreach(first_module_cache||first_modules(), funp)
  {
    if(file = funp( id ))
      break;
    if(id->conf != this_object()) {
      REQUEST_WERR("handle_request(): Redirected (2)");
      return id->conf->handle_request(id);
    }
  }
  TIMER_END(first_modules);
  if(!mappingp(file) && !mappingp(file = get_file(id)))
  {
    mixed ret;
    TIMER_START(last_modules);
    foreach(last_module_cache||last_modules(), funp) if(ret = funp(id)) break;
    if (ret == 1) {
      REQUEST_WERR("handle_request(): Recurse");
      TIMER_END(last_modules);
      TIMER_END(handle_request);
      return handle_request(id);
    }
    file = ret;
    TIMER_END(last_modules);
  }
  TIMER_END(handle_request);
  REQUEST_WERR("handle_request(): Done");
  MERGE_TIMERS(roxen);
  return file;
}

mapping get_file(RequestID id, int|void no_magic, int|void internal_get)
//! Return a result mapping for the id object at hand, mapping all
//! modules, including the filter modules. This function is mostly a
//! wrapper for <ref>low_get_file()</ref>.
{
  TIMER_START(get_file);
  int orig_internal_get = id->misc->internal_get;
  id->misc->internal_get = internal_get;
  RequestID root_id = id->root_id || id;
  int sub_req_limit = query("SubRequestLimit");
  root_id->misc->_request_depth++;
  if(sub_req_limit && root_id->misc->_request_depth > sub_req_limit)
    throw( ({ "Subrequest limit reached. (Possibly an insertion loop.)", backtrace() }) );

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
      if(res && res->file && (res2->file != res->file))
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
      nest ++;

      TRACE_LEAVE("Recursing");
      file = id->not_query;
      err = catch {
	if( nest < 20 )
	  dir = (id->conf || this_object())->find_dir( file, id );
	else
	  error("Too deep recursion in roxen::find_dir() while mapping "
		+file+".\n");
      };
      nest = 0;
      TRACE_LEAVE("");
      if(err)
	throw(err);
      return dir;
    }
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
  string loc;
  mixed s, tmp;
#ifdef THREADS
  Thread.MutexKey key;
#endif
  TRACE_ENTER(sprintf("Stat file %O.", file), 0);

  file=replace(file, "//", "/"); // "//" is really "/" here...

#ifdef URL_MODULES
  // Map URL-modules
  foreach(url_modules(), function funp)
  {
    string of = id->not_query;
    id->not_query = file;

    TRACE_ENTER("URL module", funp);
    LOCK(funp);
    tmp=funp( id, file );
    UNLOCK();

    if(mappingp( tmp )) {
      id->not_query = of;
      TRACE_LEAVE("");
      TRACE_LEAVE("Returned 'No thanks'.");
      return 0;
    }
    if(objectp( tmp ))
    {
      file = id->not_query;

      mixed err;
      nest ++;
      TRACE_LEAVE("Recursing");
      err = catch {
	if( nest < 20 )
	  tmp = (id->conf || this_object())->stat_file( file, id );
	else
	  error("Too deep recursion in roxen::stat_file() while mapping "
		+file+".\n");
      };
      nest = 0;
      if(err)
	throw(err);
      TRACE_LEAVE("");
      TRACE_LEAVE("Returning data");
      return tmp;
    }
    TRACE_LEAVE("");
    id->not_query = of;
  }
#endif

  // Map location-modules.
  foreach(location_modules(), tmp)
  {
    loc = tmp[0];
    if((file == loc) || ((file+"/")==loc))
    {
      TRACE_ENTER(sprintf("Location module [%s] ", loc), tmp[1]);
      TRACE_LEAVE("Exact match.");
      TRACE_LEAVE("");
      return ({ 0775, -3, 0, 0, 0, 0, 0 });
    }
    if(!search(file, loc))
    {
      TRACE_ENTER(sprintf("Location module [%s] ", loc), tmp[1]);
#ifdef MODULE_LEVEL_SECURITY
      if(check_security(tmp[1], id)) {
	TRACE_LEAVE("");
	TRACE_LEAVE("Permission denied");
	continue;
      }
#endif
      if(s=function_object(tmp[1])->stat_file(file[strlen(loc)..], id))
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
  string data = query("ZNoSuchFile");
  NOCACHE();
#if ROXEN_COMPAT <= 2.1
  data = replace(data,({"$File", "$Me"}),
                 ({"&page.virtfile;", "&roxen.server;"}));
#endif
  mapping res = Roxen.http_rxml_answer( data, id, 0, "text/html" );
  res->error = 404;
  return res;
}

// this is not as trivial as it sounds. Consider gtext. :-)
array open_file(string fname, string mode, RequestID id, void|int internal_get)
{
  if( id->conf && (id->conf != this_object()) )
    return id->conf->open_file( fname, mode, id, internal_get );

  Configuration oc = id->conf;
  string oq = id->not_query;
  function funp;
  mapping|int(0..1) file;

  id->not_query = fname;

  foreach(first_modules(), funp)
    if(file = funp( id ))
      break;
    else if(id->conf && (id->conf != oc))
    {
      return id->conf->open_file(fname, mode,id, internal_get);
    }
  fname = id->not_query;

  if(search(mode, "R")!=-1) //  raw (as in not parsed..)
  {
    string f;
    mode -= "R";
    if(f = real_file(fname, id))
    {
      //      report_debug("opening "+fname+" in raw mode.\n");
      return ({ open(f, mode), ([]) });
    }
//     return ({ 0, (["error":302]) });
  }

  if(mode=="r")
  {
    if(!file)
    {
      file = get_file( id, 0, internal_get );
      if(!file) {
	foreach(last_modules(), funp) if(file = funp( id ))
	  break;
	if (file == 1) {
	  // Recurse.
	  return open_file(id->not_query, mode, id, internal_get);
	}
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
    return ({ file->file, file });
  }
  id->not_query = oq;
  return ({ 0, (["error":501, "data":"Not implemented." ]) });
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
      TRACE_LEAVE("Returned mapping."+sprintf("%O", tmp));
      TRACE_LEAVE("");
      return 0;
    }
    if(objectp( tmp ))
    {
      mixed err;
      nest ++;

      file = id->not_query;
      err = catch {
	if( nest < 20 )
	  tmp = (id->conf || this_object())->find_dir_stat( file, id );
	else {
	  TRACE_LEAVE("Too deep recursion");
	  error("Too deep recursion in roxen::find_dir_stat() while mapping "
		+file+".\n");
	}
      };
      nest = 0;
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
      if(check_security(tmp[1], id)) continue;
#endif
      RoxenModule c = function_object(tmp[1]);
      string f = file[strlen(loc)..];
      if (c->find_dir_stat) {
	TRACE_ENTER("Has find_dir_stat().", 0);
	if (d = c->find_dir_stat(f, id)) {
          TRACE_ENTER("Returned mapping."+sprintf("%O", d), c);
	  dir = d | dir;
	  TRACE_LEAVE("");
	}
	TRACE_LEAVE("");
      } else if(d = c->find_dir(f, id)) {
	TRACE_ENTER("Returned array.", 0);
	dir = mkmapping(d, Array.map(d, lambda(string fn)
                                        {
                                          return c->stat_file(f + fn, id);
                                        })) | dir;
	TRACE_LEAVE("");
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

int|string try_get_file(string s, RequestID id,
                        int|void status, int|void nocache,
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
  string res, q, cache_key;
  RequestID fake_id;
  mapping m;

  if(!objectp(id))
    error("No ID passed to 'try_get_file'\n");

  // id->misc->common is here for compatibility; it's better to use
  // id->root_id->misc.
  if ( !id->misc )
    id->misc = ([]);
  if ( !id->misc->common )
    id->misc->common = ([]);

  fake_id = id->clone_me();

  fake_id->misc->common = id->misc->common;
  fake_id->misc->internal_get = !not_internal;

  if (fake_id->scan_for_query)
    // FIXME: If we're using e.g. ftp this doesn't exist. But the
    // right solution might be that clone_me() in an ftp id object
    // returns a vanilla (i.e. http) id instead when this function is
    // used.
    s = fake_id->scan_for_query (s);

  s = Roxen.fix_relative (s, id);

  fake_id->raw_url=s;
  fake_id->not_query=s;
  fake_id->method = "GET";

  if(!(m = get_file(fake_id,0,!not_internal))) {
    // Might be a PATH_INFO type URL.
    m_delete (fake_id->misc, "path_info");
    array a = open_file( s, "r", fake_id, !not_internal );
    if(a && a[0]) {
      m = a[1];
      m->file = a[0];
    }
    else {
      destruct (fake_id);
      return 0;
    }
  }

  CACHE( fake_id->misc->cacheable );
  destruct (fake_id);

  if (!mappingp(m) && !objectp(m)) {
    report_error("try_get_file(%O, %O, %O, %O): m = %O is not a mapping.\n",
		 s, id, status, nocache, m);
    return 0;
  }

  if (result_mapping)
    foreach(m; string i; mixed v)
      result_mapping[i] = v;

  // Allow 2* and 3* error codes, not only a few specific ones.
  if (!(< 0,2,3 >)[m->error/100]) return 0;

  if(status) return 1;

  if(m->data)
    res = m->data;
  else
    res="";
  m->data = 0;

  if( objectp(m->file) )
  {
    res += m->file->read();
    if (m->file) {
      // Some wrappers may destruct themselves in read()...
      destruct(m->file);
    }
    m->file = 0;
  }

  if(m->raw)
  {
    res -= "\r";
    if(!sscanf(res, "%*s\n\n%s", res))
      sscanf(res, "%*s\n%s", res);
  }
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
void start(int num)
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
  foreach(modules; string modname; ModuleCopies mc)
  {
    foreach(indices(mc->copies), int i)
    {
      store(modname+"#"+i, mc->copies[i]->query(), 0, this_object());
      if (mixed err = catch(mc->copies[i]->
			    start(2, this_object())))
	report_error("Error calling start in module.\n%s",
		     describe_backtrace (err));
    }
  }
  invalidate_cache();
}

int save_one( RoxenModule o )
//! Save all variables in a given module.
{
  mapping mod;
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
  if( error = catch( o->start(2, this_object()) ) )
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
  ModuleInfo mi = roxen.find_module( (modname/"#")[0] );

  roxen->bootstrap_info->set (({this_object(), modname }));

  if( !old_module ) return 0;

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
  nm = mi->instance( this_object() );
  // If this is a faked module, let's call it a failure.
  if( nm->not_a_module )
  {
    old_module->report_error("Reload failed\n");
    return old_module;
  }

  disable_module( modname, 1 );
  destruct( old_module ); 

  mi->update_with( nm,0 ); // This is sort of nessesary...
  enable_module( modname, nm, mi );

  foreach (old_error_log, [string msg, array(int) times])
    nm->error_log[msg] += times;

  nm->report_notice("Reloaded " + mi->get_name() + ".\n");
  return nm;
}

#ifdef THREADS
Thread.Mutex enable_modules_mutex = Thread.Mutex();
#define MODULE_LOCK(TYPE) \
  Thread.MutexKey enable_modules_lock = enable_modules_mutex->lock (TYPE)
#else
#define MODULE_LOCK(TYPE)
#endif

static int enable_module_batch_msgs;

RoxenModule enable_module( string modname, RoxenModule|void me, 
                           ModuleInfo|void moduleinfo, 
                           int|void nostart, int|void nosave )
{
  MODULE_LOCK (2);
  int id;
  ModuleCopies module;
  int pr;
  mixed err;
  int module_type;

  if( forcibly_added[modname] == 2 )
    return search(otomod, modname);
  
  if( datacache ) datacache->flush();

  if( sscanf(modname, "%s#%d", modname, id ) != 2 )
    while( modules[ modname ] && modules[ modname ][ id ] )
      id++;

  roxen->bootstrap_info->set (({this_object(), modname + "#" + id}));

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
      roxen->bootstrap_info->set (0);
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
    if(err = catch(me = moduleinfo->instance(this_object())))
    {
#ifdef MODULE_DEBUG
      if (enable_module_batch_msgs) report_debug("\bERROR\n");
      if (err != "") {
#endif
	string bt=describe_backtrace(err);
	report_error("enable_module(): Error while initiating module copy of %s%s",
		     moduleinfo->get_name(), (bt ? ":\n"+bt : "\n"));
#ifdef MODULE_DEBUG
      }
#endif
      got_no_delayed_load = -1;
      roxen->bootstrap_info->set (0);
      return module[id];
    }
  }

  if(module[id] && module[id] != me)
  {
    if( module[id]->stop ) {
      if (err = catch( module[id]->stop() )) {
	string bt=describe_backtrace(err);
	report_error("disable_module(): Error while disabling module %s%s",
		     descr, (bt ? ":\n"+bt : "\n"));
      }
    }
  }

  me->set_configuration( this_object() );

  module_type = moduleinfo->type;
  if (module_type & (MODULE_LOCATION|MODULE_EXTENSION|
                     MODULE_CONFIG|MODULE_FILE_EXTENSION|MODULE_LOGGER|
                     MODULE_URL|MODULE_LAST|MODULE_PROVIDER|
                     MODULE_FILTER|MODULE_TAG|MODULE_FIRST|MODULE_USERDB))
  {
    if(module_type != MODULE_CONFIG)
    {
      if (err = catch {
	me->defvar("_priority", 5, "Priority", TYPE_INT_LIST,
		   ("The priority of the module. 9 is highest and 0 is lowest."
		    " Modules with the same priority can be assumed to be "
		    "called in random order"),
		   ({0, 1, 2, 3, 4, 5, 6, 7, 8, 9}));
      }) {
	roxen->bootstrap_info->set (0);
	throw(err);
      }
    }

#ifdef MODULE_LEVEL_SECURITY
    if( (module_type & ~(MODULE_LOGGER|MODULE_PROVIDER|MODULE_USERDB)) != 0 )
    {
//       me->defvar("_sec_group", "user", "Security: Realm",
// 		 TYPE_STRING,
// 		 ("The realm to use when requesting password from the "
//		  "client. Usually used as an informative message to the "
// 		  "user."));
      
      me->defvar("_seclevels", "", "Security: Patterns",
		 TYPE_TEXT_FIELD,
		 #"The syntax is:
<dl>
  <dt><b>userdb</b> <i>userdatabase module</i></dt>
  <dd> Select a non-default userdatabase module. The default is to
       search all modules. The userdatabase module config_userdb is always
       present, and contains the configuration users</dd>
  <dt><b>authmethod</b> <i>authentication module</i></dt>
  <dd>Select a non-default authentication method.</dd>
  <dt><b>realm</b> <i>realm name</i></dt>
  <dd>The realm is used when user authentication info is requested</dd>
</dl>

Below, CMD is one of 'allow' and 'deny'
<dl>
  <dt>CMD <b>ip</b>=<i>ip/bits</i>  [return]<br />
      CMD <b>ip</b>=<i>ip:mask</i>  [return] <br />
      CMD <b>ip</b>=<i>pattern[,pattern,...]</i>  [return] <br /></dt>
  <dd>Match the remote IP-address.</dd>

  <dt>CMD <b>user</b>=<i>name[,name,...]</i>  [return]</dt>
  <dd>Requires a authenticated user. If the user name 'any' is used, any
      valid user will be OK. Otherwise, one of the listed users are required.
      </dd>
  <dt>CMD <b>group</b>=<i>name[,name,...]</i> [return]</dt>
  <dd>Requires a authenticated user with a group. If the group name
      'any' is used, any valid group will be OK. Otherwise, one of the
      listed groups are required.</dd>

  <dt>CMD <b>dns</b>=<i>pattern[,pattern,...]</i>           [return]</dt>
  <dd>Require one of the specified DNS domain-names</dd>

  <dt>CMD <b>time</b>=<i>HH:mm-HH:mm</i>   [return]</dt>
  <dd>Only allow access to the module from the first time to the
      second each day. Both times should be specified in 24-hour
      HH:mm format.</dd>
  <dt>CMD <b>day</b>=<i>day[,day,...]</i> [return]</dt>
  <dd>Only allow access during certain days. Day is either a numerical
      value (monday=1, sunday=7) or a string (monday, thuesday etc)</dd>
</dl>
<p>pattern is always a glob pattern (* = any characters, ? = any character).</p>
<p>return means that reaching this command results in immediate
   return, only useful for 'allow'.</p>

<p>'deny' always implies a return, no futher testing is done if a
   'deny' match.</p>
");

      if(!(module_type & MODULE_PROXY))
      {
	me->defvar("_seclvl", 0, "Security: Security level",
		   TYPE_INT,
		   #"The modules security level is used to determine if a
request should be handled by the module.
<p><h2>Security level vs Trust level</h2>
 Each module has a configurable <i>security level</i>.
 Each request has an assigned trust level. Higher
 <i>trust levels</i> grants access to modules with higher
 <i>security levels</i>.</p>

<p><h2>Definitions</h2><ul>
 <li>A requests initial Trust level is infinitely high.</li>
 <li> A request will only be handled by a module if its
     <i>trust level</i> is higher or equal to the
     <i>security level</i> of the module.</li>
 <li> Each time the request is handled by a module the
     <i>trust level</i> of the module will be set to the
        lower of its <i>trust level</i> and the modules
     <i>security level</i>, <i>unless</i> the security
        level of the module is 0, which is a special
        case and means that no change should be made.</li>
</ul></p>

<p><h2>Example</h2>
 Modules:<ul>
 <li>  User filesystem, <i>security level</i> 1</li>
 <li>  Filesystem module, <i>security level</i> 3</li>
 <li>  CGI module, <i>security level</i> 2</li>
</ul></p>

<p>A request handled by \"User filesystem\" is assigned
   a <i>trust level</i> of one after the <i>security
   level</i> of that module. That request can then not be
   handled by the \"CGI module\" since that module has a
   higher <i>security level</i> than the requests trust
   level.</p>

<p>On the other hand, a request handled by the the
   \"Filsystem module\" could later be handled by the
   \"CGI module\".</p>");

      }
      else
	me->definvisvar("_seclvl", -10, TYPE_INT); // A very low one
    }
#endif
  }
  else
    me->defvar("_priority", 0, "", TYPE_INT, "", 0, 1);

  mapping(string:mixed) stored_vars = retrieve(modname + "#" + id, this_object());
  int has_stored_vars = sizeof (stored_vars); // A little ugly, but it suffices.
  me->setvars(stored_vars);

  module[ id ] = me;
  otomod[ me ] = modname+"#"+id;

  if(!nostart) call_start_callbacks( me, moduleinfo, module );

#ifdef MODULE_DEBUG
  if (enable_module_batch_msgs) {
    if(moduleinfo->config_locked[this_object()])
      report_debug("\bLocked %6.1fms\n", (gethrtime()-start_time)/1000.0);
    else
      report_debug("\bOK %6.1fms\n", (gethrtime()-start_time)/1000.0);
  }
#else
  if(moduleinfo->config_locked[this_object()])
    report_error("   Error: \"%s\" not loaded (license restriction).\n",
		 moduleinfo->get_name());
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

  roxen->bootstrap_info->set (0);
  return me;
}

void call_start_callbacks( RoxenModule me, 
                           ModuleInfo moduleinfo, 
                           ModuleCopies module )
{
  if(!me) return;
  if(!moduleinfo) return;
  if(!module) return;

  call_low_start_callbacks(  me, moduleinfo, module );

  mixed err;
  if((me->start) && (err = catch( me->start(0, this_object()) ) ) )
  {
#ifdef MODULE_DEBUG
    if (enable_module_batch_msgs) 
      report_debug("\bERROR\n");
#endif
    string bt=describe_backtrace(err);
    report_error("Error while initiating module copy of %s%s",
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
    report_error("Error while initiating module copy of %s%s",
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
      report_error("Error while initiating module copy of %s%s",
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
      report_error("Error while initiating module copy of %s%s",
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

  invalidate_cache();
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
      foreach( values (pri[pr]->file_extension_modules), array mods )
	mods -= ({me});
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
}

int disable_module( string modname, int|void nodest )
{
  MODULE_LOCK (2);
  RoxenModule me;
  int id, pr;
  sscanf(modname, "%s#%d", modname, id );

  if( datacache ) datacache->flush();

  ModuleInfo moduleinfo =  roxen.find_module( modname );
  mapping module = modules[ modname ];
  string descr = moduleinfo->get_name() + (id ? " copy " + (id + 1) : "");

  if(!module)
  {
    report_error("disable_module(): Failed to disable module:\n"
		 "No module by that name: %O.\n", modname);
    return 0;
  }

  me = module[id];
  m_delete(module->copies, id);

  if(!sizeof(module->copies))
    m_delete( modules, modname );

  invalidate_cache();

  if(!me)
  {
    report_error("disable_module(): Failed to disable module %O.\n", descr);
    return 0;
  }

  if(me->stop)
    if (mixed err = catch (me->stop())) {
      string bt=describe_backtrace(err);
      report_error("disable_module(): Error while disabling module %s%s",
		   descr, (bt ? ":\n"+bt : "\n"));
    }

#ifdef MODULE_DEBUG
  report_debug("Disabling "+descr+"\n");
#endif

  clean_up_for_module( moduleinfo, me );

  if( !nodest )
  {
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

Sql.Sql sql_connect(string db)
{
  if (sql_urls[db])
    return sql_cache_get(sql_urls[db]);
  else
    return sql_cache_get(db);
}

// END SQL
#endif

static string my_url;

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
}

//! Returns some URL for accessing the configuration. (Should be
//! used instead of querying MyWorldLocation directly.)
string get_url() {return my_url;}

array after_init_hooks = ({});
mixed add_init_hook( mixed what )
{
  if( inited )
    call_out( what, 0, this_object() );
  else
    after_init_hooks |= ({ what });
}

static int got_no_delayed_load = 0;
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
  low_init( );
  fix_no_delayed_load_flag();
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
    enabled_modules = retrieve("EnabledModules", this_object());
//     roxenloader.LowErrorContainer ec = roxenloader.LowErrorContainer();
//     roxenloader.push_compile_error_handler( ec );

    array modules_to_process = indices( enabled_modules );
    string tmp_string;

    mixed err;
    forcibly_added = ([]);
    enable_module_batch_msgs = 1;
    foreach( modules_to_process, tmp_string )
    {
      if( !forcibly_added[ tmp_string ] )
	if(err = catch( enable_module( tmp_string )))
	{
	  report_error("Failed to enable the module %s. Skipping.\n%s\n",
		       tmp_string, describe_backtrace(err));
	  got_no_delayed_load = -1;
	}
    }
    enable_module_batch_msgs = 0;
    roxenloader.pop_compile_error_handler();
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
    report_notice("All modules for %s enabled in %3.1f seconds\n\n",
		  query_name(), (gethrtime()-start_time)/1000000.0);

#ifdef SNMP_AGENT
  // Start trap after real virt.serv. loading
  if(query("snmp_process") && objectp(roxen->snmpagent))
    roxen->snmpagent->vs_start_trap(get_config_id());
#endif

}

DataCache datacache;

static void create()
{
  if (!name) error ("Configuration name not set through bootstrap_info.\n");
//   int st = gethrtime();
  roxen.add_permission( "Site:"+name, "Site: "+name );

  // for now only these two. In the future there might be more variables.
  defvar( "data_cache_size", 16384, "Cache:Cache size",
          TYPE_INT| VAR_PUBLIC,
          ("The size of the data cache used to speed up requests "
	   "for commonly requested files, in KBytes"));

  defvar( "data_cache_file_max_size", 100, "Cache:Max file size",
          TYPE_INT | VAR_PUBLIC,
          "The maximum size of a file that is to be considered for the cache");

  defvar("default_server", 0, "Default site",
	 TYPE_FLAG| VAR_PUBLIC,
	 ("If true, this site will be selected in preference of "
	  "other sites when virtual hosting is used and no host "
	  "header is supplied, or the supplied host header does not "
	  "match the address of any of the other servers.") );

  defvar("comment", "", "Site comment",
	 TYPE_TEXT_FIELD|VAR_MORE,
	 ("This text will be visible in the administration "
	  "interface, it can be quite useful to use as a memory helper."));

  defvar("name", "", "Site name",
	 TYPE_STRING|VAR_MORE| VAR_PUBLIC|VAR_NO_DEFAULT,
	 ("This is the name that will be used in the administration "
	  "interface. If this is left empty, the actual name of the "
	  "site will be used."));

  defvar("compat_level", Variable.StringChoice (
	   "", roxen.compat_levels, VAR_NO_DEFAULT,
	   "Compatibility level",
	   ("<p>The compatibility level is used by different modules to select "
	    "the right behavior to remain compatible with earlier Roxen "
	    "versions. When a server configuration is created, this variable "
	    "is set to the latest version. After that it's never changed "
	    "automatically, thereby ensuring that server configurations "
	    "migrated from earlier Roxen versions is kept at the right "
	    "compatibility level.\n"
	    "</p><p>\n"
	    "This variable may be changed manually, but it's advisable to "
	    "test the site carefully afterwards. A reload of the whole "
	    "server configuration is required to propagate the change properly "
	    "to all modules.</p>")));
  set ("compat_level", roxen.__roxen_version__);
  // Note to developers: This setting can be accessed through
  // id->conf->query("compat_level") or similar, but observe that that
  // call is not entirely cheap. It's therefore advisable to put it in
  // a local variable if the compatibility level is to be tested
  // frequently. It's perfectly all right to do that in e.g. the
  // module start function, since the documentation explicitly states
  // that a reload of all modules is necessary to propagate a change
  // the setting.

  defvar("Log", 1, "Logging: Enabled",
	 TYPE_FLAG, "Log requests");

  defvar("LogFormat",
	 "404: $host $referer - [$cern_date] \"$method $resource $protocol\" 404 -\n"
	 "500: $host $referer ERROR [$cern_date] \"$method $resource $protocol\" 500 -\n"
	 "*: $host - - [$cern_date] \"$method $resource $protocol\" $response $length",
	 "Logging: Format",
	 TYPE_TEXT_FIELD|VAR_MORE,
	 #"What format to use for logging. The syntax is:
<pre>response-code or *: Log format for that response code

Log format is normal characters, or one or more of the variables below:

\\n \\t \\r        -- As in C, newline, tab and linefeed
$char(int)      -- Insert the (1 byte) character specified by the integer.
$wchar(int)     -- Insert the (2 byte) word specified by the integer.
$int(int)       -- Insert the (4 byte) word specified by the integer.
$^              -- Supress newline at the end of the logentry
$host           -- The remote host name, or ip number.
$vhost          -- The Host request-header sent by the client, or - if none
$ip_number      -- The remote ip number.
$bin-ip_number  -- The remote host id as a binary integer number.
$cern_date      -- Cern Common Log file format date.
$bin-date       -- Time, but as an 32 bit integer in network byteorder
$method         -- Request method
$resource       -- Resource identifier
$full_resource  -- Full requested resource, including any query fields
$protocol       -- The protocol used (normally HTTP/1.0)
$response       -- The response code sent
$bin-response   -- The response code sent as a binary short number
$length         -- The length of the data section of the reply
$bin-length     -- Same, but as an 32 bit integer in network byteorder
$request-time   -- The time the request took (seconds)
$referer        -- The header 'referer' from the request, or '-'.
$user_agent     -- The header 'User-Agent' from the request, or '-'.
$user_agent_raw -- Same, but spaces in the name are not encoded to %20.
$user           -- the name of the auth user used, if any
$user_id        -- A unique user ID, if cookies are supported,
                   by the client, otherwise '0'
$cache-status   -- A comma separated list of words (containing no
                   whitespace) that describes which cache(s) the page
                   was delivered from:
                   protcache -- The low-level cache in the HTTP
                                protocol module.
                   xsltcache -- The XSLT cache.
                   pcoderam  -- RXML parse tree RAM cache.
                   pcodedisk -- RXML parse tree persistent cache.
                   cachetag  -- No RXML &lt;cache&gt; tag misses.
                   nocache   -- No hit in any known cache.
</pre>", 0, lambda(){ return !query("Log");});

  // FIXME: Mention it is relative to getcwd(). Can not be localized in pike 7.0.
  defvar("LogFile", "$LOGDIR/"+Roxen.short_name(name)+"/Log",
	 "Logging: Log file", TYPE_FILE,
	 "The log file. "
	 ""
	 "A file name. Some substitutions will be done:"
	 "<pre>"
	 "%y    Year  (e.g. '1997')\n"
	 "%m    Month (e.g. '08')\n"
	 "%d    Date  (e.g. '10' for the tenth)\n"
	 "%h    Hour  (e.g. '00')\n"
	 "%H    Hostname\n"
	 "</pre>"
	 ,0, lambda(){ return !query("Log");});

  defvar("NoLog", ({ }),
	 "Logging: No Logging for", TYPE_STRING_LIST|VAR_MORE,
	 ("Don't log requests from hosts with an IP number which "
	  "matches any of the patterns in this list. This also affects "
	  "the access counter log."),
	 0, lambda(){ return !query("Log");});

  defvar("Domain", roxen.get_domain(), "Domain",
	 TYPE_STRING|VAR_PUBLIC|VAR_NO_DEFAULT,
	 ("The domain name of the server. The domain name is used "
	  "to generate default URLs, and to generate email addresses."));

  defvar("MyWorldLocation", "",
         "Ports: Primary Server URL", TYPE_URL|VAR_PUBLIC,
	 #"\
<p>This is the main server URL, where your start page is located. This
setting is for instance used as fallback to generate absolute URLs to
the server, but in most circumstances the URLs sent by the clients are
used. A URL is deduced from the first entry in 'URLs' if this is left
blank.</p>

<p>Note that setting this doesn't make the server accessible; you must
also set 'URLs'.</p>");

  defvar("URLs", 
         Variable.PortList( ({"http://*/"}), VAR_INITIAL|VAR_NO_DEFAULT,
           "Ports: URLs",
	   ("Bind to these URLs. You can use '*' and '?' to perform "
	    "globbing (using any of these will default to binding to "
	    "all IP-numbers on your machine).  If you specify a IP# in "
	    "the field it will take precedence over the hostname.")));

  defvar("InternalLoc", "/_internal/",
	 "Internal module resource mountpoint",
         TYPE_LOCATION|VAR_MORE|VAR_DEVELOPER,
         ("Some modules may want to create links to internal "
	  "resources. This setting configures an internally handled "
	  "location that can be used for such purposes.  Simply select "
	  "a location that you are not likely to use for regular "
	  "resources."));
  
  defvar("SubRequestLimit", 30,
	 "Subrequest depth limit",
	 TYPE_INT | VAR_MORE,
	 "A limit for the number of nested sub requests for each request. "
	 "This is intented to catch unintended infinite loops when for example "
	 "inserting files in RXML. 0 for no limit." );

  // Throttling-related variables

  defvar("throttle", 0,
         "Throttling: Server; Enabled", TYPE_FLAG,
	 ("If set, per-server bandwidth throttling will be enabled. "
	  "It will allow you to limit the total available bandwidth for "
	  "this site.<br />Bandwidth is assigned using a Token Bucket. "
	  "The principle under which it works is: for each byte we send we use a token. "
	  "Tokens are added to a repository at a constant rate. When there's not enough, "
	  "we can't transmit. When there's too many, they \"spill\" and are lost."));
  //TODO: move this explanation somewhere on the website and just put a link.

  defvar("throttle_fill_rate", 102400,
         "Throttling: Server; Average available bandwidth",
         TYPE_INT,
	 ("This is the average bandwidth available to this site in "
	  "bytes/sec (the bucket \"fill rate\")."),
         0, arent_we_throttling_server);

  defvar("throttle_bucket_depth", 1024000,
         "Throttling: Server; Bucket Depth", TYPE_INT,
	 ("This is the maximum depth of the bucket. After a long enough period "
	  "of inactivity, a request will get this many unthrottled bytes of data, before "
	  "throttling kicks back in.<br>Set equal to the Fill Rate in order not to allow "
	  "any data bursts. This value determines the length of the time over which the "
	  "bandwidth is averaged."), 0, arent_we_throttling_server);

  defvar("throttle_min_grant", 1300,
         "Throttling: Server; Minimum Grant", TYPE_INT,
	 ("When the bandwidth availability is below this value, connections will "
	  "be delayed rather than granted minimal amounts of bandwidth. The purpose "
	  "is to avoid sending too small packets (which would increase the IP overhead)."),
         0, arent_we_throttling_server);

  defvar("throttle_max_grant", 14900,
         "Throttling: Server; Maximum Grant", TYPE_INT,
	 ("This is the maximum number of bytes assigned in a single request "
	  "to a connection. Keeping this number low will share bandwidth more evenly "
	  "among the pending connections, but keeping it too low will increase IP "
	  "overhead and (marginally) CPU usage. You'll want to set it just a tiny "
	  "bit lower than any integer multiple of your network's MTU (typically 1500 "
	  "for ethernet)."), 0, arent_we_throttling_server);

  defvar("req_throttle", 0,
         "Throttling: Request; Enabled", TYPE_FLAG,
	 "If set, per-request bandwidth throttling will be enabled.");

  defvar("req_throttle_min", 1024,
         "Throttling: Request; Minimum guarranteed bandwidth",
         TYPE_INT,
	 ("The maximum bandwidth each connection (in bytes/sec) can use is determined "
	  "combining a number of modules. But doing so can lead to too small "
	  "or even negative bandwidths for particularly unlucky requests. This variable "
	  "guarantees a minimum bandwidth for each request."),
         0, arent_we_throttling_request);

  defvar("req_throttle_depth_mult", 60.0,
         "Throttling: Request; Bucket Depth Multiplier",
         TYPE_FLOAT,
	 ("The average bandwidth available for each request will be determined by "
	  "the modules combination. The bucket depth will be determined multiplying "
	  "the rate by this factor."),
         0, arent_we_throttling_request);


  defvar("404-files", ({ "404.inc" }),
	 "No such file message override files",
	 TYPE_STRING_LIST|VAR_PUBLIC,
	 ("<p>If no file match a given resource all directories above the "
	  "wanted file is searched for one of the files in this list.</p>"
	  "\n"
	  "<p>As an example, if the file /foo/bar/not_there.html is "
	  "wanted, and this list contains the default value of 404.inc, "
	  "these files will be searched for, in this order:</p><br /> "
	  "/foo/bar/404.inc, /foo/404.inc and /404.inc." ) );

  defvar("license",
	 License.
	 LicenseVariable("../license/", VAR_NO_DEFAULT, "License file",
			 "The license file for this configuration.",
			 this_object()));

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
   <set variable='var.base' value=''/>
   <emit source='path'>
     <append variable='var.base' value='/&_.name;'/>
     <set variable='var.404' value='&var.base;/&ef.value;'/>
     <if exists='&var.404;'>
       <set variable='var.errfile' from='var.404'/>
     </if>
   </emit>
</emit>
</nooutput><if variable='var.errfile'><eval><insert file='&var.errfile;'/></eval></if><else><eval>&modvar.site.404-message:none;</eval></else>", 0, 0, 0 );
    }
  };
  
  defvar("ZNoSuchFile", NoSuchFileOverride() );

  defvar("404-message", #"<html><head>
<title>404 - Page not found</title>
</head>
<body alink=\"#000000\" bgcolor=\"#ffffff\" bottommargin=\"0\" leftmargin=\"0\" link=\"#ce5c00\" marginheight=\"2\" marginwidth=\"0\" rightmargin=\"0\" text=\"#333333\" topmargin=\"2\" vlink=\"#ce5c00\">

<if nserious=''><set variable='var.404' value='-sorry' /></if>

<table width=\"100%\"  border=\"0\" cellspacing=\"0\" cellpadding=\"0\">
  <tr>
    <td><img src=\"/internal-roxen-page-not-found&var.404;\" border=\"0\" alt=\"Page not found\" width=\"404\" hspace=\"2\" /></td>
    <td>&nbsp;</td>
    <td align=\"right\"><font face=\"lucida,helvetica,arial\">
      <if variable='roxen.product-name is Roxen CMS'>
        <b>Roxen CMS&nbsp;</b>
      </if>
      <else>
        <b>Internet Server &roxen.base-version;&nbsp;</b>
      </else>
    </font></td>
  </tr>
  <tr>
    <td width=\"100%\" height=\"21\" colspan=\"3\" background=\"/internal-roxen-tile\"><img src=\"/internal-roxen-unit\" alt=\"\" /></td>
  </tr>
</table>

<font face=\"lucida,helvetica,arial\">
<h2>&nbsp;Unable to retrieve &page.virtfile;.</h2>
<br /><br />
<blockquote>

If you feel that this is a configuration error,
please contact the administrators of this
webserver or the author of the
<if referrer=''>
<a href=\"&client.referrer;\">referring</a>
</if><else>
referring
</else>
page.

</blockquote>
</font>
</body>
</html>
",
	 "No such file message",
	 TYPE_TEXT_FIELD|VAR_PUBLIC,
	 ("What to return when there is no resource or file "
	  "available at a certain location."));

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

  if (query("snmp_process")) {
    if(objectp(roxen()->snmpagent)) {
      int servid;
      servid = roxen()->snmpagent->add_virtserv(get_config_id());
      // todo: make invisible varibale and set it to this value for future reference
      // (support for per-reload persistence of server index?)
    } else
      report_error("SNMPagent: something gets wrong! The main agent is disabled!\n");  }
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
}

static int arent_we_throttling_server () {
  return !query("throttle");
}
static int arent_we_throttling_request() {
  return !query("req_throttle");
}

#ifdef SNMP_AGENT
private static int(0..1) snmp_disabled() {
  return (!snmp_global_disabled() && !query("snmp_process"));
}
private static int(0..1) snmp_global_disabled() {
  return (!objectp(roxen->snmpagent));
}
#endif

