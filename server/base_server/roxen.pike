// This file is part of Roxen WebServer.
// Copyright © 1996 - 2004, Roxen IS.
//
// The Roxen WebServer main program.
//
// Per Hedbor, Henrik Grubbström, Pontus Hagland, David Hedbor and others.
// ABS and suicide systems contributed freely by Francesco Chemolli

constant cvs_version="$Id: roxen.pike,v 1.900 2005/03/30 17:52:39 grubba Exp $";

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
#include <variables.h>
#include <stat.h>
#include <timers.h>

// Inherits
inherit "global_variables";
#ifdef SNMP_AGENT
inherit "snmpagent";
#endif
inherit "hosts";
inherit "disk_cache";
// inherit "language";
inherit "supports";
inherit "module_support";
inherit "config_userdb";

#ifdef THREADS
// Used when running threaded to find out which thread is the backend thread.
Thread.Thread backend_thread;
#endif /* THREADS */

// --- Locale defines ---

//<locale-token project="roxen_start">   LOC_S </locale-token>
//<locale-token project="roxen_message"> LOC_M </locale-token>
#define LOC_S(X,Y)	_STR_LOCALE("roxen_start",X,Y)
#define LOC_M(X,Y)	_STR_LOCALE("roxen_message",X,Y)
#define CALL_M(X,Y)	_LOCALE_FUN("roxen_message",X,Y)

// --- Debug defines ---

#ifdef SSL3_DEBUG
# define SSL3_WERR(X) report_debug("SSL3: "+X+"\n")
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
#elif constant(system.dumpable)
// Pike 7.2.
#define enable_coredumps(X)   system.dumpable(X)
#else
#define enable_coredumps(X)
#endif

#define DDUMP(X) sol( combine_path( __FILE__, "../../" + X ), dump )
static function sol = master()->set_on_load;

#ifdef TEST_EUID_CHANGE
int test_euid_change;
#endif

string md5( string what )
{
  return Gmp.mpz(Crypto.md5()->update( what )->digest(),256)
    ->digits(32);
}
  
string query_configuration_dir()
{
  return configuration_dir;
}

string filename( program|object o )
{
  if( objectp( o ) )
    o = object_program( o );

  string fname = master()->program_name( o );
  if( !fname )
    fname = "Unknown Program";
  return fname-(getcwd()+"/");
}

static int once_mode;

// Note that 2.5 is a nonexisting version. It's only used for the
// cache static optimization for tags such as <if> and <emit> inside
// <cache> since that optimization can give tricky incompatibilities
// with 2.4.
array(string) compat_levels = ({"2.1", "2.2", "2.4", "2.5", "3.3", "3.4", "4.0", "4.1" });

#ifdef THREADS
mapping(string:string) thread_names = ([]);
string thread_name( object thread )
{
  string tn;
  if( thread_names[ tn=sprintf("%O",thread) ] )
    return thread_names[tn];
  return tn;
}

void name_thread( object thread, string name )
{
  catch(thread->set_name( name ));
  thread_names[ sprintf( "%O", thread ) ] = name;
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

static class Privs
{
#if efun(seteuid)

  int saved_uid;
  int saved_gid;

  int new_uid;
  int new_gid;

#define LOGP (variables && variables->audit && variables->audit->query())

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
      catch { mutex_key = euid_egid_lock->lock(); };
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
#if efun(cleargroups)
      catch { cleargroups(); };
#endif /* cleargroups */
#if efun(initgroups)
      catch { initgroups(u[0], u[3]); };
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
      catch {
	array bt = backtrace();
	if (sizeof(bt) >= 2) {
	  report_notice(LOC_M(3,"Change back to uid#%d gid#%d, from %s")+"\n",
			saved_uid, saved_gid, dbt(bt[-2]));
	} else {
	  report_notice(LOC_M(4,"Change back to uid#%d gid#%d, "
			      "from backend")+"\n", saved_uid, saved_gid);
	}
      };
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
#if efun(cleargroups)
    catch { cleargroups(); };
#endif /* cleargroups */
    if(u && (sizeof(u) > 3)) {
      catch { initgroups(u[0], u[3]); };
    }
    setegid(saved_gid);
    seteuid(saved_uid);
    enable_coredumps(1);
#endif /* HAVE_EFFECTIVE_USER */
  }
#else /* efun(seteuid) */
  void create(string reason, int|string|void uid, int|string|void gid){}
#endif /* efun(seteuid) */
}

/* Used by read_config.pike, since there seems to be problems with
 * overloading otherwise.
 */
static Privs PRIVS(string r, int|string|void u, int|string|void g)
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
  catch (stop_handler_threads());
#endif /* THREADS */
  if (!exit_code || once_mode) {
    // We're shutting down; Attempt to take mysqld with us.
    catch { report_notice("Shutting down MySQL.\n"); };
    catch {
      Sql.sql db = connect_to_my_mysql(0, "mysql");
      db->shutdown();
    };
  }
  destruct (cache);
#if 0
  // Disabled since it's lying when the server is shut down with a
  // SIGTERM or SIGINT to the start script (which include the stop
  // action of the init.d script).
  catch {
    if (exit_code && !once_mode)
      report_notice("Restarting Roxen.\n");
    else
      report_notice("Shutting down Roxen.\n");
  };
#endif
  roxenloader.real_exit( exit_code ); // Now we die...
}

private int _recurse;

// Shutdown Roxen
//  exit_code = 0	True shutdown
//  exit_code = -1	Restart
private void low_shutdown(int exit_code)
{
  if(_recurse >= 4)
  {
    catch (report_notice("Exiting roxen (spurious signals received).\n"));
    catch (stop_all_configurations());
    destruct(cache);
#ifdef THREADS
    catch (stop_handler_threads());
#endif /* THREADS */
    roxenloader.real_exit(exit_code);
  }
  if (_recurse++) return;

  catch(stop_all_configurations());

#ifdef SNMP_AGENT
  if(objectp(snmpagent)) {
    snmpagent->stop_trap();
    snmpagent->disable();
  }
#endif

  call_out(really_low_shutdown, 0.1, exit_code);
}

// Perhaps somewhat misnamed, really...  This function will close all
// listen ports and then quit.  The 'start' script should then start a
// new copy of roxen automatically.
void restart(float|void i, void|int exit_code)
//! Restart roxen, if the start script is running
{
  call_out(low_shutdown, i, exit_code || -1);
}

void shutdown(float|void i)
//! Shut down roxen
{
  call_out(low_shutdown, i, 0);
}

void exit_when_done()
{
  report_notice("Interrupt request received.\n");
  low_shutdown(-1);
}


/*
 * handle() stuff
 */

#ifdef THREADS
// function handle = threaded_handle;

Thread do_thread_create(string id, function f, mixed ... args)
{
  Thread.Thread t = thread_create(f, @args);
  name_thread( t, id );
  return t;
}

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

  mixed tryread()
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
local static Queue handle_queue = Queue();
//! Queue of things to handle.
//! An entry consists of an array(function fp, array args)

local static int thread_reap_cnt;
//! Number of handler threads in the process of being stopped.

static int threads_on_hold;
//! Number of handler threads on hold.

