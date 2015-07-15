// This file is part of Roxen WebServer.
// Copyright © 1996 - 2009, Roxen IS.
//
// The Roxen WebServer main program.
//
// Per Hedbor, Henrik Grubbström, Pontus Hagland, David Hedbor and others.
// ABS and suicide systems contributed freely by Francesco Chemolli

constant cvs_version="$Id$";

//! @appears roxen
//!
//! The Roxen WebServer main program.

// The argument cache. Used by the image cache.
ArgCache argcache;

// Some headerfiles
#define IN_ROXEN
#include <roxen.h>
#include <config.h>
#include <module.h>
#include <stat.h>
#include <timers.h>

// Inherits
inherit "global_variables";
#ifdef SNMP_AGENT
inherit "snmpagent";
#endif
#ifdef SMTP_RELAY
inherit "smtprelay";
#endif
inherit "hosts";
inherit "disk_cache";
inherit "fsgc";
// inherit "language";
inherit "supports";
inherit "module_support";
inherit "config_userdb";

// Used to find out which thread is the backend thread.
Thread.Thread backend_thread;

// --- Locale defines ---

//<locale-token project="roxen_start">   LOC_S </locale-token>
//<locale-token project="roxen_message"> LOC_M </locale-token>
#define LOC_S(X,Y)	_STR_LOCALE("roxen_start",X,Y)
#define LOC_M(X,Y)	_STR_LOCALE("roxen_message",X,Y)
#define CALL_M(X,Y)	_LOCALE_FUN("roxen_message",X,Y)

// --- Debug defines ---

#ifdef SSL3_DEBUG
# define SSL3_WERR(X) report_debug("TLS port %s: %s\n", get_url(), X)
#else
# define SSL3_WERR(X)
#endif

#ifdef THREAD_DEBUG
# define THREAD_WERR(X) report_debug("Thread: "+X+"\n")
#else
# define THREAD_WERR(X)
#endif

// Needed to get core dumps of seteuid()'ed processes on Linux.
#if constant(System.dumpable)
#define enable_coredumps(X)	System.dumpable(X)
#else
#define enable_coredumps(X)
#endif

#define DDUMP(X) sol( combine_path( __FILE__, "../../" + X ), dump )
protected function sol = master()->set_on_load;

// Tell Pike.count_memory this is global.
constant pike_cycle_depth = 0;

#ifdef TEST_EUID_CHANGE
int test_euid_change;
#endif

string md5( string what )
{
  return Gmp.mpz(Crypto.MD5.hash( what ),256)->digits(32);
}
  
string query_configuration_dir()
{
  return configuration_dir;
}

array(string|int) filename_2 (program|object o)
{
  if( objectp( o ) )
    o = object_program( o );

  string fname = Program.defined (o);
  int line;
  if (fname) {
    array(string) p = fname / ":";
    if (sizeof (p) > 1 && p[-1] != "" && sscanf (p[-1], "%d%*c", int l) == 1) {
      fname = p[..<1] * ":";
      line = l;
    }
  }

  else if( !fname ) {
    fname = master()->program_name( o );
    if (!fname)
      return ({0, 0});
  }

  string cwd = getcwd() + "/";
  if (has_prefix (fname, cwd))
    fname = fname[sizeof (cwd)..];
  else if (has_prefix (fname, roxenloader.server_dir))
    fname = fname[sizeof (roxenloader.server_dir)..];

  return ({fname, line});
}

string filename( program|object o )
{
  [string fname, int line] = filename_2 (o);
  return fname || "(unknown program)";
}

protected int once_mode;

// Note that 2.5 is a nonexisting version. It's only used for the
// cache static optimization for tags such as <if> and <emit> inside
// <cache> since that optimization can give tricky incompatibilities
// with 2.4.
array(string) compat_levels = ({"2.1", "2.2", "2.4", "2.5",
				"3.3", "3.4",
				"4.0", "4.5",
				"5.0", "5.1", "5.2" });

#ifdef THREADS
mapping(string:string) thread_names = ([]);
string thread_name( object thread, int|void skip_auto_name )
{
  string tn;
  if( thread_names[ tn=sprintf("%O",thread) ] || skip_auto_name )
    return thread_names[tn];
  return tn;
}

void name_thread( object thread, string name )
{
  string th_key = sprintf("%O", thread);
  if (name)
    thread_names[th_key] = name;
  else
    m_delete(thread_names, th_key);
}

// This mutex is used by Privs
Thread.Mutex euid_egid_lock = Thread.Mutex();
#endif /* THREADS */

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

#define LOGP (variables && variables->audit && variables->audit->query())

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

/* Used by read_config.pike, since there seems to be problems with
 * overloading otherwise.
 */
protected Privs PRIVS(string r, int|string|void u, int|string|void g)
{
  return Privs(r, u, g);
}

// Current Configuration.
Thread.Local current_configuration = Thread.Local();

// font cache and loading.
// 
// This will be changed to a list of server global modules, to make it
// easier to implement new types of fonts (such as PPM color fonts, as
// an example)
class Fonts
{
  class Font
  {
    Image.Image write( string ... what );
    array(int) text_extents( string ... what );
  };
  array available_font_versions(string name, int size);
  string describe_font_type(string n);
  Font get_font(string f, int size, int bold, int italic,
		string justification, float|int xspace, float|int yspace);

  Font resolve_font(string f, string|void justification);
  array(string) available_fonts(int(0..1)|void force_reload);
}
Fonts fonts;

// Will replace Configuration after create() is run.
program _configuration;	/*set in create*/

array(Configuration) configurations = ({});

private void stop_all_configurations()
{
  configurations->unregister_urls();
#ifdef THREADS
  // Spend some time waiting out the handler threads before starting
  // to shut down the modules.
  hold_handler_threads();
  release_handler_threads(3);
#endif
  configurations->stop(1);
}

// Function that actually shuts down Roxen. (see low_shutdown).
private void really_low_shutdown(int exit_code)
{
  // Die nicely. Catch for paranoia reasons
#ifdef THREADS
  if (mixed err = catch (stop_handler_threads()))
    werror (describe_backtrace (err));
#endif /* THREADS */
  if (!exit_code || once_mode) {
    // We're shutting down; Attempt to take mysqld with us.
    if (mixed err =
	catch { report_notice("Shutting down MySQL.\n"); } ||
	catch {
	  Sql.Sql db = connect_to_my_mysql(0, "mysql");
	  db->shutdown();
	})
      master()->handle_error (err);
  }
  // Zap some of the remaining caches.
  destruct (argcache);
  destruct (cache);
#if 0
  // Disabled since it's lying when the server is shut down with a
  // SIGTERM or SIGINT to the start script (which include the stop
  // action of the init.d script).
  if (mixed err = catch {
      if (exit_code && !once_mode)
	report_notice("Restarting Roxen.\n");
      else
	report_notice("Shutting down Roxen.\n");
    })
    master()->handle_error (err);
#endif
  roxenloader.real_exit( exit_code ); // Now we die...
}

private int shutdown_recurse;

// Shutdown Roxen
//  exit_code = 0	True shutdown
//  exit_code = -1	Restart
private void low_shutdown(int exit_code)
{
  if(shutdown_recurse >= 4)
  {
    if (mixed err =
	catch (report_notice("Exiting roxen (spurious signals received).\n")) ||
	catch (stop_all_configurations()))
      master()->handle_error (err);
    // Zap some of the remaining caches.
    destruct(argcache);
    destruct(cache);
#ifdef THREADS
#if constant(Filesystem.Monitor.basic)
    stop_fsgarb();
#endif
    if (mixed err = catch (stop_handler_threads()))
      master()->handle_error (err);
#endif /* THREADS */
    roxenloader.real_exit(exit_code);
  }
  if (shutdown_recurse++) return;

#ifndef NO_SLOW_REQ_BT
  // Turn off the backend thread monitor while we're shutting down.
  slow_be_timeout_changed();
#endif

  if (mixed err = catch(stop_all_configurations()))
    master()->handle_error (err);

#ifdef SNMP_AGENT
  if(objectp(snmpagent)) {
    snmpagent->stop_trap();
    snmpagent->disable();
  }
#endif

  call_out(really_low_shutdown, 0.1, exit_code);
}

private int shutdown_started;

// Perhaps somewhat misnamed, really...  This function will close all
// listen ports and then quit.  The 'start' script should then start a
// new copy of roxen automatically.
void restart(float|void i, void|int exit_code)
//! Restart roxen, if the start script is running
{
  shutdown_started = 1;
  call_out(low_shutdown, i, exit_code || -1);
}

void shutdown(float|void i)
//! Shut down roxen
{
  shutdown_started = 1;
  call_out(low_shutdown, i, 0);
}

void exit_when_done()
{
  shutdown_started = 1;
  report_notice("Interrupt request received.\n");
  low_shutdown(-1);
}

int is_shutting_down()
//! Returns true if Roxen is shutting down.
{
  return shutdown_started;
}


/*
 * handle() stuff
 */

#ifdef THREADS
// function handle = threaded_handle;

Thread.Thread do_thread_create(string id, function f, mixed ... args)
{
  Thread.Thread t = thread_create(f, @args);
  name_thread( t, id );
  return t;
}

#if 1
constant Queue = Thread.Queue;
#else
// Shamelessly uses facts about pikes preemting algorithm.
// Might have to be fixed in the future.
class Queue 
//! Thread.Queue lookalike, which uses some archaic and less
//! known features of the preempting algorithm in pike to optimize the
//! read function.
//
// If those archaic and less known features are to depend on the
// interpreter lock in the while loop that waits on the condition
// variable then it doesn't work since Pike always might yield before
// a function call (specifically, the wait() call in the condition
// variable). Thus a handler thread might wait even though there is a
// request to process. However, the only effect is that that specific
// request isn't serviced timely; when the next request comes in the
// thread will be woken up and both requests will be handled.
// Furthermore it's extremely rare in the first place since there
// normally are several handler threads.
{
  inherit Thread.Condition : r_cond;
  array buffer=allocate(8);
  int r_ptr, w_ptr;
  
  int size() 
  { 
    return w_ptr - r_ptr;  
  }
  
  mixed read()
  {
    while(!(w_ptr - r_ptr)) {
      // Make a MutexKey for wait() to please 7.3. This will of course
      // not fix the race, but we ignore that. See the discussion
      // above. (Must have an extra ref to the mutex since the
      // MutexKey doesn't keep one.)
      Thread.Mutex m = Thread.Mutex();
      r_cond::wait (m->lock());
    }
    mixed tmp = buffer[r_ptr];
    buffer[r_ptr++] = 0;	// Throw away any references.
    return tmp;
  }

  mixed try_read()
  {
    if (!(w_ptr - r_ptr)) return ([])[0];
    mixed tmp = buffer[r_ptr];
    buffer[r_ptr++] = 0;	// Throw away any references.
    return tmp;
  }

  // Warning: This function isn't thread safe.
  void write(mixed v)
  {
    if(w_ptr >= sizeof(buffer))
    {
      buffer=buffer[r_ptr..]+allocate(8);
      w_ptr-=r_ptr;
      r_ptr=0;
    }
    buffer[w_ptr++]=v;
    r_cond::signal();
  }
}
#endif

#ifndef NO_SLOW_REQ_BT
// This is a system to dump all threads whenever a request takes
// longer than a configurable timeout.

protected Pike.Backend slow_req_monitor; // Set iff slow req bt is enabled.
protected float slow_req_timeout, slow_be_timeout;

protected void slow_req_monitor_thread (Pike.Backend my_monitor)
{
  // my_monitor is just a safeguard to ensure we don't get multiple
  // monitor threads.
  name_thread(this_thread(), "Slow request monitor");
  while (slow_req_monitor == my_monitor)
    slow_req_monitor (3600.0);
  name_thread(this_thread(), 0);
}

protected mixed slow_be_call_out;

protected void slow_be_before_cb()
{
#ifdef DEBUG
  if (this_thread() != backend_thread) error ("Run from wrong thread.\n");
#endif
  if (Pike.Backend monitor = slow_be_call_out && slow_req_monitor) {
    monitor->remove_call_out (slow_be_call_out);
    slow_be_call_out = 0;
  }
}

protected void slow_be_after_cb()
{
  // FIXME: This should try to compensate for delays due to the pike
  // gc, because it just causes noise here.
#ifdef DEBUG
  if (this_thread() != backend_thread) error ("Run from wrong thread.\n");
#endif
  if (slow_be_timeout > 0.0)
    if (Pike.Backend monitor = slow_req_monitor)
      slow_be_call_out = monitor->call_out (dump_slow_req, slow_be_timeout,
					    this_thread(), slow_be_timeout);
}

void slow_req_count_changed()
{
  Pike.Backend monitor = slow_req_monitor;
  int count = query ("slow_req_bt_count");

  if (count && monitor) {
    // Just a change of the count - nothing to do.
  }

  else if (count) {		// Start.
    monitor = slow_req_monitor = Pike.SmallBackend();
    Thread.thread_create (slow_req_monitor_thread, monitor);
    monitor->call_out (lambda () {}, 0); // Safeguard if there's a race.
    slow_be_timeout_changed();
  }

  else if (monitor) {		// Stop.
    slow_req_monitor = 0;
    monitor->call_out (lambda () {}, 0); // To wake up the thread.
    slow_be_timeout_changed();
  }
}

void slow_req_timeout_changed()
{
#ifdef DEBUG
  if (query ("slow_req_bt_timeout") < 0) error ("Invalid timeout.\n");
#endif
  slow_req_timeout = query ("slow_req_bt_timeout");
}

void slow_be_timeout_changed()
{
#ifdef DEBUG
  if (query ("slow_be_bt_timeout") < 0) error ("Invalid timeout.\n");
#endif
  slow_be_timeout = query ("slow_be_bt_timeout");

#ifdef DEBUG
  if ((Pike.DefaultBackend->before_callback &&
       Pike.DefaultBackend->before_callback != slow_be_before_cb) ||
      (Pike.DefaultBackend->after_callback &&
       Pike.DefaultBackend->after_callback != slow_be_after_cb))
    werror ("Pike.DefaultBackend already hooked up with "
	    "other before/after callbacks - they get overwritten: %O/%O\n",
	    Pike.DefaultBackend->before_callback,
	    Pike.DefaultBackend->after_callback);
#endif

  if (query ("slow_req_bt_count") && slow_be_timeout > 0.0 &&
      // Don't trig if we're shutting down.
      !shutdown_started) {
    Pike.DefaultBackend->before_callback = slow_be_before_cb;
    Pike.DefaultBackend->after_callback = slow_be_after_cb;
  }
  else {
    Pike.DefaultBackend->before_callback = 0;
    Pike.DefaultBackend->after_callback = 0;
    if (Pike.Backend monitor = slow_be_call_out && slow_req_monitor) {
      monitor->remove_call_out (slow_be_call_out);
      slow_be_call_out = 0;
    }
  }
}

protected void dump_slow_req (Thread.Thread thread, float timeout)
{
  object threads_disabled = _disable_threads();

  int count = query ("slow_req_bt_count");
  if (count > 0) set ("slow_req_bt_count", count - 1);

  if (thread == backend_thread && !slow_be_call_out) {
    // Avoid false alarms for the backend thread if we got here due to
    // a race. Should perhaps have something like this for the handler
    // threads too, but otoh races are more rare there due to the
    // longer timeouts.
  }

  else {
    report_debug ("###### %s 0x%x has been busy for more than %g seconds.\n",
		  thread == backend_thread ? "Backend thread" : "Thread",
		  thread->id_number(), timeout);
    describe_all_threads (0, threads_disabled);
  }

  threads_disabled = 0; 	// Paranoia.
}

#endif	// !NO_SLOW_REQ_BT

// // This is easier than when there are no threads.
// // See the discussion below. :-)
//
//  // But there is extra functionality below we really want, though,
//  // so let's use that one instead...
// function async_sig_start( function f, int really )
// {
//   return lambda( mixed ... args ) {
// 	   thread_create( f, @args );
//  };
// }
local protected Queue handle_queue = Queue();
//! Queue of things to handle.
//! An entry consists of an array(function fp, array args)

local protected int thread_reap_cnt;
//! Number of handler threads in the process of being stopped.

protected int threads_on_hold;
//! Number of handler threads on hold.

// Global variables for statistics
int handler_num_runs = 0;
int handler_num_runs_001s = 0;
int handler_num_runs_005s = 0;
int handler_num_runs_015s = 0;
int handler_num_runs_05s = 0;
int handler_num_runs_1s = 0;
int handler_num_runs_5s = 0;
int handler_num_runs_15s = 0;
int handler_acc_time = 0;
int handler_acc_cpu_time = 0;

protected string debug_format_queue_task (array(function|array) task)
// Debug formatter of an entry in the handler or background_run queues.
{
  return ((functionp (task[0]) ?
	   sprintf ("%s: %s", Function.defined (task[0]),
		    master()->describe_function (task[0])) :
	   programp (task[0]) ?
	   sprintf ("%s: %s", Program.defined (task[0]),
		    master()->describe_program (task[0])) :
	   sprintf ("%O", task[0])) +
	  "(" +
	  map (task[1], lambda (mixed arg)
			  {return RXML.utils.format_short (arg, 200);}) * ", " +
	  ")");
}

protected mapping(Thread.Thread:int) thread_task_start_times = ([]);

mapping(Thread.Thread:int) get_thread_task_start_times()
{
  //  Also needed in Admin interface's thread wizard
  return thread_task_start_times + ([ ]);
}

local protected void handler_thread(int id)
//! The actual handling function. This functions read function and
//! parameters from the queue, calls it, then reads another one. There
//! is a lot of error handling to ensure that nothing serious happens if
//! the handler function throws an error.
{
  THREAD_WERR("Handle thread ["+id+"] started");
  mixed h, q;
  set_u_and_gid (1);
#ifdef TEST_EUID_CHANGE
  if (test_euid_change) {
    Stdio.File f = Stdio.File();
    if (f->open ("rootonly", "r") && f->read())
      werror ("Handler thread %d can read rootonly\n", id);
    else
      werror ("Handler thread %d can't read rootonly\n", id);
  }
#endif
  while(1)
  {
    int thread_flagged_as_busy;
#ifndef NO_SLOW_REQ_BT
    Pike.Backend monitor;
    mixed call_out;
#endif
    if(q=catch {
      do {
//  	if (!busy_threads) werror ("GC: %d\n", gc());
	cache_clear_deltas();
	THREAD_WERR("Handle thread ["+id+"] waiting for next event");
	if(arrayp(h=handle_queue->read()) && h[0]) {
	  THREAD_WERR(sprintf("Handle thread [%O] calling %s",
			      id, debug_format_queue_task (h)));
	  set_locale();
	  busy_threads++;
	  thread_flagged_as_busy = 1;
	  handler_num_runs++;

	  int start_hrtime = gethrtime();
	  thread_task_start_times[this_thread()] = start_hrtime;
	  float handler_vtime = gauge {
#ifndef NO_SLOW_REQ_BT
	      if (h[0] != bg_process_queue &&
		  // Leave out bg_process_queue. It makes a timeout on
		  // every individual job instead.
		  (monitor = slow_req_monitor) && slow_req_timeout > 0.0) {
		call_out = monitor->call_out (dump_slow_req, slow_req_timeout,
					      this_thread(), slow_req_timeout);
		h[0](@h[1]);
		monitor->remove_call_out (call_out);
	      }
	      else
#endif
		{
		  h[0](@h[1]);
		}
	    };
	  float handler_rtime = (gethrtime() - start_hrtime)/1E6;
	  thread_task_start_times[this_thread()] = 0;

	  h=0;
	  busy_threads--;
	  thread_flagged_as_busy = 0;
	  if (handler_rtime >  0.01) handler_num_runs_001s++;
	  if (handler_rtime >  0.05) handler_num_runs_005s++;
	  if (handler_rtime >  0.15) handler_num_runs_015s++;
	  if (handler_rtime >  0.50) handler_num_runs_05s++;
	  if (handler_rtime >  1.00) handler_num_runs_1s++;
	  if (handler_rtime >  5.00) handler_num_runs_5s++;
	  if (handler_rtime > 15.00) handler_num_runs_15s++;
	  handler_acc_cpu_time += (int)(1E6*handler_vtime);
	  handler_acc_time += (int)(1E6*handler_rtime);
	} else if(!h) {
	  // Roxen is shutting down.
	  report_debug("Handle thread ["+id+"] stopped.\n");
	  thread_reap_cnt--;
#ifdef NSERIOUS
	  if(!thread_reap_cnt) report_debug("+++ATH\n");
#endif
	  return;
	}
#ifdef DEBUG
	else if (h != 1)
	  error ("Unknown message in handle_queue: %O\n", h);
#endif
	else {
	  num_hold_messages--;
	  THREAD_WERR("Handle thread [" + id + "] put on hold");
	  threads_on_hold++;
	  if (Thread.Condition cond = hold_wakeup_cond) {
	    // Make a MutexKey for wait() to please 7.3. This will of
	    // course not fix the race, but we ignore that. See the
	    // comment at the declaration of hold_wakeup_cond. (Must
	    // have an extra ref to the mutex since the MutexKey
	    // doesn't keep one.)
	    Thread.Mutex m = Thread.Mutex();
	    cond->wait (m->lock());
	  }
	  threads_on_hold--;
	  THREAD_WERR("Handle thread [" + id + "] released");
	}
      } while(1);
    }) {
      if (thread_flagged_as_busy)
	busy_threads--;
#ifndef NO_SLOW_REQ_BT
      if (call_out) monitor->remove_call_out (call_out);
#endif
      if (h = catch {
	master()->handle_error (q);
	if (q = catch {h = 0;}) {
	  report_error(LOC_M(5, "Uncaught error in handler thread: %sClient "
			     "will not get any response from Roxen.")+"\n",
		       describe_backtrace(q));
	  catch (q = 0);
	}
      }) {
	catch {
	  report_error("Error reporting error:\n");
	  report_error(sprintf("Raw error: %O\n", h[0]));
	  report_error(sprintf("Original raw error: %O\n", q[0]));
	};
	catch (q = 0);
	catch (h = 0);
      }
    }
  }
}

void handle(function f, mixed ... args)
{
  handle_queue->write(({f, args }));
}

int handle_queue_length()
{
  return handle_queue->size();
}

int number_of_threads;
//! The number of handler threads to run.

int busy_threads;
//! The number of currently busy threads.

protected array(object) handler_threads = ({});
//! The handler threads, the list is kept for debug reasons.

void start_handler_threads()
{
  if (query("numthreads") <= 1) {
    set( "numthreads", 1 );
    report_warning (LOC_S(1, "Starting one thread to handle requests.")+"\n");
  } else { 
    report_notice (LOC_S(2, "Starting %d threads to handle requests.")+"\n",
		   query("numthreads") );
  }
  array(object) new_threads = ({});
  for(; number_of_threads < query("numthreads"); number_of_threads++)
    new_threads += ({ do_thread_create( "Handle thread [" +
					number_of_threads + "]",
					handler_thread, number_of_threads ) });
  handler_threads += new_threads;
}

protected int num_hold_messages;
protected Thread.Condition hold_wakeup_cond = Thread.Condition();
// Note: There are races in the use of this condition variable, but
// the only effect of that is that some handler thread might be
// considered hung when it's actually waiting on hold_wakeup_cond, and
// the hold/release handler threads function deal with hung threads
// anyway. The outcome would only be that release_handler_threads
// starts some extra handler thread unnecessarily.

void hold_handler_threads()
//! Tries to put all handler threads on hold, but gives up if it takes
//! too long.
{
  if (!hold_wakeup_cond) {
    THREAD_WERR("Ignoring request to hold handler threads during stop");
    return;
  }

  int timeout=10;
#if constant(_reset_dmalloc)
  // DMALLOC slows stuff down a bit...
  timeout *= 10;
#endif /* constant(_reset_dmalloc) */

  THREAD_WERR("Putting " + (number_of_threads - threads_on_hold) +
	      " handler threads on hold, " +
	      threads_on_hold + " on hold already");

  for (int i = number_of_threads - threads_on_hold - num_hold_messages; i-- > 0;) {
    handle_queue->write (1);
    num_hold_messages++;
  }
  while (threads_on_hold < number_of_threads && timeout--)
    sleep (0.1);

  THREAD_WERR(threads_on_hold + " handler threads on hold, " +
	      (number_of_threads - threads_on_hold) + " not responding");
}

void release_handler_threads (int numthreads)
//! Releases any handler threads put on hold. If necessary new threads
//! are started to ensure that at least @[numthreads] threads are
//! responding. Threads that haven't arrived to the hold state since
//! @[hold_handler_threads] are considered nonresponding.
{
  if (Thread.Condition cond = hold_wakeup_cond) {
    // Flush out any remaining hold messages from the queue.
    for (int i = handle_queue->size(); i && num_hold_messages; i--) {
      mixed task = handle_queue->try_read();
      if (task == 1) num_hold_messages--;
      else handle_queue->write (task);
    }
#ifdef DEBUG
    if (num_hold_messages)
      error ("num_hold_messages is bogus (%d).\n", num_hold_messages);
#endif
    num_hold_messages = 0;

    int blocked_threads = number_of_threads - threads_on_hold;
    int threads_to_create = numthreads - threads_on_hold;

    THREAD_WERR("Releasing " + threads_on_hold + " threads on hold");
    cond->broadcast();

    if (threads_to_create > 0) {
      array(object) new_threads = ({});
      for (int n = 0; n < threads_to_create; number_of_threads++, n++)
	new_threads += ({ do_thread_create( "Handle thread [" +
					    number_of_threads + "]",
					    handler_thread, number_of_threads ) });
      handler_threads += new_threads;
      report_notice ("Created %d new handler threads to compensate "
		     "for %d blocked ones.\n", threads_to_create, blocked_threads);
    }
  }
  else {
    THREAD_WERR("Ignoring request to release handler threads during stop");
    return;
  }
}

//!
int handler_threads_on_hold() {return !!hold_wakeup_cond;}

protected Thread.MutexKey backend_block_lock;

void stop_handler_threads()
//! Stop all the handler threads and the backend, but give up if it
//! takes too long.
{
  int timeout=15;		// Timeout if the bg queue doesn't get shorter.
  int background_run_timeout = 100; // Hard timeout that cuts off the bg queue.
#if constant(_reset_dmalloc)
  // DMALLOC slows stuff down a bit...
  timeout *= 10;
  background_run_timeout *= 3;
#endif /* constant(_reset_dmalloc) */

  report_debug("Stopping all request handler threads.\n");

  // Wake up any handler threads on hold, and ensure none gets on hold
  // after this.
  if (Thread.Condition cond = hold_wakeup_cond) {
    hold_wakeup_cond = 0;
    cond->broadcast();
  }

  while(number_of_threads>0) {
    number_of_threads--;
    handle_queue->write(0);
    thread_reap_cnt++;
  }
  handler_threads = ({});

  if (this_thread() != backend_thread && !backend_block_lock) {
    thread_reap_cnt++;
    Thread.Mutex mutex = Thread.Mutex();
    backend_block_lock = mutex->lock();
    call_out (lambda () {
		thread_reap_cnt--;
		report_debug("Backend thread stopped.\n");
		mutex->lock();
		error("Backend stop failed.\n");
	      }, 0);
  }

  int prev_bg_len = bg_queue_length();

  while (thread_reap_cnt) {
    sleep(0.1);

    if (--timeout <= 0) {
      int cur_bg_len = bg_queue_length();
      if (prev_bg_len < cur_bg_len)
	// Allow more time if the background queue is being worked off.
	timeout = 10;
      prev_bg_len = cur_bg_len;
    }

    if(--background_run_timeout <= 0 || timeout <= 0) {
      report_debug("Giving up waiting on threads; "
		   "%d threads blocked, %d jobs in the background queue.\n",
		   thread_reap_cnt, bg_queue_length());
#ifdef DEBUG
      describe_all_threads();
#endif
      return;
    }
  }
}

#else
// handle function used when THREADS is not enabled.
 void handle(function f, mixed ... args)
{
  f(@args);
}

// function handle = unthreaded_handle;

#endif /* THREADS */

function async_sig_start( function f, int really )
{
  class SignalAsyncVerifier( function f )
  {
    protected int async_called;

    void really_call( array args )
    {
      async_called = 0;
      f( @args );
    }

    void call( mixed ... args )
    {
      if( async_called && async_called-time() )
      {
	report_debug("Received signal %s\n", (string) signame( args[0] ) );
        report_debug("\n\n"
                     "Async calling failed for %O, calling synchronous\n", f);
        report_debug("Backtrace at time of hangup:\n%s\n",
                     describe_backtrace( backtrace() ));
        f( @args );
        return;
      }
      if( !async_called ) // Do not queue more than one call at a time.
      {
	report_debug("Received signal %s\n", (string) signame( args[0] ) );
        async_called=time();
        call_out( really_call, 0, args );
      }
    }
  };
  // call_out is not really useful here, since we probably want to run
  // the signal handler immediately, not whenever the backend thread
  // is available. /per
  //
  // Calling directly like this may however lead to recursive mutex
  // lock errors. The problem cannot be solved using lock(2) since the
  // internal structures may be in an inconsistent state from the
  // previous call, and waiting for the lock probably leads to a
  // deadlock. /noring
  //
  // But on the other hand, you are not very likely to have any mutex
  // locks in an unthreaded pike, since it's quite impossible. /per
  //
  // But still, the problems with inconsistent internal states are
  // there. The API:s for many (thread safe) objects are designed to
  // only allow one (1) caller at any given time. It's a bug if this
  // restriction can be circumvented using signals. I suggest that
  // Thread.Mutex takes care of this problem in non-threaded mode.
  // /  noring
  //
  // Apparantly it already did that. :-)
  // 
  // I also fixed SIGHUP to be somewhat more asynchronous.  
  //
  // I also added a rather small amount of magic so that it is called
  // asynchronously the first time it is received, but repeated
  // signals are not called asynchronously unless the first signal
  // handler was actually called.
  //
  // Except for the SIGQUIT signal, which dumps a backtrace. It would
  // be an excercise in futility to call that one asynchronously.
  //
  // I hope that this will solve all your problems. /per
  if( really > 0 )
    return lambda( mixed ... args ){ call_out( f, 0, @args ); };
  if( really < 0 )
    return f;
  return SignalAsyncVerifier( f )->call;
}

