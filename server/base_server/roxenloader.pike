string cvs_version = "$Id: roxenloader.pike,v 1.6.2.1 1997/03/02 19:16:09 grubba Exp $";

import files;
import spider;

#define error(X) do{array Y=backtrace();throw(({(X),Y[..sizeof(Y)-2]}));}while(0)

#include <simulate.h>
#include <roxen.h>
#include <stdio.h>  // load "perror" in this before "roxen.pre.pike"'s perror
#include <roxen.h>  

object roxen;
function nwrite;

#include <module.h>

#if efun(syslog)
# include <syslog.h>
int use_syslog, loggingfield;
#endif

mixed query(string arg) 
{
  if(!roxen)
    error("No roxen object!\n");
  if(!roxen->variables)
    error("No roxen variables!\n");
  if(!roxen->variables[arg])
    error("Unknown variable: "+arg+"\n");
  return roxen->variables[arg][VAR_VALUE];
}

// used for debug messages. Sent to the configuration interface and STDERR.
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
  openlog(query("LogNA"), (query("LogSP")*LOG_PID)|(query("LogCO")*LOG_CONS),
	  res); 
#endif
}

void report_debug(string message)
{
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_DEBUG))
    syslog(LOG_DEBUG, replace(message, "%", "%%"));
  else
#endif
    nwrite("Debug:\n" + message);
}


void report_error(string message)
{
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_ERR))
    syslog(LOG_ERR, replace(message, "%", "%%"));
  else
#endif
    nwrite("Error: "+message);
}

void report_fatal(string message)
{
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_EMERG))
    syslog(LOG_EMERG, replace(message, "%", "%%"));
  else
#endif
    nwrite("Fatal error: "+message);
}
 


static private void initiate_cache()
{
  object cache;
  cache=((program)"cache")();
  add_constant("cache_set", cache->cache_set);
  add_constant("cache_lookup", cache->cache_lookup);
  add_constant("cache_remove", cache->cache_remove);
  add_constant("cache", cache);
}


void load_roxen()
{
  roxen = ((program)"roxen")();
  perror("Roxen version "+roxen->cvs_version+"\n");
  nwrite = roxen->nwrite;
}

object|void open(string filename, string mode)
{
  object o;
  o=file();
  if(o->open(filename, mode))
  {
    mark_fd(o->query_fd(), filename+" (mode: "+mode+")");
    return o;
  }
  destruct(o);
}


void mkdirhier(string from)
{
  string a, b;
  array f;

  f=(from/"/");
  b="";

  foreach(f[0..sizeof(f)-2], a)
  {
    mkdir(b+a);
    b+=a+"/";
  }
}

string make_path(string ... from)
{
  return Array.map(from, lambda(string a, string b) {
    return (a[0]=='/')?combine_path("/",a):combine_path(b,a);
  }, getcwd())*":";
}

void main(mixed ... args)
{
  perror("Roxen loader version "+cvs_version+"\n");

  string path = make_path("base_server", "etc/include", ".", getcwd());

  master()->putenv("PIKE_INCLUDE_PATH", path);
  master()->pike_include_path = path/":";

  object mm=((program)"etc/master.pike")();
  replace_master(mm);
#if 0
  mm->putenv("PIKE_INCLUDE_PATH", path);
  mm->pike_include_path = path/":";
  mm->pike_library_path = master()->pike_library_path;
#endif /* 0 */

  add_constant("error", lambda(string s){error(s);});

  add_constant("roxenp", lambda() { return roxen; });
  add_constant("report_debug", report_debug);
  add_constant("report_error", report_error);
  add_constant("report_fatal", report_fatal);
  add_constant("init_logger", init_logger);

  add_constant("open", open);
  add_constant("mkdirhier", mkdirhier);

  initiate_cache();
  load_roxen();
  return roxen->main(@args);
}
  
