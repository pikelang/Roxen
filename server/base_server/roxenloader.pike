// This file is part of Roxen WebServer.
// Copyright � 1996 - 2004, Roxen IS.
//
// Roxen bootstrap program.

// $Id: roxenloader.pike,v 1.366 2005/11/14 10:06:13 grubba Exp $

#define LocaleString Locale.DeferredLocale|string

mixed x = Calendar.Timezone; // #"!�&"�%/"&#�!%#�&#

// #pragma strict_types

// Sets up the roxen environment. Including custom functions like spawne().

#include <stat.h>
#include <config.h>
//
// NOTE:
//	This file uses replace_master(). This implies that the
//	master() efun when used in this file will return the old
//	master and not the new one.
//
private static __builtin.__master new_master;

constant s = spider; // compatibility

int      remove_dumped;
string   configuration_dir;

#define werror roxen_perror

constant cvs_version="$Id: roxenloader.pike,v 1.366 2005/11/14 10:06:13 grubba Exp $";

int pid = getpid();
Stdio.File stderr = Stdio.File("stderr");

#if !constant(uname)
#ifdef __NT__
mapping uname()
{
  return ([ 
	   "machine":"NT",
	   "release":"unknown",
	   "sysname":"NT",
	   "nodename":gethostname(),
	   "version":"unknown",
	   ]);
}
#else
mapping uname()
{
  return ([ 
	   "machine":"unknown",
	   "release":"unknown",
	   "sysname":"unknown",
	   "nodename":gethostname(),
	   "version":"unknown",
	   ]);
}
#endif
#endif

mapping(int:string) pwn=([]);
string pw_name(int uid)
{
#if !constant(getpwuid)
  return "uid #"+uid;
#else
  if(pwn[uid]) return pwn[uid];
  return pwn[uid]=([array(string)]getpwuid(uid)||((""+uid)/":"))[0];
#endif
}

#if !constant(getppid)
int getppid() {   return -1; }
#endif

#if efun(syslog)
#define  LOG_CONS   (1<<0)
#define  LOG_NDELAY (1<<1)
#define  LOG_PERROR (1<<2)
#define  LOG_PID    (1<<3)

#define  LOG_AUTH    (1<<0)
#define  LOG_AUTHPRIV (1<<1)
#define  LOG_CRON    (1<<2)
#define  LOG_DAEMON  (1<<3)
#define  LOG_KERN    (1<<4)
#define  LOG_LOCAL  (1<<5)
#define  LOG_LOCAL1  (1<<6)
#define  LOG_LOCAL2  (1<<7)
#define  LOG_LOCAL3  (1<<8)
#define  LOG_LOCAL4  (1<<9)
#define  LOG_LOCAL5  (1<<10)
#define  LOG_LOCAL6  (1<<11)
#define  LOG_LOCAL7  (1<<12)
#define  LOG_LPR     (1<<13)
#define  LOG_MAIL    (1<<14)
#define  LOG_NEWS    (1<<15)
#define  LOG_SYSLOG  (1<<16)
#define  LOG_USER    (1<<17)
#define  LOG_UUCP    (1<<18)

#define  LOG_EMERG   (1<<0)
#define  LOG_ALERT   (1<<1)
#define  LOG_CRIT    (1<<2)
#define  LOG_ERR     (1<<3)
#define  LOG_WARNING (1<<4)
#define  LOG_NOTICE  (1<<5)
#define  LOG_INFO    (1<<6)
#define  LOG_DEBUG   (1<<7)
int use_syslog, loggingfield;
#endif


/*
 * Some efuns used by Roxen
 */

static string last_id, last_from;
string get_cvs_id(string from)
{
  if(last_from == from) return last_id;
  last_from=from;
  catch {
    object f = open(from,"r");
    string id;
    id = f->read(1024);
    if(sscanf(id, "%*s$"+"Id: %*s,v %s ", id) == 3)
      return last_id=" (version "+id+")";
  };
  last_id = "";
  return "";
}

void add_cvs_ids(mixed to)
{
  if (arrayp(to) && sizeof(to) >= 2 && !objectp(to[1]) && arrayp(to[1]) ||
      objectp(to) && to->is_generic_error)
    to = to[1];
  else if (!arrayp(to)) return;
  foreach(to, mixed q)
    if(arrayp(q) && sizeof(q) && stringp(q[0])) {
      string id = get_cvs_id(q[0]);
      catch (q[0] += id);
    }
}

string describe_backtrace (mixed err, void|int linewidth)
{
  add_cvs_ids (err);
  return predef::describe_backtrace (err, 999999);
}

static int(0..5) last_was_change;
int(2..2147483647) roxen_started = [int(2..2147483647)]time();
float roxen_started_flt = time(time());
string short_time()
{
  if( last_was_change>0 )
    switch( last_was_change-- )
    {
     default:
       return "          : ";
     case 5:
       float up = time(roxen_started)-roxen_started_flt;
       if( up > 3600 )
       {
         return sprintf( "%2dd%2dh%2dm : ",
                       (int)up/86400,
                       (((int)up/3600)%24),
                       ((int)up/60)%60);
       }
       return sprintf( "%2dm%4.1fs  : ",((int)up/60)%60, up%60 );
    }
  mapping l = localtime( time( ) );
  string ct =  sprintf("%2d:%02d:%02d  : ", l->hour, l->min, l->sec );
  last_was_change=5;
  return ct;
}

string possibly_encode( string what )
{
  if( catch {
    if( String.width( what ) > 8 )
      return string_to_utf8( what );
  } )
    return string_to_utf8( what );
  return what;
}

//! @decl void werror(string format, mixed ... args)
//! @appears werror

//! @decl void roxen_perror(string format, mixed ... args)
//! @appears roxen_perror

static int last_was_nl;
// Used to print error/debug messages
void roxen_perror(string format, mixed ... args)
{
  if(sizeof(args))
    format=sprintf(format,@args);

  // "Delayed newlines": End a message with \b and start the next one
  // with \b to make them continue on the same line. If another
  // message gets in between, it still gets written on a new line.
  int delayed_nl;
  if (format == "\b") format = "";
  else if (sizeof (format)) {
    if (format[0] == '\b') {
      if (last_was_nl == -1) last_was_nl = 0;
      format = format[1..];
    }
    if (format[-1] == '\b') {
      delayed_nl = 1;
      format = format[..sizeof(format)-2];
    }
  }

  if (!last_was_nl && (format != "")) {
    // Continuation line.
    int i = search(format, "\n");

    if (i == -1) {
      stderr->write(possibly_encode(format));
      format = "";
      if (delayed_nl) last_was_nl = -1;
    } else {
      stderr->write(possibly_encode(format[..i]));
      format = format[i+1..];
      last_was_nl = 1;
    }
  }

  if (sizeof(format)) {
#if efun(syslog)
    if(use_syslog && (loggingfield&LOG_DEBUG))
      foreach(format/"\n"-({""}), string message)
	syslog(LOG_DEBUG, replace(message+"\n", "%", "%%"));
#endif

    if (last_was_nl == -1) stderr->write("\n");
    last_was_nl = format[-1] == '\n';

#ifdef RUN_SELF_TEST
    stderr->write( possibly_encode( format ) );
#else
    array(string) a = format/"\n";
    int i;

    a = map( a, possibly_encode );

    for(i=0; i < sizeof(a)-1; i++) {
      stderr->write(short_time() + a[i] + "\n");
    }
    if (!last_was_nl) {
      stderr->write(short_time() + a[-1]);
    }
#endif
  }

  if (delayed_nl) last_was_nl = -1;
}

//! @appears mkdirhier
//! Make a directory hierachy
int mkdirhier(string from, int|void mode)
{
  int r = 1;
  from = roxen_path( from + "x" ); // "x" keeps roxen_path from stripping trailing '/'.
  array(string) f=(from/"/");
  string b="";


  foreach(f[0..sizeof(f)-2], string a)
  {
    if (query_num_arg() > 1) {
      mkdir(b+a, mode);
#if constant(chmod)
      Stdio.Stat stat = file_stat (b + a, 1);
      if (stat && stat[0] & ~mode)
	// Race here. Not much we can do about it at this point. :/
	catch (chmod (b+a, [int]stat[0] & mode));
#endif
    }
    else mkdir(b+a);
    b+=a+"/";
  }
  if(!r)
    return (file_stat(from)||({0,0}))[1] == -2;
  return 1;
}

// Roxen itself

//! @ignore
class Roxen {
  mixed query(string);
  void nwrite(string, int|void, int|void, void|mixed ...);
}
//! @endignore

Roxen roxen;

// The function used to report notices/debug/errors etc.
function(string, int|void, int|void, void|mixed ...:void) nwrite;

// Standin for nwrite until roxen is loaded.
void early_nwrite(string s, int|void perr, int|void errtype,
		  object|void mod, object|void conf)
{
  report_debug(s);
}

/*
 * Code to get global configuration variable values from Roxen.
 */

mixed query(string arg)
{
  if(!roxen)
    error("No roxen object!\n");
  return roxen->query( arg );
}