#ifdef THREADS
protected Thread.Queue bg_queue = Thread.Queue();
protected Thread.Thread bg_process_thread;

// Use a time buffer to strike a balance if the server is busy and
// always have at least one busy thread: The maximum waiting time in
// that case is somewhere between bg_time_buffer_min and
// bg_time_buffer_max. If there are only short periods of time between
// the queue runs, the max waiting time will shrink towards the
// minimum.
protected constant bg_time_buffer_max = 30;
protected constant bg_time_buffer_min = 0;
protected int bg_last_busy = 0;
int bg_num_runs = 0;
int bg_num_runs_001s = 0;
int bg_num_runs_005s = 0;
int bg_num_runs_015s = 0;
int bg_num_runs_05s = 0;
int bg_num_runs_1s = 0;
int bg_num_runs_5s = 0;
int bg_num_runs_15s = 0;
int bg_acc_time = 0;
int bg_acc_cpu_time = 0;

int bg_queue_length()
{
  return bg_queue->size();
}

protected void bg_process_queue()
{
  if (bg_process_thread) return;
  // Relying on the interpreter lock here.
  bg_process_thread = this_thread();

  int maxbeats =
    min (time() - bg_last_busy, bg_time_buffer_max) * (int) (1 / 0.01);

#ifndef NO_SLOW_REQ_BT
  Pike.Backend monitor;
  mixed call_out;
#endif

  if (mixed err = catch {
    // Make sure we don't run forever if background jobs are queued
    // over and over again, to avoid starving other threads. (If they
    // are starved enough, busy_threads will never be incremented.)
    // If jobs are enqueued while running another background job,
    // bg_process_queue is put on the handler queue again at the very
    // end of this function.
    //
    // However, during shutdown we continue until the queue is really
    // empty. background_run won't queue new jobs then, and if this
    // takes too long, stop_handler_threads will exit anyway.
    int jobs_to_process = bg_queue->size();
    while (hold_wakeup_cond ? jobs_to_process-- : bg_queue->size()) {
      // Not a race here since only one thread is reading the queue.
      array task = bg_queue->read();

      // Wait a while if another thread is busy already.
      if (busy_threads > 1) {
	for (maxbeats = max (maxbeats, (int) (bg_time_buffer_min / 0.01));
	     busy_threads > 1 && maxbeats > 0;
	     maxbeats--)
	  sleep (0.01);
	bg_last_busy = time();
      }

#ifdef DEBUG_BACKGROUND_RUN
      report_debug ("background_run run %s [%d jobs left in queue]\n",
		    debug_format_queue_task (task),
		    bg_queue->size());
#endif

      float task_vtime, task_rtime;
      bg_num_runs++;

#ifndef NO_SLOW_REQ_BT
      if ((monitor = slow_req_monitor) && slow_req_timeout > 0.0) {
	call_out = monitor->call_out (dump_slow_req, slow_req_timeout,
				      this_thread(), slow_req_timeout);
	int start_hrtime = gethrtime();
	thread_task_start_times[this_thread()] = start_hrtime;
	task_vtime = gauge {
	    if (task[0]) // Ignore things that have become destructed.
	      // Note: BackgroundProcess.repeat assumes that there are
	      // exactly two refs to task[0] during the call below.
	      task[0] (@task[1]);
	  };
	task_rtime = (gethrtime() - start_hrtime) / 1e6;
	thread_task_start_times[this_thread()] = 0;
	monitor->remove_call_out (call_out);
      }
      else
#endif
      {
	int start_hrtime = gethrtime();
	thread_task_start_times[this_thread()] = start_hrtime;
	task_vtime = gauge {
	    if (task[0])
	      task[0] (@task[1]);
	  };
	task_rtime = (gethrtime() - start_hrtime) / 1e6;
	thread_task_start_times[this_thread()] = 0;
      }

      if (task_rtime >  0.01) bg_num_runs_001s++;
      if (task_rtime >  0.05) bg_num_runs_005s++;
      if (task_rtime >  0.15) bg_num_runs_015s++;
      if (task_rtime >  0.50) bg_num_runs_05s++;
      if (task_rtime >  1.00) bg_num_runs_1s++;
      if (task_rtime >  5.00) bg_num_runs_5s++;
      if (task_rtime > 15.00) bg_num_runs_15s++;
      bg_acc_cpu_time += (int)(1E6*task_vtime);
      bg_acc_time += (int)(1E6*task_rtime);

      if (task_rtime > 60.0)
	report_warning ("Warning: Background job took more than one minute "
			"(%g s real time and %g s cpu time):\n"
			"  %s (%s)\n%s",
			task_rtime, task_vtime,
			functionp (task[0]) ?
			sprintf ("%s: %s", Function.defined (task[0]),
				 master()->describe_function (task[0])) :
			programp (task[0]) ?
			sprintf ("%s: %s", Program.defined (task[0]),
				 master()->describe_program (task[0])) :
			sprintf ("%O", task[0]),
			map (task[1], lambda (mixed arg)
					{return sprintf ("%O", arg);}) * ", ",
			bg_queue->size() ?
			(bg_queue->size() > 1 ?
			 "  " + bg_queue->size() + " more jobs in the "
			 "background queue were delayed.\n" :
			 "  1 more job in the background queue was delayed.\n"):
			"");
#ifdef DEBUG_BACKGROUND_RUN
      else
	report_debug ("background_run done, "
		      "took %g ms cpu time and %g ms real time\n",
		      task_vtime * 1000, task_rtime * 1000);
#endif

      if (busy_threads > 1) bg_last_busy = time();
    }
  }) {
#ifndef NO_SLOW_REQ_BT
    if (call_out) monitor->remove_call_out (call_out);
#endif
    bg_process_thread = 0;
    handle (bg_process_queue);
    throw (err);
  }
  bg_process_thread = 0;
  if (bg_queue->size()) {
    handle (bg_process_queue);
    // Sleep a short while to encourage a thread switch. This is a
    // kludge to avoid starving non-handler threads, since pike
    // currently (7.8.503) doesn't switch threads reliably on yields.
    sleep (0.001);
  }
}
#endif

Thread.Thread background_run_thread()
//! Returns the thread currently executing the background_run queue,
//! or 0 if it isn't being processed.
{
#ifdef THREADS
  return bg_process_thread;
#else
  // FIXME: This is not correct. Should return something nonzero when
  // called from the call out. But noone is running without threads
  // nowadays anyway.
  return 0;
#endif
}

mixed background_run (int|float delay, function func, mixed... args)
//! Enqueue a task to run in the background in a way that makes as
//! little impact as possible on the incoming requests. No matter how
//! many tasks are queued to run in the background, only one is run at
//! a time. The tasks won't be starved regardless of server load,
//! though.
//!
//! The function @[func] will be enqueued after approximately @[delay]
//! seconds, to be called with the rest of the arguments as its
//! arguments.
//!
//! In a multithreaded server the function will be executed in one of
//! the handler threads. The function is executed in the backend
//! thread if no thread support is available, although that
//! practically never occurs anymore.
//!
//! To avoid starving other background jobs, the function should never
//! run for a long time. Instead do another call to @[background_run]
//! to queue it up again after some work has been done, or use
//! @[BackgroundProcess].
//!
//! @returns
//! If the function is queued for execution right away then zero is
//! returned. Otherwise its call out identifier is returned, which can
//! be used with @[find_call_out] or @[remove_call_out].
{
  // FIXME: Make it possible to associate the background job with a
  // RoxenModule or Configuration, so that report_error etc can log in
  // a good place.
#ifdef DEBUG_BACKGROUND_RUN
  report_debug ("background_run enqueue %s (%s) [%d jobs in queue]\n",
		functionp (func) ?
		sprintf ("%s: %s", Function.defined (func),
			 master()->describe_function (func)) :
		programp (func) ?
		sprintf ("%s: %s", Program.defined (func),
			 master()->describe_program (func)) :
		sprintf ("%O", func),
		map (args, lambda (mixed arg)
			   {return sprintf ("%O", arg);}) * ", ",
		bg_queue->size());
#endif

#ifdef THREADS
  if (!hold_wakeup_cond) {
    // stop_handler_threads is running; ignore more work.
#ifdef DEBUG
    report_debug ("Ignoring background job queued during shutdown: %O\n", func);
#endif
    return 0;
  }

  class enqueue(function func, mixed ... args)
  {
    int __hash() { return hash_value(func); }
    int `==(mixed gunc) { return func == gunc; }
    string _sprintf() { return sprintf("background_run(%O)", func); }
    mixed `()()
    {
      bg_queue->write (({func, args}));
      if (!bg_process_thread)
	handle (bg_process_queue);
    }
  };

  if (delay)
    return call_out (enqueue(func, @args), delay);
  else {
    enqueue(func, @args)();
    return 0;
  }
#else
  // Can't do much better when we haven't got threads..
  return call_out (func, delay, @args);
#endif
}

class BackgroundProcess
//! A class to do a task repeatedly in the background, in a way that
//! makes as little impact as possible on the incoming requests (using
//! @[background_run]).
//!
//! The user must keep a reference to this object, otherwise it will remove
//! itself and the callback won't be called anymore.
{
  int|float period;
  function func;
  array args;
  int stopping = 0;

  protected void repeat (function func, array args)
  {
    // Got a minimum of four refs to this:
    // o  One in the task array in bg_process_queue.
    // o  One on the stack in the call in bg_process_queue.
    // o  One as current_object in the stack frame.
    // o  One on the stack as argument to _refs.
    int self_refs = _refs (this);
#ifdef DEBUG
    if (self_refs < 4)
      error ("Minimum ref calculation wrong - have only %d refs.\n", self_refs);
#endif
    if (stopping || (self_refs <= 4) || !func) {
      stopping = 2;	// Stopped.
      return;
    }
    mixed err = catch {
	func (@args);
      };
    if (err)
      master()->handle_error (err);
    background_run (period, repeat, func, args);
  }

  //! @decl void set_period (int|float period);
  //!
  //! Changes the period to @[period] seconds between calls.
  //!
  //! @note
  //! This does not change the currently ongoing period, if any. That
  //! might be remedied.
  void set_period (int|float period_)
  {
    period = period_;
  }

  //! @decl protected void create (int|float period, function func, mixed... args);
  //!
  //! The function @[func] will be called with the following arguments
  //! after approximately @[period] seconds, and then kept being
  //! called with approximately that amount of time between each call.
  //!
  //! The repetition will stop if @[stop] is called, or if @[func]
  //! throws an error.
  protected void create (int|float period_, function func_, mixed... args_)
  {
    period = period_;
    func = func_;
    args = args_;
    background_run (period, repeat, func, args);
  }

  void stop()
  //! Sets a flag to stop the succession of calls.
  {
    stopping |= 1;
  }

  void start()
  //! Restart a stopped process.
  {
    int state = stopping;
    stopping = 0;
    if (state & 2) {
      background_run (period, repeat, func, args);
    }
  }

  string _sprintf()
  {
    return sprintf("BackgroundProcess(%O, %O)", period, func);
  }
}


mapping get_port_options( string key )
//! Get the options for the key 'key'.
//! The intepretation of the options is protocol specific.
{
  return (query( "port_options" )[ key ] || ([]));
}

void set_port_options( string key, mapping value )
//! Set the options for the key 'key'.
//! The intepretation of the options is protocol specific.
{
  mapping q = query("port_options");
  q[ key ] = value;
  set( "port_options" , q );
  save( );
}

#ifdef DEBUG_URL2CONF
#define URL2CONF_MSG(X...) report_debug (X)
#else
#define URL2CONF_MSG(X...)
#endif

protected mapping(string:int(0..1)) host_is_local_cache = ([]);

//! Check if @[hostname] is local to this machine.
int(0..1) host_is_local(string hostname)
{
  int(0..1) res;
  if (!zero_type(res = host_is_local_cache[hostname])) return res;
  
  // Look up the IP.
  string ip = blocking_host_to_ip(hostname);

  // Can we bind to it?
  Stdio.Port port = Stdio.Port();
  // bind() can trow error if ip is an invalid hostname.
  catch {
    res = port->bind(0, 0, ip);
  };

  destruct(port);
  return host_is_local_cache[hostname] = res;
}

array(Protocol|mapping(string:mixed)) find_port_for_url (
  Standards.URI url, void|Configuration only_this_conf)
// Returns ({port_obj, url_data}) for a url that matches the given
// one. url_data is the mapping for the url in port_obj->urls. If
// only_this_conf is given then only ports for that configuration are
// searched.
{
  // Cannot use the uri formatter in Standards.URI here since we
  // always want the port number to be present.
  string host = url->host;
  if (has_value (host, ":"))
    host = "[" + (Protocols.IPv6.normalize_addr_basic (host) || host) + "]";
  string url_with_port = sprintf ("%s://%s:%d%s", url->scheme, host, url->port,
				  sizeof (url->path) ? url->path : "/");

  URL2CONF_MSG("URL with port: %s\n", url_with_port);

  foreach (urls; string u; mapping(string:mixed) q)
  {
    URL2CONF_MSG("Trying %O:%O\n", u, q);
    if( glob( u+"*", url_with_port ) )
    {
      URL2CONF_MSG("glob match\n");
      if (Protocol p = q->port)
	if (mapping(string:mixed) url_data =
	    p->find_url_data_for_url (url_with_port, 0, 0))
	{
	  Configuration c = url_data->conf;
	  URL2CONF_MSG("Found config: %O\n", url_data->conf);

	  if ((only_this_conf && (c != only_this_conf)) ||
	      (sscanf (u, "%*s://%*[^*?]%*c") == 3 && // u contains * or ?.
	       // u is something like "http://*:80/"
	       (!host_is_local(url->host)))) {
	    // Bad match.
	    URL2CONF_MSG("Bad match: only_this_conf:%O, host_is_local:%O\n",
			 (only_this_conf && (c == only_this_conf)),
			 (!host_is_local(url->host)));
	    c = 0;
	    continue;
	  }

	  URL2CONF_MSG("Result: %O\n", c);
	  return ({p, url_data});
	}
    }
  }

  return ({0, 0});
}

Configuration find_configuration_for_url(Standards.URI url,
					 void|Configuration only_this_conf,
					 void|array(Protocol) return_port)
//! Tries to to determine if a request for the given url would end up
//! in this server, and if so returns the corresponding configuration.
//!
//! If @[only_this_conf] has been specified only matches against it
//! will be returned.
{
  [Protocol port_obj, mapping(string:mixed) url_data] =
    find_port_for_url (url, only_this_conf);
  if (return_port)
    return_port[0] = port_obj;
  return url_data && url_data->conf;
}

class InternalRequestID
//! ID for internal requests that are not linked to any real request.
{
  inherit RequestID;

  this_program set_path( string f )
  {
    raw_url = Roxen.http_encode_invalids( f );

    if( strlen( f ) > 5 )
    {
      string a;
      switch( f[1] )
      {
	case '<':
	  if (sscanf(f, "/<%s>/%s", a, f)==2)
	  {
	    config = (multiset)(a/",");
	    f = "/"+f;
	  }
	  // intentional fall-through
	case '(':
	  if(strlen(f) && sscanf(f, "/(%s)/%s", a, f)==2)
	  {
	    prestate = (multiset)( a/","-({""}) );
	    f = "/"+f;
	  }
      }
    }
    not_query = Roxen.simplify_path( scan_for_query( f ) );
    return this;
  }

  this_program set_url( string url )
  {
    object uri = Standards.URI(url);
    prot = upper_case(uri->scheme);
    misc->host = uri->host;
    if ((prot == "HTTP" && uri->port != 80) ||
	(prot == "HTTPS" && uri->port != 443))
      misc->host += ":" + uri->port;
    string path = uri->path;
    raw_url = path;
    method = "GET";
    raw = "GET " + raw_url + " HTTP/1.1\r\n\r\n";
    [port_obj, mapping(string:mixed) url_data] = find_port_for_url (uri, 0);
    if (url_data) {
      conf = url_data->conf;
      if (!conf->inited) conf->enable_all_modules();
      if (string config_path = url_data->path)
	adjust_for_config_path (config_path);
    }
    return set_path( raw_url );
  }

  protected string _sprintf()
  {
    return sprintf("InternalRequestID(conf=%O; not_query=%O)", conf, not_query );
  }

  protected void create()
  {
    client = ({ "Roxen" });
    prot = "INTERNAL";
    method = "GET";
    real_variables = ([]);
    variables = FakedVariables( real_variables );
    root_id = this_object();

    misc = ([ "pref_languages": PrefLanguages(),
	      "cacheable": INITIAL_CACHEABLE,
    ]);
    connection_misc = ([]);
    cookies = CookieJar();
    throttle = ([]);
    client_var = ([]);
    request_headers = ([]);
    prestate = (<>);
    config = (<>);
    supports = (<>);
    pragma = (<>);
    rest_query = "";
    extra_extension = "";
    remoteaddr = "127.0.0.1";
  }
}

class Protocol
//! The basic protocol.
//! Implements reference handling, finding Configuration objects
//! for URLs, and the bind/accept handling.
{
  protected Stdio.Port port_obj;

  inherit "basic_defvar";

  int bound;
  //! 0 if the port isn't bound, 1 if it is, and -1 if it binding it
  //! failed with EADDRINUSE when told to ignore that error.
  //!
  //! @note
  //! The -1 state should be uncommon since @[register_url] should
  //! remove such objects after the failed bind attempt.

  string path;
  constant name = "unknown";

  constant supports_ipless = 0;
  //! If true, the protocol handles ip-less virtual hosting

  constant requesthandlerfile = "";
  //! Filename of a by-connection handling class. It is also possible
  //! to set the 'requesthandler' class member in a overloaded create
  //! function.

  constant default_port = 4711;
  //! If no port is specified in the URL, use this one

  string url_prefix = name + "://";

  int port;
  //! The currently bound portnumber

  string ip;
  //! The canonical IP-number (0 for ANY) this port is bound to.
  //!
  //! IPv6 numbers are in colon separated four-digit lower-case hexadecimal
  //! notation with the first longest sequence of zeros compressed.

  int refs;
  //! The number of references to this port. This is the same as the
  //! size of @[urls] and @[sorted_urls].

  program requesthandler;
  //! The per-connection request handling class

  array(string) sorted_urls = ({});
  //! Sorted by length, longest first

  mapping(string:mapping(string:mixed)) urls = ([]);
  //! .. url -> ([ "conf":.., ... ])
  //!
  //! Indexed by URL. The following data is stored:
  //! @mapping
  //!   @member Configuration "conf"
  //!     The Configuration object for this URL.
  //!   @member string "hostname"
  //!     The hostname from the URL.
  //!   @member string|void "path"
  //!     The path (if any) from the URL.
  //!   @member Protocol "port"
  //!     The protocol handler for this URL.
  //!   @member int "mib_version"
  //!     (Only SNMP). The version number for the configuration MIB
  //!     tree when it was last merged.
  //! @endmapping

  mapping(Configuration:mapping(string:mixed)) conf_data = ([]);
  //! Maps the configuration objects to the data mappings in @[urls].

  void ref(string name, mapping(string:mixed) data)
  //! Add a ref for the URL @[name] with the data @[data].
  //!
  //! See @[urls] for documentation about the supported
  //! fields in @[data].
  {
    if(urls[name])
    {
      conf_data[urls[name]->conf] = urls[name] = data;
      return; // only ref once per URL
    }
    if (!refs) path = data->path;
    else if (path != (data->path || "")) path = 0;
    refs++;
    mu = 0;
    conf_data[data->conf] = urls[name] = data;
    sorted_urls = Array.sort_array(indices(urls),
                                 lambda(string a, string b) {
                                   return sizeof(a)<sizeof(b);
                                 });
  }

  void unref(string _name)
  //! Remove a ref for the URL '_name'
  {
//     if(!urls[name]) // only unref once
//       return;

    m_delete(conf_data, urls[_name]->conf);
    m_delete(urls, _name);
    if (!path) {
      array(string) paths = Array.uniq (values (urls)->path);
      if (sizeof (paths) == 1) path = paths[0];
    }
    sorted_urls -= ({_name});
#ifdef PORT_DEBUG
    report_debug("Protocol(%s)->unref(%O): refs:%d\n",
		 get_url(), _name, refs);
#endif /* PORT_DEBUG */
    if( !--refs ) {
      if (retries) {
	remove_call_out(bind);
      }
      if (port_obj) {
	destruct(port_obj);
      }
      port_obj = 0;
      if (open_ports[name]) {
	if (open_ports[name][ip]) {
	  m_delete(open_ports[name][ip], port);
	  if(!sizeof(open_ports[name][ip])) {
	    // Make sure the entries for IPv4 and IPv6 ANY are left alone.
	    if (ip && ip != "::")
	      m_delete(open_ports[name], ip);
	  }
	}
	if (sizeof(open_ports[name]) <= 2) {
	  // Only ANY left.
	  int empty = 1;
	  foreach(open_ports[name]; string ip; mapping m) {
	    if (sizeof(m)) {
	      empty = 0;
	      break;
	    }
	  }
	  if (empty)
	    m_delete(open_ports, name);
	}
      }
      any_port = 0;		// Avoid possibly cyclic ref.
      //destruct( ); // Close the port.
    }
  }

  Stdio.File accept()
  {
    return port_obj->accept();
  }

  string query_address()
  {
    return port_obj && port_obj->query_address();
  }

  mapping(string:mixed) mu;
  string rrhf;
  protected void got_connection()
  {
    Stdio.File q;
    while( q = accept() )
    {
      if( !requesthandler && rrhf )
      {
	requesthandler = (program)(rrhf);
      }
      Configuration c;
      if( refs < 2 )
      {
        if(!mu) 
        {
	  mu = get_iterator(urls)->value();
	  if(!(c=mu->conf)->inited ) {
	    handle (lambda () {
		      c->enable_all_modules();
		      call_out (lambda ()
				{
				  // The connection might have been
				  // closed already, e.g. by
				  // http_fallback.ssl_alert_callback()
				  // (prot_https.pike). Avoid a
				  // backtrace in that case.
				  if (q->is_open())
				    requesthandler (q, this, c);
				}, 0);
		    });
	    return;
	  }
        } else
          c = mu->conf;
      }
      requesthandler( q, this_object(), c );
    }
  }

  private Protocol any_port;

  mapping(string:mixed) find_url_data_for_url (string url, int no_default,
					       RequestID id)
  {
    if( refs == 1 )
    {
      if (!no_default) {
	if(!mu) mu=get_iterator(urls)->value();
	URL2CONF_MSG ("%O %O Only one configuration: %O\n",
		      this, url, mu->conf);
	return mu;
      }
    } else if (!refs) {
      URL2CONF_MSG("%O %O No active URLS!\n", this, url);
      return 0;
    }

    URL2CONF_MSG("sorted_urls: %O\n"
		 "url: %O\n", sorted_urls, url);
    // The URLs are sorted from longest to shortest, so that short
    // urls (such as http://*/) will not match before more complete
    // ones (such as http://*.roxen.com/)
    foreach( sorted_urls, string in )
    {
      if( glob( in+"*", url ) )
      {
	URL2CONF_MSG ("%O %O sorted_urls: %O\n", this, url, urls[in]->conf);
	return urls[in];
      }
    }
    
    if( no_default ) {
      URL2CONF_MSG ("%O %O no default\n", this, url);
      return 0;
    }

    // Note: The docs for RequestID.misc->default_conf has a
    // description of this fallback procedure.

    // No host matched, or no host header was included in the request.
    // Is the URL in the '*' ports?
    if (!any_port)
      any_port = open_ports[ name ][ 0 ][ port ];
    if (any_port && any_port != this)
      if (mapping(string:mixed) u =
	  any_port->find_url_data_for_url (url, 1, id)) {
	URL2CONF_MSG ("%O %O found on ANY port: %O\n", this, url, u->conf);
	if (id) {
	  id->misc->defaulted_conf = 1;
	  id->port_obj = any_port;
	}
	return u;
      }
    
    // No. We have to default to one of the other ports.
    // It might be that one of the servers is tagged as a default server.
    mapping(Configuration:int(1..1)) choices = ([]);
    foreach( configurations, Configuration c )
      if( c->query( "default_server" ) )
	choices[c] = 1;
    
    if( sizeof( choices ) )
    {
      // Pick a default server bound to this port
      foreach (urls;; mapping cc)
	if( choices[ cc->conf ] )
	{
	  URL2CONF_MSG ("%O %O conf in choices: %O\n", this, url, cc->conf);
	  if (id) id->misc->defaulted_conf = 2;
	  return cc;
	}
    }

    return 0;
  }

  Configuration find_configuration_for_url( string url, RequestID id )
  //! Given a url and requestid, try to locate a suitable configuration
  //! (virtual site) for the request. 
  //! This interface is not at all set in stone, and might change at 
  //! any time.
  {
    mapping(string:mixed) url_data = find_url_data_for_url (url, 0, id);

    if (!url_data) {
      // Pick the first default server available. FIXME: This makes
      // it impossible to handle the server path correctly.
      foreach (configurations, Configuration c)
	if (c->query ("default_server")) {
	  URL2CONF_MSG ("%O %O any default server: %O\n", this, url, c);
	  if (id) id->misc->defaulted_conf = 3;
	  if(!c->inited)
	    // FIXME: We can be called from the backend thread, so
	    // this should be queued for a handler thread.
	    c->enable_all_modules();
	  return c;
	}

      // if we end up here, there is no default port at all available
      // so grab the first configuration that is available at all.
      // We choose the last entry in sorted_urls since that's the most
      // generic one and therefore probably the best option for a
      // fallback.
      url_data = urls[sorted_urls[-1]];
      if (id) {
	id->misc->defaulted_conf = 4;
	id->misc->defaulted=1;	// Compat.
      }
      URL2CONF_MSG ("%O %O last in sorted_urls: %O\n", this, url,
		    url_data->conf);
    }

    // It's assumed nothing below uses data in this object, since
    // find_url_data_for_url might have switched Protocol object.

    string config_path = url_data->path;
    if (config_path && id && id->adjust_for_config_path)
      id->adjust_for_config_path (config_path);
    Configuration c = url_data->conf;
    if(!c->inited)
      // FIXME: We can be called from the backend thread, so this
      // should be queued for a handler thread.
      c->enable_all_modules();
    return c;
  }

  mixed query_option( string x )
  //! Query the port-option 'x' for this port. 
  {
    return query( x );
  }

  string get_key()
  //! Return the key used for this port (protocol:ip:portno)
  {
#if 0
    if (ip == "::")
      return name + ":0:" + port;
    else
#endif
      return name+":"+ip+":"+port;
  }

  string get_url()
  //! Return the port on URL form.
  {
    return (string) name + "://" +
      (!ip ? "*" : has_value (ip, ":") ? "[" + ip + "]" : ip) +
      ":" + port + "/";
  }

  void save()
  //! Save all port options
  {
    set_port_options( get_key(),
                      mkmapping( indices(variables),
                                 map(indices(variables),query)));
  }

  void restore()
  //! Restore all port options from saved values
  {
    foreach( (array)get_port_options( get_key() ),  array kv )
      set( kv[0], kv[1] );
  }

  protected int retries;
  protected void bind (void|int ignore_eaddrinuse)
  {
    if (bound) return;
    if (!port_obj) port_obj = Stdio.Port();
    Privs privs = Privs (sprintf ("Binding %s", get_url()));
    if (port_obj->bind(port, got_connection, ip))
    {
      privs = 0;
      bound = 1;
      return;
    }
    privs = 0;
#if constant(System.EAFNOSUPPORT)
    if (port_obj->errno() == System.EAFNOSUPPORT) {
      // Fail permanently.
      error("Invalid address " + ip);
    }
#endif /* System.EAFNOSUPPORT */
#if constant(System.EADDRINUSE)
    if (port_obj->errno() == System.EADDRINUSE) {
      if (ignore_eaddrinuse) {
	// Told to ignore the bind problem.
	bound = -1;
	return;
      }
      if (retries++ < 10) {
	// We may get spurious failures on rebinding ports on some OS'es
	// (eg Linux, WIN32). See [bug 3031].
	report_error(LOC_M(6, "Failed to bind %s (%s)")+"\n",
		     get_url(), strerror(port_obj->errno()));
	report_notice(LOC_M(62, "Attempt %d. Retrying in 1 minute.")+"\n",
		      retries);
	call_out(bind, 60);
      }
    }
    else
#endif /* constant(System.EADDRINUSE) */
    {
      report_error(LOC_M(6, "Failed to bind %s (%s)")+"\n",
		   get_url(), strerror(port_obj->errno()));
#if 0
      werror (describe_backtrace (backtrace()));
#endif
    }
  }

  string canonical_ip(string i)
  {
    if (!i) return 0;
    if (has_value(i, ":"))
      return Protocols.IPv6.normalize_addr_short (i);
    else {
      // IPv4
      array(int) segments = array_sscanf(i, "%d.%d.%d.%d");
      string bytes;
      switch(sizeof(segments)) {
      default:
      case 4:
	bytes = sprintf("%1c%1c%1c%1c", @segments);
	break;
      case 0: return 0;	// ANY.
      case 1:
	/* When only one part is given, the value is stored directly in
	 * the network address without any byte rearrangement.
	 */
	bytes = sprintf("%4c", @segments);
	break;
      case 2:
	/* When a two part address is supplied, the last part is inter-
	 * preted  as  a  24-bit  quantity and placed in the right most
	 * three bytes of the network address. This makes the two  part
	 * address  format  convenient  for  specifying Class A network
	 * addresses as  net.host.
	 */
	bytes = sprintf("%1c%3c", @segments);
	break;
      case 3:
	/* When a three part address is specified,  the  last  part  is
	 * interpreted  as  a  16-bit  quantity and placed in the right
	 * most two bytes of the network address. This makes the  three
	 * part  address  format convenient for specifying Class B net-
	 * work addresses as  128.net.host.
	 */
	bytes = sprintf("%1c%1c%2c", @segments);
	break;
      }
      if (bytes == "\0\0\0\0") return 0;	// ANY.
      return sprintf("%d.%d.%d.%d", @((array(int))bytes));
    }
  }

  protected void setup (int pn, string i)
  {
    port = pn;
    ip = canonical_ip(i);

    restore();
    if (sizeof(requesthandlerfile)) {
      if( file_stat( "../local/"+requesthandlerfile ) )
	rrhf = "../local/"+requesthandlerfile;
      else
	rrhf = requesthandlerfile;
      DDUMP( rrhf );
#ifdef DEBUG
      if( !requesthandler )
	requesthandler = (program)(rrhf);
#endif
    }
    bound = 0;
    port_obj = 0;
    retries = 0;
  }

  protected void create( int pn, string i, void|int ignore_eaddrinuse )
  //! Constructor. Bind to the port 'pn' ip 'i'
  {
    setup (pn, i);
    bind (ignore_eaddrinuse);
  }

  protected string _sprintf( )
  {
    return "Protocol(" + get_url() + ")";
  }
}

