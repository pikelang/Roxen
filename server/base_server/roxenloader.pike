string cvs_version = "$Id: roxenloader.pike,v 1.3 1996/11/27 14:10:28 per Exp $";
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
  perror("Roxen version "+roxen->version+"\n");
  nwrite = roxen->nwrite;
}

object|void open(string filename, string mode)
{
  object o;
  o=File();
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

void main(mixed ... args)
{
  perror("Roxen loader version "+cvs_version+"\n");
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
