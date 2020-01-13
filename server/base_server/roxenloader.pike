// This file is part of Roxen WebServer.
// Copyright © 1996 - 2009, Roxen IS.
//
// Roxen bootstrap program.

// $Id$

#define LocaleString Locale.DeferredLocale|string

mixed x = Calendar.Timezone; // #"!¤&"¤%/"&#¤!%#¤&#

// #pragma strict_types

// Sets up the roxen environment. Including custom functions like spawne().

#include <stat.h>
#include <roxen.h>

// --- Locale defines ---

//<locale-token project="roxen_start">   LOC_S </locale-token>
//<locale-token project="roxen_message"> LOC_M </locale-token>
#define LOC_S(X,Y)	_STR_LOCALE("roxen_start",X,Y)
#define LOC_M(X,Y)	_STR_LOCALE("roxen_message",X,Y)
#define CALL_M(X,Y)	_LOCALE_FUN("roxen_message",X,Y)

//
// NOTE:
//	This file uses replace_master(). This implies that the
//	master() efun when used in this file will return the old
//	master and not the new one.
//
private __builtin.__master new_master;

#if constant(spider)
// This ancient module has been removed in Pike 8.1.
constant s = spider; // compatibility
#endif

// Enable decoding of wide string data from mysql.
// Disabled since it isn't compatible enough - has to be enabled on a
// per-connection basis through the charset argument. /mast
//#define ENABLE_MYSQL_UNICODE_MODE

int      remove_dumped;
string   configuration_dir;
int once_mode;

#define werror roxen_perror

constant cvs_version="$Id$";

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

#if !constant(utf8_string)
protected typedef __attribute__("utf8", string(8bit))	utf8_string;
#endif

#if !constant(getppid)
int getppid() {   return -1; }
#endif

#if constant(syslog)
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

#if constant(DefaultCompilerEnvironment)
#if (__REAL_MAJOR__ == 8) && (__REAL_MINOR__ == 0) && (__REAL_BUILD__ < 694)
/* Workaround for [PIKE-126]. */
object _disable_threads()
{
  object compiler_lock = DefaultCompilerEnvironment->lock();
  return predef::_disable_threads();
}
#endif
#endif

//! The path to the server directory, without trailing slash. If
//! available, this is the logical path without following symlinks (as
//! opposed to what @[getcwd] returns).
//!
//! @note
//! @[getcwd] should be used when the server directory is combined
//! with a path that may contain "..". The main reason is to keep
//! compatibility, and in extension for the sake of consistency.
string server_dir =
  lambda () {
    string cwd = getcwd();
#ifdef __NT__
    cwd = replace (cwd, "\\", "/");
#endif
    if (has_suffix (cwd, "/"))
      report_warning ("Warning: Server directory is a root dir "
		      "(or getcwd() misbehaves): %O\n", cwd);

    string check_dir (string d) {
      while (has_suffix (d, "/"))
	d = d[..<2];
#if constant (resolvepath)
      if (resolvepath (d) == cwd)
	return d;
#else
      if (cd (d)) {
	if (getcwd() == cwd)
	  return d;
	else
	  cd (cwd);
      }
#endif
      return 0;
    };

    if (string env_pwd = getenv ("PWD"))
      if (string res = check_dir (env_pwd))
	return res;

    if (string res = check_dir (combine_path (__FILE__, "../..")))
      return res;

    return cwd;
  }();


/*
 * Some efuns used by Roxen
 */