#if constant(SSL.File)

class SSLContext {
#if constant(SSL.Context)
  inherit SSL.Context;

#if defined(DEBUG) || defined(SSL3_DEBUG)
  SSL.Alert alert_factory(SSL.Connection con, int level, int description,
			  SSL.Constants.ProtocolVersion version,
			  string|void debug_message)
  {
    if (description != SSL.Constants.ALERT_close_notify) {
      if (debug_message) {
	werror("SSL %s: %s: %s",
	       (level == SSL.Constants.ALERT_warning)?
	       "WARNING":"ERROR",
	       SSL.Constants.fmt_constant(description, "ALERT"),
	       debug_message);
      } else {
	werror("SSL %s: %s\n",
	       (level == SSL.Constants.ALERT_warning)?
	       "WARNING":"ERROR",
	       SSL.Constants.fmt_constant(description, "ALERT"));
      }
    }
    return ::alert_factory(con, level, description, version, debug_message);
  }
#endif /* DEBUG || SSL3_DEBUG */

#else
  inherit SSL.context;
#endif
}

class SSLProtocol
//! Base protocol for SSL ports. Exactly like Port, but uses SSL.
{
  inherit Protocol;

  // SSL context
  SSLContext ctx = SSLContext();

  int cert_failure;

  protected void cert_err_unbind()
  {
    if (bound > 0) {
      port_obj->close();
      report_warning ("TLS port %s closed.\n", get_url());
      bound = 0;
    }
  }

#define CERT_WARNING(VAR, MSG, ARGS...) do {				\
    string msg = (MSG);							\
    array args = ({ARGS});						\
    if (sizeof (args)) msg = sprintf (msg, @args);			\
    report_warning ("TLS port %s: %s", get_url(), msg);			\
    (VAR)->add_warning (msg);						\
  } while (0)

#define CERT_ERROR(VAR, MSG, ARGS...) do {				\
    string msg = (MSG);							\
    array args = ({ARGS});						\
    if (sizeof (args)) msg = sprintf (msg, @args);			\
    report_error ("TLS port %s: %s", get_url(), msg);			\
    (VAR)->add_warning (msg);						\
    cert_err_unbind();							\
    cert_failure = 1;							\
    return;								\
  } while (0)

#if constant(SSL.ServerConnection)
  protected void set_version()
  {
    ctx->min_version = query("ssl_min_version");
  }
#endif

  protected void filter_preferred_suites()
  {
#if constant(SSL.ServerConnection)
    int mode = query("ssl_suite_filter");
    int bits = query("ssl_key_bits");

    array(int) suites = ({});

    if ((mode & 8) && !ctx->configure_suite_b) {
      // FIXME: Warn: Suite B suites not available.
      mode &= ~8;
    }

    if ((mode & 8) && ctx->configure_suite_b) {
      // Suite B.
      switch(mode) {
      case 15:
	// Strict mode.
	ctx->configure_suite_b(bits, 2);
	break;
      case 14:
	// Transitional mode.
	ctx->configure_suite_b(bits, 1);
	break;
      default:
	ctx->configure_suite_b(bits);
	break;
      }
      suites = ctx->preferred_suites;

      if (ctx->min_version < query("ssl_min_version")) {
	set_version();
      }
    } else {
      suites = ctx->get_suites(bits, 1);

      // Make sure the min version is restored in case we've
      // switched from Suite B.
      set_version();
    }
    if (mode & 4) {
      // Ephemeral suites only.
      suites = filter(suites,
		      lambda(int suite) {
			return (<
			  SSL.Constants.KE_dhe_dss,
			  SSL.Constants.KE_dhe_rsa,
			  SSL.Constants.KE_ecdhe_ecdsa,
			  SSL.Constants.KE_ecdhe_rsa,
			>)[(SSL.Constants.CIPHER_SUITES[suite]||({ -1 }))[0]];
		      });
    }
    ctx->preferred_suites = suites;
#else
#ifndef ALLOW_WEAK_SSL
    // Filter weak and really weak cipher suites.
    ctx->preferred_suites -= ({
      SSL.Constants.SSL_rsa_with_des_cbc_sha,
      SSL.Constants.SSL_dhe_dss_with_des_cbc_sha,
      SSL.Constants.SSL_rsa_export_with_rc4_40_md5,
      SSL.Constants.TLS_rsa_with_null_sha256,
      SSL.Constants.SSL_rsa_with_null_sha,
      SSL.Constants.SSL_rsa_with_null_md5,
      SSL.Constants.SSL_dhe_dss_export_with_des40_cbc_sha,
      SSL.Constants.SSL_null_with_null_null,
    });
#endif
#endif /* SSL.ServerConnection */
  }

#if constant(Standards.X509)
  void certificates_changed(Variable.Variable|void ignored,
			    void|int ignore_eaddrinuse)
  {
    int old_cert_failure = cert_failure;
    cert_failure = 0;

    array(string) certificates = ({});
    array(object) decoded_certs = ({});
    array(object) decoded_keys = ({});

    void handle_pem_file(string pem_file, Variable.Variable conf_var)
    {
      string raw_cert;
      SSL3_WERR (sprintf ("Reading PEM file %O\n", pem_file));
      if( catch{ raw_cert = lopen(pem_file, "r")->read(); } )
      {
	CERT_WARNING (conf_var,
		      LOC_M(8, "Reading PEM file %O failed: %s\n"),
		      pem_file, strerror (errno()));
	return;
      }

      Standards.PEM.Messages msgs = Standards.PEM.Messages(raw_cert);

      foreach(msgs->fragments, string|Standards.PEM.Message msg) {
	if (stringp(msg)) {
	  if (String.trim_all_whites(msg) != "") {
	    CERT_WARNING(conf_var,
			 LOC_M(0, "Invalid PEM in %O.\n"),
			 pem_file);
	  }
	  continue;
	}
	string body = msg->body;
	if (msg->headers["dek-info"]) {
	  mixed err = catch {
	      body = Standards.PEM.decrypt_body(msg->headers["dek-info"],
						body, query("ssl_password"));
	    };
	  if (err) {
	    CERT_WARNING(conf_var,
			 LOC_M(0, "Invalid decryption password for %O.\n"),
			 pem_file);
	  }
	}
	switch(msg->pre) {
	case "CERTIFICATE":
	case "X509 CERTIFICATE":
	  Standards.X509.TBSCertificate tbs =
	    Standards.X509.decode_certificate(body);
	  if (!tbs) {
	    CERT_WARNING (conf_var,
			  LOC_M(13, "Certificate not valid (DER).\n"));
	    return;
	  }
	  certificates += ({ body });
	  decoded_certs += ({ Standards.X509.decode_certificate(body) });
	  break;
	case "PRIVATE KEY":
	case "RSA PRIVATE KEY":
	case "DSA PRIVATE KEY":
	case "ECDSA PRIVATE KEY":
	  Crypto.Sign key = Standards.X509.parse_private_key(body);
	  if (!key) {
	    CERT_ERROR (conf_var,
			LOC_M(11,"Private key not valid")+" (DER).\n");
	    return;
	  }
	  decoded_keys += ({ key });
	  break;
	}
      }
    };

    Variable.Variable Certificates = getvar("ssl_cert_file");
    Variable.Variable KeyFile = getvar("ssl_key_file");

    object privs = Privs("Reading cert file");

    foreach(map(Certificates->query(), String.trim_whites), string cert_file) {
      if (cert_file == "") continue;
      handle_pem_file(cert_file, Certificates);
    }

    string key_file = String.trim_whites(KeyFile->query());
    if (key_file != "") {
      handle_pem_file(key_file, KeyFile);
    } else {
      KeyFile = Certificates;
    }

    privs = 0;

    if (!sizeof(decoded_certs)) {
      CERT_ERROR(Certificates, LOC_M(63,"No certificates found.\n"));
      report_error ("TLS port %s: %s", get_url(),
		    LOC_M(63,"No certificates found.\n"));
      cert_err_unbind();
      cert_failure = 1;
      return;
    }

    if (!sizeof(decoded_keys)) {
      CERT_ERROR (KeyFile, LOC_M (17,"No private key found.\n"));
      report_error ("TLS port %s: %s", get_url(),
		    LOC_M (17,"No private key found.\n"));
      cert_err_unbind();
      cert_failure = 1;
      return;
    }

    // FIXME: Only do this if there are certs loaded?
    // We must reset the set of certificates.
    ctx = SSLContext();
    set_version();
    filter_preferred_suites();

    mapping(string:array(int)) cert_lookup = ([]);
    foreach(decoded_certs; int no; Standards.X509.TBSCertificate tbs) {
      cert_lookup[tbs->subject->get_der()] += ({ no });
    }

    foreach(decoded_keys, Crypto.Sign key) {
      // NB: We need to support multiple certificates with the same key.
      int found;
      Standards.X509.TBSCertificate tbs;
      foreach(decoded_certs; int no; tbs) {
	if (!tbs->public_key->pkc->public_key_equal(key))
	  continue;

	array(int) cert_nos = ({ no });

	// Build the certificate chain.
	Standards.X509.TBSCertificate issuer;
	do {
	  string issuer_der = tbs->issuer->get_der();
	  array(int) issuer_nos = cert_lookup[issuer_der];
	  if (!issuer_nos) break;

	  issuer = decoded_certs[issuer_nos[0]];

	  // FIXME: Verify that the issuer has signed the cert.

	  if (issuer != tbs) {
	    cert_nos += ({ issuer_nos[0] });
	  } else {
	    // Self-signed.
	    issuer = UNDEFINED;
	    break;
	  }
	} while ((tbs = issuer));

	report_notice("Adding %s certificate (%d certs) for %s\n",
		      key->name(), sizeof(cert_nos), get_url());
	// FIXME: Ought to only add "*" for the certificate chains
	//        belonging to the default server.
	ctx->add_cert(key, rows(certificates, cert_nos), ({ name, "*" }));
	found = 1;
      }
      if (!found) {
	CERT_ERROR (KeyFile,
		    LOC_M(14, "Private key without matching certificate.\n"));
	continue;
      }
    }

#if 0
    // FIXME: How do this in current Pike 8.0?
    if (!sizeof(ctx->cert_pairs)) {
      CERT_ERROR(Certificates,
		 LOC_M(0,"No matching keys and certificates found.\n"));
      report_error ("TLS port %s: %s", get_url(),
		    LOC_M(0,"No matching keys and certificates found.\n"));
      cert_err_unbind();
      cert_failure = 1;
      return;
    }
#endif

    if (!bound) {
      bind (ignore_eaddrinuse);
      if (old_cert_failure && bound)
	report_notice (LOC_M(64, "TLS port %s opened.\n"), get_url());
      if (!bound)
	report_notice("Failed to bind port %s.\n", get_url());
    }
  }
#else
  // NB: The TBS Tools.X509 API has been deprecated in Pike 8.0.
#pragma no_deprecation_warnings
  void certificates_changed(Variable.Variable|void ignored,
			    void|int ignore_eaddrinuse)
  {
    int old_cert_failure = cert_failure;
    cert_failure = 0;

    string raw_keydata;
    array(string) certificates = ({});
    array(object) decoded_certs = ({});
    Variable.Variable Certificates = getvar("ssl_cert_file");

    object privs = Privs("Reading cert file");

    foreach(map(Certificates->query(), String.trim_whites), string cert_file) {
      string raw_cert;
      SSL3_WERR (sprintf ("Reading cert file %O", cert_file));
      if( catch{ raw_cert = lopen(cert_file, "r")->read(); } )
      {
	CERT_WARNING (Certificates,
		      LOC_M(8, "Reading certificate file %O failed: %s\n"),
		      cert_file, strerror (errno()));
	continue;
      }

      object msg = Tools.PEM.pem_msg()->init( raw_cert );
      object part = msg->parts["CERTIFICATE"] ||
	msg->parts["X509 CERTIFICATE"];
      string cert;

      if (msg->parts["RSA PRIVATE KEY"] ||
	  msg->parts["DSA PRIVATE KEY"]) {
	raw_keydata = raw_cert;
      }

      if (!part || !(cert = part->decoded_body())) 
      {
	CERT_WARNING (Certificates,
		      LOC_M(10, "No certificate found in %O.\n"),
		      cert_file);
	continue;
      }
      certificates += ({ cert });

      // FIXME: Support PKCS7
      object tbs = Tools.X509.decode_certificate (cert);
      if (!tbs) {
	CERT_WARNING (Certificates,
		      LOC_M(13, "Certificate not valid (DER).\n"));
	continue;
      }
      decoded_certs += ({tbs});
    }

    if (!sizeof(decoded_certs)) {
      report_error ("TLS port %s: %s", get_url(),
		    LOC_M(63,"No certificates found.\n"));
      cert_err_unbind();
      cert_failure = 1;
      return;
    }

    Variable.Variable KeyFile = getvar("ssl_key_file");

    if( strlen(KeyFile->query())) {
      SSL3_WERR (sprintf ("Reading key file %O", KeyFile->query()));
      if (catch{ raw_keydata = lopen(KeyFile->query(), "r")->read(); } )
	CERT_ERROR (KeyFile,
		    LOC_M(9, "Reading key file %O failed: %s\n"),
		    KeyFile->query(), strerror (errno()));
    }
    else
      KeyFile = Certificates;

    privs = 0;

    if (!raw_keydata)
      CERT_ERROR (KeyFile, LOC_M (17,"No private key found.\n"));

    object msg = Tools.PEM.pem_msg()->init( raw_keydata );

    SSL3_WERR(sprintf("key file contains: %O", indices(msg->parts)));

    object part;
    if (part = msg->parts["RSA PRIVATE KEY"])
    {
      string key;

      if (!(key = part->decoded_body()))
	CERT_ERROR (KeyFile,
		    LOC_M(11,"Private rsa key not valid")+" (PEM).\n");

      object rsa = Standards.PKCS.RSA.parse_private_key(key);
      if (!rsa)
	CERT_ERROR (KeyFile,
		    LOC_M(11,"Private rsa key not valid")+" (DER).\n");

      ctx->rsa = rsa;

      SSL3_WERR(sprintf("RSA key size: %d bits", rsa->rsa_size()));

      if (rsa->rsa_size() > 512)
      {
	/* Too large for export */
	ctx->short_rsa = Crypto.RSA()->generate_key(512, ctx->random);

	// ctx->long_rsa = Crypto.RSA()->generate_key(rsa->rsa_size(), ctx->random);
      }
      ctx->rsa_mode();
      filter_preferred_suites();

      array(int) key_matches =
	map(decoded_certs,
	    lambda (object tbs) {
	      return tbs->public_key->rsa->public_key_equal (rsa);
	    });
      
      int num_key_matches;
      // DWIM: Make sure the main cert comes first.
      array(string) new_certificates = allocate(sizeof(certificates));
      int i,j;
      for (i=0; i < sizeof(certificates); i++) {
	if (key_matches[i]) {
	  new_certificates[j++] = certificates[i];
	  num_key_matches++;
	}
      }
      for (i=0; i < sizeof(certificates); i++) {
	if (!key_matches[i]) {
	  new_certificates[j++] = certificates[i];
	}
      }
      if( !num_key_matches )
	CERT_ERROR (KeyFile,
		    LOC_M(14, "Certificate and private key do not match.\n"));
      ctx->certificates = new_certificates;
    }
    else if (part = msg->parts["DSA PRIVATE KEY"])
    {
      string key;

      if (!(key = part->decoded_body()))
	CERT_ERROR (KeyFile,
		    LOC_M(15,"Private dsa key not valid")+" (PEM).\n");

      object dsa = Standards.PKCS.DSA.parse_private_key(key);
      if (!dsa)
	CERT_ERROR (KeyFile,
		    LOC_M(15,"Private dsa key not valid")+" (DER).\n");

      SSL3_WERR(sprintf("Using DSA key."));

      //dsa->use_random(ctx->random);
      ctx->dsa = dsa;
      /* Use default DH parameters */
#if constant(SSL.cipher)
      ctx->dh_params = SSL.cipher()->dh_parameters();
#endif

      ctx->dhe_dss_mode();
      filter_preferred_suites();

      // FIXME: Add cert <-> private key check.

      ctx->certificates = certificates;
    }
    else
      CERT_ERROR (KeyFile, LOC_M(17,"No private key found.\n"));

#if EXPORT
    ctx->export_mode();
#endif

    if (!bound) {
      bind (ignore_eaddrinuse);
      if (old_cert_failure && bound)
	report_notice (LOC_M(64, "TLS port %s opened.\n"), get_url());
    }
  }
#pragma deprecation_warnings
#endif /* Tools.X509 */

  class CertificateListVariable
  {
    inherit Variable.FileList;

    string doc()
    {
      return sprintf(::doc() + "\n",
		     combine_path(getcwd(), "../local"),
		     getcwd());
    }
  }

  class KeyFileVariable
  {
    inherit Variable.String;

    string doc()
    {
      return sprintf(::doc() + "\n",
		     combine_path(getcwd(), "../local"),
		     getcwd());
    }
  }

  SSL.File accept()
  {
    Stdio.File q = ::accept();
    if (q) {
      SSL.File ssl = SSL.File(q, ctx);
      ssl->accept();
      return ssl;
    }
    return 0;
  }

#if constant(SSL.Connection)
  protected void bind (void|int ignore_eaddrinuse)
  {
    // Don't bind if we don't have correct certs.
    // if (!sizeof(ctx->cert_pairs)) return;
    ::bind (ignore_eaddrinuse);
  }
#else
  protected void bind (void|int ignore_eaddrinuse)
  {
    // Don't bind if we don't have correct certs.
    if (!ctx->certificates) return;
    ::bind (ignore_eaddrinuse);
  }
#endif

  void create(int pn, string i, void|int ignore_eaddrinuse)
  {
    ctx->random = Crypto.Random.random_string;

    set_up_ssl_variables( this_object() );

    filter_preferred_suites();

    ::setup(pn, i);

    certificates_changed (0, ignore_eaddrinuse);

    // Install the change callbacks here to avoid duplicate calls
    // above.
    // FIXME: Both variables ought to be updated on save before the
    //        changed callback is called. Currently you can get warnings
    //        that the files don't match if you update both variables
    //        at the same time.
    getvar ("ssl_cert_file")->set_changed_callback (certificates_changed);
    getvar ("ssl_key_file")->set_changed_callback (certificates_changed);

#if constant(SSL.ServerConnection)
    getvar("ssl_key_bits")->set_changed_callback(filter_preferred_suites);
    getvar("ssl_suite_filter")->set_changed_callback(filter_preferred_suites);
    getvar("ssl_min_version")->set_changed_callback(set_version);
#endif
  }

  string _sprintf( )
  {
    return "SSLProtocol(" + get_url() + ")";
  }
}
#endif

mapping(string:program/*(Protocol)*/) build_protocols_mapping()
{
  mapping protocols = ([]);
  int st = gethrtime();
  report_debug("Protocol handlers ... \b");
#ifndef DEBUG
  class lazy_load( string prog, string name )
  {
    program real;
    protected void realize()
    {
      if( catch {
	DDUMP( prog );
	real = (program)prog;
	protocols[name] = real;
      } )
	report_error("Failed to compile protocol handler for "+name+"\n");
    }

    Protocol `()(mixed ... x)
    {
      if(!real) realize();
      return real(@x);
    };
    mixed `->( string x )
    {
      if(!real) realize();
      return predef::`->(real, x);
    }
  };
#endif
  foreach( glob( "prot_*.pike", get_dir("protocols") ), string s )
  {
    sscanf( s, "prot_%s.pike", s );
#if !constant(SSL.File)
    switch( s )
    {
      case "https":
      case "ftps":
	continue;
    }
#endif
    report_debug( "\b%s \b", s );

    catch
    {
#ifdef DEBUG
      protocols[ s ] = (program)("protocols/prot_"+s+".pike");
#else
      protocols[ s ] = lazy_load( ("protocols/prot_"+s+".pike"),s );
#endif
    };
  }
  foreach( glob("prot_*.pike",get_dir("../local/protocols")||({})), string s )
  {
    sscanf( s, "prot_%s.pike", s );
#if !constant(SSL.File)
    switch( s )
    {
      case "https":
      case "ftps":
	continue;
    }
#endif
    report_debug( "\b%s \b", s );
    catch {
#ifdef DEBUG
      protocols[ s ] = (program)("../local/protocols/prot_"+s+".pike");
#else
      protocols[ s ] = lazy_load( ("../local/protocols/prot_"+s+".pike"),s );
#endif
    };
  }
  report_debug("\bDone [%.1fms]\n", (gethrtime()-st)/1000.0 );
  return protocols;
}


mapping(string:program/*(Protocol)*/) protocols;

//! Lookup from protocol, IP number and port to
//! the corresponding open @[Protocol] port.
//!
//! @mapping
//!   @member mapping(string:mapping(int:Protocol)) protocol_name
//!     @mapping
//!       @member mapping(int:Protocol) ip_number
//!         @mapping
//!           @member Protocol port_number
//!             @[Protocol] object that holds this ip_number and port open.
//!         @endmapping
//!     @endmapping
//! @endmapping
mapping(string:mapping(string:mapping(int:Protocol))) open_ports = ([ ]);

//! Lookup from URL string to the corresponding open @[Protocol] ports.
//!
//! Note that there are two classes of URL strings used as indices in
//! this mapping:
//! @dl
//!   @item "prot://host_glob:port/path/"
//!     A normalized URL string as returned by @[normalize_url()].
//!
//!     @[Protocol()->ref()] in the contained ports as been called
//!     with the url.
//!
//!   @item "port://host_glob:port/path/#opt1=val1;opt2=val2"
//!     An URL string containing options as stored in the @tt{"URLs"@}
//!     configuration variable, and expected as argument by
//!     @[register_url()] and @[unregister_url()]. Also known
//!     as an ourl.
//! @enddl
//!
//! In both cases the same set of data is stored:
//! @mapping
//!   @member mapping(string:Configuration|Protocol|string|array(Protocol)|array(string)) url
//!     @mapping
//!       @member Protocol "port"
//!         Representative open port for this URL.
//!       @member array(Protocol) "ports"
//!         Array of all open ports for this URL.
//!       @member Configuration "conf"
//!         Configuration that has registered the URL.
//!       @member string "path"
//!         Path segment of the URL.
//!       @member string "host"
//!         Hostname segment of the URL.
//!       @member array(string) "skipped"
//!         List of IP numbers not bound due to a corresponding
//!         ANY port already being open.
//!     @endmapping
//! @endmapping
mapping(string:mapping(string:Configuration|Protocol|string|array(Protocol)|array(string)))
  urls = ([]);

array sorted_urls = ({});

array(string) find_ips_for( string what )
{
  if( what == "*" || lower_case(what) == "any" || has_value(what, "*") )
    return ({
#if constant(__ROXEN_SUPPORTS_IPV6__)
	      "::",
#endif /* __ROXEN_SUPPORTS_IPV6__ */
	      0,
    });	// ANY

  if( is_ip( what ) )
    return ({ what });
  else if (has_prefix (what, "[") && what[-1] == ']') {
    /* RFC 3986 3.2.2. Host
     *
     * host       = IP-literal / IPv4address / reg-name
     * IP-literal = "[" ( IPv6address / IPvFuture  ) "]"
     * IPvFuture  = "v" 1*HEXDIG "." 1*( unreserved / sub-delims / ":" )
     *
     * IPv6address is as in RFC3513.
     */
    return ({ what[1..sizeof(what)-2] });
  } else if (has_suffix(lower_case(what), ".ipv6")) {
    // draft-masinter-url-ipv6-00 3
    //
    //   a) replace every colon ":" with a "-"
    //   b) append ".ipv6" to the end.
    return ({ replace(what[..sizeof(what)-6], "-", ":") });
  } 
  array res = gethostbyname( what );
  if( res && sizeof( res[1] ) )
    return Array.uniq(res[1]);

  report_error(LOC_M(46, "Cannot possibly bind to %O, that host is "
		     "unknown. Substituting with ANY")+"\n", what);
  return 0;		// FAIL
}

string normalize_url(string url, void|int port_match_form)
//! Normalizes the given url to a short form.
//!
//! If @[port_match_form] is set, it normalizes to the form that is
//! used for port matching, i.e. what
//! @[roxen.Protocol.find_configuration_for_url] expects.
//!
//! @note
//!   Returns @expr{""@} for @[url]s that are incomplete.
{
  if (!sizeof (url - " " - "\t")) return "";

  Standards.URI ui = Standards.URI(url);
  string host = ui->host;

  if (lower_case (host) == "any" || host == "::")
    host = "*";
  else {
    // Note: zone_to_ascii() can throw errors on invalid hostnames.
    if (catch {
	// FIXME: Maybe Standards.URI should do this internally?
	host = lower_case(Standards.IDNA.zone_to_ascii (host));
      }) {
      host = lower_case(host);
    }
  }

  if (has_value (host, ":"))
    if (string h = port_match_form ?
	Protocols.IPv6.normalize_addr_basic (host) :
	Protocols.IPv6.normalize_addr_short (host)) {
      ui->host = h;
      host = "[" + h + "]";
    }

  string protocol = ui->scheme;
  if (host == "" || !protocols[protocol])
    return "";

  if (port_match_form) {
    int port = ui->port || protocols[protocol]->default_port;

    string path = ui->path;
    if (path) {
      if (has_suffix(path, "/"))
	path = path[..<1];
    }
    else
      path = "";

    return sprintf ("%s://%s:%d%s/", protocol, host, port,
		    // If the path is set it's assumed to begin with a
		    // "/", but not end with one.
		    path);
  }

  else {
    ui->fragment = 0;
    return (string) ui;
  }
}

//! Unregister an URL from a configuration.
//!
//! @seealso
//!   @[register_url()]
void unregister_url(string url, Configuration conf)
{
  string ourl = url;
  mapping(string:mixed) data = m_delete(urls, ourl);
  if (!data) return;	// URL not registered.
  if (!sizeof(url = normalize_url(url, 1))) return;

  report_debug ("Unregister %s%s.\n", normalize_url (ourl),
		conf ? sprintf (" for %O", conf->query_name()) : "");

  mapping(string:mixed) shared_data = urls[url];
  if (!shared_data) return;	// Strange case, but URL not registered.

  int was_any_ip;
  if (!data->skipped && data->port) {
    if (!data->port->ip || (data->port->ip == "::")) {
      was_any_ip = data->port->port;
      report_debug("Unregistering ANY port: %O:%d\n",
		   data->port->ip, data->port->port);
    }
  }

  foreach(data->ports || ({}), Protocol port) {
    shared_data->ports -= ({ port });
    port->unref(url);
    m_delete(shared_data, "port");
  }
  if (!sizeof(shared_data->ports || ({}))) {
    m_delete(urls, url);
  } else if (!shared_data->port) {
    shared_data->port = shared_data->ports[0];
  }
  sort_urls();

  if (was_any_ip) {
    foreach(urls; string url; mapping(string:mixed) url_info) {
      if (!url_info->skipped || !url_info->conf ||
	  (url_info->port && (url_info->port->port != was_any_ip))) {
	continue;
      }
      // Re-register the ports that may have bound to the removed ANY port.
      register_url(url, url_info->conf);
    }
  }
}

array all_ports( )
{
  // FIXME: Consider using open_ports instead.
  return Array.uniq( (values( urls )->ports - ({0})) * ({}) )-({0});
}

Protocol find_port( string name )
{
  foreach( all_ports(), Protocol p  )
    if( p->get_key() == name )
      return p;
}

void sort_urls()
{
  sorted_urls = indices( urls );
  sort( map( map( sorted_urls, strlen ), `-), sorted_urls );
}

