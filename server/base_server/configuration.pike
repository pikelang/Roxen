string cvs_version = "$Id: configuration.pike,v 1.20 1997/04/07 23:23:38 per Exp $";
#include <module.h>
#include <roxen.h>
/* A configuration.. */

inherit "roxenlib";

import Array;


function store = roxen->store;
function retrieve = roxen->retrieve;
function remove = roxen->remove;
function do_dest = roxen->do_dest;
function create_listen_socket = roxen->create_listen_socket;



object   parse_module;
object   types_module;
object   auth_module;
object   dir_module;

function types_fun;
function auth_fun;

string name;

/* Since the main module (Roxen, formerly Spinner, alias spider), does
 * not have any clones its settings must be stored somewhere else.
 * This looked like a likely spot.. :)
 */
mapping variables = ([]); 

public mixed query(string var)
{
  if(var && variables[var])
    return variables[var][ VAR_VALUE ];
  if(!var) return variables;
  error("query("+var+"): Unknown variable.\n");
}

mixed set(string var, mixed val)
{
#if DEBUG_LEVEL > 30
  perror(sprintf("MAIN: set(\"%s\", %O)\n", var, val));
#endif
  if(variables[var])
  {
#if DEBUG_LEVEL > 28
    perror("MAIN:    Setting global variable.\n");
#endif
    return variables[var][VAR_VALUE] = val;
  }
  error("set("+var+"). Unknown variable.\n");
}

int setvars( mapping (string:mixed) vars )
{
  string v;
//  perror("Setting variables to %O\n", vars);
  foreach( indices( vars ), v )
    if(variables[v])
      variables[v][ VAR_VALUE ] = vars[ v ];
  return 1;
}



void killvar(string name)
{
  m_delete(variables, name);
}

varargs int defvar(string var, mixed value, string name, int type,
		   string doc_str, mixed misc, int|function not_in_config)
{
  variables[var]                = allocate( VAR_SIZE );
  variables[var][ VAR_VALUE ]        = value;
  variables[var][ VAR_TYPE ]         = type;
  variables[var][ VAR_DOC_STR ]      = doc_str;
  variables[var][ VAR_NAME ]         = name;
  variables[var][ VAR_MISC ]         = misc;
  if(intp(not_in_config))
    variables[var][ VAR_CONFIGURABLE ] = !not_in_config;
  else
    variables[var][ VAR_CONFIGURABLE ] = not_in_config;
  variables[var][ VAR_SHORTNAME ] = var;
}

int definvisvar(string var, mixed value, int type)
{
  return defvar(var, value, "", type, "", 0, 1);
}


string query_name()
{
  if(strlen(QUERY(name))) return QUERY(name);
  return name;
}

string comment()
{
  return QUERY(comment);
}

class Priority 
{
  array (object) url_modules = ({ });
  array (object) logger_modules = ({ });
  array (object) location_modules = ({ });
  array (object) filter_modules = ({ });
  array (object) last_modules = ({ });
  array (object) first_modules = ({ });
  
  mapping (string:array(object)) extension_modules = ([ ]);
  mapping (string:array(object)) file_extension_modules = ([ ]);


  void stop()
  {
    foreach(url_modules, object m)      catch { m->stop(); };
    foreach(logger_modules, object m)   catch { m->stop(); };
    foreach(filter_modules, object m)  catch { m->stop(); };
    foreach(location_modules, object m)catch { m->stop(); };
    foreach(last_modules, object m)    catch { m->stop(); };
    foreach(first_modules, object m)    catch { m->stop(); };
  }
}



/* A 'pri' is one of the ten priority objects. Each one holds a list
 * of modules for that priority. They are all merged into one list for
 * performance reasons later on.
 */

array (object) allocate_pris()
{
  int a;
  array (object) tmp;
  tmp=allocate(10);
  for(a=0; a<10; a++)  tmp[a]=Priority();
  return tmp;
}

class Bignum {
//object this = this_object();
// constant This = object_program(this_object());
#if efun(Mpz) && 0
  inherit Mpz;
  float mb()
  {
    return (float)this_object()/(1024.0*1024.0);
  }
#else
  int msb;
  int lsb=-0x7ffffffe;