// used for debug messages. Sent to the administration interface and STDERR.
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
  openlog([string]query("LogNA"),
	  ([int]query("LogSP")*LOG_PID)|([int]query("LogCO")*LOG_CONS),
          res);
#endif
}

void report_debug(string message, mixed ... foo)
//! @appears report_debug
//! Print a debug message in the server's debug log.
//! Shares argument prototype with @[sprintf()].
{
  if( sizeof( foo ) )
    message = sprintf((string)message, @foo );
  roxen_perror( message );
}


array(object) find_module_and_conf_for_log( array(array) q )
{
  object conf, mod;
  for( int i = sizeof (q); i-- > 0; )
  {
    if(!functionp([function]q[i][2]))
      continue;
    object o = function_object( [function]q[i][2] );
    if(!o) 
      continue;
    if( o->is_module ) {
      if( !mod ) mod = o;
      if (!conf && functionp (mod->my_configuration))
	conf = ([function(void:object)]mod->my_configuration)();
    }
    if( o->is_configuration ) {
      if( !conf ) conf = o;
    }
    if( conf )
      break;
  }
  return ({ mod,conf });
}


#define MC @find_module_and_conf_for_log(backtrace())

void report_warning(LocaleString message, mixed ... foo)
//! @appears report_warning
//! Report a warning message, that will show up in the server's debug log and
//! in the event logs, along with the yellow exclamation mark warning sign.
//! Shares argument prototype with @[sprintf()].
{
  if( sizeof( foo ) ) message = sprintf((string)message, @foo );
  nwrite([string]message,0,2,MC);
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_WARNING))
    foreach([string]message/"\n", message)
      syslog(LOG_WARNING, replace([string]message+"\n", "%", "%%"));
#endif
}

void report_notice(LocaleString message, mixed ... foo)
//! @appears report_notice
//! Report a status message of some sort for the server's debug log and event
//! logs, along with the blue informational notification sign. Shares argument
//! prototype with @[sprintf()].
{
  if( sizeof( foo ) ) message = sprintf((string)message, @foo );
  nwrite([string]message,0,1,MC);
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_NOTICE))
    foreach([string]message/"\n", message)
      syslog(LOG_NOTICE, replace([string]message+"\n", "%", "%%"));
#endif
}

void report_error(LocaleString message, mixed ... foo)
//! @appears report_error
//! Report an error message, that will show up in the server's debug log and
//! in the event logs, along with the red exclamation mark sign. Shares
//! argument prototype with @[sprintf()].
{
  if( sizeof( foo ) ) message = sprintf((string)message, @foo );
  nwrite([string]message,0,3,MC);
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_ERR))
    foreach([string]message/"\n", message)
      syslog(LOG_ERR, replace([string]message+"\n", "%", "%%"));
#endif
}

void report_fatal(string message, mixed ... foo)
//! @appears report_fatal
//! Print a fatal error message.
{
  if( sizeof( foo ) ) message = sprintf((string)message, @foo );
  nwrite(message,0,3,MC);
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_EMERG))
    foreach(message/"\n", message)
      syslog(LOG_EMERG, replace(message+"\n", "%", "%%"));
#endif
}

static mapping(string:int) sparsely_dont_log = (garb_sparsely_dont_log(), ([]));

static void garb_sparsely_dont_log()
{
  if (sparsely_dont_log && sizeof (sparsely_dont_log)) {
    int now = time (1);
    foreach (indices (sparsely_dont_log), string msg)
      if (sparsely_dont_log[msg] < now) m_delete (sparsely_dont_log, msg);
  }
  call_out (garb_sparsely_dont_log, 10*60);
}

void report_warning_sparsely (LocaleString message, mixed ... args)
//! @appears report_warning_sparsely
//! Like @[report_warning], but doesn't repeat the same message if
//! it's been logged in the last ten minutes. Useful in situations
//! where an error can cause a warning message to be logged rapidly.
{
  if( sizeof( args ) ) message = sprintf((string)message, @args );
  int now = time (1);
  if (sparsely_dont_log[message] >= now) return;
  sparsely_dont_log[message] = now + 10*60;
  nwrite([string]message,0,2,MC);
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_WARNING))
    foreach([string]message/"\n", message)
      syslog(LOG_WARNING, replace([string]message+"\n", "%", "%%"));
#endif
}

void report_error_sparsely (LocaleString message, mixed... args)
//! @appears report_error_sparsely
//! Like @[report_error], but doesn't repeat the same message if it's
//! been logged in the last ten minutes. Useful in situations where an
//! error can cause an error message to be logged rapidly.
{
  if( sizeof( args ) ) message = sprintf((string)message, @args );
  int now = time (1);
  if (sparsely_dont_log[message] >= now - 10*60*60) return;
  sparsely_dont_log[message] = now;
  nwrite([string]message,0,3,MC);
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_ERR))
    foreach([string]message/"\n", message)
      syslog(LOG_ERR, replace([string]message+"\n", "%", "%%"));
#endif
}

//! @appears popen
//! Starts the specified process and returns a string
//! with the result. Mostly a compatibility functions, uses
//! Process.create_process
string popen(string s, void|mapping env, int|void uid, int|void gid)
{
  Stdio.File f = Stdio.File(), p = f->pipe(Stdio.PROP_IPC);

  if(!p) error("Popen failed. (could not create pipe)\n");

  mapping(string:mixed) opts = ([
    "env": (env || getenv()),
    "stdout":p,
  ]);

  if (!getuid())
  {
    switch(query_num_arg())
    {
    case 4:
      opts->gid = gid;
    case 3:
      opts->uid = uid;
      break;
    }
  }
  opts->noinitgroups = 1;
#if defined(__NT__) || defined(__amigaos__)
  Process.Process proc = Process.Process(Process.split_quoted_string(s), opts);
#else /* !__NT||__amigaos__ */
  Process.Process proc = Process.Process(({"/bin/sh", "-c", s}), opts);
#endif /* __NT__ || __amigaos__ */
  p->close();

  if( proc )
  {
    string t = f->read();
    f->close();
    destruct(f);
    return t;
  }
  f->close();
  destruct(f);
  return 0;
}

//! @appears spawne
//! Create a process
Process.Process spawne(string s, array(string) args, mapping|array env,
		       Stdio.File stdin, Stdio.File stdout, Stdio.File stderr,
		       void|string wd, void|array(int) uid)
{
  int u, g;
  if(uid) { u = uid[0]; g = uid[1]; }
#if efun(geteuid)
  else { u=geteuid(); g=getegid(); }
#endif
  return Process.create_process(({s}) + (args || ({})), ([
    "toggle_uid":1,
    "stdin":stdin,
    "stdout":stdout,
    "stderr":stderr,
    "cwd":wd,
    "env":env,
    "uid":u,
    "gid":g,
  ]));
}

//! @appears spawn_pike
//! Start a new Pike process with the same configuration as the current one
Process.Process spawn_pike(array(string) args, void|string wd,
			   Stdio.File|void stdin, Stdio.File|void stdout,
			   Stdio.File|void stderr)
{
  //! @ignore
  return Process.create_process(
    ({
#ifndef __NT__
      getcwd()+"/start",
#else /* __NT__ */
      getcwd()+"/../ntstart.exe",
#endif /* __NT__ */
      "--cd",wd,
      "--quiet","--program"})+args,
      (["toggle_uid":1,
	"stdin":stdin,
	"stdout":stdout,
	"stderr":stderr]));
  //! @endignore
}

// Add a few cache control related efuns
static private object initiate_cache()
{
  object cache;
  cache=((program)"base_server/cache")();

  add_constant("http_decode_string", _Roxen.http_decode_string );
  add_constant("cache_set",    cache->cache_set);
  add_constant("cache_lookup", cache->cache_lookup);
  add_constant("cache_remove", cache->cache_remove);
  add_constant("cache_expire", cache->cache_expire);
  add_constant("cache_clear",  cache->cache_expire);
  add_constant("cache_indices",cache->cache_indices);

  return cache;
}

class _error_handler {
  void compile_error(string a,int b,string c);
  void compile_warning(string a,int b,string c);
}

array(_error_handler) compile_error_handlers = ({});
void push_compile_error_handler( _error_handler q )
{
  if( q->do_not_push )
  {
    master()->set_inhibit_compile_errors( q );
    compile_error_handlers = ({0})+compile_error_handlers;
  }
  else
    compile_error_handlers = ({q})+compile_error_handlers;
}

void pop_compile_error_handler()
{
  if( !compile_error_handlers[0] )
  {
    master()->set_inhibit_compile_errors(0);
    return;
  }
  compile_error_handlers = compile_error_handlers[1..];
}

