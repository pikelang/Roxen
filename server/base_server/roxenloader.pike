import spider;
#define error(X) do{array Y=backtrace();throw(({(X),Y[..sizeof(Y)-2]}));}while(0)

program Privs;

// Set up the roxen environment. Including custom functions like spawne().
constant cvs_version="$Id: roxenloader.pike,v 1.55 1998/02/04 16:10:41 per Exp $";

#define perror roxen_perror

//
// NOTE:
//	This file uses replace_master(). This implies that the
//	master() efun when used in this file will return the old
//	master and not the new one.
//
private static object new_master;


private static int perror_status_reported=0;

int pid = getpid();
object stderr = Stdio.File("stderr");

mapping pwn=([]);
string pw_name(int uid)
{
  if(pwn[uid]) return pwn[uid];
  return pwn[uid]=(getpwuid(uid)||((""+uid)/":"))[0];
}

void roxen_perror(string format,mixed ... args)
{
  int t = time();

  if (perror_status_reported < t) {
    stderr->write("[1mRoxen is alive! pid: "+pid+"   ppid: "+getppid()+
#if efun(geteuid)
		  (geteuid()!=getuid()?"   euid: "+pw_name(geteuid()):"")+
#endif
		  "   uid: "+pw_name(getuid())+
		  "    Time: "+(ctime(t)/" ")[-2]+"[0m\n");
    perror_status_reported = t + 60;	// 60s delay.
  }

  string s;
  if(sizeof(args)) format=sprintf(format,@args);
  if (format=="") return;
  stderr->write(format);
}

void mkdirhier(string from, int|void mode)
{
  string a, b;
  array f;

  f=(from/"/");
  b="";

  foreach(f[0..sizeof(f)-2], a)
  {
    mkdir(b+a);
#if constant(chmod)
    if (mode) {
      catch { chmod(b+a, mode); };
    }
#endif /* constant(chmod) */
    b+=a+"/";
  }
}

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



object roxen;
function nwrite;

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

void report_debug(string message)
{
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_DEBUG))
    syslog(LOG_DEBUG, replace(message, "%", "%%"));
  else
#endif
    nwrite(message,0,2);
}

void report_warning(string message)
{
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_WARNING))
    syslog(LOG_WARNING, replace(message, "%", "%%"));
  else
#endif
    nwrite(message,0,2);
}

void report_notice(string message)
{
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_NOTICE))
    syslog(LOG_NOTICE, replace(message, "%", "%%"));
  else
#endif
    nwrite(message,0,1);
}

void report_error(string message)
{
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_ERR))
    syslog(LOG_ERR, replace(message, "%", "%%"));
  else
#endif
    nwrite(message,0,3);
}

void report_fatal(string message)
{
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_EMERG))
    syslog(LOG_EMERG, replace(message, "%", "%%"));
  else
#endif
    nwrite(message,0,3);
}
 
string popen(string s, void|mapping env, int|void uid, int|void gid)
{
  object p,p2;

  p2 = Stdio.File();
  p=p2->pipe();
  if(!p) error("Popen failed. (couldn't create pipe)\n");

#if constant(Process.create_process)

  p2->set_close_on_exec(1);	// Paranoia.

  mapping opts = ([
    "uid":uid,
    "gid":gid,
    "env": env || getenv(),
    "stdout":p
  ]);

#ifdef MODULE_DEBUG
//   report_debug(sprintf("POPEN: Creating process( %O, %O)...\n",
// 		       ({ "/bin/sh", "-c", s }), opts));
#endif /* MODULE_DEBUG */
  object proc;
  proc = Process.create_process(({ "/bin/sh", "-c", s }), opts);

  if (proc) {
    p->close();
    destruct(p);
    string t = p2->read(0x7fffffff);
    p2->close();
    destruct(p2);
    return t;
  }
  return 0;
  
#else /* !constant(Process.create_process) */
  if(!fork())
  {
    array (int) olduid = ({ -1, -1 });
    catch {
      if(p->query_fd() < 0)
      {
	perror("File to dup2 to closed!\n");
	exit(99);
      }
      p->dup2(Stdio.File("stdout"));
      // p->close();
      // p2->close();
      _verify_internals();
      if(uid || gid)
      {
	object privs = Privs("Executing script as non-www user");
	olduid = ({ uid, gid });
	setgid(olduid[1]);
	setuid(olduid[0]);
#if efun(initgroups)
	array pw = getpwuid((int)uid);
	if(pw) initgroups(pw[0], (int)olduid[0]);
#endif
      }
      catch(exece("/bin/sh", ({ "-c", s }), (env||getenv())));
    };
    exit(69);
  }else{
    string t;
    // p->close();
    destruct(p);
    t=p2->read(0x7fffffff);
    destruct(p2);
    return t;
  }
#endif /* constant(Process.create_process) */
}

