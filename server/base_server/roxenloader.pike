/*
 * $Id: roxenloader.pike,v 1.140 2000/02/13 16:28:32 per Exp $
 *
 * Roxen bootstrap program.
 *
 */

// Sets up the roxen environment. Including custom functions like spawne().

#include <stat.h>

//
// NOTE:
//	This file uses replace_master(). This implies that the
//	master() efun when used in this file will return the old
//	master and not the new one.
//
private static object new_master;

#define werror roxen_perror

constant cvs_version="$Id: roxenloader.pike,v 1.140 2000/02/13 16:28:32 per Exp $";

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

string oct;
int last_was_change;
int roxen_started = time();
string short_time()
{
  if( last_was_change>0 )
    switch( last_was_change-- )
    {
     default:
       return "          : ";
     case 5:
       float up = time(roxen_started);
       if( up > 3600 )
       {
         return sprintf( "%2dd%2dh%2dm : ",
                       (int)up/216000,
                       (((int)up/3600)%24),
                       ((int)up/60)%60);
       }
       return sprintf( "%2dm%4.1fs  : ",((int)up/60)%60, up%60 );
    }
  mapping l = localtime( time( ) );
  string ct =  sprintf("%2d:%02d:%02d  : ", l->hour, l->min, l->sec );
  last_was_change=5;
  oct = ct;
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

int last_was_nl;
// Used to print error/debug messages
void roxen_perror(string format, mixed ... args)
{
  int t = time();
  spider;

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

    array(string) a = format/"\n";
    int i;

    a = map( a, possibly_encode );

    for(i=0; i < sizeof(a)-1; i++) {
      stderr->write(short_time() + a[i] + "\n");
    }
    if (!last_was_nl) {
      stderr->write(short_time() + a[-1]);
    }
  }

  if (delayed_nl) last_was_nl = -1;
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
    if (query_num_arg() > 1) {
      mkdir(b+a, mode);
#if constant(chmod)
      array(int) stat = file_stat (b + a, 1);
      if (stat && stat[0] & ~mode)
	// Race here. Not much we can do about it at this point. :\
	catch (chmod (b+a, stat[0] & mode));
#endif
    }
    else mkdir(b+a);
    b+=a+"/";
  }
  if(!r)
    return (file_stat(from)||({0,0}))[1] == -2;
  return 1;
}

/*
 * PDB support
 */
// object db;
// mapping dbs = ([ ]);

// #if constant(thread_create)
// static private inherit Thread.Mutex:db_lock;
// #endif

// object open_db(string id)
// {
// #if constant(thread_create)
//   object key = db_lock::lock();
// #endif
// #if constant(myPDB)
//   if(!db) db = myPDB.PDB()->db("pdb_dir", "wcCr"); //myPDB ignores 2nd arg.
// #else
//   if(!db) db = PDB->db("pdb_dir", "wcCr");
// #endif
//   if(dbs[id]) return dbs[id];
//   return dbs[id]=db[id];
// }


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
void report_debug(string message, mixed ... foo)
{
  if( sizeof( foo ) )
    message = sprintf(message, @foo );
  roxen_perror( message );
}


array find_module_and_conf_for_log( array q )
{
  object conf, mod;
  for( int i = 0; i<sizeof( q ); i++ )
  {
    object o = function_object( q[i][2] );
//     werror(" We are in %O:%O <%d,%d>\n",
//            o, q[i][2], o->is_configuration, o->is_module);
    if( o->is_configuration )
      conf = o;
    else if( o->is_module )
      mod = o;
  }
  return ({ mod,conf });
}


#define MC @find_module_and_conf_for_log(backtrace())

// Print a warning
void report_warning(string message, mixed ... foo)
{
  if( sizeof( foo ) ) message = sprintf(message, @foo );
  nwrite(message,0,2,MC);
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_WARNING))
    foreach(message/"\n", message)
      syslog(LOG_WARNING, replace(message+"\n", "%", "%%"));
#endif
}

// Print a notice
void report_notice(string message, mixed ... foo)
{
  if( sizeof( foo ) ) message = sprintf(message, @foo );
  nwrite(message,0,1,MC);
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_NOTICE))
    foreach(message/"\n", message)
      syslog(LOG_NOTICE, replace(message+"\n", "%", "%%"));
#endif
}

// Print an error message
void report_error(string message, mixed ... foo)
{
  if( sizeof( foo ) ) message = sprintf(message, @foo );
  nwrite(message,0,3,MC);
#if efun(syslog)
  if(use_syslog && (loggingfield&LOG_ERR))
    foreach(message/"\n", message)
      syslog(LOG_ERR, replace(message+"\n", "%", "%%"));
#endif
}

