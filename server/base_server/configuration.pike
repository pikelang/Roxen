string cvs_version = "$Id: configuration.pike,v 1.10.2.1 1997/03/09 13:31:11 grubba Exp $";
#include <module.h>
/* A configuration.. */

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

void create(string n) { name=n; }

class Bignum {
  object this = this_object();
#if efun(Mpz) && 0
  inherit Mpz;
  float mb()
  {
    return (float)this/(1024.0*1024.0);
  }
#else
  program This = object_program(this);
  int msb;
  int lsb=-0x7ffffffe;

  object `-(int i);
  object `+(int i)
  {
    if(!i) return this;
    if(i<0) return `-(-i);
    object res = This(lsb+i,msb,2);
    if(res->lsb < lsb) res->msb++;
    return res;
  }

  object `-(int i)
  {
    if(!i) return this;
    if(i<0) return `+(-i);
    object res = This(lsb-i,msb,2);
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
  if(roxenp()->misc_cache)
    roxenp()->misc_cache = ([ ]);
#endif
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



// Save this configuration. If all is included, save all configuration
// global variables as well, otherwise only all module variables.
void save(int|void all)
{
  mapping mod;
  object oc;
  oc = roxenp()->current_configuration;
  roxenp()->current_configuration=this_object();
  
  if(all)
  {
    roxenp()->store("spider.lpc#0", variables, 0);
    roxenp()->start(2);
  }
  
  foreach(values(modules), mod)
  {
    if(mod->enabled)
    {
      roxenp()->store(mod->sname+"#0", mod->master->query(), 0);
      mod->enabled->start(2);
    } else if(mod->copies) {
      int i;
      foreach(indices(mod->copies), i)
      {
	roxenp()->store(mod->sname+"#"+i, mod->copies[i]->query(), 0);
	mod->copies[i]->start(2);
      }
    }
  }
  unvalidate_cache();
  roxenp()->current_configuration = oc;
}

// Save all variables in _one_ module.
int save_one( object o )
{
  object oc;
  mapping mod;
  oc = roxenp()->current_configuration;
  roxenp()->current_configuration=this_object();
  if(!o) 
  {
    roxenp()->store("spider#0", variables, 0);
    roxenp()->start(2);
    roxenp()->current_configuration = oc;
    return 1;
  }
  foreach(values(modules), mod)
  {
    if( mod->enabled == o)
    {
      roxenp()->store(mod->sname+"#0", o->query(), 0);
      o->start(2);
      unvalidate_cache();
      roxenp()->current_configuration = oc;
      return 1;
    } else if(mod->copies) {
      int i;
      foreach(indices(mod->copies), i)
      {
	if(mod->copies[i] == o)
	{
	  roxenp()->store(mod->sname+"#"+i, o->query(), 0);
	  o->start(2);
	  unvalidate_cache();
	  roxenp()->current_configuration = oc;
	  return 1;
	}
      }
    }
  }
  roxenp()->current_configuration = oc;
}


mapping (object:array) open_ports = ([]);


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
    
    switch(port[1])
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