class LowErrorContainer
{
  string d;
  string errors="", warnings="";
  constant do_not_push = 0;
  string get()
  {
    return errors;
  }
  string get_warnings()
  {
    return warnings;
  }
  void got_error(string file, int line, string err, int|void is_warning)
  {
    if (file[..sizeof(d)-1] == d) {
      file = file[sizeof(d)..];
    }
    if( is_warning)
      warnings+= sprintf("%s:%s\t%s\n", file, line ? (string) line : "-", err);
    else
      errors += sprintf("%s:%s\t%s\n", file, line ? (string) line : "-", err);
  }
  void compile_error(string file, int line, string err)
  {
    got_error(file, line, "Error: " + err);
  }
  void compile_warning(string file, int line, string err)
  {
    got_error(file, line, "Warning: " + err, 1);
  }
  void create()
  {
    d = getcwd();
    if (sizeof(d) && (d[-1] != '/') && (d[-1] != '\\'))
      d += "/";
  }
}

//! @appears ErrorContainer
class ErrorContainer
{
  inherit LowErrorContainer;
  constant do_not_push = 1;
  void compile_error(string file, int line, string err)
  {
    if( sizeof(compile_error_handlers) )
      (compile_error_handlers-({0}))->compile_error( file,line, err );
    ::compile_error(file,line,err);
  }
  void compile_warning(string file, int line, string err)
  {
    if( sizeof(compile_error_handlers) )
      (compile_error_handlers-({0}))->compile_warning( file,line, err );
    ::compile_warning(file,line,err);
  }
}

//! @decl int cd(string path)
//! @appears cd
//! Overloads the Pike cd function.
//! Doesn't allow cd() unless we are in a forked child.