int low_spawne(string s,string *args, mapping|array env, object stdin, 
	   object stdout, object stderr, void|string wd)
{
  object p;
  int pid;
  string t;

  if(arrayp(env))
    env = make_mapping(env);
  if(!mappingp(env)) 
    env=([]);
  
  
  stdin->dup2(Stdio.File("stdin"));
  stdout->dup2(Stdio.File("stdout"));
  stderr->dup2(Stdio.File("stderr"));
  if(stringp(wd) && sizeof(wd))
    cd(wd);
  exece(s, args, env);
  perror(sprintf("Spawne: Failed to exece %s\n", s));
  exit(99);
}

int spawne(string s,string *args, mapping|array env, object stdin, 
	   object stdout, object stderr, void|string wd, void|array (int) uid)
{
  int pid, *olduid = allocate(2, "int");
  object privs;

#if constant(Process.create_process)
// if (arrayp(uid) && (sizeof(uid) == 2)) {
//   privs = Privs("Executing program as non-www user (outside roxen)", @uid);
// }

#ifdef MODULE_DEBUG
  report_debug(sprintf("SPAWNE: Creating process( %O, %O)...\n",
		       ({ s }) + (args || ({})), ([
			 "toggle_uid":1,
			 "stdin":stdin,
			 "stdout":stdout,
			 "stderr":stderr,
			 "cwd":wd,
			 "env":env,
		       ])));
#endif /* MODULE_DEBUG */
  int u, g;
  if(uid) { u = uid[0]; g = uid[1]; } else { u=geteuid(); g=getegid(); }
  object proc = Process.create_process(({ s }) + (args || ({})), ([
    "toggle_uid":1,
    "stdin":stdin,
    "stdout":stdout,
    "stderr":stderr,
    "cwd":wd,
    "env":env,
    "uid":u,
    "gid":g,
  ]));

//   privs = 0;

  if (proc) {
    return(proc->pid());
  }
  return(-1);

#else /* !constant(Process.create_process) */
  if(pid=fork()) return pid;

  if(arrayp(uid) && sizeof(uid) == 2)
  {
    privs = Privs("Executing program as non-www user (outside roxen)");
    setgid(uid[1]);
    setuid(uid[0]);
  } 
  catch(low_spawne(s, args, env, stdin, stdout, stderr, wd));
  exit(99); 
#endif /* constant(Process.create_process) */
}

int spawn_pike(array(string) args, void|string wd, object|void stdin,
	       object|void stdout, object|void stderr)
{
  int pid;
  string cwd = getcwd();
  string pikebin = combine_path(cwd, "bin/pike");
  string mast = new_master->_master_file_name ||
    combine_path(cwd,"../pike/src/lib/master.pike");
  array preargs = ({ });

