/*
 * A vitual server's main configuration 
 * (C) 1996, 1999 Idonex AB.
 */

constant cvs_version = "$Id: configuration.pike,v 1.246 1999/12/28 00:00:17 mast Exp $";
constant is_configuration = 1;
#include <module.h>
#include <roxen.h>
#include <request_trace.h>

mapping enabled_modules = ([]);
mapping(string:array(int)) error_log=([]);

#ifdef PROFILE
mapping profile_map = ([]);
#endif

#define CATCH(P,X) do{mixed e;if(e=catch{X;})report_error("While "+P+"\n"+describe_backtrace(e));}while(0)

// Locale support...
#define LOCALE	LOW_LOCALE->base_server

#ifdef THROTTLING_DEBUG
#undef THROTTLING_DEBUG
#define THROTTLING_DEBUG(X) perror("Throttling: "+X+"\n")
#else
#define THROTTLING_DEBUG(X)
#endif

/* A configuration.. */

#include "rxml.pike";

object      throttler;
function    store = roxen->store;
function    retrieve = roxen->retrieve;
function    remove = roxen->remove;
RoxenModule types_module;
RoxenModule auth_module;
RoxenModule dir_module;
function    types_fun;
function    auth_fun;

string name;

mapping variables = ([]); 


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
      return module->variables[variable][VAR_NAME]+
        "\n"+module->variables[ variable ][ VAR_DOC_STR ];
  }
  if(variables[ variable ])
    return variables[variable][VAR_NAME]+
      "\n"+variables[ variable ][ VAR_DOC_STR ];
}

public mixed query(string var)
{
  if(var && variables[var])
    return variables[var][ VAR_VALUE ];
  if(!var) return variables;
  error("query("+var+"): Unknown variable.\n");
}

mixed set(string var, mixed val)
{
  if(variables[var])
    return variables[var][VAR_VALUE] = val;
  error("set("+var+"). Unknown variable.\n");
}

int setvars( mapping (string:mixed) vars )
{
  string v;
  foreach( indices( vars ), v )
    if(variables[v])
      variables[v][ VAR_VALUE ] = vars[ v ];
  return 1;
}

void killvar(string name)
{
  m_delete(variables, name);
}

constant ConfigurableWrapper = roxen.ConfigurableWrapper;

int defvar(string var, mixed value, string name, int type,
	   string|void doc_str, mixed|void misc,
	   int|function|void not_in_config)
{
  variables[var]                     = allocate( VAR_SIZE );
  variables[var][ VAR_VALUE ]        = value;
  variables[var][ VAR_TYPE ]         = type & VAR_TYPE_MASK;
  variables[var][ VAR_DOC_STR ]      = doc_str;
  variables[var][ VAR_NAME ]         = name;
  variables[var][ VAR_MISC ]         = misc;
  
  Locale.Roxen.standard
    ->register_module_doc( this_object(), var, name, doc_str );

  type &= (VAR_EXPERT | VAR_MORE);
  if (functionp(not_in_config))
    if (type)
      variables[var][ VAR_CONFIGURABLE ] = ConfigurableWrapper(type, not_in_config)->check;
    else
      variables[var][ VAR_CONFIGURABLE ] = not_in_config;
  else if (type) 
    variables[var][ VAR_CONFIGURABLE ] = type;
  else if(intp(not_in_config))
    variables[var][ VAR_CONFIGURABLE ] = !not_in_config;
  variables[var][ VAR_SHORTNAME ] = var;
}

void deflocaledoc( string locale, string variable, 
		   string name, string doc, mapping|void translate )
{
  if( !Locale.Roxen[locale] )
    report_warning("Invalid locale: "+locale+". Ignoring.\n");
  else
    Locale.Roxen[locale]
      ->register_module_doc( this_object(), variable, name, doc, translate );
}

int definvisvar(string var, mixed value, int type)
{
  return defvar(var, value, "", type, "", 0, 1);
}

string query_internal_location(RoxenModule|void mod)
{
  return QUERY(InternalLoc)+(mod?replace(otomod[mod]||"", "#", "!")+"/":"");
}

string query_name()
{
  if(strlen(QUERY(name))) 
    return QUERY(name);
  return name;
}

string comment()
{
  return QUERY(comment);
}

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

  void stop()
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
  }
}



/* A 'pri' is one of the ten priority objects. Each one holds a list
 * of modules for that priority. They are all merged into one list for
 * performance reasons later on.
 */

array (Priority) allocate_pris()
{
  return allocate(10, Priority)();
}

/* For debug and statistics info only */
int requests;
// Protocol specific statistics.
mapping(string:mixed) extra_statistics = ([]);
mapping(string:mixed) misc = ([]);	// Even more statistics.

int sent;     // Sent data
int hsent;    // Sent headers
int received; // Received data

// Will write a line to the log-file. This will probably be replaced
// entirely by log-modules in the future, since this would be much
// cleaner.

function(string:int) log_function;

// The logging format used. This will probably move the the above
// mentioned module in the future.
private mapping (string:string) log_format = ([]);

// A list of priority objects
private array (Priority) pri = allocate_pris();

// All enabled modules in this virtual server.
// The format is "module":{ "copies":([ num:instance, ... ]) }
public mapping modules = ([]);

// A mapping from objects to module names
public mapping (RoxenModule:string) otomod = ([]);


// Caches to speed up the handling of the module search.
// They are all sorted in priority order, and created by the functions
// below.
private array (function) url_module_cache, last_module_cache;
private array (function) logger_module_cache, first_module_cache;
private array (function) filter_module_cache;
private array (array (string|function)) location_module_cache;
private mapping (string:array (function)) file_extension_module_cache=([]);
private mapping (string:array (RoxenModule)) provider_module_cache=([]);


// Call stop in all modules.
void stop()
{
  CATCH("stopping type modules",
        types_module && types_module->stop && types_module->stop());
  CATCH("stopping auth module",
        auth_module && auth_module->stop && auth_module->stop());
  CATCH("stopping directory module",
        dir_module && dir_module->stop && dir_module->stop());
  for(int i=0; i<10; i++) 
    CATCH("stopping priority group",
          (pri[i],pri[i]->stop,pri[i]->stop()));
}

public string type_from_filename( string file, int|void to, string|void myext )
{
  mixed tmp;
  if(!types_fun)
    return to?({ "application/octet-stream", 0 }):"application/octet-stream";

  string ext=myext || extension(file);

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
      else if(tmp2=types_fun("default"))
	tmp[0] = tmp2[0];
      else
	tmp[0]="application/octet-stream";
    }
  } else if(!(tmp = types_fun("default"))) {
    tmp = ({ "application/octet-stream", 0 });
  }
  return to?tmp:tmp[0];
}