  object `-(int i);
  object `+(int i)
  {
    if(!i) return this_object();
    if(i<0) return `-(-i);
    object res = object_program(this_object())(lsb+i,msb,2);
    if(res->lsb < lsb) res->msb++;
    return res;
  }

  object `-(int i)
  {
    if(!i) return this_object();
    if(i<0) return `+(-i);
    object res = object_program(this_object())(lsb-i,msb,2);
    if(res->lsb > lsb) res->msb--;
    return res;
  }

  float mb()
  {
    return ((((float)lsb/1024.0/1024.0)+2048.0)+(msb*4096.0));
  }

  void create(int|void num, int|void bnum, int|void d)
  {
    if(!d)
      lsb = num-0x7ffffffe;
    else
      lsb = num;
    msb = bnum;
  }
#endif
}



/* For debug and statistics info only */
int requests;

object sent=Bignum();     // Sent data
object hsent=Bignum();    // Sent headers
object received=Bignum(); // Received data

object this = this_object();


// Used to store 'parser' modules before the main parser module
// is added to the configuration.

private object *_toparse_modules = ({});

// Will write a line to the log-file. This will probably be replaced
// entirely by log-modules in the future, since this would be much
// cleaner.

private function log_function;

// The logging format used. This will probably move the the above
// mentioned module in the future.
private mapping (string:string) log_format = ([]);

// A list of priority objects (used like a 'struct' in C, really)
private array (object) pri = allocate_pris();

// All enabled modules in this virtual server.
// The format is "module#copy":([ module_info ])
public mapping (string:mapping(string:mixed)) modules = ([]);

// A mapping from objects to module names
public mapping (object:string) otomod = ([]);


// Caches to speed up the handling of the module search.
// They are all sorted in priority order, and created by the functions
// below.
private array (function) url_module_cache, last_module_cache;
private array (function) logger_module_cache, first_module_cache;
private array (function) filter_module_cache;
private array (array (string|function)) location_module_cache;
private mapping (string:array (function)) extension_module_cache=([]);
private mapping (string:array (function)) file_extension_module_cache=([]);


// Call stop in all modules.
void stop()
{
  catch { parse_module->stop(); };
  catch { types_module->stop(); };
  catch { auth_module->stop(); };
  catch { dir_module->stop(); };
  for(int i=0; i<10; i++) catch { pri[i]->stop(); };
}

public varargs string type_from_filename( string file, int to )
{
  mixed tmp;
  object current_configuration;
  string ext=extension(file);
    
  if(!types_fun)
    return to?({ "application/octet-stream", 0 }):"application/octet-stream";

  while(file[-1] == '/') 
    file = file[0..strlen(file)-2]; // Security patch? 
  
  if(tmp = types_fun(ext))
  {
    mixed tmp2,nx;
    if(tmp[0] == "strip")
    {
      tmp2=file/".";
      if(sizeof(tmp2) > 2)
	nx=tmp2[-2];
      if(nx && (tmp2=types_fun(nx)))
	tmp[0] = tmp2[0];
      else
	if(tmp2=types_fun("default"))
	  tmp[0] = tmp2[0];
	else
	  tmp[0]="application/octet-stream";
    }
    return to?tmp:tmp[0];
  } else {
    if(!(tmp=types_fun("default")))
      tmp=({ "application/octet-stream", 0 });
  }
  return 0;
}



array (function) extension_modules(string ext, object id)
{
  if(!extension_module_cache[ext])
  { 
    int i;
    extension_module_cache[ext]  = ({ });
    for(i=9; i>=0; i--)
    {
      object *d, p;
      if(d = pri[i]->extension_modules[ext])
	foreach(d, p)
	  extension_module_cache[ext] += ({ p->handle_extension });
    }
  }
  return extension_module_cache[ext];
}

array (function) file_extension_modules(string ext, object id)
{
  if(!file_extension_module_cache[ext])
  { 
    int i;
    file_extension_module_cache[ext]  = ({ });
    for(i=9; i>=0; i--)
    {
      object *d, p;
      if(d = pri[i]->file_extension_modules[ext])
	foreach(d, p)
	  file_extension_module_cache[ext] += ({ p->handle_file_extension });
    }
  }
  return file_extension_module_cache[ext];
}

array (function) url_modules(object id)
{
  if(!url_module_cache)
  {
    int i;
    url_module_cache=({ });
    for(i=9; i>=0; i--)
    {
      object *d, p;
      if(d=pri[i]->url_modules)
	foreach(d, p)
	  url_module_cache += ({ p->remap_url });
    }
  }
  return url_module_cache;
}

array (function) logger_modules(object id)
{
  if(!logger_module_cache)
  {
    int i;
    logger_module_cache=({ });
    for(i=9; i>=0; i--)
    {
      object *d, p;
      if(d=pri[i]->logger_modules)
	foreach(d, p)
	  if(p->log)
	    logger_module_cache += ({ p->log });
    }
  }
  return logger_module_cache;
}

array (function) last_modules(object id)
{
  if(!last_module_cache)
  {
    int i;
    last_module_cache=({ });
    for(i=9; i>=0; i--)
    {
      object *d, p;
      if(d=pri[i]->last_modules)
	foreach(d, p)
	  if(p->last_resort)
	    last_module_cache += ({ p->last_resort });
    }
  }
  return last_module_cache;
}

array (function) first_modules(object id)
{
  if(!first_module_cache)
  {
    int i;
    first_module_cache=({ });
    for(i=9; i>=0; i--)
    {
      object *d, p;
      if(d=pri[i]->first_modules)
	foreach(d, p)
	  if(p->first_try)
	    first_module_cache += ({ p->first_try });
    }
  }
  return first_module_cache;
}


array location_modules(object id)
{
  if(!location_module_cache)
  {
    int i;
    location_module_cache=({ });
    for(i=9; i>=0; i--)
    {
      object *d, p;
      if(d=pri[i]->location_modules)
	foreach(d, p)
	  if(p->find_file)
	    location_module_cache+=({({ p->query_location(), 
					  p->find_file })});
    }
  }
  return location_module_cache;
}

array filter_modules(object id)
{
  if(!filter_module_cache)
  {
    int i;
    filter_module_cache=({ });
    for(i=9; i>=0; i--)
    {
      object *d, p;
      if(d=pri[i]->filter_modules)
	foreach(d, p)
	  if(p->filter)
	    filter_module_cache+=({ p->filter });
    }
  }
  return filter_module_cache;
}


// Some logging stuff, should probably move to either the actual
// configuration object, or into a module. That would be much more
// beautiful, really. 
void init_log_file()
{
  int possfd;
  object lf;

  remove_call_out(init_log_file);

  if(log_function)
  {
    destruct(function_object(log_function)); 
    // Free the old one.
  }
  
  if(query("Log")) // Only try to open the log file if logging is enabled!!
  {
    if(query("LogFile") == "stdout")
    {
      log_function=Stdio.stdout->write;
      possfd=-1;
    } else if(query("LogFile") == "stderr") {
      log_function=Stdio.stderr->write;
    } else {
      if(strlen(query("LogFile")))
      {
	int opened;
	lf=files.file();
	opened=lf->open( query("LogFile"), "wac");
	if(!opened)
	  mkdirhier(query("LogFile"));
	if(!opened && !(lf->open( query("LogFile"), "wac")))	
	{
	  destruct(lf);
	  report_error("Failed to open logfile. ("+query("LogFile")+")\n" +
		       "No logging will take place!\n");
	  log_function=0;
	} else {
	  mark_fd(lf->query_fd(), "Roxen log file ("+query("LogFile")+")");
	  log_function=lf->write;	
	  // Function pointer, speeds everything up (a little..).
	  possfd=lf->query_fd();
	  lf=0;
	}
      } else
	log_function=0;	
    }
    call_out(init_log_file, 60);
  } else
    log_function=0;	
}

// Parse the logging format strings.
private inline string fix_logging(string s)
{
  string pre, post, c;
  sscanf(s, "%*[\t ]", s);
  s = replace(s, ({"\\t", "\\n", "\\r" }), ({"\t", "\n", "\r" }));
  while(s[0] == ' ') s = s[1..10000];
  while(s[0] == '\t') s = s[1..10000];
  while(sscanf(s, "%s$char(%d)%s", pre, c, post)==3)
    s=sprintf("%s%c%s", pre, c, post);
  while(sscanf(s, "%s$wchar(%d)%s", pre, c, post)==3)
    s=sprintf("%s%2c%s", pre, c, post);
  while(sscanf(s, "%s$int(%d)%s", pre, c, post)==3)
    s=sprintf("%s%4c%s", pre, c, post);
  if(!sscanf(s, "%s$^%s", pre, post))
    s+="\n";
  else
    s=pre+post;
  return s;
}

private void parse_log_formats()
{
  string b;
  array foo=query("LogFormat")/"\n";
  foreach(foo, b)
    if(strlen(b) && b[0] != '#' && sizeof(b/":")>1)
      log_format[(b/":")[0]] = fix_logging((b/":")[1..100000]*":");
}



// Really write an entry to the log.
private void write_to_log( string host, string rest, string oh, function fun )
{
  int s;
  if(!host) host=oh;
  if(!stringp(host))
    host = "error:no_host";
  if(fun) fun(replace(rest, "$host", host));
}

// Logging format support functions.
nomask private inline string host_ip_to_int(string s)
{
  int a, b, c, d;
  sscanf(s, "%d.%d.%d.%d", a, b, c, d);
  return sprintf("%c%c%c%c",a, b, c, d);
}

nomask private inline string unsigned_to_bin(int a)
{
  return sprintf("%4c", a);
}

nomask private inline string unsigned_short_to_bin(int a)
{
  return sprintf("%2c", a);
}

nomask private inline string extract_user(string from)
{
  array tmp;
  if (!from || sizeof(tmp = from/":")<2)
    return "-";
  
  return tmp[0];      // username only, no password
}

public void log(mapping file, object request_id)
{
  string a;
  string form;
  function f;

  foreach(logger_modules(request_id), f) // Call all logging functions
    if(f(request_id,file))return;

  if(!log_function) return;// No file is open for logging.


  if(QUERY(NoLog) && _match(request_id->remoteaddr, QUERY(NoLog)))
    return;
  
  if(!(form=log_format[(string)file->error]))
    form = log_format["*"];
  
  if(!form) return;
  
  form=replace(form, 
	       ({ 
		 "$ip_number", "$bin-ip_number", "$cern_date",
		 "$bin-date", "$method", "$resource", "$protocol",
		 "$response", "$bin-response", "$length", "$bin-length",
		 "$referer", "$user_agent", "$user", "$user_id",
	       }), ({
		 (string)request_id->remoteaddr,
		   host_ip_to_int(request_id->remoteaddr),
		   cern_http_date(time(1)),
		   unsigned_to_bin(time(1)),
		   (string)request_id->method,
		   http_encode_string((string)request_id->not_query),
		   (string)request_id->prot,
		   (string)(file->error||200),
		   unsigned_short_to_bin(file->error||200),
		   (string)(file->len>=0?file->len:"?"),
		   unsigned_to_bin(file->len),
		   (string)
		   (sizeof(request_id->referer)?request_id->referer[0]:"-"),
		   http_encode_string(sizeof(request_id->client)?request_id->client*" ":"-"),
		   extract_user(request_id->realauth),
		   (string)request_id->cookies->RoxenUserID,
		 }));
  
  if(search(form, "host") != -1)
    roxen->ip_to_host(request_id->remoteaddr, write_to_log, form,
		      request_id->remoteaddr, log_function);
  else
    log_function(form);
}

// These are here for statistics and debug reasons only.
public string status()
{
  float tmp;
  string res="";

  if(!sent||!received||!hsent)
    return "Fatal error in status(): Bignum object gone.\n";

  tmp = (sent->mb()/(float)(time(1)-roxen->start_time+1));
  res = sprintf("<table><tr align=right><td><b>Sent data:</b></td><td>%.2fMB"
		"</td><td>%.2f Kbit/sec</td>",
		sent->mb(),tmp * 8192.0);
  
  res += sprintf("<td><b>Sent headers:</b></td><td>%.2fMB</td>",
		 hsent->mb());
  
  tmp=(((float)requests*(float)600)/
       (float)((time(1)-roxen->start_time)+1));

  res += ("<tr align=right><td><b>Number of requests:</b></td><td>" 
	  + sprintf("%8d", requests)
	  + sprintf("</td><td>%.2f/min</td><td><b>Recieved data:</b></"
		    "td><td>%.2f</td>", (float)tmp/(float)10,
		    (received->mb())));
  
  return res +"</table>";
}

public string *userinfo(string u, object id)
{
  if(auth_module) return auth_module->userinfo(u);
}

public string *userlist(object id)
{
  if(auth_module) return auth_module->userlist();
}

public string *user_from_uid(int u, object id)
{
  if(auth_module)
    return auth_module->user_from_uid(u);
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
  return (["file":open("roxen-images/dir/"+from+".gif","r"),
	  "type":"image/gif"]);
}

private static int nest = 0;
  
#ifdef MODULE_LEVEL_SECURITY
private mapping misc_cache=([]);

int|mapping check_security(function a, object id, void|int slevel)
{
  array level;
  int need_auth;
  array seclevels;
  
  if(!(seclevels = misc_cache[ a ]))
    misc_cache[ a ] = seclevels = ({
      function_object(a)->query_seclevels(),
      function_object(a)->query("_seclvl")
    });

  if(slevel && (seclevels[1] > slevel)) // "Trustlevel" to low.
    return 1;
  

  if(!sizeof(seclevels[0]))
    return 0; // Ok if there are no patterns.

  catch
  {
    foreach(seclevels[0], level)
      switch(level[0])
      {
       case MOD_ALLOW: // allow ip=...
	if(level[1](id->remoteaddr)) return 0; // Match. It's ok.
	return http_low_answer(403, "<h2>Access forbidden</h2>");
	continue;
	
       case MOD_DENY: // deny ip=...
	if(level[1](id->remoteaddr)) throw("");
	return http_low_answer(403, "<h2>Access forbidden</h2>");
	continue;

       case MOD_USER: // allow user=...
	if(id->auth && id->auth[0] && level[1](id->auth[1])) return 0;
	need_auth = 1;
	continue;
	
       case MOD_PROXY_USER: // allow user=...
	if(id->misc->proxyauth && id->misc->proxyauth[0] && 
	   level[1](id->misc->proxyauth[1])) return 0;
	return http_proxy_auth_required("user");
      }
  };
  // If auth is needed (access might be allowed if you are the right user),
  // request authentification from the user. Otherwise this is a lost case,
  // the user will never be allowed access unless the patterns change.
  return need_auth ? http_auth_failed("user") : 1; 
}
#endif
// Empty all the caches above.
void unvalidate_cache()
{
  last_module_cache = 0;
  filter_module_cache = 0;
  first_module_cache = 0;
  url_module_cache = 0;
  location_module_cache = 0;
  logger_module_cache = 0;
  extension_module_cache      = ([]);
  file_extension_module_cache = ([]);
#ifdef MODULE_LEVEL_SECURITY
  if(misc_cache)
    misc_cache = ([ ]);
#endif
}

// Inspired by the internal-gopher-... thingie, this is the images
// from the configuration interface. :-)
private mapping internal_roxen_image(string from)
{
  sscanf(from, "%s.gif", from);
  sscanf(from, "%s.jpg", from);
  from -= ".";
  // Disallow "internal-roxen-..", it won't really do much harm, but a list of
  // all files in '..' might be retrieved (that is, the actual directory
  // file was sent to the browser)
  // /internal-roxen-../.. was never possible, since that would be remapped to
  // /..
  return (["file":open("roxen-images/"+from+".gif", "r"),"type":"image/gif"]);
}

// The function that actually tries to find the data requested.  All
// modules are mapped, in order, and the first one that returns a
// suitable responce is used.

mapping (mixed:function|int) locks = ([]);

public mapping|int get_file(object id, int|void no_magic);

#ifdef THREADS
object _lock(object|function f)
{
  object key;
  function|int q;				
  if(q=locks[f])
  {
    if(q!=-1)
    {
      perror("lock %O\n", f);
      key=q();
    }
  } else {
    if(objectp(f))
      if(f->thread_safe)
	locks[f]=-1;
      else
	locks[f]=Mutex()->lock;
    else if(function_object(f)->thread_safe)
      locks[f]=-1;
    else
    {
      perror("new lock for %O\n", f);
      locks[f]=Mutex()->lock;
    }
    if((q=locks[f]) && q!=-1)
    {
      perror("lock %O\n", f);
      key=q();
    }
  }
  return key;
}

#define LOCK(X) key=_lock(X)
#define UNLOCK() do{perror("unlock\n");key=0;}while(0)
#else
#define LOCK(X)
#define UNLOCK(X)
#endif

mapping|int low_get_file(object id, int|void no_magic)
{
#ifdef MODULE_LEVEL_SECURITY
  int slevel;
#endif

#ifdef THREADS
  object key;
#endif

  string file=id->not_query;
  string loc;
  function funp;
  mixed tmp, tmp2;
  mapping|object fid;

  if(!no_magic)
  {
#ifndef NO_INTERNAL_HACK 
    // No, this is not beautiful... :) 
    if(sscanf(id->not_query, "%*s/internal-%s", loc))
    {
      if(sscanf(loc, "gopher-%[^/]", loc))    // The directory icons.
	return internal_gopher_image(loc);

      if(sscanf(loc, "spinner-%[^/]", loc)  // Configuration interface images.
	 ||sscanf(loc, "roxen-%[^/]", loc)) // Try /internal-roxen-power
	return internal_roxen_image(loc);
    }
#endif

    if(id->prestate->diract && dir_module)
    {
      LOCK(dir_module);
      tmp = dir_module->parse_directory(id);
      UNLOCK();
      if(mappingp(tmp)) return tmp;
    }
  }

  // Well, this just _might_ be somewhat over-optimized, since it is
  // quite unreadable, but, you cannot win them all.. 

#ifdef URL_MODULES
  // Map URL-modules.
  foreach(url_modules(id), funp)
  {
    LOCK(funp);
    tmp=funp( id, file );
    UNLOCK();
    
    if(tmp && mappingp( tmp ) || objectp( tmp ))
    {
      array err;

      if(tmp->error) 
	return tmp;
      nest ++;
      err = catch {
	if( nest < 20 )
	  tmp = low_get_file( tmp, no_magic );
	else
	  error("Too deep recursion in roxen::get_file() while mapping "
		+file+".\n");
      };
      nest = 0;
      if(err)
	throw(err);
      return tmp;
    }
  }
#endif
#ifdef EXTENSION_MODULES  
  if(tmp=extension_modules(loc=extension(file), id))
  {
    foreach(tmp, funp)
    {
      LOCK(funp);
      tmp=funp(loc, id);
      UNLOCK();
      if(tmp)
      {
	if(!objectp(tmp)) 
	  return tmp;
	fid = tmp;
#ifdef MODULE_LEVEL_SECURITY
	slevel = function_object(funp)->query("_seclvl");
	id->misc->seclevel = slevel;
#endif
	break;
      }
    }
  }
#endif 
 
  foreach(location_modules(id), tmp)
  {
    loc = tmp[0];
    if(!search(file, loc)) 
    {
#ifdef MODULE_LEVEL_SECURITY
      if(tmp2 = check_security(tmp[1], id, slevel))
	if(intp(tmp2))
	{
	  continue;
	} else {
	  return tmp2;
	}
#endif
      LOCK(tmp[1]);
      fid=tmp[1]( file[ strlen(loc) ..] + id->extra_extension, id);
      UNLOCK();
      if(fid)
      {
	id->virtfile = loc;

	if(mappingp(fid))
	  return fid;
	else
	{
#ifdef MODULE_LEVEL_SECURITY
	  slevel = misc_cache[ tmp[1] ][1];// misc_cache from check_security
	  id->misc->seclevel = slevel;
#endif
	  break;
	}
      }
    } else if(strlen(loc)-1==strlen(file)) {
      // This one is here to allow accesses to /local, even if 
      // the mountpoint is /local/. It will slow things down, but...
      if(file+"/" == loc) 
	return http_redirect(id->not_query + "/", id);
    }
  }
  
  if(fid == -1)
  {
    if(no_magic) return -1;
    if(dir_module)
    {
      LOCK(dir_module);
      fid = dir_module->parse_directory(id);
      UNLOCK();
    }
    else
      return 0;
    if(mappingp(fid)) return (mapping)fid;
  }
  
  // Map the file extensions, but only if there is a file...
  if(objectp(fid)&&
     (tmp=file_extension_modules(loc=extension(id->not_query), id)))
    foreach(tmp, funp)
    {
#ifdef MODULE_LEVEL_SECURITY
      if(tmp=check_security(funp, id, slevel))
	if(intp(tmp))
	{
	  continue;
	}
	else
	  return tmp;
#endif
      LOCK(funp);
      tmp=funp(fid, loc, id);
      UNLOCK();
      if(tmp)
      {
	if(!objectp(tmp))
	  return tmp;
	if(fid)
          destruct(fid);
	fid = tmp;
	break;
      }
    }
  
  if(objectp(fid))
  {
    if(stringp(id->extension))
      id->not_query += id->extension;
    
    tmp=type_from_filename(id->not_query, 1);
    
    if(tmp)
      return ([ "file":fid, "type":tmp[0], "encoding":tmp[1] ]);
    
    return ([ "file":fid, ]);
  }
  return fid;
}

mixed get_file(object id, int|void no_magic)
{
  mixed res, res2;
  function tmp;
  res = low_get_file(id, no_magic);
  // finally map all filter type modules.
  // Filter modules are like TYPE_LAST modules, but they get called
  // for _all_ files.
  foreach(filter_modules(id), tmp)
    if(res2=tmp(res,id))
    {
      if(res && res->file && (res2->file != res->file))
	destruct(res->file);
      res=res2;
    }
  return res;
}

public array find_dir(string file, object id)
{
  string loc;
  array dir = ({ }), d, tmp;

  file=replace(file, "//", "/");
  
  foreach(location_modules(id), tmp)
  {
    loc = tmp[0];
    if(file[0] != '/')
      file = "/" + file;
    
    if(!search(file, loc))
    {
//#ifdef MODULE_LEVEL_SECURITY
//      if(check_security(tmp[1], id)) continue;
//#endif
      if(d=function_object(tmp[1])->find_dir(file[strlen(loc)..1000000], id))
	dir |= d;
    } else {
      if(search(loc, file)==0 && loc[strlen(file)-1]=='/' 
	 && (loc[0]==loc[-1]) && loc[-1]=='/')
      {
	loc=loc[strlen(file)..100000];
	sscanf(loc, "%s/", loc);
	dir += ({ loc });
      }
    }
  }
  if(sizeof(dir))
    return dir;
}

// Stat a virtual file. 

public array stat_file(string file, object id)
{
  string loc;
  array s, tmp;
  
  file=replace(file, "//", "/"); // "//" is really "/" here...
    
  // Map location-modules.
  foreach(location_modules(id), tmp)
  {
    loc = tmp[0];
    if((file == loc) || ((file+"/")==loc))
      return ({ 0, -3, 0, 0, 0, 0, 0, 0, 0, 0, 0 });
    if(!search(file, loc)) 
    {
//#ifdef MODULE_LEVEL_SECURITY
//      if(check_security(tmp[1], id)) continue;
//#endif
      if(s=function_object(tmp[1])->stat_file(file[strlen(loc)..], id))
	return s;
    }
  }
}


// Access a virtual file?

public array access(string file, object id)
{
  string loc;
  array s, tmp;
  
  file=replace(file, "//", "/"); // "//" is really "/" here...
    
  // Map location-modules.
  foreach(location_modules(id), tmp)
  {
    loc = tmp[0];
    if((file+"/")==loc)
      return file+="/";
    if(!search(file, loc)) 
    {
#ifdef MODULE_LEVEL_SECURITY
      if(check_security(tmp[1], id)) continue;
#endif
      if(s=function_object(tmp[1])->access(file[strlen(loc)..], id))
	return s;
    }
  }
}

// Return the _real_ filename of a virtual file, if any.

public string real_file(string file, object id)
{
  string loc;
  string s;
  array tmp;
  file=replace(file, "//", "/"); // "//" is really "/" here...
    
  if(!id) error("No id passed to real_file");

  // Map location-modules.
  foreach(location_modules(id), tmp)
  {
    loc = tmp[0];
    if(!search(file, loc)) 
    {
#ifdef MODULE_LEVEL_SECURITY
      if(check_security(tmp[1], id)) continue;
#endif
      if(s=function_object(tmp[1])->real_file(file[strlen(loc)..1000000], id))
	return s;
    }
  }
}

// Convenience functions used in quite a lot of modules. Tries to
// read a file into memory, and then returns the resulting string.

// NOTE: A 'file' can be a cgi script, which will be executed, resulting in
// a horrible delay.

public mixed try_get_file(string s, object id, int|void status, int|void nocache)
{
  string res, q;
  object fake_id;
  mapping m;


  if(objectp(id))
    fake_id = id->clone_me();
  else
    error("No ID passed to 'try_get_file'\n");

  if(!id->pragma["no-cache"] )
    if(res = cache_lookup("file:"+id->conf->name, s))
      return res;

  if(sscanf(s, "%s?%s", s, q))
  {
    string v, name, value;
    foreach(q/"&", v)
      if(sscanf(v, "%s=%s", name, value))
	fake_id->variables[http_decode_string(name)]=value;
    fake_id->query=q;
  }

  fake_id->raw_url=s;
  fake_id->not_query=s;
  fake_id->misc->internal_get=1;

  if(!(m = get_file(fake_id)))
  {
    fake_id->end();
    return 0;
  }
  fake_id->end();
  
  if(status) return 1;
  
#ifdef COMPAT
  if(m["string"])  res = m["string"];	// Compability..
#endif
  else if(m->data) res = m->data;
  else res="";
  m->data = 0;
  
  if(m->file)
  {
    res += m->file->read(200000);
    destruct(m->file);
    m->file = 0;
  }
  
  if(m->raw)
  {
    res -= "\r";
    if(!sscanf(res, "%*s\n\n%s", res))
      sscanf(res, "%*s\n%s", res);
  }
  cache_set("file:"+id->conf->name, s, res);
  return res;
}

// Is 'what' a file in our virtual filesystem?
public int is_file(string what, object id)
{
  return !!stat_file(what, id);
}

mapping (object:array) open_ports = ([]);

void start(int num)
{
  array port, erro;
  int possfd;
  int err=0;
  object lf;
  mapping new=([]), o2;

  parse_log_formats();
  init_log_file();
  map(indices(open_ports), do_dest);

  erro = catch {
    perror("Opening ports for "+query_name()+" ");
    foreach(query("Ports"), port )
    {
      array tmp;
      function rp;
      array old = port;
      object o;
    
      if(rp = ((object)("protocols/"+port[1]))->real_port)
	if(tmp = rp(port))
	  port = tmp;
      object privs;
      if(port[0] < 1024)
	privs = ((program)"privs")("Opening listen port below 1024");
      perror("...  "+port[0]+" "+port[2]+" ("+port[1]+") ");
      if(!(o=create_listen_socket(port[0], this, port[2],
				  (program)("protocols/"+port[1]))))
      {
	perror("I failed to open the port "+old[0]+" at "+old[2]
	       +" ("+old[1]+")\n");
	err++;
      } else
	open_ports[o]=old;
    }
    perror("\n");
  };
  if(erro)
  {
    perror("Error:\n"+describe_backtrace(erro));
  }
  if(!num && sizeof(query("Ports")))
  {
    if(err == sizeof(query("Ports")))
    {
      report_error("No ports available for "+name+"\n"
		    "Tried:\n"
		    "Port  Protocol   IP-Number \n"
		    "---------------------------\n"
		    + map(query("Ports"), lambda(array p) {
		      return sprintf("%5d %-10s %-20s\n", @p);
		    })*"");
    }
  }
}



// Save this configuration. If all is included, save all configuration
// global variables as well, otherwise only all module variables.
void save(int|void all)
{
  mapping mod;
  if(all)
  {
    store("spider.lpc#0", variables, 0, this);
    start(2);
  }
  
  foreach(values(modules), mod)
  {
    if(mod->enabled)
    {
      store(mod->sname+"#0", mod->master->query(), 0, this);
      mod->enabled->start(2, this);
    } else if(mod->copies) {
      int i;
      foreach(indices(mod->copies), i)
      {
	store(mod->sname+"#"+i, mod->copies[i]->query(), 0, this);
	mod->copies[i]->start(2, this);
      }
    }
  }
  unvalidate_cache();
}

// Save all variables in _one_ module.
int save_one( object o )
{
  mapping mod;
  if(!o) 
  {
    store("spider#0", variables, 0, this);
    start(2);
    return 1;
  }
  foreach(values(modules), mod)
  {
    if( mod->enabled == o)
    {
      store(mod->sname+"#0", o->query(), 0, this);
      o->start(2, this);
      unvalidate_cache();
      return 1;
    } else if(mod->copies) {
      int i;
      foreach(indices(mod->copies), i)
      {
	if(mod->copies[i] == o)
	{
	  store(mod->sname+"#"+i, o->query(), 0, this);
	  o->start(2, this);
	  unvalidate_cache();
	  return 1;
	}
      }
    }
  }
}

mapping _hooks=([ ]);


void hooks_for( string modname, object mod )
{
  array hook;
  if(_hooks[modname])
  {
#ifdef MODULE_DEBUG
    perror("Module hooks...");
#endif
    foreach(_hooks[modname], hook)
      hook[0]( @hook[1], mod );
  }
}


int unload_module( string modname );
int load_module( string modname );

object enable_module( string modname )
{
  string id;
  mapping module;
  mapping enabled_modules;

  roxen->current_configuration = this_object();
  modname = replace(modname, ".lpc#","#");
  
  sscanf(modname, "%s#%s", modname, id );

  module = modules[ modname ];
  if(!module)
  {
    load_module(modname);
    module = modules[ modname ];
  }

  if( module )
  {
    object me;
    mapping tmp;
    int pr;

#ifdef MODULE_DEBUG
    perror("Modules: Enabling "+module->name+" # "+id+" ... ");
#endif


    if(module->copies)
    {
      me = module["program"]();
      if(module->copies[id])
      {
	module->copies[id]->stop();
	destruct(module->copies[id]);
      }
    } else {
      if(objectp(module->master))
	me = module->master;
      else
	me = module["program"]();
    }


    if((module->type & MODULE_LOCATION)       ||
       (module->type & MODULE_EXTENSION)      ||
       (module->type & MODULE_FILE_EXTENSION) ||
       (module->type & MODULE_LOGGER)         ||
       (module->type & MODULE_URL)  	      ||
       (module->type & MODULE_LAST)           ||
       (module->type & MODULE_FILTER)         ||
       (module->type & MODULE_PARSER)         ||
       (module->type & MODULE_FIRST))
    {
      me->defvar("_priority", 5, "Priority", TYPE_INT_LIST,
		 "The priority of the module. 9 is highest and 0 is lowest."
		 " Modules with the same priority can be assumed to be "
		 "called in random order", 
		 ({0, 1, 2, 3, 4, 5, 6, 7, 8, 9}));
      
      if(module->type != MODULE_LOGGER)
      {
        if(!(module->type & MODULE_PROXY))
        {
	  me->defvar("_seclvl",  0, "Security: Trust level", TYPE_INT, 
		   "When a location module find a file, that file will get "
		   "a 'Trust level' that equals the level of the module."
		   " This file will then only be sent to modules with a higher "
		   " or equal 'Trust level'. <p>As an example: If the trust "
		   " level of a User filesystem is one, and the CGI module"
		   " have trust level two, the file will never get passed to"
		   " the CGI module. A trust level of zero is the same thing as"
		   " free access.\n");

	  me->defvar("_seclevels", "", "Security: Patterns", TYPE_TEXT_FIELD,
		     "This is the 'security level=value' list.<br>"
		     "Each security level can be any or more from this list:"
		     "<hr noshade>"
		     "allow ip=pattern<br>"
		     "allow user=username,...<br>"
		     "deny ip=pattern<br>"
		     "<hr noshade>"
		     "In patterns: * is on or more characters, ? is one "
		     " character.<p>"
		     "In username: 'any' stands for any valid account "
		     "(from .htaccess"
		     " or auth-module. The default (used when _no_ "
		     "entries are present) is 'allow ip=*', allowing"
		     " everyone to access the module");
	  
	} else {
	  me->definvisvar("_seclvl", -10, TYPE_INT); /* A very low one */
	  
	  me->defvar("_seclevels", "", "Proxy security: Patterns",
		     TYPE_TEXT_FIELD,
		     "This is the 'security level=value' list.<br>"
		     "Each security level can be any or more from "
		     "this list:<br>"
		     "<hr noshade>"
		     "allow ip=pattern<br>"
		     "allow user=username,...<br>"
		     "deny ip=pattern<br>"
		     "<hr noshade>"
		     "In patterns: * is on or more characters, ? is one "
		     " character.<p>"
		     "In username: 'any' stands for any valid account"
		     " (from .htaccess"
		     " or auth-module. The default is 'deny ip=*'");
	}
      }
    } else
      me->defvar("_priority", 0, "", TYPE_INT, "", 0, 1);

    me->defvar("_comment", "", " Comment", TYPE_TEXT_FIELD,
	       "An optional comment. This has no effect on the module, it "
	       "is only a text field for comments that the administrator "
	       "might have (why the module are here, etc.)");

    me->defvar("_name", "", " Module name", TYPE_STRING,
	       "An optional name. Set to something to remaind you what "
	       "the module really does.");

    me->setvars(retrieve(modname + "#" + id, this));
      
    mixed err;
    if(err=catch{if(me->start) me->start(0, this);})
    {
      report_error("Error while initiating module copy of "+module->name+"\n"
		    + describe_backtrace(err));
      destruct(me);
      return 0;
    }
      
    pr = me->query("_priority");

    if((module->type&MODULE_EXTENSION) && arrayp(me->query_extensions()))
    {
      string foo;
      foreach( me->query_extensions(), foo )
	if(pri[pr]->extension_modules[ foo ])
	  pri[pr]->extension_modules[foo] += ({ me });
	else
	  pri[pr]->extension_modules[foo] = ({ me });
    }	  

    if((module->type & MODULE_FILE_EXTENSION) && 
       arrayp(me->query_file_extensions()))
    {
      string foo;
      foreach( me->query_file_extensions(), foo )
	if(pri[pr]->file_extension_modules[foo] ) 
	  pri[pr]->file_extension_modules[foo]+=({me});
	else
	  pri[pr]->file_extension_modules[foo]=({me});
    }

    if(module->type & MODULE_TYPES)
    {
      types_module = me;
      types_fun = me->type_from_extension;
    }


    if((module->type & MODULE_MAIN_PARSER))
    {
      parse_module = me;
      if(_toparse_modules)
	map(_toparse_modules,
	    lambda(object o, object me) 
	    { me->add_parse_module(o); }, me);
    }

    if(module->type & MODULE_PARSER)
    {
      if(parse_module)
	parse_module->add_parse_module( me );
      _toparse_modules += ({ me });
    }

    if(module->type & MODULE_AUTH)
    {
      auth_module = me;
      auth_fun = me->auth;
    }

    if(module->type & MODULE_DIRECTORIES)
      dir_module = me;

    if(module->type & MODULE_LOCATION)
      pri[pr]->location_modules += ({ me });

    if(module->type & MODULE_LOGGER)
      pri[pr]->logger_modules += ({ me });

    if(module->type & MODULE_URL)
      pri[pr]->url_modules += ({ me });

    if(module->type & MODULE_LAST)
      pri[pr]->last_modules += ({ me });

    if(module->type & MODULE_FILTER)
      pri[pr]->filter_modules += ({ me });

    if(module->type & MODULE_FIRST)
      pri[pr]->first_modules += ({ me });

    if(module->copies)
      module->copies[(int)id] = me;
    else
      module->enabled = me;

    hooks_for(module->sname+"#"+id, me);
      

    otomod[ me ] = modname;
    enabled_modules=retrieve("EnabledModules", this);

    if(!enabled_modules[modname+"#"+id])
    {
#ifdef MODULE_DEBUG
      perror("New module...");
#endif
      enabled_modules[modname+"#"+id] = 1;
      store( "EnabledModules",enabled_modules, 1, this);
    }
#ifdef MODULE_DEBUG
    perror(" Done.\n");
#endif 
    unvalidate_cache();
    return me;
  }
  return 0;
}

// Called from the configuration interface.
string check_variable(string name, string value)
{
  switch(name)
  {
   case "MyWorldLocation":
    if(strlen(value)<7 || value[-1] != '/' ||
       !(sscanf(value,"%*s://%*s/")==2))
      return "The URL should follow this format: protocol://computer[:port]/";
  }
}


// This is used to update the server-global and module variables
// between Roxen releases. It enables the poor roxen administrator to
// reuse the configuration file from a previous release. without any
// fuss. Configuration files from Roxen 1.0ß11 pre 11 and earlier
// are not differentiated, but since that release is quite old already
// when I write this, that is not really a problem....


#define perr(X) do { report += X; perror(X); } while(0)

private void update_vars(int from)
{
  string report = "";
  int i;
  string modname;
  mapping redir;
  mapping enabled_modules = retrieve("EnabledModules");
  array p, res=({});

  perr("Updating configuration file....\n");
  perr("----------------------------------------------------\n");
  switch(from)
  {
  case 0:

   // Pre b11p11 
   // Ports changed from int, int, int ... to
   // ({ int, "http", query("PEther") })
   //
    
    if(sizeof(retrieve("spider#0")))
    {
      p = query("Ports");
      foreach(p, p)
	if(intp(p))
	  res += ({ ({ p, "http", query("PEther") }) });

      perr("Updating ports variable.\n");
      set("PEther", 0);
      set("Ports", res);
    } else {
      perr("Ports variable already fixed.\n");
    }

    // Now comes the tricky part..
    // Fix all thoose redirection modules.
    res = ({});
    while(sizeof(redir = retrieve(modname = "redirect#"+i++)))
    {
      string from, to;
      if(redir->fileredirect)
      {
	res += ({ "\n\n" +redir->fileredirect });
	remove( modname, this );
	if(enabled_modules[modname] )
	  m_delete( enabled_modules, modname );
	continue;
      }
      // from -> to
      remove( modname, this );
      if(enabled_modules[modname] )
	m_delete( enabled_modules, modname );
      from = redir->from;
      to = redir->redirect;
      if(redir->internal)
	res += ({ from + "	" + to });
      else
	res += ({ from + "	" + "%u" + to });
      perr("Fixing redirect from " + from + " to "+to+"\n");
    }

    if(sizeof(res)) // Hepp hopp
    {
      enabled_modules["redirect#0"] = 1;
      store("redirect#0",
	    ([
	      "fileredirect":"# Automatically converted patterns...\n\n" 
	                     + res*"\n"
	      ]), 1);
    }    
    
    // And now the etc/extentions bug...
    redir = retrieve("contenttypes#0");

    if(!sizeof(redir))
      enabled_modules["contenttypes#0"] = 1;
    else
    {
      redir->exts = replace(redir->exts, "etc/extentions", "etc/extensions");
      store("contenttypes#0", redir, 1);
      perr("Fixing spelling error in contenttypes configuration.\n");
    }
    
    // Is there a directory parser in there somewhere?

    perror("Making a list of all wanted index files...\n");
    
    i=0;
    res=({ });
    while(sizeof(redir = retrieve(modname = "userfs#"+i++)))
    {
      if(redir->indexfiles)
      {
	res |= redir->indexfiles;
	redir[".files"] = !redir[".files"];
	store("userfs#"+(i-1), redir, 1);
#ifdef SUPPORT_HTACCESS
	if(redir[".htaccess"])
	{
	  if(!query("htaccess"))
	  {
	    perr("A filesystem used .htaccess parsing.\n"
		 "This variable is now server global.\n"
		 "This variable has now been set to 'Yes'\n");
	    set("htaccess", 1);
	  }
	}
#endif
      }
    }
    i=0;
    while(sizeof(redir = retrieve(modname = "secure_fs#"+i++)))
    {
      if(redir->indexfiles)
      {
	res |= redir->indexfiles;
	redir[".files"] = !redir[".files"];
	store("secure_fs#"+(i-1), redir, 1);
#ifdef SUPPORT_HTACCESS
	if(redir[".htaccess"])
	{
	  if(!query("htaccess"))
	  {
	    perr("A secure filesystem used .htaccess parsing.\n"
		 "This variable is now server global.\n"
		 "This variable has now been set to 'Yes'\n");
	    set("htaccess", 1);
	  }
	}
#endif
      }
    }
    i=0;
    while(sizeof(redir = retrieve(modname = "filesystem#"+i++)))
    {
      if(redir->indexfiles)
      {
	res |= redir->indexfiles;
	redir[".files"] = !redir[".files"];
	store("filesystem#"+(i-1), redir, 1);
#ifdef SUPPORT_HTACCESS
	if(redir[".htaccess"])
	{
	  if(!query("htaccess"))
	  {
	    perr("A user filesystem used .htaccess parsing.\n"
		 "This variable is now server global.\n"
		 "It has been set to 'Yes'\n");
	    set("htaccess", 1);
	  }
	}
#endif
      }
    }
    perr("-> "+res*","+"\n");
    
    for(i=0; i<10; i++)
    {
      remove("status#"+i, this);
      m_delete(enabled_modules, "status#"+i);
    }
    
    if(!sizeof(retrieve("directories#0"))
       && (sizeof(redir = retrieve("fastdir#0"))))
    {
      redir->indexfiles = res;
      store("fastdir#0", redir, 1);
      perr("Updated fast directory parser to include new list.\n");
    } else {
      if(!(sizeof(redir = retrieve("directories#0"))))
      {
	enabled_modules["directories#0"] = 1;
	perr("Enabled a directory parsing module.\n");
	redir = ([ ]);
      }
      redir->indexfiles = res;
      store("directories#0", redir, 1);
      perr("Updated directory parser to include new list.\n");
    }
    perr("Saving new module list.\n");
    store( "EnabledModules", enabled_modules, 1 );

  case 1:
  case 2:
   perr("The 'No directory lists' variable is yet again available.\n");
  case 3:
   // The htaccess support moved to a module. 
   if(query(".htaccess"))
   {
     perr("The 'HTACCESS' support has been moved to a module.\n");
     enable_module("htaccess#0");
   }
   case 4:
   case 5:
    
    while(sizeof(redir = retrieve(modname = "lpcscript#"+i)))
    {
      remove( modname, this );
      if(search(redir->exts, "pike") == -1)
	redir->exts += ({"pike"});
      if(enabled_modules[modname] )
	m_delete( enabled_modules, modname );
      store("pikescript#"+i, redir, 1);
      enable_module("pikescript#"+i);
      perr("Renaming "+modname+" to pikescript#"+i+"\n");
      i++;
    }
    store( "EnabledModules", enabled_modules, 1 );
    
   case 6:// Current level. 
  }

  perr("----------------------------------------------------\n");
  report_debug(report);
}




// Used to hide some variables when logging is not enabled.

int log_is_not_enabled()
{
  return !query("Log");
}


private string get_domain(int|void l)
{
  array f;
  string t, s;

//  ConfigurationURL is set by the 'install' script.
  if(!(!l && sscanf(roxen->QUERY(ConfigurationURL), "http://%s:%*s", s)))
  {
#if efun(gethostbynme) && efun(gethostname)
    f = gethostbyname(gethostname()); // First try..
    if(f)
      foreach(f, f) foreach(f, t) if(search(t, ".") != -1 && !(int)t)
	if(!s || strlen(s) < strlen(t))
	  s=t;
#endif
    if(!s)
    {
      t = Stdio.read_bytes("/etc/resolv.conf");
      if(t) 
      {
	if(!sscanf(t, "domain %s\n", s))
	  if(!sscanf(t, "search %s%*[ \t\n]", s))
	    s="nowhere";
      } else {
	s="nowhere";
      }
      s = "host."+s;
    }
  }
  sscanf(s, "%*s.%s", s);
  if(s && strlen(s))
  {
    if(s[-1] == '.') s=s[..strlen(s)-2];
    if(s[0] == '.') s=s[1..];
  } else {
    s="unknown"; 
  }
  return s;
}

// Get the current domain. This is not as easy as one could think.

int disable_module( string modname )
{
  mapping module;
  mapping enabled_modules;
  object me;
  int pr;
  int id;

  sscanf(modname, "%s#%d", modname, id );

  module = modules[ modname ];

  if(!module) 
  {
    report_error("Modules: Failed to disable module\n"
		 "Modules: No module by that name: \""+modname+"\".\n");
    return 0;
  }

  if(module->copies)
  {
    me = module->copies[id];
    m_delete(module->copies, id);
    if(!sizeof(module->copies))
      unload_module(modname);
  } else {
    me = module->enabled || module->master;
    module->enabled=module->master = 0;
    unload_module(modname);
  }

  unvalidate_cache();

  if(!me)
  {
    report_error("Modules: Failed to Disable "+module->name+" # "+id+"\n");
    return 0;
  }

  if(me->stop) me->stop();

#ifdef MODULE_DEBUG
  perror("Modules: Disabling "+module->name+" # "+id+"\n");
#endif

  if(module["type"] & MODULE_EXTENSION 
     && arrayp( me -> query_extensions()))
  {
    string foo;
    foreach( me -> query_extensions(), foo )
      for(pr=0; pr<10; pr++)
	if( pri[pr]->extension_modules[ foo ] ) 
	  pri[pr]->extension_modules[ foo ]-= ({ me });
  }

  if(module["type"] & MODULE_FILE_EXTENSION 
     && arrayp( me -> query_file_extensions()))
  {
    string foo;
    foreach( me -> query_file_extensions(), foo )
      for(pr=0; pr<10; pr++)
	if(pri[pr]->file_extension_modules[ foo ] ) 
	  pri[pr]->file_extension_modules[foo]-=({me});
  }

  if(module["type"] & MODULE_TYPES)
  {
    types_module = 0;
    types_fun = 0;
  }

  if(module->type & MODULE_MAIN_PARSER)
    parse_module = 0;

  if(module->type & MODULE_PARSER)
  {
    if(parse_module)
      parse_module->remove_parse_module( me );
    _toparse_modules -= ({ me, 0 });
  }

  if( module->type & MODULE_AUTH )
  {
    auth_module = 0;
    auth_fun = 0;
  }

  if( module->type & MODULE_DIRECTORIES )
    dir_module = 0;


  if( module->type & MODULE_LOCATION )
    for(pr=0; pr<10; pr++)
     pri[pr]->location_modules -= ({ me });

  if( module->type & MODULE_URL )
    for(pr=0; pr<10; pr++)
      pri[pr]->url_modules -= ({ me });

  if( module->type & MODULE_LAST )
    for(pr=0; pr<10; pr++)
      pri[pr]->last_modules -= ({ me });

  if( module->type & MODULE_FILTER )
    for(pr=0; pr<10; pr++)
      pri[pr]->filter_modules -= ({ me });

  if( module->type & MODULE_FIRST )
    for(pr=0; pr<10; pr++)
      pri[pr]->first_modules -= ({ me });

  if( module->type & MODULE_LOGGER )
    for(pr=0; pr<10; pr++)
      pri[pr]->logger_modules -= ({ me });

  enabled_modules=retrieve("EnabledModules", this);

  if(enabled_modules[modname+"#"+id])
  {
    m_delete( enabled_modules, modname + "#" + id );
    store( "EnabledModules",enabled_modules, 1, this);
  }
  destruct(me);
  return 1;
}

object|string find_module(string name)
{
  int id;
  mapping modules;
  modules = modules;
  sscanf(name, "%s#%d", name, id);
  if(modules[name])
  {
    if(modules[name]->copies)
      return modules[name]->copies[id];
    else 
      if(modules[name]->enabled)
	return modules[name]->enabled;
  }
  return 0;
}

void register_module_load_hook( string modname, function fun, mixed ... args )
{
  object o;
#ifdef MODULE_DEBUG
  perror("Registering a hook for the module "+modname+"\n");
#endif
  if(o=find_module(modname))
  {
#ifdef MODULE_DEBUG
    perror("Already there!\n");
#endif
    fun( @args, o );
  } else
    if(!_hooks[modname])
      _hooks[modname] = ({ ({ fun, args }) });
    else
      _hooks[modname] += ({ ({ fun, args }) });
}


int load_module(string module_file)
{
  int foo, disablep;
  mixed err;
  mixed *module_data;
  mapping loaded_modules;
  object obj;
  program prog;

  roxen->current_configuration = this_object();
#ifdef MODULE_DEBUG
  perror("Modules: Loading "+module_file+"... ");
#endif

  if(prog=cache_lookup("modules", module_file))
    obj=prog();
  else
  {
    string dir;

//   _master->set_inhibit_compile_errors("");

    err = catch { obj = roxen->load_from_dirs(roxen->QUERY(ModuleDirs), module_file); };

    if( err && obj ) {
      obj=0;
      report_error("Error while enabling module ("+module_file+"):\n"+
		   describe_backtrace(err)+"\n");
    }

//    _master->set_inhibit_compile_errors(0);

    prog = roxen->last_loaded();
  }


  if(!obj)
  {
#ifdef MODULE_DEBUG
    perror("FAILED (the module was not found)\n");
#endif
    report_error( "Module load failed ("+module_file+") (not found).\n" );
    return 0;
  }

  err = catch (module_data = obj->register_module());

  if (err)
  {
#ifdef MODULE_DEBUG
    perror("FAILED\n" + describe_backtrace( err ));
#endif
    report_error( "Module loaded, but register_module() failed (" 
		 + module_file + ").\n"  +
		  describe_backtrace( err ));
    return 0;
  }

  err = "";
      
  if (!arrayp( module_data ))
    err = "Register_module didn't return an array.\n";
  else
    switch (sizeof( module_data ))
    {
     case 5:
      foo=1;
      module_data=module_data[0..3];
     case 4:
      if (module_data[3] && !arrayp( module_data[3] ))
	err = "The fourth element of the array register_module returned "
	  + "(extra_buttons) wasn't an array.\n" + err;
     case 3:
      if (!stringp( module_data[2] ))
	err = "The third element of the array register_module returned "
	  + "(documentation) wasn't a string.\n" + err;
      if (!stringp( module_data[1] ))
	err = "The second element of the array register_module returned "
	  + "(name) wasn't a string.\n" + err;
      if (!intp( module_data[0] ))
	err = "The first element of the array register_module returned "
	  + "(type) wasn't an integer.\n" + err;
      break;

     default:
      err = ("The array register_module returned was too small/large. "
	     + "It should have been three or four elements (type, name, "
	     + "documentation and extra buttons (optional))\n");
    }
  if (err != "")
  {
#ifdef MODULE_DEBUG
    perror("FAILED\n"+err);
#endif
    report_error( "Tried to load module " + module_file + ", but:\n" + err );
    if(obj)
      destruct( obj );
    return 0;
  } 
    
  if (sizeof(module_data) == 3)
    module_data += ({ 0 }); 

  if(!foo)
  {
    destruct(obj);
    obj=0;
  } else {
    otomod[obj] = module_file;
  }

  if(!modules[ module_file ])
    modules[ module_file ] = ([]);
  mapping tmpp = modules[ module_file ];

  tmpp->type=module_data[0];
  tmpp->name=module_data[1];
  tmpp->doc=module_data[2];
  tmpp->extra=module_data[3];
  tmpp["program"]=prog;
  tmpp->master=obj;
  tmpp->copies=(foo ? 0 : (tmpp->copies||([])));
  tmpp->sname=module_file;
      
#ifdef MODULE_DEBUG
  perror(" Done ("+search(_master->programs,prog)+").\n");
#endif
  cache_set("modules", module_file, modules[module_file]["program"]);
// ??  unvalidate_cache();

  return 1;
}

int unload_module(string module_file)
{
  mapping module;
  int id;

  module = modules[ module_file ];

  if(!module) 
    return 0;

  if(objectp(module->master)) 
    destruct(module->master);

  cache_remove("modules", module_file);
  
  m_delete(modules, module_file);

  return 1;
}

int port_open(array prt)
{
  array v;
  foreach(values(open_ports), v)
    if(equal(v, prt)) return 1;
  return 0;
}


string desc()
{
  string res="";
  array (string|int) port;
  
  foreach(QUERY(Ports), port)
  {
    string prt;
    
    switch(port[1][0..2])
    {
    case "ssl":
      prt = "https://";
      break;
      
    default:
      prt = port[1]+"://";
    }
    if(port[2] && port[2]!="ANY")
      prt += port[2];
    else
      prt += (gethostname()/".")[0] + "." + QUERY(Domain);
 prt += ":"+port[0]+"/";
    if(port_open( port ))
      res += "<a target=server_view href='"+prt+"'>"+prt+"</a>\n<br>";
    else
      res += "<font color=red><b>Not open:</b> <a target=server_view href='"+prt+"'>"+prt+"</a></font><br>\n";
  }
  return res+"<p>";
}





// This is the most likely URL for a virtual server. Again, this
// should move into the actual 'configuration' object. It is not all
// that nice to have all this code lying around in here.

private string get_my_url()
{
  string s;
  s = (gethostname()/".")[0] + "." + query("Domain");
  s -= "\n";
  return "http://" + s + "/";
}

void create(string config)
{
  array modules_to_process;
  string tmp_string;

  roxen->current_configuration = this;
  name=config;

  perror("Enabling virtual server '"+config+"'\n");
  
  definvisvar("htaccess", 0, TYPE_FLAG);

  defvar("ZNoSuchFile", "<title>Sorry. I cannot find this resource</title>"
	 "\n<h2 align=center><configimage src=roxen.gif alt=\"File not found\">\n"
	 "<p><hr noshade>"
	 "\n<i>Sorry</i></h2>\n"
	 "<br clear>\n<font size=+2>The resource requested "
	 "<i>$File</i>\ncannot be found.<p>\n\nIf you feel that this is a "
	 "configuration error, please contact "
	 "the administrators or the author of the <if referer>"
	 "<a href=<referer>>referring</a> </if> <else>referring</else> page."
	 "<p>\n</font>\n"
	 "<hr noshade>"
	 "<version>, at <a href=$Me>$Me</a>.\n", 

	 "Messages: No such file", TYPE_TEXT_FIELD,
	 "What to return when there is no resource or file available "
	 "at a certain location. $File will be replaced with the name "
	 "of the resource requested, and $Me with the URL of this server ");


  defvar("comment", "", "Configuration interface comment",
	 TYPE_TEXT_FIELD,
	 "This text will be visible in the configuration interface, it "
	 " can be quite useful to use as a memory helper.");
  
  defvar("name", "", "Configuration interface name",
	 TYPE_STRING,
	 "This is the name that will be used in the configuration "
	 "interface. If this is left empty, the actual name of the "
	 "virtual server will be used");
  
  defvar("LogFormat", 
 "404: $host $referer - [$cern_date] \"$method $resource $protocol\" 404 -\n"
 "500: $host ERROR - [$cern_date] \"$method $resource $protocol\" 500 -\n"
 "*: $host - - [$cern_date] \"$method $resource $protocol\" $response $length"
	 ,

	 "Logging: Format", 
	 TYPE_TEXT_FIELD,
	 
	 "What format to use for logging. The syntax is:\n"
	 "<pre>"
	 "response-code or *: Log format for that response acode\n\n"
	 "Log format is normal characters, or one or more of the "
	 "variables below:\n"
	 "\n"
	 "\\n \\t \\r       -- As in C, newline, tab and linefeed\n"
	 "$char(int)     -- Insert the (1 byte) character specified by the integer.\n"
	 "$wchar(int)    -- Insert the (2 byte) word specified by the integer.\n"
	 "$int(int)      -- Insert the (4 byte) word specified by the integer.\n"
	 "$^             -- Supress newline at the end of the logentry\n"
	 "$host          -- The remote host name, or ip number.\n"
	 "$ip_number     -- The remote ip number.\n"
	 "$bin-ip_number -- The remote host id as a binary integer number.\n"
	 "\n"
	 "$cern_date     -- Cern Common Log file format date.\n"
       "$bin-date      -- Time, but as an 32 bit iteger in network byteorder\n"
	 "\n"
	 "$method        -- Request method\n"
	 "$resource      -- Resource identifier\n"
	 "$protocol      -- The protocol used (normally HTTP/1.0)\n"
	 "$response      -- The response code sent\n"
	 "$bin-response  -- The response code sent as a binary short number\n"
	 "$length        -- The length of the data section of the reply\n"
       "$bin-length    -- Same, but as an 32 bit iteger in network byteorder\n"
	 "$referer       -- the header 'referer' from the request, or '-'.\n"
      "$user_agent    -- the header 'User-Agent' from the request, or '-'.\n\n"
	 "$user          -- the name of the auth user used, if any\n"
	 "$user_id       -- A unique user ID, if cookies are supported,\n"
	 "                  by the client, otherwise '0'\n"
	 "</pre>", 0, log_is_not_enabled);
  
  defvar("Log", 1, "Logging: Enabled", TYPE_FLAG, "Log requests");
  
  defvar("LogFile", roxen->QUERY(logdirprefix)+
	 short_name(name)+"/Log", 

	 "Logging: Log file", TYPE_FILE, "The log file. "
	 "stdout for standard output, or stderr for standard error, or "+
	 "a file name. May be relative to "+getcwd()+".",0, log_is_not_enabled);
  
  defvar("NoLog", ({ }), 
	 "Logging: No Logging for", TYPE_STRING_LIST,
         "Don't log requests from hosts with an IP number which matches any "
	 "of the patterns in this list. This also affects the access counter "
	 "log.\n",0, log_is_not_enabled);
  
  defvar("Domain", get_domain(), 

	 "Domain", TYPE_STRING, 
	 "Your domainname, should be set automatically, if not, "
	 "enter the real domain name here, and send a bug report to "
	 "<a href=mailto:roxen-bugs@infovav.se>roxen-bugs@infovav.se"
	 "</a>");
  

    defvar("Ports", ({ }), 
	 "Listen ports", TYPE_PORTS,
         "The ports this virtual instance of Roxen will bind to.\n");

  defvar("MyWorldLocation", get_my_url(), 
	 "Server URL", TYPE_STRING,
	 "This is where your start page is located.");


// This should be somewhere else, I think. Same goes for HTTP related ones

  defvar("FTPWelcome",  
	 "              +-------------------------------------------------\n"
	 "              +-- Welcome to the Roxen Challenger FTP server ---\n"
	 "              +-------------------------------------------------\n",
	 "Messages: FTP Welcome",
	 TYPE_TEXT_FIELD,
	 "FTP Welcome answer; transmitted to new FTP connections if the file "
	 "<i>/welcome.msg</i> doesn't exist.\n");
  

  defvar("_v", CONFIGURATION_FILE_LEVEL, 0, TYPE_INT, 0, 0, 1);
  setvars(retrieve("spider#0", this));
  
  if((sizeof(retrieve("spider#0", this)) && 
      (!retrieve("spider#0",this)->_v) 
      || (query("_v") < CONFIGURATION_FILE_LEVEL)))
  {
    update_vars(retrieve("spider#0",this)->_v?query("_v"):0);
    killvar("PEther"); // From Spinner 1.0b11
    variables->_v[VAR_VALUE] = CONFIGURATION_FILE_LEVEL;
    store("spider#0", variables, 0);
  }
    
  set("_v", CONFIGURATION_FILE_LEVEL);
  
  modules_to_process = sort_array(indices(retrieve("EnabledModules",this)));

  // Always enable the user database module first.
  if(search(modules_to_process, "userdb#0")>-1)
    modules_to_process = (({"userdb#0"})+(modules_to_process-({"userdb#0"})));


  array err;
  foreach( modules_to_process, tmp_string )
    if(err = catch( enable_module( tmp_string ) ))
      report_error("Failed to enable the module "+tmp_string+". Skipping\n"
#ifdef MODULE_DEBUG
                    +describe_backtrace(err)+"\n"
#endif
	);
  roxen->current_configuration = 0;
}



