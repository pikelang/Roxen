/*
 * $Id: roxen.pike,v 1.326 1999/09/10 22:08:17 mast Exp $
 *
 * The Roxen Challenger main program.
 *
 * Per Hedbor, Henrik Grubbström, Pontus Hagland, David Hedbor and others.
 */

// ABS and suicide systems contributed freely by Francesco Chemolli
constant cvs_version="$Id: roxen.pike,v 1.326 1999/09/10 22:08:17 mast Exp $";

object backend_thread;
object argcache;

// Some headerfiles
#define IN_ROXEN
#include <roxen.h>
#include <config.h>
#include <module.h>
#include <variables.h>
#include <stat.h>

// Inherits
inherit "global_variables";
inherit "hosts";
inherit "disk_cache";
inherit "language";
inherit "supports";

/*
 * Version information
 */
constant __roxen_version__ = "1.4";
constant __roxen_build__ = "38";

#ifdef __NT__
string real_version= "Roxen Challenger/"+__roxen_version__+"."+__roxen_build__+" NT";
#else
string real_version= "Roxen Challenger/"+__roxen_version__+"."+__roxen_build__;
#endif

// Prototypes for other parts of roxen.
class RequestID 
{
  object conf; // Really Configuration, but that's sort of recursive.
  int time;
  string raw_url;
  int do_not_disconnect;
  mapping (string:string) variables;
  mapping (string:mixed) misc;
  mapping (string:string) cookies;
  mapping (string:string) request_headers;
  multiset(string) prestate;
  multiset(string) config;
  multiset(string) supports;
  multiset(string) pragma;
  array(string) client;
  array(string) referer;

  Stdio.File my_fd;
  string prot;
  string clientprot;
  string method;
  
  string realfile;
  string virtfile;
  string rest_query;
  string raw;
  string query;
  string not_query;
  string extra_extension;
  string data;
  string leftovers;
  array (int|string) auth;
  string rawauth;
  string realauth;
  string since;
  string remoteaddr;
  string host;

  void create(object|void master_request_id);
  void send(string|object what, int|void len);
  string scan_for_query( string in );
  void end(string|void s, int|void keepit);
  void ready_to_receive();
  void send_result(mapping|void result);
  RequestID clone_me();
};


/*
 * The privilege changer.
 *
 * Based on privs.pike,v 1.36.
 */

string filename( object o )
{
  return search( master()->programs, object_program( o ) );
}

// Some variables used by Privs
#ifdef THREADS
// This mutex is used by Privs
object euid_egid_lock = Thread.Mutex();
#endif /* THREADS */

int privs_level;

static class Privs {
#if efun(seteuid)

  int saved_uid;
  int saved_gid;

  int new_uid;
  int new_gid;

#define LOGP (variables && variables->audit && GLOBVAR(audit))

#if constant(geteuid) && constant(getegid) && constant(seteuid) && constant(setegid)
#define HAVE_EFFECTIVE_USER
#endif

  static private string _getcwd()
  {
    if (catch{return(getcwd());}) {
      return("Unknown directory (no x-bit on current directory?)");
    }
  }

  static private string dbt(array t)
  {
    if(!arrayp(t) || (sizeof(t)<2)) return "";
    return (((t[0]||"Unknown program")-(_getcwd()+"/"))-"base_server/")+":"+t[1]+"\n";
  }

#ifdef THREADS
  static mixed mutex_key;	// Only one thread may modify the euid/egid at a time.
  static object threads_disabled;
#endif /* THREADS */

  int p_level;