class restricted_cd
{
  int locked_pid = getpid();
  int `()(string path)
  {
    if (locked_pid == getpid()) {
      error ("Use of cd() is restricted.\n");
    }
    return cd(path);
  }
}

// Fallback efuns.
#if !constant(getuid)
int getuid(){ return 17; }
int getgid(){ return 42; }
#endif

// Load Roxen for real
Roxen really_load_roxen()
{
  int start_time = gethrtime();
  report_debug("Loading Roxen ... \b");
  Roxen res;
  mixed err = catch {
    res = ((program)"base_server/roxen.pike")();
  };
  if (err) 
  {
    report_debug("\bERROR\n");
    werror (describe_backtrace (err));
    throw(err);
  }
  report_debug("\bDone [%.1fms]\n",
	       (gethrtime()-start_time)/1000.0);

  res->start_time = start_time;
  res->boot_time = start_time;
  nwrite = res->nwrite;

  return res;
}

// Debug function to trace calls to destruct().
#ifdef TRACE_DESTRUCT
void trace_destruct(mixed x)
//! @appears destruct
//! Overloads the Pike destruct function. If the webserver is
//! started with the TRACE_DESTRUCT define set, all destruct
//! calls will be logged in the debug log.
{
  report_debug("DESTRUCT(%O)\n%s\n",
               x, describe_backtrace(backtrace())):
  destruct(x);
}
#endif /* TRACE_DESTRUCT */

void trace_exit (int exitcode)
{
  catch (report_notice ("Exiting Roxen - exit(%d) called.\n", exitcode));
#ifdef TRACE_EXIT
  catch (report_debug (describe_backtrace (backtrace())));
#endif
  exit (exitcode);
}

constant real_exit = exit;

#define DC(X) add_dump_constant( X,nm_resolv(X) )
function add_dump_constant;
mixed nm_resolv(string x )
{
  catch {
    return new_master->resolv( x );
  };
  return ([])[0];
};
  
// Set up efuns and load Roxen.
void load_roxen()
{
//   new_master->resolv("Roxen");
#if !constant( callablep )
  add_constant( "callablep",
		lambda(mixed f){return functionp(f)||programp(f);});
#endif
  add_constant("cd", restricted_cd());
  add_constant ("exit", trace_exit);
#ifdef TRACE_DESTRUCT
  add_constant("destruct", trace_destruct);
#endif /* TRACE_DESTRUCT */
#if !constant(getppid)
  add_constant("getppid", getppid);
#endif
#if !constant(getuid)
  add_constant("getuid", getuid);
  add_constant("getgid", getgid);
#endif
#if !constant(gethostname)
  add_constant("gethostname", lambda() { return "localhost"; });
#endif

#ifndef OLD_PARSE_HTML
  // Temporary kludge to get wide string rxml parsing.
  add_constant("parse_html", parse_html);
  add_constant("parse_html_lines", parse_html_lines);
#endif

  DC( "Roxen" );

  roxen = really_load_roxen();
}


#ifndef OLD_PARSE_HTML

static int|string|array(string) compat_call_tag (
  Parser.HTML p, string str, mixed... extra)
{
  string name = lower_case (p->tag_name());
  if (string|function tag = p->m_tags[name])
    if (stringp (tag)) return ({[string]tag});
    else return ([function(string,mapping,mixed...:string|array(string))]tag) (name, p->tag_args(), @extra);
  else if (string|function container = p->m_containers[name])
    // A container has been added.
    p->add_container (name, compat_call_container);
  return 1;
}

static int|string|array(string) compat_call_container (
  Parser.HTML p, mapping(string:string) args, string content, mixed... extra)
{
  string name = lower_case (p->tag_name());
  if (string|function container = p->m_containers[name])
    if (stringp (container)) return ({[string]container});
    else return container (name, args, content, @extra);
  else
    // The container has disappeared from the mapping.
    p->add_container (name, 0);
  return 1;
}

class ParseHtmlCompat
{
  inherit Parser.HTML;

  mapping(string:string|function) m_tags, m_containers;

  void create (mapping(string:string|function) tags,
	       mapping(string:string|function) containers,
	       mixed... extra)
  {
    m_tags = tags;
    m_containers = containers;
    add_containers (mkmapping (indices (m_containers),
			       ({compat_call_container}) * sizeof (m_containers)));
    _set_tag_callback (compat_call_tag);
    set_extra (@extra);
    case_insensitive_tag (1);
    lazy_entity_end (1);
    match_tag (0);
    ignore_unknown (1);
  }
}

string parse_html (string data, mapping(string:function|string) tags,
		   mapping(string:function|string) containers,
		   mixed... args)
{
  return ParseHtmlCompat (tags, containers, @args)->finish (data)->read();
}

static int|string|array(string) compat_call_tag_lines (
  Parser.HTML p, string str, mixed... extra)
{
  string name = lower_case (p->tag_name());
  if (string|function tag = p->m_tags[name])
    if (stringp (tag)) return ({tag});
    else return tag (name, p->tag_args(), p->at_line(), @extra);
  else if (string|function container = p->m_containers[name])
    // A container has been added.
    p->add_container (name, compat_call_container_lines);
  return 1;
}

static int|string|array(string) compat_call_container_lines (
  Parser.HTML p, mapping(string:string) args, string content, mixed... extra)
{
  string name = lower_case (p->tag_name());
  if (string|function container = p->m_containers[name])
    if (stringp (container)) return ({[string]container});
    else return container (name, args, content, p->at_line(), @extra);
  else
    // The container has disappeared from the mapping.
    p->add_container (name, 0);
  return 1;
}

class ParseHtmlLinesCompat
{
  inherit Parser.HTML;

  mapping(string:string|function) m_tags, m_containers;

  void create (mapping(string:string|function) tags,
	       mapping(string:string|function) containers,
	       mixed... extra)
  {
    m_tags = tags;
    m_containers = containers;
    add_containers (mkmapping (indices (m_containers),
			       ({compat_call_container_lines}) * sizeof (m_containers)));
    _set_tag_callback (compat_call_tag_lines);
    set_extra (@extra);
    case_insensitive_tag (1);
    lazy_entity_end (1);
    match_tag (0);
    ignore_unknown (1);
  }
}

string parse_html_lines (string data, mapping tags, mapping containers,
			 mixed... args)
{
  return ParseHtmlLinesCompat (tags, containers, @args)->finish (data)->read();
}

#endif

static local mapping fd_marks = ([]);

//! @appears mark_fd
mixed mark_fd( int fd, string|void with )
{
  if(!with)
    return fd_marks[ fd ];
  fd_marks[fd] = with;
}

// Code to trace fd usage.
#ifdef FD_DEBUG
class mf
{
  inherit Stdio.File;

  mixed open(string what, string mode, int|void perm)
  {
    int res;
    res = ::open(what, mode, perm||0666);
    if(res)
    {
      array bt = backtrace();
      string file = bt[-2][0];
      int line = bt[-2][1];
      mark_fd(query_fd(),
	      sprintf("%s:%d open(%O, %O, 0%03o)",
		      file, line, what, mode, perm||0666));
    }
    return res;
  }

  void destroy()
  {
    catch { mark_fd(query_fd(),"CLOSED"); };
  }

  int close(string|void what)
  {
    destroy();
    if (what) {
      return ::close(what);
    }
    return ::close();
  }
}
#else
constant mf = Stdio.File;
#endif

#include "../etc/include/version.h"

static string release;
static string dist_version;
static int roxen_is_cms;
static string roxen_product_name;

string roxen_version()
//! @appears roxen_version
{
  // Note: roxen_release is usually "-cvs" at the time this is compiled.
  return __roxen_version__+"."+__roxen_build__+(release||roxen_release);
}

//! @appears roxen_path
//!
//! Buhu
//!
//! @string
//!   @value "$LOCALDIR"
//!     The local directory of the webserver, Normally "../local",
//!     but it can be changed in by setting the environment
//!     variable LOCALDIR.
//!   @value "$LOGDIR"
//!     The log directory of the webserver. Normally "../logs",
//!     but it can be changed in the configuration interface under
//!     global settings.
//!   @value "$VARDIR"
//!     The webservers var directory. Normally "../var", but it can
//!     be changed by setting the environment variable VARDIR.
//!   @value "$VVARDIR"
//!     Same as $VARDIR, but with a server version specific subdirectory
//!     prepended.
//! @endstring
string roxen_path( string filename )
{
  filename = replace( filename, ({"$VVARDIR","$LOCALDIR"}),
                      ({"$VARDIR/"+roxen_version(),
                        getenv ("LOCALDIR") || "../local"}) );
  if( roxen )
    filename = replace( filename, 
                        "$LOGDIR", 
                        [string]roxen->query("logdirprefix") );
  else
    if( search( filename, "$LOGDIR" ) != -1 )
      roxen_perror("Warning: mkdirhier with $LOGDIR before variable is available\n");
  filename = replace( filename, "$VARDIR", getenv ("VARDIR") || "../var" );
#ifdef __NT__
  while( strlen(filename) && filename[-1] == '/' )
    filename = filename[..strlen(filename)-2];
#endif
  return filename;
}

int rm( string filename )
{
  return predef::rm( roxen_path(filename) );
}

array(string) r_get_dir( string path )
{
  return predef::get_dir( roxen_path( path ) );
}

int mv( string f1, string f2 )
{
  return predef::mv( roxen_path(f1), roxen_path( f2 ) );
}

Stdio.Stat file_stat( string filename, int|void slinks )
{
  return predef::file_stat( roxen_path(filename), slinks );
}

//! @appears open
object|void open(string filename, string mode, int|void perm)
{
#ifdef FD_DEBUG
  mf o;
#else
  Stdio.File o;
#endif
  o=mf();
  filename = roxen_path( filename );
  if(!(o->open(filename, mode, perm||0666))) {
    // EAGAIN, ENOMEM, ENFILE, EMFILE, EAGAIN(FreeBSD)
    if ((< 11, 12, 23, 24, 35 >)[o->errno()]) {
      // Let's see if the garbage-collector can free some fd's
      gc();
      // Retry...
      if(!(o->open(filename, mode, perm||0666))) {
	destruct(o);
	return;
      }
    } else {
      destruct(o);
      return;
    }
  }

  // FIXME: Might want to stat() here to check that we don't open
  // devices...
  return o;
}

//! @appears lopen
object|void lopen(string filename, string mode, int|void perm)
{
  Stdio.File o;
  if( filename[0] != '/' )
    o = open( "../local/"+filename, mode, perm );
  if( !o )
    o = open( filename, mode, perm );
  return o;
}

// Make a $PATH-style string
string make_path(string ... from)
{
  return map(from, lambda(string a, string b) {
    return (a[0]=='/')?combine_path("/",a):combine_path(b,a);
    //return combine_path(b,a);
  }, getcwd())*":";
}

//! @appears isodate
//! Returns a string with the given posix time @[t] formated as
//! YYYY-MM-DD.
string isodate( int t )
{
  mapping lt = localtime(t);
  return sprintf( "%d-%02d-%02d", lt->year+1900, lt->mon+1, lt->mday );
}

void write_current_time()
{
  if( !roxen )
  {
    call_out( write_current_time, 10 );
    return;
  }
  int t = time(1);
  mapping lt = localtime(t);
  report_debug("\n** "+sprintf("%02d-%02d-%02d %02d:%02d", lt->year+1900,
			       lt->mon+1, lt->mday, lt->hour, lt->min)+
               "   pid: "+pid+"   ppid: "+getppid()+
#if efun(geteuid)
	       (geteuid()!=getuid()?"   euid: "+pw_name(geteuid()):"")+
#endif
               "   uid: "+pw_name(getuid())+"\n\n");
  call_out( write_current_time, 3600 - t % 3600 );
}

//! @appears throw
//!   Overloads Pikes throw function.
//! 
//!   Exists for detection of code that throws non-errors.
void paranoia_throw(mixed err)
{
  if ((arrayp(err) && ((sizeof([array]err) < 2) || !stringp(([array]err)[0]) ||
		       !arrayp(([array]err)[1]) ||
		       !(arrayp(([array(array)]err)[1][0])||stringp(([array(array)]err)[1][0])))) ||
      (!arrayp(err) && (!objectp(err) || !([object]err)->is_generic_error))) {
    report_debug(sprintf("Warning: throwing non-error: %O\n"
			 "From: %s\n",
			 err, describe_backtrace(backtrace())));
  }
  throw(err);
}

// Roxen bootstrap code.
int main(int argc, array(string) argv)
{
  // For Pike 7.3
  add_constant("__pragma_save_parent__",1); // FIXME: Change this later on
  Protocols.HTTP; // FIXME: Workaround for bug 2637.

#if __VERSION__ < 7.4
    report_debug(
#"
------- FATAL -------------------------------------------------
Roxen 4.0 should be run with Pike 7.4 or newer.
---------------------------------------------------------------
");
    exit(1);
#endif

  // Check if IPv6 support is available.
  catch {
    // Note: Attempt to open a port on the IPv6 loopback (::1)
    //       rather than on IPv6 any (::), to make sure some
    //       IPv6 support is actually configured. This is needed
    //       since eg Solaris happily opens ports on :: even
    //       if no IPv6 interfaces are configured.
    Stdio.Port p = Stdio.Port(0, 0, "::1");
    destruct(p);
    add_constant("__ROXEN_SUPPORTS_IPV6__", 1);
  };

  // (. Note: Optimal implementation. .)
  array av = copy_value( argv );
  configuration_dir =
    Getopt.find_option(av, "d",({"config-dir","configuration-directory" }),
	     ({ "ROXEN_CONFIGDIR", "CONFIGURATIONS" }), "../configurations");

  remove_dumped =
    Getopt.find_option(av, "remove-dumped",({"remove-dumped", }), 0 );

  if( configuration_dir[-1] != '/' ) configuration_dir+="/";

  // Get the release version.
  if (release = Stdio.read_bytes("RELEASE")) {
    // Only the first line is interresting.
    release = (replace(release, "\r", "\n")/"\n")[0];
  }

  // Get product package version
  if (dist_version = Stdio.read_bytes("VERSION.DIST"))
    dist_version = (replace(dist_version, "\r", "\n") / "\n")[0];
  else
    dist_version = roxen_version();

  roxen_is_cms = !!file_stat("modules/sitebuilder");

  if(roxen_is_cms)
    roxen_product_name="Roxen CMS";
  else
    roxen_product_name="Roxen WebServer";

  // The default (internally managed) mysql path
  string defpath =
#ifdef __NT__
    // Use pipes with a name created from the config dir
    "mysql://%user%@.:"+
    replace(combine_path( getcwd(),
                          query_configuration_dir()+"_mysql/pipe"), ":", "_") +
    "/%db%";
#else
    "mysql://%user%@localhost:"+
    combine_path( getcwd(), query_configuration_dir()+"_mysql/socket")+
    "/%db%";
#endif

  my_mysql_path =
    Getopt.find_option(av, "m",({"mysql-url", }), 0,defpath);

  if( my_mysql_path != defpath )
  {
    werror(
     "          : ----------------------------------------------------------\n"
      "Notice: Not using the built-in MySQL\n"
      "MySQL path is "+my_mysql_path+"\n"
    );
    mysql_path_is_remote = 1;
  }

  nwrite = lambda(mixed ... ){};
  call_out( do_main_wrapper, 0, argc, argv );
  // Get rid of the _main and main() backtrace elements..
  return -1;
}

// Wrapper to make sure we die if loading fails.
void do_main_wrapper(int argc, array(string) argv)
{
  mixed err = catch {
    do_main(argc, argv);
    return;
  };
  catch {
    if (err) {
      werror(sprintf("Roxen loader failed:\n"
                     "%s\n", describe_backtrace(err)));
    }
  };
  trace_exit(1);
}

string query_mysql_dir()
{
  // FIXME: Should be configurable.
  return combine_path( __FILE__, "../../mysql/" );
}

string  my_mysql_path;

string query_configuration_dir()
{
  return configuration_dir;
}

static mapping(string:array(SQLTimeout)) sql_free_list = ([ ]);
static Thread.Local sql_reuse_in_thread = Thread.Local();
mapping sql_active_list = ([ ]);

#ifdef DB_DEBUG
static int sql_keynum;
mapping(int:string) my_mysql_last_user = ([]);
multiset(SQLKey) all_sql_wrappers = set_weak_flag( (<>), 1 );
#endif /* DB_DEBUG */


//! @appears clear_connect_to_my_mysql_cache
void clear_connect_to_my_mysql_cache( )
{
  sql_free_list = ([]);
}

static class SQLTimeout(static Sql.Sql real)
{
  // 5 minutes timeout.
  static int timeout = time(1) + 5*60;

  static int(0..1) `!()
  {
    if (timeout < time(1)) {
      real = 0;
    }
    return !real;
  }
  Sql.Sql get()
  {
    if (timeout < time(1)) {
      real = 0;
    }
    Sql.Sql res = real;
    real = 0;
    return res;
  }
}