//! Register an URL for a configuration.
//!
//! @seealso
//!   @[unregister_url()]
int register_url( string url, Configuration conf )
{
  string ourl = url;
  if (!sizeof (url - " " - "\t")) return 1;

  Standards.URI ui = Standards.URI(url);
  mapping opts = ([]);
  string a, b;
  foreach( (ui->fragment||"")/";", string x )
  {
    sscanf( x, "%s=%s", a, b );
    opts[a]=b;
  }

  if( (int)opts->nobind )
  {
    report_warning(
      LOC_M(61,"Not binding the port %O - disabled in configuration.")+"\n",
      (string) ui );
    return 0;
  }

  string display_url = normalize_url (url, 0);
  url = normalize_url (url, 1);
  if (url == "") return 1;
  ui = Standards.URI (url);

  string protocol = ui->scheme;
  string host = ui->host;
  if (host == "" || !protocols[protocol]) {
    report_error(LOC_M(19,"Bad URL %O for server %O.")+"\n",
		 ourl, conf->query_name());
  }

  int port = ui->port || protocols[protocol]->default_port;

  string path = ui->path;
  if (has_suffix(path, "/"))
    path = path[..<1];
  if (path == "") path = 0;

  if( urls[ url ]  )
  {
    if( !urls[ url ]->port )
      m_delete( urls, url );
    else if(  urls[ url ]->conf )
    {
      if( urls[ url ]->conf != conf )
      {
	report_error(LOC_M(20,
			   "Cannot register URL %s - "
			   "already registered by %s.")+"\n",
		     display_url, urls[ url ]->conf->name);
	return 0;
      }
      // FIXME: Is this correct?
      urls[ url ]->port->ref(url, urls[url]);
    }
    else
      urls[ url ]->port->unref( url );
  }

  program prot;

  if( !( prot = protocols[ protocol ] ) )
  {
    report_error(LOC_M(21, "Cannot register URL %s - "
			  "cannot find the protocol %s.")+"\n",
		 display_url, protocol);
    return 0;
  }

  // FIXME: Do we need to unref the old ports first in case of a reregister?
  urls[ ourl ] = ([ "conf":conf, "path":path, "hostname": host ]);
  if (!urls[url]) {
    urls[ url ] = urls[ourl] + ([]);
    sorted_urls += ({ url });	// FIXME: Not exactly sorted...
  }

  array(string)|int(-1..0) required_hosts;

  if (is_ip(host))
    required_hosts = ({ host });
  else if(!sizeof(required_hosts =
		  filter(replace(opts->ip||"", " ","")/",", is_ip)) ) {
    required_hosts = find_ips_for( host );
    if (!required_hosts) {
      // FIXME: Used to fallback to ANY.
      //        Will this work with glob URLs?
      return 0;
    }
  }

  mapping(string:mapping(int:Protocol)) m;
  if( !( m = open_ports[ protocol ] ) )
    // always add 'ANY' (0) and 'IPv6_ANY' (::) here, as empty mappings,
    // for speed reasons.
    // There is now no need to check for both open_ports[prot][0] and
    // open_ports[prot][0][port], we can go directly to the latter
    // test.
    m = open_ports[ protocol ] = ([ 0:([]), "::":([]) ]); 

  if (prot->supports_ipless ) {
    // Check if the ANY port is already open for this port, since this
    // protocol supports IP-less virtual hosting, there is no need to
    // open yet another port if it is, since that would most probably
    // only conflict with the ANY port anyway. (this is true on most
    // OSes, it works on Solaris, but fails on linux)
    array(string) ipv6 = filter(required_hosts - ({ 0 }), has_value, ":");
    array(string) ipv4 = required_hosts - ipv6;
    if (m[0][port] && sizeof(ipv4 - ({ 0 }))) {
      // We have a non-ANY IPv4 IP number.
      // Keep track of the ips in case the ANY port is removed.
      urls[ourl]->skipped = ipv4;
      ipv4 = ({ 0 });
    }
#if constant(__ROXEN_SUPPORTS_IPV6__)
    if (m["::"][port] && sizeof(ipv6 - ({ "::" }))) {
      // We have a non-ANY IPv6 IP number.
      // Keep track of the ips in case the ANY port is removed.
      urls[ourl]->skipped += ipv6;
      ipv6 = ({ "::" });
    }
    required_hosts = ipv6 + ipv4;
#else
    if (sizeof(ipv6)) {
      foreach(ipv6, string p) {
	report_warning(LOC_M(65, "Cannot open port %s for URL %s - "
			     "IPv6 support disabled.\n"),
		       p, display_url);
      }
    }
    required_hosts = ipv4;
#endif /* __ROXEN_SUPPORTS_IPV6__ */
  }

  int failures;
  int opened_ipv6_any_port;

  foreach(required_hosts, string required_host)
  {
    if( m[ required_host ] && m[ required_host ][ port ] )
    {
      if (required_host == "::") opened_ipv6_any_port = 1;

      m[required_host][port]->ref(url, urls[url]);

      urls[url]->port = m[required_host][port];
      if (urls[url]->ports) {
	urls[url]->ports += ({ m[required_host][port] });
      } else {
	urls[url]->ports = ({ m[required_host][port] });
      }
      urls[ourl]->port = m[required_host][port];
      if (urls[ourl]->ports) {
	urls[ourl]->ports += ({ m[required_host][port] });
      } else {
	urls[ourl]->ports = ({ m[required_host][port] });
      }
      continue;    /* No need to open a new port */
    }

    if( !m[ required_host ] )
      m[ required_host ] = ([ ]);


    Protocol prot_obj;
    if (mixed err = catch {
	prot_obj = m[ required_host ][ port ] =
	  prot( port, required_host,
		// Don't complain if binding IPv4 ANY fails with
		// EADDRINUSE after we've bound IPv6 ANY. 
		// Most systems seems to bind both IPv4 ANY and
		// IPv6 ANY for "::"
		!required_host && opened_ipv6_any_port);
      }) {
      failures++;
#if 0
      if (has_prefix(describe_error(err), "Invalid address") &&
	  required_host && has_value(required_host, ":")) {
	report_error(sprintf("Failed to initialize IPv6 port for URL %s"
			     " (ip %s).\n",
			     display_url, required_host));
      } else
#endif
	report_error(sprintf("Initializing the port handler for "
			     "URL %s (ip %s) failed: %s\n",
			     display_url,
			     required_host||"ANY",
#ifdef DEBUG
			     describe_backtrace(err)
#else
			     describe_error (err)
#endif
			    ));
      continue;
    }

    if (required_host == "::") opened_ipv6_any_port = 1;

    if (prot_obj->bound == -1) {
      // Got EADDRINUSE for the IPv6 case - see above. Just forget
      // about this one.
      m_delete (m[required_host], port);
      continue;
    }

    urls[ url ]->port = prot_obj;
    if (urls[url]->ports) {
      urls[url]->ports += ({ prot_obj });
    } else {
      urls[url]->ports = ({ prot_obj });
    }
    urls[ ourl ]->port = prot_obj;
    if (urls[ourl]->ports) {
      urls[ourl]->ports += ({ prot_obj });
    } else {
      urls[ourl]->ports = ({ prot_obj });
    }
    prot_obj->ref(url, urls[url]);
 
    if( !prot_obj->bound )
      failures++;
  }
  if (failures == sizeof(required_hosts)) 
  {
    report_error(LOC_M(23, "Failed to register URL %s for %O.")+"\n",
		 display_url, conf->query_name());
    return 0;
  }
  sort_urls();

  // The following will show the punycoded version for IDN hostnames.
  // That is intentional, to make it clear what actually happens.
  report_notice(" "+LOC_S(3, "Registered URL %s for %O.")+"\n",
		display_url, conf->query_name() );
  return 1;
}


Configuration find_configuration( string name )
//! Searches for a configuration with a name or fullname like the
//! given string. See also get_configuration().
{
  // Optimization, in case the exact name is given...
  if( Configuration o = get_configuration( name ) )
    return o;

  name = replace( lower_case( replace(name,"-"," ") )-" ", "/", "-" );
  foreach( configurations, Configuration o )
  {
    if( (lower_case( replace( replace(o->name, "-"," ") - " " ,
			      "/", "-" ) ) == name) ||
        (lower_case( replace( replace(o->query_name(), "-", " ") - " " ,
			      "/", "-" ) ) == name) )
      return o;
  }
  return 0;
}

protected int last_hrtime = gethrtime(1)/100;
protected int clock_sequence = random(0x4000);
protected string hex_mac_address =
  String.string2hex(Crypto.Random.random_string (6)|
		    "\1\0\0\0\0\0");	// Multicast bit.
// Generate an uuid string.
string new_uuid_string()
{
  int now = gethrtime(1)/100;
  if (now != last_hrtime) {
    clock_sequence = random(0x4000);
    last_hrtime = now;
  }
  int seq = clock_sequence++;
  // FIXME: Check if clock_sequence has wrapped during this @[now].

  // Adjust @[now] with the number of 100ns intervals between
  // 1582-10-15 00:00:00.00 GMT and 1970-01-01 00:00:00.00 GMT.
#if 0
  now -= Calendar.parse("%Y-%M-%D %h:%m:%s.%f %z",
			"1582-10-15 00:00:00.00 GMT")->unix_time() * 10000000;
#else /* !0 */
  now += 0x01b21dd213814000;	// Same as above.
#endif /* 0 */
  now &= 0x0fffffffffffffff;
  now |= 0x1000000000000000;	// DCE version 1.
  clock_sequence &= 0x3fff;
  clock_sequence |= 0x8000;	// DCE variant of UUIDs.
  return sprintf("%08x-%04x-%04x-%04x-%s",
		 now & 0xffffffff,
		 (now >> 32) & 0xffff,
		 (now >> 48) & 0xffff,
		 clock_sequence,
		 hex_mac_address);
}

mapping(string:array(int)) error_log=([]);

// Write a string to the administration interface error log and to stderr.
void nwrite(string s, int|void perr, int|void errtype,
            object|void mod, object|void conf)
{
  int log_time = time(1);
  string reference = (mod ? Roxen.get_modname(mod) : conf && conf->name) || "";
  string log_index = sprintf("%d,%s,%s", errtype, reference, s);
  if(!error_log[log_index])
    error_log[log_index] = ({ log_time });
  else
    error_log[log_index] += ({ log_time });

  if( mod )
  {
    if( mod->error_log )
      mod->error_log[log_index] += ({ log_time });
  }
  if( conf )
  {
    if( conf->error_log )
      conf->error_log[log_index] += ({ log_time });
  }

  if(errtype >= 1)
    report_debug( s );
}

// When was Roxen started?
int boot_time  =time();
int start_time =time();

string version()
{
#ifndef NSERIOUS
  return query("default_ident")?real_version:query("ident");
#else
  multiset choices=(<>);
  string version=query("default_ident")?real_version:query("ident");
  return version+", "+ ({
    "Applier of Templates",
    "Beautifier of Layouts",
    "Conqueror of Comdex",
    "Deliverer of Documents",
    "Enhancer of Abilities",
    "Freer of Webmasters",
    "Generator of Logs",
    "Helper of Users",
    "Interpreter of Scripts",
    "Juggler of Java-code",
    "Keeper of Databases",
    "Locator of Keywords",
    "Manipulator of Data",
    "Negatiator of Protocols",
    "Operator of Sites",
    "Provider of Contents",
    "Quintessence of Quality",
    "Responder to Connections",
    "Server of Webs",
    "Translator of Texts",
    "Unifier of Interfaces",
    "Valet of Visitors",
    "Watcher for Requests",
    "Xylem of Services",
    "Yielder of Information",
    "Zenith of Extensibility"
  })[random(26)];
#endif
}

public void log(mapping file, RequestID request_id)
{
  if(!request_id->conf) return;
  request_id->conf->log(file, request_id);
}

#if ROXEN_COMPAT < 2.2
// Support for unique user id's
private Stdio.File current_user_id_file;
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
  report_debug("Restoring unique user ID information. (" + current_user_id_number
	       + ")\n");
#ifdef FD_DEBUG
  mark_fd(current_user_id_file->query_fd(), "Unique user ID logfile.\n");
#endif
}

int increase_id()
{
  if(!current_user_id_file)
  {
    restore_current_user_id_number();
    return current_user_id_number+time(1);
  }
  if(current_user_id_file->stat()[2] != current_user_id_file_last_mod)
    restore_current_user_id_number();
  current_user_id_number++;
  current_user_id_file->seek(0);
  current_user_id_file->write((string)current_user_id_number);
  current_user_id_file_last_mod = current_user_id_file->stat()[2];
  return current_user_id_number;
}
#endif // ROXEN_COMPAT < 2.2

private int unique_id_counter;
string create_unique_id()
{
  return String.string2hex(Crypto.MD5.hash(query("server_salt") + start_time
    + "|" + (unique_id_counter++) + "|" + time(1)));
}

#ifndef __NT__
protected int abs_started;
protected int handlers_alive;

protected void low_engage_abs()
{
  report_debug("**** %s: ABS exiting roxen!\n\n",
	       ctime(time()) - "\n");
  _exit(1);	// It might not quit correctly otherwise, if it's
		// locked up
}

protected void engage_abs(int n)
{
  if (!query("abs_engage")) {
    abs_started = 0;
    report_debug("Anti-Block System Disabled.\n");
    return;
  }
  report_debug("**** %s: ABS engaged!\n"
	       "Waited more than %d minute(s).\n",
	       ctime(time()) - "\n",
	       query("abs_timeout"));
  // Paranoia exit in case describe_all_threads below hangs.
  signal(signum("SIGALRM"), low_engage_abs);
  int t = alarm(20);
  report_debug("\nTrying to dump backlog: \n");
  if (mixed err = catch {
      // Catch for paranoia reasons.
      describe_all_threads();
    })
    master()->handle_error (err);
#ifdef THREADS
  report_debug("\nHandler queue:\n");
  if (mixed err = catch {
    t = alarm(20);	// Restart the timeout timer.
    array(mixed) queue = handle_queue->buffer[handle_queue->r_ptr..];
    foreach(queue, mixed v) {
      if (!v) continue;
      if (!arrayp(v)) {
	report_debug("  *** Strange entry: %O ***\n", v);
      } else {
	report_debug("  %{%O, %}\n", v/({}));
      }
    }
    })
    master()->handle_error (err);
#endif
  report_debug("\nPending call_outs:\n");
  if (mixed err = catch {
      t = alarm(20);	// Restart the timeout timer.
      foreach(call_out_info(), array info) {
	report_debug("  %4d seconds: %O(%{%O, %})\n",
		     info[0], info[2], info[3]);
      }
    })
    master()->handle_error(err);
  low_engage_abs();
}

void restart_if_stuck (int force)
//! @note
//! Must be called from the backend thread due to Linux peculiarities.
{
  remove_call_out(restart_if_stuck);
  if (!(query("abs_engage") || force))
    return;
  if(!abs_started)
  {
    abs_started = 1;
    handlers_alive = time();
    report_debug("Anti-Block System Enabled.\n");
  }
  call_out (restart_if_stuck,10);
//    werror("call_out_info %O\n", filter(call_out_info(), lambda(array a) {
//  							 return a[2] == restart_if_stuck; }));
  signal(signum("SIGALRM"), engage_abs);
  int t = alarm (60*query("abs_timeout")+20);
  // werror("alarm: %d seconds left, set to %d\n", t, 60*query("abs_timeout")+20);
  if ((time(1) - handlers_alive) > 60*query("abs_timeout")) {
    // The handler installed below hasn't run.
    report_debug("**** %s: ABS: Handlers are dead!\n",
		 ctime(time()) - "\n");
    engage_abs(0);
  }
  handle(lambda() { handlers_alive = time(); });
}
#endif

#if constant(ROXEN_MYSQL_SUPPORTS_UNICODE)
// NOTE: We need to mark binary data as binary in case
//       the Mysql character_set_connection has been
//       set to anything other than "latin1".
#define MYSQL__BINARY	"_binary"
#else
#define MYSQL__BINARY	""
#endif

function(string:Sql.Sql) dbm_cached_get;

// Threshold in seconds for updating atime records Currently set to
// one day.
#define ATIME_THRESHOLD 60*60*24