// Print a fatal error message
void report_fatal(string message, mixed ... foo)
{
  if( sizeof( foo ) ) message = sprintf(message, @foo );
  nwrite(message,0,3,MC);
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
  int u, g;
  if(uid) { u = uid[0]; g = uid[1]; }
#if efun(geteuid)
  else { u=geteuid(); g=getegid(); }
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

  add_constant("Stdio.File", Stdio.File );
  add_constant("Stdio.stderr", Stdio.stderr );
  add_constant("Stdio.stdout", Stdio.stdout );
  add_constant("Stdio.stdin", Stdio.stdin );
  add_constant("cache_set", cache->cache_set);
  add_constant("cache_lookup", cache->cache_lookup);
  add_constant("cache_remove", cache->cache_remove);
  add_constant("cache_clear", cache->cache_clear);
  add_constant("cache_expire", cache->cache_expire);
  add_constant("capitalize",
               lambda(string s){return upper_case(s[0..0])+s[1..];});
}

array compile_error_handlers = ({});
void push_compile_error_handler( object q )
{
  compile_error_handlers = ({q})+compile_error_handlers;
}

void pop_compile_error_handler()
{
  compile_error_handlers = compile_error_handlers[1..];
}

class LowErrorContainer
{
  string d;
  string errors="";
  string get()
  {
    return errors;
  }
  void got_error(string file, int line, string err)
  {
    if (file[..sizeof(d)-1] == d) {
      file = file[sizeof(d)..];
    }
    errors += sprintf("%s:%s\t%s\n", file, line ? (string) line : "-", err);
  }
  void compile_error(string file, int line, string err)
  {
    got_error(file, line, "Error: " + err);
  }
  void compile_warning(string file, int line, string err)
  {
    got_error(file, line, "Warning: " + err);
  }
  void `() (string file, int line, string err)
  {
    got_error (file, line, err);
  }
  void create()
  {
    d = getcwd();
    if (sizeof(d) && (d[-1] != '/') && (d[-1] != '\\'))
      d += "/";
  }
}

class ErrorContainer
{
  inherit LowErrorContainer;

  void compile_error(string file, int line, string err)
  {
    if( sizeof(compile_error_handlers) )
      compile_error_handlers->compile_error( file,line, err );
    else
      ::compile_error(file,line,err);
  }
  void compile_warning(string file, int line, string err)
  {
    if( sizeof(compile_error_handlers) )
      compile_error_handlers->compile_warning( file,line, err );
    else
      ::compile_warning(file,line,err);
  }
  void `() (string file, int line, string err)
  {
    if( sizeof(compile_error_handlers) )
      compile_error_handlers->compile_error( file,line,err );
    else
      ::compile_error(file,line,err);
  }
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
  report_debug("Loading roxen ... ");
  object e = ErrorContainer();
  object res;
  master()->set_inhibit_compile_errors(e);
  mixed err = catch {
    res =((program)"roxen")();
  };
  master()->set_inhibit_compile_errors(0);
  string q = e->get();
  if (err) {
    report_debug("ERROR\n" + (q||""));
    throw(err);
  }
  report_debug("done after %3.3fs\n",
	       (gethrtime()-start_time)/1000000.0);

  if (q && sizeof(q)) {
    report_debug("Warnings compiling Roxen:\n" + q);
  }
  res->start_time = start_time;
  res->boot_time = start_time;
  nwrite = res->nwrite;
  return res;
}

// Debug function to trace calls to destruct().
#ifdef TRACE_DESTRUCT
void trace_destruct(mixed x)
{
  report_debug("DESTRUCT(%O)\n%s\n",
               x, describe_backtrace(backtrace())):
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

#ifndef OLD_PARSE_HTML
  // Temporary kludge to get wide string rxml parsing.
  add_constant("parse_html", parse_html);
  add_constant("parse_html_lines", parse_html_lines);
#endif

  roxen = really_load_roxen();

  report_debug("roxen.pike version "+(roxen->cvs_version/ " ")[2]+"\n"
	       "Roxen release "+roxen->real_version+"\n"
#ifdef __NT__
	       "Running on NT\n"
#endif
    );
}


#ifndef OLD_PARSE_HTML