  void create(string reason, int|string|void uid, int|string|void gid)
  {
#ifdef PRIVS_DEBUG
    werror(sprintf("Privs(%O, %O, %O)\n"
		   "privs_level: %O\n",
		   reason, uid, gid, privs_level));
#endif /* PRIVS_DEBUG */

#ifdef HAVE_EFFECTIVE_USER
    array u;

#ifdef THREADS
    if (euid_egid_lock) {
      catch { mutex_key = euid_egid_lock->lock(); };
    }
    threads_disabled = _disable_threads();
#endif /* THREADS */

    p_level = privs_level++;

    if(getuid()) return;

    /* Needs to be here since root-priviliges may be needed to
     * use getpw{uid,nam}.
     */
    saved_uid = geteuid();
    saved_gid = getegid();
    seteuid(0);

    /* A string of digits? */
    if (stringp(uid) && ((int)uid) &&
	(replace(uid, ({ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" }),
		 ({ "", "", "", "", "", "", "", "", "", "" })) == "")) {
      uid = (int)uid;
    }
    if (stringp(gid) && ((int)gid) &&
	(replace(gid, ({ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" }),
		 ({ "", "", "", "", "", "", "", "", "", "" })) == "")) {
      gid = (int)gid;
    }

    if(!stringp(uid)) {
      u = getpwuid(uid);
    } else {
      u = getpwnam(uid);
      if(u) 
	uid = u[2];
    }

    if(u && !gid) gid = u[3];
  
    if(!u) {
      if (uid && (uid != "root")) {
	if (intp(uid) && (uid >= 60000)) {
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
      report_notice(sprintf("Change to %s(%d):%d privs wanted (%s), from %s",
			    (string)u[0], (int)uid, (int)gid,
			    (string)reason,
			    (string)dbt(backtrace()[-2])));

#if efun(cleargroups)
    catch { cleargroups(); };
#endif /* cleargroups */
#if efun(initgroups)
    catch { initgroups(u[0], u[3]); };
#endif
    gid = gid || getgid();
    int err = (int)setegid(new_gid = gid);
    if (err < 0) {
      report_debug(sprintf("Privs: WARNING: Failed to set the effective group id to %d!\n"
			   "Check that your password database is correct for user %s(%d),\n"
			   "and that your group database is correct.\n",
			   gid, (string)u[0], (int)uid));
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
	perror("Privs: WARNING: Assuming nobody-group.\n"
	       "Trying some alternatives...\n");
	// Assume we want the nobody group, and try a couple of alternatives
	foreach(({ 60001, 65534, -2 }), gid2) {
	  perror("%d... ", gid2);
	  if (initgroups(u[0], gid2) >= 0) {
	    if ((err = setegid(new_gid = gid2)) >= 0) {
	      perror("Success!\n");
	      break;
	    }
	  }
	}
      }
#endif /* HPUX_KLUDGE */
      if (err < 0) {
	perror("Privs: Failed\n");
	throw(({ sprintf("Failed to set EGID to %d\n", gid), backtrace() }));
      }
      perror("Privs: WARNING: Set egid to %d instead of %d.\n",
	     gid2, gid);
      gid = gid2;
    }
    if(getgid()!=gid) setgid(gid||getgid());
    seteuid(new_uid = uid);
#endif /* HAVE_EFFECTIVE_USER */
  }

  void destroy()
  {
#ifdef PRIVS_DEBUG
    werror(sprintf("Privs->destroy()\n"
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
      catch {
	array bt = backtrace();
	if (sizeof(bt) >= 2) {
	  report_notice(sprintf("Change back to uid#%d gid#%d, from %s\n",
				saved_uid, saved_gid, dbt(bt[-2])));
	} else {
	  report_notice(sprintf("Change back to uid#%d gid#%d, from backend\n",
				saved_uid, saved_gid));
	}
      };
    }

    if(getuid()) return;

#ifdef DEBUG
    int uid = geteuid();
    if (uid != new_uid) {
      report_warning(sprintf("Privs: UID #%d differs from expected #%d\n"
			     "%s\n",
			     uid, new_uid, describe_backtrace(backtrace())));
    }
    int gid = getegid();
    if (gid != new_gid) {
      report_warning(sprintf("Privs: GID #%d differs from expected #%d\n"
			     "%s\n",
			     gid, new_gid, describe_backtrace(backtrace())));
    }
#endif /* DEBUG */

    seteuid(0);
    array u = getpwuid(saved_uid);
#if efun(cleargroups)
    catch { cleargroups(); };
#endif /* cleargroups */
    if(u && (sizeof(u) > 3)) {
      catch { initgroups(u[0], u[3]); };
    }
    setegid(saved_gid);
    seteuid(saved_uid);
#endif /* HAVE_EFFECTIVE_USER */
  }
#endif /* efun(seteuid) */
};

/* Used by read_config.pike, since there seems to be problems with
 * overloading otherwise.
 */
static object PRIVS(string r, int|string|void u, int|string|void g)
{
  return Privs(r, u, g);
}


#if _DEBUG_HTTP_OBJECTS
mapping httpobjects = ([]);
static int idcount;
int new_id(){ return idcount++; }
#endif

#ifdef MODULE_DEBUG
#define MD_PERROR(X)	roxen_perror X;
#else
#define MD_PERROR(X)
#endif /* MODULE_DEBUG */

// pids of the start-script and ourselves.
int startpid, roxenpid;

#ifndef THREADS
class container
{
  mixed value;
  mixed set(mixed to)
  {
    return value=to;
  }
  mixed get()
  {
    return value;
  }
}
#endif

// Locale support
Locale.Roxen.standard default_locale=Locale.Roxen.standard;
object fonts;
#ifdef THREADS
object locale = thread_local();
#else
object locale = container(); 
#endif /* THREADS */
#define LOCALE	LOW_LOCALE->base_server

program Configuration;	/*set in create*/

array configurations = ({});
object main_configuration_port;
mapping allmodules, somemodules=([]);

// A mapping from ports (objects, that is) to an array of information
// about that port.  This will hopefully be moved to objects cloned
// from the configuration object in the future.
mapping portno=([]);

// Function pointer and the root of the configuration interface
// object.
function build_root;
object root;

int die_die_die;

void stop_all_modules()
{
  foreach(configurations, object conf)
    conf->stop();
}

// Function that actually shuts down Roxen. (see low_shutdown).
private static void really_low_shutdown(int exit_code)
{
  // Die nicely.
#ifdef THREADS
  catch( stop_handler_threads() );
#endif /* THREADS */
  exit(exit_code);		// Now we die...
}

// Shutdown Roxen
//  exit_code = 0	True shutdown
//  exit_code = -1	Restart
private static void low_shutdown(int exit_code)
{
  catch( stop_all_modules() );
  
  int pid;
  if (exit_code) {
    roxen_perror("Restarting Roxen.\n");
  } else {
    roxen_perror("Shutting down Roxen.\n");
    // exit(0);
  }
  call_out(really_low_shutdown, 0.1, exit_code);
}

// Perhaps somewhat misnamed, really...  This function will close all
// listen ports and then quit.  The 'start' script should then start a
// new copy of roxen automatically.
mapping restart() 
{ 
  low_shutdown(-1);
  return ([ "data": replace(Stdio.read_bytes("etc/restart.html"),
		    ({"$docurl", "$PWD"}), ({docurl, getcwd()})),
  	    "type":"text/html" ]);
} 

mapping shutdown() 
{
  low_shutdown(0);
  return ([ "data":replace(Stdio.read_bytes("etc/shutdown.html"),
			   ({"$docurl", "$PWD"}), ({docurl, getcwd()})),
	    "type":"text/html" ]);
} 

// This is called for each incoming connection.
private static void accept_callback( object port )
{
  object file;
  int q=QUERY(NumAccept);
  array pn=portno[port];

  while(q--)
  {
    catch { file = port->accept(); };
#ifdef SOCKET_DEBUG
    if(!pn[-1])
    {
      report_error("In accept: Illegal protocol handler for port.\n");
      if(file) destruct(file);
      return;
    }
    perror(sprintf("SOCKETS: accept_callback(CONF(%s))\n", 
		   pn[1]&&pn[1]->name||"Configuration"));
#endif
    if(!file)
    {
      switch(port->errno())
      {
       case 0:
#if constant(system.EAGAIN)
      case system.EAGAIN:
#endif /* constant(system.EAGAIN) */
	return;

#if constant(system.EMFILE)
      case system.EMFILE:
#endif /* constant(system.EMFILE) */
#if constant(system.EBADF)
      case system.EBADF:
#endif /* constant(system.EBADF) */
	report_fatal(LOCALE->out_of_sockets());
	low_shutdown(-1);
	return;

      default:
#ifdef DEBUG
	perror("Accept failed.\n");
#if constant(real_perror)
	real_perror();
#endif
#endif /* DEBUG */
 	return;
      }
    }
#ifdef FD_DEBUG
    mark_fd( file->query_fd(),
	     LOCALE->out_of_sockets(file->query_address()));
#endif
    pn[-1](file,pn[1],pn);
#ifdef SOCKET_DEBUG
    perror(sprintf("SOCKETS:   Ok. Connect on %O:%O from %O\n", 
		   pn[2], pn[0], file->query_address()));
#endif
  }
}

/*
 * handle() stuff
 */

#ifndef THREADS
// handle function used when THREADS is not enabled.
void unthreaded_handle(function f, mixed ... args)
{
  f(@args);
}

function handle = unthreaded_handle;
#else
function handle = threaded_handle;
#endif

/*
 * THREADS code starts here
 */
#ifdef THREADS
// #define THREAD_DEBUG

object do_thread_create(string id, function f, mixed ... args)
{
  object t = thread_create(f, @args);
  catch(t->set_name( id ));
  roxen_perror(id+" started\n");
  return t;
}

// Queue of things to handle.
// An entry consists of an array(function fp, array args)
static object (Thread.Queue) handle_queue = Thread.Queue();

// Number of handler threads that are alive.
static int thread_reap_cnt;

void handler_thread(int id)
{
  array (mixed) h, q;
  while(!die_die_die)
  {
    if(q=catch {
      do {
#ifdef THREAD_DEBUG
	werror("Handle thread ["+id+"] waiting for next event\n");
#endif /* THREAD_DEBUG */
	if((h=handle_queue->read()) && h[0]) {
#ifdef THREAD_DEBUG
	  werror(sprintf("Handle thread [%O] calling %O(@%O)...\n",
			 id, h[0], h[1..]));
#endif /* THREAD_DEBUG */
	  SET_LOCALE(default_locale);
	  h[0](@h[1]);
	  h=0;
	} else if(!h) {
	  // Roxen is shutting down.
	  werror("Handle thread ["+id+"] stopped\n");
	  thread_reap_cnt--;
	  return;
	}
      } while(1);
    }) {
      report_error(/* LOCALE->uncaught_error(*/describe_backtrace(q)/*)*/);
      if (q = catch {h = 0;}) {
	report_error(LOCALE->
		     uncaught_error(describe_backtrace(q)));
      }
    }
  }
}

void threaded_handle(function f, mixed ... args)
{
  handle_queue->write(({f, args }));
}

int number_of_threads;
void start_handler_threads()
{
  if (QUERY(numthreads) <= 1) {
    QUERY(numthreads) = 1;
    report_debug("Starting 1 thread to handle requests.\n");
  } else {
    report_debug("Starting "+QUERY(numthreads)
                 +" threads to handle requests.\n");
  }
  for(; number_of_threads < QUERY(numthreads); number_of_threads++)
    do_thread_create( "Handle thread ["+number_of_threads+"]",
		   handler_thread, number_of_threads );
}

void stop_handler_threads()
{
  int timeout=10;
  roxen_perror("Stopping all request handler threads.\n");
  while(number_of_threads>0) {
    number_of_threads--;
    handle_queue->write(0);
    thread_reap_cnt++;
  }
  while(thread_reap_cnt) {
    if(--timeout<=0) {
      roxen_perror("Giving up waiting on threads!\n");
      return;
    }
    sleep(0.1);
  }
}
#endif /* THREADS */



// Listen to a port, connected to the configuration 'conf', binding
// only to the netinterface 'ether', using 'requestprogram' as a
// protocol handled.

// If you think that the argument order is quite unintuitive and odd,
// you are right, the order is the same as the implementation order.

// Old spinners only listened to a port number, then the
// configurations came, then the need to bind to a specific
// ethernetinterface, and then the need to have more than one concurrent
// protocol (http, ftp, ssl, etc.)

object create_listen_socket(mixed port_no, object conf,
			    string|void ether, program requestprogram,
			    array prt)
{
  object port;
#ifdef SOCKET_DEBUG
  perror(sprintf("SOCKETS: create_listen_socket(%d,CONF(%s),%s)\n",
		 port_no, conf?conf->name:"Configuration port", ether));
#endif
  if(!requestprogram)
    error("No request handling module passed to create_listen_socket()\n");

  if(!port_no)
  {
    port = Stdio.Port( "stdin", accept_callback );
    port->set_id(port);
    if(port->errno()) {
      report_error(LOCALE->stdin_is_quiet(port->errno()));
    }
  } else {
    port = Stdio.Port();
    port->set_id(port);
    if(!stringp(ether) || (lower_case(ether) == "any"))
      ether=0;
    if(ether)
      sscanf(ether, "addr:%s", ether);
    if(!port->bind(port_no, accept_callback, ether))
    {
#ifdef SOCKET_DEBUG
      perror("SOCKETS:    -> Failed.\n");
#endif
      report_warning(LOCALE->
		     socket_already_bound_retry(ether, port_no,
						port->errno()));
      sleep(1);
      if(!port->bind(port_no, accept_callback, ether))
      {
	report_warning(LOCALE->
		       socket_already_bound(ether, port_no, port->errno()));
	return 0;
      }
    }
  }
  portno[port]=({ port_no, conf, ether||"Any", 0, requestprogram });
#ifdef SOCKET_DEBUG
  perror("SOCKETS:    -> Ok.\n");
#endif
  return port;
}


/*
 * Port DB stuff.
 */

// ([ "prot" : ([ "ip" : ([ port : protocol_handler, ]), ]), ])
static mapping(string:mapping(string:mapping(int:object))) handler_db = ([]);

// ([ "prot" : protocol_program, ])
static mapping(string:program) port_db = ([]);

// Is there a handler for this port?
object low_find_handler(string prot, string ip, int port)
{
  mixed res;
  return((res = handler_db[prot]) && (res = res[ip]) && res[port]);
}

// Register a handler for a port.
void register_handler(string prot, string ip, int port, object handler)
{
  mapping m;
  if (m = handler_db[prot]) {
    mapping mm;
    if (mm = m[ip]) {
      // FIXME: What if mm[port] already exists?
      mm[port] = handler;
    } else {
      m[ip] = ([ port : handler ]);
    }
  } else {
    handler_db[prot] = ([ ip : ([ port : handler ]) ]);
  }
}

object find_handler(string prot, string ip, int port)
{
  object handler = low_find_handler(prot, ip, port);

  if (!handler) {
    program prog = port_db[prot];
    if (!prog) {
      return 0;
    }
    mixed err = catch {
      handler = prog(prot, ip, port);
    };
    if (err) {
      report_error(LOCALE->failed_to_open_port("?",
					       sprintf("%s://%s:%d/",
						       prot, ip, port),
					       describe_backtrace(err)));
    } else {
      register_handler(prot, ip, port, handler);
    }
  }
  return handler;
}

// The configuration interface is loaded dynamically for faster
// startup-time, and easier coding in the configuration interface (the
// Roxen environment is already finished when it is loaded)
object configuration_interface_obj;
int loading_config_interface;
int enabling_configurations;

object configuration_interface()
{
  if(enabling_configurations)
    return 0;
  if(loading_config_interface)
    perror("Recursive calls to configuration_interface()\n"
	   + describe_backtrace(backtrace())+"\n");
  
  if(!configuration_interface_obj)
  {
    perror("Loading configuration interface.\n");
    loading_config_interface = 1;
    array err = catch {
      configuration_interface_obj=((program)"mainconfig")();
      root = configuration_interface_obj->root;
      build_root = configuration_interface_obj->build_root;
    };
    loading_config_interface = 0;
    if(!configuration_interface_obj) {
      report_error(LOCALE->
		   configuration_interface_failed(describe_backtrace(err)));
    }
  }
  return configuration_interface_obj;
}

// Unload the configuration interface
void unload_configuration_interface()
{
  report_notice(LOCALE->unload_configuration_interface());

  configuration_interface_obj = 0;
  loading_config_interface = 0;
  enabling_configurations = 0;
  build_root = 0;
  catch{root->dest();};
  root = 0;
}


// Create a new configuration from scratch.

// 'type' is as in the form. 'none' for a empty configuration.
int add_new_configuration(string name, string type)
{
  return configuration_interface()->low_enable_configuration(name, type);
}

#ifdef THREADS
object configuration_lock = Thread.Mutex();
#endif

// Call the configuration interface function. This is more or less
// equivalent to a virtual configuration with the configurationinterface
// mounted on '/'. This will probably be the case in future versions
mixed configuration_parse(mixed ... args)
{
#ifdef THREADS
  object key;
  catch(key = configuration_lock->lock());
#endif
  if(args)
    return configuration_interface()->configuration_parse(@args);
}

mapping(string:array(int)) error_log=([]);

string last_error="";

// Write a string to the configuration interface error log and to stderr.
void nwrite(string s, int|void perr, int|void type)
{
  last_error = s;
  if (!error_log[type+","+s]) {
    error_log[type+","+s] = ({ time() });
  } else {
    error_log[type+","+s] += ({ time() });
  }
  if(type>=1) roxen_perror(s);
}

// When was Roxen started?
int boot_time  =time();
int start_time =time();

string version()
{
  return QUERY(default_ident)?real_version:QUERY(ident);
}

public void log(mapping file, object request_id)
{
  if(!request_id->conf) return; 
  request_id->conf->log(file, request_id);
}

// Support for unique user id's 
private object current_user_id_file;
private int current_user_id_number, current_user_id_file_last_mod;

private void restore_current_user_id_number()
{
  if(!current_user_id_file)
    current_user_id_file = open(configuration_dir + "LASTUSER~", "rwc");
  if(!current_user_id_file)
  {
    call_out(restore_current_user_id_number, 2);
    return;
  } 
  current_user_id_number = (int)current_user_id_file->read(100);
  current_user_id_file_last_mod = current_user_id_file->stat()[2];
  perror("Restoring unique user ID information. (" + current_user_id_number 
	 + ")\n");
#ifdef FD_DEBUG
  mark_fd(current_user_id_file->query_fd(), LOCALE->unique_uid_logfile());
#endif
}


int increase_id()
{
  if(!current_user_id_file)
  {
    restore_current_user_id_number();
    return current_user_id_number+time();
  }
  if(current_user_id_file->stat()[2] != current_user_id_file_last_mod)
    restore_current_user_id_number();
  current_user_id_number++;
  //perror("New unique id: "+current_user_id_number+"\n");
  current_user_id_file->seek(0);
  current_user_id_file->write((string)current_user_id_number);
  current_user_id_file_last_mod = current_user_id_file->stat()[2];
  return current_user_id_number;
}

public string full_status()
{
  int tmp;
  string res="";
  array foo = ({0.0, 0.0, 0.0, 0.0, 0});
  if(!sizeof(configurations))
    return LOCALE->no_servers_enabled();
  
  foreach(configurations, object conf)
  {
    if(!conf->sent
       ||!conf->received
       ||!conf->hsent)
      continue;
    foo[0] += conf->sent->mb()/(float)(time(1)-start_time+1);
    foo[1] += conf->sent->mb();
    foo[2] += conf->hsent->mb();
    foo[3] += conf->received->mb();
    foo[4] += conf->requests;
  }

  for(tmp = 1; tmp < 4; tmp ++)
  {
    // FIXME: LOCALE?

    if(foo[tmp] < 1024.0)     
      foo[tmp] = sprintf("%.2f MB", foo[tmp]);
    else
      foo[tmp] = sprintf("%.2f GB", foo[tmp]/1024.0);
  }

  int uptime = time()-start_time;
  int days = uptime/(24*60*60);
  int hrs = uptime/(60*60);
  int min = uptime/60 - hrs*60;
  hrs -= days*24;

  tmp=(int)((foo[4]*600.0)/(uptime+1));

  return(LOCALE->full_status(real_version, boot_time, start_time-boot_time,
			     days, hrs, min, uptime%60,
			     foo[1], foo[0] * 8192.0, foo[2],
			     foo[4], (float)tmp/(float)10, foo[3]));
}


int config_ports_changed = 0;

static string MKPORTKEY(array(string) p)
{
  if (sizeof(p[3])) {
    return(sprintf("%s://%s:%s/(%s)",
		   p[1], p[2], (string)p[0],
		   replace(p[3], ({"\n", "\r"}), ({ " ", " " }))));
  } else {
    return(sprintf("%s://%s:%s/",
		   p[1], p[2], (string)p[0]));
  }
}

// Is this only used to hold the config-ports?
// Seems like it. Changed to a mapping.
private mapping(string:object) configuration_ports = ([]);

// Used by config_actions/openports.pike
array(object) get_configuration_ports()
{
  return(values(configuration_ports));
}

class Codec
{
  program p;
  string nameof(mixed x)
  {
    if(p!=x)
      if(mixed tmp=search(all_constants(),x))
	return "efun:"+tmp;

    switch(sprintf("%t",x))
    {
      case "program":
	if(p!=x)
	{
          mixed tmp;
	  if(tmp=search(master()->programs,x))
	    return tmp;

	  if((tmp=search(values(_static_modules), x))!=-1)
	    return "_static_modules."+(indices(_static_modules)[tmp]);
	}
	break;

      case "object":
	if(mixed tmp=search(master()->objects,x))
	{
	  if(tmp=search(master()->programs,tmp))
	  {
	    return tmp;
	  }
	}
	break;
    }

    return ([])[0];
  }

  function functionof(string x)
  {
    if(sscanf(x,"efun:%s",x))
      return all_constants()[x];

    werror("Failed to decode %s\n",x);
    return 0;
  }


  object objectof(string x)
  {
    if(sscanf(x,"efun:%s",x))
      return all_constants()[x];

    if(object tmp=(object)x) return tmp;
    werror("Failed to decode %s\n",x);
    return 0;
    
  }

  program programof(string x)
  {
    if(sscanf(x,"efun:%s",x))
      return all_constants()[x];

    if(sscanf(x,"_static_modules.%s",x))
    {
      return (program)_static_modules[x];
    }

    if(program tmp=(program)x) return tmp;
    werror("Failed to decode %s\n",x);
    return 0;
  }

  mixed encode_object(object x)
  {
    error("Cannot encode objects yet.\n");
  }

  mixed decode_object(object x)
  {
    error("Cannot encode objects yet.\n");
  }

  void create( program q )
  {
    p = q;
  }
}

int remove_dumped_mark = lambda ()
{
  array stat = file_stat (combine_path (
    getcwd(), __FILE__ + "/../../.remove_dumped_mark"));
  return stat && stat[ST_MTIME];
}();

program my_compile_file(string file)
{
  m_delete( master()->programs, file);
  string ofile = file + ".o";
  if (file_stat (ofile) &&
      file_stat (ofile)[ST_MTIME] < remove_dumped_mark)
    rm (ofile);
  program p  = (program)( file );
  if( !file_stat( ofile ) ||
      file_stat(ofile)[ST_MTIME] <
      file_stat(file)[ST_MTIME] )
    if( catch 
    {
      string data = encode_value( p, Codec(p) );
      if( strlen( data ) )
        Stdio.File( ofile, "wct" )->write( data );
    } )
    {
#ifdef MODULE_DEBUG
      werror(" [nodump] ");
#endif
      Stdio.File( ofile, "wct" );
    } else {
#ifdef MODULE_DEBUG
      werror(" [dump] ");
#endif
    }
  return p;
}

array compile_module( string file )
{
  array foo;
  object o;
  program p;

  MD_PERROR(("Compiling " + file + "...\n"));

  if (catch(p = my_compile_file(file)) || (!p)) {
    MD_PERROR((" compilation failed"));
    throw("MODULE: Compilation failed.\n");
  }
  
  array err = catch(o =  p());

  if (err) {
    MD_PERROR((" load failed\n"));
    throw(err);
  } else if (!o) {
    MD_PERROR((" load failed\n"));
    throw("Failed to initialize module.\n");
  } else {
    MD_PERROR((" load ok - "));
    if (!o->register_module) {
      MD_PERROR(("register_module missing"));
      throw("No registration function in module.\n");
    }
  }

  foo = o->register_module();
  if (!foo) {
    MD_PERROR(("registration failed.\n"));
    return 0;
  } else {
    MD_PERROR(("registered."));
  }
  return({ foo[1], foo[2]+"<p><i>"+
	   replace(o->file_name_and_stuff(), "0<br>", file+"<br>")
	   +"</i>", foo[0] });
}

// ([ filename:stat_array ])
mapping(string:array) module_stat_cache = ([]);
object load(string s, object conf)   // Should perhaps be renamed to 'reload'. 
{
  string cvs;
  array st;
  sscanf(s, "/cvs:%s", cvs);

  if(st=file_stat(s+".pike"))
  {
    program p;
    if((cvs?
        (p=master()->cvs_load_file( cvs+".pike" ))
	:(p=my_compile_file(s+".pike"))))
    {
      mixed q;
      module_stat_cache[s-dirname(s)]=st;
      if(q = catch{ return p(conf); })
        perror(s+".pike exists, but could not be instantiated.\n"+
               describe_backtrace(q));
    } else
      perror(s+".pike exists, but compilation failed.\n");
  }
#if constant(load_module)
  if(st=file_stat(s+".so"))
    if(mixed q=predef::load_module(s+".so"))
    {
      if(!catch(q = q->instance(conf)))
      {
        module_stat_cache[s-dirname(s)]=st;
        return q;
      }
      perror(s+".so exists, but could not be initated (no instance class?)\n");
    }
    else
      perror(s+".so exists, but load failed.\n");
#endif
  return 0; // FAILED..
}

array(string) expand_dir(string d)
{
  string nd;
  array(string) dirs=({d});

  catch {
    foreach(get_dir(d) - ({"CVS"}) , nd) 
      if(file_stat(d+nd)[1]==-2)
	dirs+=expand_dir(d+nd+"/");
  }; // This catch is needed... (permission denied problems)
  return dirs;
}

array(string) last_dirs=0,last_dirs_expand;

object load_from_dirs(array dirs, string f, object conf)
{
  string dir;
  object o;

  if (dirs!=last_dirs)
  {
    last_dirs_expand=({});
    foreach(dirs, dir)
      last_dirs_expand+=expand_dir(dir);
  }

  foreach (last_dirs_expand,dir)
     if((o=load(dir+f, conf))) 
       return o;

  return 0;
}


static int abs_started;

void restart_if_stuck (int force) 
{
  remove_call_out(restart_if_stuck);
  if (!(QUERY(abs_engage) || force))
    return;
  if(!abs_started) 
  {
    abs_started = 1;
    roxen_perror("Anti-Block System Enabled.\n");
  }
  call_out (restart_if_stuck,10);
  signal(signum("SIGALRM"),
	 lambda( int n ) {
	   werror(sprintf("**** %s: ABS engaged!\n"
			  "Trying to dump backlog: \n",
			  ctime(time()) - "\n"));
	   catch {
	     // Catch for paranoia reasons.
	     describe_all_threads();
	   };
	   werror(sprintf("**** %s: ABS exiting roxen!\n\n",
			  ctime(time())));
	   _exit(1); 	// It might now quit correctly otherwise, if it's
	   //  locked up
	 });
  alarm (60*QUERY(abs_timeout)+10);
}

void post_create () 
{
  if (QUERY(abs_engage))
    call_out (restart_if_stuck,10);
  if (QUERY(suicide_engage))
    call_out (restart,60*60*24*QUERY(suicide_timeout));
}



class ImageCache
{
  string name;
  string dir;
  function draw_function;
  mapping data_cache = ([]); // not normally used.
  mapping meta_cache = ([]);


  static mapping meta_cache_insert( string i, mapping what )
  {
    return meta_cache[i] = what;
  }
  
  static string data_cache_insert( string i, string what )
  {
    return data_cache[i] = what;
  }

  static mixed frommapp( mapping what )
  {
    if( what[""] ) return what[""];
    return what;
  }

  static void draw( string name, RequestID id )
  {
    mixed args = Array.map( Array.map( name/"$", argcache->lookup, id->client ), frommapp);
    mapping meta;
    string data;
    mixed reply = draw_function( @copy_value(args), id );

    if( arrayp( args ) )
      args = args[0];


    if( objectp( reply ) || (mappingp(reply) && reply->img) )
    {
      int quant = (int)args->quant;
      string format = lower_case(args->format || "gif");
      string dither = args->dither;
      Image.Colortable ct;
      object alpha;
      int true_alpha; 

      if( args->fs  || dither == "fs" )
	dither = "floyd_steinberg";

      if(  dither == "random" )
	dither = "random_dither";

      if( format == "jpg" ) 
        format = "jpeg";

      if(mappingp(reply))
      {
        alpha = reply->alpha;
        reply = reply->img;
      }
      
      if( args->gamma )
        reply = reply->gamma( (float)args->gamma );

      if( args["true-alpha"] )
        true_alpha = 1;

      if( args["opaque-value"] )
      {
        true_alpha = 1;
        int ov = (int)(((float)args["opaque-value"])*2.55);
        if( ov < 0 )
          ov = 0;
        else if( ov > 255 )
          ov = 255;
        if( alpha )
        {
          object i = Image.image( reply->xsize(), reply->ysize(), ov,ov,ov );
          i->paste_alpha( alpha, ov );
          alpha = i;
        }
        else
        {
          alpha = Image.image( reply->xsize(), reply->ysize(), ov,ov,ov );
        }
      }

      if( args->scale )
      {
        int x, y;
        if( sscanf( args->scale, "%d,%d", x, y ) == 2)
        {
          reply = reply->scale( x, y );
          if( alpha )
            alpha = alpha->scale( x, y );
        }
        else if( (float)args->scale < 3.0)
        {
          reply = reply->scale( ((float)args->scale) );
          if( alpha )
            alpha = alpha->scale( ((float)args->scale) );
        }
      }

      if( args->maxwidth || args->maxheight )
      {
        int x = (int)args->maxwidth, y = (int)args->maxheight;
        if( x && reply->xsize() > x )
        {
          reply = reply->scale( x, 0 );
          if( alpha )
            alpha = alpha->scale( x, 0 );
        }
        if( y && reply->ysize() > y )
        {
          reply = reply->scale( 0, y );
          if( alpha )
            alpha = alpha->scale( 0, y );
        }
      }

      if( quant || (format=="gif") )
      {
        int ncols = quant||id->misc->defquant||16;
        if( ncols > 250 )
          ncols = 250;
        ct = Image.Colortable( reply, ncols );
        if( dither )
          if( ct[ dither ] )
            ct[ dither ]();
          else
            ct->ordered();
      }

      if(!Image[upper_case( format )] 
         || !Image[upper_case( format )]->encode )
        error("Image format "+format+" unknown\n");

      mapping enc_args = ([]);
      if( ct )
        enc_args->colortable = ct;
      if( alpha )
        enc_args->alpha = alpha;

      foreach( glob( "*-*", indices(args)), string n )
        if(sscanf(n, "%*[^-]-%s", string opt ) == 2)
          enc_args[opt] = (int)args[n];

      switch(format)
      {
       case "gif":
         if( alpha && true_alpha )
         {
           object ct=Image.Colortable( ({ ({ 0,0,0 }), ({ 255,255,255 }) }) );
           ct->floyd_steinberg();
           alpha = ct->map( alpha );
         }
         if( catch {
           if( alpha )
             data = Image.GIF.encode_trans( reply, ct, alpha );
           else
             data = Image.GIF.encode( reply, ct );
         })
           data = Image.GIF.encode( reply );
         break;
       case "png":
         if( ct )
           enc_args->palette = ct;
         m_delete( enc_args, "colortable" );
       default:
        data = Image[upper_case( format )]->encode( reply, enc_args );
      }

      meta = ([ 
        "xsize":reply->xsize(),
        "ysize":reply->ysize(),
        "type":"image/"+format,
      ]);
    }
    else if( mappingp(reply) ) 
    {
      meta = reply->meta;
      data = reply->data;
      if( !meta || !data )
        error("Invalid reply mapping.\n"
              "Should be ([ \"meta\": ([metadata]), \"data\":\"data\" ])\n");
    }
    store_meta( name, meta );
    store_data( name, data );
  }


  static void store_meta( string id, mapping meta )
  {
    meta_cache_insert( id, meta );

    string data = encode_value( meta );
    Stdio.File f = Stdio.File(  );
    if(!f->open(dir+id+".i", "wct" ))
    {
      report_error( "Failed to open image cache persistant cache file "+
                    dir+id+".i: "+strerror( errno() )+ "\n" );
      return;
    }
    f->write( data );
  }

  static void store_data( string id, string data )
  {
    Stdio.File f = Stdio.File(  );
    if(!f->open(dir+id+".d", "wct" ))
    {
      data_cache_insert( id, data );
      report_error( "Failed to open image cache persistant cache file "+
                    dir+id+".d: "+strerror( errno() )+ "\n" );
      return;
    }
    f->write( data );
  }


  static mapping restore_meta( string id )
  {
    Stdio.File f;
    if( meta_cache[ id ] )
      return meta_cache[ id ];
    f = Stdio.File( );
    if( !f->open(dir+id+".i", "r" ) )
      return 0;
    return meta_cache_insert( id, decode_value( f->read() ) );
  }

  static mapping restore( string id )
  {
    string|object(Stdio.File) f;
    mapping m;
    if( data_cache[ id ] )
      f = data_cache[ id ];
    else 
      f = Stdio.File( );

    if(!f->open(dir+id+".d", "r" ))
      return 0;

    m = restore_meta( id );
    
    if(!m)
      return 0;

    if( stringp( f ) )
      return roxenp()->http_string_answer( f, m->type||("image/gif") );
    return roxenp()->http_file_answer( f, m->type||("image/gif") );
  }


  string data( string|mapping args, RequestID id, int|void nodraw )
  {
    string na = store( args, id );
    mixed res;

    if(!( res = restore( na )) )
    {
      if(nodraw)
        return 0;
      draw( na, id );
      res = restore( na );
    }
    if( res->file )
      return res->file->read();
    return res->data;
  }

  mapping http_file_answer( string|mapping data, 
                            RequestID id, 
                            int|void nodraw )
  {
    string na = store( data,id );
    mixed res;
    if(!( res = restore( na )) )
    {
      if(nodraw)
        return 0;
      draw( na, id );
      res = restore( na );
    }
    return res;
  }

  mapping metadata( string|mapping data, RequestID id, int|void nodraw )
  {
    string na = store( data,id );
    if(!restore_meta( na ))
    {
      if(nodraw)
        return 0;
      draw( na, id );
      return restore_meta( na );
    }
    return restore_meta( na );
  }

  mapping tomapp( mixed what )
  {
    if( mappingp( what ))
      return what;
    return ([ "":what ]);
  }

  string store( array|string|mapping data, RequestID id )
  {
    string ci;
    if( mappingp( data ) )
      ci = argcache->store( data );
    else if( arrayp( data ) )
      ci = Array.map( Array.map( data, tomapp ), argcache->store )*"$";
    else
      ci = data;
    return ci;
  }

  void set_draw_function( function to )
  {
    draw_function = to;
  }

  void create( string id, function draw_func, string|void d )
  {
    if(!d) d = roxenp()->QUERY(argument_cache_dir);
    if( d[-1] != '/' )
      d+="/";
    d += id+"/";

    mkdirhier( d+"foo");

    dir = d;
    name = id;
    draw_function = draw_func;
  }
}


class ArgCache
{
  static string name;
  static string path;
  static int is_db;
  static object db;

#define CACHE_VALUE 0
#define CACHE_SKEY  1
#define CACHE_SIZE  600
#define CLEAN_SIZE  100

#ifdef THREADS
  static Thread.Mutex mutex = Thread.Mutex();
# define LOCK() object __key = mutex->lock()
#else
# define LOCK() 
#endif

  static mapping (string:mixed) cache = ([ ]);

  static void setup_table()
  {
    if(catch(db->query("select id from "+name+" where id=-1")))
      if(catch(db->query("create table "+name+" ("
                         "id int auto_increment primary key, "
                         "lkey varchar(80) not null default '', "
                         "contents blob not null default '', "
                         "atime bigint not null default 0)")))
        throw("Failed to create table in database\n");
  }

  void create( string _name, 
               string _path, 
               int _is_db )
  {
    name = _name;
    path = _path;
    is_db = _is_db;

    if(is_db)
    {
      db = Sql.sql( path );
      if(!db)
        error("Failed to connect to database for argument cache\n");
      setup_table( );
    } else {
      if(path[-1] != '/' && path[-1] != '\\')
        path += "/";
      path += replace(name, "/", "_")+"/";
      mkdirhier( path + "/tmp" );
      object test = Stdio.File();
      if (!test->open (path + "/.testfile", "wc"))
	error ("Can't create files in the argument cache directory " + path + "\n");
      else {
	test->close();
	rm (path + "/.testfile");
      }
    }
  }

  static string read_args( string id )
  {
    if( is_db )
    {
      mapping res = db->query("select contents from "+name+" where id='"+id+"'");
      if( sizeof(res) )
      {
        db->query("update "+name+" set atime='"+
                  time()+"' where id='"+id+"'");
        return res[0]->contents;
      }
      return 0;
    } else {
      if( file_stat( path+id ) )
        return Stdio.read_bytes(path+"/"+id);
    }
    return 0;
  }

  static string create_key( string long_key )
  {
    if( is_db )
    {
      mapping data = db->query(sprintf("select id,contents from %s where lkey='%s'",
                                       name,long_key[..79]));
      foreach( data, mapping m )
        if( m->contents == long_key )
          return m->id;

      db->query( sprintf("insert into %s (contents,lkey,atime) values "
                         "('%s','%s','%d')", 
                         name, long_key, long_key[..79], time() ));
      return create_key( long_key );
    } else {
      string _key=MIME.encode_base64(Crypto.md5()->update(long_key)->digest(),1);
      _key = replace(_key-"=","/","=");
      string short_key = _key[0..1];

      while( file_stat( path+short_key ) )
      {
        if( Stdio.read_bytes( path+short_key ) == long_key )
          return short_key;
        short_key = _key[..strlen(short_key)];
        if( strlen(short_key) >= strlen(_key) )
          short_key += "."; // Not very likely...
      }
      object f = Stdio.File( path + short_key, "wct" );
      f->write( long_key );
      return short_key;
    }
  }


  int key_exists( string key )
  {
    LOCK();
    if( !is_db ) 
      return !!file_stat( path+key );
    return !!read_args( key );
  }

  string store( mapping args )
  {
    LOCK();
    array b = values(args), a = sort(indices(args),b);
    string data = MIME.encode_base64(encode_value(({a,b})),1);

    if( cache[ data ] )
      return cache[ data ][ CACHE_SKEY ];

    string id = create_key( data );
    cache[ data ] = ({ 0, 0 });
    cache[ data ][ CACHE_VALUE ] = copy_value( args );
    cache[ data ][ CACHE_SKEY ] = id;
    cache[ id ] = data;

    if( sizeof( cache ) > CACHE_SIZE )
    {
      array i = indices(cache);
      while( sizeof(cache) > CACHE_SIZE-CLEAN_SIZE )
        m_delete( cache, i[random(sizeof(i))] );
    }
    return id;
  }

  mapping lookup( string id, string|void client )
  {
    LOCK();
    if(cache[id])
      return cache[cache[id]][CACHE_VALUE];

    string q = read_args( id );

    if(!q) error("Key does not exist! (Thinks "+ client +")\n");
    mixed data = decode_value(MIME.decode_base64( q ));
    data = mkmapping( data[0],data[1] );

    cache[ q ] = ({0,0});
    cache[ q ][ CACHE_VALUE ] = data;
    cache[ q ][ CACHE_SKEY ] = id;
    cache[ id ] = q;
    return data;
  }

  void delete( string id )
  {
    LOCK();
    if(cache[id])
    {
      m_delete( cache, cache[id] );
      m_delete( cache, id );
    }
    if( is_db )
      db->query( "delete from "+name+" where id='"+id+"'" );
    else
      rm( path+id );
  }
}

mapping cached_decoders = ([]);
string decode_charset( string charset, string data )
{
  // FIXME: This code is probably not thread-safe!
  if( charset == "iso-8859-1" ) return data;
  if( !cached_decoders[ charset ] )
    cached_decoders[ charset ] = Locale.Charset.decoder( charset );
  data = cached_decoders[ charset ]->feed( data )->drain();
  cached_decoders[ charset ]->flush();
  return data;
}

void create()
{
   SET_LOCALE(default_locale);
// catch
// {
//   module_stat_cache = decode_value(Stdio.read_bytes(".module_stat_cache"));
//   allmodules = decode_value(Stdio.read_bytes(".allmodules"));
// };

  // Dump some programs (for speed)
  dump( "base_server/newdecode.pike" );
  dump( "base_server/read_config.pike" );
  dump( "base_server/global_variables.pike" );
  dump( "base_server/module_support.pike" );
  dump( "base_server/http.pike" );
  dump( "base_server/socket.pike" );
  dump( "base_server/cache.pike" );
  dump( "base_server/supports.pike" );
  dump( "base_server/fonts.pike");
  dump( "base_server/hosts.pike");
  dump( "base_server/language.pike");

#ifndef __NT__
  if(!getuid()) {
    add_constant("Privs", Privs);
  } else
#endif /* !__NT__ */
    add_constant("Privs", class{});

  // for module encoding stuff
  
  add_constant( "Image", Image );
  add_constant( "Image.Image", Image.Image );
  add_constant( "Image.Font", Image.Font );
  add_constant( "Image.Colortable", Image.Colortable );
  add_constant( "Image.Color", Image.Color );
  add_constant( "Image.GIF.encode", Image.GIF.encode );
  add_constant( "Image.Color.Color", Image.Color.Color );
  add_constant( "roxen.argcache", argcache );
  add_constant( "ArgCache", ArgCache );
  add_constant( "Regexp", Regexp );
  add_constant( "Stdio.File", Stdio.File );
  add_constant( "Stdio.stdout", Stdio.stdout );
  add_constant( "Stdio.stderr", Stdio.stderr );
  add_constant( "Stdio.stdin", Stdio.stdin );
  add_constant( "Stdio.read_bytes", Stdio.read_bytes );
  add_constant( "Stdio.write_file", Stdio.write_file );
  add_constant( "Stdio.sendfile", Stdio.sendfile );
  add_constant( "Process.create_process", Process.create_process );
  add_constant( "roxen.load_image", load_image );
#if constant(Thread.Mutex)
  add_constant( "Thread.Mutex", Thread.Mutex );
  add_constant( "Thread.Queue", Thread.Queue );
#endif

  add_constant( "roxen", this_object());
  add_constant( "roxen.decode_charset", decode_charset);
  add_constant( "RequestID", RequestID);
  add_constant( "load",    load);
  add_constant( "Roxen.set_locale", set_locale );
  add_constant( "Roxen.locale", locale );
  add_constant( "Locale.Roxen", Locale.Roxen );
  add_constant( "Locale.Roxen.standard", Locale.Roxen.standard );
  add_constant( "Locale.Roxen.standard.register_module_doc", 
                 Locale.Roxen.standard.register_module_doc );
  add_constant( "roxen.ImageCache", ImageCache );
  // compatibility
  add_constant( "hsv_to_rgb",  Colors.hsv_to_rgb  );
  add_constant( "rgb_to_hsv",  Colors.rgb_to_hsv  );
  add_constant( "parse_color", Colors.parse_color );
  add_constant( "color_name",  Colors.color_name  );
  add_constant( "colors",      Colors             );
  add_constant( "roxen.fonts", (fonts = (object)"fonts.pike") );
  Configuration = (program)"configuration";
  if(!file_stat( "base_server/configuration.pike.o" ) ||
     file_stat("base_server/configuration.pike.o")[ST_MTIME] <
     file_stat("base_server/configuration.pike")[ST_MTIME])
  {
    Stdio.write_file( "base_server/configuration.pike.o", 
                      encode_value( Configuration, Codec( Configuration ) ) );
  }
  add_constant("Configuration", Configuration );

  call_out(post_create,1); //we just want to delay some things a little
}



// Set the uid and gid to the ones requested by the user. If the sete*
// functions are available, and the define SET_EFFECTIVE is enabled,
// the euid and egid is set. This might be a minor security hole, but
// it will enable roxen to start CGI scripts with the correct
// permissions (the ones the owner of that script have).

int set_u_and_gid()
{
#ifndef __NT__
  string u, g;
  int uid, gid;
  array pw;
  
  u=QUERY(User);
  sscanf(u, "%s:%s", u, g);
  if(strlen(u))
  {
    if(getuid())
    {
      report_error ("It is only possible to change uid and gid if the server "
		    "is running as root.\n");
    } else {
      if (g) {
#if constant(getgrnam)
	pw = getgrnam (g);
	if (!pw)
	  if (sscanf (g, "%d", gid)) pw = getgrgid (gid), g = (string) gid;
	  else report_error ("Couldn't resolve group " + g + ".\n"), g = 0;
	if (pw) g = pw[0], gid = pw[2];
#else
	if (!sscanf (g, "%d", gid))
	  report_warning ("Can't resolve " + g + " to gid on this system; "
			  "numeric gid required.\n");
#endif
      }

      pw = getpwnam (u);
      if (!pw)
	if (sscanf (u, "%d", uid)) pw = getpwuid (uid), u = (string) uid;
	else {
	  report_error ("Couldn't resolve user " + u + ".\n");
	  return 0;
	}
      if (pw) {
	u = pw[0], uid = pw[2];
	if (!g) gid = pw[3];
      }

#ifdef THREADS
      object mutex_key;
      catch { mutex_key = euid_egid_lock->lock(); };
      object threads_disabled = _disable_threads();
#endif

#if constant(seteuid)
      if (geteuid() != getuid()) seteuid (getuid());
#endif

#if constant(initgroups)
      catch {
	initgroups(pw[0], gid);
	// Doesn't always work - David.
      };
#endif

      if (QUERY(permanent_uid)) {
#if constant(setuid)
	if (g) {
#  if constant(setgid)
	  setgid(gid);
	  if (getgid() != gid) report_error ("Failed to set gid.\n"), g = 0;
#  else
	  report_warning ("Setting gid not supported on this system.\n");
	  g = 0;
#  endif
	}
	setuid(uid);
	if (getuid() != uid) report_error ("Failed to set uid.\n"), u = 0;
	if (u) report_notice(LOCALE->setting_uid_gid_permanently (uid, gid, u, g));
#else
	report_warning ("Setting uid not supported on this system.\n");
	u = g = 0;
#endif
      }
      else {
#if constant(seteuid)
	if (g) {
#  if constant(setegid)
	  setegid(gid);
	  if (getegid() != gid) report_error ("Failed to set effective gid.\n"), g = 0;
#  else
	  report_warning ("Setting effective gid not supported on this system.\n");
	  g = 0;
#  endif
	}
	seteuid(uid);
	if (geteuid() != uid) report_error ("Failed to set effective uid.\n"), u = 0;
	if (u) report_notice(LOCALE->setting_uid_gid (uid, gid, u, g));
#else
	report_warning ("Setting effective uid not supported on this system.\n");
	u = g = 0;
#endif
      }

      return !!u;
    }
  }
#endif
  return 0;
}

void reload_all_configurations()
{
  object conf;
  array (object) new_confs = ({});
  mapping config_cache = ([]);
  int modified;

  report_notice(LOCALE->reloading_config_interface());
  configs = ([]);
  setvars(retrieve("Variables", 0));
  initiate_configuration_port( 0 );

  foreach(list_all_configurations(), string config)
  {
    array err, st;
    foreach(configurations, conf)
    {
      if(lower_case(conf->name) == lower_case(config))
      {
	break;
      } else
	conf = 0;
    }
    if(!(st = config_is_modified(config))) {
      if(conf) {
	config_cache[config] = config_stat_cache[config];
	new_confs += ({ conf });
      }
      continue;
    }
    modified = 1;
    config_cache[config] = st;
    if(conf) {
      // Closing ports...
      if (conf->server_ports) {
	// Roxen 1.2.26 or later
	Array.map(values(conf->server_ports), destruct);
      } else {
	Array.map(indices(conf->open_ports), destruct);
      }
      conf->stop();
      conf->invalidate_cache();
      conf->modules = ([]);
      conf->create(conf->name);
    } else {
      if(err = catch
      {
	conf = enable_configuration(config);
      }) {
	report_error(LOCALE->
		     error_enabling_configuration(config,
						  describe_backtrace(err)));
	continue;
      }
    }
    if(err = catch
    {
      conf->start();
      conf->enable_all_modules();
    }) {
      report_error(LOCALE->
		   error_enabling_configuration(config,
						describe_backtrace(err)));
      continue;
    }
    new_confs += ({ conf });
  }
    
  foreach(configurations - new_confs, conf)
  {
    modified = 1;
    report_notice(LOCALE->disabling_configuration(conf->name));
    if (conf->server_ports) {
      // Roxen 1.2.26 or later
      Array.map(values(conf->server_ports), destruct);
    } else {
      Array.map(indices(conf->open_ports), destruct);
    }
    conf->stop();
    destruct(conf);
  }
  if(modified) {
    configurations = new_confs;
    config_stat_cache = config_cache;
    unload_configuration_interface();
  }
}

object enable_configuration(string name)
{
  object cf = Configuration(name);
  configurations += ({ cf });
  report_notice(LOCALE->enabled_server(name));
  
  return cf;
}

// Enable all configurations
void enable_configurations()
{
  array err;

  enabling_configurations = 1;
  configurations = ({});
  foreach(list_all_configurations(), string config)
  {
    if(err=catch { enable_configuration(config)->start();  })
      perror("Error while loading configuration "+config+":\n"+
	     describe_backtrace(err)+"\n");
  };
  enabling_configurations = 0;
}


void enable_configurations_modules()
{
  foreach(configurations, object config)
  {
    array err;
    if(err=catch { config->enable_all_modules();  })
      perror("Error while loading modules in configuration "+config->name+":\n"+
	     describe_backtrace(err)+"\n");
  };
}

array(int) invert_color(array color )
{
  return ({ 255-color[0], 255-color[1], 255-color[2] });
}


mapping low_decode_image(string data, void|array tocolor)
{
  Image.image i, a;
  string format;
  if(!data)
    return 0; 

#if constant(Image.GIF._decode)  
  // Use the low-level decode function to get the alpha channel.
  catch
  {
    array chunks = Image.GIF._decode( data );

    // If there is more than one render chunk, the image is probably
    // an animation. Handling animations is left as an exercise for
    // the reader. :-)
    foreach(chunks, mixed chunk)
      if(arrayp(chunk) && chunk[0] == Image.GIF.RENDER )
        [i,a] = chunk[3..4];
    format = "GIF";
  };

  if(!i) catch
  {
    i = Image.GIF.decode( data );
    format = "GIF";
  };
#endif

#if constant(Image.JPEG) && constant(Image.JPEG.decode)
  if(!i) catch
  {
    i = Image.JPEG.decode( data );
    format = "JPEG";
  };
#endif

#if constant(Image.XCF) && constant(Image.XCF._decode)
  if(!i) catch
  {
    mixed q = Image.XCF._decode( data,(["background":tocolor,]) );
    tocolor=0;
    format = "XCF Gimp file";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.PSD) && constant(Image.PSD._decode)
  if(!i) catch
  {
    mixed q = Image.PSD._decode( data, ([
      "background":tocolor,
      ]));
    tocolor=0;
    format = "PSD Photoshop file";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.PNG) && constant(Image.PNG._decode)
  if(!i) catch
  {
    mixed q = Image.PNG._decode( data );
    format = "PNG";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.BMP) && constant(Image.BMP._decode)
  if(!i) catch
  {
    mixed q = Image.BMP._decode( data );
    format = "Windows bitmap file";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.TGA) && constant(Image.TGA._decode)
  if(!i) catch
  {
    mixed q = Image.TGA._decode( data );
    format = "Targa";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.PCX) && constant(Image.PCX._decode)
  if(!i) catch
  {
    mixed q = Image.PCX._decode( data );
    format = "PCX";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.XBM) && constant(Image.XBM._decode)
  if(!i) catch
  {
    mixed q = Image.XBM._decode( data, (["bg":tocolor||({255,255,255}),
                                    "fg":invert_color(tocolor||({255,255,255})) ]));
    format = "XBM";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.XPM) && constant(Image.XPM._decode)
  if(!i) catch
  {
    mixed q = Image.XPM._decode( data );
    format = "XPM";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.TIFF) && constant(Image.TIFF._decode)
  if(!i) catch
  {
    mixed q = Image.TIFF._decode( data );
    format = "TIFF";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.ILBM) && constant(Image.ILBM._decode)
  if(!i) catch
  {
    mixed q = Image.ILBM._decode( data );
    format = "ILBM";
    i = q->image;
    a = q->alpha;
  };
#endif


#if constant(Image.PS) && constant(Image.PS._decode)
  if(!i) catch
  {
    mixed q = Image.PS._decode( data );
    format = "Postscript";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.XWD) && constant(Image.XWD.decode)
  if(!i) catch
  {
    i = Image.XWD.decode( data );
    format = "XWD";
  };
#endif

#if constant(Image.HRZ) && constant(Image.HRZ._decode)
  if(!i) catch
  {
    mixed q = Image.HRZ._decode( data );
    format = "HRZ";
    i = q->image;
    a = q->alpha;
  };
#endif

#if constant(Image.AVS) && constant(Image.AVS._decode)
  if(!i) catch
  {
    mixed q = Image.AVS._decode( data );
    format = "AVS X";
    i = q->image;
    a = q->alpha;
  };
#endif

  if(!i)
    catch{
      i = Image.PNM.decode( data );
      format = "PNM";
    };

  if(!i) // No image could be decoded at all. 
    return 0;

  if( tocolor && i && a )
  {
    object o = Image.image( i->xsize(), i->ysize(), @tocolor );
    o->paste_mask( i,a );
    i = o;
  }

  return ([
    "format":format,
    "alpha":a,
    "img":i,
  ]);
}

mapping low_load_image(string f,object id)
{
  string data;
  object file, img;
  if(id->misc->_load_image_called < 5) 
  {
    // We were recursing very badly with the demo module here...
    id->misc->_load_image_called++;
    if(!(data=id->conf->try_get_file(f, id)))
    {
      file=Stdio.File();
      if(!file->open(f,"r") || !(data=file->read()))
	return 0;
    }
  }
  id->misc->_load_image_called = 0;
  if(!data)  return 0;
  return low_decode_image( data );
}



object load_image(string f,object id)
{
  mapping q = low_load_image( f, id );
  if( q ) return q->img;
  return 0;
}


// Somewhat misnamed, since there can be more then one
// configuration-interface port nowdays. But, anyway, this function
// opens and listens to all configuration interface ports.
void initiate_configuration_port( int|void first )
{
  object o;
  array port;

  // Hm.
  if(!first && !config_ports_changed )
    return 0;
  
  config_ports_changed = 0;

  // First find out if we have any new ports.
  mapping(string:array(string)) new_ports = ([]);
  foreach(QUERY(ConfigPorts), port) {
    if ((< "ssl", "ssleay", "ssl3" >)[port[1]]) {
      // Obsolete versions of the SSL protocol.
      report_warning(LOCALE->obsolete_ssl(port[1]));
      port[1] = "https";
    } else if ((< "ftp2" >)[port[1]]) {
      // ftp2.pike has replaced ftp.pike entirely.
      report_warning(LOCALE->obsolete_ftp(port[1]));
      port[1] = "ftp";
    }
    string key = MKPORTKEY(port);
    if (!configuration_ports[key]) {
      report_notice(LOCALE->new_config_port(key));
      new_ports[key] = port;
    } else {
      // This is needed not to delete old unchanged ports.
      new_ports[key] = 0;
    }
  }

  // Then disable the old ones that are no more.
  foreach(indices(configuration_ports), string key) {
    if (zero_type(new_ports[key])) {
      report_notice(LOCALE->disable_config_port(key));
      object o = configuration_ports[key];
      if (main_configuration_port == o) {
	main_configuration_port = 0;
      }
      m_delete(configuration_ports, key);
      mixed err;
      if (err = catch{
	destruct(o);
      }) {
	report_warning(LOCALE->
		       error_disabling_config_port(key,
						   describe_backtrace(err)));
      }
      o = 0;	// Be sure that there are no references left...
    }
  }

  // Now we can create the new ports.
  foreach(indices(new_ports), string key)
  {
    port = new_ports[key];
    if (port) {
      array old = port;
      mixed erro;
      erro = catch {
	program requestprogram = (program)(getcwd()+"/protocols/"+port[1]);
	function rp;
	array tmp;
	if(!requestprogram) {
	  report_error(LOCALE->no_request_program(port[1]));
	  continue;
	}
	if(rp = requestprogram()->real_port)
	  if(tmp = rp(port, 0))
	    port = tmp;

	// FIXME: For SSL3 we might need to be root to read our
	// secret files.
	object privs;
	if(port[0] < 1024)
	  privs = Privs(LOCALE->opening_low_port());
	if(o=create_listen_socket(port[0],0,port[2],requestprogram,port)) {
	  report_notice(LOCALE->opening_config_port(key));
	  if (!main_configuration_port) {
	    main_configuration_port = o;
	  }
	  configuration_ports[key] = o;
	} else {
	  report_error(LOCALE->could_not_open_config_port(key));
	}
      };
      if (erro) {
	report_error(LOCALE->open_config_port_failed(key,
			     (stringp(erro)?erro:describe_backtrace(erro))));
      }
    }
  }
  if(!main_configuration_port)
  {
    if (sizeof(configuration_ports)) {
      // This case happens when you delete the main config port,
      // but still have others left.
      main_configuration_port = values(configuration_ports)[0];
    } else {
      report_error(LOCALE->no_config_port());
      if(first)
	exit( -1 );	// Restart.
    }
  }
}
#include <stat.h>
// Find all modules, so a list of them can be presented to the
// user. This is not needed when the server is started.
void scan_module_dir(string d)
{
  if(sscanf(d, "%*s.pmod")!=0) return;
  MD_PERROR(("\n\nLooking for modules in "+d+" "));

  string file,path=d;
  mixed err;
  array q  = (get_dir( d )||({})) - ({".","..","CVS","RCS" });
  if(!sizeof(q)) {
    MD_PERROR(("No modules in here. Continuing elsewhere\n"));
    return;
  }
  if(search(q, ".no_modules")!=-1) {
    MD_PERROR(("No modules in here. Continuing elsewhere\n"));
    return;
  }
  MD_PERROR(("There are "+language("en","number")(sizeof(q))+" files.\n"));

  foreach( q, file )
  {
    object e = ErrorContainer();
    master()->set_inhibit_compile_errors(e->got_error);
    if ( file[0]!='.' && !backup_extension(file) && (file[-1]!='z') &&
         ((file[-1] != 'o') || file[-2] == 's'))
    {
      array stat = file_stat(path+file);
      if(!stat || (stat[ST_SIZE] < 0))
      {
	if(err = catch ( scan_module_dir(path+file+"/") ))
	  MD_PERROR((sprintf("Error in module rescanning directory code:"
			     " %s\n",describe_backtrace(err))));
      } else {
	if((module_stat_cache[path+file] &&
	    module_stat_cache[path+file][ST_MTIME])==stat[ST_MTIME])
	{
	  continue;
	}
	module_stat_cache[path+file]=stat;
	
	switch(extension(file))
	{
	case "pike":
	case "lpc":
          MD_PERROR(("Considering "+file+" - "));
	  if(catch{
	    if((open(path+file,"r")->read(4))=="#!NO") {
	      MD_PERROR(("Not a module\n"));
	      file=0;
	    }
	  }) {
	    MD_PERROR(("Couldn't open file\n"));
	    file=0;
	  }
	  if(!file) {
            break;
          }
	case "mod":
	case "so":
	  array(string) module_info;
          int s = gethrtime();
	  if (!(err = catch( module_info = compile_module(path + file)))) {
	    // Load OK
	    if (module_info) {
	      // Module load OK.
	      allmodules[ file-("."+extension(file)) ] = module_info;
	    } else {
	      // Disabled module.
	      report_notice(LOCALE->disabled_module(path+file));
	    }
	  } else {
	    // Load failed.
	    module_stat_cache[path+file]=0;
	    e->errors += "\n";
// 	    if (arrayp(err)) {
// 	      e->errors += path + file + ":" +describe_backtrace(err) + "\n";
// 	    } else {
// 	      _master->errors += path + file + ": " + err;
// 	    }
	  }
          MD_PERROR(("     [%4.2fms]\n", (gethrtime()-s)/1000.0));
	}
      }
    }
    master()->set_inhibit_compile_errors(0);
    if(strlen(e->get())) {
      report_debug(LOCALE->module_compilation_errors(d, e->get()));
    }
  }
}

void rescan_modules()
{
  string file, path;
  mixed err;
  report_notice(LOCALE->scanning_for_modules());
  if (!allmodules) {
    allmodules=copy_value(somemodules);
  }

  foreach(QUERY(ModuleDirs), path)
  {
    array err;
    err = catch(scan_module_dir( path ));
    if(err) {
      report_error(LOCALE->module_scan_error(path, describe_backtrace(err)));
    }
  }
  catch {
//     rm(".module_stat_cache");
//     rm(".allmodules");
//     Stdio.write_file(".module_stat_cache", encode_value(module_stat_cache));
//     Stdio.write_file(".allmodules", encode_value(allmodules));
  };
  report_notice(LOCALE->module_scan_done(sizeof(allmodules)));
}

// do the chroot() call. This is not currently recommended, since
// roxen dynamically loads modules, all module files must be
// available at the new location.

private void fix_root(string to)
{
#ifndef __NT__
  if(getuid())
  {
    perror("It is impossible to chroot() if the server is not run as root.\n");
    return;
  }

  if(!chroot(to))
  {
    perror("Roxen: Cannot chroot to "+to+": ");
#if efun(real_perror)
    real_perror();
#endif
    return;
  }
  perror("Root is now "+to+".\n");
#endif
}

void create_pid_file(string where)
{
#ifndef __NT__
  if(!where) return;
  where = replace(where, ({ "$pid", "$uid" }), 
		  ({ (string)getpid(), (string)getuid() }));

  rm(where);
  if(catch(Stdio.write_file(where, sprintf("%d\n%d", getpid(), getppid()))))
    perror("I cannot create the pid file ("+where+").\n");
#endif
}

program pipe;
object shuffle(object from, object to,
	       object|void to2, function(:void)|void callback)
{
#if efun(spider.shuffle)
  if(!to2)
  {
    if(!pipe)
      pipe = ((program)"smartpipe");
    object p = pipe( );
    p->input(from);
    p->set_done_callback(callback);
    p->output(to);
    return p;
  } else {
#endif
    // 'smartpipe' does not support multiple outputs.
    object p = Pipe.pipe();
    if (callback) p->set_done_callback(callback);
    p->output(to);
    if(to2) p->output(to2);
    p->input(from);
    return p;
#if efun(spider.shuffle)
  }
#endif
}


static private int _recurse;
// FIXME: Ought to use the shutdown code.
void exit_when_done()
{
  object o;
  int i;
  roxen_perror("Interrupt request received. Exiting,\n");
  die_die_die=1;
//   trace(9);
  if(++_recurse > 4)
  {
    roxen_perror("Exiting roxen (spurious signals received).\n");
    stop_all_modules();
#ifdef THREADS
    stop_handler_threads();
#endif /* THREADS */
    exit(-1);	// Restart.
  }

  // First kill off all listening sockets.. 
  foreach(indices(portno)||({}), o)
  {
#ifdef THREADS
    object fd = Stdio.File();
    fd->connect( portno[o][2]!="Any"?portno[o][2]:"127.0.0.1", portno[o][0] );
    destruct(fd);
#endif
    destruct(o);
  }
  
  // Then wait for all sockets, but maximum 10 minutes.. 
  call_out(lambda() { 
    call_out(Simulate.this_function(), 5);
    if(!_pipe_debug()[0])
    {
      roxen_perror("Exiting roxen (all connections closed).\n");
      stop_all_modules();
#ifdef THREADS
      stop_handler_threads();
#endif /* THREADS */
      add_constant("roxen", 0);	// Paranoia...
      exit(-1);	// Restart.
      roxen_perror("Odd. I am not dead yet.\n");
    }
  }, 0.1);
  call_out(lambda(){
    roxen_perror("Exiting roxen (timeout).\n");
    stop_all_modules();
#ifdef THREADS
    stop_handler_threads();
#endif /* THREADS */
    add_constant("roxen", 0);	// Paranoia...
    exit(-1); // Restart.
  }, 600, 0); // Slow buggers..
}

void exit_it()
{
  perror("Recursive signals.\n");
  exit(-1);	// Restart.
}

void set_locale( string to )
{
  if( to == "standard" )
    SET_LOCALE( default_locale );
  SET_LOCALE( Locale.Roxen[ to ] || default_locale );
}


// Dump all threads to the debug log.
void describe_all_threads()
{
  array(mixed) all_backtraces;
#if constant(all_threads)
  all_backtraces = all_threads()->backtrace();
#else /* !constant(all_threads) */
  all_backtraces = ({ backtrace() });
#endif /* constant(all_threads) */

  werror("Describing all threads:\n");
  int i;
  for(i=0; i < sizeof(all_backtraces); i++) {
    werror(sprintf("Thread %d:\n"
		   "%s\n",
		   i+1,
		   describe_backtrace(all_backtraces[i])));
  }
}


void dump( string file )
{
  program p = master()->programs[ replace(getcwd() +"/"+ file , "//", "/" ) ];
  array q;
  if(!p)
  {
#ifdef DUMP_DEBUG
    report_debug(file+" not loaded, and thus cannot be dumped.\n");
#endif
    return;
  }

  if(!file_stat( file+".o" ) ||
     (file_stat(file+".o")[ST_MTIME] < file_stat(file)[ST_MTIME]))
  {
    if(q=catch{
      Stdio.write_file(file+".o",encode_value(p,Codec(p)));
#ifdef DUMP_DEBUG
      report_debug( file+" dumped successfully to "+file+".o\n" );
#endif
    })
      report_debug("** Cannot encode "+file+": "+describe_backtrace(q)+"\n");
  }
#ifdef DUMP_DEBUG
  else
      report_debug(file+" already dumped (and up to date)\n");
#endif
}

int main(int argc, array argv)
{
//   dump( "base_server/disk_cache.pike");
// cannot encode this one yet...

  call_out( lambda() {
              ((program)"fastpipe"),
              ((program)"slowpipe"),

              dump( "protocols/http.pike");
              dump( "protocols/ftp.pike");
              dump( "protocols/https.pike");

              dump( "base_server/state.pike" );
              dump( "base_server/struct/node.pike" );
              dump( "base_server/persistent.pike");
              dump( "base_server/restorable.pike");
              dump( "base_server/highlight_pike.pike");
              dump( "base_server/dates.pike");
              dump( "base_server/wizard.pike" );
              dump( "base_server/proxyauth.pike" );
              dump( "base_server/html.pike" );
              dump( "base_server/module.pike" );
              dump( "base_server/throttler.pike" );
              dump( "base_server/smartpipe.pike" );
              dump( "base_server/slowpipe.pike" );
              dump( "base_server/fastpipe.pike" );
            }, 9);


  switch(getenv("LANG"))
  {
   case "sv":
     default_locale = Locale.Roxen["svenska"];
     break;
   case "jp":
     default_locale = Locale.Roxen["nihongo"];
     break;
  }
  SET_LOCALE(default_locale);
  initiate_languages();
  mixed tmp;
  
  mark_fd(0, "Stdin");
  mark_fd(1, "Stdout");
  mark_fd(2, "Stderr");

  configuration_dir =
    Getopt.find_option(argv, "d",({"config-dir","configuration-directory" }),
	     ({ "ROXEN_CONFIGDIR", "CONFIGURATIONS" }), "../configurations");

  if(configuration_dir[-1] != '/')
    configuration_dir += "/";

  startpid = getppid();
  roxenpid = getpid();

  // Dangerous...
  if(tmp = Getopt.find_option(argv, "r", "root")) fix_root(tmp);

  argv -= ({ 0 });
  argc = sizeof(argv);

  define_global_variables(argc, argv);

  object o;
  if(QUERY(locale) != "standard" && (o = Locale.Roxen[QUERY(locale)]))
  {
    default_locale = o;
    SET_LOCALE(default_locale);
  }
#if efun(syslog)
  init_logger();
#endif
  init_garber();
  initiate_supports();
  initiate_configuration_port( 1 );
  enable_configurations();

  set_u_and_gid(); // Running with the right [e]uid:[e]gid from this point on.

  create_pid_file(Getopt.find_option(argv, "p", "pid-file", "ROXEN_PID_FILE")
		  || QUERY(pidfile));

  roxen_perror("Initiating argument cache ... ");

  int id;
  string cp = QUERY(argument_cache_dir), na = "args";
  if( QUERY(argument_cache_in_db) )
  {
    id = 1;
    cp = QUERY(argument_cache_db_path);
    na = "argumentcache";
  }
  mixed e;
  e = catch( argcache = ArgCache(na,cp,id) );
  if( e )
  {
    report_error( "Failed to initialize the global argument cache:\n"
                  + (describe_backtrace( e )/"\n")[0]+"\n");
    werror( describe_backtrace( e ) );
  }
  roxen_perror( "\n" );

  enable_configurations_modules();
  
  call_out(update_supports_from_roxen_com,
	   QUERY(next_supports_update)-time());
  
#ifdef THREADS
  start_handler_threads();
  catch( this_thread()->set_name("Backend") );
  backend_thread = this_thread();
#if efun(thread_set_concurrency)
  thread_set_concurrency(QUERY(numthreads)+1);
#endif
#endif /* THREADS */

  // Signals which cause a restart (exitcode != 0)
  foreach( ({ "SIGINT", "SIGTERM" }), string sig) {
    catch { signal(signum(sig), exit_when_done); };
  }
  catch { signal(signum("SIGHUP"), reload_all_configurations); };
  // Signals which cause a shutdown (exitcode == 0)
  foreach( ({  }), string sig) {
    catch { signal(signum(sig), shutdown); };
  }
  // Signals which cause Roxen to dump the thread state
  foreach( ({ "SIGUSR1", "SIGUSR2", "SIGTRAP" }), string sig) {
    catch { signal(signum(sig), describe_all_threads); };
  }

#ifdef __RUN_TRACE
  trace(1);
#endif
  start_time=time();		// Used by the "uptime" info later on.

  

  return -1;
}

string diagnose_error(array from)
{
}

// Called from the configuration interface.
string check_variable(string name, mixed value)
{
  switch(name)
  {
   case "ConfigPorts":
    config_ports_changed = 1;
    break;
   case "cachedir":
//     if(!sscanf(value, "%*s/roxen_cache"))
//     {
      // FIXME: LOCALE?
      // We will skip this soon anyway....
//    object node;
//    node = (configuration_interface()->root->descend("Globals", 1)->
//            descend("Proxy disk cache: Base Cache Dir", 1));
//    if(node && !node->changed) node->change(1);
//       mkdirhier(value+"roxen_cache/foo");
//       call_out(set, 0, "cachedir", value+"roxen_cache/");
//     }
    break;

   case "ConfigurationURL":
   case "MyWorldLocation":
    if(strlen(value)<7 || value[-1] != '/' ||
       !(sscanf(value,"%*s://%*s/")==2))
      return(LOCALE->url_format());
    break;

   case "abs_engage":
    if (value)
      restart_if_stuck(1);
    else 
      remove_call_out(restart_if_stuck);
    break;

   case "suicide_engage":
    if (value) 
      call_out(restart,60*60*24*QUERY(suicide_timeout));
    else
      remove_call_out(restart);
    break;
   case "locale":
     object o;
     if(value != "standard" && (o = Locale.Roxen[value]))
     {
       default_locale = o;
       SET_LOCALE(default_locale);
       if(root)
       {
         root->clear();
//       destruct(root);
// 	 configuration_interface()->root = configuration_interface()->Node();
	 configuration_interface()->
	   build_root(configuration_interface()->root);
       }
     }
     break;
  }
}


mapping config_cache = ([ ]);
mapping host_accuracy_cache = ([]);
int is_ip(string s)
{
  return (replace(s,"0123456789."/"",({""})*11) == "");
}

object find_server_for(object id, string host, string|void port)
{
  object old_conf = id->conf;
  int portno = ((int)port);

#ifdef REQUEST_DEBUG
  werror(sprintf("ROXEN: find_server_for(%O, %O, %O)\n", id, host, port));
#endif /* REQUEST_DEBUG */

  if(portno!=0 && portno!=21 && portno!=80 && portno!=443)
    // Not likely to be anything else than the current virtual server.
    return id->conf;

  host = lower_case(host);
  if(config_cache[host]) {
    id->conf=config_cache[host];
  } else {
    if (is_ip(host)) {
      // Not likely to be anything else than the current virtual server.
      config_cache[host] = id->conf;
      return (id->conf);
    }

    int best;
    object c;
    string hn;
#if !constant(String.fuzzymatch) && constant(Array.diff_longest_sequence)
    array a = host/"";
#endif /* !String.fuzzymatch && Array.diff_longest_sequence */

    foreach(configurations, object s) {
      string h = lower_case(s->query("MyWorldLocation"));

      // Remove http:// et al here...
      // Would get interresting correlation problems with the "http" otherwise.
      int i = search(h, "://");
      if (i != -1) {
	h = h[i+3..];
      }
      if ((i = search(h, "/")) != -1) {
	h = h[..i-1];
      }

#if constant(String.fuzzymatch)
      int corr = String.fuzzymatch(host, h);
#elif constant(Array.diff_longest_sequence)
      int corr = sizeof(Array.diff_longest_sequence(a, h/""));
#endif /* constant(Array.diff_longest_sequence) */

      /* The idea of the algorithm is to find the server-url with the longest
       * common sequence of characters with the host-string, and among those
       * with the same correlation take the one which is shortest (ie least
       * amount to throw away).
       */
      if ((corr > best) ||
	  ((corr == best) && hn && (sizeof(hn) > sizeof(h)))) {
	/* Either better correlation,
	 * or the same, but a shorter hostname.
	 */
	best = corr;
	c = s;
	hn = h;
      }
    }

#if !constant(String.fuzzymatch) && constant(Array.diff_longest_sequence)
    // Minmatch should be counted in percent
    best=best*100/strlen(host);
#endif /* !String.fuzzymatch && Array.diff_longest_sequence */

    if(best >= 50 /* QUERY(minmatch) */)
      id->conf = config_cache[host] = (c || id->conf);
    else
      config_cache[host] = id->conf;
    host_accuracy_cache[host] = best;
  }

  if (id->conf != old_conf) 
  {
    /* Need to re-authenticate with the new server */

    if (id->rawauth) {
      array(string) y = id->rawauth / " ";

      id->realauth = 0;
      id->auth = 0;

      if (sizeof(y) >= 2) {
	y[1] = MIME.decode_base64(y[1]);
	id->realauth = y[1];
	if (id->conf && id->conf->auth_module) {
	  y = id->conf->auth_module->auth(y, id);
	}
	id->auth = y;
      }
    }
  }
  return id->conf;
}

object find_site_for( object id )
{
  if(id->misc->host) 
    return find_server_for(id,@lower_case(id->misc->host)/":");
  else
    return id->conf;
}
