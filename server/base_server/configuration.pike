string cvs_version = "$Id: configuration.pike,v 1.136 1998/05/28 00:08:29 grubba Exp $";
#include <module.h>
#include <roxen.h>


#ifdef PROFILE
mapping profile_map = ([]);
#endif

#define CATCH(X)	do { mixed err; if(err = catch{X;}) report_error(describe_backtrace(err)); } while(0)


/* A configuration.. */


inherit "roxenlib";

public string real_file(string file, object id);


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

int defvar(string var, mixed value, string name, int type,
	   string|void doc_str, mixed|void misc,
	   int|function|void not_in_config)
{
  variables[var]                = allocate( VAR_SIZE );
  variables[var][ VAR_VALUE ]        = value;
  variables[var][ VAR_TYPE ]         = type & VAR_TYPE_MASK;
  variables[var][ VAR_DOC_STR ]      = doc_str;
  variables[var][ VAR_NAME ]         = name;
  variables[var][ VAR_MISC ]         = misc;
  
  if((type&~VAR_TYPE_MASK) & VAR_EXPERT)
    variables[var][ VAR_CONFIGURABLE ] = VAR_EXPERT;
  else if((type&~VAR_TYPE_MASK) & VAR_MORE)
    variables[var][ VAR_CONFIGURABLE ] = VAR_MORE;
  else
    if(intp(not_in_config))
      variables[var][ VAR_CONFIGURABLE ]= !not_in_config;
    else if(functionp(not_in_config))
      variables[var][ VAR_CONFIGURABLE ]= not_in_config;
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
  mapping (object:multiset) provider_modules = ([ ]);


  void stop()
  {
    foreach(url_modules, object m)      	 CATCH(m->stop && m->stop());
    foreach(logger_modules, object m)   	 CATCH(m->stop && m->stop());
    foreach(filter_modules, object m)  		 CATCH(m->stop && m->stop());
    foreach(location_modules, object m)		 CATCH(m->stop && m->stop());
    foreach(last_modules, object m)    		 CATCH(m->stop && m->stop());
    foreach(first_modules, object m)    	 CATCH(m->stop && m->stop());
    foreach(indices(provider_modules), object m) CATCH(m->stop && m->stop());
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
#if constant(Gmp.mpz) // Perfect. :-)
  object gmp = Gmp.mpz();
  float mb()
  {
    return (float)(gmp/1024)/1024.0;
  }

  object `+(int i)
  {
    gmp = gmp+i;
    return this_object();
  }

  object `-(int i)
  {
    gmp = gmp-i;
    return this_object();
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
// Protocol specific statistics.
mapping(string:mixed) extra_statistics = ([]);
mapping(string:mixed) misc = ([]);	// Even more statistics.

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

function log_function;

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
private mapping (string:array (object)) provider_module_cache=([]);


// Call stop in all modules.
void stop()
{
  CATCH(parse_module && parse_module->stop && parse_module->stop());
  CATCH(types_module && types_module->stop && types_module->stop());
  CATCH(auth_module && auth_module->stop && auth_module->stop());
  CATCH(dir_module && dir_module->stop && dir_module->stop());
  for(int i=0; i<10; i++) CATCH(pri[i] && pri[i]->stop && pri[i]->stop());
}

public string type_from_filename( string file, int|void to )
{
  mixed tmp;
  object current_configuration;
  string ext=extension(file);
    
  if(!types_fun)
    return to?({ "application/octet-stream", 0 }):"application/octet-stream";

//   while(file[-1] == '/') 
//     file = file[0..strlen(file)-2]; // Security patch? 
  
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

// Return an array with all provider modules that provides "provides".
array (object) get_providers(string provides)
{
  // FIXME: Is there any way to clear this cache?
  // /grubba 1998-05-28
  if(!provider_module_cache[provides])
  { 
    int i;
    provider_module_cache[provides]  = ({ });
    for(i = 9; i >= 0; i--)
    {
      object d;
      foreach(indices(pri[i]->provider_modules), d) 
	if(pri[i]->provider_modules[ d ][ provides ]) 
	  provider_module_cache[provides] += ({ d });
    }
  }
  return provider_module_cache[provides];
}

// Return the first provider module that provides "provides".
object get_provider(string provides)
{
  array (object) prov = get_providers(provides);
  if(sizeof(prov))
    return prov[0];
  return 0;
}

// map the function "fun" over all matching provider modules.
void map_providers(string provides, string fun, mixed ... args)
{
  array (object) prov = get_providers(provides);
  array error;
  foreach(prov, object mod) {
    if(!objectp(mod))
      continue;
    if(functionp(mod[fun])) 
      error = catch(mod[fun](@args));
    if(arrayp(error))
      werror(describe_backtrace(error + ({ "Error in map_providers:"})));
    error = 0;
  }
}

// map the function "fun" over all matching provider modules and
// return the first positive response.
mixed call_provider(string provides, string fun, mixed ... args)
{
  foreach(get_providers(provides), object mod) {
    function f;
    if(objectp(mod) && functionp(f = mod[fun])) {
      mixed error;
      if (arrayp(error = catch {
	mixed ret;
	if (ret = f(@args)) {
	  return(ret);
	}
      })) {
	throw(error + ({ "Error in call_provider:"}));
      }
    }
  }
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

mapping api_module_cache = ([]);
mapping api_functions(object id)
{
  return copy_value(api_module_cache);
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


array location_modules(object id)
{
  if(!location_module_cache)
  {
    int i;
    array new_location_module_cache=({ });
    for(i=9; i>=0; i--)
    {
      object *d, p;
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
  remove_call_out(init_log_file);

  if(log_function)
  {
    destruct(function_object(log_function)); 
    // Free the old one.
  }
  
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
#ifndef THREADS
	object privs = Privs("Opening logfile \""+logfile+"\"");
#endif
	object lf=open( logfile, "wac");
#if efun(chmod)
#if efun(geteuid)
	if(geteuid() != getuid()) catch {chmod(logfile,0666);};
#endif
#endif
	if(!lf) {
	  mkdirhier(logfile);
	  if(!(lf=open( logfile, "wac"))) {
	    report_error("Failed to open logfile. ("+logfile+")\n" +
			 "No logging will take place!\n");
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

public void log(mapping file, object request_id)
{
//    _debug(2);
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
		 "$request-time"
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
		 (sizeof(request_id->referer||({}))?request_id->referer[0]:"-"),
		 http_encode_string(sizeof(request_id->client||({}))?request_id->client*" ":"-"),
		 extract_user(request_id->realauth),
		 (string)request_id->cookies->RoxenUserID,
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

  if(!sent||!received||!hsent)
    return "Fatal error in status(): Bignum object gone.\n";

  tmp = (sent->mb()/(float)(time(1)-roxen->start_time+1));
  res = sprintf("<table><tr align=right><td><b>Sent data:</b></td><td>%.2fMB"
		"</td><td>%.2f Kbit/sec</td>",
		sent->mb(),tmp * 8192.0);
  
  res += sprintf("<td><b>Sent headers:</b></td><td>%.2fMB</td></tr>\n",
		 hsent->mb());
  
  tmp=(((float)requests*(float)600)/
       (float)((time(1)-roxen->start_time)+1));

  res += sprintf("<tr align=right><td><b>Number of requests:</b></td>"
		 "<td>%8d</td><td>%.2f/min</td>"
		 "<td><b>Received data:</b></td><td>%.2fMB</td></tr>\n",
		 requests, (float)tmp/(float)10, received->mb());

  if (!zero_type(misc->ftp_users)) {
    tmp = (((float)misc->ftp_users*(float)600)/
	   (float)((time(1)-roxen->start_time)+1));

    res += sprintf("<tr align=right><td><b>FTP users (total):</b></td>"
		   "<td>%8d</td><td>%.2f/min</td>"
		   "<td><b>FTP users (now):</b></td><td>%d</td></tr>\n",
		   misc->ftp_users, (float)tmp/(float)10, misc->ftp_users_now);
  }
  res += "</table><p>\n\n";

  if ((roxen->configuration_interface()->more_mode) &&
      (extra_statistics->ftp) && (extra_statistics->ftp->commands)) {
    // FTP statistics.
    res += "<b>FTP statistics:</b><br>\n"
      "<ul><table>\n";
    foreach(sort(indices(extra_statistics->ftp->commands)), string cmd) {
      res += sprintf("<tr align=right><td><b>%s</b></td>"
		     "<td align=right>%d</td><td> time%s</td></tr>\n",
		     upper_case(cmd), extra_statistics->ftp->commands[cmd],
		     (extra_statistics->ftp->commands[cmd] == 1)?"":"s");
    }
    res += "</table></ul>\n";
  }
  
  return res;
}

public string *userinfo(string u, object|void id)
{
  if(auth_module) return auth_module->userinfo(u);
  else report_warning(sprintf("userinfo(): No authorization module\n"
			      "%s\n", describe_backtrace(backtrace())));
}

public string *userlist(object|void id)
{
  if(auth_module) return auth_module->userlist();
  else report_warning(sprintf("userlist(): No authorization module\n"
			      "%s\n", describe_backtrace(backtrace())));
}

public string *user_from_uid(int u, object|void id)
{
  if(auth_module)
    return auth_module->user_from_uid(u);
  else report_warning(sprintf("user_from_uid(): No authorization module\n"
			      "%s\n", describe_backtrace(backtrace())));
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
    misc_cache[ a ] = seclevels = ({
      function_object(a)->query_seclevels(),
      function_object(a)->query("_seclvl"),
      function_object(a)->query("_sec_group")
    });

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
	  return(1);
	}
      }
    }
  };

  if (err) {
    report_error(sprintf("Error during module security check:\n"
			 "%s\n", describe_backtrace(err)));
    return(1);
  }

  if (ip_ok == 1) {
    // Bad IP.
    return(1);
  } else {
    // IP OK, or no IP restrictions.
    if (auth_ok == 1) {
      // Bad authentification.
      // Query for authentification.
      return(http_auth_failed(seclevels[2]));
    } else {
      // No auth required, or authentification OK.
      return(0);
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
  extension_module_cache      = ([]);
  file_extension_module_cache = ([]);
  provider_module_cache = ([]);
#ifdef MODULE_LEVEL_SECURITY
  if(misc_cache)
    misc_cache = ([ ]);
#endif
}


string draw_saturation_bar(int hue,int brightness, int where)
{
  object bar=Image.image(30,256);

  for(int i=0;i<128;i++)
  {
    int j = i*2;
    bar->line(0,j,29,j,@hsv_to_rgb(hue,255-j,brightness));
    bar->line(0,j+1,29,j+1,@hsv_to_rgb(hue,255-j,brightness));
  }

  where = 255-where;
  bar->line(0,where,29,where, 255,255,255);

  return bar->togif(255,255,255);
}


// Inspired by the internal-gopher-... thingie, this is the images
// from the configuration interface. :-)
private mapping internal_roxen_image(string from)
{
  sscanf(from, "%s.gif", from);
  sscanf(from, "%s.jpg", from);

  // Disallow "internal-roxen-..", it won't really do much harm, but a list of
  // all files in '..' might be retrieved (that is, the actual directory
  // file was sent to the browser)
  // /internal-roxen-../.. was never possible, since that would be remapped to
  // /..
  from -= ".";

  // changed 970820 by js to allow for jpeg images

  // New idea: Automatically generated colorbar. Used by wizard code...
  int hue,bright,w;
  if(sscanf(from, "%*s:%d,%d,%d", hue, bright,w)==4)
    return http_string_answer(draw_saturation_bar(hue,bright,w),"image/gif");

  if(object f=open("roxen-images/"+from+".gif", "r"))
    return (["file":f,"type":"image/gif"]);
  else
    return (["file":open("roxen-images/"+from+".jpg", "r"),"type":"image/jpeg"]);
}

// The function that actually tries to find the data requested.  All
// modules are mapped, in order, and the first one that returns a
// suitable responce is used.

mapping (mixed:function|int) locks = ([]);

public mapping|int get_file(object id, int|void no_magic);

#ifdef THREADS
// import Thread;

mapping locked = ([]), thread_safe = ([]);

object _lock(object|function f)
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


#define TRACE_ENTER(A,B) do{if(id->misc->trace_enter)id->misc->trace_enter((A),(B));}while(0)
#define TRACE_LEAVE(A) do{if(id->misc->trace_leave)id->misc->trace_leave((A));}while(0)

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
	    res 
	       = "Returned <i><b>redirect</b></i>;<br>&nbsp;&nbsp;&nbsp;to "
	       "<a href="+(m->extra_heads->location)+">"
	       "<font color=darkgreen><tt>"+
	       (m->extra_heads->location)+
	       "</tt></font></a><br>";
	 else
	    res = "Returned redirect, but no location header\n";
	 break;

      case 401:
	 if (m->extra_heads["www-authenticate"])
	    res
	       = "Returned <i><b>authentication failed</b></i>;"
	       "<br>&nbsp;&nbsp;&nbsp;<tt>"+
	       m->extra_heads["www-authenticate"]+"</tt><br>";
	 else
	    res 
	       = "Returned <i><b>authentication failed</b></i>.<br>";
	 break;

      case 200:
	 res
	    = "Returned <i><b>ok</b></i><br>\n";
	 break;
	 
      default:
	 res
	    = "Returned <b><tt>"+m->error+"</tt></b>.<br>\n";
   }

   if (!zero_type(m->len))
      if (m->len<0)
	 res+="No data ";
      else
	 res+=m->len+" bytes ";
   else if (stringp(m->data))
      res+=strlen(m->data)+" bytes";
   else if (objectp(m->file))
      if (catch {
	 array a=m->file->stat();
	 res+=(a[1]-m->file->tell())+" bytes ";
      }) res+="? bytes";

   if (m->data) res+=" (static)";
   else if (m->file) res+="(open file)";

   if (stringp(m->extra_heads["http-content-type"]))
      res+=" of <tt>"+m->type+"</tt>\n";
   else if (stringp(m->type))
      res+=" of <tt>"+m->type+"</tt>\n";

   res+="<br>";

   return res;
}

mapping|int low_get_file(object id, int|void no_magic)
{
#ifdef MODULE_LEVEL_SECURITY
  int slevel;
#endif

#ifdef THREADS
  object key;
#endif
  TRACE_ENTER("Request for "+id->not_query, 0);

  string file=id->not_query;
  string loc;
  function funp;
  mixed tmp, tmp2;
  mapping|object fid;


  if(!no_magic)
  {
#ifndef NO_INTERNAL_HACK 
    // No, this is not beautiful... :) 

    if(sizeof(file) && (file[0] == '/') &&
       sscanf(file, "%*s/internal-%s", loc))
    {
      if(sscanf(loc, "gopher-%[^/]", loc))    // The directory icons.
      {
	TRACE_LEAVE("Magic internal gopher image");
	return internal_gopher_image(loc);
      }
      if(sscanf(loc, "spinner-%[^/]", loc)  // Configuration interface images.
	 ||sscanf(loc, "roxen-%[^/]", loc)) // Try /internal-roxen-power
      {
	TRACE_LEAVE("Magic internal roxen image");
	return internal_roxen_image(loc);
      }
    }
#endif

    if(id->prestate->diract && dir_module)
    {
      LOCK(dir_module);
      TRACE_ENTER("Directory module", dir_module);
      tmp = dir_module->parse_directory(id);
      UNLOCK();
      if(mappingp(tmp)) 
      {
	TRACE_LEAVE("");
	TRACE_LEAVE("Returning data");
	return tmp;
      }
      TRACE_LEAVE("");
    }
  }

  // Well, this just _might_ be somewhat over-optimized, since it is
  // quite unreadable, but, you cannot win them all.. 
#ifdef URL_MODULES
  // Map URL-modules
  foreach(url_modules(id), funp)
  {
    LOCK(funp);
    TRACE_ENTER("URL Module", funp);
    tmp=funp( id, file );
    UNLOCK();
    
    if(mappingp(tmp)) 
    {
      TRACE_LEAVE("");
      TRACE_LEAVE("Returning data");
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
	  TRACE_LEAVE("Too deep recursion");
	  error("Too deep recursion in roxen::get_file() while mapping "
		+file+".\n");
	}
      };
      nest = 0;
      if(err) throw(err);
      TRACE_LEAVE("");
      TRACE_LEAVE("Returned data");
      return tmp;
    }
    TRACE_LEAVE("");
  }
#endif
#ifdef EXTENSION_MODULES  
  if(tmp=extension_modules(loc=extension(file), id))
  {
    foreach(tmp, funp)
    {
      TRACE_ENTER("Extension Module ["+loc+"] ", funp);
      LOCK(funp);
      tmp=funp(loc, id);
      UNLOCK();
      if(tmp)
      {
	if(!objectp(tmp)) 
	{
	  TRACE_LEAVE("Returing data");
	  return tmp;
	}
	fid = tmp;
#ifdef MODULE_LEVEL_SECURITY
	slevel = function_object(funp)->query("_seclvl");
#endif
	TRACE_LEAVE("Retured open filedescriptor."
#ifdef MODULE_LEVEL_SECURITY
		    +(slevel != id->misc->seclevel?
		    ". The security level is now "+slevel:"")
#endif
		    );
#ifdef MODULE_LEVEL_SECURITY
	id->misc->seclevel = slevel;
#endif
	break;
      } else
	TRACE_LEAVE("");
    }
  }
#endif 
 
  foreach(location_modules(id), tmp)
  {
    loc = tmp[0];
    if(!search(file, loc)) 
    {
      TRACE_ENTER("Location Module ["+loc+"] ", tmp[1]);
#ifdef MODULE_LEVEL_SECURITY
      if(tmp2 = check_security(tmp[1], id, slevel))
	if(intp(tmp2))
	{
	  TRACE_LEAVE("Permission to access module denied");
	  continue;
	} else {
	  TRACE_LEAVE("Request denied.");
	  return tmp2;
	}
#endif
      TRACE_ENTER("Calling find_file()...", 0);
      LOCK(tmp[1]);
      fid=tmp[1]( file[ strlen(loc) .. ], id);
      UNLOCK();
      TRACE_LEAVE(sprintf("find_file has returned %O", fid));
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
	  slevel = misc_cache[ tmp[1] ][1];// misc_cache from check_security
#endif
	  if(objectp(fid))
	    TRACE_LEAVE("Returned open file"
#ifdef MODULE_LEVEL_SECURITY
			+(slevel != oslevel?
			  ". The security level is now "+slevel:"")
#endif
			
			+".");
	  else
	    TRACE_LEAVE("Returned directory indicator"
#ifdef MODULE_LEVEL_SECURITY
			+(oslevel != slevel?
			  ". The security level is now "+slevel:"")
#endif
			);
	  break;
	}
      } else
	TRACE_LEAVE("");
    } else if(strlen(loc)-1==strlen(file)) {
      // This one is here to allow accesses to /local, even if 
      // the mountpoint is /local/. It will slow things down, but...
      if(file+"/" == loc) 
      {
	TRACE_ENTER("Automatic redirect to location module", tmp[1]);
	TRACE_LEAVE("Returning data");
	return http_redirect(id->not_query + "/", id);
      }
    }
  }
  
  if(fid == -1)
  {
    if(no_magic)
    {
      TRACE_LEAVE("No magic requested. Returning -1");
      return -1;
    }
    if(dir_module)
    {
      LOCK(dir_module);
      TRACE_ENTER("Directory module", dir_module);
      fid = dir_module->parse_directory(id);
      UNLOCK();
    }
    else
    {
      TRACE_LEAVE("No directory module. Returning 'no such file'");
      return 0;
    }
    if(mappingp(fid)) 
    {
      TRACE_LEAVE("Returned data");
      return (mapping)fid;
    }
  }
  
  // Map the file extensions, but only if there is a file...
  if(objectp(fid)&&
     (tmp=file_extension_modules(loc=extension(id->not_query), id)))
    foreach(tmp, funp)
    {
      TRACE_ENTER("Extension module", funp);
#ifdef MODULE_LEVEL_SECURITY
      if(tmp=check_security(funp, id, slevel))
	if(intp(tmp))
	{
	  TRACE_LEAVE("Permission to access module denied");
	  continue;
	}
	else
	{
	  TRACE_LEAVE("");
	  TRACE_LEAVE("Permission denied");
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
	  TRACE_LEAVE("Returning data");
	  return tmp;
	}
	if(fid)
          destruct(fid);
	TRACE_LEAVE("Returned new open file");
	fid = tmp;
	break;
      } else
	TRACE_LEAVE("");
    }
  
  if(objectp(fid))
  {
    if(stringp(id->extension))
      id->not_query += id->extension;


    TRACE_ENTER("Content-type mapping module", types_module);
    tmp=type_from_filename(id->not_query, 1);
    TRACE_LEAVE(tmp?"Returned type "+tmp[0]+" "+tmp[1]:"Missing");
    if(tmp)
    {
      TRACE_LEAVE("");
      return ([ "file":fid, "type":tmp[0], "encoding":tmp[1] ]);
    }    
    TRACE_LEAVE("");
    return ([ "file":fid, ]);
  }
  if(!fid)
    TRACE_LEAVE("Returning 'no such file'");
  else
    TRACE_LEAVE("Returning data");
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
  {
    TRACE_ENTER("Filter module", tmp);
    if(res2=tmp(res,id))
    {
      if(res && res->file && (res2->file != res->file))
	destruct(res->file);
      TRACE_LEAVE("Rewrote result");
      res=res2;
    } else
      TRACE_LEAVE("");
  }
  return res;
}

public array find_dir(string file, object id)
{
  string loc;
  array dir = ({ }), d, tmp;
  TRACE_ENTER("List directory "+file, 0);
  file=replace(file, "//", "/");
  
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
    TRACE_ENTER("URL module", funp);
    tmp=funp( id, file );
    UNLOCK();

    if(mappingp( tmp ))
    {
      id->not_query=of;
      TRACE_LEAVE("Returned 'no thanks'");
      TRACE_LEAVE("");
      return 0;
    }
    if(objectp( tmp ))
    {
      array err;
      nest ++;
      
      TRACE_LEAVE("Recursing");
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
      TRACE_ENTER("Location module", tmp[1]);
#ifdef MODULE_LEVEL_SECURITY
      if(check_security(tmp[1], id)) {
	TRACE_LEAVE("Permission denied");
	continue;
      }
#endif
      if(d=function_object(tmp[1])->find_dir(file[strlen(loc)..], id))
      {
	TRACE_LEAVE("Got files");
	dir |= d;
      } else
	TRACE_LEAVE("");
    } else if((search(loc, file)==0) && (loc[strlen(file)-1]=='/') &&
	      (loc[0]==loc[-1]) && (loc[-1]=='/') &&
	      (function_object(tmp[1])->stat_file(".", id))) {
      /* loc == file + "/" + subpath + "/"
       * and stat_file(".") returns non-zero.
       */
      TRACE_ENTER("Location module", tmp[1]);
      loc=loc[strlen(file)..];
      sscanf(loc, "%s/", loc);
      dir += ({ loc });
      TRACE_LEAVE("Added module mountpoint");
    }
  }
  if(sizeof(dir))
  {
    TRACE_LEAVE("Returning list of "+sizeof(dir)+" files");
    return dir;
  } 
  TRACE_LEAVE("Returning 'no such directory'");
}

// Stat a virtual file. 

public array stat_file(string file, object id)
{
  string loc;
  array s, tmp;
  TRACE_ENTER("Stat file "+file, 0);
  
  file=replace(file, "//", "/"); // "//" is really "/" here...

#ifdef URL_MODULES
#ifdef THREADS
  object key;
#endif
  // Map URL-modules
  foreach(url_modules(id), function funp)
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
      TRACE_LEAVE("said 'No thanks'");
      return 0;
    }
    if(objectp( tmp ))
    {
      file = id->not_query;

      array err;
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
  foreach(location_modules(id), tmp)
  {
    loc = tmp[0];
    if((file == loc) || ((file+"/")==loc))
    {
      TRACE_ENTER("Location module", tmp[1]);
      TRACE_LEAVE("Exact match");
      TRACE_LEAVE("");
      return ({ 0775, -3, 0, 0, 0, 0, 0, 0, 0, 0, 0 });
    }
    if(!search(file, loc)) 
    {
      TRACE_ENTER("Location module", tmp[1]);
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
	TRACE_LEAVE("Stat ok");
	return s;
      }
      TRACE_LEAVE("");
    }
  }
  TRACE_LEAVE("Returning 'no such file'");
}