static int|string|array(string) compat_call_tag (
  Parser.HTML p, string str, mixed... extra)
{
  string name = lower_case (p->tag_name());
  if (string|function tag = p->m_tags[name])
    if (stringp (tag)) return ({tag});
    else return tag (name, p->tag_args(), @extra);
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
    if (stringp (container)) return ({container});
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

string parse_html (string data, mapping tags, mapping containers,
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
    if (stringp (container)) return ({container});
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

#if 0&&constant(fork)
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
    report_error("Error in bootstrap code: %s\n"
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

void write_current_time()
{
  if( !roxen )
  {
    call_out( write_current_time, 10 );
    return;
  }
  int t = time();
  report_debug("\n** "+roxen->strftime("%Y-%m-%d %H:%M", t )+
               "   pid: "+pid+"   ppid: "+getppid()+
#if efun(geteuid)
	       (geteuid()!=getuid()?"   euid: "+pw_name(geteuid()):"")+
#endif
               "   uid: "+pw_name(getuid())+"\n\n");
  call_out( write_current_time, 3600 - t % 3600 );
}

void paranoia_throw(mixed err)
{
  if ((arrayp(err) && ((sizeof(err) < 2) || !stringp(err[0]) ||
		       !arrayp(err[1]) ||
		       !(arrayp(err[1][0])||stringp(err[1][0])))) ||
      (!arrayp(err) && (!objectp(err) || !err->is_generic_error))) {
    report_debug(sprintf("Warning: throwing non-error: %O\n"
			 "From: %s\n",
			 err, describe_backtrace(backtrace())));
  }
  throw(err);
}

int global_count;

// Roxen bootstrap code.
int main(int argc, array argv)
{
  call_out( do_main, 0, argc, argv );
  // Get rid of the _main and main() backtrace elements..
  return -1;
}

void do_main( int argc, array argv )
{
  array hider = argv;
  argv = 0;

#ifdef NOT_INSTALLED
report_debug(
#"


*************************** WARNING ***************************
You are running with an un-installed pike binary.

Please note that this is unsupported, and might stop working at
any time, since some things are done differently in uninstalled
pikes, as an example the module search paths are different, and
some environment variables are ignored.
*************************** WARNING ***************************


");
#endif

#if __VERSION__ < 0.7
report_debug(
#"


******************************************************
Roxen 2.0 requires pike 7.
Please install a newer pike version
******************************************************


");
 _exit(0); /* 0 means stop start script looping */
#endif /* __VERSION__ < 0.7 */



 int start_time = gethrtime();
  string path = make_path("base_server", "etc/include", ".");
  last_was_nl = 1;
  report_debug("\n"+version()+"\n");
  report_debug("Roxen loader version "+(cvs_version/" ")[2]+"\n");
  master()->putenv("PIKE_INCLUDE_PATH", path);
  foreach(path/":", string p) {
    add_include_path(p);
    add_program_path(p);
  }

#if 0&&constant(fork)
  if (catch { getpw_kluge(); }) {
    /* We're in the kluge process, and it's time to die... */
    exit(0);
  }
#endif /* constant(fork) */

#ifdef INTERNAL_ERROR_DEBUG
  add_constant("throw", paranoia_throw);
#endif /* INTERNAL_ERROR_DEBUG */

  replace_master(new_master=(((program)"etc/roxen_master.pike")()));

//   add_constant("open_db", open_db);
  add_constant("roxenloader", this_object());
  add_constant("ErrorContainer", ErrorContainer);
  add_constant("spawne",spawne);
  add_constant("spawn_pike",spawn_pike);
  add_constant("perror",roxen_perror);
  add_constant("werror",roxen_perror);
  add_constant("roxen_perror",roxen_perror);
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

  add_constant( "ST_MTIME", ST_MTIME );
  add_constant( "ST_CTIME", ST_CTIME );
  add_constant( "ST_SIZE",  ST_SIZE );

  // It's currently tricky to test for Image.TTF correctly with a
  // preprocessor directive, so let's add a constant for it.
#if constant (Image.TTF)
  if (sizeof (indices (Image.TTF)))
    add_constant ("has_Image_TTF", 1);
#endif

  if( search( hider, "--long-error-file-names" ) != -1 )
  {
    hider -= ({ "--long-error-file-names" });
    argc = sizeof(hider);
    new_master->long_file_names = 1;
    new_master->putenv("LONG_PIKE_ERRORS", "yup");
  }

  initiate_cache();
  load_roxen();

  int retval = roxen->main(argc,hider);
  report_debug("\n-- Total boot time %2.1f seconds ---------------------------\n",
	       (gethrtime()-start_time)/1000000.0);
  write_current_time();
  if( retval > -1 )
    exit( retval );
  return;
}
