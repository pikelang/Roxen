/*
 * $Id: roxenloader.pike,v 1.84 1999/03/27 22:17:20 grubba Exp $
 *
 * Roxen bootstrap program.
 *
 */

// Sets up the roxen environment. Including custom functions like spawne().

// Roxen 1.4 requires Pike 0.7 or later.
#if __VERSION__ < 0.7
#error Roxen 1.4 requires Pike 0.7 or later.
#endif /* __VERSION__ < 0.7 */

//
// NOTE:
//	This file uses replace_master(). This implies that the
//	master() efun when used in this file will return the old
//	master and not the new one.
//
private static object new_master;

constant cvs_version="$Id: roxenloader.pike,v 1.84 1999/03/27 22:17:20 grubba Exp $";

#define perror roxen_perror
private static int perror_status_reported=0;

int pid = getpid();
object stderr = Stdio.File("stderr");

mapping pwn=([]);
string pw_name(int uid)
{
#if !constant(getpwuid)
  return "uid #"+uid;
#else
  if(pwn[uid]) return pwn[uid];
  return pwn[uid]=(getpwuid(uid)||((""+uid)/":"))[0];
#endif
}

#if !constant(getppid)
int getppid()
{
  return -1;
}
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

// Used to print error/debug messages
void roxen_perror(string format,mixed ... args)
{
  int t = time();

  if (perror_status_reported < t) {
    stderr->write("[1mRoxen is alive!\n"
		  "   Time: "+ctime(t)+
		  "   pid: "+pid+"   ppid: "+getppid()+
#if efun(geteuid)
		  (geteuid()!=getuid()?"   euid: "+pw_name(geteuid()):"")+
#endif
		  "   uid: "+pw_name(getuid())+"[0m\n");
    perror_status_reported = t + 60;	// 60s delay.
  }

  string s;
  spider;
  if(sizeof(args)) format=sprintf(format,@args);
  if (format=="") return;

#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_DEBUG))
    foreach(format/"\n"-({""}), string message)
      syslog(LOG_DEBUG, replace(message+"\n", "%", "%%"));
#endif
  stderr->write(format);
}

// Make a directory hierachy
int mkdirhier(string from, int|void mode)
{
  int r = 1;
  string a, b;
  array f;

  f=(from/"/");
  b="";

  foreach(f[0..sizeof(f)-2], a)
  {
    r = mkdir(b+a);
#if constant(chmod)
    if (mode) {
      catch { chmod(b+a, mode); };
    }
#endif /* constant(chmod) */
    b+=a+"/";
  }
  if(!r)
    return (file_stat(from)||({0,0}))[1] == -2;
  return 1;
}

/*
 * PDB support
 */
object db;
mapping dbs = ([ ]);

#if constant(thread_create)
static private inherit Thread.Mutex:db_lock;
#endif

object open_db(string id)
{
#if constant(thread_create)
  object key = db_lock::lock();
#endif
  if(!db) db = PDB->db("pdb_dir", "wcCr");
  if(dbs[id]) return dbs[id];
  return dbs[id]=db[id];
}


// Help function used by low_spawne()
mapping make_mapping(string *f)
{
  mapping foo=([ ]);
  string s, a, b;
  foreach(f, s)
  {
    sscanf(s, "%s=%s", a, b);
    foo[a]=b;
  }
  return foo;
}


// Roxen itself
object roxen;

// The function used to report notices/debug/errors etc.
function nwrite;


/*
 * Code to get global configuration variable values from Roxen.
 */
#define VAR_VALUE 0

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

// Print a debug message
void report_debug(string message)
{
  nwrite(message,0,2);
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_DEBUG))
    foreach(message/"\n", message)
      syslog(LOG_DEBUG, replace(message+"\n", "%", "%%"));
#endif
}

// Print a warning
void report_warning(string message)
{
  nwrite(message,0,2);
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_WARNING))
    foreach(message/"\n", message)
      syslog(LOG_WARNING, replace(message+"\n", "%", "%%"));
#endif
}

// Print a notice
void report_notice(string message)
{
  nwrite(message,0,1);
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_NOTICE))
    foreach(message/"\n", message)
      syslog(LOG_NOTICE, replace(message+"\n", "%", "%%"));
#endif
}

// Print an error message
void report_error(string message)
{
  nwrite(message,0,3);
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_ERR))
    foreach(message/"\n", message)
      syslog(LOG_ERR, replace(message+"\n", "%", "%%"));
#endif
}

// Print a fatal error message
void report_fatal(string message)
{
  nwrite(message,0,3);
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_EMERG))
    foreach(message/"\n", message)
      syslog(LOG_EMERG, replace(message+"\n", "%", "%%"));
#endif
}