// Return an array with all provider modules that provides "provides".
array (RoxenModule) get_providers(string provides)
{
  // FIXME: Is there any way to clear this cache?
  // /grubba 1998-05-28
  // - Yes, it is zapped together with the rest in invalidate_cache().
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

// Return the first provider module that provides "provides".
RoxenModule get_provider(string provides)
{
  array (RoxenModule) prov = get_providers(provides);
  if(sizeof(prov))
    return prov[0];
  return 0;
}

// map the function "fun" over all matching provider modules.
array(mixed) map_providers(string provides, string fun, mixed ... args)
{
  array (RoxenModule) prov = get_providers(provides);
  array error;
  array a=({ });
  mixed m;
  foreach(prov, RoxenModule mod) 
  {
    if(!objectp(mod))
      continue;
    if(functionp(mod[fun])) 
      error = catch(m=mod[fun](@args));
    if(arrayp(error)) {
      error[0] = "Error in map_providers(): "+error[0];
      roxen_perror(describe_backtrace(error));
    }
    else
      a += ({ m });
    error = 0;
  }
  return a;
}

// map the function "fun" over all matching provider modules and
// return the first positive response.
mixed call_provider(string provides, string fun, mixed ... args)
{
  foreach(get_providers(provides), RoxenModule mod) 
  {
    function f;
    if(objectp(mod) && functionp(f = mod[fun])) {
      mixed error;
      if (arrayp(error = catch {
	mixed ret;
	if (ret = f(@args)) {
	  return ret;
	}
      })) {
	error[0] = "Error in call_provider(): "+error[0];
	throw(error);
      }
    }
  }
}

array (function) file_extension_modules(string ext, RequestID id)
{
  if(!file_extension_module_cache[ext])
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

array (function) url_modules(RequestID id)
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

mapping api_module_cache = ([]);
mapping api_functions(void|RequestID id)
{
  return copy_value(api_module_cache);
}

array (function) logger_modules(RequestID id)
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

array (function) last_modules(RequestID id)
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
  id->not_query = a[0];
  id->misc->fork_information = a[1..];
  return 0;
}
#endif /* __NT__ */

array (function) first_modules(RequestID id)
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


array location_modules(RequestID id)
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
	sort(level_locations, level_find_files);
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

array filter_modules(RequestID id)
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
  remove_call_out(init_log_file);

  if(log_function)
    destruct(function_object(log_function)); 
    // Free the old one.
  
  if(query("Log")) // Only try to open the log file if logging is enabled!!
  {
    mapping m = localtime(time());
    string logfile = query("LogFile");
    m->year += 1900;	/* Adjust for years being counted since 1900 */
    m->mon++;		/* Adjust for months being counted 0-11 */
    if(m->mon < 10) m->mon = "0"+m->mon;
    if(m->mday < 10) m->mday = "0"+m->mday;
    if(m->hour < 10) m->hour = "0"+m->hour;
    logfile = replace(logfile,({"%d","%m","%y","%h" }),
		      ({ (string)m->mday, (string)(m->mon),
			 (string)(m->year),(string)m->hour,}));
    if(strlen(logfile))
    {
      do {
	Stdio.File lf=open( logfile, "wac");
	if(!lf) {
	  mkdirhier(logfile);
	  if(!(lf=open( logfile, "wac"))) {
	    report_error(LOCALE->failed_to_open_logfile(logfile));
	    log_function=0;
	    break;
	  }
	}
	log_function=lf->write;	
	// Function pointer, speeds everything up (a little..).
	lf=0;
      } while(0);
    } else
      log_function=0;	
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

  // FIXME: This looks like a bug.
  // Is it supposed to strip all initial whitespace, or do what it does?
  //	/grubba 1997-10-03
  while(s[0] == ' ') s = s[1..];
  while(s[0] == '\t') s = s[1..];
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
      log_format[(b/":")[0]] = fix_logging((b/":")[1..]*":");
}



// Really write an entry to the log.
private void write_to_log( string host, string rest, string oh, function fun )
{
  int s;
  if(!host) host=oh;
  if(!stringp(host))
    host = "error:no_host";
  else
    host = (host/" ")[0];	// In case it's an IP we don't want the port.
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

public void log(mapping file, RequestID request_id)
{
//    _debug(2);
  string a;
  string form;
  function f;

  foreach(logger_modules(request_id), f) // Call all logging functions
    if(f(request_id,file))return;

  if(!log_function || !request_id) return;// No file is open for logging.


  if(QUERY(NoLog) && _match(request_id->remoteaddr, QUERY(NoLog)))
    return;
  
  if(!(form=log_format[(string)file->error]))
    form = log_format["*"];
  
  if(!form) return;
  
  form=replace(form, 
	       ({ 
		 "$ip_number", "$bin-ip_number", "$cern_date",
		 "$bin-date", "$method", "$resource", "$full_resource", "$protocol",
		 "$response", "$bin-response", "$length", "$bin-length",
		 "$referer", "$user_agent", "$user", "$user_id",
		 "$request-time"
	       }), 
               ({
		 (string)request_id->remoteaddr,
		 host_ip_to_int(request_id->remoteaddr),
		 cern_http_date(time(1)),
		 unsigned_to_bin(time(1)),
		 (string)request_id->method,
		 http_encode_string((string)request_id->not_query),
		 http_encode_string((string)request_id->raw_url),
		 (string)request_id->prot,
		 (string)(file->error||200),
		 unsigned_short_to_bin(file->error||200),
		 (string)(file->len>=0?file->len:"?"),
		 unsigned_to_bin(file->len),
		 (string)
		 (sizeof(request_id->referer||({}))?request_id->referer[0]:"-"),
		 http_encode_string(sizeof(request_id->client||({}))?request_id->client*" ":"-"),
		 extract_user(request_id->realauth),
		 request_id->cookies->RoxenUserID||"0",
		 (string)(time(1)-request_id->time)
	       }));
  
  if(search(form, "host") != -1)
    roxen->ip_to_host(request_id->remoteaddr, write_to_log, form,
		      request_id->remoteaddr, log_function);
  else
    log_function(form);
//    _debug(0);
}

// These are here for statistics and debug reasons only.
public string status()
{
  float tmp;
  string res="";
  float dt = (float)(time(1) - roxen->start_time + 1);

  res = "<table>";
  res += LOCALE->config_status(((float)sent/(1024.0*1024.0)), 
                               (((float)sent)/(1024.0*1024.0)/dt) * 8192.0,
			       ((float)hsent)/(1024.0*1024.0), 
                                requests,
                                (((float)requests * 60.0)/dt), 
                                ((float)received)/(1024.0*1024.0));

  if (!zero_type(misc->ftp_users)) {
    res += LOCALE->ftp_status(misc->ftp_users,
			      (((float)misc->ftp_users*(float)60.0)/dt),
			      misc->ftp_users_now);
  }
  res += "</table><p>\n\n";

  if ((extra_statistics->ftp) && (extra_statistics->ftp->commands)) {
    // FTP statistics.
    res += LOCALE->ftp_statistics() + "<br>\n"
      "<ul><table>\n";
    foreach(sort(indices(extra_statistics->ftp->commands)), string cmd) {
      res += LOCALE->ftp_stat_line(upper_case(cmd),
				   extra_statistics->ftp->commands[cmd]);
    }
    res += "</table></ul>\n";
  }
  
  return res;
}

public array(string) userinfo(string u, RequestID|void id)
{
  if(auth_module) return auth_module->userinfo(u);
  else report_warning(sprintf("userinfo(): %s\n"
			      "%s\n",
			      LOCALE->no_auth_module(),
			      describe_backtrace(backtrace())));
}

public array(string) userlist(RequestID|void id)
{
  if(auth_module) return auth_module->userlist();
  else report_warning(sprintf("userlist(): %s\n"
			      "%s\n",
			      LOCALE->no_auth_module(),
			      describe_backtrace(backtrace())));
}

public array(string) user_from_uid(int u, RequestID|void id)
{
  if(auth_module)
    return auth_module->user_from_uid(u);
  else report_warning(sprintf("user_from_uid(): %s\n"
			      "%s\n",
			      LOCALE->no_auth_module(),
			      describe_backtrace(backtrace())));
}

public string last_modified_by(Stdio.File file, RequestID id)
{
  int *s;
  int uid;
  mixed *u;
  
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
  Stdio.File f = open("roxen-images/dir/"+from+".gif","r");
  if (f) {
    return (["file":f, "type":"image/gif"]);
  } else {
    // File not found.
    return 0;
  }
}

private static int nest = 0;
  
#ifdef MODULE_LEVEL_SECURITY
private mapping misc_cache=([]);

int|mapping check_security(function a, RequestID id, void|int slevel)
{
  array level;
  array seclevels;
  int ip_ok = 0;	// Unknown
  int auth_ok = 0;	// Unknown
  // NOTE:
  //   ip_ok and auth_ok are three-state variables.
  //   Valid contents for them are:
  //     0  Unknown state -- No such restriction encountered yet.
  //     1  May be bad -- Restriction encountered, and test failed.
  //    ~0  OK -- Test passed.

  if(!(seclevels = misc_cache[ a ]))
    if(function_object(a)->query_seclevels)
      misc_cache[ a ] = seclevels = ({
	function_object(a)->query_seclevels(),
	function_object(a)->query("_seclvl"),
	function_object(a)->query("_sec_group")
      });
    else
      misc_cache[ a ] = seclevels = ({({}),0,"foo" });

  if(slevel && (seclevels[1] > slevel)) // "Trustlevel" to low.
    return 1;
  
  if(!sizeof(seclevels[0]))
    return 0; // Ok if there are no patterns.

  mixed err;
  err = catch {
    foreach(seclevels[0], level) {
      switch(level[0]) {
      case MOD_ALLOW: // allow ip=...
	if(level[1](id->remoteaddr)) {
	  ip_ok = ~0;	// Match. It's ok.
	} else {
	  ip_ok |= 1;	// IP may be bad.
	}
	break;
	
      case MOD_DENY: // deny ip=...

	// FIXME: LOCALE?
	if(level[1](id->remoteaddr))
	  return http_low_answer(403, "<h2>Access forbidden</h2>");
	break;

      case MOD_USER: // allow user=...
	if(id->auth && id->auth[0] && level[1](id->auth[1])) {
	  auth_ok = ~0;	// Match. It's ok.
	} else {
	  auth_ok |= 1;	// Auth may be bad.
	}
	break;
	
      case MOD_PROXY_USER: // allow user=...
	if (ip_ok != 1) {
	  // IP is OK as of yet.
	  if(id->misc->proxyauth && id->misc->proxyauth[0] && 
	     level[1](id->misc->proxyauth[1])) return 0;
	  return http_proxy_auth_required(seclevels[2]);
	} else {
	  // Bad IP.
	  return 1;
	}
        break;

      case MOD_ACCEPT: // accept ip=...
	// Short-circuit version on allow.
	if(level[1](id->remoteaddr)) {
	  // Match. It's ok.
	  return 0;
	} else {
	  ip_ok |= 1;	// IP may be bad.
	}
	break;

      case MOD_ACCEPT_USER: // accept user=...
	// Short-circuit version on allow.
	if(id->auth && id->auth[0] && level[1](id->auth[1])) {
	  // Match. It's ok.
	  return 0;
	} else {
	  if (id->auth) {
	    auth_ok |= 1;	// Auth may be bad.
	  } else {
	    // No auth yet, get some.
	    return http_auth_failed(seclevels[2]);
	  }
	}
	break;
      }
    }
  };

  if (err) {
    report_error(LOCALE->module_security_error(describe_backtrace(err)));
    return 1;
  }

  if (ip_ok == 1) {
    // Bad IP.
    return 1;
  } else {
    // IP OK, or no IP restrictions.
    if (auth_ok == 1) {
      // Bad authentification.
      // Query for authentification.
      return http_auth_failed(seclevels[2]);
    } else {
      // No auth required, or authentification OK.
      return 0;
    }
  }
}
#endif
// Empty all the caches above.
void invalidate_cache()
{
  last_module_cache = 0;
  filter_module_cache = 0;
  first_module_cache = 0;
  url_module_cache = 0;
  location_module_cache = 0;
  logger_module_cache = 0;
  file_extension_module_cache = ([]);
  provider_module_cache = ([]);
#ifdef MODULE_LEVEL_SECURITY
  if(misc_cache)
    misc_cache = ([ ]);
#endif
}

// Empty all the caches above AND the ones in the loaded modules.
void clear_memory_caches()
{
  invalidate_cache();
  foreach(indices(otomod), RoxenModule m) 
    if (m && m->clear_memory_caches) 
      if (mixed err = catch( m->clear_memory_caches() )) 
	report_error(LOCALE->
		     clear_memory_cache_error(otomod[m],
					      describe_backtrace(err)));
}

string draw_saturation_bar(int hue,int brightness, int where)
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

  return Image.GIF.encode(bar);
}


// Inspired by the internal-gopher-... thingie, this is the images
// from the configuration interface. :-)
private mapping internal_roxen_image(string from)
{
  // changed 970820 by js to allow for jpeg images
  sscanf(from, "%s.gif", from);
  sscanf(from, "%s.jpg", from);

  // Disallow "internal-roxen-..", it won't really do much harm, but a list of
  // all files in '..' might be retrieved (that is, the actual directory
  // file was sent to the browser)
  // /internal-roxen-../.. was never possible, since that would be remapped to
  // /..
  from -= ".";

  // New idea: Automatically generated colorbar. Used by wizard code...
  int hue,bright,w;
  if(sscanf(from, "%*s:%d,%d,%d", hue, bright,w)==4)
    return http_string_answer(draw_saturation_bar(hue,bright,w),"image/gif");

  if(Stdio.File f=open("roxen-images/"+from+".gif", "r"))
    return (["file":f, "type":"image/gif"]);
  else if (f = open("roxen-images/"+from+".jpg", "r")) {
    return (["file":f, "type":"image/jpeg"]);
  } else {
    // File not found.
    return 0;
  }
}


mapping (mixed:function|int) locks = ([]);

#ifdef THREADS
// import Thread;

mapping locked = ([]), thread_safe = ([]);

mixed _lock(object|function f)
{
  object key;
  function|int l;

  if (functionp(f)) {
    f = function_object(f);
  }
  if (l = locks[f])
  {
    if (l != -1)
    {
      // Allow recursive locks.
      catch{
	//perror("lock %O\n", f);
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
    //perror("lock %O\n", f);
    locked[f]++;
    key = l();
  }
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
	   res = LOCALE->returned_redirect_to(m->extra_heads->location);
	 else
	   res = LOCALE->returned_redirect_no_location();
	 break;

      case 401:
	 if (m->extra_heads["www-authenticate"])
	   res = LOCALE->
	     returned_authenticate(m->extra_heads["www-authenticate"]);
	 else
	   res = LOCALE->returned_auth_failed();
	 break;

      case 200:
	 res = LOCALE->returned_ok();
	 break;
	 
      default:
	 res = LOCALE->returned_error(m->error);
   }

   if (!zero_type(m->len))
      if (m->len<0)
	 res += LOCALE->returned_no_data();
      else
	 res += LOCALE->returned_bytes(m->len);
   else if (stringp(m->data))
      res += LOCALE->returned_bytes(strlen(m->data));
   else if (objectp(m->file))
      if (catch {
	 array a=m->file->stat();
	 res += LOCALE->returned_bytes(a[1]-m->file->tell());
      })
	res += LOCALE->returned_unknown_bytes();

   if (m->data) res += LOCALE->returned_static_data();
   else if (m->file) res += LOCALE->returned_open_file();

   if (stringp(m->extra_heads["http-content-type"]) ||
       stringp(m->type)) {
      res += LOCALE->returned_type(m->type);
   }

   res+="<br>";

   return res;
}

// The function that actually tries to find the data requested.  All
// modules are mapped, in order, and the first one that returns a
// suitable responce is used.
mapping|int low_get_file(RequestID id, int|void no_magic)
{
#ifdef MODULE_LEVEL_SECURITY
  int slevel;
#endif

#ifdef THREADS
  object key;
#endif
  TRACE_ENTER(LOCALE->request_for(id->not_query), 0);

  string file=id->not_query;
  string loc;
  function funp;
  mixed tmp, tmp2;
  mapping|object fid;

  if(!no_magic)
  {
#ifndef NO_INTERNAL_HACK
    string type;
    // No, this is not beautiful... :) 
    // min length == 17 (/internal-roxen-?..)
    // This will save some time indeed.
    if(sizeof(file) > 17 && (file[0] == '/') &&
       sscanf(file, "%*s/internal-%s-%[^/]", type, loc) == 3)
    {
      switch(type) {
       case "gopher":
	TRACE_LEAVE(LOCALE->magic_internal_gopher());
	return internal_gopher_image(loc);

       case "spinner": case "roxen":
	TRACE_LEAVE(LOCALE->magic_internal_roxen());
	return internal_roxen_image(loc);
      }
    }
#endif
  
    if(id->prestate->diract && dir_module)
    {
      LOCK(dir_module);
      TRACE_ENTER(LOCALE->directory_module(), dir_module);
      tmp = dir_module->parse_directory(id);
      UNLOCK();
      if(mappingp(tmp)) 
      {
	TRACE_LEAVE("");
	TRACE_LEAVE(LOCALE->returning_data());
	return tmp;
      }
      TRACE_LEAVE("");
    }

    if(!search(file, QUERY(InternalLoc))) 
    {
      TRACE_ENTER(LOCALE->magic_internal_module_location(), 0);
      RoxenModule module;
      string name, rest;
      function find_internal;
      if(2==sscanf(file[strlen(QUERY(InternalLoc))..], "%s/%s", name, rest) &&
	 (module = find_module(replace(name, "!", "#"))) &&
	 (find_internal = module->find_internal))
      {
#ifdef MODULE_LEVEL_SECURITY
	if(tmp2 = check_security(find_internal, id, slevel))
	  if(intp(tmp2))
	  {
	    TRACE_LEAVE(LOCALE->module_access_denied());
	    find_internal = 0;
	  } else {
	    TRACE_LEAVE("");
	    TRACE_LEAVE(LOCALE->request_denied());
	    return tmp2;
	  }
#endif
	if(find_internal)
	{
	  TRACE_ENTER(LOCALE->calling_find_internal(), find_internal);
	  LOCK(find_internal);
	  fid=find_internal( rest, id );
	  UNLOCK();
	  TRACE_LEAVE(LOCALE->find_internal_returned(fid));
	  if(fid)
	  {
	    if(mappingp(fid))
	    {
	      TRACE_LEAVE("");
	      TRACE_LEAVE(examine_return_mapping(fid));
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
		TRACE_LEAVE(LOCALE->returned_fd()
#ifdef MODULE_LEVEL_SECURITY
			    +(slevel != oslevel?
			      LOCALE->seclevel_is_now(slevel):"")
#endif
			    +".");
	      else
		TRACE_LEAVE(LOCALE->returned_directory_indicator()
#ifdef MODULE_LEVEL_SECURITY
			    +(oslevel != slevel?
			      LOCALE->seclevel_is_now(slevel):"")
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
  }

  // Well, this just _might_ be somewhat over-optimized, since it is
  // quite unreadable, but, you cannot win them all.. 
  if(!fid)
  {
#ifdef URL_MODULES
  // Map URL-modules
    foreach(url_modules(id), funp)
    {
      LOCK(funp);
      TRACE_ENTER(LOCALE->url_module(), funp);
      tmp=funp( id, file );
      UNLOCK();
    
      if(mappingp(tmp)) 
      {
	TRACE_LEAVE("");
	TRACE_LEAVE(LOCALE->returning_data());
	return tmp;
      }
      if(objectp( tmp ))
      {
	array err;
	
	nest ++;
	err = catch {
	  if( nest < 20 )
	    tmp = (id->conf || this_object())->low_get_file( tmp, no_magic );
	  else
	  {
	    TRACE_LEAVE(LOCALE->too_deep_recursion());
	    error("Too deep recursion in roxen::get_file() while mapping "
		  +file+".\n");
	  }
	};
	nest = 0;
	if(err) throw(err);
	TRACE_LEAVE("");
	TRACE_LEAVE(LOCALE->returning_data());
	return tmp;
      }
      TRACE_LEAVE("");
    }
#endif

    foreach(location_modules(id), tmp)
    {
      loc = tmp[0];
      if(!search(file, loc))
      {
	TRACE_ENTER(LOCALE->location_module(loc), tmp[1]);
#ifdef MODULE_LEVEL_SECURITY
	if(tmp2 = check_security(tmp[1], id, slevel))
	  if(intp(tmp2))
	  {
	    TRACE_LEAVE(LOCALE->module_access_denied());
	    continue;
	  } else {
	    TRACE_LEAVE("");
	    TRACE_LEAVE(LOCALE->request_denied());
	    return tmp2;
	  }
#endif
	TRACE_ENTER(LOCALE->calling_find_file(), 0);
	LOCK(tmp[1]);
	fid=tmp[1]( file[ strlen(loc) .. ] + id->extra_extension, id);
	UNLOCK();
	TRACE_LEAVE(LOCALE->find_file_returned(fid));
	if(fid)
	{
	  id->virtfile = loc;
	  
	  if(mappingp(fid))
	  {
	    TRACE_LEAVE("");
	    TRACE_LEAVE(examine_return_mapping(fid));
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
	      TRACE_LEAVE(LOCALE->returned_fd()
#ifdef MODULE_LEVEL_SECURITY
			  +(slevel != oslevel?
			    LOCALE->seclevel_is_now(slevel):"")
#endif
			  
			  +".");
	    else
	      TRACE_LEAVE(LOCALE->returned_directory_indicator()
#ifdef MODULE_LEVEL_SECURITY
			  +(oslevel != slevel?
			    LOCALE->seclevel_is_now(slevel):"")
#endif
			  );
	    break;
	  }
	} else
	  TRACE_LEAVE("");
      } else if(strlen(loc)-1==strlen(file) && file+"/" == loc) {
	// This one is here to allow accesses to /local, even if 
	// the mountpoint is /local/. It will slow things down, but...
	TRACE_ENTER(LOCALE->automatic_redirect_to_location(), tmp[1]);
	TRACE_LEAVE(LOCALE->returning_data());
	  
	// Keep query (if any).
	/* FIXME: Should probably keep prestate etc.
	 *	/grubba 1999-01-14
	 */
	string new_query = http_encode_string(id->not_query) + "/" +
	  (id->query?("?"+id->query):"");
	
	return http_redirect(new_query, id);
      }
    }
  }
  
  if(fid == -1)
  {
    if(no_magic)
    {
      TRACE_LEAVE(LOCALE->no_magic());
      return -1;
    }
    if(dir_module)
    {
      LOCK(dir_module);
      TRACE_ENTER(LOCALE->directory_module(), dir_module);
      fid = dir_module->parse_directory(id);
      UNLOCK();
    }
    else
    {
      TRACE_LEAVE(LOCALE->no_directory_module());
      return 0;
    }
    if(mappingp(fid)) 
    {
      TRACE_LEAVE(LOCALE->returning_data());
      return (mapping)fid;
    }
  }
  
  // Map the file extensions, but only if there is a file...
  if(objectp(fid) &&
     (tmp = file_extension_modules(loc = extension(id->not_query, id), id))) {
    foreach(tmp, funp)
    {
      TRACE_ENTER(LOCALE->extension_module(loc), funp);
#ifdef MODULE_LEVEL_SECURITY
      if(tmp=check_security(funp, id, slevel))
	if(intp(tmp))
	{
	  TRACE_LEAVE(LOCALE->module_access_denied());
	  continue;
	}
	else
	{
	  TRACE_LEAVE("");
	  TRACE_LEAVE(LOCALE->permission_denied());
	  return tmp;
	}
#endif
      LOCK(funp);
      tmp=funp(fid, loc, id);
      UNLOCK();
      if(tmp)
      {
	if(!objectp(tmp))
	{
	  TRACE_LEAVE("");
	  TRACE_LEAVE(LOCALE->returning_data());
	  return tmp;
	}
	if(fid)
	  destruct(fid);
	TRACE_LEAVE(LOCALE->returned_new_open_file());
	fid = tmp;
	break;
      } else
	TRACE_LEAVE("");
    }
  }
  if(objectp(fid))
  {
    if(stringp(id->extension)) {
      id->not_query += id->extension;
      loc = extension(id->not_query, id);
    }
    TRACE_ENTER(LOCALE->content_type_module(), types_module);
    tmp=type_from_filename(id->not_query, 1, loc);
    TRACE_LEAVE(tmp?LOCALE->returned_mime_type(tmp[0],tmp[1]):
		LOCALE->missing_type());
    if(tmp)
    {
      TRACE_LEAVE("");
      return ([ "file":fid, "type":tmp[0], "encoding":tmp[1] ]);
    }    
    TRACE_LEAVE("");
    return ([ "file":fid, ]);
  }
  if(!fid)
  {
    TRACE_LEAVE(LOCALE->returned_not_found());
  }
  else
    TRACE_LEAVE(LOCALE->returning_data());
  return fid;
}


mixed handle_request( RequestID id  )
{
  function funp;
  mixed file;

#ifdef REQUEST_DEBUG
  werror("CONFIG: handle_request()\n");
#endif /* REQUEST_DEBUG */
  foreach(first_modules(id), funp)
  {
    if(file = funp( id )) 
      break;
    if(id->conf != this_object()) {
#ifdef REQUEST_DEBUG
      werror("CONFIG: handle_request(): Redirected (2)\n");
#endif /* REQUEST_DEBUG */
      return id->conf->handle_request(id);
    }
  }
  if(!mappingp(file) && !mappingp(file = get_file(id)))
  {
    mixed ret;
    foreach(last_modules(id), funp) if(ret = funp(id)) break;
    if (ret == 1) {
#ifdef REQUEST_DEBUG
      werror("CONFIG: handle_request(): Recurse\n");
#endif /* REQUEST_DEBUG */
      return handle_request(id);
    }
    file = ret;
  }
#ifdef REQUEST_DEBUG
  werror("CONFIG: handle_request(): Done\n");
#endif /* REQUEST_DEBUG */
  return file;
}

mixed get_file(RequestID id, int|void no_magic)
{
  mixed res, res2;
  function tmp;
  res = low_get_file(id, no_magic);
  // finally map all filter type modules.
  // Filter modules are like TYPE_LAST modules, but they get called
  // for _all_ files.
  foreach(filter_modules(id), tmp)
  {
    TRACE_ENTER(LOCALE->filter_module(), tmp);
    if(res2=tmp(res,id))
    {
      if(res && res->file && (res2->file != res->file))
	destruct(res->file);
      TRACE_LEAVE(LOCALE->rewrote_result());
      res=res2;
    } else
      TRACE_LEAVE("");
  }
  return res;
}

public array find_dir(string file, RequestID id)
{
  string loc;
  array dir = ({ }), tmp;
  array | mapping d;
  TRACE_ENTER(LOCALE->list_directory(file), 0);
//   file=replace(file, "//", "/");
  
  if(file[0] != '/')
    file = "/" + file;

#ifdef URL_MODULES
#ifdef THREADS
  object key;
#endif
  // Map URL-modules
  foreach(url_modules(id), function funp)
  {
    string of = id->not_query;
    id->not_query = file;
    LOCK(funp);
    TRACE_ENTER(LOCALE->url_module(), funp);
    tmp=funp( id, file );
    UNLOCK();

    if(mappingp( tmp ))
    {
      id->not_query=of;
      TRACE_LEAVE(LOCALE->returned_no_thanks());
      TRACE_LEAVE("");
      return 0;
    }
    if(objectp( tmp ))
    {
      array err;
      nest ++;
      
      TRACE_LEAVE(LOCALE->recursing());
      file = id->not_query;
      err = catch {
	if( nest < 20 )
	  tmp = (id->conf || this_object())->find_dir( file, id );
	else
	  error("Too deep recursion in roxen::find_dir() while mapping "
		+file+".\n");
      };
      nest = 0;
      TRACE_LEAVE("");
      if(err)
	throw(err);
      return tmp;
    }
    id->not_query=of;
  }
#endif /* URL_MODULES */

  foreach(location_modules(id), tmp)
  {
    loc = tmp[0];
    if(!search(file, loc)) {
      /* file == loc + subpath */
      TRACE_ENTER(LOCALE->location_module(loc), tmp[1]);
#ifdef MODULE_LEVEL_SECURITY
      if(check_security(tmp[1], id)) {
	TRACE_LEAVE(LOCALE->permission_denied());
	continue;
      }
#endif
      if(d=function_object(tmp[1])->find_dir(file[strlen(loc)..], id))
      {
	if(mappingp(d))
	{
	  if(d->files) { 
	    dir |= d->files;
	    TRACE_LEAVE(LOCALE->got_exclusive_dir());
	    TRACE_LEAVE(LOCALE->returning_file_list(sizeof(dir)));
	    return dir;
	  } else
	    TRACE_LEAVE("");
	} else {
	  TRACE_LEAVE(LOCALE->got_files());
	  dir |= d;
	}
      } else
	TRACE_LEAVE("");
    } else if((search(loc, file)==0) && (loc[strlen(file)-1]=='/') &&
	      (loc[0]==loc[-1]) && (loc[-1]=='/') &&
	      (function_object(tmp[1])->stat_file(".", id))) {
      /* loc == file + "/" + subpath + "/"
       * and stat_file(".") returns non-zero.
       */
      TRACE_ENTER(LOCALE->location_module(loc), tmp[1]);
      loc=loc[strlen(file)..];
      sscanf(loc, "%s/", loc);
      dir += ({ loc });
      TRACE_LEAVE(LOCALE->added_module_mountpoint());
    }
  }
  if(sizeof(dir))
  {
    TRACE_LEAVE(LOCALE->returning_file_list(sizeof(dir)));
    return dir;
  } 
  TRACE_LEAVE(LOCALE->returning_no_dir());
}

// Stat a virtual file. 

public array(int) stat_file(string file, RequestID id)
{
  string loc;
  array s, tmp;
#ifdef THREADS
  object key;
#endif
  TRACE_ENTER(LOCALE->stat_file(file), 0);
  
  file=replace(file, "//", "/"); // "//" is really "/" here...

#ifdef URL_MODULES
  // Map URL-modules
  foreach(url_modules(id), function funp)
  {
    string of = id->not_query;
    id->not_query = file;

    TRACE_ENTER(LOCALE->url_module(), funp);
    LOCK(funp);
    tmp=funp( id, file );
    UNLOCK();

    if(mappingp( tmp )) {
      id->not_query = of;
      TRACE_LEAVE("");
      TRACE_LEAVE(LOCALE->returned_no_thanks());
      return 0;
    }
    if(objectp( tmp ))
    {
      file = id->not_query;

      array err;
      nest ++;
      TRACE_LEAVE(LOCALE->recursing());
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
      TRACE_LEAVE(LOCALE->returning_data());
      return tmp;
    }
    TRACE_LEAVE("");
    id->not_query = of;
  }
#endif
    
  // Map location-modules.
  foreach(location_modules(id), tmp)
  {
    loc = tmp[0];
    if((file == loc) || ((file+"/")==loc))
    {
      TRACE_ENTER(LOCALE->location_module(loc), tmp[1]);
      TRACE_LEAVE(LOCALE->exact_match());
      TRACE_LEAVE("");
      return ({ 0775, -3, 0, 0, 0, 0, 0, 0, 0, 0, 0 });
    }
    if(!search(file, loc)) 
    {
      TRACE_ENTER(LOCALE->location_module(loc), tmp[1]);
#ifdef MODULE_LEVEL_SECURITY
      if(check_security(tmp[1], id)) {
	TRACE_LEAVE("");
	TRACE_LEAVE(LOCALE->permission_denied());
	continue;
      }
#endif
      if(s=function_object(tmp[1])->stat_file(file[strlen(loc)..], id))
      {
	TRACE_LEAVE("");
	TRACE_LEAVE(LOCALE->stat_ok());
	return s;
      }
      TRACE_LEAVE("");
    }
  }
  TRACE_LEAVE(LOCALE->returned_not_found());
}

class StringFile
{
  string data;
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

  void write(mixed ... args)
  {
    throw( ({ "File not open for write", backtrace() }) );
  }

  void seek(int to)
  {
    offset = to;
  }

  void create(string d)
  {
    data = d;
  }

}


// this is not as trivial as it sounds. Consider gtext. :-)
public array open_file(string fname, string mode, RequestID id)
{
  object oc = id->conf;
  string oq = id->not_query;
  function funp;
  mapping|int(0..1) file;

  id->not_query = fname;

  foreach(oc->first_modules(), funp)
    if(file = funp( id )) 
      break;
    else if(id->conf != oc) 
    {
      return open_file(fname, mode,id);
    }
  fname = id->not_query;

  if(search(mode, "R")!=-1) //  raw (as in not parsed..)
  {
    string f;
    mode -= "R";
    if(f = real_file(fname, id))
    {
      //      werror("opening "+fname+" in raw mode.\n");
      return ({ open(f, mode), ([]) });
    }
//     return ({ 0, (["error":302]) });
  }

  if(mode=="r")
  {
    if(!file)
    {
      file = oc->get_file( id );
      if(!file) {
	foreach(oc->last_modules(), funp) if(file = funp( id ))
	  break;
	if (file == 1) {
	  // Recurse.
	  return open_file(id->not_query, mode, id);
	}
      }
    }

    if(!mappingp(file))
    {
      if(id->misc->error_code)
	file = http_low_answer(id->misc->error_code, "Failed" );
      else if(id->method!="GET"&&id->method != "HEAD"&&id->method!="POST")
	file = http_low_answer(501, "Not implemented.");
      else
	file=http_low_answer(404,replace(parse_rxml(query("ZNoSuchFile"),id),
					 ({"$File", "$Me"}), 
					 ({fname,query("MyWorldLocation")})));

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
  return ({ 0, (["error":501, "data":"Not implemented"]) });
}


public mapping(string:array(mixed)) find_dir_stat(string file, RequestID id)
{
  string loc;
  mapping(string:array(mixed)) dir = ([]);
  mixed d, tmp;


  file=replace(file, "//", "/");
  
  if(file[0] != '/')
    file = "/" + file;

  // FIXME: Should I append a "/" to file if missing?

  TRACE_ENTER(LOCALE->find_dir_stat(file), 0);

#ifdef URL_MODULES
#ifdef THREADS
  object key;
#endif
  // Map URL-modules
  foreach(url_modules(id), function funp)
  {
    string of = id->not_query;
    id->not_query = file;
    LOCK(funp);
    TRACE_ENTER(LOCALE->url_module(), funp);
    tmp=funp( id, file );
    UNLOCK();

    if(mappingp( tmp ))
    {
      id->not_query=of;
#ifdef MODULE_DEBUG
      roxen_perror(sprintf("conf->find_dir_stat(\"%s\"): url_module returned mapping:%O\n", 
			   file, tmp));
#endif /* MODULE_DEBUG */
      TRACE_LEAVE(LOCALE->returned_mapping()+sprintf("%O", tmp));
      TRACE_LEAVE("");
      return 0;
    }
    if(objectp( tmp ))
    {
      array err;
      nest ++;
      
      file = id->not_query;
      err = catch {
	if( nest < 20 )
	  tmp = (id->conf || this_object())->find_dir_stat( file, id );
	else {
	  TRACE_LEAVE(LOCALE->too_deep_recursion());
	  error("Too deep recursion in roxen::find_dir_stat() while mapping "
		+file+".\n");
	}
      };
      nest = 0;
      if(err)
	throw(err);
#ifdef MODULE_DEBUG
      roxen_perror(sprintf("conf->find_dir_stat(\"%s\"): url_module returned object:\n", 
			   file));
#endif /* MODULE_DEBUG */
      TRACE_LEAVE(LOCALE->returned_object());
      TRACE_LEAVE(LOCALE->returning_it());
      return tmp;	// FIXME: Return 0 instead?
    }
    id->not_query=of;
    TRACE_LEAVE("");
  }
#endif /* URL_MODULES */

  foreach(location_modules(id), tmp)
  {
    loc = tmp[0];

    TRACE_ENTER(LOCALE->location_module(loc), 0);
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
	TRACE_ENTER(LOCALE->has_find_dir_stat(), 0);
	if (d = c->find_dir_stat(f, id)) {
          TRACE_ENTER(LOCALE->returned_mapping()+sprintf("%O", d),c);
	  dir = d | dir;
	  TRACE_LEAVE("");
	}
	TRACE_LEAVE("");
      } else if(d = c->find_dir(f, id)) {
	TRACE_ENTER(LOCALE->returned_array(), 0);
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
      TRACE_ENTER(LOCALE->file_on_mountpoint_path(file, loc), 0);
      loc=loc[strlen(file)..];
      sscanf(loc, "%s/", loc);
      if (!dir[loc]) {
	dir[loc] = ({ 0775, -3, 0, 0, 0, 0, 0, 0, 0, 0, 0 });
      }
      TRACE_LEAVE("");
    }
    TRACE_LEAVE("");
  }
  if(sizeof(dir))
    return dir;
}


// Access a virtual file?

public array access(string file, RequestID id)
{
  string loc;
  array s, tmp;
  
  file=replace(file, "//", "/"); // "//" is really "/" here...
    
  // Map location-modules.
  foreach(location_modules(id), tmp)
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

// Return the _real_ filename of a virtual file, if any.

public string real_file(string file, RequestID id)
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
      if(s=function_object(tmp[1])->real_file(file[strlen(loc)..], id))
	return s;
    }
  }
}

// Convenience functions used in quite a lot of modules. Tries to
// read a file into memory, and then returns the resulting string.

// NOTE: A 'file' can be a cgi script, which will be executed, resulting in
// a horrible delay.
int|string try_get_file(string s, RequestID id, 
                        int|void status, int|void nocache)
{
  string res, q;
  RequestID fake_id;
  mapping m;

  if(!objectp(id)) 
    error("No ID passed to 'try_get_file'\n");

  // id->misc->common makes it possible to pass information to
  // the originating request.
  if ( !id->misc )
    id->misc = ([]);
  if ( !id->misc->common )
    id->misc->common = ([]);
  
  fake_id = id->clone_me();
  
  fake_id->misc->common = id->misc->common;

  if(!id->pragma["no-cache"] && !nocache && (!id->auth || !id->auth[0]))
    if(res = cache_lookup("file:"+id->conf->name, s))
      return res;

  if(sscanf(s, "%s?%s", s, q))
  {
    string v, name, value;
    foreach(q/"&", v)
      if(sscanf(v, "%s=%s", name, value))
	fake_id->variables[http_decode_string(name)]=
          http_decode_string(value);
    fake_id->query=q;
  }

  fake_id->raw_url=s;
  fake_id->not_query=s;
  fake_id->misc->internal_get=1;

  if(!(m = get_file(fake_id)))
    return 0;

  if (!(< 0, 200, 201, 202, 203 >)[m->error]) return 0;
  
  if(status) return 1;

  if(m->data) 
    res = m->data;
  else 
    res="";
  m->data = 0;
  
  if(m->file)
  {
    res += m->file->read();
    destruct(m->file);
    m->file = 0;
  }
  
  if(m->raw)
  {
    res -= "\r";
    if(!sscanf(res, "%*s\n\n%s", res))
      sscanf(res, "%*s\n%s", res);
  }
  if (!id->auth || !id->auth[0]) 
    cache_set("file:"+id->conf->name, s, res);
  return res;
}

// Is 'what' a file in our virtual filesystem?
int(0..1) is_file(string what, RequestID id)
{
  return !!stat_file(what, id);
}

array registered_urls = ({});
void start(int num)
{
  // Note: This is run as root if roxen is started as root
  foreach( query( "URLs" )-registered_urls, string url )
  {
    registered_urls += ({ url });
    roxenp()->register_url( url, this_object() );
  }
  foreach( registered_urls-query("URLs"), string url )
  {
    registered_urls -= ({ url });
    roxenp()->unregister_url( url );
  }
}

// Save this configuration. If all is included, save all configuration
// global variables as well, otherwise only all module variables.
void save_me()
{
  save_one( 0 );
}

void save(int|void all)
{
  if(all)
  {
    store("spider#0", variables, 0, this_object());
    start(2);
  }
  
  foreach(indices(modules), string modname)
  {
    foreach(indices(modules[modname]->copies), int i)
    {
      store(modname+"#"+i, modules[modname]->copies[i]->query(), 0, this_object());
      modules[modname]->copies[i]->start(2, this_object());
    }
  }
  invalidate_cache();
}

// Save all variables in _one_ module.
int save_one( RoxenModule o )
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
  o->start(2, this_object());
  invalidate_cache();
  return 1;
}

void reload_module( string modname )
{
  RoxenModule old_module = find_module( modname );
  int do_delete_doto;

  if( !old_module )
    return;

  master()->refresh_inherit( object_program( old_module ) );

  if( enable_module( modname ) == old_module )
    return;

  catch( disable_module( modname ) );

  if( enable_module( modname ) == 0 )
    enable_module( modname, old_module );
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
  mixed _indices()
  {
    return(indices(copies));
  }
  mixed _values()
  {
    return(values(copies));
  }
  string _sprintf( ) { return "ModuleCopies()"; }
}

RoxenModule enable_module( string modname, RoxenModule|void me )
{
  int id;
  ModuleInfo moduleinfo;
  ModuleCopies module;
  int pr;
  mixed err;
  int module_type;

  if( sscanf(modname, "%s#%d", modname, id ) != 2 )
    while( modules[modname] && modules[modname][id] )
      id++;

  int start_time = gethrtime();

  moduleinfo = roxen->find_module( modname );

  if (!moduleinfo)
  {
#ifdef MODULE_DEBUG
    report_warning("Failed to load %s\n", modname);
#endif
    return 0;
  }

#ifdef MODULE_DEBUG
  if( id )
    report_debug(" %-33s ... \b", moduleinfo->get_name()+" copy "+(id+1));
  else
    report_debug(" %-33s ... \b", moduleinfo->get_name() );
#endif

  module = modules[ modname ];

  if(!module)
    modules[ modname ] = module = ModuleCopies();

  if( !me )
  {
    if(err = catch(me = moduleinfo->instance(this_object())))
    {
#ifdef MODULE_DEBUG
      report_debug("\b ERROR\n");
#endif
      report_error(LOCALE->
                   error_initializing_module_copy(moduleinfo->get_name(),
						  err != "" &&
                                                  describe_backtrace(err)));
      return module[id];
    }
  }

  if(module[id] && module[id] != me)
  {
    module[id]->stop();
//     if( err = catch( disable_module( modname+"#"+id ) ) )
//       report_error(LOCALE->error_disabling_module(moduleinfo->get_name(),
//                                                   describe_backtrace(err)));
  }

  me->set_configuration( this_object() );

  module_type = moduleinfo->type;
  if (module_type & (MODULE_LOCATION|MODULE_EXTENSION|
                     MODULE_CONFIG|MODULE_FILE_EXTENSION|MODULE_LOGGER|
                     MODULE_URL|MODULE_LAST|MODULE_PROVIDER|
                     MODULE_FILTER|MODULE_PARSER|MODULE_FIRST))
  {
    if(module_type != MODULE_CONFIG)
    {
      if (err = catch {
	me->defvar("_priority", 5, "Priority", TYPE_INT_LIST,
		   "The priority of the module. 9 is highest and 0 is lowest."
		   " Modules with the same priority can be assumed to be "
		   "called in random order", 
		   ({0, 1, 2, 3, 4, 5, 6, 7, 8, 9}));
	me->deflocaledoc("svenska", "_priority", "Prioritet",
			 "Modulens prioritet, 9 är högst och 0 är"
			 " lägst. Moduler med samma prioritet anropas i "
			 "mer eller mindre slumpmässig ordning.");
      }) {
	throw(err);
      }
    }
      
    if(module_type != MODULE_LOGGER && module_type != MODULE_PROVIDER)
    {
      if(!(module_type & MODULE_PROXY))
      {
	me->defvar("_sec_group", "user", "Security: Realm", TYPE_STRING,
		   "The realm to use when requesting password from the "
		   "client. Usually used as an informative message to the "
		   "user.");

	me->deflocaledoc("svenska", "_sec_group", "Säkerhet: Grupp",
			 "Gruppnamnet som används när klienten bes"
			 " ange lösenord. I de flesta klienter visas den "
			 " här informationen för användaren i"
			 " lösenordsdialogen.");


	me->defvar("_seclvl",  0, "Security: Security level", TYPE_INT, 
		   "The modules security level is used to determine if a "
		   " request should be handled by the module."
		   "\n<p><h2>Security level vs Trust level</h2>"
		   " Each module has a configurable <i>security level</i>."
		   " Each request has an assigned trust level. Higher"
		   " <i>trust levels</i> grants access to modules with higher"
		   " <i>security levels</i>."
		   "\n<p><h2>Definitions</h2><ul>"
		   " <li>A requests initial Trust level is infinitely high."
		   " <li> A request will only be handled by a module if its"
		   "     <i>trust level</i> is higher or equal to the"
		   "     <i>security level</i> of the module."
		   " <li> Each time the request is handled by a module the"
		   "     <i>trust level</i> of the module will be set to the"
		   "      lower of its <i>trust level</i> and the modules"
		   "     <i>security level</i>."
		   " </ul>"
		   "\n<p><h2>Example</h2>"
		   " Modules:<ul>"
		   " <li>  User filesystem, <i>security level</i> 1"
		   " <li>  Filesystem module, <i>security level</i> 3"
		   " <li>  CGI module, <i>security level</i> 2"
		   " </ul>"
		   "\n<p>A request handled by \"User filesystem\" is assigned"
		   " a <i>trust level</i> of one after the <i>security"
		   " level</i> of that module. That request can then not be"
		   " handled by the \"CGI module\" since that module has a"
		   " higher <i>security level</i> than the requests trust"
		   " level."
		   "\n<p>On the other hand, a request handled by the the"
		   " \"Filsystem module\" could later be handled by the"
		   " \"CGI module\".");
	me->deflocaledoc("svenska", "_seclvl", "Säkerhet: Säkerhetsnivå",
			 "Modulens säkerhetsnivå används för att avgöra om "
			 " en specifik request ska få hanteras av  modulen. "
			 "\n<p><h2>Säkerhetsnivå och pålitlighetsnivå</h2>"
			 " Varje modul har en konfigurerbar "
			 "<i>säkerhtesnivå</i>. "
			 "Varje request har en <i>pålitlighetsnivå</i>.<p>"
			 "Högre <i>pålitlighetsnivåer</i> ger "
			 " requesten tillgång till moduler med högre "
			 "<i>säkerhetsnivå</i>. <p>\n"
			 "\n<p><h2>Defenitioner</h2><ul>"
			 " <li>En requests initialpålitlighetsnivå är "
			 " oändligt hög."
			 " <li> En request hanteras bara av moduler om "
			 "dess <i>pålitlighetsnivå</i> är högre eller "
			 " lika hög som modulens <i>säkerhetsnivå</i>"
			 " <li> Varje gång en request hanteras av en"
			 " modul så sätts dess <i>pålitlighetsnivå</i> "
			 "till modulens <i>säkerhetsnivå</i> om "
			 " modulen har en <i>säkerhetsnivå</i> som är "
			 "skiljd from noll. "
			 " </ul>"
			 "\n<p><h2>Ett exempel</h2>"
			 " Moduler:<ul>"
			 " <li>  Användarfilsystem, <i>säkerhetsnivå</i> 1"
			 " <li>  Filesystem, <i>säkerhetsnivå</i> 3"
			 " <li>  CGI modul, <i>säkerhetsnivå</i> 2"
			 " </ul>"
			 "\n<p>En request hanterad av "
			 " <i>Användarfilsystemet</i> får ett "
			 "som <i>pålitlighetsnivå</i>. Den här"
			 " requesten kan därför inte skickas vidare "
			 "till <i>CGI modulen</i> eftersom den har"
			 " en <i>säkerhetsnivå</i> som är högre än"
			 " requestens <i>pålitlighetsnivå</i>.<p>"
			 "  Å andra sidan så kan en request som "
			 " hanteras av <i>Filsystem</i> modulen "
			 " skickas vidare till <i>CGI modulen</i>.");

	me->defvar("_seclevels", "", "Security: Patterns", TYPE_TEXT_FIELD,
		   "This is the 'security level=value' list.<br>"
		   "Each security level can be any or more from this list:"
		   "<hr noshade>"
		   "allow ip=<i>IP</i>/<i>bits</i><br>"
		   "allow ip=<i>IP</i>:<i>mask</i><br>"
		   "allow ip=<i>pattern</i><br>"
		   "allow user=<i>username</i>,...<br>"
		   "deny ip=<i>IP</i>/<i>bits</i><br>"
		   "deny ip=<i>IP</i>:<i>mask</i><br>"
		   "deny ip=<i>pattern</i><br>"
		   "<hr noshade>"
		   "In patterns: * matches one or more characters, "
		   "and ? matches one character.<p>"
		   "In username: 'any' stands for any valid account "
		   "(from .htaccess"
		   " or an auth module. The default (used when _no_ "
		   "entries are present) is 'allow ip=*', allowing"
		   " everyone to access the module");

	me->deflocaledoc("svenska", "_seclevels", 
			 "Säkerhet: Behörighetsregler",
			 "Det här är en lista av behörighetsregler.<p>"
			 "Varje behörighetsregler måste följa någon av de "
			 " här mönstren: "
			 "<hr noshade>"
			 "allow ip=<i>IP-nummer</i>/<i>antal nätmaskbittar</i><br>"
			 "allow ip=<i>IP-nummer</i>:<i>nätmask</i><br>"
			 "allow ip=<i>globmönster</i><br>"
			 "allow user=<i>användarnamn</i>,...<br>"
			 "deny ip=<i>IP-nummer</i>/<i>antal nätmaskbittar</i><br>"
			 "deny ip=<i>IP-nummer</i>:<i>nätmask</i><br>"
			 "deny ip=<i>globmönster</i><br>"
			 "<hr noshade>"
			 "I globmänster betyer '*' ett eller flera "
			 "godtyckliga tecken, och '?' betyder exekt "
			 "ett godtyckligt tecken.<p> "
			 "Användnamnet 'any' kan användas för att ange "
			 "att vilken giltig användare som helst ska "
			 " kunna få använda modulen.");
      } else {
	me->definvisvar("_seclvl", -10, TYPE_INT); /* A very low one */
	  
	me->defvar("_sec_group", "user", "Proxy Security: Realm", TYPE_STRING,
		   "The realm to use when requesting password from the "
		   "client. Usually used as an informative message to the "
		   "user.");
	me->deflocaledoc("svenska", "_sec_group", "Säkerhet: Grupp",
			 "Gruppnamnet som används när klienten bes"
			 " ange lösenord. I de flesta klienter visas den "
			 " här informationen för användaren i"
			 "lösenordsdialogen.");



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
		   " or an auth module. The default is 'deny ip=*'");

	me->deflocaledoc("svenska", "_seclevels", 
			 "Säkerhet: Behörighetsregler",
			 "Det här är en lista av behörighetsregler.<p>"
			 "Varje behörighetsregler måste följa någon av de "
			 " här mönstren: "
			 "<hr noshade>"
			 "allow ip=<i>IP-nummer</i>/<i>antal nätmaskbittar</i><br>"
			 "allow ip=<i>IP-nummer</i>:<i>nätmask</i><br>"
			 "allow ip=<i>globmönster</i><br>"
			 "allow user=<i>användarnamn</i>,...<br>"
			 "deny ip=<i>IP-nummer</i>/<i>antal nätmaskbittar</i><br>"
			 "deny ip=<i>IP-nummer</i>:<i>nätmask</i><br>"
			 "deny ip=<i>globmönster</i><br>"
			 "<hr noshade>"
			 "I globmänster betyer '*' ett eller flera "
			 "godtyckliga tecken, och '?' betyder exekt "
			 "ett godtyckligt tecken.<p> "
			 "Användnamnet 'any' kan användas för att ange "
			 "att vilken giltig användare som helst ska "
			 " kunna få använda modulen.");


      }
    }
  } else {
    me->defvar("_priority", 0, "", TYPE_INT, "", 0, 1);
  }

  me->defvar("_comment", "", " Comment", TYPE_TEXT_FIELD|VAR_MORE,
	     "An optional comment. This has no effect on the module, it "
	     "is only a text field for comments that the administrator "
	     "might have (why the module are here, etc.)");

  me->deflocaledoc("svenska", "_comment", 
		   "Kommentar",
		   "En kommentar. Den här kommentaren påverkar inte "
		   " funktionaliteten hos modulen på något sätt, den "
		   " syns bara i konfigurationsinterfacet.");



  me->defvar("_name", "", " Module name", TYPE_STRING|VAR_MORE,
	     "An optional name. You can set it to something to remaind you what "
	     "the module really does.");

  me->deflocaledoc("svenska", "_name", "Namn",
		   "Modulens namn. Om den här variablen är satt så "
		   "används dess värde istället för modulens riktiga namn "
		   "i konfigurationsinterfacet.");

  me->setvars(retrieve(modname + "#" + id, this_object()));


  module[ id ] = me;
  otomod[ me ] = modname+"#"+id;
      
  mixed err;
  if((me->start) && (err = catch( me->start(0, this_object()) ) ) )
  {
#ifdef MODULE_DEBUG
    report_debug("\b ERROR\n");
#endif
    report_error(LOCALE->
		 error_initializing_module_copy(moduleinfo->get_name(),
						describe_backtrace(err)));


    /* Clean up some broken references to this module. */
    m_delete(otomod, me);
    m_delete(module->copies, id);
    destruct(me);
    return 0;
  }
    
  if (err = catch(pr = me->query("_priority"))) 
  {
#ifdef MODULE_DEBUG
    report_debug("\b ERROR\n");
#endif
    report_error(LOCALE->
		 error_initializing_module_copy(moduleinfo->get_name(),
						describe_backtrace(err)));
    pr = 3;
  }

  api_module_cache |= me->api_functions();

  if(module_type & MODULE_EXTENSION) 
  {
    report_error( moduleinfo->get_name()+
                  " is an MODULE_EXTENSION, that type is no "
                  "longer available.\nPlease notify the modules writer.\n"
                  "Suitable replacement types include MODULE_FIRST and "
                  " MODULE_LAST\n");
  }

  if(module_type & MODULE_FILE_EXTENSION)
    if (err = catch {
      array arr = me->query_file_extensions();
      if (arrayp(arr)) 
      {
	string foo;
	foreach( me->query_file_extensions(), foo )
	  if(pri[pr]->file_extension_modules[foo] ) 
	    pri[pr]->file_extension_modules[foo]+=({me});
	  else
	    pri[pr]->file_extension_modules[foo]=({me});
      }
    }) {
#ifdef MODULE_DEBUG
      report_debug("\b ERROR\n");
#endif
      report_error(LOCALE->
		   error_initializing_module_copy(moduleinfo->get_name(),
						  describe_backtrace(err)));
    }

  if(module_type & MODULE_PROVIDER) 
    if (err = catch 
    {
      mixed provs = me->query_provides();
      if(stringp(provs))
	provs = (< provs >);
      if(arrayp(provs))
	provs = mkmultiset(provs);
      if (multisetp(provs)) {
	pri[pr]->provider_modules [ me ] = provs;
      }
    }) {
#ifdef MODULE_DEBUG
      report_debug("\b ERROR\n");
#endif
      report_error(LOCALE->
		   error_initializing_module_copy(moduleinfo->get_name(),
                                                  describe_backtrace(err)));
    }
      
  if(module_type & MODULE_TYPES)
  {
    types_module = me;
    types_fun = me->type_from_extension;
  }
  
  if(module_type & MODULE_PARSER)
    add_parse_module( me );


  if(module_type & MODULE_AUTH)
  {
    auth_module = me;
    auth_fun = me->auth;
  }

  if(module_type & MODULE_DIRECTORIES)
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

  if(!enabled_modules[ modname+"#"+id ])
  {
    enabled_modules[modname+"#"+id] = 1;
    store( "EnabledModules", enabled_modules, 1, this_object());
  }
  invalidate_cache();
#ifdef MODULE_DEBUG
  report_debug("\b OK   %5.1fms.\n", (gethrtime()-start_time)/1000.0);
#endif
  return me;
}

// Called from the configuration interface.
string check_variable(string name, mixed value)
{
  switch(name)
  {
   case "MyWorldLocation":
    if(strlen(value)<7 || value[-1] != '/' ||
       !(sscanf(value,"%*s://%*s/")==2))
      return LOCALE->url_format();
    return 0;
  case "throttle":
    if (value) {
      THROTTLING_DEBUG("configuration: Starting throttler up");
      throttler=.throttler();
      throttler->throttle(query("throttle_fill_rate"),
                          query("throttle_bucket_depth"),
                          query("throttle_min_grant"),
                          query("throttle_max_grant"));
    } else {
      THROTTLING_DEBUG("configuration: Stopping throttler");
      destruct(throttler);
      throttler=0;
    }
    return 0;
  case "throttle_fill_rate":
  case "throttle_bucket_depth":
  case "throttle_min_grant":
  case "throttle_max_grant":
    THROTTLING_DEBUG("configuration: setting throttling parameter: "+
                     name+"="+value);
    throttler->throttle(query("throttle_fill_rate"),
                        query("throttle_bucket_depth"),
                        query("throttle_min_grant"),
                        query("throttle_max_grant"));
    return 0;
  }
}

int disable_module( string modname )
{
  RoxenModule me;
  int id, pr;
  sscanf(modname, "%s#%d", modname, id );

  ModuleInfo moduleinfo =  roxen->find_module( modname );
  mapping module = modules[ modname ];

  if(!module) 
  {
    report_error(LOCALE->disable_nonexistant_module(modname));
    return 0;
  }

  me = module[id];
  m_delete(module->copies, id);
  
  if(!sizeof(module->copies))
    m_delete( modules, modname );

  invalidate_cache();

  if(!me)
  {
    if( id )
      report_error(LOCALE->disable_module_failed(moduleinfo->get_name()
                                                 +" # "+id));
    else
      report_error(LOCALE->disable_module_failed(moduleinfo->get_name()));
    return 0;
  }

  if(me->stop) me->stop();

#ifdef MODULE_DEBUG
  if( id )
    report_debug("Disabling "+moduleinfo->get_name()+" # "+id+"\n");
  else
    report_debug("Disabling "+moduleinfo->get_name()+"\n");
#endif

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

  if(moduleinfo->type & MODULE_PARSER)
    remove_parse_module( me );

  if( moduleinfo->type & MODULE_AUTH )
  {
    auth_module = 0;
    auth_fun = 0;
  }

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


  if( enabled_modules[modname+"#"+id] )
  {
    m_delete( enabled_modules, modname + "#" + id );
    store( "EnabledModules",enabled_modules, 1, this_object());
  }
  destruct(me);
  return 1;
}

RoxenModule|string find_module(string name)
{
  int id;
  sscanf(name, "%s#%d", name, id);
  if(modules[name])
    return modules[name]->copies[id];
  return 0;
}

multiset forcibly_added = (<>);
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
        report_debug("\b[ adding required modules\n");
#endif
        forcibly_added[ mod+"#0" ] = 1;
        enable_module( mod+"#0" );
    }
  }
#ifdef MODULE_DEBUG
  if( wr )
    report_debug("]\n");
#endif
}

// BEGIN SQL

mapping(string:string) sql_urls = ([]);

mapping sql_cache = ([]);

Sql.sql sql_cache_get(string what)
{
#ifdef THREADS
  if(sql_cache[what] && sql_cache[what][this_thread()])
    return sql_cache[what][this_thread()];
  if(!sql_cache[what])
    sql_cache[what] =  ([ this_thread():Sql.sql( what ) ]);
  else
    sql_cache[what][ this_thread() ] = Sql.sql( what );
  return sql_cache[what][ this_thread() ];
#else /* !THREADS */
  if(!sql_cache[what])
    sql_cache[what] =  Sql.sql( what );
  return sql_cache[what];
#endif
}

Sql.sql sql_connect(string db)
{
  if (sql_urls[db])
    return sql_cache_get(sql_urls[db]);
  else
    return sql_cache_get(db);
}

// END SQL

// This is the most likely URL for a virtual server.
private string get_my_url()
{
  string s;
#if efun(gethostname)
  s = (gethostname()/".")[0] + "." + query("Domain");
  s -= "\n";
#else
  s = "localhost";
#endif
  return "http://" + s + "/";
}

void enable_all_modules()
{
  enabled_modules = retrieve("EnabledModules", this_object());

  object ec = roxenloader.LowErrorContainer();
  roxenloader.push_compile_error_handler( ec );

  array modules_to_process = indices( enabled_modules );
  string tmp_string;

  parse_log_formats();
  init_log_file();

  int start_time = gethrtime();

  report_debug("\nEnabling all modules for "+query_name()+"... \n");

  // Always enable the user database module first.
  if(search(modules_to_process, "userdb#0")>-1)
    modules_to_process = (({"userdb#0"})+(modules_to_process-({"userdb#0"})));

  array err;
  forcibly_added = (<>);
  foreach( modules_to_process, tmp_string )
  {
    if( !forcibly_added[ tmp_string ] )
      if(err = catch( enable_module( tmp_string )))
        report_error(LOCALE->enable_module_failed(tmp_string, 
                                                  describe_backtrace(err)));
  }
  roxenloader.pop_compile_error_handler();
  if( strlen( ec->get() ) )
    report_error( "While enabling modules in "+name+":\n"+ec->get() );
  report_notice("All modules for %s enabled in %3.1f seconds\n\n", 
                query_name(),(gethrtime()-start_time)/1000000.0);
}

void create(string config)
{
  add_parse_module( (object)this_object() );
  name=config;

  defvar("ZNoSuchFile", "<title>Sorry. I cannot find this resource</title>\n"
	 "<body bgcolor='#ffffff' text='#000000' alink='#ff0000' "
	 "vlink='#00007f' link='#0000ff'>\n"
	 "<h2 align=center><configimage src=roxen.gif alt=\"File not found\">\n"
	 "<p><hr noshade>"
	 "\n<i>Sorry</i></h2>\n"
	 "<br clear>\n<font size=\"+2\">The resource requested "
	 "<i>$File</i>\ncannot be found.<p>\n\nIf you feel that this is a "
	 "configuration error, please contact "
	 "the administrators or the author of the\n"
	 "<if referrer>"
	 "<a href=\"<referrer>\">referring</a>"
	 "</if>\n"
	 "<else>referring</else>\n"
	 "page."
	 "<p>\n</font>\n"
	 "<hr noshade>"
	 "<version>, at <a href=\"$Me\">$Me</a>.\n"
	 "</body>\n", 

	 "Messages: No such file", TYPE_TEXT_FIELD,
	 "What to return when there is no resource or file available "
	 "at a certain location. $File will be replaced with the name "
	 "of the resource requested, and $Me with the URL of this server ");
  deflocaledoc("svenska", "ZNoSuchFile",
	       "Meddelanden: Filen finns inte",
#"Det här meddelandet returneras om en användare frågar efter en
  resurs som inte finns. '$File' byts ut mot den efterfrågade
  resursen, och '$Me' med serverns URL");
  
  defvar("comment", "", "Virtual server comment",
	 TYPE_TEXT_FIELD|VAR_MORE,
	 "This text will be visible in the configuration interface, it "
	 " can be quite useful to use as a memory helper.");

  deflocaledoc("svenska", "comment", "Kommentar",
	       "En kommentar som syns i konfigurationsinterfacet");

  defvar("name", "", "Virtual server name",
	 TYPE_STRING|VAR_MORE,
	 "This is the name that will be used in the configuration "
	 "interface. If this is left empty, the actual name of the "
	 "virtual server will be used");

  deflocaledoc("svenska", "name", "Serverns namn",
#"Det här är namnet som kommer att synas i
  konfigurationsgränssnittet. Om du lämnar det här fältet tomt kommer
  serverns ursprungliga namn (det du skrev in när du skapade servern)
  att användas.");
  
  defvar("LogFormat", 
 "404: $host $referer - [$cern_date] \"$method $resource $protocol\" 404 -\n"
 "500: $host $referer ERROR [$cern_date] \"$method $resource $protocol\" 500 -\n"
 "*: $host - - [$cern_date] \"$method $resource $protocol\" $response $length"
	 ,

	 "Logging: Format", 
	 TYPE_TEXT_FIELD|VAR_MORE,
	 
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
	 "$full_resource -- Full requested resource, including any query fields\n"
	 "$protocol      -- The protocol used (normally HTTP/1.0)\n"
	 "$response      -- The response code sent\n"
	 "$bin-response  -- The response code sent as a binary short number\n"
	 "$length        -- The length of the data section of the reply\n"
       "$bin-length    -- Same, but as an 32 bit iteger in network byteorder\n"
	 "$request-time  -- The time the request took (seconds)\n"
	 "$referer       -- the header 'referer' from the request, or '-'.\n"
      "$user_agent    -- the header 'User-Agent' from the request, or '-'.\n\n"
	 "$user          -- the name of the auth user used, if any\n"
	 "$user_id       -- A unique user ID, if cookies are supported,\n"
	 "                  by the client, otherwise '0'\n"
	 "</pre>", 0, lambda(){ return !query("Log");});
  deflocaledoc("svenska", "LogFormat", "Loggning: Loggningsformat",
#"Vilket format som ska användas för att logga
<pre>
svarskod eller *: Loggformat för svarskoden (eller alla koder som inte 
                  har något annat format specifierat om du använder '*')

loggformatet är normala tecken, och en eller flera av koderna nedan.

\\n \\t \\r    -- Precis som i C, ny rad, tab och carriage return
$char(int)     -- Stoppa in det tecken vars teckenkod är det angivna nummret.
$wchar(int)    -- Stoppa in det tvåocktetstecken vars teckenkod är det 
                  angivna nummret.
$int(int)      -- Stoppa in det fyraocktetstecken vars teckenkod är det 
                  angivna nummret.
$^             -- Stoppa <b>inte</b> in en vagnretur på slutet av
                  varje loggrad
$host          -- DNS namnet för datorn som gjorde förfrågan
$ip_number     -- IP-nummret för datorn som gjorde förfrågan
$bin-ip_number -- IP-nummret för datorn som gjorde förfrågan som
                  binärdata i nätverksoktettordning 

$cern_date     -- Ett datum som det ska vara enligt Cern Common Log
                  file specifikationen 
$bin-date      -- Tiden för requesten som sekunder sedan 1970, binärt
                  i nätverksoktettordning.

$method        -- Förfrågningsmetoden (GET, POST etc)
$resource      -- Resursidentifieraren (filnamnet)
$protocol      -- Protokollet som användes för att fråga efter filen
$response      -- Den skickade svarskoden
$bin-response  -- Den skickade svarskoden som ett binärt ord (2
                  oktetter) i nätverksoktettordning
$length        -- Längden av datan som skickades som svar till klienten
$bin-length    -- Samma sak, men som ett 4 oktetters ord i
                  nätverksoktettordning. 
$request-time  -- Tiden som requeten tog i sekunder
$referer       -- Headern 'referer' från förfrågan eller '-'.
$user_agent    -- Headern 'User-Agent' från förfrågan eller '-'.
$user          -- Den autentifierade användarens namn, eller '-'
$user_id       -- Ett unikt användarid. Tas från kakan RoxenUserID, du 
                  måste slå på kaksättningsfunktionaliteten i de
                  globala inställningarna. '0' används för de
                  förfrågningar som inte har kakan.
</pre>");
	       
  
  defvar("Log", 1, "Logging: Enabled", TYPE_FLAG, "Log requests");
  deflocaledoc("svenska", "Log", "Loggning: På",
	       "Ska roxen logga alla förfrågningar till en logfil?");

  defvar("LogFile", roxen->QUERY(logdirprefix)+
	 short_name(name)+"/Log", 

	 "Logging: Log file", TYPE_FILE, "The log file. "
	 ""
	 "A file name. May be relative to "+getcwd()+"."
	 " Some substitutions will be done:"
	 "<pre>"
	 "%y    Year  (e.g. '1997')\n"
	 "%m    Month (e.g. '08')\n"
	 "%d    Date  (e.g. '10' for the tenth)\n"
	 "%h    Hour  (e.g. '00')\n</pre>"
	 ,0, lambda(){ return !query("Log");});
  deflocaledoc("svenska", "LogFile", 
	       "Loggning: Loggfil",
	       "Filen som roxen loggar i. Filnamnet kan vara relativt "
	       +getcwd()+
#". Du kan använda några kontrollkoder för att få flera loggfiler och
 automatisk loggrotation:
<pre>
%y    År     (t.ex. '1997')
%m    Månad  (t.ex. '08')
%d    Datum  (t.ex. '10')
%h    Timme  (t.ex. '00')
</pre>");

  
  defvar("NoLog", ({ }), 
	 "Logging: No Logging for", TYPE_STRING_LIST|VAR_MORE,
         "Don't log requests from hosts with an IP number which matches any "
	 "of the patterns in this list. This also affects the access counter "
	 "log.\n",0, lambda(){ return !query("Log");});
  deflocaledoc("svenska", "NoLog", 
	       "Loggning: Logga inte för",
#"Logga inte några förfrågningar vars IP-nummer matchar
  något av de mönster som står i den här listan.  Den här variabeln
  påverkar även &lt;accessed&gt; RXML-styrkoden.");
  
  defvar("Domain", roxen->get_domain(), "Domain", TYPE_STRING,
	 "The domainname of the server. The domainname is used "
	 " to generate default URLs, and to gererate email addresses");
  deflocaledoc( "svenska", "Domain", 
		"DNS Domän",
#"Serverns domännamn. Det av en del RXML styrkoder för att generara
epostadresser, samt för att generera skönskvärdet för serverurl variablen.");
		

  defvar("MyWorldLocation", "", "Server URL", TYPE_STRING,
	 "This is the main server URL, where your start page is located.");
  deflocaledoc( "svenska", "MyWorldLocation",
		"Serverns URL",
#"Det här är huvudURLen till din startsida. Den används av många 
  moduler för att bygga upp absoluta URLer från en relativ URL.");

  defvar("URLs", ({"http://*:80/"}), "URLs", TYPE_STRING_LIST|VAR_INITIAL,
         "Bind to these URLs" );

  defvar("InternalLoc", "/_internal/",
	 "Internal module resource mountpoint", 
         TYPE_LOCATION|VAR_MORE|VAR_DEVELOPER,
         "Some modules may want to create links to internal resources.  "
	 "This setting configures an internally handled location that can "
	 "be used for such purposes.  Simply select a location that you are "
	 "not likely to use for regular resources.");

  deflocaledoc("svenska", "InternalLoc", 
	       "Intern modulresursmountpoint",
#"Somliga moduler kan vilja skapa länkar till interna resurser.
  Denna inställning konfigurerar en internt hanterad location som kan användas
  för sådana ändamål.  Välj bara en location som du förmodligen inte kommer
  behöva för vanliga resurser.");

  // throttling-related variables
  defvar("throttle",0,
         "Bandwidth Throttling: Server: Enabled",TYPE_FLAG,
#"If set, per-server bandwidth throttling will be enabled. 
It will allow you to limit the total available bandwidth for 
this Virtual Server.<BR>Bandwidth is assigned using a Token Bucket.
The principle under which it works is: for each byte we send we use a token.
Tokens are added to a repository at a constant rate. When there's not enough,
we can't transmit. When there's too many, they \"spill\" and are lost.");
  //TODO: move this explanation somewhere on the website and just put a link.

  deflocaledoc( "svenska", "throttle", "Bandviddsbegränsning: Servernivå: På",
               #"Om den här variablen är på så kommer bandvisddsbegränsning 
på servernivå att ske. Det gör det möjligt för dig att begränsa den totala
bandvidden som den här virtuella servern använder.
<p>
Bandvidden räknas ut genom att använda en poletthink. Principen som den 
arbetar efter är: För varje byte som sänds så används en polett, poletter
stoppas i hinken i en konstant hastighet. När det inte finns några poletter
så avstännar dataskickande tills en polett blir tillgänglig. När det är för
många poletter i hinken så kommer de nya som kommer in att \"ramla ut\".");


  defvar("throttle_fill_rate",102400,
         "Bandwidth Throttling: Server: Average available bandwidth",
         TYPE_INT,
#"This is the average bandwidth available to this Virtual Server in 
bytes/sec (the bucket \"fill rate\").",
         0,arent_we_throttling_server);

  deflocaledoc( "svenska", "throttle_fill_rate",
                "Bandviddsbegränsning: Servernivå:"
                " Genomsnittlig tillgänglig bandvidd",
                "Det här är den genomsnittliga bandvidden som är tillgänglig "
                "för servern (hastigheten med vilken hinken fylls)");

  defvar("throttle_bucket_depth",1024000,
         "Bandwidth Throttling: Server: Bucket Depth", TYPE_INT,
#"This is the maximum depth of the bucket. After a long enough period
of inactivity, a request will get this many unthrottled bytes of data, before
throttling kicks back in.<br>Set equal to the Fill Rate in order not to allow
any data bursts. This value determines the length of the time over which the
bandwidth is averaged",0,arent_we_throttling_server);

  deflocaledoc( "svenska", "throttle_bucket_depth",
                "Bandviddsbegränsning: Servernivå:"
                " Hinkstorlek",
                "Det här är det maximala antalet poletter som får plats "
                "i hinken. Om det här värdet är lika stort som den "
                "genomsnittliga tillgängliga bandvidden så tillåts inga "
                "tillfälliga datapulser när servern har varit inaktiv ett tag"
                " utan data skickas alltid med max den bandvidden");
  
  defvar("throttle_min_grant",1300,
         "Bandwidth Throttling: Server: Minimum Grant", TYPE_INT,
#"When the bandwidth availability is below this value, connections will
be delayed rather than granted minimal amounts of bandwidth. The purpose
is to avoid sending too small packets (which would increase the IP overhead)",
         0,arent_we_throttling_server);

  deflocaledoc( "svenska", "throttle_min_grant",
                "Bandviddsbegränsning: Servernivå:"
                " Minimalt antal bytes",
#"När det tillgängliga antalet poletter (alltså bytes) är mindre än det här 
värdet så fördröjs förbindelser, alternativet är att skicka små paket, vilket
öker overheaden som kommer till från IP och TCP paketheadrar." );

  defvar("throttle_max_grant",14900,
         "Bandwidth Throttling: Server: Maximum Grant", TYPE_INT,
#"This is the maximum number of bytes assigned in a single request
to a connection. Keeping this number low will share bandwidth more evenly
among the pending connections, but keeping it too low will increase IP
overhead and (marginally) CPU usage. You'll want to set it just a tiny
bit lower than any integer multiple of your network's MTU (typically 1500
for ethernet)",0,arent_we_throttling_server);
         
  deflocaledoc( "svenska", "throttle_max_grant",
                "Bandviddsbegränsning: Servernivå:"
                " Maximalt antal bytes",
#"Det här är det maximala antalet bytes som en förbindelse kan få.
Om det här värdet är lågt så fördelas bandvidden mer jämnt mellan olika
förbindelser, men om det är för lågt så ökar overeden från IP och TCP.
<p>

Sätt det till ett värde som är aningens lägre än en jämn multipel av
ditt nätverks MTU (normala ethernetförbindelser har en MTU på 1500)
" );

  defvar("req_throttle", 0,
         "Bandwidth Throttling: Request: Enabled", TYPE_FLAG,
#"If set, per-request bandwidth throttling will be enabled."
         );

  deflocaledoc( "svenska", "req_throttle",
                "Bandviddsbegränsning: Förbindelsenivå: På",
                "Om på så begränsas bandvidden individuellt på förbindelser"
                );
         
  defvar("req_throttle_min", 1024,
         "Bandwidth Throttling: Request: Minimum guarranteed bandwidth",
         TYPE_INT,
#"The maximum bandwidth each connection (in bytes/sec) can use is determined
combining a number of modules. But doing so can lead to too small 
or even negative bandwidths for particularly unlucky requests. This variable
guarantees a minimum bandwidth for each request",
         0,arent_we_throttling_request);
  

  deflocaledoc( "svenska", "req_throttle_min",
                "Bandviddsbegränsning: Förbindelsenivå: Minimal bandvidd",
#"Den maximala bandvidden som varje förbindelse får bestäms av en kombination 
av de bandviddsbegränsningsmoduler som är adderade i servern. Men ibland
så blir det framräknade värdet väldigt lågt, och en del riktigt otursamma 
förbindelser kan råka hamna på 0 eller mindre bytes per sekund.  <p>Den
här variablen garanterar en vis minimal bandvidd för alla requests"
                );

  defvar("req_throttle_depth_mult", 60.0,
         "Bandwidth Throttling: Request: Bucket Depth Multiplier",
         TYPE_FLOAT,
#"The average bandwidth available for each request will be determined by 
the modules combination. The bucket depth will be determined multiplying
the rate by this factor.",
         0,arent_we_throttling_request);

  deflocaledoc( "svenska", "req_throttle_depth_mult",
                "Bandviddsbegränsning: Förbindelsenivå: Hinkstorlek",
#"Den genomsnittliga bandvidden som varje förbindelse bestäms av 
de adderade bandvidsbegränsningsmodulerna. Hinkstorleken bestäms genom att
multiplicera detta värde med den här faktorn.");


  setvars(retrieve("spider#0", this_object()));

  report_notice("Creating virtual server '"+query_name()+"'\n");

  if (query("throttle"))
  {
    throttler=.throttler();
    throttler->throttle(query("throttle_fill_rate"),
                        query("throttle_bucket_depth"),
                        query("throttle_min_grant"),
                        query("throttle_max_grant"));
  }
}

int arent_we_throttling_server () {
  return !query("throttle");
}
int arent_we_throttling_request() {
  return !query("req_throttle");
}

string _sprintf( )
{
  return "Configuration("+name+")";
}