  if (file_stat(mast))
    preargs += ({ "-m", mast });
  foreach(new_master->pike_include_path, string s)
    preargs += ({ "-I"+s });
  foreach(new_master->pike_module_path, string s)
    preargs += ({ "-M"+s });
  foreach(new_master->pike_program_path, string s)
    preargs += ({ "-P"+s });

#if constant(Process.create_process)

#ifdef MODULE_DEBUG
  report_debug(sprintf("SPAWN_PIKE: Creating process( %O, %O)...\n",
		       ({ pikebin }) + preargs + args, ([
			 "toggle_uid":1,
			 "stdin":stdin,
			 "stdout":stdout,
			 "stderr":stderr,
			 "cwd":wd,
			 "env":getenv()
		       ])));
#endif /* MODULE_DEBUG */

  object proc = Process.create_process(({ pikebin }) + preargs + args, ([
    "toggle_uid":1,
    "stdin":stdin,
    "stdout":stdout,
    "stderr":stderr,
    "cwd":wd,
    "env":getenv()
  ]));

  if (proc) {
    return(proc->pid());
  }
  return -1;

#else /* !constant(Process.create_process) */
  if ((pid = fork()) == 0) {
    stdin && stdin->dup2(Stdio.File("stdin"));
    stdout && stdout->dup2(Stdio.File("stdout"));
    stderr && stderr->dup2(Stdio.File("stderr"));
    if(wd)
      cd(wd);
    exece(pikebin, preargs+args, getenv());
    perror(sprintf("Spawn_pike: Failed to exece %s\n", pikebin));
    exit(-1);
  }
  return pid;
#endif /* constant(Process.create_process) */
}



static private void initiate_cache()
{
  object cache;
  cache=((program)"base_server/cache")();
  add_constant("cache_set", cache->cache_set);
  add_constant("cache_lookup", cache->cache_lookup);
  add_constant("cache_remove", cache->cache_remove);
  add_constant("cache_expire", cache->cache_expire);
  add_constant("cache", cache);
  add_constant("capitalize", lambda(string s){return upper_case(s[0..0])+s[1..];});
}

class myprivs
{
  program privs;
  object master;
    
  void create(object m)
  {
    master = m;
  }

  object `()(mixed ... args)
  {
    if(!privs) privs = master->Privs;
    return privs(@args);
  }
}

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

class empty_class {
};

void load_roxen()
{
  add_constant("cd", restricted_cd());

  // Attempt to resolv cross-references...
  if(!getuid())
    add_constant("Privs", myprivs(this_object()));
  else  // No need, we are not running as root.
    add_constant("Privs", (Privs=empty_class));
  roxen = ((program)"roxen")();
  if(!getuid())
  {
    add_constant("roxen_pid", getpid());
    Privs = ((program)"privs");
    add_constant("Privs", Privs);
  }
  perror("Roxen version "+roxen->cvs_version+"\n"
	 "Roxen release "+roxen->real_version+"\n");
  nwrite = roxen->nwrite;
}

object|void open(string filename, string mode, int|void perm)
{
  object o;
  o=Stdio.File();
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

  mark_fd(o->query_fd(), filename+" (mode: "+mode+")");
  return o;
}

string make_path(string ... from)
{
  return Array.map(from, lambda(string a, string b) {
    return (a[0]=='/')?combine_path("/",a):combine_path(b,a);
    //return combine_path(b,a);
  }, getcwd())*":";
}

int main(mixed ... args)
{
  string path = make_path("base_server", "etc/include", ".");
  roxen_perror("Roxen loader version "+cvs_version+"\n");
  roxen_perror("Roxen started on "+ctime(time()));	// ctime has an lf.
  master()->putenv("PIKE_INCLUDE_PATH", path);
  master()->pike_include_path = path/":";

  replace_master(new_master=(((program)"etc/roxen_master.pike")()));

  add_constant("open_db", open_db);
  add_constant("do_destruct", lambda(object o) {
    if(o&&objectp(o))  destruct(o);
  });

  add_constant("error", lambda(string s){error(s);});

  add_constant("spawne",spawne);
  add_constant("spawn_pike",spawn_pike);
  add_constant("perror",perror);
  add_constant("roxen_perror",perror);
  add_constant("popen",popen);

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
  roxen_perror("-------------------------------------\n\n");
  return(retval);
}