static class SQLResKey
{
  static Sql.sql_result real;
  static SQLKey key;

  static void create (Sql.sql_result real, SQLKey key)
  {
    this_program::real = real;
    this_program::key = key;
  }

  // Proxy functions:
  // Why are these needed? /mast
  static int num_rows()
  {
    return real->num_rows();
  }
  static int num_fields()
  {
    return real->num_fields();
  }
  static int eof()
  {
    return real->eof();
  }
  static array(mapping(string:mixed)) fetch_fields()
  {
    return real->fetch_fields();
  }
  static void seek(int skip)
  {
    real->seek(skip);
  }
  static int|array(string|int) fetch_row()
  {
    return real->fetch_row();
  }

  static int(0..1) `!()
  {
    return !real;
  }

  static mixed `[]( string what )
  {
    return `->( what );
  }
  static mixed `->(string what )
  {
    switch( what )
    {
    case "real":         return real;
    case "num_rows":     return num_rows;
    case "num_fields":   return num_fields;
    case "eof":          return eof;
    case "fetch_fields": return fetch_fields;
    case "seek":         return seek;
    case "fetch_row":    return fetch_row;
    }
    return real[what];
  }

  static string _sprintf(int type)
  {
    return sprintf( "SQLRes( X, %O )", key );
  }

  static void destroy()
  {
    if (key->reuse_in_thread) {
      mapping(string:Sql.Sql) dbs_for_thread = sql_reuse_in_thread->get();
      if (!dbs_for_thread[key->db_name])
	dbs_for_thread[key->db_name] = key->real;
    }
#if 0
    werror("Destroying %O\n", this_object());
#endif
  }
}

static class SQLKey
{
  static Sql.Sql real;
  static string db_name;
  static int reuse_in_thread;