protected string last_id, last_from;
string get_cvs_id(string from)
{
  if(last_from == from) return last_id;
  last_from=from;
  catch {
    object f = open(from,"r");
    string id;
    id = f->read(1024);
    if (sscanf (id, "%*s$""Id: %s $", id) == 2) {
      if(sscanf(id, "%*s,v %[0-9.] %*s", string rev) == 3)
	return last_id=" (rev "+rev+")"; // cvs
      if (sscanf (id, "%[0-9a-z]%*c", id) == 1)
	return last_id = " (" + id[..7] + ")"; // git
    }
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

int num_describe_backtrace = 0; // For statistics
string describe_backtrace (mixed err, void|int linewidth
#ifdef RUN_SELF_TEST
  , void|bool silent
#endif
)
{
  num_describe_backtrace++;

#ifdef RUN_SELF_TEST
  // Count this as a failure if it occurs during the self test. This
  // is somewhat blunt, but it should catch all the places (typically
  // in other threads) where we catch errors, log them, and continue.
  if (roxen && !silent)
    foreach (roxen->configurations, object/*(Configuration)*/ conf)
      if (object/*(RoxenModule)*/ mod = conf->get_provider ("roxen_test")) {
	mod->background_failure();
      }
#endif

  add_cvs_ids (err);
  return predef::describe_backtrace (err, 999999);
}

int co_num_call_out = 0;    // For statistics
int co_num_runs_001s = 0;
int co_num_runs_005s = 0;
int co_num_runs_015s = 0;
int co_num_runs_05s = 0;
int co_num_runs_1s = 0;
int co_num_runs_5s = 0;
int co_num_runs_15s = 0;
int co_acc_time = 0;
int co_acc_cpu_time = 0;
mixed call_out(function f, float|int delay, mixed ... args)
{
  return predef::call_out(class (function f) {
      int __hash() { return hash_value(f); }
      int `==(mixed g) { return f == g; }
      string _sprintf() { return sprintf("%O", f); }
      mixed `()(mixed ... args)
      {
	co_num_call_out++;
	mixed err, res;
	int start_hrtime = gethrtime();
	float co_vtime = gauge { err = catch { res = f && f(@args); }; };
	float co_rtime = (gethrtime() - start_hrtime)/1E6;
	if (co_rtime >  0.01) co_num_runs_001s++;
	if (co_rtime >  0.05) co_num_runs_005s++;
	if (co_rtime >  0.15) co_num_runs_015s++;
	if (co_rtime >  0.50) co_num_runs_05s++;
	if (co_rtime >  1.00) co_num_runs_1s++;
	if (co_rtime >  5.00) co_num_runs_5s++;
	if (co_rtime > 15.00) co_num_runs_15s++;
	co_acc_cpu_time += (int)(1E6*co_vtime);
	co_acc_time += (int)(1E6*co_rtime);
	if (err) throw(err);
	return res;
      }
    }(f), delay, @args);
}


protected int(2..2147483647) roxen_started = [int(2..2147483647)]time();
protected float roxen_started_flt = time(time());
protected int uptime_row_counter;

// -----------------------------------------------------------------------------
// NB: If the length of the timestamp is modified, the following files should
//     also be updated:
//         Roxen:  server/bin/functions
//                 server/start
//                 server/tools/ntroxen/startdll/cmdline.cpp
//         Search: modules/search_sb_interface.pike
//                 programs/compact.pike
//                 programs/multiprocess_crawler.pike
//
// The Pike class Search.Utils.Logger, in lib/modules/Search.pmod/Utils.pmod,
// was previously also effected when indentation width was changed but now it
// is possible to specify indentation width as an argument to
// the Search.Utils.Logger constructor.
// -----------------------------------------------------------------------------
string format_timestamp()
{
  string up_str;
  if (uptime_row_counter) {
    up_str = "         ";
  } else {
    float up = time(roxen_started) - roxen_started_flt;
    if (up > 3600) {
      up_str = sprintf( "%2dd%2dh%2dm",
			(int) up / 86400,
			(((int) up / 3600) % 24),
			((int) up / 60) % 60);
    } else {
      up_str = sprintf( "%2dm%4.1fs ", ((int) up / 60) % 60, up % 60);
    }
  }
  uptime_row_counter = (uptime_row_counter + 1) % 5;

  mapping l = localtime(time());
  return sprintf("%4d-%02d-%02d %2d:%02d:%02d  %s : ",
                 (1900 + l->year), (1 + l->mon), l->mday,
                 l->hour, l->min, l->sec, up_str);
}


//! @decl void werror(string format, mixed ... args)
//! @appears werror

//! @decl void roxen_perror(string format, mixed ... args)
//! @appears roxen_perror

protected int last_was_nl = 1;
// Used to print error/debug messages
void roxen_perror(sprintf_format format, sprintf_args ... args)
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
      stderr->write(string_to_utf8(format));
      format = "";
      if (delayed_nl) last_was_nl = -1;
    } else {
      stderr->write(string_to_utf8(format[..i]));
      format = format[i+1..];
      last_was_nl = 1;
    }
  }

  if (sizeof(format)) {
#if constant(syslog)
    syslog_report (format, LOG_DEBUG);
#endif

    if (last_was_nl == -1) stderr->write("\n");
    last_was_nl = format[-1] == '\n';

#ifdef RUN_SELF_TEST
    stderr->write( string_to_utf8( format ) );
#else
    array(string) a = format/"\n";
    int i;

    a = map( a, string_to_utf8 );

#ifdef DEBUG_LOG_SHOW_USER
    string usr;
    catch {
      mixed rxml_ctx = all_constants()["_cur_rxml_context"]->get();
      if(rxml_ctx)
	usr = rxml_ctx->user_get_var("user.username");
    };
#endif

    for(i=0; i < sizeof(a)-1; i++) {
#ifdef DEBUG_LOG_SHOW_USER
      if(usr)
	a[i] = usr + " : " + a[i];
#endif
      stderr->write(format_timestamp() + a[i] + "\n");
    }
    if (!last_was_nl) {
#ifdef DEBUG_LOG_SHOW_USER
      if(usr)
	a[-1] = usr + " : " + a[-1];
#endif
      stderr->write(format_timestamp() + a[-1]);
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
#if constant(syslog)
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

void report_debug(sprintf_format message, sprintf_args ... foo)
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

protected void syslog_report (string message, int level)
{
#if constant(syslog)
  if(use_syslog && (loggingfield&level))
    foreach(message/"\n", message)
      syslog(level, replace(message+"\n", "%", "%%"));
#endif
}


#define MC @find_module_and_conf_for_log(backtrace())

void report_warning(LocaleString|sprintf_format message, sprintf_args ... foo)
//! @appears report_warning
//! Report a warning message, that will show up in the server's debug log and
//! in the event logs, along with the yellow exclamation mark warning sign.
//! Shares argument prototype with @[sprintf()].
//!
//! @seealso
//! @[report_warning_sparsely], @[report_warning_for]
{
  if( sizeof( foo ) ) message = sprintf((string)message, @foo );
  nwrite([string]message,0,2,MC);
#if constant(syslog)
  if (use_syslog) syslog_report (message, LOG_WARNING);
#endif
}

void report_notice(LocaleString|sprintf_format message, sprintf_args ... foo)
//! @appears report_notice
//! Report a status message of some sort for the server's debug log and event
//! logs, along with the blue informational notification sign. Shares argument
//! prototype with @[sprintf()].
//!
//! @seealso
//! @[report_notice_for]
{
  if( sizeof( foo ) ) message = sprintf((string)message, @foo );
  nwrite([string]message,0,1,MC);
#if constant(syslog)
  if (use_syslog) syslog_report (message, LOG_NOTICE);
#endif
}

void report_error(LocaleString|sprintf_format message, sprintf_args ... foo)
//! @appears report_error
//! Report an error message, that will show up in the server's debug log and
//! in the event logs, along with the red exclamation mark sign. Shares
//! argument prototype with @[sprintf()].
//!
//! @seealso
//! @[report_error_sparsely], @[report_error_for]
{
  if( sizeof( foo ) ) message = sprintf((string)message, @foo );
  nwrite([string]message,0,3,MC);
#if constant(syslog)
  if (use_syslog) syslog_report (message, LOG_ERR);
#endif
}

void report_fatal(sprintf_format message, sprintf_args ... foo)
//! @appears report_fatal
//! Print a fatal error message.
//!
//! @seealso
//! @[report_fatal_for]
{
  if( sizeof( foo ) ) message = sprintf((string)message, @foo );
  nwrite(message,0,3,MC);
#if constant(syslog)
  if (use_syslog) syslog_report (message, LOG_EMERG);
#endif
}

void report_warning_for (object/*(Configuration|RoxenModule)*/ where,
			 LocaleString|sprintf_format message,
			 sprintf_args ... args)
//! @appears report_warning_for
//! See @[report_error_for].
{
  if (sizeof (args)) message = sprintf (message, @args);
  nwrite (message, 0, 2,
	  where && where->is_module && where,
	  where && where->is_configuration && where);
#if constant(syslog)
  if (use_syslog) syslog_report (message, LOG_WARNING);
#endif
}

void report_notice_for (object/*(Configuration|RoxenModule)*/ where,
			LocaleString|sprintf_format message,
			sprintf_args ... args)
//! @appears report_notice_for
//! See @[report_error_for].
{
  if (sizeof (args)) message = sprintf (message, @args);
  nwrite (message, 0, 1,
	  where && where->is_module && where,
	  where && where->is_configuration && where);
#if constant(syslog)
  if (use_syslog) syslog_report (message, LOG_NOTICE);
#endif
}

void report_error_for (object/*(Configuration|RoxenModule)*/ where,
		       LocaleString|sprintf_format message,
		       sprintf_args ... args)
//! @appears report_error_for
//! Like @[report_error], but logs the message for the given
//! configuration or Roxen module @[where], or globally if @[where] is
//! zero. @[report_error] searches the call stack to find that out,
//! but this function is useful to specify it explicitly.
{
  if (sizeof (args)) message = sprintf (message, @args);
  nwrite (message, 0, 3,
	  where && where->is_module && where,
	  where && where->is_configuration && where);
#if constant(syslog)
  if (use_syslog) syslog_report (message, LOG_ERR);
#endif
}

void report_fatal_for (object/*(Configuration|RoxenModule)*/ where,
		       LocaleString|sprintf_format message,
		       sprintf_args ... args)
//! @appears report_fatal_for
//! See @[report_error_for].
{
  if (sizeof (args)) message = sprintf (message, @args);
  nwrite (message, 0, 3,
	  where && where->is_module && where,
	  where && where->is_configuration && where);
#if constant(syslog)
  if (use_syslog) syslog_report (message, LOG_EMERG);
#endif
}

protected mapping(string:int) sparsely_dont_log = (garb_sparsely_dont_log(), ([]));

protected void garb_sparsely_dont_log()
{
  if (sparsely_dont_log && sizeof (sparsely_dont_log)) {
    int now = time (1);
    foreach (sparsely_dont_log; string msg; int ts)
      if (ts < now) m_delete (sparsely_dont_log, msg);
  }
  call_out (garb_sparsely_dont_log, 20*60);
}

void report_warning_sparsely (LocaleString|sprintf_format message,
			      sprintf_args ... args)
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
#if constant(syslog)
  if (use_syslog) syslog_report (message, LOG_WARNING);
#endif
}

void report_error_sparsely (LocaleString|sprintf_format message,
			    sprintf_args ... args)
//! @appears report_error_sparsely
//! Like @[report_error], but doesn't repeat the same message if it's
//! been logged in the last ten minutes. Useful in situations where an
//! error can cause an error message to be logged rapidly.
{
  if( sizeof( args ) ) message = sprintf((string)message, @args );
  int now = time (1);
  if (sparsely_dont_log[message] >= now) return;
  sparsely_dont_log[message] = now + 10*60;
  nwrite([string]message,0,3,MC);
#if constant(syslog)
  if (use_syslog) syslog_report (message, LOG_ERR);
#endif
}

//! @appears popen
//! Starts the specified process and returns a string
//! with the result. Mostly a compatibility functions, uses
//! Process.Process
//!
//! If @[cmd] is a string then it's interpreted as a command line with
//! glob expansion, argument splitting, etc according to the command
//! shell rules on the system. If it's an array of strings then it's
//! taken as processed argument list and is sent to
//! @[Process.Process] as-is.
string popen(string|array(string) cmd, void|mapping env,
	     int|void uid, int|void gid)
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
  if (stringp (cmd)) {
#if defined(__NT__) || defined(__amigaos__)
    cmd = Process.split_quoted_string(cmd);
#else /* !__NT||__amigaos__ */
    cmd = ({"/bin/sh", "-c", cmd});
#endif /* __NT__ || __amigaos__ */
  }
  Process.Process proc = Process.Process (cmd, opts);
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
#if constant(geteuid)
  else { u=geteuid(); g=getegid(); }
#endif
  return Process.Process(({s}) + (args || ({})), ([
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
  array(string) cmd = ({
#ifndef __NT__
    getcwd()+"/start",
#else /* __NT__ */
    getcwd()+"/../ntstart.exe",
#endif /* __NT__ */
  });

  if (wd) cmd += ({"--cd", wd});

  cmd += ({"--quiet","--program"}) + args;

  return Process.Process (cmd,
			  (["toggle_uid":1,
			    "stdin":stdin,
			    "stdout":stdout,
			    "stderr":stderr]));
}

// Add a few cache control related efuns
private object initiate_cache()
{
  object cache;
  cache=((program)"base_server/cache")();

  add_constant("http_decode_string", _Roxen.http_decode_string );
  add_constant("cache_clear_deltas", cache->cache_clear_deltas);
  add_constant("cache_set",    cache->cache_set);
  add_constant("cache_lookup", cache->cache_lookup);
  add_constant("cache_peek",   cache->cache_peek);
  add_constant("cache_remove", cache->cache_remove);
  add_constant("cache_expire", cache->cache_expire);
  add_constant("cache_expire_by_prefix", cache->cache_expire_by_prefix);
  add_constant("cache_clear",  cache->cache_expire);
  add_constant("cache_entries",cache->cache_entries);
  add_constant("cache_indices",cache->cache_indices);
  add_constant("CacheEntry",   cache->CacheEntry); // For cache_entries typing.

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
    if (has_prefix (file, d)) file = file[sizeof(d)..];
    if (has_prefix (file, server_dir)) file = file[sizeof(server_dir)..];
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

#if constant(Crypto.Password)
// Pike 7.9 and later.
constant verify_password = Crypto.Password.verify;
constant crypt_password = Crypto.Password.hash;

#else /* !Crypto.Password */

//! @appears verify_password
//!
//! Verify a password against a hash.
//!
//! This function attempts to support most
//! password hashing schemes.
//!
//! @returns
//!   Returns @expr{1@} on success, and @expr{0@} (zero) otherwise.
//!
//! @seealso
//!   @[hash_password()], @[predef::crypt()]
int verify_password(string password, string hash)
{
  if (hash == "") return 1;

  // Detect the password hashing scheme.
  // First check for an LDAP-style marker.
  string scheme = "crypt";
  sscanf(hash, "{%s}%s", scheme, hash);
  // NB: RFC2307 proscribes lower case schemes, while
  //     in practise they are usually in upper case.
  switch(lower_case(scheme)) {
  case "md5":	// RFC 2307
  case "smd5":
    hash = MIME.decode_base64(hash);
    password += hash[16..];
    hash = hash[..15];
    return Crypto.MD5.hash(password) == hash;

  case "sha":	// RFC 2307
  case "ssha":
    // SHA1 and Salted SHA1.
    hash = MIME.decode_base64(hash);
    password += hash[20..];
    hash = hash[..19];
    return Crypto.SHA1.hash(password) == hash;

  case "crypt":	// RFC 2307
    // First try the operating system's crypt(3C).
    if ((hash == "") || crypt(password, hash)) return 1;
    if (hash[0] != '$') {
      if (hash[0] == '_') {
	// FIXME: BSDI-style crypt(3C).
      }
      return 0;
    }

    // Then try our implementations.
    sscanf(hash, "$%s$%s$%s", scheme, string salt, string hash);
    int rounds = UNDEFINED;
    if (has_prefix(salt, "rounds=")) {
      sscanf(salt, "rounds=%d", rounds);
      sscanf(hash, "%s$%s", salt, hash);
    }
    switch(scheme) {
    case "1":	// crypt_md5
      return Nettle.crypt_md5(password, salt) == hash;

    case "2":	// Blowfish (obsolete)
    case "2a":	// Blowfish (possibly weak)
    case "2x":	// Blowfish (weak)
    case "2y":	// Blowfish (stronger)
      break;

    case "3":	// MD4 NT LANMANAGER (FreeBSD)
      break;

#if constant(Crypto.SHA256.crypt_hash)
      // cf http://www.akkadia.org/drepper/SHA-crypt.txt
    case "5":	// SHA-256
      return Crypto.SHA256.crypt_hash(password, salt, rounds) == hash;
#endif
#if constant(Crypto.SHA512.crypt_hash)
    case "6":	// SHA-512
      return Crypto.SHA512.crypt_hash(password, salt, rounds) == hash;
#endif
    }
    break;
  }
  return 0;
}

//! @appears crypt_password
//!
//! Generate a hash of @[password] suitable for @[verify_password()].
//!
//! @param password
//!   Password to hash.
//!
//! @param scheme
//!   Password hashing scheme. If not specified the strongest available
//!   will be used.
//!
//!   If an unsupported scheme is specified an error will be thrown.
//!
//! @param rounds
//!   The number of rounds to use in parameterized schemes. If not
//!   specified the scheme specific default will be used.
//!
//! @returns
//!   Returns a string suitable for @[verify_password()].
//!
//! @seealso
//!   @[verify_password], @[predef::crypt()], @[Nettle.crypt_md5()],
//!   @[Nettle.HashInfo()->crypt_hash()]
string crypt_password(string password, string|void scheme, int|void rounds)
{
  function(string, string, int:string) crypt_hash;
  int salt_size = 16;
  int default_rounds = 5000;
  switch(scheme) {
  case UNDEFINED:
    // FALL_THROUGH
#if constant(Crypto.SHA512.crypt_hash)
  case "6":
  case "$6$":
    crypt_hash = Crypto.SHA512.crypt_hash;
    scheme = "6";
    break;
#endif
#if constant(Crypto.SHA256.crypt_hash)
  case "5":
  case "$5$":
    crypt_hash = Crypto.SHA256.crypt_hash;
    scheme = "5";
    break;
#endif
#if constant(Crypto.MD5.crypt_hash)
  case "1":
  case "$1$":
    crypt_hash = Crypto.MD5.crypt_hash;
    salt_size = 8;
    rounds = 1000;		// Currently only 1000 rounds is supported.
    default_rounds = 1000;
    scheme = "1";
    break;
#endif
  case "":
    return crypt(password);
    // FIXME: Add support for SSHA?
  default:
    error("Unsupported hashing scheme: %O\n", scheme);
  }

  if (!rounds) rounds = default_rounds;

  // NB: The salt must be printable.
  string salt =
    MIME.encode_base64(Crypto.Random.random_string(salt_size))[..salt_size-1];

  string hash = crypt_hash(password, salt, rounds);

  if (rounds != default_rounds) {
    salt = "rounds=" + rounds + "$" + salt;
  }

  return sprintf("$%s$%s$%s", scheme, salt, hash);
}
#endif /* !Crypto.Password */

#ifdef THREADS
// This mutex is used by Privs
Thread.Mutex euid_egid_lock = Thread.Mutex();
#endif /* THREADS */

// Needed to get core dumps of seteuid()'ed processes on Linux.
#if constant(System.dumpable)
#define enable_coredumps(X)	System.dumpable(X)
#else
#define enable_coredumps(X)
#endif

/*
 * The privilege changer. Works like a mutex lock, but changes the UID/GID
 * while held. Blocks all threads.
 *
 * Based on privs.pike,v 1.36.
 */
int privs_level;

protected class Privs
{
#if constant(seteuid)

  int saved_uid;
  int saved_gid;

  int new_uid;
  int new_gid;

#define LOGP (roxen->variables && roxen->variables->audit && roxen->variables->audit->query())

#if constant(geteuid) && constant(getegid) && constant(seteuid) && constant(setegid)
#define HAVE_EFFECTIVE_USER
#endif

  private string _getcwd()
  {
    if (catch{return(getcwd());}) {
      return("Unknown directory (no x-bit on current directory?)");
    }
  }

  private string dbt(array t)
  {
    if(!arrayp(t) || (sizeof(t)<2)) return "";
    return (((t[0]||"Unknown program")-(_getcwd()+"/"))-"base_server/")+":"+t[1]+"\n";
  }

#ifdef THREADS
  protected mixed mutex_key; // Only one thread may modify the euid/egid at a time.
  protected object threads_disabled;
#endif /* THREADS */

  int p_level;

  void create(string reason, int|string|void uid, int|string|void gid)
  {
    // No need for Privs if the uid has been changed permanently.
    if(getuid()) return;

#ifdef PRIVS_DEBUG
    report_debug(sprintf("Privs(%O, %O, %O)\n"
			 "privs_level: %O\n",
			 reason, uid, gid, privs_level));
#endif /* PRIVS_DEBUG */

#ifdef HAVE_EFFECTIVE_USER
    array u;

#ifdef THREADS
    if (euid_egid_lock) {
      if (mixed err = catch { mutex_key = euid_egid_lock->lock(); })
	master()->handle_error (err);
    }
    threads_disabled = _disable_threads();
#endif /* THREADS */

    p_level = privs_level++;

    /* Needs to be here since root-priviliges may be needed to
     * use getpw{uid,nam}.
     */
    saved_uid = geteuid();
    saved_gid = getegid();
    seteuid(0);

    /* A string of digits? */
    if(stringp(uid) && (replace(uid,"0123456789"/"",({""})*10)==""))
      uid = (int)uid;

    if(stringp(gid) && (replace(gid, "0123456789"/"", ({"" })*10) == ""))
      gid = (int)gid;

    if(!stringp(uid))
      u = getpwuid(uid);
    else
    {
      u = getpwnam(uid);
      if(u)
	uid = u[2];
    }

    if(u && !gid)
      gid = u[3];

    if(!u)
    {
      if (uid && (uid != "root"))
      {
	if (intp(uid) && (uid >= 60000))
        {
	  report_warning(sprintf("Privs: User %d is not in the password database.\n"
				 "Assuming nobody.\n", uid));
	  // Nobody.
	  gid = gid || uid;	// Fake a gid also.
	  u = ({ "fake-nobody", "x", uid, gid, "A real nobody", "/", "/sbin/sh" });
	} else {
	  error("Unknown user: "+uid+"\n");
	}
      } else {
	u = ({ "root", "x", 0, gid, "The super-user", "/", "/sbin/sh" });
      }
    }

    if(LOGP)
      report_notice(LOC_M(1, "Change to %s(%d):%d privs wanted (%s), from %s"),
		    (string)u[0], (int)uid, (int)gid,
		    (string)reason,
		    (string)dbt(backtrace()[-2]));

    if (u[2]) {
#if constant(cleargroups)
      if (mixed err = catch { cleargroups(); })
	master()->handle_error (err);
#endif /* cleargroups */
#if constant(initgroups)
      if (mixed err = catch { initgroups(u[0], u[3]); })
	master()->handle_error (err);
#endif
    }
    gid = gid || getgid();
    int err = (int)setegid(new_gid = gid);
    if (err < 0) {
      report_warning(LOC_M(2, "Privs: WARNING: Failed to set the "
			   "effective group id to %d!\n"
			   "Check that your password database is correct "
			   "for user %s(%d),\n and that your group "
			   "database is correct.\n"),
		     gid, (string)u[0], (int)uid);
      int gid2 = gid;
#ifdef HPUX_KLUDGE
      if (gid >= 60000) {
	/* HPUX has doesn't like groups higher than 60000,
	 * but has assigned nobody to group 60001 (which isn't even
	 * in /etc/group!).
	 *
	 * HPUX's libc also insists on filling numeric fields it doesn't like
	 * with the value 60001!
	 */
	report_debug("Privs: WARNING: Assuming nobody-group.\n"
	       "Trying some alternatives...\n");
	// Assume we want the nobody group, and try a couple of alternatives
	foreach(({ 60001, 65534, -2 }), gid2) {
	  report_debug("%d... ", gid2);
	  if (initgroups(u[0], gid2) >= 0) {
	    if ((err = setegid(new_gid = gid2)) >= 0) {
	      report_debug("Success!\n");
	      break;
	    }
	  }
	}
      }
#endif /* HPUX_KLUDGE */
      if (err < 0) {
	report_debug("Privs: Failed\n");
	error ("Failed to set EGID to %d\n", gid);
      }
      report_debug("Privs: WARNING: Set egid to %d instead of %d.\n",
	     gid2, gid);
      gid = gid2;
    }
    if(getgid()!=gid) setgid(gid||getgid());
    seteuid(new_uid = uid);
    enable_coredumps(1);
#endif /* HAVE_EFFECTIVE_USER */
  }

  void destroy()
  {
    // No need for Privs if the uid has been changed permanently.
    if(getuid()) return;

#ifdef PRIVS_DEBUG
    report_debug(sprintf("Privs->destroy()\n"
			 "privs_level: %O\n",
			 privs_level));
#endif /* PRIVS_DEBUG */

#ifdef HAVE_EFFECTIVE_USER
    /* Check that we don't increase the privs level */
    if (p_level >= privs_level) {
      report_error(sprintf("Change back to uid#%d gid#%d from uid#%d gid#%d\n"
			   "in wrong order! Saved level:%d Current level:%d\n"
			   "Occurs in:\n%s\n",
			   saved_uid, saved_gid, new_uid, new_gid,
			   p_level, privs_level,
			   describe_backtrace(backtrace())));
      return(0);
    }
    if (p_level != privs_level-1) {
      report_error(sprintf("Change back to uid#%d gid#%d from uid#%d gid#%d\n"
			   "Skips privs level. Saved level:%d Current level:%d\n"
			   "Occurs in:\n%s\n",
			   saved_uid, saved_gid, new_uid, new_gid,
			   p_level, privs_level,
			   describe_backtrace(backtrace())));
    }
    privs_level = p_level;

    if(LOGP) {
      if (mixed err = catch {
	array bt = backtrace();
	if (sizeof(bt) >= 2) {
	  report_notice(LOC_M(3,"Change back to uid#%d gid#%d, from %s")+"\n",
			saved_uid, saved_gid, dbt(bt[-2]));
	} else {
	  report_notice(LOC_M(4,"Change back to uid#%d gid#%d, "
			      "from backend")+"\n", saved_uid, saved_gid);
	}
	})
	master()->handle_error (err);
    }

#ifdef PRIVS_DEBUG
    int uid = geteuid();
    if (uid != new_uid) {
      report_debug("Privs: UID #%d differs from expected #%d\n"
		   "%s\n",
		   uid, new_uid, describe_backtrace(backtrace()));
    }
    int gid = getegid();
    if (gid != new_gid) {
      report_debug("Privs: GID #%d differs from expected #%d\n"
		   "%s\n",
		   gid, new_gid, describe_backtrace(backtrace()));
    }
#endif /* PRIVS_DEBUG */

    seteuid(0);
    array u = getpwuid(saved_uid);
#if constant(cleargroups)
    if (mixed err = catch { cleargroups(); })
      master()->handle_error (err);
#endif /* cleargroups */
    if(u && (sizeof(u) > 3)) {
      if (mixed err = catch { initgroups(u[0], u[3]); })
	master()->handle_error (err);
    }
    setegid(saved_gid);
    seteuid(saved_uid);
    enable_coredumps(1);
#endif /* HAVE_EFFECTIVE_USER */
  }
#else /* constant(seteuid) */
  void create(string reason, int|string|void uid, int|string|void gid){}
#endif /* constant(seteuid) */
}

class RoxenConcurrent
{
  inherit Concurrent;

  class Promise
  {
    inherit ::this_program;

    private string describe_funcall(Pike.BacktraceFrame frame)
    {
      string fun;
      if (stringp(frame[2])) {
	fun = frame[2];
      } else {
	fun = master()->describe_function(frame[2]);
      }
      return sprintf("%s(%s)",
		     fun,
		     master()->Describer()->
		     describe_comma_list(frame[3..], 99999));
    }

    private string describe_initiator()
    {
      foreach(reverse(backtrace()), Pike.BacktraceFrame frame) {
	mixed fun = frame[2];
	if (callablep(fun)) {
	  object o = function_object(fun);
	  if ((o == this_object()) || (object_program(o) == RoxenConcurrent)) {
	    continue;
	  }
	}
	return describe_funcall(frame);
      }
      return UNDEFINED;
    }

    protected string initiator = describe_initiator();

#ifdef THREADS
    protected class HandlerBackend
    {
      array call_out(function co, int t, mixed ... args)
      {
	if (roxen && !t) {
	  roxen->low_handle(co, @args);
	  return 0;
	} else {
	  return predef::call_out(roxen->low_handle, t, co, @args);
	}
      }

      void remove_call_out(function|array co)
      {
	if (!co) return;
	predef::remove_call_out(co);
      }
    }

    protected Pike.Backend backend = HandlerBackend();
#endif /* THREADS */

    protected string _sprintf(int c)
    {
      if (c == 'O') {
	return sprintf("%O(/* %s */)", object_program(this), initiator || "");
      }
      return UNDEFINED;
    }
  }
}

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

#if constant(DefaultCompilerEnvironment)
#if (__REAL_MAJOR__ == 8) && (__REAL_MINOR__ == 0) && (__REAL_BUILD__ < 694)
  /* Workaround for [PIKE-126]. */
  add_constant("_disable_threads", _disable_threads);
#endif
#endif

  add_constant("Concurrent", RoxenConcurrent());
  add_constant("PikeConcurrent", Concurrent);

  DC( "Roxen" );

  roxen = really_load_roxen();
}


#ifndef OLD_PARSE_HTML

protected int|string|array(string) compat_call_tag (
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

protected int|string|array(string) compat_call_container (
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

protected int|string|array(string) compat_call_tag_lines (
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

protected int|string|array(string) compat_call_container_lines (
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

protected local mapping fd_marks = ([]);

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

protected string release;
protected string dist_version;
protected string dist_os;
protected int roxen_is_cms;
protected string roxen_product_name;
protected string roxen_product_code;

protected string mysql_product_name;
protected string mysql_version;

protected constant mysql_good_versions = ({ "5.5.*", "5.6.*" });
protected constant mariadb_good_versions = ({ "5.5.*", "10.0.*", "10.1.*", "10.3.*" });
protected constant mysql_maybe_versions = ({ "5.*", "6.*" });
protected constant mariadb_maybe_versions = ({ "5.*", "10.*", "11.*" });
protected constant mysql_bad_versions = ({});
protected constant mariadb_bad_versions = ({ "10.2.*" });

string roxen_version()
//! @appears roxen_version
{
  // Note: roxen_release is usually "-cvs" at the time this is compiled.
  return roxen_ver+"."+roxen_build+(release||roxen_release);
}

//! @appears roxen_path
//!
//! Expands the following paths in the given string and returns the
//! result. If on Windows, also strips off trailing slashes.
//!
//! @string
//!   @value "$LOCALDIR"
//!     The local directory of the web server, Normally "../local",
//!     but it can be changed in by setting the environment
//!     variable LOCALDIR.
//!   @value "$LOGDIR"
//!     The log directory of the web server. Normally "../logs",
//!     but it can be changed in the configuration interface under
//!     global settings.
//!   @value "$LOGFILE"
//!     The debug log of the web server. Normally
//!     "../logs/debug/default.1", but it can be the name of the
//!     configuration directory if multiple instances are used.
//!   @value "$VARDIR"
//!     The web server's var directory. Normally "../var", but it can
//!     be changed by setting the environment variable VARDIR.
//!   @value "$VVARDIR"
//!     Same as $VARDIR, but with a server version specific subdirectory.
//!   @value "$SERVERDIR"
//!     Base path for the version-specific installation directory.
//! @endstring
string roxen_path( string filename )
{
  filename = replace( filename,
		      ({"$VVARDIR","$LOCALDIR","$LOGFILE","$SERVERDIR"}),
                      ({"$VARDIR/"+roxen_version(),
                        getenv ("LOCALDIR") || "../local",
			getenv ("LOGFILE") || "$LOGDIR/debug/default.1",
			server_dir }) );
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
//! @appears r_get_dir
//! Like @[predef::get_dir], but processes the path with @[roxen_path].
{
  return predef::get_dir( roxen_path( path ) );
}

int mv( string f1, string f2 )
{
  return predef::mv( roxen_path(f1), roxen_path( f2 ) );
}

int r_cp( string f1, string f2 )
//! @appears r_cp
//! Like @[Stdio.cp], but processes the paths with @[roxen_path].
{
  return Stdio.cp( roxen_path(f1), roxen_path( f2 ) );
}

Stdio.Stat file_stat( string filename, int|void slinks )
{
  return predef::file_stat( roxen_path(filename), slinks );
}

// Like the other wrappers above, the following get the "r_" prefix
// when they're added as constants, so it makes no sense to have
// different names for the real functions in this file.

int r_is_file (string path)
//! @appears r_is_file
//! Like @[Stdio.is_file], but processes the path with @[roxen_path].
{
  return Stdio.is_file (roxen_path (path));
}

int r_is_dir (string path)
//! @appears r_is_dir
//! Like @[Stdio.is_dir], but processes the path with @[roxen_path].
{
  return Stdio.is_dir (roxen_path (path));
}

int r_is_link (string path)
//! @appears r_is_link
//! Like @[Stdio.is_link], but processes the path with @[roxen_path].
{
  return Stdio.is_link (roxen_path (path));
}

int r_exist (string path)
//! @appears r_exist
//! Like @[Stdio.exist], but processes the path with @[roxen_path].
{
  return Stdio.exist (roxen_path (path));
}

string r_read_bytes (string filename, mixed... args)
//! @appears r_read_bytes
//! Like @[Stdio.read_bytes], but processes the path with @[roxen_path].
{
  return Stdio.read_bytes (roxen_path (filename), @args);
}

//! @appears open
//! Like @[Stdio.File.open] on a new file object, but processes the
//! path with @[roxen_path]. Returns zero on open error.
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

array(string) default_roxen_font_path =
  ({ "nfonts/",
#ifdef __NT__
     combine_path(replace(getenv("SystemRoot"), "\\", "/"), "fonts/")
#else
     @((getenv("RX_FONTPATH") || "")/"," - ({""}))
#endif
  });
array(string) package_module_path = ({ });

array(string) package_directories = ({ });

void add_package(string package_dir)
{
  string ver = r_read_bytes(combine_path(package_dir, "VERSION"));
  if (ver && (ver != "")) {
    report_debug("Adding package %s (Version %s).\n",
		 roxen_path (package_dir), ver - "\n");
  } else {
    report_debug("Adding package %s.\n",
		 roxen_path (package_dir));
  }
  package_directories += ({ package_dir });
  string real_pkg_dir = roxen_path (package_dir);
  string sub_dir = combine_path(real_pkg_dir, "pike-modules");
  if (Stdio.is_dir(sub_dir)) {
    master()->add_module_path(sub_dir);
  }
  if (Stdio.is_dir(sub_dir = combine_path(real_pkg_dir, "include/"))) {
    master()->add_include_path(sub_dir);
  }
#ifdef RUN_SELF_TEST
  sub_dir = combine_path(real_pkg_dir, "test/pike-modules");
  if (Stdio.is_dir(sub_dir)) {
    master()->add_module_path(sub_dir);
  }
  if (Stdio.is_dir(sub_dir = combine_path(real_pkg_dir, "test/include/"))) {
    master()->add_include_path(sub_dir);
  }
#endif

  package_module_path += ({ combine_path(package_dir, "modules/") });
  if (r_is_dir(sub_dir = combine_path(package_dir, "roxen-modules/"))) {
    package_module_path += ({ sub_dir });
  }
  if (r_is_dir(sub_dir = combine_path(package_dir, "fonts/"))) {
    default_roxen_font_path += ({ sub_dir });
  }
#ifdef RUN_SELF_TEST
  if (r_is_dir(sub_dir = combine_path(package_dir, "test/modules/"))) {
    package_module_path += ({ sub_dir });
  }
#endif
}


//! @appears lopen
object|void lopen(string filename, string mode, int|void perm)
{
  if( filename[0] != '/' ) {
    foreach(package_directories, string dir) {
      Stdio.File o;
      if (o = open(combine_path(roxen_path(dir), filename), mode, perm))
	return o;
    }
  }
  return open( filename, mode, perm );
}

//! @appears lfile_stat
object(Stdio.Stat) lfile_stat(string filename)
{
  if (filename[0] != '/') {
    foreach(package_directories, string dir) {
      Stdio.Stat res;
      if (res = file_stat(combine_path(roxen_path(dir), filename)))
	return res;
    }
  }
  return file_stat(filename);
}

//! @appears lfile_path
string lfile_path(string filename)
{
  if (filename[0] != '/') {
    foreach(package_directories, string dir) {
      string path = combine_path(roxen_path(dir), filename);
      if (file_stat(path)) return path;
    }
  }
  return file_stat(filename) && filename;
}

// Make a $PATH-style string
string make_path(string ... from)
{
  return map(from, lambda(string a, string b) {
    return (a[0]=='/')?combine_path("/",a):combine_path(b,a);
    //return combine_path(b,a);
  }, server_dir)*":";
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
#if constant(geteuid)
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
  Protocols.HTTP; // FIXME: Workaround for bug 2637.

#if __VERSION__ < 8.0
    report_debug(
#"
------- FATAL -------------------------------------------------
Roxen 6.0 should be run with Pike 8.0 or newer.
---------------------------------------------------------------
");
    exit(1);
#endif

#if !constant(utf8_string)
  // Not present in Pike 8.0 and earlier.
  add_constant("utf8_string", utf8_string);
#endif

  // Check if IPv6 support is available.
  if (mixed err = catch {
    // Note: Attempt to open a port on the IPv6 loopback (::1)
    //       rather than on IPv6 any (::), to make sure some
    //       IPv6 support is actually configured. This is needed
    //       since eg Solaris happily opens ports on :: even
    //       if no IPv6 interfaces are configured.
    //       Try IPv6 any (::) too for paranoia reasons.
    string interface;
    Stdio.Port p = Stdio.Port();
    if (p->bind(0, 0, interface = "::1") &&
	p->bind(0, 0, interface = "::")) {
      add_constant("__ROXEN_SUPPORTS_IPV6__", 1);
      report_debug("Support for IPv6 enabled.\n");
    }
    else
      report_debug ("IPv6 support check failed: Could not bind %s: %s\n",
		    interface, strerror (p->errno()));
    destruct(p);
  })
    report_debug ("IPv6 support check failed: %s",
#ifdef DEBUG
		  describe_backtrace (err)
#else
		  describe_error (err)
#endif
		 );

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

  // Get build OS for dist
  dist_os =
    (replace(Stdio.read_bytes("OS") || "src dist", "\r", "\n") / "\n")[0];
  
  // Get package directories.
  add_package("$LOCALDIR");
  foreach(package_directories + ({ "." }), string dir) {
    dir = combine_path(dir, "packages");
    foreach(sort(get_dir(roxen_path(dir)) || ({})), string fname) {
      if (fname == "CVS") continue;
      fname = combine_path(dir, fname);
      if (Stdio.is_dir(roxen_path(fname))) {
	add_package(fname);
      }
    }
  }

  roxen_is_cms = !!lfile_stat("modules/sitebuilder") ||
    !!lfile_stat("packages/sitebuilder");

  if(roxen_is_cms) {
    if (lfile_stat("modules/print") || lfile_stat("packages/print")) {
      roxen_product_name="Roxen EP";
      roxen_product_code = "rep";
    } else {
      roxen_product_name="Roxen CMS";
      roxen_product_code = "cms";
    }
  } else {
    roxen_product_name="Roxen WebServer";
    roxen_product_code = "webserver";
  }

#if defined(ROXEN_USE_FORKD) && constant(Process.set_forkd_default)
  report_debug("Enabling use of forkd daemon.\n");
  Process.set_forkd_default(1);
#endif

  // The default (internally managed) mysql path
  string defpath =
#ifdef __NT__
    // Use pipes with a name created from the config dir
    "mysql://%user%@.:" + query_mysql_socket() + "/%db%";
#else
    "mysql://%user%@localhost:" + query_mysql_socket() + "/%db%";
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

#if constant(MIME.set_boundary_prefix)
  // Set MIME message boundary prefix.
  string boundary_prefix = Standards.UUID.make_version4()->str();
  boundary_prefix = (boundary_prefix / "-") * "";
  MIME.set_boundary_prefix(boundary_prefix);
#endif

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


protected mapping(string:string) cached_mysql_location;

//!  Returns a mapping with the following MySQL-related paths:
//!
//!  @code
//!    ([
//!       "basedir"       : <absolute path to MySQL server directory>
//!       "mysqld"        : <absolute path to mysqld[-nt.exe]>
//!       "myisamchk"     : <absolute path to myisamchk[.exe]>
//!       "mysqldump"     : <absolute path to mysqldump[.exe]>
//!       "mysql_upgrade" : <absolute path to mysql_upgrade[.exe]>
//!    ])
//!  @endcode
//!
//!  If a path cannot be resolved it will be set to 0.
//!
//!  The paths are read from "mysql-location.txt" in the server-x.y.z
//!  directory. If that file doesn't exist then default values based
//!  on the server-x.y.z/mysql/ subdirectory will be substituted.
//!
//!  @note
//!  Don't be destructive on the returned mapping.
mapping(string:string) mysql_location()
{
  if (cached_mysql_location)
    return cached_mysql_location;

  string check_paths(array(string) paths)
  {
    foreach(paths, string p)
      if (file_stat(p))
	return p;
    return 0;
  };

  multiset(string) valid_keys =
    //  NOTE: "mysqladmin" not used but listed here since NT starter
    //  looks for it.
    (< "basedir", "mysqld", "myisamchk", "mysqladmin", "mysqldump",
       "mysql_upgrade",
    >);
  
  //  If the path file is missing we fall back on the traditional
  //  /mysql/ subdirectory. The file should contain lines on this
  //  format:
  //
  //    # comment
  //    key1 = value
  //    key2 = value
  //
  //  All non-absolute paths will be interpreted relative to server-x.y.z.
  
  mapping res = ([ "basedir" : combine_path(server_dir, "mysql/") ]);

  string mysql_loc_file = combine_path(server_dir, "mysql-location.txt");
  if (string data = Stdio.read_bytes(mysql_loc_file)) {
    data = replace(replace(data, "\r\n", "\n"), "\r", "\n");
    foreach(data / "\n", string line) {
      line = String.trim_whites((line / "#")[0]);
      if (sizeof(line)) {
	sscanf(line, "%[^ \t=]%*[ \t]=%*[ \t]%s", string key, string val);
	if (key && val && sizeof(val)) {
	  //  Check for valid key
	  key = lower_case(key);
	  if (!valid_keys[key]) {
	    report_warning("mysql-location.txt: Unknown key '%s'.\n", key);
	    continue;
	  }
	  
	  //  Convert to absolute path and check for existence
	  if (val[0] == '"' || val[0] == '\'')
	    val = val[1..];
	  if (sizeof(val))
	    if (val[-1] == '"' || val[-1] == '\'')
	      val = val[..sizeof(val) - 2];
	  string path = combine_path(server_dir, val);
	  if (check_paths( ({ path }) )) {
	    res[key] = path;
	  } else {
	    report_warning("mysql-location.txt: "
			   "Ignoring non-existing path for key '%s': %s\n",
			   key, path);
	  }
	}
      }
    }
  }
  
  //  Find specific paths derived from the MySQL base directory
  if (res->basedir) {
    //  Locate mysqld
    if (!res->mysqld) {
#ifdef __NT__
      string binary = "mysqld-nt.exe";
#else
      string binary = "mysqld";
#endif
      res->mysqld =
	check_paths( ({ combine_path(res->basedir, "libexec", binary),
			combine_path(res->basedir, "bin", binary),
			combine_path(res->basedir, "sbin", binary) }) );
    }
    
    //  Locate myisamchk
    if (!res->myisamchk) {
#ifdef __NT__
      string binary = "myisamchk.exe";
#else
      string binary = "myisamchk";
#endif
      res->myisamchk =
	check_paths( ({ combine_path(res->basedir, "libexec", binary),
			combine_path(res->basedir, "bin", binary),
			combine_path(res->basedir, "sbin", binary) }) );
    }

    //  Locate mysqldump
    if (!res->mysqldump) {
#ifdef __NT__
      string binary = "mysqldump.exe";
#else
      string binary = "mysqldump";
#endif
      res->mysqldump =
	check_paths( ({ combine_path(res->basedir, "libexec", binary),
			combine_path(res->basedir, "bin", binary),
			combine_path(res->basedir, "sbin", binary) }) );
    }

    //  Locate mysql_upgrade
    if (!res->mysql_upgrade) {
#ifdef __NT__
      string binary = "mysql_upgrade.exe";
#else
      string binary = "mysql_upgrade";
#endif
      res->mysql_upgrade =
	check_paths( ({ combine_path(res->basedir, "libexec", binary),
			combine_path(res->basedir, "bin", binary),
			combine_path(res->basedir, "sbin", binary) }) );
    }
  }
  
  return cached_mysql_location = res;
}

mapping(string:string) parse_mysql_location()
// Compatibility alias.
{
  return mysql_location();
}

string query_mysql_data_dir()
{
  string old_dir = combine_path(getcwd(), query_configuration_dir(), "_mysql");
  string new_dir, datadir = getenv("ROXEN_DATADIR");
  if(datadir)
    new_dir = combine_path(getcwd(), datadir, "mysql");
  if(new_dir && Stdio.exist(new_dir))
    return new_dir;
  if(Stdio.exist(old_dir))
    return old_dir;
  if(new_dir)
    return new_dir;
  return old_dir;
}

string query_mysql_socket()
{
#ifdef __NT__
  return replace(combine_path(query_mysql_data_dir(), "pipe"), ":", "_");
#else
  return combine_path(query_mysql_data_dir(), "socket");
#endif
}

string query_mysql_config_file(string|void datadir)
{
  datadir = datadir || query_mysql_data_dir();
  return datadir + "/my.cfg";
}

string  my_mysql_path;

string query_configuration_dir()
{
  return configuration_dir;
}

protected mapping(string:array(SQLTimeout)) sql_free_list = ([ ]);
protected Thread.Local sql_reuse_in_thread = Thread.Local();
mapping(string:int) sql_active_list = ([ ]);

#ifdef DB_DEBUG
#ifdef OBJ_COUNT_DEBUG
mapping(int:string) my_mysql_last_user = ([]);
#endif
multiset(Sql.Sql) all_wrapped_sql_objects = set_weak_flag( (<>), 1 );
#endif /* DB_DEBUG */


//! @appears clear_connect_to_my_mysql_cache
void clear_connect_to_my_mysql_cache( )
{
  sql_free_list = ([]);
}

//  Helper function for DB status tab in Admin interface
mapping(string:int) get_sql_free_list_status()
{
  return map(sql_free_list, sizeof);
}

#ifndef DB_CONNECTION_TIMEOUT
// 1 minute timeout by default.
#define DB_CONNECTION_TIMEOUT 60
#endif

protected class SQLTimeout(protected Sql.Sql real)
{
  protected int timeout = time(1) + DB_CONNECTION_TIMEOUT;

  protected int(0..1) `!()
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
    if (timeout - time(1) < (DB_CONNECTION_TIMEOUT - 10)) {
      // Idle more than 10 seconds.
      // - Check that the connection still is alive.
      if (real->ping()) real = 0;
    } else {
      // Idle less than 10 seconds.
      // - Just check that the connection hasn't been closed.
      if (!real->is_open()) real = 0;
    }
    Sql.Sql res = real;
    real = 0;
    return res;
  }
}

//!
protected class SQLResKey
{
  protected Sql.sql_result real;
  protected SQLKey key;

  //! @ignore
  DECLARE_OBJ_COUNT;
  //! @endignore

  protected void create (Sql.sql_result real, SQLKey key)
  {
    this_program::real = real;
    this_program::key = key;
  }

  // Proxy functions:
  // Why are these needed? /mast
  protected int num_rows()
  {
    return real->num_rows();
  }
  protected int num_fields()
  {
    return real->num_fields();
  }
  protected int eof()
  {
    return real->eof();
  }
  protected array(mapping(string:mixed)) fetch_fields()
  {
    return real->fetch_fields();
  }
  protected void seek(int skip)
  {
    real->seek(skip);
  }
  protected int|array(string|int) fetch_row()
  {
    return real->fetch_row();
  }
  protected int|string fetch_json_result()
  {
    return real->fetch_json_result();
  }

  protected int(0..1) `!()
  {
    return !real;
  }

  // Iterator copied from Sql.sql_result. It's less hassle to
  // implement our own than to wrap the real one.
  class _get_iterator
  {
    protected int|array(string|int) row = fetch_row();
    protected int pos = 0;

    int index()
    {
      return pos;
    }

    int|array(string|int) value()
    {
      return row;
    }

    int(0..1) next()
    {
      pos++;
      return !!(row = fetch_row());
    }

    this_program `+=(int steps)
    {
      if(!steps) return this;
      if(steps<0) error("Iterator must advance a positive number of steps.\n");
      if(steps>1)
      {
	pos += steps-1;
	seek(steps-1);
      }
      next();
      return this;
    }

    int(0..1) `!()
    {
      return eof();
    }

    int _sizeof()
    {
      return num_fields();
    }
  }

  protected mixed `[]( string what )
  {
    return `->( what );
  }
  protected mixed `->(string what )
  {
    switch( what )
    {
    case "real":              return real;
    case "num_rows":          return num_rows;
    case "num_fields":        return num_fields;
    case "eof":               return eof;
    case "fetch_fields":      return fetch_fields;
    case "seek":              return seek;
    case "fetch_row":         return fetch_row;
    case "_get_iterator":     return _get_iterator;
    case "fetch_json_result": return fetch_json_result;
    }
    return real[what];
  }

  protected string _sprintf(int type)
  {
    return sprintf( "SQLResKey(%O)" + OBJ_COUNT, real );
  }

  protected void destroy()
  {
    if (key->reuse_in_thread) {
      // FIXME: This won't work well; destroy() might get called from
      // any thread when an object is refcount garbed.
      mapping(string:Sql.Sql) dbs_for_thread = sql_reuse_in_thread->get();
      if (!dbs_for_thread[key->db_name])
	dbs_for_thread[key->db_name] = key->real;
    }
#if 0
    werror("Destroying %O\n", this_object());
#endif
  }
}

//!
protected class SQLKey
{
  protected Sql.Sql real;
  protected string db_name;
  protected int reuse_in_thread;

  protected int `!( )  { return !real; }

  protected void handle_db_error (mixed err)
  {
    // FIXME: Ugly way of recognizing connect errors. If these errors
    // happen the connection is not welcome back to the pool.
    string errmsg = describe_error (err);
    if (has_prefix (errmsg, "Mysql.mysql(): Couldn't connect ") ||
	has_prefix (errmsg, "Mysql.mysql(): Couldn't reconnect ") ||
	has_suffix (errmsg, "(MySQL server has gone away)\n")) {
      if (reuse_in_thread) {
	mapping(string:Sql.Sql) dbs_for_thread = sql_reuse_in_thread->get();
	if (dbs_for_thread[db_name] == real)
	  m_delete (dbs_for_thread, db_name);
      }
      real = 0;
    }
    throw (err);
  }

  array(mapping) query( string f, mixed ... args )
  {
    mixed err = catch {
	return real->query( f, @args );
      };
    handle_db_error (err);
  }

  Sql.sql_result big_query( string f, mixed ... args )
  {
    Sql.sql_result o;
    if (mixed err = catch (o = real->big_query( f, @args )))
      handle_db_error (err);
    if (reuse_in_thread) {
      mapping(string:Sql.Sql) dbs_for_thread = sql_reuse_in_thread->get();
      if (dbs_for_thread[db_name] == real)
	m_delete (dbs_for_thread, db_name);
    }
    return [object(Sql.sql_result)] (object) SQLResKey (o, this);
  }

  //! @ignore
  DECLARE_OBJ_COUNT;
  //! @endignore
#ifdef DB_DEBUG
  protected string bt;
#endif
  protected void create( Sql.Sql real, string db_name, int reuse_in_thread)
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
    if( !real )
      error("Creating SQL with empty real sql\n");

    foreach( (array)all_wrapped_sql_objects, Sql.Sql sql )
    {
      if( sql )
	if( sql == real )
	  error("Fatal: This database connection is already used!\n");
	else if( sql->master_sql == real->master_sql )
	  error("Fatal: Internal share error: master_sql equal!\n");
    }

    all_wrapped_sql_objects[real] = 1;
#if 0
    // Disabled, since it seems to have bad side-effects :-(
#ifdef OBJ_COUNT_DEBUG
    bt=(my_mysql_last_user[__object_count] = describe_backtrace(backtrace()));
#endif
#endif
#endif /* DB_DEBUG */
  }
  
  protected void destroy()
  {
    // FIXME: Ought to be abstracted to an sq_cache_free().
#ifdef DB_DEBUG
    all_wrapped_sql_objects[real]=0;
#endif

    if (reuse_in_thread) {
      // FIXME: This won't work well; destroy() might get called from
      // any thread when an object is refcount garbed.
      mapping(string:Sql.Sql) dbs_for_thread = sql_reuse_in_thread->get();
      if (dbs_for_thread[db_name] == real) {
	m_delete (dbs_for_thread, db_name);
	if (!sizeof (dbs_for_thread)) sql_reuse_in_thread->set (0);
      }
    }

    if (!real) return;

#ifndef NO_DB_REUSE
    mixed key;
    catch {
      key = sq_cache_lock();
    };
    
#ifdef DB_DEBUG
    werror("%O added to free list\n", this );
#ifdef OBJ_COUNT_DEBUG
    m_delete(my_mysql_last_user, __object_count);
#endif
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

  protected mixed `[]( string what )
  {
    return `->( what );
  }
  
  protected mixed `->(string what )
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

  protected string _sprintf(int type)
  {
    string display_name = db_name || "";
    if (has_suffix(display_name, ":-")) {
      // Unmangle the mangling from DBManager.sql_cache_get().
      display_name = replace(display_name[..<2], ";", ":");
    }
    array(string) a = display_name/"://";
    string prot = a[0];
    string host = a[1..] * "://";
    a = host/"@";
    if (sizeof(a) > 1) {
      host = a[-1];
      a = (a[..<1] * "@")/":";
      string user = a[0];
      if (sizeof(a) > 1) {
	display_name = prot + "://" + user + ":CENSORED@" + host;
      }
    }
    return sprintf( "SQLKey(%O, %O)" + OBJ_COUNT, display_name, real );
  }
}

protected Thread.Mutex mt = Thread.Mutex();
Thread.MutexKey sq_cache_lock()
{
  return mt->lock();
}

protected mapping(program:string) default_db_charsets = ([]);

//! Get a cached connection to an SQL database.
//!
//! @param db_name
//!   SQL-URL for the connection.
//!
//! @param reuse_in_thread
//!   Use a thread-dedicated cache.
Sql.Sql sq_cache_get( string db_name, void|int reuse_in_thread)
{
  Sql.Sql db;
  Thread.MutexKey key = sq_cache_lock();

  if (reuse_in_thread) {
    mapping(string:Sql.Sql) dbs_for_thread = sql_reuse_in_thread->get();
    db = dbs_for_thread && dbs_for_thread[db_name];
  }

  else {
    while(sizeof(sql_free_list[db_name] || ({})))
    {
#ifdef DB_DEBUG
      werror("%O found in free list\n", db_name );
#endif
      SQLTimeout res = sql_free_list[db_name][0];
      if( sizeof( sql_free_list[ db_name ] ) > 1)
	sql_free_list[ db_name ] = sql_free_list[db_name][1..];
      else
	m_delete( sql_free_list, db_name );
      if (res) {
	destruct(key);
	// NB: Release the lock during connection validation. Cf [WS-28].
	if ((db = res->get()) && db->is_open()) {
	  key = sq_cache_lock();
	  sql_active_list[db_name]++;
	  break;
	}
	key = sq_cache_lock();
      }
    }
  }

  if (db)
    return [object(Sql.Sql)] (object) SQLKey (db, db_name, reuse_in_thread);
  return 0;
}

Sql.Sql fix_connection_charset (Sql.Sql db, string charset)
{
  if (object master_sql = db->master_sql) {
    if (mixed err = catch {

	if (master_sql->set_charset) {
	  if (!charset)
	    charset = default_db_charsets[object_program (master_sql)];

	  if ((charset == "unicode" || charset == "broken-unicode") &&
	      master_sql->get_unicode_encode_mode) {
	    // Unicode mode requested and the sql backend seems to
	    // support it (a better recognition flag would be nice).
	    // Detect if it's already enabled through
	    // get_unicode_encode_mode and get_unicode_decode_mode. It's
	    // enabled iff both return true.
	    if (!(master_sql->get_unicode_encode_mode() &&
		  master_sql->get_unicode_decode_mode()))
	      master_sql->set_charset (charset);
	  }

	  else {
	    if (master_sql->set_unicode_decode_mode &&
		master_sql->get_unicode_decode_mode())
	      // Ugly special case for mysql: The set_charset call does
	      // not reset this state.
	      master_sql->set_unicode_decode_mode (0);
	    if (charset != master_sql->get_charset())
	      master_sql->set_charset (charset);
	  }
	}

      })
    {
      // Since SQLKey (currently) doesn't wrap master_sql, be careful
      // to destroy the wrapper object on errors above so we don't
      // risk getting an object with a strange charset state in the cache.
      if (db) destruct (db);
      throw (err);
    }
  }

  return db;
}

#define FIX_CHARSET_FOR_NEW_SQL_CONN(SQLOBJ, CHARSET) do {		\
    if (object master_sql = SQLOBJ->master_sql)				\
      if (master_sql->set_charset) {					\
	if (zero_type (default_db_charsets[object_program (master_sql)])) \
	  default_db_charsets[object_program (master_sql)] =		\
	    SQLOBJ->get_charset();					\
	if (CHARSET) SQLOBJ->set_charset (CHARSET);			\
      }									\
  } while (0)

Sql.Sql sq_cache_set( string db_name, Sql.Sql res,
		      void|int reuse_in_thread, void|string charset)
// Should only be called with a "virgin" Sql.Sql object that has never
// been used or had its charset changed.
{
  if( res )
  {
    FIX_CHARSET_FOR_NEW_SQL_CONN (res, charset);
    Thread.MutexKey key = sq_cache_lock();
    sql_active_list[ db_name ]++;
    return [object(Sql.Sql)] (object) SQLKey( res, db_name, reuse_in_thread);
  }
}

/* Not to be documented. This is a low-level function that should be
 * avoided by normal users. 
*/
Sql.Sql connect_to_my_mysql( string|int ro, void|string db,
			     void|int reuse_in_thread, void|string charset)
{
#if 0
#ifdef DB_DEBUG
  gc();
#endif
#endif
  string i = db+":"+(intp(ro)?(ro&&"ro")||"rw":ro);
  Sql.Sql res;
  if (catch {
      res = sq_cache_get(i, reuse_in_thread);
    }) {
    // Threads disabled.
    // This can occur if we are called from the compiler.
    // NB: This is probably dead code with Pike 8.0 and later,
    //     as the compiler no longer disables all threads.
    Sql.Sql res = low_connect_to_my_mysql(ro, db);
    FIX_CHARSET_FOR_NEW_SQL_CONN (res, charset);
    return res;
  }
  if (res) {
    return fix_connection_charset (res, charset);
  }
  if (res = low_connect_to_my_mysql( ro, db )) {
    return sq_cache_set(i, res, reuse_in_thread, charset);
  }
  return 0;
}

protected mixed low_connect_to_my_mysql( string|int ro, void|string db )
{
  object res;
#ifdef DB_DEBUG
  werror("Requested %O for %O DB\n", db, ro );
#endif

  if( !db )
    db = "mysql";
  
  mixed err = catch
  {
    if( intp( ro ) )
      ro = ro?"ro":"rw";
    int t = gethrtime();
    res = Sql.Sql( replace( my_mysql_path,({"%user%", "%db%" }),
			    ({ ro, db })),
		   ([ "reconnect":0 ]));
#ifdef ENABLE_MYSQL_UNICODE_MODE
    if (res && res->master_sql && res->master_sql->set_unicode_decode_mode) {
      // NOTE: The following code only works on Mysql servers 4.1 and later.
      mixed err2 = catch {
	res->master_sql->set_unicode_decode_mode(1);
#ifdef DB_DEBUG
	werror("Unicode decode mode enabled.\n");
#endif
      };
#ifdef DB_DEBUG
      if (err2) werror ("Failed to enable unicode decode mode: %s",
			describe_error (err2));
#endif
    }
#endif /* ENABLE_MYSQL_UNICODE_MODE */
#ifdef DB_DEBUG
    werror("Connect took %.2fms\n", (gethrtime()-t)/1000.0 );
#endif
    return res;
  };

  if( db == "mysql" ||
      // Yep, this is ugly..
      has_value (describe_error (err), "Access denied"))
    throw( err );

  if (mixed err_2 = catch {
      low_connect_to_my_mysql( 0, "mysql" )
	->query( "CREATE DATABASE "+ db );
    }) {
    report_warning ("Attempt to autocreate database %O failed: %s",
		    db, describe_error (err_2));
    throw (err);
  }

  return low_connect_to_my_mysql( ro, db );
}


protected mapping tailf_info = ([]);
protected void do_tailf( int loop, string file )
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

  int os, si;
  if( tailf_info[file] )
    os = tailf_info[file];
  do
  {
    Stdio.Stat s = file_stat( file );
    if(!s) {
      os = tailf_info[ file ] = 0;
      sleep(1);
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

protected void low_check_mysql(string myisamchk, string datadir,
			       array(string) args, void|Stdio.File errlog)
{
  array(string) files = ({});
  foreach(get_dir(datadir) || ({}), string dir) {
    foreach(get_dir(combine_path(datadir, dir)) || ({}), string file)
      if(!file || !glob("*.myi", lower_case(file), ))
	continue;
      else
	files += ({ combine_path(datadir, dir, file) });
  }

  if(!sizeof(files))
    return;
  
  Stdio.File  devnull
#ifndef __NT__
    = Stdio.File( "/dev/null", "w" )
#endif
    ;
  
  report_debug("Checking MySQL tables with %O...\n", args*" ");
  mixed err = catch {
      Process.Process(({ myisamchk,
			 "--defaults-file=" + query_mysql_config_file(datadir),
		      }) + args + sort(files),
		      ([
			"stdin":devnull,
			"stdout":errlog,
			"stderr":errlog
		      ]))->wait();
    };
  if(err)
    werror(describe_backtrace(err));
}

Process.Process low_start_mysql( string datadir,
				 string uid,
				 void|int log_queries_to_stdout)
{
  void rotate_log(string path)
  {
    rm(path+".5");
    for(int i=4; i>0; i--)
      mv(path+"."+(string)i, path+"."+(string)(i+1));
  };

  //  Get mysql base directory and binary paths
  mapping mysql_location = this_program::mysql_location();
  if (!mysql_location->mysqld) {
    report_debug("\nNo MySQL found in "+ mysql_location->basedir + "!\n");
    exit(1);
  }

  //  Start by verifying the mysqld version
  string version_fatal_error = 0;
  string version = popen(({ mysql_location->mysqld,
			    "--version", "--no-defaults",
			 }));
  if (!version) {
    version_fatal_error =
      sprintf("Unable to determine MySQL version with this command:\n\n"
	      "  %s --version --no-defaults\n\n",
	      mysql_location->mysqld);
  } else {
    //  Parse version string
    string orig_version = version;
    string trailer;
    if (has_prefix (version, mysql_location->mysqld))
      // mysqld puts $0 first in the version string. Cut it off to
      // avoid possible false matches.
      version = version[sizeof (mysql_location->mysqld)..];
    if (sscanf(lower_case(version), "%*s  ver %[0-9.]%s",
	       mysql_version, trailer) < 2) {
      version_fatal_error =
	  sprintf("Failed to parse MySQL version string - got %q from:\n"
		  "%O\n\n", version, orig_version);
#ifndef YES_I_KNOW_WHAT_I_AM_DOING
    } else {
      array(string) good_versions = mysql_good_versions;
      array(string) maybe_versions = mysql_maybe_versions;
      array(string) bad_versions = mysql_bad_versions;
      mysql_product_name = "MySQL";
      if (has_prefix(trailer, "-mariadb")) {
	mysql_product_name = "MariaDB";
	good_versions = mariadb_good_versions;
	maybe_versions = mariadb_maybe_versions;
	bad_versions = mariadb_bad_versions;
      }
      //  Determine if version is acceptable
      if (has_value(glob(good_versions[*], mysql_version), 1)) {
	//  Everything is fine
      } else if (has_value(glob(maybe_versions[*], mysql_version), 1)) {
	if (has_value(glob(bad_versions[*], mysql_version), 1)) {
	  version_fatal_error =
	    sprintf("This version of %s (%s) is known to not work "
		    "with Roxen:\n\n"
		    "  %s\n",
		    mysql_product_name, mysql_version, orig_version);
	} else {
	  //  Don't allow unless user gives special define
#ifdef ALLOW_UNSUPPORTED_MYSQL
	  report_debug("\nWARNING: Forcing Roxen to run with unsupported "
		       "%s version (%s).\n",
		       mysql_product_name, mysql_version);
#else
	  version_fatal_error =
	    sprintf("This version of %s (%s) is not officially supported "
		    "with Roxen.\n"
		    "If you want to override this restriction, use this "
		    "option:\n\n"
		    "  -DALLOW_UNSUPPORTED_MYSQL\n\n",
		    mysql_product_name, mysql_version);
#endif
	}
      } else {
	//  Version not recognized (maybe too old or too new) so bail out
	version_fatal_error =
	  sprintf("%s version %s detected:\n\n"
		  "  %s\n", mysql_product_name, mysql_version, orig_version);
      }
#endif
#ifdef RUN_SELF_TEST
      if (version_fatal_error) {
	report_debug ("\n%s"
		      "Continuing anyway in self test mode.\n\n",
		      version_fatal_error);
	version_fatal_error = 0;
      }
#endif
    }
  }
  if (version_fatal_error) {
    report_debug("\n%s"
		 "Roxen cannot run unknown/unsupported versions for data\n"
                 "integrity reasons and will therefore terminate.\n\n",
		 version_fatal_error);
    exit(1);
  }

  string pid_file = datadir + "/mysql_pid";
  string err_log  = datadir + "/error_log";
  string slow_query_log;

  // If the LOGFILE environment variable is set, the logfile will be written
  // to the same directory as the debug log. Otherwise, it will be written
  // to the mysql data directory (i.e. configurations/_mysql/).
  if(getenv("LOGFILE"))
    slow_query_log = dirname(roxen_path("$LOGFILE")) + "/slow_query_log";
  else
    slow_query_log = datadir + "/slow_query_log";

  slow_query_log = combine_path(getcwd(), slow_query_log);
  
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
		  has_prefix(version, "5.1.")?
		  "--skip-locking":"--skip-external-locking",
		  "--skip-name-resolve",
		  "--basedir=" + mysql_location->basedir,
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

  string normalized_mysql_version =
    map(mysql_version/".",
	lambda(string d) {
	  return ("000" + d)[<2..];
	}) * ".";

  if(!env->ROXEN_MYSQL_SLOW_QUERY_LOG || 
     env->ROXEN_MYSQL_SLOW_QUERY_LOG != "0") {
    rotate_log(slow_query_log);
    if (normalized_mysql_version > "005.006.") {
      args += ({
	"--slow-query-log-file="+slow_query_log+".1",
	"--slow-query-log",
      });
    } else {
      // NB: Deprecated in MySQL 5.1.29 and removed in MySQL 5.6.1.
      args += ({ "--log-slow-queries="+slow_query_log+".1" });
    }
    report_debug("Setting MySQL's slow query log to \"%s.1\"\n", slow_query_log);
  }

  if (log_queries_to_stdout) {
    if (normalized_mysql_version > "005.006.") {
      args += ({
	"--general-log-file=/dev/stdout",
	"--general-log",
      });
    } else {
      // NB: Deprecated in MySQL 5.1.29 and removed in MySQL 5.6.1.
      args += ({"--log=/dev/stdout"});
    }
  }

  // Create the configuration file.
  int force = !file_stat( query_mysql_config_file(datadir) );
  string cfg_file = (Stdio.read_bytes(query_mysql_config_file(datadir)) ||
		     "[mysqld]\n"
		     "max_allowed_packet = 128M\n"
		     "net_buffer_length = 8K\n"
		     "query-cache-type = 2\n"
		     "query-cache-size = 32M\n"
		     "default-storage-engine = MYISAM\n"
		     "innodb-data-file-path=ibdata1:10M:autoextend\n"
#ifndef UNSAFE_MYSQL
		     "local-infile = 0\n"
#endif
		     "skip-name-resolve\n"
		     "character-set-server=latin1\n"
		     "collation-server=latin1_swedish_ci\n"
		     "bind-address = "+env->MYSQL_HOST+"\n" +
		     (uid ? "user = " + uid : "") + "\n");

  string normalized_cfg_file = replace(cfg_file, "_", "-");

  // Check if we need to update the contents of the config file.
  //
  // NB: set-variable became optional after MySQL 4.0.2,
  //     and was deprecated in MySQL 5.5.
  if (has_value(normalized_cfg_file, "set-variable=") ||
      has_value(normalized_cfg_file, "set-variable =")) {
    report_debug("Repairing pre Mysql 4.0.2 syntax in %s.\n",
		 query_mysql_config_file(datadir));
    cfg_file = replace(cfg_file,
		       ({ "set-variable=",
			  "set-variable = ", "set-variable =",
			  "set_variable=",
			  "set_variable = ", "set_variable =",
		       }),
		       ({ "", "", "", "", "", "",
		       }));
    force = 1;
  }

  if ((normalized_mysql_version > "005.000.") &&
      !has_value(normalized_cfg_file, "innodb-data-file-path")) {
    // It seems the defaults for this variable have changed
    // from "ibdata1:10M:autoextend" to "ibdata1:12M:autoextend".
    // For some reason InnoDB doesn't always auto-detect correctly.
    // cf [bug 7264].
    array a = cfg_file/"[mysqld]";
    if (sizeof(a) > 1) {
      report_debug("Adding innodb-data-file-path to %s.\n",
		   query_mysql_config_file(datadir));
      int initial = 10;	// 10 MB -- The traditional setting.
      int bytes = Stdio.file_size(datadir + "/ibdata1");
      if (bytes) {
	// ibdata1 grows in increments of 8 MB.
	// Assumes that the initial default size won't grow to 18 MB.
	initial = ((bytes / (1024 * 1024)) % 8) + 8;
	if (initial < 10) initial += 8;
      }
      report_debug("%O\n",
		   "ibdata1:" + initial + "M:autoextend");
      a[1] = "\n"
	"innodb-data-file-path=ibdata1:" + initial + "M:autoextend" + a[1];
      cfg_file = a * "[mysqld]";
      force = 1;
    } else {
      report_warning("Mysql configuration file %s lacks\n"
		     "InnoDB data file path entry, "
		     "and automatic repairer failed.\n",
		     query_mysql_config_file(datadir));
    }
  }

  if ((normalized_mysql_version > "005.002.") &&
      !has_value(normalized_cfg_file, "character-set-server")) {
    // The default character set was changed sometime
    // during the MySQL 5.x series. We need to set
    // the default to latin1 to avoid breaking old
    // internal tables (like eg roxen/dbs) where fields
    // otherwise shrink to a third.
    array a = cfg_file/"[mysqld]";
    if (sizeof(a) > 1) {
      report_debug("Adding default character set entries to %s.\n",
		   query_mysql_config_file(datadir));
      a[1] = "\n"
	"character-set-server=latin1\n"
	"collation-server=latin1_swedish_ci" + a[1];
      cfg_file = a * "[mysqld]";
      force = 1;
    } else {
      report_warning("Mysql configuration file %s lacks\n"
		     "character set entry, and automatic repairer failed.\n",
		     query_mysql_config_file(datadir));
    }
  }

  if ((normalized_mysql_version > "005.005.") &&
      !has_value(normalized_cfg_file, "default-storage-engine")) {
    // The default storage engine was changed to InnoDB in MySQL 5.5.
    // We need to set the default to MyISAM to avoid breaking old code
    // due to different parameter limits (eg key lengths).
    array a = cfg_file/"[mysqld]";
    if (sizeof(a) > 1) {
      report_debug("Adding default storage engine entry to %s.\n",
		   query_mysql_config_file(datadir));
      a[1] = "\n"
	"default-storage-engine = MYISAM" + a[1];
      cfg_file = a * "[mysqld]";
      force = 1;
    } else {
      report_warning("Mysql configuration file %s lacks\n"
		     "storage engine entry, and automatic repairer failed.\n",
		     query_mysql_config_file(datadir));
    }
  }

  if ((normalized_mysql_version > "010.002.003") &&
      !has_value(normalized_cfg_file, "sql_mode")) {
    // Since MariaDB 10.2.4, SQL_MODE is by default set to NO_AUTO_CREATE_USER,
    // NO_ENGINE_SUBSTITUTION, STRICT_TRANS_TABLES, ERROR_FOR_DIVISION_BY_ZERO.
    // In earlier versions of MariaDB 10.2, and since MariaDB 10.1.7, SQL_MODE
    // is by default set to NO_ENGINE_SUBSTITUTION, NO_AUTO_CREATE_USER.
    // For earlier versions of MariaDB 10.1, and MariaDB 10.0 and before, no
    // default is set.
    //
    // This change in 10.2 can cause queries to fail, complaining about
    // no default values:
    //
    //   big_query(): Query failed (Field 'x' doesn't have a default value)
    //
    // cf:
    //   https://www.slickdev.com/2017/09/05/mariadb-10-2-field-xxxxxxx-doesnt-default-value-error/
    array a = cfg_file/"[mysqld]";
    if (sizeof(a) > 1) {
      report_debug("Adding sql_mode entry to %s/my.cfg.\n", datadir);
      a[1] = "\n"
	"sql_mode = NO_ENGINE_SUBSTITUTION" + a[1];
      cfg_file = a * "[mysqld]";
      force = 1;
    } else {
      report_warning("Mysql configuration file %s/my.cfg lacks\n"
		     "sql_mode entry, and automatic repairer failed.\n",
		     datadir);
    }
  }

#ifdef __NT__
  cfg_file = replace(cfg_file, ({ "\r\n", "\n" }), ({ "\r\n", "\r\n" }));
#endif /* __NT__ */

  if(force)
    catch(Stdio.write_file(query_mysql_config_file(datadir), cfg_file));

  // Keep mysql's logging to stdout and stderr when running in --once
  // mode, to get it more synchronous.
  Stdio.File errlog = !once_mode && Stdio.File( err_log, "wct" );

  string mysql_table_check =
    Stdio.read_file(combine_path(query_configuration_dir(),
				 "_mysql_table_check"));
  if(!mysql_table_check)
    mysql_table_check = "--force --silent --fast\n"
			"--myisam-recover=QUICK,FORCE\n";
  sscanf(mysql_table_check, "%s\n%s\n",
	 string myisamchk_args, string mysqld_extra_args);
  if(myisamchk_args && sizeof(myisamchk_args)) {
    if (string myisamchk = mysql_location->myisamchk)
      low_check_mysql(myisamchk, datadir, (myisamchk_args / " ") - ({ "" }),
		      errlog);
    else {
      report_warning("No myisamchk found in %s. Tables not checked.\n",
		     mysql_location->basedir);
    }
  }

  if(mysqld_extra_args && sizeof(mysqld_extra_args))
    args += (mysqld_extra_args/" ") - ({ "" });

  args = ({ mysql_location->mysqld }) + args;

  Stdio.File  devnull
#ifndef __NT__
    = Stdio.File( "/dev/null", "w" )
#endif
    ;

#ifdef DEBUG
  report_debug ("MySQL server command: %s%{\n    %s%}\n", args[0], args[1..]);
#else
  report_debug ("MySQL server executable: %s\n", args[0]);
#endif

  rm(pid_file);
  Process.Process p = Process.Process( args,
				       ([
					 "environment":env,
					 "stdin":devnull,
					 "stdout":errlog,
					 "stderr":errlog
				       ]) );
#ifdef __NT__
  if (p)
    Stdio.write_file(pid_file, p->pid() + "\n");
#endif

  return p;
}


int mysql_path_is_remote;
void start_mysql (void|int log_queries_to_stdout)
{
  Sql.Sql db;
  int st = gethrtime();
  string mysqldir = query_mysql_data_dir();
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

    // At this moment new_master does not exist, and
    // DBManager can not possibly compile. :-)
    call_out( lambda(){
		// Inhibit backups of the precompiled_files table.
		new_master->resolv("DBManager.inhibit_backups")
		  ("local", "precompiled_files");
	      }, 1 );

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

    if ((float)version > 4.0) {
      // UTF8 and explicit character set markup was added in Mysql 4.1.x.
      add_constant("ROXEN_MYSQL_SUPPORTS_UNICODE", 1);
    }

    if( !do_tailf_threaded && !once_mode ) do_tailf(0, err_log );
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
    if (!once_mode) start_tailf();
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

  mkdirhier( mysqldir+"/mysql/" );

#ifndef __NT__
  if (!Stdio.exist(pid_file)) sleep(0.1);
  if (Stdio.exist(pid_file)) {
    int pid;
    int prev_pid = -1;
    int cnt;
    for (cnt = 0; cnt < 600; cnt++) {
      // Check if the mysqld process is running (it could eg be starting up).
      pid = pid ||
	(int)String.trim_all_whites(Stdio.read_bytes(pid_file)||"");
      if (pid) {
	if (!kill(pid, 0) && errno() == System.ESRCH) {
	  // The process has gone away.
	  if (prev_pid == pid) {
	    // The pid_file is stale.
	    rm(pid_file);
	  }

	  prev_pid = pid;
	  pid = 0;	// Reread the pid file.
	  cnt = 0;
	  sleep(0.1);
	  continue;
	}
      } else if (prev_pid) {
	// A new process might be taking over, give it some more time...
	prev_pid = 0;
	sleep(0.1);
	continue;
      } else {
	// No active process is claiming the pid file.
	break;
      }
      report_debug("Retrying to connect to local MySQL (pid: %d).\n", pid);
      if( mixed err = catch( db = connect_to_my_mysql( 0, "mysql" ) ) ) {
#ifdef MYSQL_CONNECT_DEBUG
	werror ("Error connecting to local MySQL: %s", describe_error (err));
#endif
      }
      else {
	if (!once_mode) start_tailf();
	connected_ok(1);
	return;
      }
      sleep(0.1);
    }
    if (pid && (cnt >= 600)) {
      report_error("Process %d is claiming to be MySQLd (pid file: %O),\n"
		   "but doesn't answer to connection attempts.\n",
		   pid, pid_file);
      exit(1);
    }
  }  
#endif

  // Steal the mysqld pid_file, and claim that we are mysqld
  // until we actually start mysqld.
  Stdio.write_file(pid_file, getpid()+"\n");
  rm( err_log );

  if (!once_mode) start_tailf();

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


  Process.Process mysqld =
    low_start_mysql( mysqldir,
#if constant(getpwuid)
		     (getpwuid(getuid()) || ({0}))[ 0 ],
#else /* Ignored by the start_mysql script */
		     0,
#endif
		     log_queries_to_stdout);

  int repeat;
  while( 1 )
  {
    if (!mysqld || (mysqld->status() == 2)) {
      // mysqld has died.
      int ret = mysqld->wait();
      werror("\nMySQL failed to start with error code %O. Aborting.\n", ret);
      exit(1);
    }
    sleep( 0.1 );
    // Allow mysqld 1 minute to start answering before aborting.
    // Initial start delays of up to 26 seconds have been observed [WS-582].
    if( repeat++ > 600 )
    {
      if( !do_tailf_threaded && !once_mode ) do_tailf(0, err_log );
      report_fatal("\nFailed to start MySQL. Aborting\n");
      exit(1);
    }
    if( mixed err = catch( db = connect_to_my_mysql( 0, "mysql" ) ) ) {
#ifdef MYSQL_CONNECT_DEBUG
      werror ("Error connecting to local MySQL: %s", describe_error (err));
#endif
    }
    else if (db)
    {
      connected_ok(0);
      return;
    }
  }
}

int low_dump( string file, program|void p )
{
#ifdef ENABLE_DUMPING
  if( file[0] != '/' )
    file = server_dir +"/"+ file;
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
#endif // ENABLE_DUMPING
  return 0;
}

int dump( string file, program|void p )
{
  // int t = gethrtime();
  int res = low_dump(file, p);
  // werror("dump(%O, %O): %.1fms\n", file, p, (gethrtime()-t)/1000.0);
  return res;
}

object(Stdio.Stat)|array(int) da_Stat_type;
LocaleString da_String_type;
function orig_predef_describe_bt = predef::describe_backtrace;

void do_main( int argc, array(string) argv )
{
  array(string) hider = argv;
  argv = 0;

  catch (once_mode = (int)Getopt.find_option(hider + ({}), "o", "once"));

#ifdef GC_TRACE
  trace (GC_TRACE, "gc");
#endif

  nwrite = early_nwrite;

  add_constant( "connect_to_my_mysql", connect_to_my_mysql );
  add_constant( "clear_connect_to_my_mysql_cache",
		clear_connect_to_my_mysql_cache );  

#if !constant(thread_create)
  report_debug(#"


------ FATAL ----------------------------------------------------
Roxen requires Pike with thread support.
-----------------------------------------------------------------


");
  exit(-1);
#endif

#ifdef SECURITY
#if !constant(__builtin.security.Creds)
  report_debug(#"


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
    report_debug(#"


------- WARNING -----------------------------------------------
Roxen requires bignum support in Pike since version 2.4.
Please recompile Pike with gmp / bignum support to run Roxen.

It might still be possible to start Roxen, but the 
functionality will be affected, and stange errors might occur.
---------------------------------------------------------------


");
  }

#ifdef NOT_INSTALLED
    report_debug(#"


------- WARNING -----------------------------------------------
You are running with an un-installed Pike binary.

Please note that this is unsupported, and might stop working at
any time, since some things are done differently in uninstalled
Pikes, as an example the module search paths are different, and
some environment variables are ignored.
---------------------------------------------------------------


");
#endif

#if __VERSION__ < 8.0
  report_debug(#"


******************************************************
Roxen " + roxen_ver + #" requires Pike 8.0 or newer.
Please install a newer version of Pike.
******************************************************


");
  _exit(0); /* 0 means stop start script looping */
#endif /* __VERSION__ < 8.0 */

#if !constant (Mysql.mysql)
  report_debug (#"


******************************************************
Roxen requires MySQL support in Pike since version 2.4.
Your Pike has been compiled without support for MySQL.
Please install MySQL client libraries and reconfigure
and rebuild Pike from source.
******************************************************


");
  _exit(0); // 0 means stop start script looping
#endif // !constant (Mysql.mysql)

#if !constant (Regexp.PCRE)
  report_debug (#"


******************************************
Roxen requires Regexp.PCRE support in Pike
******************************************


");
  _exit(0); // 0 means stop start script looping
#endif // !constant (Regexp.PCRE)


  string s;
  if (!catch(s = _Roxen->make_http_headers((["a\r\n":"b\r\n"]), 1)) &&
      (sizeof(s/"\r\n") > 2)) {
    add_constant("HAVE_OLD__Roxen_make_http_headers", 1);
    report_debug(#"


------- WARNING -----------------------------------------------
Old or broken _Roxen.make_http_headers() detected.

Roxen 6.0 prefers Pike 8.0.270 or later.
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
  add_constant ("call_out", call_out);

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
  add_constant("roxen_dist_os", dist_os);
  add_constant("roxen_release", release || roxen_release);
  add_constant("roxen_is_cms",  roxen_is_cms);
  add_constant("roxen_product_name", roxen_product_name);
  add_constant("roxen_product_code", roxen_product_code);
  add_constant("lopen",         lopen);
  add_constant("lfile_stat",    lfile_stat);
  add_constant("lfile_path",    lfile_path);
  add_constant("report_notice", report_notice);
  add_constant("report_debug",  report_debug);
  add_constant("report_warning",report_warning);
  add_constant("report_error",  report_error);
  add_constant("report_fatal",  report_fatal);
  add_constant("report_notice_for", report_notice_for);
  add_constant("report_warning_for", report_warning_for);
  add_constant("report_error_for", report_error_for);
  add_constant("report_fatal_for", report_fatal_for);
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
  add_constant("r_cp", r_cp);
  add_constant("r_get_dir", r_get_dir);
  add_constant("r_file_stat", file_stat);
  add_constant("r_is_file", r_is_file);
  add_constant("r_is_dir", r_is_dir);
  add_constant("r_is_link", r_is_link);
  add_constant("r_exist", r_exist);
  add_constant("r_read_bytes", r_read_bytes);
  add_constant("roxenloader", this_object());
  add_constant("ErrorContainer", ErrorContainer);

#ifdef THREADS
  add_constant("euid_egid_lock", euid_egid_lock);
#endif
#ifndef __NT__
  if(!getuid())
    add_constant("Privs", Privs);
  else
#endif /* !__NT__ */
    add_constant("Privs", class {
      void create(string reason, int|string|void uid, int|string|void gid) {}
    });

  add_constant("_cur_rxml_context", Thread.Local());

  int mysql_only_mode =
    (int)Getopt.find_option(hider, "mysql-only", ({ "mysql-only" }));
  if (mysql_only_mode) {
    // Force --once mode.
    //
    // This avoids starting eg the tailf thread.
    once_mode = 1;
  }

  if (has_value (hider, "--mysql-log-queries")) {
    hider -= ({"--mysql-log-queries"});
    argc = sizeof (hider);
    start_mysql (1);
  }
  else
    start_mysql (0);

  if (mysql_only_mode) {
    exit(0);
  }

  if (err = catch {
    if(master()->relocate_module) add_constant("PIKE_MODULE_RELOC", 1);
    replace_master(new_master=[object(__builtin.__master)](((program)"etc/roxen_master.pike")()));
  }) {
    werror("Initialization of Roxen's master failed:\n"
	   "%s\n", describe_backtrace(err));
    exit(1);
  }

  // Restore describe_backtrace(), which was zapped by the new master.
  add_constant ("describe_backtrace", describe_backtrace);

#if constant( Gz.inflate )
  add_constant("grbz",lambda(string d){return Gz.inflate()->inflate(d);});
#else
  add_constant("grbz",lambda(string d){return d;});
  report_debug(#"


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
    report_debug(#"


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
    new_master->putenv("LONG_PIKE_ERRORS", "yup");
  }

  array(string) patches = get_dir("patches");
  if (patches && sizeof(patches)) {
    report_debug("Installed patches:\n");
    foreach(sort(patches), string patch) {
      report_debug("  %s\n", patch);
    }
    report_debug("\n");
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

  if( DC("SSL.File" ) )
  {
    DC( "SSL.context" );
    DC( "Tools.PEM.pem_msg" );
    DC( "Crypto.Random.random_string" );
    DC( "Standards.PKCS.RSA.parse_private_key");
    DC( "Crypto.RSA" );
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

  DC( "Locale" );

  DC( "Charset" );

  report_debug("\bDone [%.1fms]\n", (gethrtime()-t)/1000.0);

  add_constant( "hsv_to_rgb",  nm_resolv("Colors.hsv_to_rgb")  );
  add_constant( "rgb_to_hsv",  nm_resolv("Colors.rgb_to_hsv")  );
  add_constant( "parse_color", nm_resolv("Colors.parse_color") );
  add_constant( "color_name",  nm_resolv("Colors.color_name")  );
  add_constant( "colors",      nm_resolv("Colors")             );

  add_constant("verify_password", verify_password);
  add_constant("crypt_password", crypt_password);

  // report_debug("Loading prototypes ... \b");
  // t = gethrtime();

  // Load prototypes (after the master is replaces, thus making it
  // possible to dump them to a .o file (in the mysql))
  object prototypes = (object)"base_server/prototypes.pike";
  dump( "base_server/prototypes.pike", object_program( prototypes ) );
  foreach (indices (prototypes), string id)
    if (!prototypes->ignore_identifiers[id])
      add_constant (id, prototypes[id]);
  // report_debug("\bDone [%.1fms]\n", (gethrtime()-t)/1000.0);

  // report_debug("Resolving Roxen ... \b");
  // t = gethrtime();
  prototypes->Roxen = master()->resolv ("Roxen");
  // report_debug("\bDone [%.1fms]\n", (gethrtime()-t)/1000.0);

  // report_debug("Initiating cache system ... \b");
  // t = gethrtime();
  object cache = initiate_cache();
  // report_debug("\bDone [%.1fms]\n", (gethrtime()-t)/1000.0);

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
//! Like @[predef::rm], but processes the path with @[roxen_path].

//! @decl int(0..1) r_mv(string from, string to)
//! @appears r_mv
//! Like @[predef::mv], but processes the paths with @[roxen_path].

//! @decl Stdio.Stat r_file_stat(string path, void|int(0..1) symlink)
//! @appears r_file_stat
//! Like @[predef::file_stat], but processes the path with @[roxen_path].

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