class StringFile
{
  string data;
  int offset;

  string read(int nbytes)
  {
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
public array open_file(string fname, string mode, object id)
{
  object oc = id->conf;
  string oq = id->not_query;
  function funp;
  mapping file;
  foreach(oc->first_modules(), funp)
    if(file = funp( id )) 
      break;
    else if(id->conf != oc) 
    {
      id->not_query = fname;
      return open_file(fname, mode,id);
    }
  fname = id->not_query;

  if(search(mode, "R")!=-1) //  raw (as in not parsed..)
  {
    string f;
    mode -= "R";
    if(f = real_file(fname, id))
    {
      werror("opening "+fname+" in raw mode.\n");
      return ({ open(f, mode), ([]) });
    }
//     return ({ 0, (["error":302]) });
  }

  if(mode=="r")
  {
    if(!file)
    {
      file = oc->get_file( id );
      if(!file)
	foreach(oc->last_modules(), funp) if(file = funp( id ))
	  break;
    }

    if(!mappingp(file))
    {
      if(id->misc->error_code)
	file = http_low_answer(id->misc->error_code,"Failed" );
      else if(id->method!="GET"&&id->method != "HEAD"&&id->method!="POST")
	file = http_low_answer(501, "Not implemented.");
      else
	file=http_low_answer(404,replace(parse_rxml(query("ZNoSuchFile"),id),
					 ({"$File", "$Me"}), 
					 ({fname,query("MyWorldLocation")})));

      id->not_query = oq;
      return ({ 0, file });
    }

    if(file->data) 
    {
      file->file = StringFile(file->data);
      m_delete(file, "data");
    } 
    id->not_query = oq;
    return ({ file->file, file });
  }
  id->not_query = oq;
  return ({ 0,(["error":501,"data":"Not implemented"]) });
}


public mapping(string:array(mixed)) find_dir_stat(string file, object id)
{
  string loc;
  mapping(string:array(mixed)) dir = ([]);
  mixed d, tmp;

  file=replace(file, "//", "/");
  
  if(file[0] != '/')
    file = "/" + file;

  // FIXME: Should I append a "/" to file if missing?

  TRACE_ENTER("Request for directory and stat's \""+file+"\"", 0);

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
    TRACE_ENTER("URL Module", funp);
    tmp=funp( id, file );
    UNLOCK();

    if(mappingp( tmp ))
    {
      id->not_query=of;
#ifdef MODULE_DEBUG
      roxen_perror(sprintf("conf->find_dir_stat(\"%s\"): url_module returned mapping:%O\n", 
			   file, tmp));
#endif /* MODULE_DEBUG */
      TRACE_LEAVE("URL Module returned mapping");
      TRACE_LEAVE("Empty directory");
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
	  TRACE_LEAVE("Too deep recursion");
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
      TRACE_LEAVE("URL Module returned object");
      TRACE_LEAVE("Returning it");
      return tmp;	// FIXME: Return 0 instead?
    }
    id->not_query=of;
    TRACE_LEAVE("");
  }
#endif /* URL_MODULES */

  foreach(location_modules(id), tmp)
  {
    loc = tmp[0];

    TRACE_ENTER("Trying location module mounted on "+loc, 0);
    /* Note that only new entries are added. */
    if(!search(file, loc))
    {
      /* file == loc + subpath */
#ifdef MODULE_LEVEL_SECURITY
      if(check_security(tmp[1], id)) continue;
#endif
      object c = function_object(tmp[1]);
      string f = file[strlen(loc)..];
      if (c->find_dir_stat) {
	TRACE_ENTER("Has find_dir_stat()", 0);
	if (d = c->find_dir_stat(f, id)) {
	  TRACE_ENTER("find_dir_stat() returned mapping", 0);
	  dir = d | dir;
	  TRACE_LEAVE("");
	}
	TRACE_LEAVE("");
      } else if(d = c->find_dir(f, id)) {
	TRACE_ENTER("find_dir() returned array", 0);
	dir = mkmapping(d, Array.map(d, lambda(string f, string base,
					 object c, object id) {
				    return(c->stat_file(base + f, id));
				  }, f, c, id)) | dir;
	TRACE_LEAVE("");
      }
    } else if(search(loc, file)==0 && loc[strlen(file)-1]=='/' &&
	      (loc[0]==loc[-1]) && loc[-1]=='/' &&
	      (function_object(tmp[1])->stat_file(".", id))) {
      /* loc == file + "/" + subpath + "/"
       * and stat_file(".") returns non-zero.
       */
      TRACE_ENTER("file is on the path to the mountpoint", 0);
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
      // FIXME: NOTE: Limits filename length to 1000000 bytes.
      //	/grubba 1997-10-03
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

  if(!id->pragma["no-cache"] && !nocache)
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
  
  if (!(< 0, 200, 201, 202, 203 >)[m->error]) return 0;
  
  if(status) return 1;

#ifdef COMPAT
  if(m["string"])  res = m["string"];	// Compability..
  else
#endif
  if(m->data) res = m->data;
  else res="";
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
  cache_set("file:"+id->conf->name, s, res);
  return res;
}

// Is 'what' a file in our virtual filesystem?
public int is_file(string what, object id)
{
  return !!stat_file(what, id);
}

static mapping(string:object) server_ports = ([]);
#define MKPORTKEY(P)	((P)[1]+"://"+(P)[2]+":"+(P)[0])

int ports_changed = 1;
void start(int num)
{
  string server_name = query_name();
  array port;
  int err=0;
  object lf;
  mapping new=([]), o2;

  parse_log_formats();
  init_log_file();

#if 0
  // Doesn't seem to be set correctly.
  //	/grubba 1998-05-18
  if (!ports_changed) {
    return;
  }
#endif /* 0 */

  ports_changed = 0;

  // First find out if we have any new ports.
  mapping(string:array(string)) new_ports = ([]);
  foreach(query("Ports"), port) {
    string key = MKPORTKEY(port);
    if (!server_ports[key]) {
      report_notice(sprintf("%s: New port: %s\n", server_name, key));
      new_ports[key] = port;
    } else {
      // This is needed not to delete old unchanged ports.
      new_ports[key] = 0;
    }
  }

  // Then disable the old ones that are no more.
  foreach(indices(server_ports), string key) {
    if (zero_type(new_ports[key])) {
      report_notice(sprintf("%s: Disabling port: %s...\n", server_name, key));
      object o = server_ports[key];
      m_delete(server_ports, key);
      mixed err;
      if (err = catch{
        destruct(o);
      }) {
        report_warning(sprintf("%s: Error disabling port: %s:\n"
                               "%s\n",
			       server_name, key, describe_backtrace(err)));
      }
      o = 0;    // Be sure that there are no references left...
    }
  }

  // Now we can create the new ports.
  roxen_perror(sprintf("Opening ports for %s... \n", server_name));
  foreach(indices(new_ports), string key) {
    port = new_ports[key];
    if (port) {
      array old = port;
      mixed erro;
      erro = catch {
	if ((< "ssl", "ssleay" >)[port[1]]) {
	  // Obsolete versions of the SSL protocol.
	  report_warning(sprintf("%s: Obsolete SSL protocol-module \"%s\".\n"
				 "Converted to SSL3.\n",
				 server_name, port[1]));
	  // Note: Change in-place.
	  port[1] = "ssl3";
	  // FIXME: Should probably mark node as changed.
	}
	program requestprogram = (program)(getcwd()+"/protocols/"+port[1]);
        function rp;
        array tmp;
        if(!requestprogram) {
          report_error(sprintf("%s: No request program for %s\n",
			       server_name, port[1]));
          continue;
        }
        if(rp = requestprogram()->real_port)
          if(tmp = rp(port, this_object()))
            port = tmp;

	// FIXME: For SSL3 we might need to be root to read our
        // secret files.
        object privs;
        if(port[0] < 1024)
          privs = Privs("Opening listen port below 1024");

	object o;
        if(o=create_listen_socket(port[0], this_object(), port[2],
				  requestprogram, port)) {
          report_notice(sprintf("%s: Opening port: %s\n", server_name, key));
          server_ports[key] = o;
        } else {
          report_error(sprintf("%s: The port %s could not be opened\n",
			       server_name, key));
        }
	if (privs) {
	  destruct(privs);	// Paranoia.
	}
      };
      if (erro) {
        report_error(sprintf("%s: Failed to open port %s:\n"
                             "%s\n", server_name, key,
                             (stringp(erro)?erro:describe_backtrace(erro))));
      }
    }
  }
  if (sizeof(query("Ports")) && !sizeof(server_ports)) {
    report_error("No ports available for "+name+"\n"
		 "Tried:\n"
		 "Port  Protocol   IP-Number \n"
		 "---------------------------\n"
		 + Array.map(query("Ports"),
			     lambda(array p) {
			       return sprintf("%5d %-10s %-20s\n", @p);
			     })*"");
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
  invalidate_cache();
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
      invalidate_cache();
      return 1;
    } else if(mod->copies) {
      int i;
      foreach(indices(mod->copies), i)
      {
	if(mod->copies[i] == o)
	{
	  store(mod->sname+"#"+i, o->query(), 0, this);
	  o->start(2, this);
	  invalidate_cache();
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

#if constant(gethrtime)
  int start_time = gethrtime();
#endif
  if (!module) {
    return 0;
  }

  object me;
  mapping tmp;
  int pr;
  array err;

#ifdef MODULE_DEBUG
  perror("Enabling "+module->name+" # "+id+" ... ");
#endif

  if(module->copies)
  {
    if (err = catch(me = module["program"]())) {
      report_error("Couldn't clone module \"" + module->name + "\"\n" +
		   describe_backtrace(err));
      if (module->copies[id]) {
#ifdef MODULE_DEBUG
	perror("Keeping old copy\n");
#endif
      }
      return(module->copies[id]);
    }
    if(module->copies[id]) {
#ifdef MODULE_DEBUG
      perror("Disabling old copy ... ");
#endif
      if (err = catch{
	module->copies[id]->stop();
      }) {
	report_error("Error during disabling of module \"" + module->name +
		     "\"\n" + describe_backtrace(err));
      }
      destruct(module->copies[id]);
    }
  } else {
    if(objectp(module->master)) {
      me = module->master;
    } else {
      if (err = catch(me = module["program"]())) {
	report_error("Couldn't clone module \"" + module->name + "\"\n" +
		     describe_backtrace(err));
	return(0);
      }
    }
  }

#ifdef MODULE_DEBUG
  //    perror("Initializing ");
#endif
  if (module->type & (MODULE_LOCATION | MODULE_EXTENSION |
		      MODULE_FILE_EXTENSION | MODULE_LOGGER |
		      MODULE_URL | MODULE_LAST | MODULE_PROVIDER |
		      MODULE_FILTER | MODULE_PARSER | MODULE_FIRST))
  {
    me->defvar("_priority", 5, "Priority", TYPE_INT_LIST,
	       "The priority of the module. 9 is highest and 0 is lowest."
	       " Modules with the same priority can be assumed to be "
	       "called in random order", 
	       ({0, 1, 2, 3, 4, 5, 6, 7, 8, 9}));
      
    if(module->type != MODULE_LOGGER &&
       module->type != MODULE_PROVIDER)
    {
      if(!(module->type & MODULE_PROXY))
      {
	me->defvar("_sec_group", "user", "Security: Realm", TYPE_STRING,
		   "The realm to use when requesting password from the "
		   "client. Usually used as an informative message to the "
		   "user.");
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
		   " or auth-module. The default (used when _no_ "
		   "entries are present) is 'allow ip=*', allowing"
		   " everyone to access the module");
	  
      } else {
	me->definvisvar("_seclvl", -10, TYPE_INT); /* A very low one */
	  
	me->defvar("_sec_group", "user", "Proxy Security: Realm", TYPE_STRING,
		   "The realm to use when requesting password from the "
		   "client. Usually used as an informative message to the "
		   "user.");
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
  } else {
    me->defvar("_priority", 0, "", TYPE_INT, "", 0, 1);
  }

  me->defvar("_comment", "", " Comment", TYPE_TEXT_FIELD|VAR_MORE,
	     "An optional comment. This has no effect on the module, it "
	     "is only a text field for comments that the administrator "
	     "might have (why the module are here, etc.)");

  me->defvar("_name", "", " Module name", TYPE_STRING|VAR_MORE,
	     "An optional name. Set to something to remaind you what "
	     "the module really does.");

  me->setvars(retrieve(modname + "#" + id, this));

  if(module->copies)
    module->copies[(int)id] = me;
  else
    module->enabled = me;

  otomod[ me ] = modname;
      
  mixed err;
  if((me->start) && (err = catch{
    me->start(0, this);
  })) {
    report_error("Error while initiating module copy of " +
		 module->name + "\n" + describe_backtrace(err));

    /* Clean up some broken references to this module. */
    m_delete(otomod, me);

    if(module->copies)
      m_delete(module->copies, (int)id);
    else
      m_delete(module, "enabled");
    
    destruct(me);
    
    return 0;
  }
    
  if (err = catch(pr = me->query("_priority"))) {
    report_error("Error while initiating module copy of " +
		 module->name + "\n" + describe_backtrace(err));
    pr = 3;
  }

  api_module_cache |= me->api_functions();

  if(module->type & MODULE_EXTENSION) {
    if (err = catch {
      array arr = me->query_extensions();
      if (arrayp(arr)) {
	string foo;
	foreach( arr, foo )
	  if(pri[pr]->extension_modules[ foo ])
	    pri[pr]->extension_modules[foo] += ({ me });
	  else
	    pri[pr]->extension_modules[foo] = ({ me });
      }
    }) {
      report_error("Error while initiating module copy of " +
		   module->name + "\n" + describe_backtrace(err));
    }
  }	  

  if(module->type & MODULE_FILE_EXTENSION) {
    if (err = catch {
      array arr = me->query_file_extensions();
      if (arrayp(arr)) {
	string foo;
	foreach( me->query_file_extensions(), foo )
	  if(pri[pr]->file_extension_modules[foo] ) 
	    pri[pr]->file_extension_modules[foo]+=({me});
	  else
	    pri[pr]->file_extension_modules[foo]=({me});
      }
    }) {
      report_error("Error while initiating module copy of " +
		   module->name + "\n" + describe_backtrace(err));
    }
  }

  if(module->type & MODULE_PROVIDER) {
    if (err = catch {
      mixed provs = me->query_provides();
      if(stringp(provs))
	provs = (< provs >);
      if(arrayp(provs))
	provs = mkmultiset(provs);
      if (multisetp(provs)) {
	pri[pr]->provider_modules [ me ] = provs;
      }
    }) {
      report_error("Error while initiating module copy of " +
		   module->name + "\n" + describe_backtrace(err));
    }
  }
    
  if(module->type & MODULE_TYPES)
  {
    types_module = me;
    types_fun = me->type_from_extension;
  }
  
  if((module->type & MODULE_MAIN_PARSER))
  {
    parse_module = me;
    if (_toparse_modules) {
      Array.map(_toparse_modules,
		lambda(object o, object me, mapping module)
		{
		  array err;
		  if (err = catch {
		    me->add_parse_module(o);
		  }) {
		    report_error("Error while initiating module copy of " +
				 module->name + "\n" +
				 describe_backtrace(err));
		  }
		}, me, module);
    }
  }

  if(module->type & MODULE_PARSER)
  {
    if(parse_module) {
      if (err = catch {
	parse_module->add_parse_module( me );
      }) {
	report_error("Error while initiating module copy of " +
		     module->name + "\n" + describe_backtrace(err));
      }
    }
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

  if(module->type & MODULE_FIRST) {
    pri[pr]->first_modules += ({ me });
  }

  hooks_for(module->sname+"#"+id, me);
      
  enabled_modules=retrieve("EnabledModules", this);

  if(!enabled_modules[modname+"#"+id])
  {
#ifdef MODULE_DEBUG
    perror("New module...");
#endif
    enabled_modules[modname+"#"+id] = 1;
    store( "EnabledModules", enabled_modules, 1, this);
  }
  invalidate_cache();
#ifdef MODULE_DEBUG
#if constant(gethrtime)
  perror(" Done (%3.3f seconds).\n", (gethrtime()-start_time)/1000000.0);
#else
  perror(" Done.\n");
#endif
#endif
  return me;
}

// Called from the configuration interface.
string check_variable(string name, string value)
{
  switch(name)
  {
   case "Ports":
     ports_changed=1; 
     return 0;
   case "MyWorldLocation":
    if(strlen(value)<7 || value[-1] != '/' ||
       !(sscanf(value,"%*s://%*s/")==2))
      return "The URL should follow this format: protocol://computer[:port]/";
    return 0;
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

   // Pre Spinnerb11p11 
   // No longer supported!
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



// Get the current domain. This is not as easy as one could think.

private string get_domain(int|void l)
{
  array f;
  string t, s;

//  ConfigurationURL is set by the 'install' script.
  if (!l) {
    f = (roxen->QUERY(ConfigurationURL)/"://");
    if (sizeof(f) > 1) {
      t = (replace(f[1], ({ ":", "/" }), ({ "\0", "\0" }))/"\0")[0];
      f = t/".";
      if (sizeof(f) > 1) {
	s = f[1..]*".";
      }
    }
  }
#if efun(gethostbyname)
#if efun(gethostname)
  if(!s) {
    f = gethostbyname(gethostname()); // First try..
    if(f)
      foreach(f, f) {
	if (arrayp(f)) {
	  foreach(f, t) {
	    f = t/".";
	    if ((sizeof(f) > 1) &&
		(replace(t, ({ "0", "1", "2", "3", "4", "5",
				 "6", "7", "8", "9", "." }),
			 ({ "","","","","","","","","","","" })) != "")) {
	      t = f[1..]*".";
	      if(!s || strlen(s) < strlen(t))
		s=t;
	    }
	  }
	}
      }
  }
#endif
#endif
  if(!s) {
    t = Stdio.read_bytes("/etc/resolv.conf");
    if(t) {
      if(!sscanf(t, "domain %s\n", s))
	if(!sscanf(t, "search %s%*[ \t\n]", s))
	  s="nowhere";
    } else {
      s="nowhere";
    }
  }
  if(s && strlen(s))
  {
    if(s[-1] == '.') s=s[..strlen(s)-2];
    if(s[0] == '.') s=s[1..];
  } else {
    s="unknown"; 
  }
  return s;
}

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
    report_error("Failed to disable module\n"
		 "No module by that name: \""+modname+"\".\n");
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

  invalidate_cache();

  if(!me)
  {
    report_error("Failed to Disable "+module->name+" # "+id+"\n");
    return 0;
  }

  if(me->stop) me->stop();

#ifdef MODULE_DEBUG
  perror("Disabling "+module->name+" # "+id+"\n");
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

  if(module->type & MODULE_PROVIDER) {
    for(pr=0; pr<10; pr++)
      m_delete(pri[pr]->provider_modules, me);
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

  if( module->type & MODULE_FIRST ) {
    for(pr=0; pr<10; pr++)
      pri[pr]->first_modules -= ({ me });
  }

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
#if efun(gethrtime)
  int start_time = gethrtime();
#endif
  // It is not thread-safe to use this.
  roxen->current_configuration = this_object();
#ifdef MODULE_DEBUG
  perror("\nLoading " + module_file + "... ");
#endif

  if(prog=cache_lookup("modules", module_file)) {
    err = catch {
      obj = prog(this_object());
    };
  } else {
    string dir;

   _master->set_inhibit_compile_errors("");

    err = catch {
      obj = roxen->load_from_dirs(roxen->QUERY(ModuleDirs), module_file,
				  this_object());
    };

    string errors = (string)_master->errors;

    _master->set_inhibit_compile_errors(0);

    if (sizeof(errors)) {
      report_error(sprintf("While compiling module (\"%s\"):\n%s\n",
			   module_file, errors));
      return(0);
    }

    prog = roxen->last_loaded();
  }

  if (err) {
    report_error("While enabling module (" + module_file + "):\n" +
		 describe_backtrace(err) + "\n");
    return(0);
  }

  if(!obj)
  {
    report_error("Module load failed (" + module_file + ") (not found).\n");
    return 0;
  }

  if (err = catch (module_data = obj->register_module(this_object()))) {
#ifdef MODULE_DEBUG
    perror("FAILED\n" + describe_backtrace( err ));
#endif
    report_error("Module loaded, but register_module() failed (" 
		 + module_file + ").\n"  +
		 describe_backtrace( err ));
    return 0;
  }

  err = "";
  roxen->somemodules[module_file]=
    ({ module_data[1], module_data[2]+"<p><i>"+
       replace(obj->file_name_and_stuff(),"0<br>", module_file+"<br>")
       +"</i>", module_data[0] });
  if (!arrayp( module_data ))
    err = "Register_module didn't return an array.\n";
  else
    switch (sizeof( module_data ))
    {
     case 5:
      foo=module_data[4];
      module_data=module_data[0..3];
     case 4:
      if (module_data[3] && !arrayp( module_data[3] ))
	err = "The fourth element of the array register_module returned "
	  "(extra_buttons) wasn't an array.\n" + err;
     case 3:
      if (!stringp( module_data[2] ))
	err = "The third element of the array register_module returned "
	  "(documentation) wasn't a string.\n" + err;
      if (!stringp( module_data[1] ))
	err = "The second element of the array register_module returned "
	  "(name) wasn't a string.\n" + err;
      if (!intp( module_data[0] ))
	err = "The first element of the array register_module returned "
	  "(type) wasn't an integer.\n" + err;
      break;

     default:
      err = "The array register_module returned was too small/large. "
	"It should have been three or four elements (type, name, "
	"documentation and extra buttons (optional))\n";
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
#if efun(gethrtime)
  perror(" Done (%3.3f seconds).\n", (gethrtime()-start_time)/1000000.0);
#else
  perror(" Done.\n");
#endif
#endif
  cache_set("modules", module_file, modules[module_file]["program"]);
// ??  invalidate_cache();

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
  return(server_ports[MKPORTKEY(prt)] != 0);
}


string desc()
{
  string res="";
  array (string|int) port;

  if(!sizeof(QUERY(Ports)))
  {
/*    array ips = roxen->configuration_interface()->ip_number_list;*/
/*    if(!ips) roxen->configuration_interface()->init_ip_list;*/
/*    ips = roxen->configuration_interface()->ip_number_list;*/
/*    foreach(ips||({}), string ip)*/
/*    {*/
      
/*    }*/

    array handlers = ({});
    foreach(roxen->configurations, object c)
      if(c->modules["ip-less_hosts"])
	handlers+=({({http_encode_string("/Configurations/"+c->name),
			strlen(c->query("name"))?c->query("name"):c->name})});

    
    if(sizeof(handlers)==1)
    {
      res = "This server is handled by the ports in <a href=\""+handlers[0][0]+
	"\">"+handlers[0][1]+"</a><br>\n";
    } else if(sizeof(handlers)) {
      res = "This server is handled by the ports in any of the following servers:<br>";
      foreach(handlers, array h)
	res += "<a href=\""+h[0]+"\">"+h[1]+"</a><br>\n";
    } else
      res=("There are no ports configured, and no virtual server seems "
	   "to have support for ip-less virtual hosting enabled<br>\n");
  }
  
  foreach(QUERY(Ports), port)
  {
    string prt;
    
    switch(port[1][0..2])
    {
    case "ssl":
      prt = "https://";
      break;
    case "ftp":
      prt = "ftp://";
      break;
      
    default:
      prt = port[1]+"://";
    }
    if(port[2] && port[2]!="ANY")
      prt += port[2];
    else
#if efun(gethostname)
      prt += (gethostname()/".")[0] + "." + QUERY(Domain);
#else
    ;
#endif
    prt += ":"+port[0]+"/";
    if(port_open( port ))
      res += "<font color=darkblue><b>Open:</b></font> <a target=server_view href=\""+prt+"\">"+prt+"</a> \n<br>";
    else
      res += "<font color=red><b>Not open:</b> <a target=server_view href=\""+
	prt+"\">"+prt+"</a></font> <br>\n";
  }
  return (res+"<font color=darkgreen>Server URL:</font> <a target=server_view "
	  "href=\""+query("MyWorldLocation")+"\">"+query("MyWorldLocation")+"</a><p>");
}


// BEGIN SQL

mapping(string:string) sql_urls = ([]);

object sql_connect(string db)
{
  if (sql_urls[db]) {
    return(Sql.sql(sql_urls[db]));
  } else {
    return(Sql.sql(db));
  }
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
#if efun(gethrtime)
  int start_time = gethrtime();
#endif
  array modules_to_process=sort(indices(retrieve("EnabledModules",this)));
  string tmp_string;
  perror("\nEnabling all modules for "+query_name()+"... \n");

#if constant(_compiler_trace)
  // _compiler_trace(1);
#endif /* !constant(_compiler_trace) */
  
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
#if efun(gethrtime)
  perror("\nAll modules for %s enabled in %4.3f seconds\n\n", query_name(),
	 (gethrtime()-start_time)/1000000.0);
#endif
}

void create(string config)
{
  roxen->current_configuration = this;
  name=config;

  perror("Creating virtual server '"+config+"'\n");

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


  defvar("comment", "", "Virtual server comment",
	 TYPE_TEXT_FIELD|VAR_MORE,
	 "This text will be visible in the configuration interface, it "
	 " can be quite useful to use as a memory helper.");
  
  defvar("name", "", "Virtual server name",
	 TYPE_STRING|VAR_MORE,
	 "This is the name that will be used in the configuration "
	 "interface. If this is left empty, the actual name of the "
	 "virtual server will be used");
  
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
	 "</pre>", 0, log_is_not_enabled);
  
  defvar("Log", 1, "Logging: Enabled", TYPE_FLAG, "Log requests");
  
  defvar("LogFile", roxen->QUERY(logdirprefix)+
	 short_name(name)+"/Log", 

	 "Logging: Log file", TYPE_FILE, "The log file. "
	 ""
	 "A file name. May be relative to "+getcwd()+"."
	 " Some substitutions will be done:"
	 "<pre>"
	 "%y    Year  (i.e. '1997')\n"
	 "%m    Month (i.e. '08')\n"
	 "%d    Date  (i.e. '10' for the tenth)\n"
	 "%h    Hour  (i.e. '00')\n</pre>"
	 ,0, log_is_not_enabled);
  
  defvar("NoLog", ({ }), 
	 "Logging: No Logging for", TYPE_STRING_LIST|VAR_MORE,
         "Don't log requests from hosts with an IP number which matches any "
	 "of the patterns in this list. This also affects the access counter "
	 "log.\n",0, log_is_not_enabled);
  
  defvar("Domain", get_domain(), "Domain", TYPE_STRING, 
	 "Your domainname, should be set automatically, if not, "
	 "enter the correct domain name here, and send a bug report to "
	 "<a href=\"mailto:roxen-bugs@idonex.se\">roxen-bugs@idonex.se"
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
	 TYPE_TEXT_FIELD|VAR_MORE,
	 "FTP Welcome answer; transmitted to new FTP connections if the file "
	 "<i>/welcome.msg</i> doesn't exist.\n");
  
  defvar("named_ftp", 0, "Allow named FTP", TYPE_FLAG|VAR_MORE,
	 "Allow ftp to normal user-accounts (requires auth-module).\n");

  defvar("anonymous_ftp", 1, "Allow anonymous FTP", TYPE_FLAG|VAR_MORE,
	 "Allows anonymous ftp.\n");

  defvar("guest_ftp", 0, "Allow FTP guest users", TYPE_FLAG|VAR_MORE,
	 "Allows FTP guest users.\n");

  defvar("ftp_user_session_limit", 0,
	 "FTP user session limit", TYPE_INT|VAR_MORE,
	 "Limit of concurrent sessions a FTP user may have. 0 = unlimited.\n");

  defvar("shells", "/etc/shells", "Shell database", TYPE_FILE|VAR_MORE,
	 "File which contains a list of all valid shells.\n"
	 "Usually /etc/shells\n");

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
}