  static int `!( )  { return !real; }

  array(mapping) query( string f, mixed ... args )
  {
    return real->query( f, @args );
  }

  Sql.sql_result big_query( string f, mixed ... args )
  {
    if (Sql.sql_result o = real->big_query( f, @args )) {
      if (reuse_in_thread) {
	mapping(string:Sql.Sql) dbs_for_thread = sql_reuse_in_thread->get();
	if (dbs_for_thread[db_name] == real)
	  m_delete (dbs_for_thread, db_name);
      }
      return [object(Sql.sql_result)] (object) SQLResKey (o, this);
    }
    return 0;
  }
  
#ifdef DB_DEBUG
  static int num = sql_keynum++;
  static string bt;
#endif
  static void create( Sql.Sql real, string db_name, int reuse_in_thread)
  {
    this_program::real = real;
    this_program::db_name = db_name;
    this_program::reuse_in_thread = reuse_in_thread;

    if (reuse_in_thread) {
      mapping(string:Sql.Sql) dbs_for_thread = sql_reuse_in_thread->get();
      if (!dbs_for_thread) sql_reuse_in_thread->set (dbs_for_thread = ([]));
      if (!dbs_for_thread[db_name])
	dbs_for_thread[db_name] = real;
    }

#ifdef DB_DEBUG
    if( !_real )
      error("Creating SQL with empty real sql\n");

    foreach( (array)all_sql_wrappers, SQLKey ro )
    {
      if( ro )
	if( ro->real == real )
	  error("Fatal: This database connection is already used!\n");
	else if( ro->real->master_sql == real->master_sql )
	  error("Fatal: Internal share error: master_sql equal!\n");
    }
    all_sql_wrappers[this] = 1;

    bt=(my_mysql_last_user[num] = describe_backtrace(backtrace()));
#endif /* DB_DEBUG */
  }
  
  static void destroy()
  {
    // FIXME: Ought to be abstracted to an sq_cache_free().
#ifdef DB_DEBUG
    all_sql_wrappers[this]=0;
#endif

    if (reuse_in_thread) {
      mapping(string:SQLKey) dbs_for_thread = sql_reuse_in_thread->get();
      if (dbs_for_thread[db_name] == real) {
	m_delete (dbs_for_thread, db_name);
	if (!sizeof (dbs_for_thread)) sql_reuse_in_thread->set (0);
      }
    }

#ifndef NO_DB_REUSE
    mixed key;
    catch {
      key = sq_cache_lock();
    };
    
#ifdef DB_DEBUG
    werror("%O:%d added to free list\n", db_name, num );
    m_delete(my_mysql_last_user, num);
#endif
    if( !--sql_active_list[db_name] )
      m_delete( sql_active_list, db_name );
    sql_free_list[ db_name ] = ({ SQLTimeout(real) }) +
      (sql_free_list[ db_name ]||({}));
    if( `+( 0, @map(values( sql_free_list ),sizeof ) ) > 20 )
    {
#ifdef DB_DEBUG
      werror("Free list too large. Cleaning.\n" );
#endif
      clear_connect_to_my_mysql_cache();
    }
#else
    // Slow'R'us
    call_out(gc,0);
#endif
  }

  static mixed `[]( string what )
  {
    return `->( what );
  }
  
  static mixed `->(string what )
  {
    switch( what )
    {
      case "real":      return real;
      case "db_name":   return db_name;
      case "reuse_in_thread": return reuse_in_thread;
      case "query":     return query;
      case "big_query": return big_query;
    }
    return real[what];
  }

  static string _sprintf(int type)
  {
#ifdef DB_DEBUG
    if (type == 'd') return (string)num;
    return sprintf( "SQL( %O:%d )", db_name, num );
#else
    return sprintf( "SQL( %O )", db_name );
#endif /* DB_DEBUG */
  }
}

static Thread.Mutex mt = Thread.Mutex();
Thread.MutexKey sq_cache_lock()
{
  return mt->lock();
}

Sql.Sql sq_cache_get( string db_name, void|int reuse_in_thread)
{
  if (reuse_in_thread) {
    mapping(string:SQLKey) dbs_for_thread = sql_reuse_in_thread->get();
    if (Sql.Sql db = dbs_for_thread && dbs_for_thread[db_name])
      return [object(Sql.Sql)] (object) SQLKey (db, db_name, 1);
  }

  while(sql_free_list[ db_name ])
  {
#ifdef DB_DEBUG
    werror("%O found in free list\n", db_name );
#endif
    SQLTimeout res = sql_free_list[db_name][0];
    if( sizeof( sql_free_list[ db_name ] ) > 1)
      sql_free_list[ db_name ] = sql_free_list[db_name][1..];
    else
      m_delete( sql_free_list, db_name );
    if (Sql.Sql db = res && res->get()) {
      sql_active_list[db_name]++;
      return [object(Sql.Sql)] (object)
	SQLKey( db, db_name, reuse_in_thread);
    }
  }
}

Sql.Sql sq_cache_set( string db_name, Sql.Sql res, void|int reuse_in_thread)
{
  if( res )
  {
    sql_active_list[ db_name ]++;
    return [object(Sql.Sql)] (object) SQLKey( res, db_name, reuse_in_thread);
  }
}

/* Not to be documented. This is a low-level function that should be
 * avoided by normal users. 
*/
Sql.Sql connect_to_my_mysql( string|int ro, void|string db,
			     void|int reuse_in_thread)
{
#if 0
#ifdef DB_DEBUG
  gc();
#endif
#endif
  Thread.MutexKey key;
  if (catch {
    key = sq_cache_lock();
  }) {
    // Threads disabled.
    // This can occurr if we are called from the compiler.
    return low_connect_to_my_mysql(ro, db);
  }
  string i = db+":"+(intp(ro)?(ro&&"ro")||"rw":ro);
  Sql.Sql res =
    sq_cache_get(i, reuse_in_thread) ||
    sq_cache_set(i,low_connect_to_my_mysql( ro, db ), reuse_in_thread);

  // Fool the optimizer so that key is not released prematurely
  if( res )
    return res;
}

static mixed low_connect_to_my_mysql( string|int ro, void|string db )
{
  object res;
#ifdef DB_DEBUG
  werror("Requested %O for %O DB\n", db, ro );
#endif

  if( !db )
    db = "mysql";
  
  if( mixed err = catch
  {
    if( intp( ro ) )
      ro = ro?"ro":"rw";
    int t = gethrtime();
    res = Sql.Sql( replace( my_mysql_path,({"%user%", "%db%" }),
			    ({ ro, db })) );
#ifdef DB_DEBUG
    werror("Connect took %.2fms\n", (gethrtime()-t)/1000.0 );
#endif
    return res;
  } )
    if( db == "mysql" )
      throw( err );
#ifdef DB_DEBUG
    else
      werror ("Couldn't connect to MySQL as %s: %s", ro, describe_error (err));
#endif
  if( db != "mysql" )
    low_connect_to_my_mysql( 0, "mysql" )
      ->query( "CREATE DATABASE "+ db );
  return low_connect_to_my_mysql( ro, db );
}


static mapping tailf_info = ([]);
static void do_tailf( int loop, string file )
{
  string mysqlify( string what )
  {
    string res = "";
    foreach( (what/"\n"), string line )
    {
      if( sscanf( line, "%*sAborted connection%*s" ) == 2 )
	continue;
      if( line == "" )
	return res+"\n";
      res += "\n";
      res += "mysql: "+line;
    }
    return res;
  };

  int os, si, first;
  if( tailf_info[file] )
    os = tailf_info[file];
  do
  {
    Stdio.Stat s = file_stat( file );
    if(!s) {
      os = tailf_info[ file ] = 0;
      continue;
    }
    si = s[ ST_SIZE ];
    if( zero_type( tailf_info[ file ] ) )
      os = tailf_info[ file ] = si;
    if( os != si )
    {
      Stdio.File f = Stdio.File( file, "r" );
      if(!f) return;
      if( os < si )
      {
	f->seek( os );
	report_debug( mysqlify( f->read( si - os ) ) );
      }
      else
	report_debug( mysqlify( f->read( si ) ) );
      os = tailf_info[ file ] = si;
    }
    if( loop )
      sleep( 1 );
  } while( loop );
}

void low_start_mysql( string datadir,
		      string basedir,
		      string uid )
{
  string mysqld =
#ifdef __NT__
    "mysqld-nt.exe";
#else
    "mysqld";
#endif
  string bindir = basedir+"libexec/";
  if( !file_stat( bindir+mysqld ) )
  {
    bindir = basedir+"bin/";
    if( !file_stat( bindir+mysqld ) )
    {
      bindir = basedir+"sbin/";
      if( !file_stat( bindir+mysqld ) )
      {
	report_debug( "\nNo MySQL found in "+basedir+"!\n" );
	exit( 1 );
      }
    }
  }
  string pid_file = datadir + "/mysql_pid";
  string err_log  = datadir + "/error_log";

  // Default arguments.
  array(string) args = ({
		  "--defaults-file="+datadir+"/my.cfg",
#ifdef __NT__
                  // Use pipes with default name "MySQL" unless --socket is set
		  "--socket="+replace(datadir, ":", "_") + "/pipe",
		  "--enable-named-pipe",
#else
		  "--socket="+datadir+"/socket",
		  "--pid-file="+pid_file,
#endif
		  "--skip-locking",
		  "--skip-name-resolve",
		  "--basedir="+basedir,
		  "--datadir="+datadir,
  });

  // Set up the environment variables, and
  // enable mysql networking if necessary.
  mapping env = getenv();
  env->MYSQL_UNIX_PORT = datadir+"/socket";
  if ((int)env->ROXEN_MYSQL_TCP_PORT) {
    env->MYSQL_TCP_PORT = env->ROXEN_MYSQL_TCP_PORT;
    args += ({ "--port="+env->MYSQL_TCP_PORT });
    if (!env->MYSQL_HOST) {
      env->MYSQL_HOST = "127.0.0.1";
    }
  } else {
    args += ({ "--skip-networking" });
    env->MYSQL_HOST = "127.0.0.1";
    env->MYSQL_TCP_PORT = "0";
  }

  // Create the configuration file.
  string cfg_file = ("[mysqld]\n"
		     "set-variable = max_allowed_packet=16M\n"
		     "set-variable = net_buffer_length=8K\n"
#ifndef UNSAFE_MYSQL
		     "local-infile = 0\n"
#endif
		     "skip-name-resolve\n"
		     "bind-address = "+env->MYSQL_HOST+"\n" +
		     (uid ? "user = " + uid : "") + "\n");

#ifdef __NT__
  cfg_file = replace(cfg_file, "\n", "\r\n");
#endif /* __NT__ */

  if(!file_stat( datadir+"/my.cfg" ))
    catch(Stdio.write_file(datadir+"/my.cfg", cfg_file));

#ifdef __NT__
  string binary = "bin/roxen_mysql.exe";
#else
  string binary = "bin/roxen_mysql";
#endif
  rm( binary );
#if constant(hardlink)
  if( catch(hardlink( bindir+mysqld, binary )) )
#endif
    if( !Stdio.cp( bindir+mysqld, binary ) ||
	catch(chmod( binary, 0500 )) )
      binary = bindir+mysqld;

  args = ({ binary }) + args;

  Stdio.File  devnull
#ifndef __NT__
    = Stdio.File( "/dev/null", "w" )
#endif
    ;
  Stdio.File errlog = Stdio.File( err_log, "wct" );

  Process.create_process p = Process.create_process( args,
			  ([
			    "environment":env,
			    "stdin":devnull,
			    "stdout":errlog,
			    "stderr":errlog
			  ]) );
#ifdef __NT__
  if (p)
    Stdio.write_file(pid_file, (string)p->pid());
#endif
}


int mysql_path_is_remote;
void start_mysql()
{
  Sql.Sql db;
  int st = gethrtime();
  string mysqldir = combine_path(getcwd(),query_configuration_dir()+"_mysql");
  string err_log = mysqldir+"/error_log";
  string pid_file = mysqldir+"/mysql_pid";
  int do_tailf_threaded = 0;
#ifdef THREADS
  // Linux pthreads hangs in mutex handling if uid is changed
  // permanently and there are threads already running.
  if (uname()->sysname != "Linux")
    do_tailf_threaded = 1;
#endif
  void assure_that_base_tables_exists( )
  {
    // 1: Create the 'ofiles' database.
    if( mixed err = catch( db->query( "SELECT id from local.precompiled_files WHERE id=''" ) ) )
    {
      db->query( "CREATE DATABASE IF NOT EXISTS local" );
      
      connect_to_my_mysql(0,"local")
	->query( "CREATE TABLE precompiled_files ("
                 "id CHAR(30) NOT NULL PRIMARY KEY, "
                 "data MEDIUMBLOB NOT NULL, "
                 "mtime INT UNSIGNED NOT NULL)" );
      
      // At this moment new_master does not exist, and
      // DBManager can not possibly compile. :-)
      call_out( lambda(){
		  new_master->resolv("DBManager.is_module_table")
		    ( 0, "local", "precompiled_files",
			 "Contains binary object code for .pike files. "
			 "This information is used to shorten the "
			 "boot time of Roxen by keeping the compiled "
			 "data instead of recompiling it every time.");
		}, 1 );

    }
    if( remove_dumped )
    {
      report_notice("Removing precompiled files\n");
      if (mixed err = catch
      {
	db->query( "DELETE FROM local.precompiled_files" );
	db->query( "DELETE FROM local.compiled_formats" );
	// Clear the modules cache too since it currently doesn't
	// depend on the module path properly.
	db->query( "DELETE FROM local.modules" );
      }) {
#ifdef MYSQL_CONNECT_DEBUG
	werror ("Error removing dumped files: %s", describe_error (err));
#endif
      }
    }
  };

  void connected_ok(int was)
  {
    string version = db->query( "SELECT VERSION() AS v" )[0]->v;
    report_debug("\b%s %s [%.1fms]\n",
                 (was?"Was running":"Done"),
                  version, (gethrtime()-st)/1000.0);
    if( (float)version < 3.23 )
      report_debug( "Warning: This is a very old MySQL. "
		    "Please use 3.23.* or later.\n");

    if( !do_tailf_threaded ) do_tailf(0, err_log );
    assure_that_base_tables_exists();
  };

  void start_tailf()
  {
    if( do_tailf_threaded ) {
      thread_create( do_tailf, 1, err_log );
      sleep(0.1);
    } else {
      do_tailf(0, err_log );
      void do_do_tailf( )
	{
	  call_out( do_do_tailf, 1 );
	  do_tailf( 0, err_log  );
	};
      call_out( do_do_tailf, 0 );
    }
  };

  report_debug( "Starting MySQL ... \b");
  
  if( mixed err = catch( db = connect_to_my_mysql( 0, "mysql" ) ) ) {
#ifdef MYSQL_CONNECT_DEBUG
    werror ("Error connecting to local MySQL: %s", describe_error (err));
#endif
  }
  else {
    start_tailf();
    connected_ok(1);
    return;
  }

  if( mysql_path_is_remote )
  {
    report_debug( "******************** FATAL ******************\n"
		  "Cannot connect to the specified MySQL server\n"
		  "                  Aborting\n"
		  "******************** FATAL ******************\n" );
    exit(1);
  }

  rm( pid_file );
  rm( err_log );

  start_tailf();

  if( !file_stat( mysqldir+"/mysql/user.MYD" ) ||
      !file_stat( mysqldir+"/mysql/host.MYD" ) ||
      !file_stat( mysqldir+"/mysql/db.MYD" ) )
  {
#ifdef DEBUG
    report_debug("MySQL data directory does not exist -- copying template\n");
#endif
    if (!file_stat(mysqldir)) {
#ifdef DEBUG
      report_debug("Creating directory %O\n", mysqldir);
#endif /* DEBUG */
      mkdirhier(combine_path(mysqldir, "../"));
      mkdir(mysqldir, 0750);
    }

    mkdirhier( mysqldir+"/mysql/" );
    Filesystem.System tar = Filesystem.Tar( "etc/mysql-template.tar" );
    foreach( tar->get_dir( "mysql" ), string f )
    {
#ifdef DEBUG
      report_debug("copying "+f+" ... ");
#endif
      Stdio.File to = Stdio.File( mysqldir+f, "wct" );
      Stdio.File from = tar->open( f, "r" );
      to->write( from->read() );
#ifdef DEBUG
      report_debug("\n");
#endif
    }
  }


  low_start_mysql( mysqldir,query_mysql_dir(),
#if constant(getpwuid)
		   (getpwuid(getuid()) || ({0}))[ 0 ]
#else /* Ignored by the start_mysql script */
		0
#endif
		 );

  int repeat;
  while( 1 )
  {
    sleep( 0.1 );
    if( repeat++ > 100 )
    {
      if( !do_tailf_threaded ) do_tailf(0, err_log );
      report_fatal("\nFailed to start MySQL. Aborting\n");
      exit(1);
    }
    if( mixed err = catch( db = connect_to_my_mysql( 0, "mysql" ) ) ) {
#ifdef MYSQL_CONNECT_DEBUG
      werror ("Error connecting to local MySQL: %s", describe_error (err));
#endif
    }
    else
    {
      connected_ok(0);
      return;
    }
  }
}

int dump( string file, program|void p )
{
  if( file[0] != '/' )
    file = getcwd() +"/"+ file;
#ifdef __NT__
  file = normalize_path( file );
#endif
  if(!p)
    p = new_master->programs[ replace(file, "//", "/" ) ];
#ifdef __NT__
  if( !p )
  {
    if( sscanf( file, "%*s:/%s", file ) )
    {
      file = "/"+file;
      p = new_master->programs[ replace(file, "//", "/" ) ];
    }
  }
#endif
    
  array q;
#ifdef MUCHU_DUMP_DEBUG
# define DUMP_DEBUG
#endif
  if(!p)
  {
#ifdef DUMP_DEBUG
    werror(file+" not loaded, and thus cannot be dumped.\n");
#endif
    return 0;
  }

  if( new_master->has_set_on_load[ file ] == 1 )
  {
    m_delete( new_master->has_set_on_load, file );
    if( q = catch( new_master->dump_program( file, p ) ) )
    {
#ifdef DUMP_DEBUG
      report_debug("** Cannot encode "+file+": "+describe_error(q)+"\n");
#else
      array parts = replace(file, "//", "/") / "/";
      if (sizeof(parts) > 3) parts = parts[sizeof(parts)-3..];
      report_debug("Notice: Dumping failed for " + parts*"/"+" (not a bug)\n");
#endif
      return -1;
    }
#ifdef DUMP_DEBUG
    werror( file+" dumped successfully\n" );
#endif
    return 1;
  }
#ifdef MUCHO_DUMP_DEBUG
  werror(file+" already dumped (and up to date)\n");
#endif
  return 0;
}

object(Stdio.Stat)|array(int) da_Stat_type;
LocaleString da_String_type;
void do_main( int argc, array(string) argv )
{
  array(string) hider = argv;
  argv = 0;

#ifdef GC_TRACE
  trace (1, "gc");
#endif

  nwrite = early_nwrite;

  add_constant( "connect_to_my_mysql", connect_to_my_mysql );
  add_constant( "clear_connect_to_my_mysql_cache",
		clear_connect_to_my_mysql_cache );  
#ifdef SECURITY
#if !constant(__builtin.security.Creds)
  report_debug(
#"
------ FATAL ----------------------------------------------------
SECURITY defined (the internal security system in roxen), but
the pike binary has not been compiled --with-security. This makes
it impossible for roxen to have any internal security at all.
-----------------------------------------------------------------
");
  exit(-1);
#endif
#endif

  if( (-1&0xffffffff) < 0 )
  {
    report_debug(
#"
------- WARNING -----------------------------------------------
Roxen requires bignum support in Pike since version 2.4.
Please recompile Pike with gmp / bignum support to run Roxen.

It might still be possible to start Roxen, but the 
functionality will be affected, and stange errors might occur.
---------------------------------------------------------------

");
  }

#ifdef NOT_INSTALLED
    report_debug(
#"
------- WARNING -----------------------------------------------
You are running with an un-installed Pike binary.

Please note that this is unsupported, and might stop working at
any time, since some things are done differently in uninstalled
Pikes, as an example the module search paths are different, and
some environment variables are ignored.
---------------------------------------------------------------

");
#endif

#if __VERSION__ < 7.4
  report_debug(
#"


******************************************************
Roxen 4.0 requires Pike 7.4 or newer.
Please install a newer version of Pike.
******************************************************


");
  _exit(0); /* 0 means stop start script looping */
#endif /* __VERSION__ < 7.4 */

#if !constant (Mysql.mysql)
  report_debug (#"


******************************************************
Roxen requires MySQL support in Pike since version 2.4.
Your Pike has been compiled without support for MySQL.
Please install MySQL client libraries and reconfigure
and rebuild Pike from scratch.
******************************************************


");
  _exit(0); // 0 means stop start script looping
#endif // !constant (Mysql.mysql)

  if (catch(((function(mapping(string:string|array(string)),int|void:string))
	     _Roxen->make_http_headers)(([]), 1))) {
    add_constant("HAVE_OLD__Roxen_make_http_headers", 1);
    report_debug(#"


------- WARNING -----------------------------------------------
Old or broken _Roxen.make_http_headers() detected.

Roxen 4.0 prefers Pike 7.4.336 or newer.
Roxen will still work, but at lower performance.
Please install a newer version of Pike.
---------------------------------------------------------------


");
  }

  Stdio.Stat stat = file_stat("etc/include/version.h");
  if (stat && (stat->mtime > time())) {
    report_debug(#"


------- WARNING -----------------------------------------------
System time is incorrect.

System time: %s
Check time: %s
This may cause unreliable operation. Please set
the correct system time.
---------------------------------------------------------------


", ctime(stat->mtime), ctime(time(1)));
  }

  int start_time = gethrtime();
  string path = make_path("base_server", "etc/include", ".");
  last_was_nl = 1;
  mapping un = uname();
  string hostinfo =
    (un->sysname || "") + " " + (un->release || "") +
    (un->machine ? (" (" + un->machine + ")") : "");
  string pike_ver = version();
  if ((__REAL_MAJOR__ != __MAJOR__) ||
      (__REAL_MINOR__ != __MINOR__)) {
    pike_ver += sprintf(" (in Pike %d.%d compat mode)",
			__MAJOR__, __MINOR__);
  }
  report_debug("-" * 65 + "\n"
	       "Pike version:      " + pike_ver + "\n"
               "Product version:   " + roxen_product_name + " " + roxen_version() + "\n"
               "Operating system:  " + hostinfo + "\n");
  master()->putenv("PIKE_INCLUDE_PATH", path);
  foreach(path/":", string p) {
    add_include_path(p);
    add_program_path(p);
  }

  add_constant ("get_cvs_id", get_cvs_id);
  add_constant ("add_cvs_ids", add_cvs_ids);
  add_constant ("describe_backtrace", describe_backtrace);

#ifdef INTERNAL_ERROR_DEBUG
  add_constant("throw", paranoia_throw);
#endif /* INTERNAL_ERROR_DEBUG */

  add_constant( "mark_fd", mark_fd );
  add_constant( "isodate", isodate );

  add_constant( "LocaleString", typeof(da_String_type) );
  add_constant( "Stat", typeof(da_Stat_type) );
  
  mixed err;

  add_constant("open",          open);
  add_constant("roxen_path",    roxen_path);
  add_constant("roxen_version", roxen_version);
  add_constant("roxen_dist_version", dist_version);
  add_constant("roxen_release", release || roxen_release);
  add_constant("roxen_is_cms",  roxen_is_cms);
  add_constant("roxen_product_name", roxen_product_name);
  add_constant("lopen",         lopen);
  add_constant("report_notice", report_notice);
  add_constant("report_debug",  report_debug);
  add_constant("report_warning",report_warning);
  add_constant("report_error",  report_error);
  add_constant("report_fatal",  report_fatal);
  add_constant("report_warning_sparsely", report_warning_sparsely);
  add_constant("report_error_sparsely", report_error_sparsely);
  add_constant("werror",        roxen_perror);
  add_constant("perror",        roxen_perror); // For compatibility.
  add_constant("roxen_perror",  roxen_perror);
  add_constant("roxenp",        lambda() { return roxen; });
  add_constant("ST_MTIME",      ST_MTIME );
  add_constant("ST_CTIME",      ST_CTIME );
  add_constant("ST_SIZE",       ST_SIZE );
  add_constant("mkdirhier",     mkdirhier );

#if !constant(uname)
  add_constant( "uname", uname );
#endif
#ifdef __NT__
  add_constant( "getuid", lambda(){ return 0; } );
  add_constant( "getgid", lambda(){ return 0; } );
  add_constant( "geteuid", lambda(){ return 0; } );
  add_constant( "getegid", lambda(){ return 0; } );
#endif

  add_constant("r_rm", rm);
  add_constant("r_mv", mv);
  add_constant("r_get_dir", r_get_dir);
  add_constant("r_file_stat", file_stat);
  add_constant("roxenloader", this_object());
  add_constant("ErrorContainer", ErrorContainer);

  add_constant("_cur_rxml_context", Thread.Local());

  start_mysql();

  if (err = catch {
    if(master()->relocate_module) add_constant("PIKE_MODULE_RELOC", 1);
    replace_master(new_master=[object(__builtin.__master)](((program)"etc/roxen_master.pike")()));
  }) {
    werror("Initialization of Roxen's master failed:\n"
	   "%s\n", describe_backtrace(err));
    exit(1);
  }


#if constant( Gz.inflate )
  add_constant("grbz",lambda(string d){return Gz.inflate()->inflate(d);});
#else
  add_constant("grbz",lambda(string d){return d;});
  report_debug(
#"
------- WARNING -----------------------------------------
The Gz (zlib) module is not available.
The default builtin font will not be available.
To get zlib support, install zlib from
ftp://ftp.freesoftware.com/pub/infozip/zlib/zlib.html
and recompile pike, after removing the file 'config.cache'
----------------------------------------------------------

");
#endif

  add_constant("spawne",spawne);
  add_constant("spawn_pike",spawn_pike);
  add_constant("popen",popen);
  add_constant("roxen_popen",popen);
  add_constant("init_logger", init_logger);
  add_constant("capitalize", String.capitalize);

  // It's currently tricky to test for Image.TTF correctly with a
  // preprocessor directive, so let's add a constant for it.
#if constant (Image.TTF)
  if (sizeof (indices (Image.TTF)))
  {
    add_constant ("has_Image_TTF", 1);
    add_constant( "Image.TTF", Image.TTF );
    // We can load the builtin font.
    add_constant("__rbf", "font_handlers/rbf" );
  } else
#endif
  {
#if constant(Image.FreeType.Face)
    // We can load the builtin font.
    add_constant("__rbf", "font_handlers/rbf" );
#else
    report_debug(
#"
------- WARNING ----------------------------------------------
Neither the Image.TTF nor the Image.FreeType module is available.
True Type fonts and the default font will not be available.
To get True Type support, download a Freetype package from

http://freetype.sourceforge.net/download.html

Install it, and then remove config.cache in pike and recompile.
If this was a binary release of Roxen, there should be no need
to recompile the pike binary, since the one included should
already have the FreeType interface module, installing the 
library should be enough.
--------------------------------------------------------------

" );
#endif
  }

  if( search( hider, "--long-error-file-names" ) != -1 )
  {
    hider -= ({ "--long-error-file-names" });
    argc = sizeof(hider);
    new_master->long_file_names = 1;
    new_master->putenv("LONG_PIKE_ERRORS", "yup");
  }

  // These are here to allow dumping of roxen.pike to a .o file.
  report_debug("Loading Pike modules ... \b");

  add_dump_constant = new_master->add_dump_constant;
  int t = gethrtime();

  DC("Thread.Thread");    DC("Thread.Local");
  DC("Thread.Mutex");     DC("Thread.MutexKey");
  DC("Thread.Condition"); DC("thread_create");
  DC( "Thread.Queue" );
  DC("Sql");  DC("Sql.mysql");
  DC ("String.Buffer");


#if constant(Oracle.oracle)
  DC("Sql.oracle");
#endif
#if constant(Odbc.odbc)
  DC("Sql.odbc");
#endif
  
  DC( "_Roxen.HeaderParser" );
  
  DC( "Protocols.HTTP" ); DC( "Protocols.HTTP.Query" );

  DC( "Calendar.ISO" );   DC( "Calendar.ISO.Second" );

  DC( "Stdio.Stat" );
  
  DC( "Regexp" );

  DC( "Pipe.pipe" );

  
  foreach( ({ "ANY", "XCF", "PSD", "PNG",  "BMP",  "TGA", "PCX",
	      "XBM", "XPM", "TIFF", "ILBM", "PS", "PVR", "GIF",
	      "JPEG", "XWD", "PNM", "RAS",  "DSI", "TIM", "HRZ",
	      "AVS", "WBF", "WBMP", "XFace" }),
	   string x )
    DC("Image."+x);
  DC( "Image.Image" );  DC( "Image.Font" );  DC( "Image.Colortable" );
  DC( "Image.Layer" );  DC( "Image.lay" );   DC( "Image.Color" );
  DC( "Image.Color.Color" );DC("Image._PSD" ); DC("Image._XCF" );
  DC ("Image.Color.black");
  DC( "Image._XPM" );  DC( "Image" );  
  if( DC("Image.GIF.encode") )
    DC( "Image.GIF.encode_trans" );


  DC( "Stdio.File" );  DC( "Stdio.UDP" );  DC( "Stdio.Port" );

  DC( "Stdio.read_bytes" );  DC( "Stdio.read_file" );
  DC( "Stdio.write_file" );


  DC( "Stdio.sendfile" );

  DC( "Stdio.stderr" );  DC( "Stdio.stdin" );  DC( "Stdio.stdout" );

  DC( "Parser.HTML" );

  if( DC("SSL.sslfile" ) )
  {
    DC( "SSL.context" );
    DC( "Tools.PEM.pem_msg" );
    DC( "Crypto.randomness.reasonably_random" );
    DC( "Standards.PKCS.RSA.parse_private_key");
    DC( "Crypto.rsa" );
    DC( "Tools.X509.decode_certificate" );
    DC( "Standards.PKCS.DSA.parse_private_key" );
    DC( "SSL.cipher.dh_parameters" );
  }

  if( DC( "HTTPLoop.prog" ) )
    DC( "HTTPLoop.Loop" );

  if( DC( "Image.FreeType" ) )
    DC( "Image.FreeType.Face" );
  
  DC( "Process.create_process" );
  DC( "MIME.Message" );  DC( "MIME.encode_base64" );
  DC( "MIME.decode_base64" );

  DC( "Locale" );  DC( "Locale.Charset" );

  report_debug("\bDone [%.1fms]\n", (gethrtime()-t)/1000.0);

  add_constant( "hsv_to_rgb",  nm_resolv("Colors.hsv_to_rgb")  );
  add_constant( "rgb_to_hsv",  nm_resolv("Colors.rgb_to_hsv")  );
  add_constant( "parse_color", nm_resolv("Colors.parse_color") );
  add_constant( "color_name",  nm_resolv("Colors.color_name")  );
  add_constant( "colors",      nm_resolv("Colors")             );

  // Load prototypes (after the master is replaces, thus making it
  // possible to dump them to a .o file (in the mysql))
  object prototypes = (object)"base_server/prototypes.pike";
  dump( "base_server/prototypes.pike", object_program( prototypes ) );
  foreach (indices (prototypes), string id)
    if (!prototypes->ignore_identifiers[id])
      add_constant (id, prototypes[id]);
  prototypes->Roxen = master()->resolv ("Roxen");

  object cache = initiate_cache();
  load_roxen();

  int retval = roxen->main(argc,hider);
  cache->init_call_outs();

  report_debug("-- Total boot time %2.1f seconds ---------------------------\n",
	       (gethrtime()-start_time)/1000000.0);
  write_current_time();
  if( retval > -1 )
    trace_exit( retval );
  return;
}

//! @decl int(0..1) callablep(mixed f)
//! @appears callablep

//! @decl roxen roxenp()
//! @appears roxenp

//! @decl int(0..1) r_rm(string f)
//! @appears r_rm
//! Alias for rm.

//! @decl int(0..1) r_mv(string from, string to)
//! @appears r_mv
//! Alias for mv.

//! @decl array(string) r_get_dir(string dirname)
//! @appears r_get_dir
//! Alias for get_dir.

//! @decl Stdio.Stat r_file_stat(string path, void|int(0..1) symlink)
//! @appears r_file_stat
//! Alias for file_stat.

//! @decl string capitalize(string text)
//! @appears capitalize
//! Alias for String.capitalize.

//! @decl array(int) hsv_to_rgb(array(int) hsv)
//! @decl array(int) hsv_to_rgb(int h, int s, int v)
//! @appears hsv_to_rgb
//! Alias for Colors.hsv_to_rgb.

//! @decl array(int) rgb_to_hsv(array(int) rgb)
//! @decl array(int) rgb_to_hsv(int r, int g, int b)
//! @appears rgb_to_hsv
//! Alias for Colors.rgb_to_hsv

//! @decl array(int) parse_color(string name)
//! @appears parse_color
//! Alias for Colors.parse_color

// @module colors
// @appears colors
// Alias for Colors
// @endmodule