class ImageCache
//! The image cache handles the behind-the-scenes caching and
//! regeneration features of graphics generated on the fly. Besides
//! being a cache, however, it serves a wide variety of other
//! interesting image conversion/manipulation functions as well.
{
#define QUERY(X,Y...) get_db()->query(X,Y)
  string name;
  string dir;
  function draw_function;
  mapping(string:array(mapping|int)) meta_cache = ([]);

  string documentation(void|string tag_n_args)
  {
    string doc = Stdio.read_file("base_server/image_cache.xml");
    if(!doc) return "";
    if(!tag_n_args)
      return Parser.HTML()->add_container("ex", "")->
	add_quote_tag("!--","","--")->finish(doc)->read();
    return replace(doc, "###", tag_n_args);
  }

  protected mapping meta_cache_insert( string i, mapping what )
  {
#ifdef ARG_CACHE_DEBUG
    werror("MD insert for %O: %O\n", i, what );
#endif
    if( sizeof( meta_cache ) > 1000 )
      sync_meta();
    if( what ) {
      meta_cache[i] = ({ what, 0 });
      return what;
    }
    else
      m_delete( meta_cache, i );
    return 0;
  }

  protected mixed frommapp( mapping what )
  {
    if( !what )
      error( "Got invalid argcache-entry\n" );
    if( !zero_type(what[""]) ) return what[""];
    return what;
  }

  protected void|mapping draw( string name, RequestID id )
  {
#ifdef ARG_CACHE_DEBUG
    werror("draw: %O id: %O\n", name, id );
#endif
    mixed args = Array.map( Array.map( name/"$", argcache->lookup,
				       id->client ), frommapp);

    id->cache_status["icachedraw"] = 1;

    mapping meta;
    string data;
    array guides;
#ifdef ARG_CACHE_DEBUG
    werror("draw args: %O\n", args );
#endif
    mixed reply = draw_function( @copy_value(args), id );

    if( !reply ) {
#ifdef ARG_CACHE_DEBUG
      werror("%O(%{%O, %}%O) ==> 0\n",
	     draw_function, args, id);
#endif
      return;
    }
    
    if( arrayp( args ) )
      args = args[0];

    if( arrayp( reply ) ) // layers.
    {
      guides = reply->get_misc_value( "image_guides" )-({});
      if( sizeof( guides ) )
	guides = guides[0];
      reply = Image.lay( reply );
    }
    if( objectp( reply ) && reply->image ) // layer.
    {
      if( !guides )
	guides = reply->get_misc_value( "image_guides" );
      reply = ([
        "img":reply->image(),
        "alpha":reply->alpha(),
      ]);
    }


    if( objectp( reply ) || (mappingp(reply) && reply->img) )
    {
      int quant = (int)args->quant;
      string format = lower_case(args->format || "gif");
      string dither = args->dither;
      Image.Colortable ct;
      Image.Color.Color bgcolor;
      Image.Image alpha;
      int true_alpha;

      if( args->fs  || dither == "fs" )
	dither = "floyd_steinberg";

      if( dither == "random" )
	dither = "random_dither";

      if( format == "jpg" )
        format = "jpeg";

      if( dither )
        dither = replace( dither, "-", "_" );

      if(mappingp(reply))
      {
        alpha = reply->alpha;
        reply = reply->img;
      }

      if( args["true-alpha"] )
        true_alpha = 1;

      if( args["background"] || args["background-color"])
        bgcolor = Image.Color( args["background"]||args["background-color"] );

      if( args["opaque-value"] )
      {
        if( !bgcolor )
	  true_alpha = 1;
        int ov = (int)(((float)args["opaque-value"])*2.55);
        if( ov < 0 )
          ov = 0;
        else if( ov > 255 )
          ov = 255;
        if( alpha )
          alpha *= ov;
        else
          alpha = Image.Image( reply->xsize(), reply->ysize(), ov,ov,ov );
      }

      if( args->gamma )
        reply = reply->gamma( (float)args->gamma );


      if( bgcolor && alpha && !true_alpha )
      {
        reply = Image.Image( reply->xsize(),
                             reply->ysize(), bgcolor )
              ->paste_mask( reply, alpha );
        alpha = alpha->threshold( 4 );
      }

      int x0, y0, x1=reply->xsize(), y1=reply->ysize(), xc, yc;
      if( args["x-offset"] || args["xoffset"] )
        x0 = (int)(args["x-offset"]||args["xoffset"]);
      if( args["y-offset"] || args["yoffset"] )
        y0 = (int)(args["y-offset"]||args["yoffset"]);
      if( args["width"] || args["x-size"] )
	x1 = (int)(args["x-size"]||args["width"]);
      if( args["height"] || args["y-size"] )
	y1 = (int)(args["y-size"]||args["height"]);

      array xguides, yguides;
      function sort_guides = lambda()
      {
	xguides = ({}); yguides = ({});
	if( guides )
	{
	  foreach( guides, object g  )
	    if( g->pos > 0 )
	      if( g->vertical )
	      {
		if( g->pos < reply->xsize() )
		  xguides += ({ g->pos });
	      }
	      else
		if( g->pos < reply->ysize() )
		  yguides += ({ g->pos });
	  sort( xguides ); sort( yguides );
	}
      };
	
      if( args->crop )
      {
	int gx=1, gy=1, gx2, gy2;
	if( sscanf( args["guides-index"]||"", "%d,%d", gx, gy ) == 2 )
	{
	  gx2 = gx+1;
	  gy2 = gy+1;
	  sscanf( args["guides-index"]||"", "%d,%d-%d,%d", gx, gy, gx2, gy2 );
	}
	/* No, I did not forget the break statements. */

	switch( args->crop )
	{
	  case "guides-cross":
	    sort_guides();
	    if( sizeof(xguides) && sizeof(yguides) )
	    {
	      xc = xguides[ min(sizeof(xguides),gx) - 1 ];
	      yc = yguides[ min(sizeof(yguides),gy) - 1 ];
	      break;
	    }
	    guides=0;
	  case "guides-region":
	    sort_guides();
	    if( (sizeof(xguides)>1) && (sizeof(yguides)>1) )
	    {
	      gx = min(sizeof(xguides)-1,gx) - 1;
	      gy = min(sizeof(yguides)-1,gy) - 1;
	      gx2 = min(sizeof(xguides),gx2) - 1;
	      gy2 = min(sizeof(yguides),gy2) - 1;

	      x0 = xguides[gx];   x1 = xguides[gx2] - x0;
	      y0 = yguides[gy];   y1 = yguides[gy2] - y0;
	      break;
	    }
	  default:
	    if( sscanf( args->crop, "%d,%d-%d,%d", x0, y0, x1, y1 ) == 4)
	    {
	      x1 -= x0;
	      y1 -= y0;
	    }
	    break;
	  case "auto":
	    [ x0, y0, x1, y1 ] = reply->find_autocrop();
	    x1 = x1 - x0 + 1;
	    y1 = y1 - y0 + 1;
	}
      }
      sort_guides = 0;		// To avoid garbage.

#define SCALEI 1
#define SCALEF 2
#define SCALEA 4
#define CROP   8

      function do_scale_and_crop = lambda ( int x0, int y0,
					    int x1, int y1,
					    int|float w,  int|float h,
					    int type )
      {
	if( (type & CROP) && x1 && y1 
	    && ((x1 != reply->xsize()) ||  (y1 != reply->ysize())
		|| x0 ||  y0 ) )
	{
	    reply = reply->copy( x0, y0, x0+x1-1, y0+y1-1,
				 (bgcolor?bgcolor->rgb():0) );
	    if( alpha )
	      alpha = alpha->copy( x0, y0, x0+x1-1,y0+y1-1, Image.Color.black);
	}

	if( type & SCALEI )
	{
	  if( xc || yc )
	  {
	    if( h && !w )
	      w = (reply->xsize() * h) / reply->ysize();

	    if( w && !h )
	      h = (reply->ysize() * w) / reply->xsize();

	    x0 = max( xc - w/2, 0 );
	    y0 = max( yc - h/2, 0 );

	    x1 = w; y1 = h;
	    if( x0 + x1 > reply->xsize() )
	    {
	      x0 = reply->xsize()-w;
	      if( x0 < 0 )
	      {
		x0 = 0;
		x1 = reply->xsize();
	      }
	    }
	    if( y0 + y1 > reply->ysize() )
	    {
	      y0 = reply->ysize()-h;
	      if( y0 < 0 )
	      {
		y0 = 0;
		y1 = reply->ysize();
	      }
	    }
	    reply = reply->copy( x0, y0, x0+x1-1, y0+y1-1,
				 (bgcolor?bgcolor->rgb():0) );

	    if( alpha )
	      alpha = alpha->copy( x0, y0, x0+x1-1,y0+y1-1, Image.Color.black);
	  }
	}


	if( (type & SCALEF) && (w != 1.0) )
	{
	  reply = reply->scale( w );
	  if( alpha )
	    alpha = alpha->scale( w );
	}
	else if( (type & SCALEA) &&
		 ((reply->xsize() != w)  || (reply->ysize() != h)) )
	{
	  reply = reply->scale( w,h );
	  if( alpha )
	    alpha = alpha->scale( w,h );
	}
	else if( (type & SCALEI) &&
		 ((reply->xsize() != w)  || (reply->ysize() != h)) )
	{
	  if( w && h )
	  {
	    if( (w * (float)reply->ysize()) < (h * (float)reply->xsize()) )
	      h = 0;
	    else
	      w = 0;
	  }
	  w = min( w, reply->xsize() );
	  h = min( h, reply->ysize() );
	  reply = reply->scale( w,h );
	  if( alpha )
	    alpha = alpha->scale( w,h );
	}
      };
      
      if( sizeof((string) (args->scale || "")) )
      {
        int x, y;
        if( sscanf( args->scale, "%d,%d", x, y ) == 2)
	  do_scale_and_crop( x0, y0, x1, y1, x, y, SCALEA|CROP );
        else if( (float)args->scale < 3.0)
	  do_scale_and_crop( x0, y0, x1, y1,
			     ((float)args->scale), ((float)args->scale),
			     SCALEF|CROP );
      }
      else
	if( sizeof( (string) (args->maxwidth || args->maxheight ||
			      args["max-width"] || args["max-height"] || "")) )
      {
        int x = (int)args->maxwidth|| (int)args["max-width"];
        int y = (int)args->maxheight||(int)args["max-height"];
	do_scale_and_crop( x0, y0, x1, y1, x, y, SCALEI|CROP );
      }
      else
	do_scale_and_crop( x0, y0, x1, y1, 0, 0, CROP );
      do_scale_and_crop = 0;	// To avoid garbage.

      if( args["span-width"] || args["span-height"] )
      {
	int width  = (int)args["span-width"];
	int height = (int)args["span-height"];

	if( (width && reply->xsize() > width) ||
	    (height && reply->ysize() > height) )
	{
	  if( (width && height && (reply->xsize() / (float)width >
				   reply->ysize() / (float)height)) ||
	      !height )
	  {
	    reply = reply->scale( width, 0 );
	    if( alpha )
	      alpha = alpha->scale( width, 0 );
	  }
	  else if( height )
	  {
	    reply = reply->scale( 0, height );
	    if( alpha )
	      alpha = alpha->scale( 0, height );
	  }
	}

	int x1,x2,y1,y2;
	if( width )
	{
	  x1 = -((width - reply->xsize()) / 2);
	  x2 = x1 + width - 1;
	}
	if( height )
	{
	  y1 = -((height - reply->ysize()) / 2);
	  y2 = y1 + height - 1;
	}
	
	if( width && height )
	{
	  reply = reply->copy(x1,y1,x2,y2,(bgcolor?bgcolor->rgb():0));
	  if( alpha ) alpha = alpha->copy(x1,y1,x2,y2);
	}
	else if( width )
	{
	  reply = reply->copy(x1,0,x2,reply->ysize(),(bgcolor?bgcolor->rgb():0));
	  if ( alpha ) alpha = alpha->copy(x1,0,x2,alpha->ysize());
	}
	else
	{
	  reply = reply->copy(0,y1,reply->xsize(),y2,(bgcolor?bgcolor->rgb():0));
	  if( alpha ) alpha = alpha->copy(0,y1,alpha->xsize(),y2);
	}
      }

      if( args["rotate-cw"] || args["rotate-ccw"])
      {
        float degree = (float)(args["rotate-cw"] || args["rotate-ccw"]);
        switch( args["rotate-unit"] && args["rotate-unit"][0..0] )
        {
         case "r":  degree = (degree / (2*3.1415)) * 360; break;
         case "d":  break;
         case "n":  degree = (degree / 400) * 360;        break;
         case "p":  degree = (degree / 1.0) * 360;        break;
        }
        if( args["rotate-cw"] )
          degree = -degree;
        if(!alpha)
          alpha = reply->copy()->clear(255,255,255);
        reply = reply->rotate_expand( degree );
        alpha = alpha->rotate( degree, 0,0,0 );
      }


      if( args["mirror-x"] )
      {
        if( alpha )
          alpha = alpha->mirrorx();
        reply = reply->mirrorx();
      }

      if( args["mirror-y"] )
      {
        if( alpha )
          alpha = alpha->mirrory();
        reply = reply->mirrory();
      }

      if( bgcolor && alpha && !true_alpha )
      {
        reply = Image.Image( reply->xsize(),
                             reply->ysize(), bgcolor )
              ->paste_mask( reply, alpha );
      }

      if( args["cs-rgb-hsv"] )reply = reply->rgb_to_hsv();
      if( args["cs-grey"] )   reply = reply->grey();
      if( args["cs-invert"] ) reply = reply->invert();
      if( args["cs-hsv-rgb"] )reply = reply->hsv_to_rgb();

      if( !true_alpha && alpha )
        alpha = alpha->threshold( 4 );

      if( quant || (format=="gif") )
      {
	int ncols = quant;
	if( format=="gif" ) {
	  ncols = ncols||id->misc->defquant||32;
	  if( ncols > 254 )
	    ncols = 254;
	}
        ct = Image.Colortable( reply, ncols );
        if( dither )
        {
          if( dither == "random" ) 
            dither = "random_grey";
          if( ct[ dither ] )
            ct[ dither ]();
          else
            ct->ordered();
        
        }
      }

      mapping enc_args = ([]);
      if( ct )
        enc_args->colortable = ct;

      if( alpha )
        enc_args->alpha = alpha;

      foreach( glob( "*-*", indices(args)), string n )
        if(sscanf(n, "%*[^-]-%s", string opt ) == 2)
          if( opt != "alpha" )
            enc_args[opt] = (int)args[n];

      switch(format)
      {
	case "wbf":
	  format = "wbmp";
	case "wbmp":
	  Image.Colortable bw=Image.Colortable( ({ ({ 0,0,0 }), 
						   ({ 255,255,255 }) }) );
	  bw->floyd_steinberg();
	  data = Image.WBF.encode( bw->map( reply ), enc_args );
	  break;
       case "gif":
#if constant(Image.GIF) && constant(Image.GIF.encode)
         if( alpha && true_alpha )
         {
           Image.Colortable bw=Image.Colortable( ({ ({ 0,0,0 }), 
                                                    ({ 255,255,255 }) }) );
           bw->floyd_steinberg();
           alpha = bw->map( alpha );
         }
         if( catch {
           if( alpha )
             data = Image.GIF.encode_trans( reply, ct, alpha );
           else
             data = Image.GIF.encode( reply, ct );
         })
           data = Image.GIF.encode( reply );
         break;

#else
         // Fall-through when there is no GIF encoder available --
         // use PNG with a colortable instead.
         format = "png";
#endif

       case "png":
         if( ct ) enc_args->palette = ct;
         m_delete( enc_args, "colortable" );
         if( !(args["png-use-alpha"] || args["true-alpha"]) )
           m_delete( enc_args, "alpha" );
         else if( enc_args->alpha )
           // PNG encoder doesn't handle alpha and palette simultaneously
           // which is rather sad, since that's the only thing 100% supported
           // by all common browsers.
	   m_delete( enc_args, "palette");
         else
	   m_delete( enc_args, "alpha" );

       default:
         if(!Image[upper_case( format )]
            || !Image[upper_case( format )]->encode )
           error("Image format "+format+" not supported\n");
	 data = Image[upper_case( format )]->encode( reply, enc_args );
      }

      meta =
      ([
        "xsize":reply->xsize(),
        "ysize":reply->ysize(),
        "type":(format == "wbmp" ? "image/vnd.wap.wbmp" : "image/"+format ),
      ]);
    }
    else if( mappingp(reply) )
    {
      // This could be an error from get_file()
      if(reply->error)
	return reply;
      meta = reply->meta;
      data = reply->data;
      if( !meta || !data )
        error("Invalid reply mapping.\n"
              "Expected ([ \"meta\": ([metadata]), \"data\":\"data\" ])\n"
	      "Got %O\n", reply);
    }
#ifdef ARG_CACHE_DEBUG
    werror("draw %O done\n", name );
#endif
    // Avoid throwing and error if the same image is rendered twice.
    mixed err = catch(store_data( name, data, meta ));
#ifdef ARG_CACHE_DEBUG
    if (err) {
      werror("store_data failed with:\n"
	     "%s\n", describe_backtrace(err));
    }
#endif
  }

  protected void store_data( string id, string data, mapping meta )
  {
    if(!stringp(data)) return;
#ifdef ARG_CACHE_DEBUG
    werror("store %O (%d bytes)\n", id, strlen(data) );
#endif
    meta_cache_insert( id, meta );
    string meta_data = encode_value( meta );
#ifdef ARG_CACHE_DEBUG
    werror("Replacing entry for %O\n", id );
#endif
    QUERY("REPLACE INTO "+name+
	  " (id,size,atime,meta,data) VALUES"
	  " (%s,%d,UNIX_TIMESTAMP()," MYSQL__BINARY "%s," MYSQL__BINARY "%s)",
	  id, strlen(data)+strlen(meta_data), meta_data, data );
#ifdef ARG_CACHE_DEBUG
    array(mapping(string:string)) q =
      QUERY("SELECT meta, data FROM " + name +
	    " WHERE id = %s", id);
    if (!q || sizeof(q) != 1) {
      werror("Unexpected result size: %d\n",
	     q && sizeof(q));
    } else {
      if (q[0]->meta != meta_data) {
	werror("Meta data differs: %O != %O\n",
	       meta_data, q[0]->meta);
      }
      if (q[0]->data != data) {
	werror("Data differs: %O != %O\n",
	       data, q[0]->data);
      }
    }
#endif
  }

  protected mapping restore_meta( string id, RequestID rid )
  {
    if( array item = meta_cache[ id ] )
    {
      item[ 1 ] = time(1); // Update cached atime.
      return item[ 0 ];
    }

#ifdef ARG_CACHE_DEBUG
    werror("restore meta %O\n", id );
#endif
    array(mapping(string:string)) q =
      QUERY("SELECT meta, UNIX_TIMESTAMP() - atime as atime_diff "
	    "FROM "+name+" WHERE id=%s", id );

    string s;
    if(!sizeof(q) || !strlen(s = q[0]->meta))
      return 0;

    mapping m;
    if (catch (m = decode_value (s)))
    {
      report_error( "Corrupt data in cache-entry "+id+".\n" );
      QUERY( "DELETE FROM "+name+" WHERE id=%s", id);
      return 0;
    }

    // Update atime only if older than threshold.
    if((int)q[0]->atime_diff > ATIME_THRESHOLD) {
      QUERY("UPDATE LOW_PRIORITY "+name+" "
	    "   SET atime = UNIX_TIMESTAMP() "
	    " WHERE id = %s ", id);
    }
    return meta_cache_insert( id, m );
  }

  protected void sync_meta()
  {
    mapping tmp = meta_cache;
    meta_cache = ([]);
    // Sync cached atimes.
    foreach(tmp; string id; array value) {
      if (value[1])
	QUERY("UPDATE "+name+" SET atime=%d WHERE id=%s",
	      value[1], id);
    }
  }

  void flush(int|void age)
  //! Flush the cache. If an age (an integer as returned by
  //! @[time()]) is provided, only images with their latest access before
  //! that time are flushed.
  {
    int num;
#if defined(DEBUG) || defined(IMG_CACHE_DEBUG)
    int t = gethrtime();
    report_debug("Cleaning "+name+" image cache ... ");
#endif
    sync_meta();
    uid_cache  = ([]);
    rst_cache  = ([]);
    if( !age )
    {
#if defined(DEBUG) || defined(IMG_CACHE_DEBUG)
      report_debug("cleared\n");
#endif
      QUERY( "DELETE FROM "+name );
      num = -1;
      return;
    }

    array(string) ids =
      QUERY( "SELECT id FROM "+name+" WHERE atime < "+age)->id;

    num = sizeof( ids );

    int q;
    while(q<sizeof(ids)) {
      string list = map(ids[q..q+99], get_db()->quote) * "','";
      q+=100;
      QUERY( "DELETE LOW_PRIORITY FROM "+name+" WHERE id in ('"+list+"')" );
    }

#if 0
    // Disabled. This can take a significant amount of time to run,
    // and we really can't afford an unresponsive image cache - it can
    // easily hang all handler threads. Besides, it's doubtful if this
    // is of any use since the space for the deleted records probably
    // will get reused soon enough anyway. /mast
    if( num )
      catch
      {
	// Old versions of Mysql lacks OPTIMIZE. Not that we support
	// them, really, but it might be nice not to throw an error, at
	// least.
#if defined(DEBUG) || defined(IMG_CACHE_DEBUG)
	report_debug("Optimizing database ... ", name);
#endif
	QUERY( "OPTIMIZE TABLE "+name );
      };
#endif

#if defined(DEBUG) || defined(IMG_CACHE_DEBUG)
    report_debug("%s removed (%dms)\n",
		 (num==-1?"all":num?(string)num:"none"),
		 (gethrtime()-t)/1000);
#endif
  }

  array(int) status(int|void age)
  //! Return the total number of images in the cache, their cumulative
  //! sizes in bytes and, if an age time_t was supplied, the number of
  //! images that has not been accessed after that time is returned
  //!  (see <ref>flush()</ref>). (Three integers are returned
  //! regardless of whether an age parameter was given.)
  {
    int imgs=0, size=0, aged=0;
    array(mapping(string:string)) q;

    q=QUERY("SHOW TABLE STATUS");
    foreach(q, mapping qq)
      if(has_prefix(qq->Name, name)) {
	imgs = (int)qq->Rows;
	size += (int)qq->Data_length;
      }

    if(age) {
      q=QUERY("select SUM(1) as num from "+name+" where atime < "+age);
      aged = (int)q[0]->num;
    }
    return ({ imgs, size, aged });
  }

  protected mapping(string:mapping) rst_cache = ([ ]);
  protected mapping(string:string) uid_cache = ([ ]);

  protected mapping restore( string id, RequestID rid )
  {
    array q;
    string uid;
    if( zero_type(uid = uid_cache[id]) )
    {
      q = QUERY( "SELECT uid FROM "+name+" WHERE id=%s",id);
      if( sizeof(q) )
	uid = q[0]->uid;
      else
	uid = 0;
      uid_cache[id] = uid;
    }

    if( uid && strlen(uid) )
    {
      User u;
      if( !(u=rid->conf->authenticate(rid)) || (u->name() != uid ) )
	return rid->conf->authenticate_throw(rid, "User");
    }

    if( rst_cache[ id ] ) {
      rid->cache_status["icacheram"] = 1;
      return rst_cache[ id ] + ([]);
    }

#ifdef ARG_CACHE_DEBUG
      werror("restore %O\n", id );
#endif
    q = QUERY( "SELECT meta,atime,data FROM "+name+" WHERE id=%s",id);
    if( sizeof(q) )
    {
      if( sizeof(q[0]->data) )
      {
	// Case 1: We have cache entry and image.
	string f = q[0]->data;
	mapping m;
	if (mixed err = catch( m = decode_value( q[0]->meta ) ))
	  report_debug ("Failed to decode meta mapping for id %O in %s: %s",
			id, name, describe_error (err));
	if( !m ) return 0;

	rid->cache_status["icachedisk"] = 1;
	m = Roxen.http_string_answer( f, m->type||("image/gif") );

	if( strlen( f ) > 6000 )
	  return m;
	rst_cache[ id ] = m;
	if( sizeof( rst_cache ) > 100 )
	  rst_cache = ([ id : m ]);
	return rst_cache[ id ] + ([]);
      }
      // Case 2: We have cache entry, but no data.
      return 0;
    }
    else
    {
      // Case 3: No cache entry. Create one
      User u = rid->conf->authenticate(rid);
      string uid = "";
      if( u ) uid = u->name();
      // Might have been insterted from elsewhere.
      QUERY("REPLACE INTO "+name+
	    " (id,uid,atime) VALUES (%s,%s,UNIX_TIMESTAMP())",
	    id, uid );
    }
    
    return 0;
  }


  string data( array|string|mapping args, RequestID id, int|void nodraw,
			   int|void timeout )
  //! Returns the actual raw image data of the image rendered from the
  //! @[args] instructions.
  //!
  //! A non-zero @[nodraw] parameter means an image not already in the
  //! cache will not be rendered on the fly, but instead return zero.
  {
    mapping res = http_file_answer( args, id, nodraw, timeout );
    return res && res->data;
  }

  mapping http_file_answer( array|string|mapping data,
                            RequestID id,
                            int|void nodraw, int|void timeout )
  //! Returns a @[result mapping] like one generated by
  //! @[Roxen.http_file_answer()] but for the image file
  //! rendered from the `data' instructions.
  //!
  //! Like @[metadata], a non-zero @[nodraw]parameter means an
  //! image not already in the cache will not be rendered on the fly,
  //! but instead zero will be returned (this will be seen as a 'File
  //! not found' error)
  {
    current_configuration->set(id->conf);
    string na = store( data, id, timeout );
    mixed res;
#ifdef ARG_CACHE_DEBUG
    werror("data: %O id: %O\n", na, id );
#endif
    if(! (res=restore( na,id )) )
    {
      mixed err;
      if (nodraw || (err = catch {
  	if (mapping res = draw( na, id ))
  	  return res;
      })) {
	if (objectp (err) && err->is_RXML_Backtrace && !RXML_CONTEXT) {
	  // If we get an rxml error and there's no rxml context then
	  // we're called from a direct request to the image cache.
	  // The error ought to have been reported in the page that
	  // generated the link to the image cache, but since it's too
	  // late for that now, we just log it as a (brief) server
	  // error with the referring page.
	  string errmsg = "Error in " + name + " image generation: " +
	    err->msg;
	  if (sizeof (id->referer))
	    errmsg += "  Referrer: " + id->referer[0];
	  report_error (errmsg + "\n");
	  return 0;
	} else if (arrayp(err) && sizeof(err) && stringp(err[0])) {
	  if (sscanf(err[0], "Requesting unknown key %s\n",
		     string message) == 1)
	  {
	    // File not found.
	    report_debug("Requesting unknown key %s %O from %O\n",
			 message,
			 id->not_query,
			 (sizeof(id->referer)?id->referer[0]:"unknown page"));
	    return 0;
	  }
	}
	throw (err);
      }
      if( !(res = restore( na,id )) ) {
	error("Draw callback %O did not generate any data.\n"
	      "na: %O\n"
	      "id: %O\n",
	      draw_function, na, id);
      }
    }
    res->stat = ({ 0, 0, 0, 900000000, 0, 0, 0, 0, 0 });

    //  Setting the cacheable flag is done in order to get headers sent which
    //  cause the image to be cached in the client even when using https
    //  sessions.
    RAISE_CACHE(INITIAL_CACHEABLE);

    //  With the new (5.0 and newer) arg-cache enabled by default we can
    //  allow authenticated images in the protocol cache. At this point
    //  http.pike will have cleared it so re-enable explicitly.
    PROTO_CACHE();
    
    return res;
  }

  mapping metadata( array|string|mapping data,
		    RequestID id,
		    int|void nodraw,
		    int|void timeout )
  //! Returns a mapping of image metadata for an image generated from
  //! the data given (as sent to @[store()]). If a non-zero
  //! @[nodraw] parameter is given and the image was not in the cache,
  //! it will not be rendered on the fly to get the correct data.
  //!
  //! @param timeout
  //!   The @[timeout] is sent unmodified to @[store()].
  {
    string na = store( data, id, timeout );
    mapping res;
#ifdef ARG_CACHE_DEBUG
      werror("meta %O\n", na );
#endif
    if(! (res = restore_meta( na,id )) )
    {
      if(nodraw)
        return 0;
      draw( na, id );
      return restore_meta( na,id );
    }
    return res;
  }

  mapping tomapp( mixed what )
  {
    if( mappingp( what ))
      return what;
    return ([ "":what ]);
  }

  string store( array|string|mapping data, RequestID id, int|void timeout )
  //! Store the data your draw callback expects to receive as its
  //! first argument(s). If the data is an array, the draw callback
  //! will be called like <pi>callback( @@data, id )</pi>.
  //!
  //! @param timeout
  //!    Timeout for the entry in seconds from now. If @expr{UNDEFINED@},
  //!    the entry will not expire. Currently just passed along to
  //!    the @[ArgCache].
  {
    string ci, user;
    function update_args = lambda ( mapping a )
    {
      if (!a->format)
	//  Make implicit format choice explicit
#if constant(Image.GIF) && constant(Image.GIF.encode)
	a->format = "gif";
#else
	a->format = "png";
#endif
	if( get_admin_configuration() != id->conf &&
	    id->misc->authenticated_user &&
	    !id->misc->authenticated_user->is_transient )
	// This entry is not actually used, it's only there to
	// generate a unique key.
	a["\0u"] = user = id->misc->authenticated_user->name();
    };
    
    if( mappingp( data ) )
    {
      update_args( data );
      ci = argcache->store( data, timeout );
    }
    else if( arrayp( data ) )
    {
      if( !mappingp( data[0] ) )
	error("Expected mapping as the first element of the argument array\n");
      update_args( data[0] );
      ci = map( map( data, tomapp ), argcache->store, timeout )*"$";
    } else
      ci = data;
    update_args = 0;		// To avoid garbage.

    if( zero_type( uid_cache[ ci ] ) )
    {
      uid_cache[ci] = user;
      // Make sure to only update the entry if it does not already
      // exists or has wrong uid. Allways updating the table will
      // casue mysql to lock the table and cause a potential gobal
      // ImageCache stall.
      string uid = user || "";
      array q = QUERY("SELECT uid from "+name+" where id=%s", ci);
      if(!sizeof(q) || (sizeof(q) && q[0]->uid != uid)) {
	QUERY("INSERT INTO "+name+" "
	      "(id,uid,atime) VALUES (%s,%s,UNIX_TIMESTAMP()) "
	      "ON DUPLICATE KEY UPDATE uid=%s",
	      ci, uid, uid);
      }
    }

#ifndef NO_ARG_CACHE_SB_REPLICATE
    if(id->misc->persistent_cache_crawler || id->misc->do_replicate_argcache) {
      // Force an update of rep_time for the requested arg cache id.
      foreach(ci/"$", string key) {
#if ARGCACHE_DEBUG
	werror("Request for id %O from prefetch crawler.\n", key);
#endif /* ARGCACHE_DEBUG */
	argcache->refresh_arg(key);
      }
    }
#endif /* NO_ARG_CACHE_SB_REPLICATE */
    return ci;
  }

  void set_draw_function( function to )
  //! Set a new draw function.
  {
    draw_function = to;
  }

  protected void setup_tables()
  {
    if(catch(QUERY("SELECT data FROM "+name+" WHERE id=''")))
    {
      werror("Creating image-cache tables for '"+name+"'\n");
      catch(QUERY("DROP TABLE "+name));

      // The old tables. This is only useful for people who have run
      // Roxen 2.2 from cvs before
      catch(QUERY("DROP TABLE "+name+"_data"));


      master()->resolv("DBManager.is_module_table")
	( 0,"local",name,"Image cache for "+name);
      
      QUERY("CREATE TABLE "+name+" ("
	    "id     CHAR(64) NOT NULL PRIMARY KEY, "
	    "size   INT      UNSIGNED NOT NULL DEFAULT 0, "
	    "uid    CHAR(32) NOT NULL DEFAULT '', "
	    "atime  INT      UNSIGNED NOT NULL DEFAULT 0,"
	    "meta MEDIUMBLOB NOT NULL DEFAULT '',"
	    "data MEDIUMBLOB NOT NULL DEFAULT '',"
	    "INDEX atime_id (atime, id)"
	    ")" );
    }

    // Create index in old databases. Index is used when flushing old
    // entries. Column 'id' is included in index in order to avoid
    // reading data file.
    array(mapping(string:mixed)) res = QUERY("SHOW INDEX FROM " + name);
    if(search(res->Key_name, "atime_id") < 0) {
      report_debug("Updating " + name + " image cache: "
		   "Adding index atime_id on %s... ", name);
      int start_time = gethrtime();
      QUERY("CREATE INDEX atime_id ON " + name + " (atime, id)");
      report_debug("complete. [%f s]\n", (gethrtime() - start_time)/1000000.0);
      report_debug("Updating " + name + " image cache: "
		   "Dropping index atime on %s... ", name);
      start_time = gethrtime();
      QUERY("DROP INDEX atime ON " + name);
      report_debug("complete. [%f s]\n", (gethrtime() - start_time)/1000000.0);
    }
  }

  Sql.Sql get_db()
  {
    return dbm_cached_get("local");
  }

  protected void init_db( )
  {
    catch(sync_meta());
    setup_tables();
  }

  void do_cleanup( )
  {
    //  Flushes may be costly in large sites (at least the OPTIMIZE TABLE
    //  command) so schedule next run sometime after 04:30 the day after
    //  tomorrow.
    //
    // Note: The OPTIMIZE TABLE step has been disabled. /mast
    int now = time();
    mapping info = localtime(now);
    int wait = (int) ((24 - info->hour) + 24 + 4.5) * 3600 + random(500);
    background_run(wait, do_cleanup);

    //  Remove items older than one week
    flush(now - 7 * 3600 * 24);
  }
  
  void create( string id, function draw_func )
  //! Instantiate an image cache of your own, whose image files will
  //! be stored in a table `id' in the cache mysql database,
  //!
  //! The `draw_func' callback passed will be responsible for
  //! (re)generation of the images in the cache. Your draw callback
  //! may take any arguments you want, depending on the first argument
  //! you give the <ref>store()</ref> method, but its final argument
  //! will be the RequestID object.
  //!
  //! @note
  //! Use @[RXML.run_error] or @[RXML.parse_error] within the draw
  //! function to throw user level drawing errors, e.g. invalid or
  //! missing images or argument errors. If it's called within a
  //! graphics tag then the error is thrown directly and reported
  //! properly by the rxml evaluator. If it's called later, i.e. in a
  //! direct request to the image cache, then it is catched by the
  //! @[ImageCache] functions and reported in as good way as possible,
  //! i.e. currently briefly in the debug log.
  {
    name = id;
    draw_function = draw_func;
    init_db();
    // Support that the 'local' database moves.
    master()->resolv( "DBManager.add_dblist_changed_callback" )( init_db );

    // Always remove entries that are older than one week.
    background_run( 10, do_cleanup );
  }

  void destroy()
  {
    if (mixed err = catch(sync_meta())) {
      report_warning("Failed to sync cached atimes for "+name+"\n");
#if 0
#ifdef DEBUG
      master()->handle_error (err);
#endif
#endif
    }
  }
}