// Pipe open 
string popen(string s, void|mapping env, int|void uid, int|void gid)
{
  object p;
  object f;

  f = Stdio.File();
  p = f->pipe(Stdio.PROP_IPC);
  if(!p) 
    error("Popen failed. (couldn't create pipe)\n");

  mapping opts = ([
    "env": (env || getenv()),
    "stdout":p,
  ]);

  if (!getuid()) {
    switch(query_num_arg()) {
    case 4:
      opts->gid = gid;
    case 3:
      opts->uid = uid;
      break;
    }
  }
  opts->noinitgroups = 1;
  object proc;
  proc = Process.create_process( ({s}), opts );
  p->close();
  destruct(p);

  if (proc) 
  {
    string t = f->read(0x7fffffff);
    f->close();
    destruct(f);
    return t;
  }
  f->close();
  destruct(f);
  return 0;
}

// Create a process
object spawne(string s,string *args, mapping|array env, object stdin, 
	      object stdout, object stderr, void|string wd, 
	      void|array (int) uid)
{
  int pid, *olduid = allocate(2, "int");
  object privs;

  int u, g;
  if(uid) { u = uid[0]; g = uid[1]; } else
#if efun(geteuid)
  { u=geteuid(); g=getegid(); }
#else
  ;
#endif
  return Process.create_process(({ s }) + (args || ({})), ([
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

// Start a new Pike process with the same configuration as the current one
object spawn_pike(array(string) args, void|string wd, object|void stdin,
		  object|void stdout, object|void stderr)
{
  string cwd = getcwd();
  return Process.create_process(({cwd+"/start","--cd",wd,
				  "--quiet","--program"})+args,
				(["toggle_uid":1,
				 "stdin":stdin,
				 "stdout":stdout,
				 "stderr":stderr]));
}


// Add a few cache control related efuns
static private void initiate_cache()
{
  object cache;
  cache=((program)"base_server/cache")();
  add_constant("cache_set", cache->cache_set);
  add_constant("cache_lookup", cache->cache_lookup);
  add_constant("cache_remove", cache->cache_remove);
  add_constant("cache_clear", cache->cache_clear);
  add_constant("cache_expire", cache->cache_expire);
  add_constant("cache", cache);
  add_constant("capitalize", lambda(string s){return upper_case(s[0..0])+s[1..];});
}

// Don't allow cd() unless we are in a forked child.
class restricted_cd
{
  int locked_pid = getpid();
  int `()(string path)
  {
    if (locked_pid == getpid()) {
      throw(({ "Use of cd() is restricted.\n", backtrace() }));
    }
    return cd(path);
  }
}

// Place holder.
class empty_class {
};

// Fallback efuns.
#if !constant(getuid)
int getuid(){ return 17; }
int getgid(){ return 42; }
#endif
#if !efun(gethrtime)
int gethrtime()
{
  return (time()*1000);
}
#endif

// Load Roxen for real
object really_load_roxen()
{
  int start_time = gethrtime();
  werror("Loading roxen ... ");
  object res = ((program)"roxen")();
  roxen_perror("Loaded roxen in "+sprintf("%4.3fs\n", (gethrtime()-start_time)/1000000.0));
  return res;
}

// Debug function to trace calls to destruct().
#ifdef TRACE_DESTRUCT
void trace_destruct(mixed x)
{
  roxen_perror(sprintf("DESTRUCT(%O)\n%s\n",
		       x, describe_backtrace(backtrace())));
  destruct(x);
}
#endif /* TRACE_DESTRUCT */

// Set up efuns and load Roxen.
void load_roxen()
{
  add_constant("cd", restricted_cd());
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
  
  roxen = really_load_roxen();

  perror("Roxen version "+roxen->cvs_version+"\n"
	 "Roxen release "+roxen->real_version+"\n"
#ifdef __NT__
	 "Running on NT\n"
#endif
    );
  nwrite = roxen->nwrite;
}

// Code to trace fd usage.
#ifdef FD_DEBUG
class mf
{
  inherit Stdio.File;

  mixed open(string what, string mode)
  {
    int res;
    res = ::open(what,mode);
    if(res)
    {
      string file;
      int line;
      sscanf(((describe_backtrace(backtrace())/"\n")[2]-(getcwd()+"/")),
	     "%*s line %d in %s", line, file);
      mark_fd(query_fd(), file+":"+line+" open(\""+ what+"\", "+mode+")");
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

// open() efun.
object|void open(string filename, string mode, int|void perm)
{
  object o;
  o=mf();
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

// Make a $PATH-style string
string make_path(string ... from)
{
  return Array.map(from, lambda(string a, string b) {
    return (a[0]=='/')?combine_path("/",a):combine_path(b,a);
    //return combine_path(b,a);
  }, getcwd())*":";
}

#if constant(fork)
class getpw_kluge
{
  object pin;
  object pout;

#if constant(thread_create)
  object lock = Thread.Mutex();
#endif /* constant(thread_create) */

  constant replace_tab = ({ "getpwnam", "getpwent", "setpwent", "setpwnam",
			    "endpwent", "get_all_users", "get_groups_for_user",
  });

  void send_msg(string tag, mixed val)
  {
    string msg = encode_value(({ tag, val }));
    msg = sprintf("%4c%s", sizeof(msg), msg);

    int bytes;

    while(sizeof(msg)) {
      bytes = pout->write(msg);

      if (bytes <= 0) {
	// Connection probably closed!
	throw(({ "Remote connection closed!\n", backtrace() }));
      }
      if (bytes == sizeof(msg)) {
	return;
      }
      msg = msg[bytes..];
    }
  }

  string expect(int len)
  {
    string msg = pin->read(len);

    if (sizeof(msg) != len) {
      throw(({ "Received short message!\n", backtrace() }));
    }
    return msg;
  }

  array(mixed) get_msg()
  {
    string msg = expect(4);

    int bytes;
    sscanf(msg, "%4c", bytes);

    msg = expect(bytes);

    return decode_value(msg);
  }

  mixed do_call(string fun, array(mixed) args)
  {
#if constant(thread_create)
    mixed key = lock->lock();
#endif /* constant(thread_create) */

    send_msg(fun, args);

    array(mixed) res = get_msg();

#if constant(thread_create)
    if (key) {
      destruct(key);
    }
#endif /* constant(thread_create) */

    if (res[0] == "throw") {
      if (arrayp(res[1]) && (sizeof(res[1]) > 1) &&
	  stringp(res[1][0]) && arrayp(res[1][1])) {
	// Looks like a backtrace...
	res[1][1] = backtrace() + res[1][1];
      }
      throw(res[1]);
    }

    return(res[1]);
  }

  void server()
  {
    mapping constants = all_constants();

    while (1) {
      array(mixed) call = get_msg();

      function fun = constants[call[0]];

      int got_res;
      mixed res;
      mixed err = catch {
	res = fun(@call[1]);

	got_res = 1;
      };
      if (got_res) {
	send_msg("return", res);
      } else {
	send_msg("throw", err);
      }
    }
  }

  void do_replace(string fun)
  {
    add_constant(fun, lambda(mixed ... args) {
			return do_call(fun, args);
		      });
  }

  void init_error(string msg)
  {
    roxen_perror(sprintf("Error in bootstrap code: %s\n"
			 "getpw_kluge not enabled.\n", msg));
  }

  void create()
  {
#if constant(thread_create)
    if (sizeof(all_threads()) > 1) {
      init_error("Threads are already active!");
      return;
    }
#endif /* constant(thread_create) */
    object pipe1 = Stdio.File();
    object pipe2 = Stdio.File();
    object pipe3 = pipe1 && pipe1->pipe();
    object pipe4 = pipe2 && pipe2->pipe();
    if (!pipe3 || !pipe4) {
      init_error("Failed to open pipes.");
      foreach(({ pipe1, pipe2, pipe3, pipe4 }), object p) {
	p && p->close();
      }
      return;
    }
    mixed pid;
    if (catch { pid = fork(); }) {
      init_error("fork() failed!");
      return;
    }
    if (pid) {
      // Parent process
      pin = pipe1;
      pout = pipe4;
      pipe2->close();
      pipe3->close();

      foreach(replace_tab, string fun_name) {
	do_replace(fun_name);
      }
    } else {
      // Child process
      pin = pipe2;
      pout = pipe3;
      pipe1->close();
      pipe4->close();
      server();
      throw(1);		// Tell main() we're now in the child.
    }
  }
};
#endif /* constant(fork) */

// Roxen bootstrap code.
int main(mixed ... args)
{
  int start_time = gethrtime();
  string path = make_path("base_server", "etc/include", ".");
  roxen_perror(version()+"\n");
  roxen_perror("Roxen loader version "+cvs_version+"\n");
  roxen_perror("Roxen started on "+ctime(time()));	// ctime has an lf.
  master()->putenv("PIKE_INCLUDE_PATH", path);
  foreach(path/":", string p) {
    add_include_path(p);
    add_program_path(p);
  }

#if 0 && constant(fork)
  if (catch { getpw_kluge(); }) {
    /* We're in the kluge process, and it's time to die... */
    exit(0);
  }
#endif /* constant(fork) */

  replace_master(new_master=(((program)"etc/roxen_master.pike")()));

  add_constant("open_db", open_db);
  add_constant("ErrorContainer", class 
  {
    string errors="";
    string get()
    {
      return errors;
    }
    void got_error(string file, int line, string err)
    {
       string e = sprintf("%s:%d\t%s\n", file-getcwd(), line, err);
//       werror(e);
      errors += e;
    }
  });
  add_constant("spawne",spawne);
  add_constant("spawn_pike",spawn_pike);
  add_constant("perror",perror);
  add_constant("roxen_perror",perror);
  add_constant("popen",popen);
  add_constant("roxen_popen",popen);
  add_constant("roxenp", lambda() { return roxen; });
  add_constant("report_notice", report_notice);
  add_constant("report_debug", report_debug);
  add_constant("report_warning", report_warning);
  add_constant("report_error", report_error);
  add_constant("report_fatal", report_fatal);
  add_constant("init_logger", init_logger);
  add_constant("open", open);
  add_constant("mkdirhier", mkdirhier);

  initiate_cache();
  load_roxen();
  int retval = roxen->main(@args);
  perror_status_reported = 0;
  roxen_perror("\n-- Total boot time %4.3f seconds ---------------------------\n\n",
	       (gethrtime()-start_time)/1000000.0);
  return(retval);
}