local static void handler_thread(int id)
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
    if(q=catch {
      do {
//  	if (!busy_threads) werror ("GC: %d\n", gc());
	THREAD_WERR("Handle thread ["+id+"] waiting for next event");
	if(arrayp(h=handle_queue->read()) && h[0]) {
	  THREAD_WERR(sprintf("Handle thread [%O] calling %O(%{%O, %})",
				id, h[0], h[1] / 1));
	  set_locale();
	  busy_threads++;
	  thread_flagged_as_busy = 1;
	  h[0](@h[1]);
	  h=0;
	  busy_threads--;
	  thread_flagged_as_busy = 0;
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
      if (h = catch {
	report_error(/*LOCALE("", "Uncaught error in handler thread: %s"
		       "Client will not get any response from Roxen.\n"),*/
		     describe_backtrace(q));
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

int number_of_threads;
//! The number of handler threads to run.

int busy_threads;
//! The number of currently busy threads.

static array(object) handler_threads = ({});
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

static int num_hold_messages;
static Thread.Condition hold_wakeup_cond = Thread.Condition();
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
      mixed task = handle_queue->tryread();
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

static Thread.MutexKey backend_block_lock;

void stop_handler_threads()
//! Stop all the handler threads and the backend, but give up if it
//! takes too long.
{
  int timeout=10;
#if constant(_reset_dmalloc)
  // DMALLOC slows stuff down a bit...
  timeout *= 10;
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

  while(thread_reap_cnt) {
    sleep(0.1);
    if(--timeout<=0) {
      report_debug("Giving up waiting on threads; "
		   "%d threads blocked.\n", thread_reap_cnt);
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
    static int async_called;

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
static Thread.Queue bg_queue = Thread.Queue();
static int bg_process_running;

// Use a time buffer to strike a balance if the server is busy and
// always have at least one busy thread: The maximum waiting time in
// that case is somewhere between bg_time_buffer_min and
// bg_time_buffer_max. If there are only short periods of time between
// the queue runs, the max waiting time will shrink towards the
// minimum.
static constant bg_time_buffer_max = 30;
static constant bg_time_buffer_min = 0;
static int bg_last_busy = 0;

static void bg_process_queue()
{
  if (bg_process_running) return;
  // Relying on the interpreter lock here.
  bg_process_running = 1;

  int maxbeats =
    min (time() - bg_last_busy, bg_time_buffer_max) * (int) (1 / 0.04);

  if (mixed err = catch {
    while (bg_queue->size()) {
      // Not a race here since only one thread is reading the queue.
      array task = bg_queue->read();

      // Wait a while if another thread is busy already.
      if (busy_threads > 1) {
	for (maxbeats = max (maxbeats, (int) (bg_time_buffer_min / 0.04));
	     busy_threads > 1 && maxbeats > 0;
	     maxbeats--)
	  // Pike implementation note: If 0.02 or smaller, we'll busy wait here.
	  sleep (0.04);
	bg_last_busy = time();
      }

#ifdef DEBUG_BACKGROUND_RUN
      report_debug ("background_run run %s (%s) [%d jobs left in queue]\n",
		    functionp (task[0]) ?
		    sprintf ("%s: %s", Function.defined (task[0]),
			     master()->describe_function (task[0])) :
		    programp (task[0]) ?
		    sprintf ("%s: %s", Program.defined (task[0]),
			     master()->describe_program (task[0])) :
		    sprintf ("%O", task[0]),
		    map (task[1], lambda (mixed arg)
				  {return sprintf ("%O", arg);}) * ", ",
		    bg_queue->size());
      float task_time = gauge {
#endif
	  if (task[0])		// Ignore things that have become destructed.
	  // Note: BackgroundProcess.repeat assumes that there are
	  // exactly two refs to task[0] during the call below.
	    task[0] (@task[1]);
#ifdef DEBUG_BACKGROUND_RUN
	};
      report_debug ("background_run done, took %f sec\n", task_time);
#endif

      if (busy_threads > 1) bg_last_busy = time();
    }
  }) {
    bg_process_running = 0;
    handle (bg_process_queue);
    throw (err);
  }
  bg_process_running = 0;
}
#endif

void background_run (int|float delay, function func, mixed... args)
//! Enqueue a task to run in the background in a way that makes as
//! little impact as possible on the incoming requests. No matter how
//! many tasks are queued to run in the background, only one is run at
//! a time. The tasks won't be starved, though.
//!
//! The function @[func] will be enqueued after approximately @[delay]
//! seconds, to be called with the rest of the arguments as its
//! arguments.
//!
//! The function might be run in the backend thread, so it should
//! never run for a considerable time. Instead do another call to
//! @[background_run] to queue it up again after some work has been
//! done, or use @[BackgroundProcess].
{
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
  if (!hold_wakeup_cond)
    // stop_handler_threads is running; ignore more work.
    return;

  function enqueue = lambda()
  {
    bg_queue->write (({func, args}));
    if (!bg_process_running)
      handle (bg_process_queue);
  };

  if (delay)
    call_out (enqueue, delay);
  else
    enqueue();

  enqueue = 0;			// To avoid garbage.

#else
  // Can't do much better when we haven't got threads..
  call_out (func, delay, @args);
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
  int stopping = 0;

  static void repeat (function func, mixed args)
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
    if (stopping || self_refs <= 4) return;
    func (@args);
    background_run (period, repeat, func, args);
  }

  //! @decl void set_period (int|float period);
  //!
  //! Changes the period to @[period] seconds between calls.
  void set_period (int|float period_)
  {
    period = period_;
  }

  //! @decl static void create (int|float period, function func, mixed... args);
  //!
  //! The function @[func] will be called with the following arguments
  //! after approximately @[period] seconds, and then kept being
  //! called with approximately that amount of time between each call.
  //!
  //! The repetition will stop if @[stop] is called, or if @[func]
  //! throws an error.
  static void create (int|float period_, function func, mixed... args)
  {
    period = period_;
    background_run (period, repeat, func, args);
  }

  void stop()
  //! Sets a flag to stop the succession of calls.
  {
    stopping = 1;
  }

  string _sprintf() {return "BackgroundProcess()";}
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

static mapping(string:int(0..1)) host_is_local_cache = ([]);

//! Check if @[hostname] is local to this machine.
int(0..1) host_is_local(string hostname)
{
  int(0..1) res;
  if (!zero_type(res = host_is_local_cache[hostname])) return res;
  
  // Look up the IP.
  string ip = blocking_host_to_ip(hostname);

  // Can we bind to it?
  Stdio.Port port = Stdio.Port();
  res = port->bind(0, 0, ip);

  destruct(port);
  return host_is_local_cache[hostname] = res;
}

Configuration find_configuration_for_url(Standards.URI url,
					 void|Configuration only_this_conf)
//! Tries to to determine if a request for the given url would end up
//! in this server, and if so returns the corresponding configuration.
//!
//! If @[only_this_conf] has been specified only matches against it
//! will be returned.
{
  Configuration c;
  string url_with_port = sprintf("%s://%s:%d%s", url->scheme, url->host,
				 url->port,
				 (sizeof(url->path)?url->path:"/"));

  URL2CONF_MSG("URL with port: %s\n", url_with_port);

  foreach( indices(urls), string u )
  {
    mixed q = urls[u];
    URL2CONF_MSG("Trying %O:%O\n", u, q);
    if( glob( u+"*", url_with_port ) )
    {
      URL2CONF_MSG("glob match\n");
      if( q->port &&
	  (c = q->port->find_configuration_for_url(url_with_port, 0, 1 )) )
      {
	URL2CONF_MSG("Found config: %O\n", c);

	if ((only_this_conf && (c != only_this_conf)) ||
	    ((search(u, "*") != -1 || search(u, "?") != -1) &&
	     // u is something like "http://*:80/"
	     (!host_is_local(url->host)))) {
	  // Bad match.
	  URL2CONF_MSG("Bad match: only_this_conf:%O, host_is_local:%O\n",
		       (only_this_conf && (c == only_this_conf)),
		       (!host_is_local(url->host)));
	  c = 0;
	  continue;
	}
	break;
      }
    }
  }
  URL2CONF_MSG("Result: %O\n", c);
  return c;
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
    string path = uri->path;
    raw_url = path;
    method = "GET";
    raw = "GET " + raw_url + " HTTP/1.1\r\n\r\n";
    conf = find_configuration_for_url(uri);
    return set_path( raw_url );
  }

  static string _sprintf()
  {
    return sprintf("RequestID(conf=%O; not_query=%O)", conf, not_query );
  }

  static void create()
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
    cookies = ([]);
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
  static Stdio.Port port_obj;

  inherit "basic_defvar";
  int bound;

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

  int port;
  //! The currently bound portnumber

  string ip;
  //! The canonical IP-number (0 for ANY) this port is bound to.
  //!
  //! IPv6 numbers are in colon separated four-digit lower-case hexadecimal
  //! notation with the first longest sequence of zeros compressed.

  int refs;
  //! The number of references to this port

  program requesthandler;
  //! The per-connection request handling class

  array(string) sorted_urls = ({});
  //! Sorted by length, longest first

  mapping(string:mapping) urls = ([]);
  //! .. url -> ([ "conf":.., ... ])

  mapping(Configuration:mapping) conf_data = ([]);
  //! Maps the configuration objects to the data mappings in @[urls].

  void ref(string name, mapping data)
  //! Add a ref for the URL 'name' with the data 'data'
  {
    if(urls[name])
    {
      conf_data[urls[name]->conf] = urls[name] = data;
      return; // only ref once per URL
    }
    if (!refs) path = data->path;
    else if (path != (data->path || "")) path = 0;
    refs++;
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
    if (!path && sizeof (Array.uniq (values (urls)->path)) == 1)
      path = values (urls)[0]->path;
    sorted_urls -= ({_name});
#ifdef PORT_DEBUG
    report_debug("Protocol(%s://%s:%d/)->unref(%O): refs:%d\n",
		 name, ip, port, _name, refs);
#endif /* PORT_DEBUG */
    if( !--refs ) {
      if (retries) {
	remove_call_out(bind);
      }
      if (port_obj) {
	destruct(port_obj);
      }
      port_obj = 0;
      m_delete(open_ports[name][ip], port);
      if(!sizeof(open_ports[name][ip]))
	m_delete(open_ports[name], ip);
      if(!sizeof(open_ports[name]))
	m_delete(open_ports, name);
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

  mapping mu;
  string rrhf;
  static void got_connection()
  {
    Stdio.File q = accept( );
    if( q )
    {
      if( !requesthandler )
      {
	requesthandler = (program)(rrhf);
      }
      Configuration c;
      if( refs < 2 )
      {
        if(!mu) 
        {
          mu = urls[sorted_urls[0]];
          if(!(c=mu->conf)->inited )
            c->enable_all_modules();
        } else
          c = mu->conf;
      }
      requesthandler( q, this_object(), c );
    }
  }

  local function sp_fcfu;



#define INIT(X) do{			\
    mapping _=(X);			\
    string __=_->path;			\
    c=_->conf;				\
    if(__&&id->adjust_for_config_path)	\
      id->adjust_for_config_path(__);	\
    if(!c->inited)			\
      c->enable_all_modules();		\
  } while(0)

  Configuration find_configuration_for_url( string url, RequestID id, 
                                            int|void no_default )
  //! Given a url and requestid, try to locate a suitable configuration
  //! (virtual site) for the request. 
  //! This interface is not at all set in stone, and might change at 
  //! any time.
  {
    Configuration c;
    if( sizeof( urls ) == 1 && !no_default)
    {
      if(!mu) mu=urls[sorted_urls[0]];
      INIT( mu );
      URL2CONF_MSG ("%O %O Only one configuration: %O\n", this_object(), url, c);
      return c;
    } else if (!sizeof(sorted_urls)) {
      URL2CONF_MSG("%O %O No active URLS!\n", this_object(), url);
      return 0;
    }

    url = lower_case( url );
    URL2CONF_MSG("sorted_urls: %O\n"
		 "url: %O\n", sorted_urls, url);
    // The URLs are sorted from longest to shortest, so that short
    // urls (such as http://*/) will not match before more complete
    // ones (such as http://*.roxen.com/)
    foreach( sorted_urls, string in )
    {
      if( glob( in+"*", url ) )
      {
        INIT( urls[in] );
	URL2CONF_MSG ("%O %O sorted_urls: %O\n", this_object(), url, c);
	return c;
      }
    }
    
    if( no_default ) {
      URL2CONF_MSG ("%O %O no default\n", this_object(), url);
      return 0;
    }
    
    // No host matched, or no host header was included in the request.
    // Is the URL in the '*' ports?
    mixed i;
    if( !functionp(sp_fcfu) && ( i=open_ports[ name ][ 0 ][ port ] ) )
      sp_fcfu = i->find_configuration_for_url;
    
    if( sp_fcfu && (sp_fcfu != find_configuration_for_url)
	&& (i = sp_fcfu( url, id, 1 ))) {
      URL2CONF_MSG ("%O %O sp_fcfu: %O\n", this_object(), url, i);
      return i;
    }
    
    // No. We have to default to one of the other ports.
    // It might be that one of the servers is tagged as a default server.
    multiset choices = (< >);
    foreach( configurations, Configuration c )
      if( c->query( "default_server" ) )
	choices |= (< c >);
    
    if( sizeof( choices ) )
    {
      // First pick default servers bound to this port
      foreach( values(urls), mapping cc )
	if( choices[ cc->conf ] )
	{
          INIT( cc );
	  URL2CONF_MSG ("%O %O conf in choices: %O\n", this_object(), url, c);
	  return c;
	}

      // if there is no such servers, pick the first default server
      // available. FIXME: This makes it impossible to handle the
      // server path correctly.

      c = ((array)choices)[0];
      if(!c->inited) c->enable_all_modules();
      URL2CONF_MSG ("%O %O any in choices: %O\n", this_object(), url, c);
      return c;
    }


    // if we end up here, there is no default port at all available
    // so grab the first configuration that is available at all.
    INIT( urls[sorted_urls[0]] );
    id->misc->defaulted=1;
    URL2CONF_MSG ("%O %O first in sorted_urls: %O\n", this_object(), url, c);
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
    return name+":"+ip+":"+port;
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

  static int retries;
  static void bind()
  {
    if (bound) return;
    if (!port_obj) port_obj = Stdio.Port();
    Privs privs = Privs (sprintf ("Binding %s://%s:%d/",
				  (string) name, ip || "*", (int) port));
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
    report_error(LOC_M(6, "Failed to bind %s://%s:%d/ (%s)")+"\n",
		 (string)name, (ip||"*"), (int)port,
		 strerror(port_obj->errno()));
    werror (describe_backtrace (backtrace()));
#if constant(System.EADDRINUSE) || constant(system.EADDRINUSE)
    if (
#if constant(System.EADDRINUSE)
	(port_obj->errno() == System.EADDRINUSE) && 
#else /* !constant(System.EADDRINUSE) */
	(port_obj->errno() == system.EADDRINUSE) && 
#endif /* constant(System.EADDRINUSE) */
	(retries++ < 10)) {
      // We may get spurious failures on rebinding ports on some OS'es
      // (eg Linux, WIN32). See [bug 3031].
      report_notice(LOC_M(62, "Attempt %d. Retrying in 1 minute.")+"\n",
		    retries);
      call_out(bind, 60);
    }
#endif /* constant(System.EADDRINUSE) || constant(system.EADDRINUSE) */
  }

  static array(int) get_ipv6_sequence(string partition)
  {
    array(int) segments = ({});
    foreach(partition/":", string part) {
      if (has_value(part, ".")) {
	array(int) sub_segs = array_sscanf(part, "%d.%d.%d.%d");
	switch(sizeof(sub_segs)) {
	default:
	case 4:
	  segments += ({ sub_segs[0]*256+sub_segs[1],
			 sub_segs[2]*256+sub_segs[3] });
	  break;
	case 3:
	  segments += ({ sub_segs[0]*256+sub_segs[1],
			 sub_segs[2] });
	  break;
	case 2:
	  segments += ({ sub_segs[0]*256 + sub_segs[1]>>16,
			 sub_segs[1]&0xffff });
	  break;
	}
      } else {
	segments += array_sscanf(part, "%x");
      }
    }
    return segments;
  }

  string canonical_ip(string i)
  {
    if (!i) return 0;
    if (has_value(i, ":")) {
      // IPv6
      if (i == "::") return "::";	// IPv6 ANY.
      array(string) partitions = i/"::";
      array(int) sections = get_ipv6_sequence(partitions[0]);
      if (sizeof(partitions) > 1) {
	array(int) tail = get_ipv6_sequence(partitions[1]);
	sections += allocate(8 - sizeof(sections) - sizeof(tail)) + tail;
      } else if (sizeof(sections) < 8) {
	sections += allocate(8 - sizeof(sections));
      }
      i = sprintf("%04.4x:%04.4x:%04.4x:%04.4x:"
		  "%04.4x:%04.4x:%04.4x:%04.4x",
		  @sections);
      // Common case.
      if (i == "0000:0000:0000:0000:0000:0000:0000:0000") return "::";	// ANY

      // Compress the longest sequence of zeros.
      partitions = i/":";
      int start;
      int max;
      int best;
      foreach(partitions + ({ "SENTINEL" }); int ind; string part) {
	if (part != "0000") {
	  if ((ind - start) > max) {
	    best = start;
	    max = ind - start;
	  }
	  start = ind + 1;
	}
      }
      if (max) {
	i = (partitions[..best-1] + ({""}) + partitions[best+max..])*":";
	if (!best) i = ":" + i;
	if (best + max == 8) i += ":";
      }
      return i;
    } else {
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

  static void create( int pn, string i )
  //! Constructor. Bind to the port 'pn' ip 'i'
  {
    port = pn;
    ip = canonical_ip(i);

    restore();
    if( file_stat( "../local/"+requesthandlerfile ) )
      rrhf = "../local/"+requesthandlerfile;
    else
      rrhf = requesthandlerfile;
    DDUMP( rrhf );
#ifdef DEBUG
    if( !requesthandler )
      requesthandler = (program)(rrhf);
#endif
    bound = 0;
    port_obj = 0;
    retries = 0;
    bind();
  }

  static string _sprintf( )
  {
   return "Protocol("+name+"://"+ip+":"+port+")";
  }
}

#if constant(SSL.sslfile)
class SSLProtocol
//! Base protocol for SSL ports. Exactly like Port, but uses SSL.
{
  inherit Protocol;

  // SSL context
  SSL.context ctx = SSL.context();

  void certificates_changed(Variable|void ignored)
  {
    string raw_keydata;
    array(string) certificates = ({});
    Variable Certificates = getvar("ssl_cert_file");

    object privs = Privs("Reading cert file");

    foreach(map(Certificates->query(), String.trim_whites), string cert_file) {
      string raw_cert;
      if( catch{ raw_cert = lopen(cert_file, "r")->read(); } )
      {
	Certificates->add_warning(sprintf(LOC_M(8,"SSL3: Reading cert-file '%s' failed!"),
					  cert_file));
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
	Certificates->add_warning(LOC_M(10, "SSL3: No certificate found.")+"\n");
	continue;
      }
      certificates += ({ cert });
    }

    Variable KeyFile = getvar("ssl_key_file");

    if( strlen(KeyFile->query()) &&
	catch{ raw_keydata = lopen(KeyFile->query(), "r")->read(); } )
    {
      KeyFile->add_warning(sprintf(LOC_M(9, "SSL3: Reading key-file '%s' failed!")+"\n",
				   query_option("ssl_key_file")));
      return;
    }

    privs = 0;

    if (!raw_keydata) {
      Certificates->add_warning(LOC_M(17,"SSL3: No private key found."));
      return;
    }

    if (!sizeof(certificates)) return;

    object msg = Tools.PEM.pem_msg()->init( raw_keydata );

    SSL3_WERR(sprintf("key file contains: %O", indices(msg->parts)));

    object part;
    if (part = msg->parts["RSA PRIVATE KEY"])
    {
      string key;

      if (!(key = part->decoded_body())) 
      {
	KeyFile->add_warning(LOC_M(11,"SSL3: Private rsa key not valid")+" (PEM).\n");
	return;
      }

      object rsa = Standards.PKCS.RSA.parse_private_key(key);
      if (!rsa) 
      {
	KeyFile->add_warning(LOC_M(11, "SSL3: Private rsa key not valid")+" (DER).\n");
	return;
      }

      ctx->rsa = rsa;

      SSL3_WERR(sprintf("RSA key size: %d bits", rsa->rsa_size()));

      if (rsa->rsa_size() > 512)
      {
	/* Too large for export */
#if constant(Crypto.RSA)
	ctx->short_rsa = Crypto.RSA()->generate_key(512, ctx->random);
#else
	ctx->short_rsa = Crypto.rsa()->generate_key(512, ctx->random);
#endif

	// ctx->long_rsa = Crypto.rsa()->generate_key(rsa->rsa_size(), ctx->random);
      }
      ctx->rsa_mode();

      array(int) key_matches =
	map(certificates,
	    lambda(string cert, Variable Certificates) {
	      // FIXME: Support PKCS7
	      object tbs = Tools.X509.decode_certificate (cert);
	      if (!tbs) 
	      {
		Certificates->add_warning(LOC_M(13,"SSL3: Certificate not valid (DER)."));
		return 0;
	      }
	      return tbs->public_key->rsa->public_key_equal (rsa);
	    }, Certificates);
      
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
      {
	KeyFile->add_warning(LOC_M(14, "SSL3: Certificate and private key "
				   "do not match."));
	return;
      }
      ctx->certificates = new_certificates;
    }
    else if (part = msg->parts["DSA PRIVATE KEY"])
    {
      string key;

      if (!(key = part->decoded_body())) 
      {
	report_error(LOC_M(15,"SSL3: Private dsa key not valid")+" (PEM).\n");
	return;
      }

      object dsa = Standards.PKCS.DSA.parse_private_key(key);
      if (!dsa) 
      {
	report_error(LOC_M(15,"SSL3: Private dsa key not valid")+" (DER).\n");
	return;
      }

      SSL3_WERR(sprintf("Using DSA key."));

      //dsa->use_random(ctx->random);
      ctx->dsa = dsa;
      /* Use default DH parameters */
#if constant(SSL.Cipher)
      ctx->dh_params = SSL.Cipher.DHParameters();
#else
      ctx->dh_params = SSL.cipher()->dh_parameters();
#endif

      ctx->dhe_dss_mode();

      // FIXME: Add cert <-> private key check.

      ctx->certificates = certificates;
    }
    else 
    {
      KeyFile->add_warning(LOC_M(17,"SSL3: No private key found."));
      return;
    }

#if EXPORT
    ctx->export_mode();
#endif
  }

  class CertificateListVariable
  {
    inherit Variable.FileList;

    string doc()
    {
      return sprintf(::doc() + "\n",
		     combine_path(getcwd(), "../local"),
		     getcwd());
    }

    static void create(mixed default_value, void|int flags,
		       void|LocaleString std_name, void|LocaleString std_doc)
    {
      ::create(default_value, flags, std_name, std_doc);
      set_changed_callback(certificates_changed);
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

    static void create(mixed default_value, void|int flags,
		       void|LocaleString std_name, void|LocaleString std_doc)
    {
      ::create(default_value, flags, std_name, std_doc);
      set_changed_callback(certificates_changed);
    }
  }

  RoxenSSLFile accept()
  {
    Stdio.File q = ::accept();
    if (q)
      return RoxenSSLFile (q, ctx);
    return 0;
  }

  void create(int pn, string i)
  {
#if constant(Crypto.Random.random_string)
    ctx->random = Crypto.Random.random_string;
#else
    ctx->random = Crypto.randomness.reasonably_random()->read;
#endif

    set_up_ssl_variables( this_object() );

    ::create(pn, i);

    certificates_changed();
  }

  string _sprintf( )
  {
    return "SSLProtocol("+name+"://"+ip+":"+port+")";
  }
}
#endif

mapping(string:Protocol) build_protocols_mapping()
{
  mapping protocols = ([]);
  int st = gethrtime();
  report_debug("Protocol handlers ... \b");
#ifndef DEBUG
  class lazy_load( string prog, string name )
  {
    program real;
    static void realize()
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
#if !constant(SSL.sslfile)
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
#if !constant(SSL.sslfile)
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


mapping protocols;

// prot:ip:port ==> Protocol.
mapping(string:mapping(string:mapping(int:Protocol))) open_ports = ([ ]);

// url:"port" ==> Protocol.
mapping(string:mapping(string:Configuration)) urls = ([]);
array sorted_urls = ({});

array(string) find_ips_for( string what )
{
  if( what == "*" || lower_case(what) == "any" )
    return ({ 0,
#if constant(__ROXEN_SUPPORTS_IPV6__)
	      "::",
#endif /* __ROXEN_SUPPORTS_IPV6__ */
    });	// ANY

  if( is_ip( what ) )
    return ({ what });
  else if (what[0] == '[' && what[-1] == ']') {
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

string normalize_url(string url)
{
  if (!sizeof (url - " " - "\t")) return "";

  url = lower_case( url );
  Standards.URI ui = Standards.URI(url);
  ui->fragment = 0;
  url = (string)ui;
  url = replace( url, "/ANY", "/*" );
  url = replace( url, "/any", "/*" );
  
  string host, path, protocol;

  sscanf( url, "%[^:]://%[^/]%s", protocol, host, path );

  if (!host || !stringp(host)) return "";
  if (!protocols[ protocol ]) return "";

  int port;
  sscanf(host, "%[^:]:%d", host, port);

  if( !port )
  {
    port = protocols[ protocol ]->default_port;
    url = protocol+"://"+host+":"+port+path;
  }
  return url;
}

void unregister_url(string url, Configuration conf)
{
  string ourl = url;
  if (!sizeof(url = normalize_url(url))) return;

  report_debug("Unregister "+url+"\n");

  if (urls[url] && (!conf || !urls[url]->conf || (urls[url]->conf == conf)) &&
      urls[url]->port)
  {
    urls[ url ]->port->unref(url);
    m_delete( urls, url );
    m_delete( urls, ourl );
    sort_urls();
  }
}

array all_ports( )
{
  return Array.uniq( values( urls )->port )-({0});
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

int register_url( string url, Configuration conf )
{
  string ourl = url;
  url = lower_case( url );
  if (!sizeof (url - " " - "\t")) return 1;
  string protocol;
  string host;
  int port;
  string path;

  Standards.URI ui = Standards.URI(url);
  mapping opts = ([]);
  string a, b;
  foreach( (ui->fragment||"")/";", string x )
  {
    sscanf( x, "%s=%s", a, b );
    opts[a]=b;
  }
  ui->fragment = 0;
  url = (string)ui;

  if( (int)opts->nobind )
  {
    report_warning(
      LOC_M(61,"Not binding the port %O, disabled in configuration")+"\n",
      url );
    return 0;
  }
  url = replace( url, "/ANY", "/*" );
  url = replace( url, "/any", "/*" );

  sscanf( url, "%[^:]://%[^/]%s", protocol, host, path );
  if (!host || !stringp(host))
  {
    report_error(LOC_M(19,"Bad URL '%s' for server `%s'")+"\n",
		 url, conf->query_name());
    return 0;
  }

  if( !protocols[ protocol ] )
  {
    report_error(LOC_M(7,"The protocol '%s' is not available")+"\n", protocol);
    return 0;
  }

  sscanf(host, "%[^:]:%d", host, port);

  if( !port )
  {
    port = protocols[ protocol ]->default_port;
    url = protocol+"://"+host+":"+port+path;
  }

  if( strlen( path ) && ( path[-1] == '/' ) )
    path = path[..strlen(path)-2];
  if( !strlen( path ) )
    path = 0;

  if( urls[ url ]  )
  {
    if( !urls[ url ]->port )
      m_delete( urls, url );
    else if(  urls[ url ]->conf )
    {
      if( urls[ url ]->conf != conf )
      {
	report_error(LOC_M(20,
			   "Cannot register URL %s, "
			   "already registered by %s!")+"\n",
		     url, urls[ url ]->conf->name);
	return 0;
      }
      urls[ url ]->port->ref(url, urls[url]);
      return 1;
    }
    else
      urls[ url ]->port->unref( url );
  }

  Protocol prot;

  if( !( prot = protocols[ protocol ] ) )
  {
    report_error(LOC_M(21, "Cannot register URL %s, "
			  "cannot find the protocol %s!")+"\n",
		 url, protocol);
    return 0;
  }

  if( !port )
    port = prot->default_port;

  urls[ url ] = ([ "conf":conf, "path":path, "hostname": host ]);
  urls[ ourl ] = urls[url] + ([]);
  sorted_urls += ({ url });

  array(string)|int(-1..0) required_hosts;

  if (is_ip(host))
    required_hosts = ({ host });
  else if(!sizeof(required_hosts =
		  filter(replace(opts->ip||"", " ","")/",", is_ip)) )
    required_hosts = find_ips_for( host );

  if (!required_hosts) {
    // FIXME: Used to fallback to ANY.
    //        Will this work with glob URLs?
    report_error(LOC_M(23, "Cannot register URL %s!")+"\n", url);
    return 0;
  }

  mapping m;
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
    // open yet another port if it is, since that would mosts probably
    // only conflict with the ANY port anyway. (this is true on most
    // OSes, it works on Solaris, but fails on linux)
    array(string) ipv6 = filter(required_hosts - ({ 0 }), has_value, ":");
    array(string) ipv4 = required_hosts - ipv6;
    if (m[0][port] && sizeof(ipv4 - ({ 0 }))) {
      // We have a non-ANY IPv4 IP number.
      ipv4 = ({ 0 });
    }
#if constant(__ROXEN_SUPPORTS_IPV6__)
    if (m["::"][port] && sizeof(ipv6 - ({ "::" }))) {
      // We have a non-ANY IPv6 IP number.
      ipv6 = ({ "::" });
    }
    required_hosts = ipv4 + ipv6;
#else
    if (sizeof(ipv6)) {
      foreach(ipv6, string p) {
	report_warning(LOC_M(0, "IPv6 port for URL %s disabled: %s\n"),
		       url, p);
      }
    }
    required_hosts = ipv4;
#endif /* __ROXEN_SUPPORTS_IPV6__ */
  }

  int failures;

  foreach(required_hosts, string required_host)
  {
    if( m[ required_host ] && m[ required_host ][ port ] )
    {
      m[required_host][port]->ref(url, urls[url]);

      urls[url]->port = m[required_host][port];
      urls[ourl]->port = m[required_host][port];
      continue;    /* No need to open a new port */
    }

    if( !m[ required_host ] )
      m[ required_host ] = ([ ]);

    mixed err;
    if (err = catch {
	m[ required_host ][ port ] = prot( port, required_host );
      }) {
      failures++;
      if (has_prefix(describe_error(err), "Invalid address") &&
	  required_host && has_value(required_host, ":")) {
	report_error(sprintf("Failed to initialize IPv6 port for URL %s"
			     " (ip %s). Not supported?\n",
			     url, required_host));
      } else {
	report_error(sprintf("Initializing the port handler for URL %s"
			     " failed! (ip %s)\n"
			     "%s\n",
			     url,
			     required_host||"ANY",
			     describe_backtrace(err)));
      }
      continue;
    }

    if( !( m[ required_host ][ port ] ) )
    {
      m_delete( m[ required_host ], port );
      failures++;
      if (required_host) {
	report_warning(LOC_M(22, "Binding the port on IP %s failed\n"
			     "   for URL %s!\n"),
		       required_host, url);
      }
      continue;
    }


    urls[ url ]->port = m[ required_host ][ port ];
    urls[ ourl ]->port = m[ required_host ][ port ];
    m[ required_host ][ port ]->ref(url, urls[url]);
 
    if( !m[ required_host ][ port ]->bound )
      failures++;
  }
  if (failures == sizeof(required_hosts)) 
  {
    report_error(LOC_M(23, "Cannot register URL %s!")+"\n", url);
    return 0;
  }
  sort_urls();
  report_notice(" "+LOC_S(3, "Registered %s for %s")+"\n",
		url, conf->query_name() );
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

static int last_hrtime = gethrtime(1)/100;
static int clock_sequence = random(0x4000);
static string hex_mac_address =
  Crypto.string_to_hex(Crypto.randomness.reasonably_random()->read(6)|
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
  object md5 = Crypto.md5();
  md5->update(query("server_salt") + start_time + "|" +
	      (unique_id_counter++) + "|" + time(1));
  return Crypto.string_to_hex(md5->digest());
}

#ifndef __NT__
static int abs_started;

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
    report_debug("Anti-Block System Enabled.\n");
  }
  call_out (restart_if_stuck,10);
//    werror("call_out_info %O\n", filter(call_out_info(), lambda(array a) {
//  							 return a[2] == restart_if_stuck; }));
  signal(signum("SIGALRM"),
	 lambda( int n ) {
	   if (!query("abs_engage")) {
	     abs_started = 0;
	     report_debug("Anti-Block System Disabled.\n");
	     return;
	   }
	   report_debug("**** %s: ABS engaged!\n"
			"Waited more than %d minute(s).\n"
			"Trying to dump backlog: \n",
			ctime(time()) - "\n",
			query("abs_timeout"));
	   catch {
	     // Catch for paranoia reasons.
	     describe_all_threads();
	   };
	   report_debug("**** %s: ABS exiting roxen!\n\n",
			ctime(time()));
	   _exit(1); 	// It might now quit correctly otherwise, if it's
	   //  locked up
	 });
  int t = alarm (60*query("abs_timeout")+20);
  // werror("alarm: %d seconds left, set to %d\n", t, 60*query("abs_timeout")+20);
}
#endif

function(string:Sql.Sql) dbm_cached_get;

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

  static mapping meta_cache_insert( string i, mapping what )
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

  static mixed frommapp( mapping what )
  {
    if( !what )
      error( "Got invalid argcache-entry\n" );
    if( !zero_type(what[""]) ) return what[""];
    return what;
  }

  static void|mapping draw( string name, RequestID id )
  {
#ifdef ARG_CACHE_DEBUG
    werror("draw %O\n", name );
#endif
    mixed args = Array.map( Array.map( name/"$", argcache->lookup,
				       id->client ), frommapp);

    mapping meta;
    string data;
    array guides;
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

  static void store_data( string id, string data, mapping meta )
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
	  " (id,size,atime,meta,data) VALUES (%s,%d,UNIX_TIMESTAMP(),%s,%s)",
	  id, strlen(data)+strlen(meta_data), meta_data, data );
  }

  static mapping restore_meta( string id, RequestID rid )
  {
    if( meta_cache[ id ] )
    {
      meta_cache[ id ][ 1 ] = time(1); // Update cached atime.
      return meta_cache[ id ][ 0 ];
    }

#ifdef ARG_CACHE_DEBUG
    werror("restore meta %O\n", id );
#endif
    array(mapping(string:string)) q =
      QUERY("SELECT meta FROM "+name+" WHERE id=%s", id );

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

    QUERY("UPDATE "+name+" SET atime=UNIX_TIMESTAMP() WHERE id=%s",id );
    return meta_cache_insert( id, m );
  }

  static void sync_meta()
  {
    // Sync cached atimes.
    foreach(indices(meta_cache), string id) {
      if (meta_cache[id][1])
	QUERY("UPDATE "+name+" SET atime=%d WHERE id=%s",
	      meta_cache[id][1], id);
    }
    meta_cache = ([]);
  }

  void flush(int|void age)
  //! Flush the cache. If an age (an integer as returned by
  //! @[time()]) is provided, only images with their latest access before
  //! that time are flushed.
  {
    int num;
#ifdef DEBUG
    int t = gethrtime();
    report_debug("Cleaning "+name+" image cache ... ");
#endif
    sync_meta();
    uid_cache  = ([]);
    rst_cache  = ([]);
    if( !age )
    {
#ifdef DEBUG
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
      QUERY( "DELETE FROM "+name+" WHERE id in ('"+list+"')" );
    }

    if( num )
      catch
      {
	// Old versions of Mysql lacks OPTIMIZE. Not that we support
	// them, really, but it might be nice not to throw an error, at
	// least.
	QUERY( "OPTIMIZE TABLE "+name );
      };

#ifdef DEBUG
    report_debug("%s removed, %dms\n",
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

  static mapping(string:mapping) rst_cache = ([ ]);
  static mapping(string:string) uid_cache = ([ ]);

  static mapping restore( string id, RequestID rid )
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

    if( rst_cache[ id ] )
      return rst_cache[ id ] + ([]);

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
	catch( m = decode_value( q[0]->meta ) );
	if( !m ) return 0;

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


  string data( array|string|mapping args, RequestID id, int|void nodraw )
  //! Returns the actual raw image data of the image rendered from the
  //! @[args] instructions.
  //!
  //! A non-zero @[nodraw] parameter means an image not already in the
  //! cache will not be rendered on the fly, but instead return zero.
  {
    mapping res = http_file_answer( args, id, nodraw );
    return res && res->data;
  }

  mapping http_file_answer( array|string|mapping data,
                            RequestID id,
                            int|void nodraw )
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
    string na = store( data,id );
    mixed res;
#ifdef ARG_CACHE_DEBUG
      werror("data %O\n", na );
#endif
    if(! (res=restore( na,id )) )
    {
      mixed err;
      if (nodraw || (err = catch {
  	if (mapping res = draw( na, id ))
  	  return res;
      })) {
	// File not found.
	if(arrayp(err) && sizeof(err) && stringp(err[0]) &&
	   sscanf(err[0], "Requesting unknown key %s\n", string message) == 1)
	{
	  report_debug("Requesting unknown key %s %O from %O\n",
		       message,
		       id->not_query,
		       (sizeof(id->referer)?id->referer[0]:"unknown page"));
	}
	else
	  report_debug("Error in draw: %s\n", describe_backtrace(err));
	return 0;
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
    //  sessions. However, this flag also controls whether the file should
    //  be placed in the protocol-level cache, so we'll counter by setting a
    //  separate flag.
    RAISE_CACHE(INITIAL_CACHEABLE);
    NO_PROTO_CACHE();
    return res;
  }

  mapping metadata( array|string|mapping data,
		    RequestID id,
		    int|void nodraw )
  //! Returns a mapping of image metadata for an image generated from
  //! the data given (as sent to @[store()]). If a non-zero
  //! @[nodraw] parameter is given and the image was not in the cache,
  //! it will not be rendered on the fly to get the correct data.
  {
    string na = store( data,id );
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

  string store( array|string|mapping data, RequestID id )
  //! Store the data your draw callback expects to receive as its
  //! first argument(s). If the data is an array, the draw callback
  //! will be called like <pi>callback( @@data, id )</pi>.
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
      if( id->misc->authenticated_user &&
	  !id->misc->authenticated_user->is_transient )
	// This entry is not actually used, it's only there to
	// generate a unique key.
	a["\0u"] = user = id->misc->authenticated_user->name();
    };
    
    if( mappingp( data ) )
    {
      update_args( data );
      ci = argcache->store( data );
    }
    else if( arrayp( data ) )
    {
      if( !mappingp( data[0] ) )
	error("Expected mapping as the first element of the argument array\n");
      update_args( data[0] );
      ci = map( map( data, tomapp ), argcache->store )*"$";
    } else
      ci = data;
    update_args = 0;		// To avoid garbage.

    if( zero_type( uid_cache[ ci ] ) )
    {
      uid_cache[ci] = user;
      if( catch(QUERY("INSERT INTO "+name+" "
		      "(id,uid,atime) VALUES (%s,%s,UNIX_TIMESTAMP())",
		      ci, user||"")) )
	QUERY( "UPDATE "+name+" SET uid=%s WHERE id=%s",
	       user||"", ci );
    }

#ifndef NO_ARG_CACHE_SB_REPLICATE
    if(id->misc->persistent_cache_crawler) {
      // Force an update of atime for the requested arg cache id.
      foreach(ci/"$", string key) {
#if REPLICATE_DEBUG
	werror("Request for id %O from prefetch crawler.\n", key);
#endif /* REPLICATE_DEBUG */
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

  static void setup_tables()
  {
    if(catch(QUERY("SELECT DATA FROM "+name+" WHERE id=''")))
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
	    "INDEX atime (atime)"
	    ")" );
    }
  }

  Sql.Sql get_db()
  {
    return dbm_cached_get("local");
  }

  static void init_db( )
  {
    catch(sync_meta());
    setup_tables();
  }

  void do_cleanup( )
  {
    background_run( 3600*10+random(4711), do_cleanup );
    flush(time()-7*3600*24);
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
    if (mixed err = catch(sync_meta()))
      report_warning("Failed to sync cached atimes for "+name+"\n");
  }
}


class ArgCache
//! Generic cache for storing away a persistent mapping of data to be
//! refetched later by a short string key. This being a cache, your
//! data may be thrown away at random when the cache is full.
{
#undef QUERY
#define QUERY(X,Y...) db->query(X,Y)
  Sql.Sql db;
  string name;

#define CACHE_VALUE 0
#define CACHE_SKEY  1
#define CACHE_SIZE  900
#define CLEAN_SIZE  100

  static string lq, ulq;

#ifdef THREADS
  Thread.Mutex mutex = Thread.Mutex();
  // Allow recursive locks, since it's normal here.
# define LOCK() mixed __; catch( __ = mutex->lock() )
#else
# define LOCK()
#endif
  
  static mapping (string:mixed) cache = ([ ]);

  static void setup_table()
  {
    if(catch(QUERY("SELECT md5 FROM "+name+" WHERE id=0")))
    {
      master()->resolv("DBManager.is_module_table")
	( 0, "local", name,
	  "The argument cache, used to map between "
	  "a short unique string and an argument "
	  "mapping" );
      catch(QUERY("DROP TABLE "+name ));
      QUERY("CREATE TABLE "+name+" ("
	    "id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, "
	    "index_id  INT UNSIGNED NULL DEFAULT NULL, "
	    "md5       CHAR(32) NOT NULL DEFAULT '', "
	    "atime     INT UNSIGNED NOT NULL DEFAULT 0, "
	    "contents  BLOB NOT NULL DEFAULT '', "
	    "INDEX hind (md5))");
    }
    // Add column index_id if it doesn't exists.
    if(catch(QUERY("SELECT index_id FROM "+name+" WHERE id=0")))
    {
      QUERY("ALTER TABLE "+name+" "
	    "ADD index_id INT UNSIGNED NULL DEFAULT NULL");
    }
  }

  static void init_db()
  {
    // Delay DBManager resolving to before the 'roxen' object is
    // compiled.
    cache = ([]);
    db = dbm_cached_get("local");
    setup_table( );
  }

  static void create( string _name )
  {
    name = _name;
    init_db();
    // Support that the 'local' database moves (not really nessesary,
    // but it won't hurt either)
    master()->resolv( "DBManager.add_dblist_changed_callback" )( init_db );
    get_plugins();
  }

  string read_args( int id )
  {
    LOCK();
    array res = QUERY("SELECT contents FROM "+name+" WHERE id="+id);
    if( sizeof(res) )
    {
      QUERY("UPDATE "+name+" SET atime='"+time(1)+"' WHERE id="+id);
      return res[0]->contents;
    }
    return 0;
  }

  int read_index_id( int id )
  {
    LOCK();
    array res = QUERY("SELECT index_id FROM "+name+" WHERE id="+id);
    if(sizeof(res) && res[0]->index_id)
      return (int)res[0]->index_id;
    return -1;
  }

  int create_key( string long_key, string|void md, int|void index_id )
  {
    if( !md )  md = md5(long_key);
    LOCK();
    array data =
      QUERY("SELECT id,contents FROM "+name+" WHERE md5=%s", md );
    
    foreach( data, mapping m )
      if( m->contents == long_key )
      	return (int)m->id;

    if(zero_type(index_id))
      index_id = -1;

    string index_id_value = (index_id == -1? "NULL": index_id);
    QUERY( "INSERT INTO "+name+" (contents,md5,atime,index_id) VALUES "
	   "(%s,%s,UNIX_TIMESTAMP(),"+index_id_value+")", long_key, md );
    int id = (int)db->master_sql->insert_id();
    if(!id)
      error("ArgCache::create_key() insert_id returned 0.\n");
#ifdef REPLICATE_DEBUG
    werror("Create new local key: id: %d, index_id: %d.\n", id, index_id);
#endif

    (plugins->create_key-({0}))( id, long_key );

    return id;
  }
  
  static int low_key_exists( string key )
  {
    LOCK();
    int res = sizeof( QUERY( "SELECT id FROM "+name+" WHERE id="+(int)key));
    // Fool optimizer.
    if( res )
      return res;
  }

  string secret;

  static void ensure_secret()
  {
    if( !secret )
      secret = query( "argcache_secret" );
  }

  string encode_id( int a, int b, string|void server )
  {
    ensure_secret();
    object crypto = Crypto.arcfour();
    crypto->set_encrypt_key( server||secret );
    string res = crypto->crypt( a+"\327"+b );
    // Ensure that we do not have a leading NUL.
    res[0] |= 0x80;
    res = Gmp.mpz( res, 256 )->digits( 36 );
    return res;
  }

  static array plugins;
  static void get_plugins()
  {
    ensure_secret();
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

  static array plugin_decode_id( string id )
  {
    mixed r;
    foreach( (plugins->decode_id-({0})), function(string:array(int)) f )
      if( r = f( id ) )
	return r;
    return 0;
  }

  array(int) low_decode_id(string a, string key)
  {
    if( catch(  a = Gmp.mpz( a, 36 )->digits( 256 ) ) )
      return 0; // Not very likely to work...
    object crypto = Crypto.arcfour();
    crypto->set_encrypt_key(key);
    string msg = crypto->crypt(a);
    // Fix the high-order bit altered by encode_id().
    msg[0] &= 0x7f;
    int i, j;
    if((sscanf(msg, "%d\327%d", i, j) == 2) &&
       (msg == i + "\327" + j)) {
      return ({ i, j });
    }
#ifndef NO_BROKEN_ARGCACHE_FALLBACK
    // Fallback -- Check if it's an old broken key.
    crypto->set_encrypt_key(key);
    msg = crypto->crypt("\0"+a);
    if((sscanf(msg, "%d\327%d", i, j) == 2) &&
       (msg == i + "\327" + j)) {
      return ({ i, j });
    }
#endif /* !NO_BROKEN_ARGCACHE_FALLBACK */
    return 0;
  }

  static array(int) decode_id( string a )
  {
    array(int) res;
    ensure_secret();
    if (res = low_decode_id(a, secret)) {
      return res;
    }
    return plugin_decode_id(a);
  }
  
  int key_exists( string key )
  //! Does the key 'key' exist in the cache? Returns 1 if it does, 0
  //! if it was not present.
  {
    if( cache[key] ) return 1;
    array i = decode_id( key );
    if(!i) return 0;
    return low_key_exists( i[0] ) && low_key_exists( i[1] );
  }

  string store( mapping args )
  //! Store a mapping (of purely encode_value:able data) in the
  //! argument cache. The string returned is your key to retrieve the
  //! data later.
  {
    array b = values(args), a = sort(indices(args),b);
    LOCK();
    int index_id = low_store( a );
    string id = encode_id( index_id, low_store( b, index_id ) );
    if( !cache[ id ] )
      cache[ id ] = args+([]);
    return id;
  }

  int low_store( array a, int|void index_id )
  {
    string data = encode_value_canonic( a );
    string hv = md5( data );
    if( mixed q = cache[ hv ] )
      return q;

#ifdef THREADS
    if( mixed q = cache[ hv ] )
      return q;
#endif
    if( sizeof( cache ) >= CACHE_SIZE )
      cache = ([]);

    int id = create_key( data, hv, index_id );
    cache[ hv ] = id;
    cache[ id ] = a;
    return id;
  }

  mapping lookup( string id )
  //! Recall a mapping stored in the cache. 
  {
    if( cache[id] )
      return cache[id]+([]);
    array i = decode_id( id );
    if( !i )
      error("Requesting unknown key (decode failed)\n");
    array a = low_lookup( i[0] );
    array b = low_lookup( i[1] );
    if (!arrayp (a) || !arrayp (b) || sizeof (a) != sizeof (b))
    {
      // Got lookup with ids from an old cache which has been zapped,
      // and the entries are now used for something else.
#ifdef ARG_CACHE_DEBUG
      werror("lookup(%O) a: %O, b: %O\n", id, a, b);
#endif
      error("Requesting unknown key (size missmatch)\n");
    }
    return (cache[id] = mkmapping( a, b ))+([]);
  }

  array low_lookup( int id )
  {
    mixed v;
    if( v = cache[id] )
      return v;
    string q = read_args( id );
    if( !q )
      error("Requesting unknown key (not found in db)\n");
    mixed data = decode_value(q);
    string hl = Crypto.md5()->update( q )->digest();
    cache[ hl ] = id;
    cache[ id ] = data;
    return data;
  }

  void delete( string id )
  //! Remove the data element stored under the key 'id'.
  {
    LOCK();
    (plugins->delete-({0}))( id );
    m_delete( cache, id );
    
    foreach( decode_id( id ), int id )
    {
      (plugins->low_delete-({0}))( id );
      if(cache[id])
      {
	m_delete( cache, cache[id] );
	m_delete( cache, id );
      }
      QUERY( "DELETE FROM "+name+" WHERE id="+id );
    }
  }

#define SECRET_TAG "££"
  
  int write_dump(Stdio.File file, int|void from_time)
  // Write a mapping from id to encoded arg string for all local arg
  // entries created after from_time to a file. Returns 0 if faled, 1
  // otherwise.
  {
    constant FETCH_ROWS = 10000;
    
    string encoded_secret = SECRET_TAG+MIME.encode_base64(secret, 1)+"\n";
    if(sizeof(encoded_secret) != file->write(encoded_secret))
      return 0;

    // The server does only need to use file based argcache
    // replication if the server don't participate in a replicate
    // setup with a shared database.
    if( !has_value((plugins->is_functional-({0}))(), 1) )
    {
      int cursor;
      array(int) ids;
      do {
	if(from_time)
	  // Only replicate entries accessed during the prefetch crawling.
	  ids = 
	    (array(int))
	    QUERY( "SELECT id from "+name+
		   " WHERE atime >= %d "
		   "   AND index_id IS NOT NULL"
		   " LIMIT %d, %d", from_time, cursor, FETCH_ROWS)->id;
	else
	  // Make sure _every_ entry is replicated when a dump is created.
	  ids = 
	    (array(int))
	    QUERY( "SELECT id from "+name+
		   " LIMIT %d, %d", cursor, FETCH_ROWS)->id;
	
	cursor += FETCH_ROWS;
	
	foreach(ids, int id) {
	  int index_id = read_index_id(id);
#ifdef REPLICATE_DEBUG
	  werror("write_dump: argcache id: %d, index_id: %d.\n", id, index_id);
#endif
	  
	  string s = 
	    MIME.encode_base64(encode_value(({ id, read_args(id),
					       index_id, read_args(index_id) })),
			       1)+"\n";
	  if(sizeof(s) != file->write(s))
	    return 0;
	}
      } while(sizeof(ids) == FETCH_ROWS);
    }
    return file->write("EOF\n") == 4;
  }

  static void create_remote_key(int id, string key,
				int index_id, string index_key,
				string server)
  {
    (plugins->create_remote_key-({0}))( id, key, index_id, index_key, server );
  }
  
  string read_dump (Stdio.FILE file)
  // Returns an error message if there was a parse error, 0 otherwise.
  {
    string secret = file->gets();
    // Note, old replication dumps can contain unencoded server secrets.
    if(secret && has_prefix(secret, SECRET_TAG))
      secret = MIME.decode_base64(secret[sizeof(SECRET_TAG)..]);

    if(!secret || !sizeof(secret))
      return "Server secret is missing\n";

    string s;
    while(s = file->gets())
    {
      if(s == "EOF")
	return 0;
      array a;
      if(catch {
	a = decode_value(MIME.decode_base64(s));
      }) return "Decode failed for argcache record\n";

      if(sizeof(a) != 4)
	return "Decode failed for argcache record (wrong size on key array)\n";
      
#ifdef REPLICATE_DEBUG
      werror("read_dump: argcache id: %d, index_id: %d.\n", a[0], a[2]);
#endif
      create_remote_key(a[0], a[1], a[2], a[3], secret);
    }
    if(s != "EOF")
      return "Missing data in argcache file\n";
    return 0;
  }

  void refresh_arg(string id)
  {
    array i = decode_id( id );
    if( !i )
      error("Requesting unknown key (decode failed)\n");
    LOCK();
    QUERY("UPDATE "+name+" SET atime='"+time(1)+"' WHERE id="+i[0]);
    QUERY("UPDATE "+name+" SET atime='"+time(1)+"' WHERE id="+i[1]);
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
	catch { mutex_key = euid_egid_lock->lock(); };
	threads_disabled = _disable_threads();
      }
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
    report_debug("\nEnabling the configuration %s ...\n", config);
    if(err=catch( enable_configuration(config)->start(0) ))
      report_error("\n"+LOC_M(35, "Error while loading configuration %s%s"),
                   config+":\n", describe_backtrace(err)+"\n");
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

mapping low_decode_image(string data, void|mixed tocolor)
{
  mapping w = Image._decode( data, tocolor );
  if( w->image ) return w;
  return 0;
}

constant decode_layers = Image.decode_layers;

mapping low_load_image(string f, RequestID id, void|mapping err)
{
  string data;
  Stdio.File file;
  if(id->misc->_load_image_called < 5)
  {
    // We were recursing very badly with the demo module here...
    id->misc->_load_image_called++;
    if(!(data=id->conf->try_get_file(f, id, 0, 0, 0, err)))
    {
      //  This is a major security hole! It can load any (image) file
      //  in the low-level file system using the server's user privileges.
      //
      //  file=Stdio.File();
      //  if(!file->open(f,"r") || !(data=file->read()))
#ifdef THREADS
        catch
        {
          string host = "";
          sscanf( f, "http://%[^/]", host );
          if( sscanf( host, "%*s:%*d" ) != 2)
            host += ":80";
          mapping hd = 
                  ([
                    "User-Agent":version(),
                    "Host":host,
                  ]);
          data = Protocols.HTTP.get_url_data( f, 0, hd );
        };
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
  Stdio.File file;
  mapping res = ([]);
  if(id->misc->_load_image_called < 5)
  {
    // We were recursing very badly with the demo module here...
    id->misc->_load_image_called++;
    if(!(data=id->conf->try_get_file(f, id, 0, 0, 0, res)))
    {
      //  This is a major security hole! It can load any (image) file
      //  in the low-level file system using the server's user privileges.
      //
      //  file=Stdio.File();
      //  if(!file->open(f,"r") || !(data=file->read()))
// #ifdef THREADS
        catch
        {
          data = Protocols.HTTP.get_url_nice( f )[1];
        };
// #endif
      if( !data )
	return res;
    }
  }
  id->misc->_load_image_called = 0;
  if(!data) return res;
  return decode_layers( data, opt );
}

Image.Image load_image(string f, RequestID id)
{
  mapping q = low_load_image( f, id );
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
#if efun(real_perror)
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
  if(catch(Stdio.write_file(where, sprintf("%d\n%d\n", getpid(), getppid()))))
    report_debug("I cannot create the pid file ("+where+").\n");
#endif
}

Pipe.pipe shuffle(Stdio.File from, Stdio.File to,
		  Stdio.File|void to2,
		  function(:void)|void callback)
{
#if efun(spider.shuffle)
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
#if efun(spider.shuffle)
  }
#endif
}

// Dump all threads to the debug log.
void describe_all_threads()
{
#if constant (thread_create)
  // Disable all threads to avoid potential locking problems while we
  // have the backtraces. It also gives an atomic view of the state.
  object threads_disabled = _disable_threads();

  report_debug("### Describing all Pike threads:\n\n");

  array(Thread.Thread) threads = all_threads();
  array(string|int) thread_ids =
    map (threads,
	 lambda (Thread.Thread t) {
	   string desc = sprintf ("%O", t);
	   if (sscanf (desc, "Thread.Thread(%d)", int i)) return i;
	   else return desc;
	 });
  sort (thread_ids, threads);

  int i;
  for(i=0; i < sizeof(threads); i++) {
    report_debug("### Thread %s%s:\n",
		 (string) thread_ids[i],
#ifdef THREADS
		 threads[i] == backend_thread ? " (backend thread)" : ""
#else
		 ""
#endif
		);
    report_debug(describe_backtrace(threads[i]->backtrace()) + "\n");
  }

  report_debug ("### Total %d Pike threads\n", sizeof (threads));

  threads = 0;
  threads_disabled = 0;
#else
  report_debug("Describing single thread:\n%s\n",
	       describe_backtrace (backtrace()));
#endif

#ifdef DEBUG
  report_debug (RoxenDebug.report_leaks());
#endif
}

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


class GCTimestamp
{
  array self_ref;
  static void create() {self_ref = ({this_object()});}
  static void destroy() {
    werror ("GC runs at %s", ctime(time()));
    GCTimestamp();
  }
}


array argv;
int main(int argc, array tmp)
{
  // __builtin.gc_parameters((["enabled": 0]));
  argv = tmp;
  tmp = 0;

#ifdef LOG_GC_TIMESTAMPS
  GCTimestamp();
#endif

  // For RBF
  catch(mkdir( "../var" ));
  
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

  if (!has_value (compat_levels, __roxen_version__))
    report_debug ("Warning: The current version %s does not exist in "
		  "roxen.compat_levels.\n", __roxen_version__);

  add_constant( "Protocol", Protocol );
#ifdef TIMERS
  call_out( show_timers, 30 );
#endif

#if constant(SSL.sslfile)
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

  set_locale();

#if efun(syslog)
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
  backend_thread = this_thread();
  name_thread( backend_thread, "Backend" );
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
  foreach( ({ "SIGBREAK", "SIGQUIT" }), string sig)
    catch( signal(signum(sig),async_sig_start(describe_all_threads,-1)));

  start_time=time();		// Used by the "uptime" info later on.

  restart_suicide_checker();

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
static object roxen_debug_info_obj;
void restart_roxen_debug_memory_trace()
{
  remove_call_out(restart_roxen_debug_memory_trace);

  if (!roxen_debug_info_obj) {
    roxen_debug_info_obj = ((program)"config_interface/actions/debug_info.pike"
)();
  }
  int t = time(0);
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
    else
      remove_call_out(restart_if_stuck);
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
    ((sscanf(s,"%*d.%*d.%*d.%*d")==4 && s[-1]>='0' && s[-1]<='9') || // IPv4
     (sizeof(s/":") > 1));	// IPv6
}

static string _sprintf( )
{
  return "roxen";
}

// Support for logging in configurations and modules.

class LogFormat
{
  static string host_ip_to_int(string s)
  {
    int a, b, c, d;
    sscanf(s, "%d.%d.%d.%d", a, b, c, d);
    return sprintf("%c%c%c%c",a, b, c, d);
  }

  static string extract_user(string from)
  {
    array tmp;
    if (!from || sizeof(tmp = from/":")<2)
      return "-";
    return tmp[0];      // username only, no password
  }

  void log( function do_write, RequestID id, mapping file );
  static void do_async_write( string host, string data, string ip, function c )
  {
    if( c ) 
      c( replace( data, "\4711", (host||ip) ) );
  }
}

static mapping(string:function) compiled_formats = ([ ]);

constant formats = 
({
  ({ "ip_number",   "%s",   "(string)request_id->remoteaddr",0 }),
  ({ "bin-ip_number","%s",  "host_ip_to_int(request_id->remoteaddr)",0 }),
  ({ "cern_date",   "%s",   "Roxen.cern_http_date( time( 1 ) )",0 }),
  ({ "bin-date",    "%4c",  "time(1)",0 }),
  ({ "method",      "%s",   "(string)request_id->method",0 }),
  ({ "resource",    "%s",   "(string)(request_id->raw_url||request_id->not_query)", 0 }),
  ({ "full_resource","%s",  "(string)(request_id->raw_url||request_id->not_query)",0 }),
  ({ "protocol",    "%s",   "(string)request_id->prot",0 }),
  ({ "response",    "%d",   "(int)(file->error || 200)",0 }),
  ({ "bin-response","%2c",  "(int)(file->error || 200)",0 }),
  ({ "length",      "%d",   "(int)file->len",0 }),
  ({ "bin-length",  "%4c",  "(int)file->len",0 }),
  ({ "vhost",       "%s",   "(request_id->misc->host||\"-\")", 0 }),
  ({ "referer",     "%s",    
     "sizeof(request_id->referer||({}))?request_id->referer[0]:\"-\"", 0 }),
  ({ "user_agent_raw",  "%s",    
     "request_id->client?request_id->client*\" \":\"-\"", 0 }),
  ({ "user_agent",  "%s",    
     "request_id->client?request_id->client*\"%20\":\"-\"", 0 }),
  ({ "user_id",     "%s",
     "(request_id->cookies&&request_id->cookies->RoxenUserID)||"
     "(request_id->misc->moreheads&&"
     " request_id->misc->moreheads[\"Set-Cookie\"]&&"
     " request_id->parse_cookies&&"
     " request_id->parse_cookies(request_id->misc->moreheads[\"Set-Cookie\"])"
     " ->RoxenUserID)||\"0\"",0 }),
  ({ "user",        "%s",    "extract_user( request_id->realauth )",0 }),
  ({ "request-time","%1.2f",  "time(request_id->time )",0 }),
  ({ "host",        "\4711",    0, 1 }), // unlikely to occur normally
  ({ "cache-status","%s",   ("sizeof(request_id->cache_status||({}))?"
			     "indices(request_id->cache_status)*\",\":"
			     "\"nocache\""), 0 }),
});

void run_log_format( string fmt, function c, RequestID id, mapping file )
{
  (compiled_formats[ fmt ] || compile_log_format( fmt ))(c,id,file);
}

function compile_log_format( string fmt )
{
  add_constant( "___LogFormat", LogFormat );
  if( compiled_formats[ fmt ] )
    return compiled_formats[ fmt ];

  string kmd5 = md5( fmt );

  array tmp =
    dbm_cached_get( "local" )
    ->query("SELECT full,enc FROM compiled_formats WHERE md5=%s", kmd5 );

  if( sizeof(tmp) && (tmp[0]->full == fmt) )
  {
    mixed err = catch {
      return compiled_formats[fmt] =
	decode_value( tmp[0]->enc, master()->MyCodec() )()->log;
    };
// #ifdef DEBUG
    report_error("Decoding of dumped log format failed:\n%s",
		 describe_backtrace(err));
// #endif
  }
  array parts = fmt/"$";
  string format = parts[0];
  array args = ({});
  int do_it_async = 0;
  int add_nl = 1;

  string sr( string s ) { return s[1..strlen(s)-2]; };
  // sr(replace(sprintf("%O", X), "%", "%%"))

#define DO_ES(X) replace(X, ({"\\n", "\\r", "\\t", }), ({ "\n", "\r", "\t" }) )

  foreach( parts[1..], string part )
  {
    int c, processed;
    foreach( formats, array q )
      if( part[..strlen(q[0])-1] == q[0])
      {
        format += q[1] + DO_ES(part[ strlen(q[0]) .. ]);
        if( q[2] ) args += ({ q[2] });
        if( q[3] ) do_it_async = 1;
        processed=1;
        break;
      }
    if( processed )
      continue;
    if( sscanf( part, "char(%d)%s", c, part ) )
      format += sprintf( "%"+(c<0?"-":"")+"c", abs( c ) )+DO_ES(part);
    else if( sscanf( part, "wchar(%d)%s", c, part ) )
      format += sprintf( "%"+(c<0?"-":"")+"2c", abs( c ) )+DO_ES(part);
    else if( sscanf( part, "int(%d)%s", c, part ) )
      format += sprintf( "%"+(c<0?"-":"")+"4c", abs( c ) )+DO_ES(part);
    else if( part[0] == '^' )
    {
      format += DO_ES(part[1..]);
      add_nl = 0;
    } else
      format += "$"+part;
  }
  if( add_nl ) format += "\n";

  string code = sprintf(
#"
  inherit ___LogFormat;
  void log( function callback, RequestID request_id, mapping file )
  {
     if(!callback) return;
     string data = sprintf( %O %{, %s%} );
", format, args );
 
  if( do_it_async )
  {
    code += 
#"
     roxen.ip_to_host(request_id->remoteaddr,do_async_write,
                      data, request_id->remoteaddr, callback );
   }
";
  } else
    code += 
#"  
   callback( data );
  }
";

  program res = compile_string(code);
  string enc = encode_value(res, master()->MyCodec(res));
  object con = dbm_cached_get("local");
  
  con->query("REPLACE INTO compiled_formats (md5,full,enc) VALUES (%s,%s,%s)",
	     kmd5, fmt, enc);
  con = 0;
  
  return compiled_formats[ fmt ] = res()->log;
}

// This array contains the compilation information for the different
// security checks for e.g. htaccess. The layout of the top array is
// triplet of sscanf string that the security command should match,
// the number of arguments that it takes and an array with the actual
// compilation information.
//
// ({ command_sscanf_string, number_of_arguments, actual_tests,
//    state_symbol_string,
// })
// 

// In the tests array the following types has the following meaning:
// function
//   The function will be run during compilation. It gets the values
//   acquired through sscanf-ing the command as input and should return
//   an array with corresponding data.
// string
//   The string will be compiled into the actual test code. It is
//   first modified as
//   str = sprintf(str, @args)
//   where args are the arguments from the command after it has been
//   processed by the provided function, if any.
// multiset
//   Strings in a multiset will be added before the string above.
//   should typically be used for variable declarations.
// int
//   Signals that an authentication request should be sent to the user
//   upon failure.
// 
// 
// NOTE: It's up to the security checks in this file to ensure that
// nothing is overcached. All patterns that perform checks using
// information from the client (such as remote address, referer etc)
// _have_ to use NOCACHE() or NO_PROTO_CACHE(). It's not necessary, however,
// to do that for checks that use the authentication module API, since
// then it's up to the user database and authentication modules to ensure
// that nothing is overcached in that case.
array(array(string|int|array)) security_checks = ({
  ({ "ip=%s:%s",2,({
    lambda( string a, string b ){
      int net  = Roxen.ip_to_int( a );
      int mask = Roxen.ip_to_int( b );
      net &= mask;
      return ({ net, sprintf("%c",mask)[0] });
    },
    "    if ((Roxen.ip_to_int(id->remoteaddr) & %[1]d) == %[0]d)",
    (<"  NO_PROTO_CACHE()" >),
  }), "ip" }),
  ({ "ip=%s/%d",2,({
    lambda( string a, int b ){
      int net  = Roxen.ip_to_int( a );
      int mask = ((~0<<(32-b))&0xffffffff);
      net &= mask;
      return ({ net, sprintf("%c",mask)[0] });
    },
    "    if ((Roxen.ip_to_int(id->remoteaddr) & %[1]d) == %[0]d) ",
    (<"  NO_PROTO_CACHE()" >),
  }), "ip", }),
  ({ "ip=%s",1,({
    "    if (sizeof(filter(%[0]O/\",\",\n"
    "                      lambda(string q){\n"
    "                        return glob(q,id->remoteaddr);\n"
    "                      })))",
    (<"  NO_PROTO_CACHE()" >),
  }), "ip", }),
  ({ "user=%s",1,({ 1,
    lambda( string x ) {
      return ({sprintf("(< %{%O, %}>)", x/"," )});
    },

    "    if ((user || (user = authmethod->authenticate(id, userdb_module)))\n"
    "         && ((%[0]s->any) || (%[0]s[user->name()]))) ",
    (<"  User user" >),
   // No need to NOCACHE () here, since it's up to the
   // auth-modules to do that.
  }), "user", }),
  ({ "group=%s",1,({ 1,
    lambda( string x ) {
      return ({sprintf("(< %{%O, %}>)", x/"," )});
    },
    "    if ((user || (user = authmethod->authenticate(id, userdb_module)))\n"
    "        && ((%[0]s->any) || sizeof(mkmultiset(user->groups())&%[0]s)))",
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
    (<"  NO_PROTO_CACHE()" >),
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
      "  string referer = sizeof(id->referer||({}))?"
      "id->referer[0]:\"\"; "
    >),
    "    if( sizeof(filter(%[0]O/\",\",\n"
    "                      lambda(string q){return glob(q,referer);})))",
    (<"  NO_PROTO_CACHE()" >),
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
//!  CMD accept_langauge=language  [return]
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

  string kmd5 = md5( pattern );

  array tmp =
    dbm_cached_get( "local" )
    ->query("SELECT full,enc FROM compiled_formats WHERE md5=%s", kmd5 );

  if( sizeof(tmp) && (tmp[0]->full == pattern) )
  {
    mixed err = catch {
      return decode_value( tmp[0]->enc, master()->MyCodec() )()->f;
    };
// #ifdef DEBUG
    report_error("Decoding of dumped log format failed:\n%s",
		 describe_backtrace(err));
// #endif
  }



  string code = "";
  array variables = ({ "  object userdb_module",
		       "  object authmethod = id->conf",
		       "  string realm = \"User\"",
		       "  mapping(string:int|mapping) state = ([])",
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
   
  dbm_cached_get( "local" )
    ->query("REPLACE INTO compiled_formats (md5,full,enc) VALUES (%s,%s,%s)",
	    kmd5,pattern,encode_value( res, master()->MyCodec( res ) ) );
  return compile_string(code)()->f;
}


static string cached_hostname = gethostname();

class LogFile(string fname)
{
  Stdio.File fd;
  int opened;

  void do_open()
  {
    mixed parent;
    if (catch { parent = function_object(object_program(this_object())); } ||
	!parent) {
      // Our parent (aka the configuration) has been destructed.
      // Time to die.
      remove_call_out(do_open);
      remove_call_out(do_close);
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
    mkdirhier( ff );
    fd = open( ff, "wac" );
    if(!fd) 
    {
      remove_call_out( do_open );
      call_out( do_open, 120 ); 
      report_error(LOC_M(37, "Failed to open logfile")+" "+fname+" "
#if constant(strerror)
                   "(" + strerror(errno()) + ")"
#endif
                   "\n");
      return;
    }
    opened = 1;
    remove_call_out( do_open );
    call_out( do_open, 900 ); 
  }
  
  void do_close()
  {
    destruct( fd );
    opened = 0;
  }

  array(string) write_buf = ({});
  static void do_the_write( )
  {
    if( !opened ) do_open();
    if( !opened ) return 0;
    fd->write( write_buf );
    write_buf = ({});
    remove_call_out( do_close );
    call_out( do_close, 10.0 );
  }

  int write( string what )
  {
    if( !sizeof( write_buf ) )
      call_out( do_the_write, 1 );
    write_buf += ({what});
    return strlen(what); 
  }
}

