import files;
import spider;

#define error(X) do{array Y=backtrace();throw(({(X),Y[..sizeof(Y)-2]}));}while(0)

// Set up the roxen enviornment. Including custom functions like spawne().
string cvs_version="$Id: roxenloader.pike,v 1.7 1997/02/13 13:01:01 per Exp $";

void perror(string format,mixed ... args);

string popen(string s, void|mapping env, int|void uid, int|void gid)
{
  object p,p2;

  p2 = file();
  p=p2->pipe();
  if(!p) error("Popen failed. (couldn't create pipe)\n");

  if(!fork())
  {
    array (int) olduid = ({ -1, -1 });
    catch {
      if(p->query_fd() < 0)
      {
	perror("File to dup2 to closed!\n");
	exit(99);
      }
      p->dup2(file("stdout"));
      if(uid || gid)
      {
	object privs = ((program)"privs")("Executing script as non-www user");
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
    destruct(p);
    t=p2->read(0x7fffffff);
    destruct(p2);
    return t;
  }
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
  
  
  stdin->dup2(file("stdin"));
  stdout->dup2(file("stdout"));
  stderr->dup2(file("stderr"));
  if(stringp(wd) && sizeof(wd))
    cd(wd);
  exece(s, args, env);
  perror(sprintf("Spawne: Failed to exece %s\n", s));
  exit(0);
}

int spawne(string s,string *args, mapping|array env, object stdin, 
	   object stdout, object stderr, void|string wd, void|array (int) uid)
{
  int pid, *olduid = allocate(2, "int");
  object privs;

  if(pid=fork()) return pid;

  if(arrayp(uid) && sizeof(uid) == 2)
  {
    privs = ((program)"privs")("Executing program as non-www user (outside roxen)");
    setgid(uid[1]);
    setuid(uid[0]);
  } 
  catch(low_spawne(s, args, env, stdin, stdout, stderr, wd));
  exit(0); 
}

private static int perror_last_was_newline=1;

void perror(string format,mixed ... args)
{
   string s;
   int lwn;
   s=((args==({}))?format:sprintf(format,@args));
   if (s=="") return;
   if ( (lwn = s[-1]=="\n") )
      s=s[0..strlen(s)-2];
   werror((perror_last_was_newline?getpid()+": ":"")
	  +replace(s,"\n","\n"+getpid()+": ")
          +(lwn?"\n":""));
   perror_last_was_newline=lwn;
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
  cache=((program)"base_server/cache")();
  add_constant("cache_set", cache->cache_set);
  add_constant("cache_lookup", cache->cache_lookup);
  add_constant("cache_remove", cache->cache_remove);
  add_constant("cache", cache);
  add_constant("capitalize", lambda(string s){return upper_case(s[0..0])+s[1..];});
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

void main(mixed ... args)
{
  object mm;
  perror("Roxen loader version "+cvs_version+"\n");
  replace_master(mm=(object)"etc/master");

  mm->pike_library_path = master()->pike_library_path;
  mm->putenv("PIKE_INCLUDE_PATH", "base_server/:etc/include/:.");


  add_constant("error", lambda(string s){error(s);});

  add_constant("spawne",spawne);
  add_constant("perror",perror);
  add_constant("popen",popen);

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
  