class ArgCache
//! Generic cache for storing away a persistent mapping of data to be
//! refetched later by a short string key. This being a cache, your
//! data may be thrown away at random when the cache is full.
{
#define GET_DB()				\
  Sql.Sql db = dbm_cached_get("local")
#undef QUERY
#define QUERY(X,Y...) db->query(X,Y)
  string name;

#define CACHE_SIZE  900

#ifdef ARGCACHE_DEBUG
#define dwerror(ARGS...) werror(ARGS)
#else
#define dwerror(ARGS...) 0
#endif    

  //! Cache of the latest entries requested or stored.
  //! Limited to @[CACHE_SIZE] (currently @expr{900@}) entries.
  protected mapping(string|int:mixed) cache = ([ ]);

  //! Cache of cache-ids that have no expiration time.
  //! This cache is maintained in sync with @[cache].
  //! Note that entries not in this cache may still have
  //! unlimited expiration time.
  protected mapping(string|int:int) no_expiry = ([ ]);

  protected void setup_table()
  {
    GET_DB();

    // New style argument2 table.
    if(catch(QUERY("SELECT id FROM "+name+"2 LIMIT 0")))
    {
      master()->resolv("DBManager.is_module_table")
	( 0, "local", name+"2",
	  "The argument cache, used to map between "
	  "a unique string and an argument mapping" );
      catch(QUERY("DROP TABLE "+name+"2" ));
      QUERY("CREATE TABLE "+name+"2 ("
	    "id        CHAR(32) PRIMARY KEY, "
	    "ctime     DATETIME NOT NULL, "
	    "atime     DATETIME NOT NULL, "
	    "rep_time  DATETIME NOT NULL, "
	    "sync_time INT NULL, "
	    "timeout   INT NULL, "
	    "contents  MEDIUMBLOB NOT NULL, "
	    "          INDEX(timeout),"
	    "          INDEX(sync_time)"
	    ")");
    }

    if (catch (QUERY ("SELECT rep_time FROM " + name + "2 LIMIT 0")))
    {
      // Upgrade a table without rep_time.
      QUERY ("ALTER TABLE " + name + "2"
	     " ADD rep_time DATETIME NOT NULL"
	     " AFTER atime");
    }

    if (catch (QUERY ("SELECT timeout FROM " + name + "2 LIMIT 0")))
    {
      // Upgrade a table without timeout.
      QUERY ("ALTER TABLE " + name + "2 "
	     "  ADD timeout INT NULL "
	     "AFTER rep_time");
      QUERY ("ALTER TABLE " + name + "2 "
	     "  ADD INDEX(timeout)");
    }

    if (catch (QUERY ("SELECT sync_time FROM " + name + "2 LIMIT 0")))
    {
      // Upgrade a table without sync_time.
      QUERY ("ALTER TABLE " + name + "2"
	     " ADD sync_time INT NULL"
	     " AFTER rep_time");
      QUERY ("ALTER TABLE " + name + "2 "
	     "  ADD INDEX(sync_time)");
    }

    catch {
      array(mapping(string:mixed)) res = 
	QUERY("DESCRIBE "+name+"2 contents");
      
      if(res[0]->Type == "blob") {
	QUERY("ALTER TABLE "+name+"2 MODIFY contents MEDIUMBLOB NOT NULL");
	werror("ArgCache: Extending \"contents\" field in table \"%s2\" from BLOB to MEDIUMBLOB.\n", name);
      }
    };
  }

  protected void do_cleanup()
  {
    GET_DB();
    QUERY("DELETE LOW_PRIORITY FROM " + name + "2 "
	  " WHERE timeout IS NOT NULL "
	  "   AND timeout < %d", time());
  }

  protected void cleanup_process( )
  {
    //  Flushes may be costly in large sites (since there's no index
    //  on the timeout field) so schedule next run sometime after
    //  04:30 the day after tomorrow.
    int now = time();
    mapping info = localtime(now);
    int wait = (int) ((24 - info->hour) + 24 + 4.5) * 3600 + random(500);
    background_run(wait, cleanup_process);

    do_cleanup();
  }
  
  protected void init_db()
  {
    // Delay DBManager resolving to before the 'roxen' object is
    // compiled.
    cache = ([]);
    no_expiry = ([]);
    setup_table( );

    // Cleanup exprired entries on start.
    background_run( 10, cleanup_process );
  }

  protected void create( string _name )
  {
    name = _name;
    init_db();
    // Support that the 'local' database moves (not really nessesary,
    // but it won't hurt either)
    master()->resolv( "DBManager.add_dblist_changed_callback" )( init_db );
    get_plugins();
  }

  protected string read_encoded_args( string id, int dont_update_atime )
  {
    GET_DB();
    array res = QUERY("SELECT contents FROM "+name+"2 "
		      " WHERE id = %s", id);
    if(!sizeof(res))
      return 0;
    if (!dont_update_atime)
      QUERY("UPDATE LOW_PRIORITY "+name+"2 "
	    "   SET atime = NOW() "
	    " WHERE id = %s", id);
    return res[0]->contents;
  }

  //  Callback used in replicate.pike
  void create_key( string id, string encoded_args, int|void timeout )
  {
    if (!zero_type(timeout) && (timeout < time(1))) return; // Expired.
    GET_DB();
    array(mapping) rows =
      QUERY("SELECT id, contents, timeout, "
	    "UNIX_TIMESTAMP() - UNIX_TIMESTAMP(atime) as atime_diff "
	    "FROM "+name+"2 "
	    "WHERE id = %s", id );

    foreach( rows, mapping row )
      if( row->contents != encoded_args ) {
      	report_error("ArgCache.create_key(): Duplicate key found! "
		     "Please report this to support@roxen.com:\n"
		     "  id: %O\n"
		     "  old data: %O\n"
		     "  new data: %O\n"
		     "  Updating local database with new value.\n",
		     id, row->contents, encoded_args);

	// Remove the old entry (probably corrupt). No need to update
	// the database since the query below uses REPLACE INTO.
	rows = ({});
      }

    if(sizeof(rows)) {
      // Update atime only if older than threshold.
      if((int)rows[0]->atime_diff > ATIME_THRESHOLD) {
	QUERY("UPDATE LOW_PRIORITY "+name+"2 "
	      "   SET atime = NOW() "
	      " WHERE id = %s", id);
      }

      // Increase timeout when needed.
      if (rows[0]->timeout) {
	if (zero_type(timeout)) {
	  // No timeout, i.e. infinite timeout.
	  QUERY("UPDATE LOW_PRIORITY "+name+"2 "
		"   SET timeout = NULL "
		" WHERE id = %s", id);
	} else if (timeout > (int)rows[0]->timeout) {
	  QUERY("UPDATE LOW_PRIORITY "+name+"2 "
		"   SET timeout = %d "
		" WHERE id = %s", timeout, id);
	}
      }
      return;
    }

    string timeout_sql = zero_type(timeout) ? "NULL" : (string)timeout;
    // Use REPLACE INTO to cope with entries created by other threads
    // as well as corrupted entries that should be overwritten.
    QUERY( "REPLACE INTO "+name+"2 "
	   "(id, contents, ctime, atime, timeout) VALUES "
	   "(%s, " MYSQL__BINARY "%s, NOW(), NOW(), "+timeout_sql+")",
	   id, encoded_args );

    dwerror("ArgCache: Create new key %O\n", id);

    (plugins->create_key-({0}))( id, encoded_args );
  }
  
  protected array plugins;
  protected void get_plugins()
  {
    plugins = ({});
    foreach( ({ "../local/arg_cache_plugins", "arg_cache_plugins" }), string d)
      if( file_stat( d  ) )
	foreach( glob("*.pike", get_dir( d )), string f )
	{
	  object plug = ((program)(d+"/"+f))(this_object());
	  if( !plug->disabled )
	    plugins += ({ plug  });
	}
  }

  protected mapping plugins_read_encoded_args( string id )
  {
    mapping args;
    foreach( (plugins->read_encoded_args - ({0})), function(string:mapping) f )
      if( args = f( id ) )
	return args;
    return 0;
  }

  string store( mapping args, int|void timeout )
  //! Store a mapping (of purely encode_value:able data) in the
  //! argument cache. The string returned is your key to retrieve the
  //! data later.
  //!
  //! @param timeout
  //!    Timeout for the entry in seconds from now. If @expr{UNDEFINED@},
  //!    the entry will not expire.
  {
    if (!zero_type(timeout)) timeout += time(1);
    string encoded_args = encode_value_canonic( args );
    string id = Gmp.mpz(Crypto.SHA1.hash(encoded_args), 256)->digits(36);
    if( cache[ id ] ) {
      if (!no_expiry[id]) {
	// The cache id may have a timeout.
	GET_DB();
	if (zero_type(timeout)) {
	  // No timeout now, but there may have been one earlier.
	  QUERY("UPDATE LOW_PRIORITY "+name+"2 "
		"   SET timeout = NULL "
		" WHERE id = %s "
		"   AND timeout IS NOT NULL", id);
	  no_expiry[id] = 1;
	} else {
	  // Attempt to bump the timeout.
	  QUERY("UPDATE LOW_PRIORITY "+name+"2 "
		"   SET timeout = %d "
		" WHERE id = %s "
		"   AND timeout IS NOT NULL "
		"   AND timeout < %d",
		timeout, id, timeout);
	}
      }
      return id;
    }
    create_key(id, encoded_args, timeout);
    if( sizeof( cache ) >= CACHE_SIZE ) {
      cache = ([]);
      no_expiry = ([]);
    }
    if( !cache[ id ] ) {
      cache[ id ] = args + ([]);
    }
    if (zero_type(timeout)) {
      no_expiry[ id ] = 1;
    }
    return id;
  }


  mapping lookup( string id )
  //! Recall a mapping stored in the cache. 
  {
    if( cache[id] )
      return cache[id] + ([]);
    string encoded_args = (read_encoded_args(id, 0) ||
			   plugins_read_encoded_args(id));
    if(!encoded_args) {
      error("Requesting unknown key (not found in db)\n");
    }
    mapping args = decode_value(encoded_args);
    if( sizeof( cache ) >= CACHE_SIZE ) {
      // Yowza! Garbing bulldoze style. /mast
      cache = ([]);
      no_expiry = ([]);
    }
    cache[id] = args + ([]);
    return args;
  }

  void delete( string id )
  //! Remove the data element stored under the key @[id].
  {
    GET_DB();
    (plugins->delete-({0}))( id );
    m_delete( cache, id );
    
    QUERY( "DELETE FROM "+name+"2 WHERE id = %s", id );
  }

  int key_exists( string id )
  //! Does the key @[id] exist in the cache? Returns 1 if it does, 0
  //! if it was not present.
  {
    if( cache[id] ) return 1;
    if (read_encoded_args(id, 0) || plugins_read_encoded_args(id)) return 1;
    return 0;
  }

#define SECRET_TAG "££"
  
  int write_dump(Stdio.File file, int from_time)
  //! Dumps all entries that have been @[refresh_arg]'ed at or after
  //! @[from_time] to @[file]. All existing entries are dumped if
  //! @[from_time] is zero.
  //!
  //! @returns
  //! Returns 0 if writing failed, -1 if there was no new entries, 1
  //! otherwise.
  //!
  //! @note
  //! Entries added during the execution of this function might or
  //! might not be included in the dump.
  {
    constant FETCH_ROWS = 10000;
    int entry_count = 0;
    
    // The server does only need to use file based argcache
    // replication if the server don't participate in a replicate
    // setup with a shared database.
    if( !has_value((plugins->is_functional-({0}))(), 1) )
    {
      GET_DB();
      int cursor;
      array(string) ids;
      do {
	// Note: No lock is held, so rows might be added between the
	// SELECTs here. That can however only cause a slight overlap
	// between the LIMIT windows since rows are only added and
	// never removed, and read_dump doesn't mind the occasional
	// duplicate entry.
	//
	// A lock will be necessary here if a garb is added, though.

	array(mapping(string:string)) entries;
	if(from_time)
	  // Only replicate entries accessed during the prefetch crawling.
	  entries = 
	    QUERY( "SELECT id, timeout from "+name+"2 "
		   " WHERE rep_time >= FROM_UNIXTIME(%d) "
		   " LIMIT %d, %d", from_time, cursor, FETCH_ROWS);
	else
	  // Make sure _every_ entry is replicated when a dump is created.
	  entries = 
	    QUERY( "SELECT id, timeout from "+name+"2 "
		   " LIMIT %d, %d", cursor, FETCH_ROWS);

	ids = entries->id;
	array(string) timeouts = entries->timeout;
	cursor += FETCH_ROWS;
	
	foreach(ids; int i; string id) {
	  dwerror("ArgCache.write_dump(): %O\n", id);

	  string encoded_args;
	  if (mapping args = cache[id])
	    encoded_args = encode_value_canonic (args);
	  else {
	    encoded_args = read_encoded_args (id, 1);
	    if (!encoded_args) error ("ArgCache entry %O disappeared.\n", id);
	  }

	  string s;
	  if (timeouts[i]) {
	    int timeout = (int)timeouts[i];
	    if (timeout < time(1)) {
	      // Expired entry. Don't replicate.
	      continue;
	    }
	    s = 
	      MIME.encode_base64(encode_value(({ id, encoded_args, timeout })),
				 1)+"\n";
	  } else {
	    // No timeout. Backward-compatible format.
	    s = 
	      MIME.encode_base64(encode_value(({ id, encoded_args })),
				 1)+"\n";
	  }
	  if(sizeof(s) != file->write(s))
	    return 0;
	  entry_count++;
	}
      } while(sizeof(ids) == FETCH_ROWS);
    }
    if (file->write("EOF\n") != 4)
      return 0;
    return entry_count ? 1 : -1;
  }

  string read_dump (Stdio.FILE file)
  // Returns an error message if there was a parse error, 0 otherwise.
  {
    string secret = file->gets();
    // Check if no secret is present -> newstyle package.
    if(!secret || !has_prefix(secret, SECRET_TAG))
      // New pakage found, restore input stream.
      file->ungets(secret);

    string s;
    while(s = file->gets())
    {
      if(s == "EOF")
	return 0;
      array a;
      if(mixed err = catch {
	a = decode_value(MIME.decode_base64(s));
      }) return "Decode failed for argcache record: " + describe_error (err);

      if(sizeof(a) == 4) {
	// Old style argcache dump.
	dwerror("ArgCache.read_dump(): value_id: %O, index_id: %O.\n", a[0], a[2]);
	if (a[2] == -1)
	  // The old write_dump didn't filter out entries with NULL
	  // index_id when from_time was zero, so we ignore them here
	  // instead.
	  dwerror ("ArgCache.read_dump(): entry ignored.\n");
	else {
	  array v = decode_value(a[1]), i = decode_value(a[3]);
#if 0
	  dwerror ("ArgCache.read_dump(): values: %O, indices: %O\n", v, i);
#endif
	  store(mkmapping(i, v));
	}
      } else if ((sizeof(a) == 2) || (sizeof(a) == 3)) {
	// New style argcache dump, possibly with timeout.
	dwerror("ArgCache.read_dump(): %O\n", a[0]);
	create_key(@a);
      } else
	return "Decode failed for argcache record (wrong size on key array)\n";
    }
    if(s != "EOF")
      return "Missing data in argcache file\n";
    return 0;
  }

  void refresh_arg(string id)
  //! Indicate that the entry @[id] needs to be included in the next
  //! @[write_dump]. @[id] must be an existing entry.
  {
    GET_DB();
    QUERY("UPDATE "+name+"2 SET rep_time=NOW() WHERE id = %s", id);
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
  cached_decoders[ charset ]->clear();
  return data;
}

//! Check if a cache key has been marked invalid (aka stale).
int(0..1) invalidp(CacheKey key)
{
  catch {
    return !key || (key->invalidp && key->invalidp());
  };
  return !key;
}

//! Invalidate (mark as stale) a cache key.
void invalidate(CacheKey key)
{
  if (invalidp(key)) return;
  catch {
    if (key->invalidate) {
      key->invalidate();
      return;
    }
  };
  if (key) destruct(key);
}

void create()
{
  // Register localization projects
#define __REG_PROJ Locale.register_project
  __REG_PROJ("roxen_""start",   "translations/%L/roxen_start.xml");
  __REG_PROJ("roxen_""config",  "translations/%L/roxen_config.xml");
  __REG_PROJ("roxen_""message", "translations/%L/roxen_message.xml");
  __REG_PROJ("admin_""tasks",   "translations/%L/admin_tasks.xml");
  Locale.set_default_project_path("translations/%L/%P.xml");
#undef __REG_PROJ

  define_global_variables();

  // for module encoding stuff

  // Pike 7.7 or later - we use the native LDAP module and link the
  // migration alias NewLDAP to it.
  add_constant ("NewLDAP", Protocols.LDAP);

  add_constant( "CFUserDBModule",config_userdb_module );
  
  //add_constant( "ArgCache", ArgCache );
  //add_constant( "roxen.load_image", load_image );

  if (all_constants()["roxen"]) {
    error("Duplicate Roxen object!\n");
  }

  // simplify dumped strings.  
  add_constant( "roxen", this_object());
  //add_constant( "roxen.decode_charset", decode_charset);

//   add_constant( "DBManager", ((object)"base_server/dbs.pike") );

  // This is currently needed to resolve the circular references in
  // RXML.pmod correctly. :P
  master()->resolv ("RXML.refs");
  master()->resolv ("RXML.PXml");
  master()->resolv ("RXML.PEnt");
  foreach(({ "module.pmod","PEnt.pike", "PExpr.pike","PXml.pike",
	     "refs.pmod","utils.pmod" }), string q )
    dump( "etc/modules/RXML.pmod/"+ q );
  dump( "etc/modules/RXML.pmod/module.pmod" );
  master()->add_dump_constant ("RXML.empty_tag_set",
			       master()->resolv ("RXML.empty_tag_set"));

  // Replace Val objects with versions extended for the rxml type system.
  Val->true = Roxen.true;
  Val->false = Roxen.false;
  Val->null = Roxen->sql_null = Roxen.null;

  // Already loaded. No delayed dump possible.
  dump( "etc/roxen_master.pike" );
  dump( "etc/modules/Roxen.pmod" );
  dump( "base_server/config_userdb.pike" );
  dump( "base_server/disk_cache.pike" );
  dump( "base_server/roxen.pike" );
  dump( "base_server/basic_defvar.pike" );
  dump( "base_server/newdecode.pike" );
  dump( "base_server/read_config.pike" );
  dump( "base_server/global_variables.pike" );
  dump( "base_server/module_support.pike" );
  dump( "base_server/socket.pike" );
  dump( "base_server/cache.pike" );
  dump( "base_server/supports.pike" );
  dump( "base_server/hosts.pike");
  dump( "base_server/language.pike");

#ifndef __NT__
  if(!getuid())
    add_constant("Privs", Privs);
  else
#endif /* !__NT__ */
    add_constant("Privs", class {
      void create(string reason, int|string|void uid, int|string|void gid) {}
    });


  DDUMP( "base_server/roxenlib.pike");
  DDUMP( "etc/modules/Dims.pmod");
  DDUMP( "config_interface/boxes/Box.pmod" );
  dump( "base_server/html.pike");

  add_constant( "RoxenModule", RoxenModule);
  add_constant( "ModuleInfo", ModuleInfo );

  add_constant( "load",    load);

  add_constant( "Roxen.set_locale", set_locale );
  add_constant( "Roxen.get_locale", get_locale );

  add_constant( "roxen.locale", locale );
  //add_constant( "roxen.ImageCache", ImageCache );

//int s = gethrtime();
  _configuration = (program)"configuration";
  dump( "base_server/configuration.pike" );
  dump( "base_server/rxmlhelp.pike" );

  // Override the one from prototypes.pike
  add_constant( "Configuration", _configuration );
//report_debug( "[Configuration: %.2fms] ", (gethrtime()-s)/1000.0);
}

mixed get_locale( )
{
  return locale->get();
}

int set_u_and_gid (void|int from_handler_thread)
//! Set the uid and gid to the ones requested by the user. If the
//! sete* functions are available, and the define SET_EFFECTIVE is
//! enabled, the euid and egid is set. This might be a minor security
//! hole, but it will enable roxen to start CGI scripts with the
//! correct permissions (the ones the owner of that script have).
{
#ifndef __NT__
  string u, g;
  int uid, gid;
  array pw;

  if (from_handler_thread && geteuid()) {
    // The euid switch in the backend thread worked here too, so
    // there's no need to do anything.
#ifdef TEST_EUID_CHANGE
    werror ("euid change effective in handler thread.\n");
#endif
    return 1;
  }

  u=query("User");
  sscanf(u, "%s:%s", u, g);
#if 0
  // FIXME: Support caching the uid/gid in the setting
  //        in case of lookup failure further below.
  sscanf(u, "%d", uid);
  sscanf(u, "%s(%d)", u, uid);
  if (g) {
    sscanf(g, "%d", gid);
    sscanf(g, "%s(%d)", g, gid);
  }
#endif /* 0 */
  if(strlen(u))
  {
    if(getuid())
    {
      if (!from_handler_thread)
	report_error(LOC_M(24, "It is possible to change uid and gid only "
			   "if the server is running as root.")+"\n");
    } else {
#ifdef TEST_EUID_CHANGE
      if (Stdio.write_file ("rootonly",
			    "Only root should be able to read this.\n",
			    0600))
	test_euid_change = 1;
#endif

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
      Thread.MutexKey mutex_key;
      object threads_disabled;
      if (!from_handler_thread) {
	// If this is necessary from every handler thread, these
	// things are thread local and thus are no locks necessary.
	if (mixed err = catch { mutex_key = euid_egid_lock->lock(); })
	  master()->handle_error (err);
	threads_disabled = _disable_threads();
      }
#endif

#if constant(seteuid)
      if (geteuid() != getuid()) seteuid (getuid());
#endif

#if constant(initgroups)
      if (mixed err = catch {
	  initgroups(pw[0], gid);
	  // Doesn't always work - David.
	})
	master()->handle_error (err);
#endif

      if (query("permanent_uid")) {
#if constant(setuid)
	if (g) {
#  if constant(setgid)
	  setgid(gid);
	  if (getgid() != gid) {
	    report_error(LOC_M(25, "Failed to set gid.")+"\n");
	    g = 0;
	  }
#  else
	  if (!from_handler_thread)
	    report_warning(LOC_M(26, "Setting gid not supported on this system.")
			   +"\n");
	  g = 0;
#  endif
	}
	setuid(uid);
	if (getuid() != uid) { 
	  report_error(LOC_M(27, "Failed to set uid.")+"\n"); 
	  u = 0;
	}
	if (u && !from_handler_thread)
	  report_notice(CALL_M("setting_uid_gid_permanently",  "eng")
			(uid, gid, u, g));
#else
	if (!from_handler_thread)
	  report_warning(LOC_M(28, "Setting uid not supported on this system.")
			 +"\n");
	u = g = 0;
#endif
      }
      else {
#if constant(seteuid)
	if (g) {
#  if constant(setegid)
	  setegid(gid);
	  if (getegid() != gid) {
	    report_error(LOC_M(29, "Failed to set effective gid.")+"\n");
	    g = 0;
	  }
#  else
	  if (!from_handler_thread)
	    report_warning(LOC_M(30, "Setting effective gid not supported on "
				 "this system.")+"\n");
	  g = 0;
#  endif
	}
	seteuid(uid);
	if (geteuid() != uid) {
	  report_error(LOC_M(31, "Failed to set effective uid.")+"\n");
	  u = 0;
	}
	if (u && !from_handler_thread)
	  report_notice(CALL_M("setting_uid_gid", "eng")(uid, gid, u, g));
#else
	if (!from_handler_thread)
	  report_warning(LOC_M(32, "Setting effective uid not supported on "
			       "this system.")+"\n");
	u = g = 0;
#endif
      }

      enable_coredumps(1);

#ifdef THREADS
      // Paranoia.
      mutex_key = 0;
      threads_disabled = 0;
#endif

      return !!u;
    }
  }
#endif
  return 0;
}

void reload_all_configurations()
{
  Configuration conf;
  array (object) new_confs = ({});
  mapping config_cache = ([]);
  int modified;

  setvars(retrieve("Variables", 0));
  
  foreach(list_all_configurations(), string config)
  {
    mixed err;
    Stat st;
    conf = find_configuration( config );
    if(!(st = config_is_modified(config))) {
      if(conf) {
	config_cache[config] = config_stat_cache[config];
	new_confs += ({ conf });
      }
      continue;
    }
    modified = 1;
    config_cache[config] = st;
    if(conf)
    {
      conf->stop();
      conf->invalidate_cache();
      conf->create(conf->name);
    } else {
      if(err = catch
      {
	conf = enable_configuration(config);
      }) {
	string bt=describe_backtrace(err);
	report_error(LOC_M(33, "Error while enabling configuration %s%s"),
		     config, (bt ? ":\n"+bt : "\n"));
	continue;
      }
      function sp = master()->resolv("DBManager.set_permission");
      catch(sp( "docs",   conf,  1 )); // the docs db can be non-existant
      sp( "local",  conf,  2 );
    }
    if(err = catch
    {
      conf->start( 0 );
      conf->enable_all_modules();
    }) {
      string bt=describe_backtrace(err);
      report_error(LOC_M(33, "Error while enabling configuration %s%s"),
		   config, (bt ? ":\n"+bt : "\n" ));
      continue;
    }
    new_confs += ({ conf });
  }

  foreach(configurations - new_confs, conf)
  {
    modified = 1;
    report_notice(LOC_M(34,"Disabling old configuration %s")+"\n", conf->name);
    conf->stop();
    destruct(conf);
  }
  if(modified) {
    configurations = new_confs;
    fix_config_lookup();
    config_stat_cache = config_cache;
  }
}

private mapping(string:Configuration) config_lookup = ([]);
// Maps config name to config object.

Thread.Local bootstrap_info = Thread.Local();
// Used temporarily at configuration and module initialization to hold
// some info so that it's available even before create() in the
// configuration/module is called.

void fix_config_lookup()
{
  config_lookup = mkmapping (configurations->name, configurations);
#ifdef DEBUG
  if (sizeof (configurations) != sizeof (config_lookup))
    error ("Duplicate configuration names in configurations array: %O",
	   configurations->name);
#endif
}

Configuration get_configuration (string name)
//! Gets the configuration with the given identifier name.
{
#ifdef DEBUG
  if (sizeof (configurations) != sizeof (config_lookup))
    error ("config_lookup out of synch with configurations.\n");
#endif
  return config_lookup[name];
}

private Configuration admin_config;

Configuration get_admin_configuration()
//! Returns the admin UI configuration, which is the one containing a
//! config_filesystem module instance.
{
  return admin_config;
}

Configuration enable_configuration(string name)
{
#ifdef DEBUG
  if (get_configuration (name))
    error ("A configuration called %O already exists.\n", name);
#endif
  bootstrap_info->set (name);
  Configuration cf = _configuration();
  configurations += ({ cf });
  fix_config_lookup();
  return cf;
}

void disable_configuration (string name)
{
  if (Configuration conf = config_lookup[ name ]) {
    configurations -= ({conf});
    fix_config_lookup();
  }
}

void remove_configuration (string name)
{
  disable_configuration (name);
  ::remove_configuration (name);
}

// Enable all configurations
void enable_configurations()
{
  array err;
  configurations = ({});
  config_lookup = ([]);

  foreach(list_all_configurations(), string config)
  {
    int t = gethrtime();
    Configuration conf_obj;
    int is_admin_config;
    report_debug("\nEnabling the configuration %s ...\n", config);
    if(err=catch {
	conf_obj = enable_configuration(config);
	is_admin_config = conf_obj->start(0);
      })
      report_error("\n"+LOC_M(35, "Error while loading configuration %s%s"),
		   config+":\n", describe_backtrace(err)+"\n");
    if (is_admin_config) admin_config = conf_obj;
    report_debug("Enabled %s in %.1fms\n", config, (gethrtime()-t)/1000.0 );
  }
  foreach( configurations, Configuration c )
  {
    if(sizeof( c->registered_urls ) )
      return;
  }
  report_fatal("No configurations could open any ports. Will shutdown.\n");
  restart(0.0, 50);	/* Actually a shutdown, but... */
}

int all_modules_loaded;
void enable_configurations_modules()
{
  if( all_modules_loaded++ ) return;
  foreach(configurations, Configuration config)
    if(mixed err=catch( config->enable_all_modules() ))
      report_error(LOC_M(36, "Error while loading modules in "
			 "configuration %s%s"),
                   config->name+":\n", describe_backtrace(err)+"\n");
}

mapping low_decode_image(string data)
{
  mapping w = Image._decode( data );
  if( w->image ) return w;
  return 0;
}

constant decode_layers = Image.decode_layers;

mapping low_load_image(string f, RequestID id, void|mapping err)
{
  string data;
  if(id->misc->_load_image_called < 5)
  {
    // We were recursing very badly with the demo module here...
    id->misc->_load_image_called++;
    if(!(data=id->conf->try_get_file(f, id, 0, 0, 0, err)))
    {
#ifdef THREADS
      if (sscanf( f, "http://%[^/]", string host ) ||
	  sscanf (f, "https://%[^/]", host)) {
	mapping hd = ([
	  "User-Agent":version(),
	  "Host":host,
	]);
	if (mixed err = catch {
	    data = Protocols.HTTP.get_url_data( f, 0, hd );
	  })
	  master()->handle_error (err);
      }
#endif
      if( !data )
	return 0;
    }
  }
  id->misc->_load_image_called = 0;
  if(!data) return 0;
  return low_decode_image( data );
}

array(Image.Layer)|mapping load_layers(string f, RequestID id, mapping|void opt)
{
  string data;
  mapping res = ([]);
  if(id->misc->_load_image_called < 5)
  {
    // We were recursing very badly with the demo module here...
    id->misc->_load_image_called++;
    if(!(data=id->conf->try_get_file(f, id, 0, 0, 0, res)))
    {
#ifdef THREADS
      if (sscanf( f, "http://%[^/]", string host ) ||
	  sscanf (f, "https://%[^/]", host)) {
	mapping hd = ([
	  "User-Agent":version(),
	  "Host":host,
	]);
	if (mixed err = catch {
	    data = Protocols.HTTP.get_url_data( f, 0, hd );
	  })
	  master()->handle_error (err);
      }
#endif
      if( !data )
	return res;
    }
  }
  id->misc->_load_image_called = 0;
  if(!data) return res;
  return decode_layers( data, opt );
}

Image.Image load_image(string f, RequestID id, mapping|void err)
{
  mapping q = low_load_image( f, id, err );
  if( q ) return q->img;
  return 0;
}

// do the chroot() call. This is not currently recommended, since
// roxen dynamically loads modules, all module files must be
// available at the new location.

private void fix_root(string to)
{
#ifndef __NT__
  if(getuid())
  {
    report_debug("It is impossible to chroot() if the server is not run as root.\n");
    return;
  }

  if(!chroot(to))
  {
    report_debug("Roxen: Cannot chroot to "+to+": ");
#if constant(real_perror)
    real_perror();
#endif
    return;
  }
  report_debug("Root is now "+to+".\n");
#endif
}

void create_pid_file(string where)
{
#ifndef __NT__
  if(!where) return;
//   where = replace(where, ({ "$pid", "$uid" }),
// 		  ({ (string)getpid(), (string)getuid() }));

  object privs = Privs("Deleting old pid file.");
  r_rm(where);
  privs = 0;

  mixed err;

  // Note: The server lock file is often created by the start script, but
  //       there is a race, so this code is here for paranoia reasons.
  if (!Stdio.exist(sprintf("/var/run/roxen-server.%d.pid", getpid())) &&
      !Stdio.exist(sprintf("/tmp/roxen-server.%d.pid", getpid()))) {
    // NB: The following won't work if there's a wrapper process
    //     for Roxen (eg started via gdb, truss or valgrind),
    //     but that shouldn't matter much, since the pid lock file
    //     won't be used in that case anyway.
    privs = Privs("Creating pid lock.");
    if (catch {
	// Try /var/run/ first.
	hardlink(sprintf("/var/run/roxen-start.%d.pid", getppid()),
		 sprintf("/var/run/roxen-server.%d.pid", getpid()));
      } && (err = catch {
	  // And then /tmp/.
	  hardlink(sprintf("/tmp/roxen-start.%d.pid", getppid()),
		   sprintf("/tmp/roxen-server.%d.pid", getpid()));
	})) {
      report_debug("Cannot create the pid lock file %O: %s",
		   sprintf("/tmp/roxen-server.%d.pid", getpid()),
		   describe_error(err));
    }
    privs = 0;
  }
  if(err = catch {
      Stdio.write_file(where, sprintf("%d\n%d\n", getpid(), getppid()));
    })
    report_debug("Cannot create the pid file %O: %s",
		 where, describe_error (err));
#endif
}

Pipe.pipe shuffle(Stdio.File from, Stdio.File to,
		  Stdio.File|void to2,
		  function(:void)|void callback)
{
#if constant(spider.shuffle)
  if(!to2)
  {
    object p = fastpipe( );
    p->input(from);
    p->set_done_callback(callback);
    p->output(to);
    return p;
  } else {
#endif
    // 'fastpipe' does not support multiple outputs.
    Pipe.pipe p = Pipe.pipe();
    if (callback) p->set_done_callback(callback);
    p->output(to);
    if(to2) p->output(to2);
    p->input(from);
    return p;
#if constant(spider.shuffle)
  }
#endif
}

// Dump all threads to the debug log.
void describe_all_threads (void|int ignored, // Might be the signal number.
			   void|object threads_disabled)
{
  if (!threads_disabled)
    // Disable all threads to avoid potential locking problems while we
    // have the backtraces. It also gives an atomic view of the state.
    threads_disabled = _disable_threads();

  array(Thread.Thread) threads = all_threads();

  report_debug("###### Describing all %d pike threads:\n>>\n",
	       sizeof (threads));

  threads = Array.sort_array (
    threads,
    lambda (Thread.Thread a, Thread.Thread b) {
      // Backend thread first, otherwise in id order.
      if (a == backend_thread)
	return 0;
      else if (b == backend_thread)
	return 1;
      else
	return a->id_number() > b->id_number();
    });

  int hrnow = gethrtime();
  foreach (threads, Thread.Thread thread) {
    string thread_descr = "";
    if (string th_name = thread_name(thread, 1))
      thread_descr += " - " + th_name;
    if (int start_hrtime = thread_task_start_times[thread])
      thread_descr += sprintf (" - busy for %.3fs",
			       (hrnow - start_hrtime) / 1e6);
    report_debug(">> ### Thread 0x%x%s:\n",
		 thread->id_number(),
		 thread_descr);
    // Use master()->describe_backtrace to sidestep the background
    // failure wrapper that's active in RUN_SELF_TEST.
    report_debug(">> " +
		 replace (master()->describe_backtrace (thread->backtrace()),
			  "\n", "\n>> ") +
		 "\n");
  }

  array(array) queue = handle_queue->peek_array();

  // Ignore the handle thread shutdown marker, if any.
  queue -= ({0});

  if (!sizeof (queue))
    report_debug ("###### No entries in the handler queue\n");
  else {
    report_debug ("###### %d entries in the handler queue:\n>>\n",
		  sizeof (queue));
    foreach (queue; int i; array task)
      report_debug (">> %d: %s\n", i,
		    replace (debug_format_queue_task (task), "\n", "\n>> "));
    report_debug (">> \n");
  }

  queue = bg_queue->peek_array();

  if (!sizeof (queue))
    report_debug ("###### No entries in the background_run queue\n");
  else {
    report_debug ("###### %d entries in the background_run queue:\n>>\n",
		  sizeof (queue));
    foreach (queue; int i; array task)
      report_debug (">> %d: %s\n", i,
		    replace (debug_format_queue_task (task), "\n", "\n>> "));
    report_debug (">> \n");
  }

  report_debug ("###### Thread and queue dumps done at %s\n", ctime (time()));

  queue = 0;
  threads = 0;
  threads_disabled = 0;

#ifdef DEBUG
  report_debug (RoxenDebug.report_leaks());
#endif
}


// Dump threads by file polling.

constant cdt_poll_interval = 5;	// Seconds.
constant cdt_dump_seq_interval = 60;

string cdt_directory, cdt_filename;

Thread.Thread cdt_thread;
int cdt_next_seq_dump;

void cdt_poll_file()
{
  name_thread(this_thread(), "Dump thread file monitor");
  while (this && query ("dump_threads_by_file")) {
    if (array(string) dir = r_get_dir (cdt_directory)) {
      if (has_value (dir, cdt_filename)) {
	r_rm (cdt_directory + "/" + cdt_filename);
	describe_all_threads();
      }
      else if (time() >= cdt_next_seq_dump) {
	dir = glob (cdt_filename + ".*", dir);
	if (sizeof (dir)) {
	  string file = dir[0];
	  r_rm (cdt_directory + "/" + file);
	  describe_all_threads();
	  sscanf (file, cdt_filename + ".%d", int count);
	  if (--count > 0) {
	    open (cdt_directory + "/" + cdt_filename + "." + count,
		  "cwt");
	    cdt_next_seq_dump = time (1) + cdt_dump_seq_interval;
	  }
	}
      }
    }
    sleep (cdt_poll_interval);
  }
  name_thread(this_thread(), 0);
  cdt_thread = 0;
}

void cdt_changed (Variable.Variable v)
{
  if (cdt_directory && v->query() && !cdt_thread)
    cdt_thread = Thread.thread_create (cdt_poll_file);
}

// ----------------------------------------


constant dump = roxenloader.dump;

program slowpipe, fastpipe;

void initiate_argcache()
{
  int t = gethrtime();
  report_debug( "Initiating argument cache ... \b");
  if( mixed e = catch( argcache = ArgCache("arguments") ) )
  {
    report_fatal( "Failed to initialize the global argument cache:\n" +
#ifdef DEBUG
		  describe_backtrace(e) +
#else /* !DEBUG */
		  describe_error(e) +
#endif /* DEBUG */
		  "\n");
    roxenloader.real_exit(1);
  }
  add_constant( "roxen.argcache", argcache );
  report_debug("\bDone [%.2fms]\n", (gethrtime()-t)/1000.0);
}

#ifdef TIMERS
void show_timers()
{
  call_out( show_timers, 30 );
  array a = values(timers);
  array b = indices( timers );
  sort( a, b );
  reverse(a);
  reverse(b);
  report_notice("Timers:\n");
  for( int i = 0; i<sizeof(b); i++ )
    report_notice( "  %-30s : %10.1fms\n", b[i], a[i]/1000.0 );
  report_notice("\n\n");
}
#endif


protected class GCTimestamp
{
  array self_ref;
  protected void create() {self_ref = ({this_object()});}
  protected void destroy() {
    werror ("GC runs at %s", ctime(time()));
    GCTimestamp();
  }
}

protected int gc_start;

protected mapping(string:int) gc_histogram = ([]);

array argv;
int main(int argc, array tmp)
{
  // __builtin.gc_parameters((["enabled": 0]));
  argv = tmp;
  tmp = 0;

#if 0
  Thread.thread_create (lambda () {
			  while (1) {
			    sleep (10);
			    describe_all_threads();
			  }
			});
#endif

#ifdef LOG_GC_TIMESTAMPS
  Pike.gc_parameters(([ "pre_cb": lambda() {
				    gc_start = gethrtime();
				    werror("GC runs at %s", ctime(time()));
				  },
			"post_cb":lambda() {
				    werror("GC done after %dus\n",
					   gethrtime() - gc_start);
				  },
			"destruct_cb":lambda(object o) {
					gc_histogram[sprintf("%O", object_program(o))]++;
					werror("GC cyclic reference in %O.\n",
					       o);
				      },
			"done_cb":lambda(int n) {
				    if (!n) return;
				    werror("GC zapped %d things.\n", n);
				    mapping h = gc_histogram + ([]);
				    if (!sizeof(h)) return;
				    array i = indices(h);
				    array v = values(h);
				    sort(v, i);
				    werror("GC histogram (accumulative):\n");
				    foreach(reverse(i)[..9], string p) {
				      werror("GC:  %s: %d\n", p, h[p]);
				    }
				  },
		     ]));
  if (!Pike.gc_parameters()->pre_cb) {
    // GC callbacks not available.
    GCTimestamp();
  }
#endif

  // For RBF
  catch(mkdir(getenv("VARDIR") || "../var"));
  
  dbm_cached_get = master()->resolv( "DBManager.cached_get" );

  dbm_cached_get( "local" )->
    query( "CREATE TABLE IF NOT EXISTS "
	   "compiled_formats ("
	   "  md5 CHAR(32) not null primary key,"
	   "  full BLOB not null,"
	   "  enc BLOB not null"
	   ")" );
  master()->resolv( "DBManager.is_module_table" )
    ( 0, "local", "compiled_formats",
      "Compiled and cached log and security pattern code. ");
  
  slowpipe = ((program)"base_server/slowpipe");
  fastpipe = ((program)"base_server/fastpipe");
  dump( "etc/modules/DBManager.pmod" );
  dump( "etc/modules/VFS.pmod" );
  dump( "base_server/slowpipe.pike" );
  dump( "base_server/fastpipe.pike" );
  dump( "base_server/throttler.pike" );

  if (!has_value (compat_levels, roxen_ver))
    report_debug ("Warning: The current version %s does not exist in "
		  "roxen.compat_levels.\n", roxen_ver);

  add_constant( "Protocol", Protocol );
#ifdef TIMERS
  call_out( show_timers, 30 );
#endif

#if constant(SSL.File)
  add_constant( "SSLProtocol", SSLProtocol );
#endif

  dump( "etc/modules/Variable.pmod/module.pmod" );
  dump( "etc/modules/Variable.pmod/Language.pike" );
  dump( "etc/modules/Variable.pmod/Schedule.pike" );

  foreach( glob("*.pike", get_dir( "etc/modules/Variable.pmod/"))
	   -({"Language.pike", "Schedule.pike"}), string f )
    DDUMP( "etc/modules/Variable.pmod/"+f );
  
  DDUMP(  "base_server/state.pike" );
  DDUMP(  "base_server/highlight_pike.pike" );
  DDUMP(  "base_server/wizard.pike" );
  DDUMP(  "base_server/proxyauth.pike" );
  DDUMP(  "base_server/module.pike" );
  DDUMP(  "base_server/throttler.pike" );

  mark_fd(0, "Stdin");
  mark_fd(1, "Stdout");
  mark_fd(2, "Stderr");

  once_mode = (int)Getopt.find_option(argv, "o", "once");

  configuration_dir =
    Getopt.find_option(argv, "d",({"config-dir","configuration-directory" }),
	     ({ "ROXEN_CONFIGDIR", "CONFIGURATIONS" }), "../configurations");

  if(configuration_dir[-1] != '/')
    configuration_dir += "/";

  restore_global_variables(); // restore settings...

  cache.set_total_size_limit (query ("mem_cache_size") * 1024 * 1024);

  if( query("replicate" ) )
  {
    report_notice( "Enabling replication support\n");
    add_constant( "WS_REPLICATE", 1 );
    // Dumping of arg_cache_plugins generates problem when trying to
    // enable/disable argcache replication.
    // call_out( lambda() {
    // 		   dump("arg_cache_plugins/replicate.pike");
    // 		 }, 2 );
  }

  // Dangerous...
  mixed tmp_root;
  if(tmp_root = Getopt.find_option(argv, "r", "root")) fix_root(tmp_root);

  argv -= ({ 0 });
  argc = sizeof(argv);

  fonts = ((program)"base_server/fonts.pike")();

  DDUMP( "languages/abstract.pike" );
  initiate_languages(query("locale"));

  cache_clear_deltas();
  set_locale();

#if constant(syslog)
  init_logger();
#endif
  init_garber();

  initiate_supports();
  initiate_argcache();
  init_configuserdb();
  cache.init_session_cache();

  protocols = build_protocols_mapping();  

  int t = gethrtime();
  report_debug("Searching for pike-modules directories ... \b");
  foreach( find_all_pike_module_directories( ), string d )
    master()->add_module_path( d );
  report_debug("\bDone [%dms]\n", (gethrtime()-t)/1000 );

#ifdef SMTP_RELAY
  smtp_relay_start();
#endif /* SMTP_RELAY */

#ifdef SNMP_AGENT
  //SNMPagent start
  report_debug("SNMPagent configuration checking ... \b");
  if(query("snmp_agent")) {
    // enabling SNMP agent
    snmpagent = SNMPagent();
    snmpagent->enable();
    report_debug("\benabled.\n");
    snmpagent->start_trap();

  } else
    report_debug("\bdisabled.\n");
#endif // SNMP_AGENT

  backend_thread = this_thread();
#ifdef THREADS
  name_thread( backend_thread, "Backend" );
#else
  report_debug("\n"
	       "WARNING: Threads not enabled!\n"
	       "\n");
#endif /* THREADS */

  foreach(({ "testca.pem", "demo_certificate.pem" }), string file_name) {
    if (!sizeof(roxenloader.package_directories)) break;
    string cert;
    if (lfile_path(file_name) == file_name) {
      file_name = roxen_path (roxenloader.package_directories[-1] + "/" +
			      file_name);
      report_notice("Generating a new certificate %s...\n", file_name);
      cert = Roxen.generate_self_signed_certificate("*");
#if constant(Standards.X509)
    } else {
      file_name = roxen_path (lfile_path(file_name));

      // Check if we need to upgrade the cert.
      //
      // Certificates generated by old versions of Pike were
      // plain X.509v1, while certificates generated by Pike 8.0
      // and later are X.509v3 with some required extensions.

      string old_cert = Stdio.read_bytes(file_name);
      if (!old_cert) {
	report_error("Failed to read certificate %s.\n", file_name);
	continue;
      }

      // Note: set_u_and_gid() hasn't been called yet,
      //       so there's no need for Privs.
      Standards.PEM.Messages msgs = Standards.PEM.Messages(old_cert);

      int upgrade_needed;

      foreach(msgs->parts; string part; Standards.PEM.Message msg) {
	if (!has_suffix(part, "CERTIFICATE")) continue;
	Standards.X509.TBSCertificate tbs =
	  Standards.X509.decode_certificate(msg->body);
	upgrade_needed = (tbs->version < 3);
	if (!upgrade_needed) {
	  // NB: This stuff is not only to work around that
	  //     Standards.X509.algorithms is protected, but
	  //     also to avoid having to know about how the
	  //     X509 algorithm sequence is structured.
	  class HashAlgVerifier {
	    inherit Standards.X509.Verifier;
	    constant type = "hash";
	    class HashPKC {
	      inherit Crypto.Sign.State;
	      int(0..1) pkcs_verify(string(8bit) msg,
				    Crypto.Hash h,
				    string(8bit) sign)
	      {
		// Disallow SHA1 and shorter.
		// Allow SHA224 and longer.
		return h && (h->digest_size() >= 28);
	      }
	    };
	    protected void create()
	    {
	      pkc = HashPKC();
	    }
	  };
	  upgrade_needed = !HashAlgVerifier()->verify(tbs->algorithm, "", "");
	}
	break;
      }

      if (!upgrade_needed || (sizeof(msgs->parts) != 2)) continue;

      // NB: We reuse the old key.
      Crypto.Sign key;
      foreach(msgs->parts; string part; Standards.PEM.Message msg) {
	if (!has_suffix(part, "PRIVATE KEY")) continue;
	if (msg->headers["dek-info"]) {
	  // Not supported here.
	  break;
	}
	key = Standards.X509.parse_private_key(msg->body);
      }
      if (!key) continue;

      report_notice("Renewing certificate: %O...\n", file_name);
      cert = Roxen.generate_self_signed_certificate("*", key);
#endif /* constant(Standards.X509) */
    }

    if (cert) {
      // Note: set_u_and_gid() hasn't been called yet,
      //       so there's no need for Privs.
      Stdio.File file = Stdio.File();
      if (!file->open(file_name, "wtc", 0600)) {
	report_error("Couldn't create certificate file %s: %s\n", file_name,
		     strerror (file->errno()));
      } else if (file->write(cert) != sizeof(cert)) {
	rm(file_name);
	report_error("Couldn't write certificate file %s: %s\n", file_name,
		     strerror (file->errno()));
      }
    }
  }

  enable_configurations();

  string pid_file = Getopt.find_option(argv, "p", "pid-file");
  if (pid_file && query("permanent_uid")) rm(pid_file);

  set_u_and_gid(); // Running with the right [e]uid:[e]gid from this point on.

  create_pid_file(pid_file);

  // Done before the modules are dumped.

#ifdef RUN_SELF_TEST
  enable_configurations_modules();
#else
  if( Getopt.find_option( argv, 0, "no-delayed-load" ))
    enable_configurations_modules();
  else
    foreach( configurations, Configuration c )
      if( c->query( "no_delayed_load" ) )
	c->enable_all_modules();
#endif // RUN_SELF_TEST

#ifdef THREADS
  start_handler_threads();
#if constant(Filesystem.Monitor.basic)
  start_fsgarb();
#endif
#endif /* THREADS */

#ifdef TEST_EUID_CHANGE
  if (test_euid_change) {
    Stdio.File f = Stdio.File();
    if (f->open ("rootonly", "r") && f->read())
      werror ("Backend thread can read rootonly\n");
    else
      werror ("Backend thread can't read rootonly\n");
  }
#endif

  // Signals which cause a restart (exitcode != 0)
  foreach( ({ "SIGINT", "SIGTERM" }), string sig)
    catch( signal(signum(sig), async_sig_start(exit_when_done,0)) );

  catch(signal(signum("SIGHUP"),async_sig_start(reload_all_configurations,1)));

  // Signals which cause Roxen to dump the thread state
  foreach( ({ "SIGBREAK", "SIGQUIT",
#ifdef ENABLE_SIGWINCH
	      "SIGWINCH",
#endif
  }), string sig)
    catch( signal(signum(sig),async_sig_start(describe_all_threads,-1)));

  start_time=time();		// Used by the "uptime" info later on.

  restart_suicide_checker();

  {
    array(string) splitdir = roxen_path ("$LOGFILE") / "/";
    cdt_filename = splitdir[-1];
    cdt_directory = splitdir[..sizeof (splitdir) - 2] * "/";
    if (has_suffix (cdt_filename, ".1"))
      cdt_filename = cdt_filename[..sizeof (cdt_filename) - 3];
    cdt_filename += ".dump_threads";
    cdt_changed (getvar ("dump_threads_by_file"));
  }

#ifndef NO_SLOW_REQ_BT
  slow_req_count_changed();
  slow_req_timeout_changed();
  slow_be_timeout_changed();
#endif

#ifdef ROXEN_DEBUG_MEMORY_TRACE
  restart_roxen_debug_memory_trace();
#endif

#ifndef __NT__
  restart_if_stuck( 0 );
#endif
#ifdef __RUN_TRACE
  trace(1);
#endif
  return -1;
}

void check_commit_suicide()
{
#ifdef SUICIDE_DEBUG
  werror("check_commit_suicide(): Engage:%d, schedule: %d, time: %d\n"
	 "                        Schedule: %s",
	 query("suicide_engage"),
	 getvar("suicide_schedule")->get_next( query("last_suicide")),
	 time(),
	 ctime(getvar("suicide_schedule")->get_next( query("last_suicide"))));
#endif /* SUICIDE_DEBUG */
  if (query("suicide_engage")) {
    int next = getvar("suicide_schedule")
      ->get_next( query("last_suicide") );
    if (next >= 0)
      if (next <= time(1)) {
	report_notice("Auto Restart triggered.\n");
	set( "last_suicide", time(1) );
	save( );
	restart();
      } else {
	call_out(check_commit_suicide, next - time(1));
      }
  }
}

void check_suicide( )
{
#ifdef SUICIDE_DEBUG
  werror("check_suicide(): Engage:%d, schedule: %d, time: %d\n"
	 "                 Schedule: %s",
	 query("suicide_engage"),
	 getvar("suicide_schedule")->get_next( query("last_suicide")),
	 time(),
	 ctime(getvar("suicide_schedule")->get_next( query("last_suicide"))));
#endif /* SUICIDE_DEBUG */
  if (query("suicide_engage")) {
    int next = getvar("suicide_schedule")
      ->get_next( query("last_suicide") );
    if( !query("last_suicide") || (next >= 0 && next <= time()) )
    {
#ifdef SUICIDE_DEBUG
      werror("Next suicide is in the past or last time not set. Reseting.\n");
#endif
      set( "last_suicide", time() );
      save( );
    }
  }
}

void restart_suicide_checker()
{
  remove_call_out(check_commit_suicide);
  remove_call_out(check_suicide);
  call_out(check_suicide, 60);
  call_out(check_commit_suicide, 180);	// Minimum uptime: 3 minutes.
}

#ifdef ROXEN_DEBUG_MEMORY_TRACE
protected object roxen_debug_info_obj;
void restart_roxen_debug_memory_trace()
{
  remove_call_out(restart_roxen_debug_memory_trace);

  if (!roxen_debug_info_obj) {
    roxen_debug_info_obj = ((program)"config_interface/actions/debug_info.pike"
)();
  }
  int t = time();
  string html = roxen_debug_info_obj->parse((["real_variables":([])]));
  if (!Stdio.is_dir("../var/debug")) {
    mkdir("../var/debug");
  }
  Stdio.write_file(sprintf("../var/debug/memory_info_%d.rxml", t), html);
  call_out(restart_roxen_debug_memory_trace, 5);
}
#endif

// Called from the administration interface.
string check_variable(string name, mixed value)
{
  switch(name)
  {
#ifndef __NT__
   case "abs_engage":
    if (value)
      // Make sure restart_if_stuck is called from the backend thread.
      call_out(restart_if_stuck, 0, 1);
    else {
      remove_call_out(restart_if_stuck);
      alarm(0);
    }
    break;
  case "abs_timeout":
    if (value < 0) {
      return "The timeout must be >= 0 minutes.";
    }
    break;
#endif

  case "suicide_schedule":
  case "suicide_engage":
    restart_suicide_checker();
    break;

#ifdef SNMP_AGENT
    case "snmp_agent":
      if (value && !snmpagent) {
          report_notice("SNMPagent enabling ...\n");
          snmpagent = SNMPagent();
          snmpagent->enable();
          snmpagent->start_trap();
      }
      if (!value && objectp(snmpagent)) {
          report_notice("SNMPagent disabling ...\n");
          snmpagent->stop_trap();
          snmpagent->disable();
          snmpagent = 0;
      }
      break;
#endif // SNMP_AGENT

  }
}

int is_ip(string s)
{
  return s &&
    (sscanf(s,"%*d.%*d.%*d.%*d%*c")==4 || // IPv4
     has_value (s, ":"));	// IPv6
}

//! @ignore
DECLARE_OBJ_COUNT;
//! @endignore

protected string _sprintf( )
{
  return "roxen()" + OBJ_COUNT;
}


// Logging

class LogFormat			// Note: Dumping won't work if protected.
{
  protected string url_encode (string str)
  {
    // Somewhat like Roxen.http_encode_url, but only encode enough
    // chars to avoid ambiguity in typical log formats. Notably, UTF-8
    // encoded chars aren't URL encoded too, to make the log easier to
    // view in any UTF-8 aware editor or viewer.
    return replace (
      string_to_utf8 (str), ({
	// Control chars.
	"\000", "\001", "\002", "\003", "\004", "\005", "\006", "\007",
	"\010", "\011", "\012", "\013", "\014", "\015", "\016", "\017",
	"\020", "\021", "\022", "\023", "\024", "\025", "\026", "\027",
	"\030", "\031", "\032", "\033", "\034", "\035", "\036", "\037",
	"\177",
	// The escape char.
	"%",
	// Basic log format separators.
	" ", "\"", "'",
      }),
      ({
	"%00", "%01", "%02", "%03", "%04", "%05", "%06", "%07",
	"%08", "%09", "%0a", "%0b", "%0c", "%0d", "%0e", "%0f",
	"%10", "%11", "%12", "%13", "%14", "%15", "%16", "%17",
	"%18", "%19", "%1a", "%1b", "%1c", "%1d", "%1e", "%1f",
	"%7f",
	"%25",
	"%20", "%22", "%27",
      }));
  }

  protected int rusage_time;
  protected mapping(string:int) rusage_data;
  protected void update_rusage()
  {
    if(!rusage_data || time(1) != rusage_time)
    {
      rusage_data = (["utime": 1, "stime": 1]) & System.getrusage();
      rusage_time = time(1);
    }
  }

  protected int server_cputime()
  {
    update_rusage();
    if(rusage_data)
      return rusage_data->utime + rusage_data->stime;
    return 0;
  }

  protected int server_usertime()
  {
    update_rusage();
    if(rusage_data)
      return rusage_data->utime;
    return 0;
  }

  protected int server_systime()
  {
    update_rusage();
    if(rusage_data)
      return rusage_data->stime;
    return 0;
  }

  protected string std_date(mapping(string:int) ct) {
    return(sprintf("%04d-%02d-%02d",
		   1900+ct->year,ct->mon+1, ct->mday));
  }
 
  protected string std_time(mapping(string:int) ct) {
    return(sprintf("%02d:%02d:%02d",
		   ct->hour, ct->min, ct->sec));
  }

  // CERN date formatter. Note similar code in Roxen.pmod.

  protected constant months = ({ "Jan", "Feb", "Mar", "Apr", "May", "Jun",
				 "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" });

  protected int chd_lt;
  protected string chd_lf;

  protected string cern_http_date(int t, mapping(string:int) ct)
  {
    if( t == chd_lt )
      // Interpreter lock assumed here.
      return chd_lf;

    string c;
    int tzh = ct->timezone/3600;
    if(tzh > 0)
      c="-";
    else {
      tzh = -tzh;
      c="+";
    }

    c = sprintf("%02d/%s/%04d:%02d:%02d:%02d %s%02d00",
		ct->mday, months[ct->mon], 1900+ct->year,
		ct->hour, ct->min, ct->sec, c, tzh);

    chd_lt = t;
    // Interpreter lock assumed here.
    chd_lf = c;

    return c;
  }
  
  protected string host_ip_to_int(string s)
  {
    int a, b, c, d;
    sscanf(s, "%d.%d.%d.%d", a, b, c, d);
    return sprintf("%c%c%c%c",a, b, c, d);
  }

  protected string extract_user(string from)
  {
    array tmp;
    if (!from || sizeof(tmp = from/":")<2)
      return "-";
    return tmp[0];      // username only, no password
  }

  void log_access( function do_write, RequestID id, mapping file );

  void log_event (function do_write, string facility, string action,
		  string resource, mapping(string:mixed) info);

  protected void do_async_write( string host, string data,
				 string ip, function c )
  {
    if( c ) 
      c( replace( data, "\4711", (host||ip) ) );
  }
}

protected mapping(string:function) compiled_log_access = ([ ]);
protected mapping(string:function) compiled_log_event = ([ ]);

#define LOG_ASYNC_HOST		1
#define LOG_NEED_COOKIES	2
#define LOG_NEED_TIMESTAMP	4
#define LOG_NEED_LTIME		(8 | LOG_NEED_TIMESTAMP)
#define LOG_NEED_GTIME		(16 | LOG_NEED_TIMESTAMP)

// Elements of a format array arr:
// arr[0]: sprintf format for access logging (run_log_format).
// arr[1]: Code for the corresponding sprintf argument of arr[0].
// arr[2]: sprintf format for event logging (run_log_event_format).
//   May be 0 to reuse arr[0] and arr[1].
//   May be 1 to indicate that an attempt is made to look up the
//   variable in the info mapping. If it isn't found then arr[3] is
//   used as fallback. The sprintf format string is always "%s" in
//   this case.
// arr[3]: Code for the corresponding sprintf argument of arr[2].
// arr[4]: Flags.

protected constant formats = ([

  // Used for both access and event logging
  "date":		({"%s", "std_date (ltime)", 0, 0, LOG_NEED_LTIME}),
  "time":		({"%s", "std_time (ltime)", 0, 0, LOG_NEED_LTIME}),
  "cern-date":		({"%s", "cern_http_date (timestamp, ltime)",
			  0, 0, LOG_NEED_LTIME}),
  "utc-date":		({"%s", "std_date (gtime)", 0, 0, LOG_NEED_GTIME}),
  "utc-time":		({"%s", "std_time (gtime)", 0, 0, LOG_NEED_GTIME}),
  "bin-date":		({"%4c", "timestamp", 0, 0, LOG_NEED_TIMESTAMP}),
  // FIXME: There is no difference between $resource and $full-resource.
  "resource":		({"%s", ("(string)"
				 "(request_id->raw_url||"
				 " (request_id->misc->common&&"
				 "  request_id->misc->common->orig_url)||"
				 " request_id->not_query)"),
			  "%s" , "url_encode (resource)", 0}),
  "server-uptime":	({"%d", "max(1, timestamp - roxen->start_time)",
			  0, 0, 0}),
  "server-cputime":	({"%d", "server_cputime()", 0, 0, 0}),
  "server-usertime":	({"%d", "server_usertime()", 0, 0, 0}),
  "server-systime":	({"%d", "server_systime()", 0, 0, 0}),

  // Used for access logging
  "host":		({"\4711" /* unlikely to occur normally */, 0,
			  1, "\"-\"", LOG_ASYNC_HOST}),
  "vhost":		({"%s", "(request_id->misc->host||\"-\")",
			  1, "\"-\"", 0}),
  "ip-number":		({"%s", "(string)request_id->remoteaddr",
			  1, "\"0.0.0.0\"", 0}),
  "bin-ip-number":	({"%s", "host_ip_to_int(request_id->remoteaddr)",
			  1, "\"\\0\\0\\0\\0\"", 0}),
  "method":		({"%s", "(string)request_id->method",
			  1, "\"-\"", 0}),
  "full-resource":	({"%s", ("(string)"
				 "(request_id->raw_url||"
				 " (request_id->misc->common&&"
				 "  request_id->misc->common->orig_url)||"
				 " request_id->not_query)"),
			  "%s" , "url_encode (resource)", 0}),
  "cs-uri-stem":	({"%s", ("(string)"
				 "((request_id->misc->common&&"
				 "  request_id->misc->common->orig_url)||"
				 " request_id->not_query||"
				 " (request_id->raw_url && "
				 "  (request_id->raw_url/\"?\")[0])||"
				 " \"-\")"),
			  "%s" , "url_encode (resource)", 0}),
  "cs-uri-query":	({"%s", "(string)(request_id->query||\"-\")",
			  1, "\"-\"", 0}),
  // FIXME: There is no difference between $real-resource and
  // $real-full-resource.
  "real-resource":	({"%s", ("(string)(request_id->raw_url||"
				 "         request_id->not_query)"),
			  "%s" , "url_encode (resource)", 0}),
  "real-full-resource":	({"%s", ("(string)(request_id->raw_url||"
				 "         request_id->not_query)"),
			  "%s" , "url_encode (resource)", 0}),
  "real-cs-uri-stem":	({"%s", ("(string)(request_id->not_query||"
				 "         (request_id->raw_url && "
				 "          (request_id->raw_url/\"?\")[0])||"
				 "         \"-\")"),
			  "%s" , "url_encode (resource)", 0}),
  "protocol":		({"%s", "(string)request_id->prot", 1, "\"-\"", 0}),
  "scheme":             ({"%s", "(string)((request_id->port_obj && "
			  "request_id->port_obj->prot_name) || \"-\")",
			  1, "\"-\"", 0 }),
  "response":		({"%d", "(int)(file->error || 200)", 1, "\"-\"", 0}),
  "bin-response":	({"%2c", "(int)(file->error || 200)", 1, "\"\\0\\0\"", 0}),
  "length":		({"%d", "(int)file->len", 1, "\"0\"", 0}),
  "bin-length":		({"%4c", "(int)file->len", 1, "\"\\0\\0\\0\\0\"", 0}),
  "queue-length":	({"%d", "(int) request_id->queue_length",
			  1, "\"-\"", 0}),
  "request-time":	({"%1.4f", ("(float)(gethrtime() - "
				    "        request_id->hrtime) /"
				    "1000000.0"),
			  1, "\"-\"", 0}),
  "queue-time":		({"%1.4f",
			  "(float) request_id->queue_time / 1000000.0",
			  1, "\"-\"", 0}),
  "handle-time":	({"%1.4f",
			  "(float) request_id->handle_time / 1000000.0",
			  1, "\"-\"", 0}),
  "handle-cputime":	({
#if constant(System.CPU_TIME_IS_THREAD_LOCAL)
    "%1.4f", "(float) request_id->handle_vtime / 1000000.0",
#else
    "%s", "\"-\"",
#endif
    1, "\"-\"", 0}),
  "etag":		({"%s", "request_id->misc->etag || \"-\"",
			  1, "\"-\"", 0}),
  "referrer":		({"%s", ("sizeof(request_id->referer||({}))?"
				 "request_id->referer[0]:\"-\""),
			  1, "\"-\"", 0}),
  "referer":		({"%s", ("sizeof(request_id->referer||({}))?"
				 "request_id->referer[0]:\"-\""),
			  1, "\"-\"", 0}),
  "user-agent":		({"%s", ("request_id->client?"
				 "request_id->client*\"%20\":\"-\""),
			  1, "\"-\"", 0}),
  "user-agent-raw":	({"%s", ("request_id->client?"
				 "request_id->client*\" \":\"-\""),
			  1, "\"-\"", 0}),
  "user":		({"%s", "extract_user( request_id->realauth )",
			  1, "\"-\"", 0}),
  "user-id":		({"%s", ("(request_id->cookies&&"
				 " request_id->cookies->RoxenUserID)||"
				 "(request_id->misc->moreheads&&"
				 " request_id->misc->"
				 "   moreheads[\"Set-Cookie\"]&&"
				 " request_id->parse_cookies&&"
				 " request_id->parse_cookies("
				 "   request_id->misc->"
				 "     moreheads[\"Set-Cookie\"])->"
				 "   RoxenUserID)||"
				 "\"0\""),
			  1, "\"-\"", 0}),
  "content-type":	({"%s", ("(((arrayp(file->type) ? "
				 "file->type[0] : file->type) "
				 "|| \"-\") / \";\")[0]"),
			  1, "\"-\"", 0}),
  "cookies":		({"%s", ("arrayp(request_id->request_headers->cookie)?"
				 "request_id->request_headers->cookie*\";\":"
				 "request_id->request_headers->cookie||\"\""),
			  1, "\"-\"", 0}),
  "cache-status":	({"%s", ("sizeof(request_id->cache_status||({}))?"
				 "indices(request_id->cache_status)*\",\":"
				 "\"nocache\""),
			  1, "\"-\"", 0}),
  "eval-status":	({"%s", ("sizeof(request_id->eval_status||({}))?"
				 "indices(request_id->eval_status)*\",\":"
				 "\"-\""),
			  1, "\"-\"", 0}),
  "protcache-cost":	({"%d", "request_id->misc->protcache_cost",
			  1, "\"-\"", 0}),
  "xff":		({"%s", ("arrayp(request_id->request_headers["
				 "\"x-forwarded-for\"]) ? "
				 "(request_id->request_headers["
				 "\"x-forwarded-for\"][-1] / \",\")[0] :"
				 "((request_id->request_headers["
				 "\"x-forwarded-for\"] || \"-\") / \",\")[0]"),
			  1, "\"-\"", 0 }),

  // Used for event logging
  "facility":		({"-", 0, "%s", "facility", 0}),
  "action":		({"-", 0, "%s", "action", 0}),
]);

void run_log_format( string fmt, function c, RequestID id, mapping file )
{
  (compiled_log_access[ fmt ] ||
   compile_log_format( fmt )->log_access) (c,id,file);
}

void run_log_event_format (string fmt, function cb,
			   string facility, string action, string resource,
			   mapping(string:mixed) info)
{
  (compiled_log_event[ fmt ] ||
   compile_log_format( fmt )->log_event) (cb, facility, action,
					  resource, info);
}

protected LogFormat compile_log_format( string fmt )
{
  add_constant( "___LogFormat", LogFormat );

  // Note similar code in compile_security_pattern.

  string kmd5 = md5( fmt );

  object con = dbm_cached_get("local");

  {
    array tmp =
      con->query("SELECT full,enc FROM compiled_formats WHERE md5=%s", kmd5 );

    if( sizeof(tmp) && (tmp[0]->full == fmt) )
    {
      LogFormat lf;
      if (mixed err = catch {
	  lf = decode_value( tmp[0]->enc, master()->Decoder() )();
	}) {
	if (describe_error (err) !=
	    "Cannot decode programs encoded with other pike version.\n")
	  report_warning ("Decoding of dumped log format failed "
			  "(will recompile): %s", describe_backtrace(err));
      }

      if (lf && lf->log_access) {
	// Check that it's a new style log program (old ones have log()
	// instead of log_access()).
	compiled_log_access[fmt] = lf->log_access;
	compiled_log_event[fmt] = lf->log_event;
	return lf;
      }
    }
  }

  array parts = fmt/"$";
  string a_format = parts[0], e_format = parts[0];
  array a_args = ({}), e_args = ({});
  int log_flags = 0;
  int add_nl = 1;

#define DO_ES(X) replace(X, ({"\\n", "\\r", "\\t", "%"}),		\
			 ({ "\n", "\r", "\t", "%%" }) )

  foreach( parts[1..], string part )
  {
    sscanf (part, "%[-_a-zA-Z0-9]%s", string kwd, part);
    kwd = replace (kwd, "_", "-");

    if (array(string|int) spec = formats[kwd]) {
      [string a_fmt, string a_code,
       string|int e_fmt, string e_code, int flags] = spec;
      string escaped = DO_ES (part);
      a_format += a_fmt + escaped;
      if( a_code ) a_args += ({ a_code });
      if (!e_fmt) e_fmt = a_fmt, e_code = a_code;
      else if (e_fmt == 1) {
	e_fmt = "%s";
	e_code = sprintf ("info && !zero_type (info[%O]) ? "
			  "url_encode ((string) info[%O]) : (%s)",
			  kwd, kwd, e_code);
      }
      e_format += e_fmt + escaped;
      if (e_code) e_args += ({e_code});
      log_flags |= flags;
      continue;
    }

    switch (kwd) {
      case "char":
	if( sscanf( part, "(%d)%s", int c, part ) == 2 ) {
	  string s = sprintf( "%"+(c<0?"-":"")+"c", abs( c ) )+DO_ES(part);
	  a_format += s, e_format += s;
	  continue;
	}
	break;
      case "wchar":
	if( sscanf( part, "(%d)%s", int c, part ) == 2 ) {
	  string s = sprintf( "%"+(c<0?"-":"")+"2c", abs( c ) )+DO_ES(part);
	  a_format += s, e_format += s;
	  continue;
	}
	break;
      case "int":
	if( sscanf( part, "(%d)%s", int c, part ) == 2 ) {
	  string s = sprintf( "%"+(c<0?"-":"")+"4c", abs( c ) )+DO_ES(part);
	  a_format += s, e_format += s;
	  continue;
	}
	break;
      case "":
	if( part[0] == '^' )
	{
	  string escaped = DO_ES(part[1..]);
	  a_format += escaped, e_format += escaped;
	  add_nl = 0;
	  continue;
	}
	break;
    }

    a_format += "-" + DO_ES (part);

    // Any unknown variable is indexed from the info mapping for events.
    e_format += "%s" + DO_ES (part);
    e_args += ({sprintf ("info && !zero_type (info[%O]) ? "
			 "url_encode ((string) info[%O]) : \"-\"",
			 kwd, kwd)});
  }
  if( add_nl ) a_format += "\n", e_format += "\n";

  string a_func = #"
    void log_access( function callback, RequestID request_id, mapping file )
    {
      if(!callback) return;";
  string e_func = #"
    void log_event (function callback, string facility, string action,
		    string resource, mapping(string:mixed) info)
    {
      if(!callback) return;";

  if (log_flags & LOG_NEED_TIMESTAMP) {
    string c = #"
      int timestamp = time (1);";
    a_func += c, e_func += c;
  }
  if (log_flags & LOG_NEED_LTIME) {
    string c = #"
      mapping(string:int) ltime = localtime (timestamp);";
    a_func += c, e_func += c;
  }
  if (log_flags & LOG_NEED_GTIME) {
    string c = #"
      mapping(string:int) gtime = gmtime (timestamp);";
    a_func += c, e_func += c;
  }

  if (log_flags & LOG_NEED_COOKIES) {
    a_func += #"
      request_id->init_cookies();";
  }

  a_func += sprintf(#"
      string data = sprintf( %O%{,
	%s%} );", a_format, a_args );
  e_func += sprintf(#"
      string data = sprintf( %O%{,
	%s%} );", e_format, e_args );
 
  if (log_flags & LOG_ASYNC_HOST)
  {
    a_func += #"
      roxen.ip_to_host(request_id->remoteaddr,do_async_write,
                       data, request_id->remoteaddr, callback );";
  } else {
    a_func += #"
      callback( data );";
  }
  a_func += #"
    }
";

  e_func += #"
      callback (data);
    }
";

  string src = #"
    inherit ___LogFormat;" + a_func + e_func;
  program res;
  if (mixed err = catch (res = compile_string (src))) {
    werror ("Failed to compile program: %s\n", src);
    throw (err);
  }
  mixed err = catch {
    string enc = encode_value(res, master()->Encoder (res));

    con->query("REPLACE INTO compiled_formats (md5,full,enc) VALUES (%s,%s,%s)",
	     kmd5, fmt, enc);
    };
  if (err) {
    master()->handle_error(err);
  }

  LogFormat lf = res();
  compiled_log_access[fmt] = lf->log_access;
  compiled_log_event[fmt] = lf->log_event;
  return lf;
}


// Security patterns

//! This array contains the compilation information for the different
//! security checks for e.g. @tt{htaccess@}. The layout of the top array is
//! a quadruple of sscanf string that the security command should match,
//! the number of arguments that it takes, an array with the actual
//! compilation information, and a symbol identifying the class of tests
//! the test belongs to.
//!
//! @array
//!   @elem string command_sscanf_string
//!     String to be passed as second argument to @[array_sscanf()]
//!     to perform the match for the pattern.
//!   @elem int(0..) number_of_arguments
//!     Number of elements expected in the array returned by
//!     @[array_sscanf()] for a proper match.
//!   @elem array(function|string|int|multiset) actual_tests
//!     In the tests array the following types has the following meaning:
//!     @mixed
//!       @type function
//!         The function will be run during compilation. It gets the values
//!         acquired through sscanf-ing the command as input and should return
//!         an array with corresponding data.
//!       @type string
//!         The string will be compiled into the actual test code. It is
//!         first modified as
//!         @expr{str = sprintf(str, @@args)@}
//!         where args are the arguments from the command after it has been
//!         processed by the provided function, if any.
//!       @type multiset
//!         Strings in a multiset will be added before the string above.
//!         should typically be used for variable declarations.
//!       @type int
//!         Signals that an authentication request should be sent to the user
//!         upon failure.
//!     @endmixed
//!   @elem string state_symbol_string
//!     Used to group the results from a class of tests.
//!     Currently the following values are used:
//!     @string
//!       @value "ip"
//!       @value "user"
//!       @value "group"
//!       @value "time"
//!       @value "referer"
//!       @value "day"
//!       @value "language"
//!       @value "luck"
//!     @endstring
//! @endarray
//! 
//! @note
//!   It's up to the security checks in this file to ensure that
//!   nothing is overcached. All patterns that perform checks using
//!   information from the client (such as remote address, referer etc)
//!   @b{have@} to use @[RequestID()->register_vary_callback()] (preferred),
//!   or @[NOCACHE()] or @[NO_PROTO_CACHE()]. It's not necessary, however,
//!   to do this for checks that use the authentication module API, since
//!   then it's up to the user database and authentication modules to ensure
//!   that nothing is overcached.
//!
//! @seealso
//!   @[RequestID()->register_vary_callback()], @[NOCACHE()],
//!   @[NO_PROTO_CACHE()], @[array_sscanf()]
array(array(string|int|array)) security_checks = ({
  ({ "ip=%s", 1, ({
    lambda(string x) {
      mapping(int:array(int)) ip_masks = ([]);
      array(string) globs = ({});
      string ret;
      foreach(x/",", string ip_mask) {
	if (sscanf(ip_mask, "%s:%s", string ip, string mask) == 2) {
	  int m = Roxen.ip_to_int(mask);
	  if (m & 0x80000000) m -= 0x100000000;
	  ip_masks[m] += ({ Roxen.ip_to_int(ip)  });
	} else if (sscanf(ip_mask, "%s/%d", string ip, int mask) == 2) {
	  mask = -1 - (0xffffffff >> mask);
	  ip_masks[mask] += ({ Roxen.ip_to_int(ip) });
	} else {
	  globs += ({ ip_mask });
	}
      }
      if (sizeof(ip_masks)) {
	foreach(ip_masks; int mask; array(int) ip) {
	  if (!mask) continue;
	  if (ret) ret += " ||\n        ";
	  else ret = "";
	  if (sizeof(ip) == 1) {
	    ret +=
	      sprintf("((remote_ip & ~0x%08x) == 0x%08x)",
		      ~mask, ip[0] & mask);
	  } else {
	    ret +=
	      sprintf("(<%{0x%08x,%}>)[remote_ip & ~0x%08x]",
		      map(ip, `&, mask), ~mask);
	  }
	}
      }
      foreach(globs, string glob) {
	if (ret) ret += " ||\n        ";
	else ret = "";
	ret += sprintf("glob(%O, id->remoteaddr)", glob);
      }
      return ({
	ret,
      });
    },
#if defined(SECURITY_PATTERN_DEBUG) || defined(HTACCESS_DEBUG)
    "    report_debug(sprintf(\"Verifying against IP %%O (0x%%08x).\\n\",\n"
    "                         id->remoteaddr, remote_ip));\n"
#endif /* SECURITY_PATTERN_DEBUG || HTACCESS_DEBUG */
    "    if (%s)",
    (< "  int remote_ip = Roxen.ip_to_int(id->remoteaddr)" >),
  }), "ip", }),
  ({ "user=%s",1,({ 1,
    lambda( string x ) {
      return ({sprintf("(< %{%O, %}>)", x/"," )});
    },

    "    if (((user || (user = authmethod->authenticate(id, userdb_module)))\n"
    "          && ((%[0]s->any) || (%[0]s[user->name()]))) || %[0]s->ANY) ",
    (<"  User user" >),
   // No need to NOCACHE () here, since it's up to the
   // auth-modules to do that.
  }), "user", }),
  ({ "group=%s",1,({ 1,
    lambda( string x ) {
      return ({sprintf("(< %{%O, %}>)", x/"," )});
    },
    "    if ((user || (user = authmethod->authenticate(id, userdb_module)))\n"
    "        && ((%[0]s->any && sizeof(user->groups())) ||\n"
    "            sizeof(mkmultiset(user->groups())&%[0]s)))",
    (<"  User user" >),
   // No need to NOCACHE () here, since it's up to the
   // auth-modules to do that.
  }), "group", }),
  ({ "dns=%s",1,({
    "    if(!dns && \n"
    "       ((dns=roxen.quick_ip_to_host(id->remoteaddr))==id->remoteaddr))\n"
    "      if( (id->misc->delayed+=0.1) < 1.0 )\n"
    "        return Roxen.http_try_again( 0.1 );\n"
    "    if (sizeof(filter(%[0]O/\",\",\n"
    "                      lambda(string q){return glob(lower_case(q),lower_case(dns));})))",
    (< "  string dns" >),
  }), "ip", }),
  ({ "time=%d:%d-%d:%d",4,({
    (< "  mapping l = localtime(time(1))" >),
    (< "  int th = l->hour, tm = l->min" >),
    // No need to NOCACHE() here, does not depend on client.
    "    if (((th >= %[0]d) && (tm >= %[1]d)) &&\n"
    "        ((th <= %[2]d) && (tm <= %[3]d)))",
  }), "time", }),
  ({ "referer=%s", 1, ({
    (<
      "  string referer = sizeof(id->referer||({}))?id->referer[0]:\"\"; "
    >),
    "    if( sizeof(filter(%[0]O/\",\",\n"
    "                      lambda(string q){return glob(q,referer);})))",
  }), "referer", }),
  ({ "day=%s",1,({
    lambda( string q ) {
      multiset res = (<>);
      foreach( q/",", string w ) if( (int)w )
	  res[((int)w % 7)] = 1;
	else
	  res[ (["monday":1,"thuesday":2,"wednesday":3,"thursday":4,"friday":5,
		 "saturday":6,"sunday":0,"mon":1, "thu":2, "wed":3, "thu":4,
		 "fri":5, "sat":6, "sun":0, ])[ lower_case(w) ] ] = 1;
      return ({sprintf("(< %{%O, %}>)", (array)res)});
    },
    (< "  mapping l = localtime(time(1))" >),
    // No need to NOCACHE() here, does not depend on client.
    "    if (%[0]s[l->wday])"
  }), "day", }),
  ({ "accept_language=%s",1,({
    "    if (has_value(id->misc->pref_languages->get_languages(), %O))",
    (<"  NO_PROTO_CACHE()" >),
  }), "language", }),
  ({ "luck=%d%%",1,({
    lambda(int luck) { return ({ 100-luck }); },
    // Not really any need to NOCACHE() here, since it does not depend
    // on client. However, it's supposed to be totally random.
    "    if( random(100)<%d )",
    (<"  NOCACHE()" >),
  }), "luck", }),
});

#define DENY  0
#define ALLOW 1

function(RequestID:mapping|int) compile_security_pattern( string pattern,
							  RoxenModule m )
//! Parse a security pattern and return a function that when called
//! will do the checks required by the format.
//!
//! The syntax is:
//! 
//!  userdb userdatabase module
//!  authmethod authentication module
//!  realm realm name
//!
//!  Below, CMD is one of 'allow' and 'deny'
//! 
//!  CMD ip=ip/bits[,ip/bits]  [return]
//!  CMD ip=ip:mask[,ip:mask]  [return]
//!  CMD ip=pattern            [return]
//! 
//!  CMD user=name[,name,...]  [return]
//!  CMD group=name[,name,...] [return]
//! 
//!  CMD dns=pattern           [return]
//!
//!  CMD day=pattern           [return]
//! 
//!  CMD time=<start>-<stop>   [return]
//!       times in HH:mm format
//!
//!  CMD referer=pattern       [return]
//!       Check the referer header.
//!
//!  CMD accept_language=language  [return]
//!
//!  CMD luck=entry_chance%    [return]
//!       Defines the minimum level of luck required. All attempts
//!       gets accepted at 0%, and no attempts gets accepted at 100%.
//!
//!  pattern is a glob pattern.
//!
//!  return means that reaching this command results in immediate
//!  return, only useful for 'allow'.
//! 
//! 'deny' always implies a return, no futher testing is done if a
//! 'deny' match.
{
  // Now, this cache is not really all that performance critical, I
  // mostly coded it as a proof-of-concept, and because it was more
  // fun that trying to find the bug in the image-cache at the moment.

  // Note similar code in compile_log_format.
  if (pattern == "")
    return 0;
  string kmd5 = md5( pattern );

#if !defined(HTACCESS_DEBUG) && !defined(SECURITY_PATTERN_DEBUG)
  array tmp =
    dbm_cached_get( "local" )
    ->query("SELECT full,enc FROM compiled_formats WHERE md5=%s", kmd5 );

  if( sizeof(tmp) && (tmp[0]->full == pattern) )
  {
    mixed err = catch {
      return decode_value( tmp[0]->enc, master()->Decoder() )()->f;
    };
// #ifdef DEBUG
    if (describe_error (err) !=
	"Cannot decode programs encoded with other pike version.\n")
      report_warning ("Decoding of dumped security pattern failed "
		      "(will recompile):\n%s", describe_backtrace(err));
// #endif
  }
#endif /* !defined(HTACCESS_DEBUG) && !defined(SECURITY_PATTERN_DEBUG) */


  string code = "";
  array variables = ({ "  object userdb_module",
		       "  object authmethod = id->conf",
		       "  string realm = \"User\"",
		       "  mapping(string:int|mapping) state = ([])",
		       "  id->register_vary_callback(0, vary_cb)",
  });

  // Some state variables for optimizing.
  int all_shorted = 1;			// All allow patterns have return.
  int need_auth = 0;			// We need auth for some checks.
  int max_short_code = 0;		// Max fail code for return checks.
  int patterns;				// Number of patterns.
  multiset(string) checks = (<>);	// Checks in state.

  foreach( pattern / "\n", string line )
  {
    line = String.trim_all_whites( line );
    if( !strlen(line) || line[0] == '#' )
      continue;
    sscanf( line, "%[^#]#", line );

    int cmd;

    if( sscanf( line, "allow %s", line ) )
      cmd = ALLOW;
    else if( sscanf( line, "deny %s", line ) )
      cmd = DENY;
    else if( sscanf( line, "userdb %s", line ) )
    {
      line = String.trim_all_whites( line );
      if( line == "config_userdb" )
	code += "    userdb_module = roxen.config_userdb_module;\n";
      else if( line == "all" )
	code += "    userdb_module = 0;\n";
      else if( !m->my_configuration()->find_user_database( line ) )
	m->report_notice( LOC_M( 58,"Syntax error in security patterns: "
				 "Cannot find the user database '%s'")+"'\n",
			line);
      else
	code +=
	  sprintf("    userdb_module = id->conf->find_user_database( %O );\n",
		  line);
      continue;
    } 
    else if( sscanf( line, "authmethod %s", line ) )
    {
      line = String.trim_all_whites( line );
      if( line == "all" )
	code += "    authmethod = id->conf;\n";
      else if( !m->my_configuration()->find_auth_module( line ) )
	m->report_notice( LOC_M( 59,"Syntax error in security patterns: "
				 "Cannot find the auth method '%s'")+"\n",
			  line);
      else
	code +=
	  sprintf("    authmethod = id->conf->find_auth_module( %O );\n",
		  line);
      continue;
    }
    else if( sscanf( line, "realm %s", line ) )
    {
      line = String.trim_all_whites( line );
      code += sprintf( "    realm = %O;\n", line );
      continue;
    }
    else {
      m->report_notice( LOC_M( 60,"Syntax error in security patterns: "
			       "Expected 'allow' or 'deny'\n" ));
      continue;
    }
    int shorted = sscanf( line, "%s return", line );


    // Notes on the variables @[state] and @[short_fail]:
    //
    // The variable @[state] has several potential entries
    // (currently "ip", "user", "group", "time", "date",
    //  "referer", "language" and "luck").
    // An entry exists in the mapping if a corresponding accept directive
    // has been executed.
    //
    // The variable @[short_fail] contains a non-zero entry if
    // a potentially acceptable accept with return has been
    // encountered.
    //
    // Valid values in @[state] and @[short_fail] are:
    // @int
    //   @value 0
    //     Successful match.
    //   @value 1
    //     Plain failure.
    //   @value 2
    //     Fail with authenticate.
    // @endint
    //
    // Shorted directives will only be regarded if all unshorted directives
    // encountered at that point have succeeded.
    // If the checking ends with an ok return unshorted directives of
    // the same class will be disregarded as well as any potential
    // short directives.
    // If there are unshorted directives of type 2 and none of type 1,
    // an auth request will be sent.
    // If there are unshorted directives, and all of them have been
    // satisfied an OK will be sent.
    // If there is a potential short directive of type 2, an auth
    // request will be sent.
    // If there are no unshorted directives and no potential short
    // directives an OK will be sent.
    // Otherwise a FAIL will be sent.

    foreach(security_checks, array(string|int|array) check)
    {
      array args;      
      if (sizeof(args = array_sscanf(line, check[0])) == check[1])
      {
	// Got a match for this security check.
	patterns++;
	int thr_code = 1;
	// run instructions.
	foreach(check[2], mixed instr )
	{
	  if( functionp( instr ) )
	    args = instr( @args );
	  else if( multisetp( instr ) )
	  {
	    foreach( (array)instr, string v )
	      if( !has_value( variables, v ) )
		variables += ({ v });
	  }
	  else if( intp( instr ) ) {
	    thr_code = 2;
	    need_auth = 1;
	  }
	  else if( stringp( instr ) )
	  {
	    code += sprintf( instr, @args )+"\n";
	    if( cmd == DENY )
	    {
	      // Make sure we fail regardless of the setting
	      // of all_shorted when we're done.
	      if (thr_code < max_short_code) {
		code += sprintf("    {\n"
				"      state->%s = %d;\n"
				"      if (short_fail < %d)\n"
				"        short_fail = %d;\n"
				"      break;\n"
				"    }\n",
				check[3], thr_code,
				thr_code,
				thr_code);
	      } else {
		code += sprintf("    {\n"
				"      state->%s = %d;\n"
				"      short_fail = %d;\n"
				"      break;\n"
				"    }\n",
				check[3], thr_code,
				thr_code);
		max_short_code = thr_code;
	      }
	    }
	    else
	    {
	      if (shorted) {
		// OK with return. Ignore FAIL/return.
		if (all_shorted) {
		  code +=
#if defined(SECURITY_PATTERN_DEBUG) || defined(HTACCESS_DEBUG)
		    "    {\n"
		    "      report_debug(\"  Result: 0 (fast return)\\n\");\n"
		    "      return 0;\n"
		    "    }\n";
#else /* !SECURITY_PATTERN_DEBUG && !HTACCESS_DEBUG */
		    "      return 0;\n";
#endif /* SECURITY_PATTERN_DEBUG || HTACCESS_DEBUG */
		} else {
		  code += "    {\n";
		  if (checks[check[3]]) {
		    code +=
		      sprintf("      m_delete(state, %O);\n",
			      check[3]);
		  }
		  if (max_short_code) {
		    code += "      short_fail = 0;\n";
		  }
		  code +=
		    "      break;\n"
		    "    }\n";
		}
		// Handle the fail case.
		if (sizeof(checks)) {
		  // Check that we can satify all preceeding tests.
		  code +=
		    "    else if (!sizeof(filter(values(state),\n"
		    "                            values(state))))\n";
		} else {
		  code += "    else\n";
		}
		// OK so far for non return tests.
		if (thr_code < max_short_code) {
		  code +=
		    sprintf("      if (short_fail < %d)\n"
			    "        short_fail = %d;\n",
			    thr_code,
			    thr_code);
		} else {
		  code +=
		    sprintf("      short_fail = %d;\n", thr_code);
		  max_short_code = thr_code;
		}
	      } else {
		// OK without return. Mark as OK.
		code +=
		  sprintf("    {\n"
			  "      state->%s = 0;\n"
			  "    }\n",
			  check[3]);
		all_shorted = 0;
		// Handle the fail case.
		if (checks[check[3]]) {
		  // If not marked
		  // set the failure level.
		  code +=
		    sprintf("    else if (zero_type(state->%s))\n",
			    check[3]);
		} else {
		  code += "    else\n";
		}
		code += sprintf("    {\n"
				"      state->%s = %d;\n"
				"    }\n",
				check[3], thr_code);
		checks[check[3]] = 1;
	      }
	    }
	  }
	}
	break;
      }
    }
  }
  if( !patterns )  return 0;
  code = ("  do {\n" +
	  code +
	  "  } while(0);\n");
  code = ("#include <module.h>\n"
	  "int|mapping f( RequestID id )\n"
	  "{\n" +
	  (variables * ";\n") +
	  ";\n" +
	  (max_short_code?"  int short_fail;\n":"") +
#if defined(SECURITY_PATTERN_DEBUG) || defined(HTACCESS_DEBUG)
	  sprintf("  report_debug(\"Verifying against pattern:\\n\"\n"
		  "%{               \"  \" %O \"\\n\"\n%}"
		  "               \"...\\n\");\n"
		  "%s"+
		  (max_short_code?
		   "  report_debug(sprintf(\"  Short code: %%O\\n\",\n"
		   "                       short_fail));\n":"")+
		  "  report_debug(sprintf(\"  Result: %%O\\n\",\n"
		  "                       state));\n",
		  pattern/"\n", code) +
#else /* !SECURITY_PATTERN_DEBUG && !HTACCESS_DEBUG */
	  code +
#endif /* SECURITY_PATTERN_DEBUG || HTACCESS_DEBUG */

	  (!all_shorted?
	   "  int fail = 0;\n"
	   "  foreach(values(state), int value) {\n"
	   "    fail |= value;\n"
	   "  }\n"
	   "  if (!fail)\n"
	   "    return 0;\n":
	   "") +
	  (max_short_code > 1?
	   "  if (short_fail > 1)\n"
	   "    return authmethod->authenticate_throw(id, realm);\n":
	   "") +
	  (!all_shorted && need_auth?
	   "  if (fail == 2)\n"
	   "    return authmethod->authenticate_throw(id, realm);\n":
	   "") +
	  "  return 1;\n"
	  "}\n"
	  "string vary_cb(string ignored, RequestID id)\n"
	  "{\n"
	  "  int|mapping res = f(id);\n"
	  "  if (intp(res)) return (string) res;\n"
	  "  return 0; // FIXME: Analyze the mapping.\n"
	  "}\n");
#if defined(SECURITY_PATTERN_DEBUG) || defined(HTACCESS_DEBUG)
  report_debug(sprintf("Compiling security pattern:\n"
		       "%{    %s\n%}\n"
		       "Code:\n"
		       "%{    %s\n%}\n",
		       pattern/"\n",
		       code/"\n"));
#endif /* SECURITY_PATTERN_DEBUG || HTACCESS_DEBUG */
  mixed res = compile_string( code );
   
#if !defined(HTACCESS_DEBUG) && !defined(SECURITY_PATTERN_DEBUG)
  dbm_cached_get( "local" )
    ->query("REPLACE INTO compiled_formats (md5,full,enc) VALUES (%s,%s,%s)",
	    kmd5,pattern,encode_value( res, master()->Encoder (res) ) );
#endif /* !defined(HTACCESS_DEBUG) && !defined(SECURITY_PATTERN_DEBUG) */

  return compile_string(code)()->f;
}


protected string cached_hostname = gethostname();

class LogFile(string fname, string|void compressor_program)
{
  private Thread.Mutex lock = Thread.Mutex();
  private Stdio.File fd;
  private int opened;

  // FIXME: compress_logs is limited to scanning files with filename
  // substitutions within a fixed directory (e.g.
  // "$LOGDIR/test/Log.%y-%m-%d", not "$LOGDIR/test/%y/Log.%m-%d").
  private Process.Process compressor_process;
  private int last_compressor_scan_time;
  private void compress_logs(string fname, string active_log)
  {
    if(!compressor_program || !sizeof(compressor_program))
      return; // No compressor program specified...
    if(compressor_process && !compressor_process->status())
      return; // The compressor is already running...
    if(time(1) - last_compressor_scan_time < 300)
      return; // Scan for compressable files at most once every 5 minutes...
    last_compressor_scan_time = time(1);
    fname = roxen_path(fname);
    active_log = roxen_path(active_log);
    string dir = dirname(fname);
    foreach(sort(get_dir(dir) || ({})), string filename_candidate)
    {
      if(filename_candidate == basename(active_log))
       continue; // Don't try to compress the active log just yet...
      if(Regexp("^"+replace(basename(fname),
                           ({ "%y", "%m", "%d", "%h", "%H" }),
                           ({ "[0-9][0-9][0-9][0-9]", "[0-9][0-9]",
                              "[0-9][0-9]", "[0-9][0-9]", "(.+)" }))+"$")->
        match(filename_candidate))
      {
       string compress_file = combine_path(dir, filename_candidate);
       Stdio.Stat stat = file_stat(compress_file);
       if(!stat || time(1) < stat->mtime + 1200)
         continue; // Wait at least 20 minutes before compressing log file...
       werror("Compressing log file %O\n", compress_file);
       compressor_process = Process.Process(({ compressor_program,
					       compress_file }));
       return;
      }
    }
  }

  private void do_open_co() { handle(do_open); }
  private void do_open(void|object mutex_key)
  {
    if (!mutex_key) mutex_key = lock->lock();

    mixed parent;
    if (catch { parent = function_object(object_program(this_object())); } ||
	!parent) {
      // Our parent (aka the configuration) has been destructed.
      // Time to die.
      remove_call_out(do_open_co);
      remove_call_out(do_close_co);
      destruct();
      return;
    }
    string ff = fname;
    mapping m = localtime(time(1));
    m->year += 1900;	// Adjust for years being counted since 1900
    m->mon++;		// Adjust for months being counted 0-11
    if(m->mon < 10) m->mon = "0"+m->mon;
    if(m->mday < 10) m->mday = "0"+m->mday;
    if(m->hour < 10) m->hour = "0"+m->hour;
    ff = replace(fname,({"%d","%m","%y","%h", "%H" }),
		      ({ (string)m->mday, (string)(m->mon),
			 (string)(m->year),(string)m->hour,
			 cached_hostname,
		      }));
    compress_logs(fname, ff);
    mkdirhier( ff );
    fd = open( ff, "wac" );
    if(!fd) 
    {
      remove_call_out(do_open_co);
      call_out(do_open_co, 120); 
      report_error(LOC_M(37, "Failed to open logfile")+" "+fname+" "
#if constant(strerror)
                   "(" + strerror(errno()) + ")"
#endif
                   "\n");
      return;
    }
    opened = 1;
    remove_call_out(do_open_co);
    call_out(do_open_co, 900); 
    remove_call_out(do_close_co);
    call_out(do_close_co, 10.0);
  }

  private void do_close_co() { handle(close); }

  void close()
  {
    object mutex_key = lock->lock();

    destruct( fd );
    opened = 0;
  }

  private array(string) write_buf = ({});
  private void do_the_write()
  {
    object mutex_key = lock->lock();

    if (!opened) do_open(mutex_key);
    if (!opened) return;
    if (!sizeof (write_buf)) return;

    array(string) buf = write_buf;
    // Relying on the interpreter lock here.
    write_buf = ({});

    mixed err = catch (fd->write(buf));
    if (err)
      catch {
	foreach (write_buf, string str)
	  if (String.width (str) > 8)
	    werror ("Got wide string in log output: %O\n", str);
      };

    remove_call_out(do_close_co);
    call_out(do_close_co, 10.0);

    if (err)
      throw (err);
  }

  int write( string what )
  {
    write_buf += ({ what });
    if (sizeof (write_buf) == 1)
      background_run (1, do_the_write);
    return strlen(what); 
  }
}
