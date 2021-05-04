// The Roxen Webserver main program.
// Copyright � 1996 - 2000, Roxen IS.
//
// Per Hedbor, Henrik Grubbstr�m, Pontus Hagland, David Hedbor and others.

// ABS and suicide systems contributed freely by Francesco Chemolli
constant cvs_version="$Id$";

// Used when running threaded to find out which thread is the backend thread.
Thread.Thread backend_thread;

// The argument cache. Used by the image cache.
ArgCache argcache;

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
// inherit "language";
inherit "supports";
inherit "module_support";
inherit "config_userdb";

// --- Locale defines ---

//<locale-token project="roxen_start">   LOC_S </locale-token>
//<locale-token project="roxen_message"> LOC_M </locale-token>
#define LOC_S(X,Y)	_STR_LOCALE("roxen_start",X,Y)
#define LOC_M(X,Y)	_STR_LOCALE("roxen_message",X,Y)
#define CALL_M(X,Y)	_LOCALE_FUN("roxen_message",X,Y)

// --- Debug defines ---

#ifdef SSL3_DEBUG
# define SSL3_WERR(X) werror("SSL3: "+X+"\n")
#else
# define SSL3_WERR(X)
#endif

#ifdef THREAD_DEBUG
# define THREAD_WERR(X) werror("Thread: "+X+"\n")
#else
# define THREAD_WERR(X)
#endif

#define DDUMP(X) sol( combine_path( __FILE__, "../../" + X ), dump )
static function sol = master()->set_on_load;

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

#ifdef THREADS
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

#if efun(cleargroups)
    catch { cleargroups(); };
#endif /* cleargroups */
#if efun(initgroups)
    catch { initgroups(u[0], u[3]); };
#endif
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
	throw(({ sprintf("Failed to set EGID to %d\n", gid), backtrace() }));
      }
      report_debug("Privs: WARNING: Set egid to %d instead of %d.\n",
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
	  report_notice(LOC_M(3,"Change back to uid#%d gid#%d, from %s")+"\n",
			saved_uid, saved_gid, dbt(bt[-2]));
	} else {
	  report_notice(LOC_M(4,"Change back to uid#%d gid#%d, "
			      "from backend")+"\n", saved_uid, saved_gid);
	}
      };
    }

    if(getuid()) return;

#ifdef PRIVS_DEBUG
    int uid = geteuid();
    if (uid != new_uid) {
      werror("Privs: UID #%d differs from expected #%d\n"
	     "%s\n",
	     uid, new_uid, describe_backtrace(backtrace()));
    }
    int gid = getegid();
    if (gid != new_gid) {
      werror("Privs: GID #%d differs from expected #%d\n"
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
  array(string) available_fonts( );
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

// When true, roxen will shut down as soon as possible.
local static int die_die_die;

// Function that actually shuts down Roxen. (see low_shutdown).
private static void really_low_shutdown(int exit_code)
{
  // Die nicely. Catch for paranoia reasons
#ifdef THREADS
  catch( stop_handler_threads() );
#endif /* THREADS */
  exit( exit_code );		// Now we die...
}

// Shutdown Roxen
//  exit_code = 0	True shutdown
//  exit_code = -1	Restart
private static void low_shutdown(int exit_code)
{
  catch
  {
    stop_all_configurations();
    int pid;
    if (exit_code) {
      report_debug("Restarting Roxen.\n");
    } else {
      report_debug("Shutting down Roxen.\n");
      // exit(0);
    }
  };
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

/*
 * handle() stuff
 */

#ifdef THREADS
// function handle = threaded_handle;

Thread do_thread_create(string id, function f, mixed ... args)
{
  Thread.Thread t = thread_create(f, @args);
  catch(t->set_name( id ));
  return t;
}

// Shamelessly uses facts about pikes preemting algorithm.
// Might have to be fixed in the future.
class Queue 
//! Thread.Queue lookalike, which uses some archaic and less
//! known features of the preempting algorithm in pike to optimize the
//! read function.
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
    while(!(w_ptr - r_ptr)) r_cond::wait();
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

// This is easier than when there is no threads.
// See the discussion below. :-)
function async_sig_start( function f, int really )
{
  return lambda( mixed ... args ) { thread_create( f, @args ); };
}
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
  while(1)
  {
    if(q=catch {
      do {
	THREAD_WERR("Handle thread ["+id+"] waiting for next event");
	if(arrayp(h = handle_queue->read())) {
	  if (!h[0]) {
	    THREAD_WERR(sprintf("Handle thread [%O] got NULL callback: %O(%{%O, %})",
				id, h[0], h[1] / 1));
	    continue;
	  }
	  THREAD_WERR(sprintf("Handle thread [%O] calling %O(%{%O, %})",
				id, h[0], h[1] / 1));
	  set_locale();
	  h[0](@h[1]);
	  h=0;
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
	  if (Thread.Condition cond = hold_wakeup_cond) cond->wait();
	  threads_on_hold--;
	  THREAD_WERR("Handle thread [" + id + "] released");
	}
      } while(1);
    }) {
      if (h = catch {
	report_error(/*LOCALE("", "Uncaught error in handler thread: %s"
		       "Client will not get any response from Roxen.\n"),*/
		     describe_backtrace(q));
	if (q = catch {h = 0;}) {
	  report_error(LOC_M(5, "Uncaught error in handler thread: %s Client"
			     "will not get any response from Roxen.")+"\n",
		       describe_backtrace(q));
	}
      }) {
	catch {
	  report_error("Error reporting error:\n");
	  report_error(sprintf("Raw error: %O\n", h[0]));
	  report_error(sprintf("Original raw error: %O\n", q[0]));
	};
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
static array(object) handler_threads = ({});
//! The handler threads, the list is kept for debug reasons.

void start_handler_threads()
{
  if (query("numthreads") <= 1) {
    set( "numthreads", 1 );
    report_notice (LOC_S(1, "Starting one thread to handle requests.")+"\n");
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
//! responding. Any thread that haven't arrived to the hold state
//! since @[hold_handler_threads] is considered nonresponding.
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

    THREAD_WERR("Releasing " + was_on_hold + " threads on hold");
    cond->broadcast();

    if (threads_to_create > 0) {
      array(object) new_threads = ({});
      for (threads_to_create = 0;
	   threads_on_hold < numthreads;
	   number_of_threads++, threads_to_create++)
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
      if( async_called )
      {
        report_debug("\n\n"
                     "Async calling failed for %O, calling synchronous\n", f);
        report_debug("Backtrace at time of hangup:\n%s\n",
                     describe_backtrace( backtrace() ));
        f( @args );
        return;
      }
      async_called=1;
      call_out( really_call, 0, args );
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
#endif /* THREADS */


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

class InternalRequestID
//! ID for internal requests that are not linked to any real request.
{
  inherit RequestID;

  static void create()
  {
    client = ({ "Roxen" });
    prot = "INTERNAL";
    method = "GET";
    real_variables = ([]);
    variables = FakedVariables( real_variables );

    misc = ([]);
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
  inherit Stdio.Port: port;
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
  //! The IP-number (0 for ANY) this port is bound to
  int refs;
  //! The number of references to this port
  program requesthandler;
  //! The per-connection request handling class
  array(string) sorted_urls = ({});
  //! Sorted by length, longest first
  mapping(string:mapping) urls = ([]);
  //! .. url -> ([ "conf":.., ... ])

  void ref(string name, mapping data)
  //! Add a ref for the URL 'name' with the data 'data'
  {
    if(urls[name])
    {
      urls[name] = data;
      return; // only ref once per URL
    }
    if (!refs) path = data->path;
    else if (path != (data->path || "")) path = 0;
    refs++;
    urls[name] = data;
    sorted_urls = Array.sort_array(indices(urls), 
                                 lambda(string a, string b) {
                                   return sizeof(a)<sizeof(b);
                                 });
  }

  void unref(string name)
  //! Remove a ref for the URL 'name'
  {
//     if(!urls[name]) // only unref once
//       return;

    m_delete(urls, name);
    if (!path && sizeof (Array.uniq (values (urls)->path)) == 1)
      path = values (urls)[0]->path;
    sorted_urls -= ({name});
    if( !--refs )
      destruct( ); // Close the port.
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



#define INIT(X) do{mapping _=(X);string __=_->path;c=_->conf;if(__&&id->adjust_for_config_path) id->adjust_for_config_path(__);if(!c->inited)c->enable_all_modules(); } while(0)

  Configuration find_configuration_for_url( string url, RequestID id, 
                                            int|void no_default )
  //! Given a url and requestid, try to locate a suitable configuration
  //! (virtual site) for the request. 
  //! This interface is not at all set in stone, and might change at 
  //! any time.
  {
    Configuration c;
    if( sizeof( urls ) == 1 )
    {
      if(!mu) mu=urls[sorted_urls[0]];
      INIT( mu );
      return c;
    }

    url = lower_case( url );
    // The URLs are sorted from longest to shortest, so that short
    // urls (such as http://*/) will not match before more complete
    // ones (such as http://*.roxen.com/)
    foreach( sorted_urls, string in )
    {
      if( glob( in+"*", url ) )
      {
        INIT( urls[in] );
	return c;
      }
    }
    
    if( no_default )
      return 0;
    
    // No host matched, or no host header was included in the request.
    // Is the URL in the '*' ports?
    mixed i;
    if( !functionp(sp_fcfu) && ( i=open_ports[ name ][ 0 ][ port ] ) )
      sp_fcfu = i->find_configuration_for_url;
    
    if( sp_fcfu && (sp_fcfu != find_configuration_for_url)
	&& (i = sp_fcfu( url, id, 1 )))
      return i;
    
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
	  return c;
	}

      // if there is no such servers, pick the first default server
      // available. FIXME: This makes it impossible to handle the
      // server path correctly.

      c = ((array)choices)[0];
      if(!c->inited) c->enable_all_modules();
      return c;
    }


    // if we end up here, there is no default port at all available
    // so grab the first configuration that is available at all.
    INIT( urls[sorted_urls[0]] );
    id->misc->defaulted=1;
    return c;
  }

  mixed query_option( string x )
  //! Query the port-option 'x' for this port. 
  {
    return query( x );
  }

  string get_key()
  //! Return he key used for this port (protocol:ip:portno)
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

  static void create( int pn, string i )
  //! Constructor. Bind to the port 'pn' ip 'i'
  {
    port = pn;
    ip = i;

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
    ::create();
    if(!bind( port, got_connection, ip ))
    {
      report_error(LOC_M(6, "Failed to bind %s://%s:%d/ (%s)")+"\n", 
		   (string)name, (ip||"*"), (int)port, strerror( errno() ));
      bound = 0;
    } else
      bound = 1;
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
  SSL.context ctx;

  class destruct_protected_sslfile
  {
    SSL.sslfile sslfile;

    mixed `[](string s)
    {
      return sslfile[s];
    }

    mixed `[]=(string s, mixed val)
    {
      return sslfile[s] = val;
    }

    mixed `->(string s)
    {
      return sslfile[s];
    }

    mixed `->=(string s, mixed val)
    {
      return sslfile[s] = val;
    }

    void destroy()
    {
      if (sslfile)
	sslfile->close();
    }

    void create(object q)
    {
      sslfile = SSL.sslfile(q, ctx);
    }
  }

  Stdio.File accept()
  {
    Stdio.File q = ::accept();
    if (q)
      return [object(Stdio.File)](object)destruct_protected_sslfile(q);
    return 0;
  }

  void create(int pn, string i)
  {
    ctx = SSL.context();
    set_up_ssl_variables( this_object() );
    port = pn;
    ip = i;

    restore();
    
    Privs privs = Privs("Reading cert file");

    string f, f2;

    if( catch{ f = lopen(query_option("ssl_cert_file"), "r")->read(); } )
    {
      report_error(LOC_M(8,"SSL3: Reading cert-file failed!")+"\n");
      destruct();
      return;
    }

    if( strlen(query_option("ssl_key_file")) &&
        catch{ f2 = lopen(query_option("ssl_key_file"),"r")->read(); } )
    {
      report_error(LOC_M(9, "SSL3: Reading key-file failed!")+"\n");
      destruct();
      return;
    }

    if (privs)
      destruct(privs);

    object msg = Tools.PEM.pem_msg()->init( f );
    object part = msg->parts["CERTIFICATE"] || msg->parts["X509 CERTIFICATE"];
    string cert;

    if (!part || !(cert = part->decoded_body())) 
    {
      report_error(LOC_M(10, "SSL3: No certificate found.")+"\n");
      destruct();
      return;
    }

    if( f2 )
      msg = Tools.PEM.pem_msg()->init( f2 );

    function r = Crypto.randomness.reasonably_random()->read;

    SSL3_WERR(sprintf("key file contains: %O", indices(msg->parts)));

    if (part = msg->parts["RSA PRIVATE KEY"])
    {
      string key;

      if (!(key = part->decoded_body())) 
      {
	report_error(LOC_M(11,"SSL3: Private rsa key not valid")+" (PEM).\n");
	destruct();
	return;
      }

      object rsa = Standards.PKCS.RSA.parse_private_key(key);
      if (!rsa) 
      {
	report_error(LOC_M(11, "SSL3: Private rsa key not valid")+" (DER).\n");
	destruct();
	return;
      }

      ctx->rsa = rsa;

      SSL3_WERR(sprintf("RSA key size: %d bits", rsa->rsa_size()));

      if (rsa->rsa_size() > 512)
      {
	/* Too large for export */
	ctx->short_rsa = Crypto.rsa()->generate_key(512, r);

	// ctx->long_rsa = Crypto.rsa()->generate_key(rsa->rsa_size(), r);
      }
      ctx->rsa_mode();

      object tbs = Tools.X509.decode_certificate (cert);
      if (!tbs) 
      {
	report_error(LOC_M(13,"SSL3: Certificate not valid (DER).")+"\n");
	destruct();
	return;
      }
      if (!tbs->public_key->rsa->public_key_equal (rsa)) 
      {
	report_error(LOC_M(14, "SSL3: Certificate and private key do not "
			   "match.")+"\n");
	destruct();
	return;
      }
    }
    else if (part = msg->parts["DSA PRIVATE KEY"])
    {
      string key;

      if (!(key = part->decoded_body())) 
      {
	report_error(LOC_M(15,"SSL3: Private dsa key not valid")+" (PEM).\n");
	destruct();
	return;
      }

      object dsa = Standards.PKCS.DSA.parse_private_key(key);
      if (!dsa) 
      {
	report_error(LOC_M(15,"SSL3: Private dsa key not valid")+" (DER).\n");
	destruct();
	return;
      }

      SSL3_WERR(sprintf("Using DSA key."));

      dsa->use_random(r);
      ctx->dsa = dsa;
      /* Use default DH parameters */
      ctx->dh_params = SSL.cipher.dh_parameters();

      ctx->dhe_dss_mode();

      // FIXME: Add cert <-> private key check.
    }
    else 
    {
      report_error(LOC_M(17,"SSL3: No private key found.")+"\n");
      destruct();
      return;
    }

    ctx->certificates = ({ cert });
    ctx->random = r;

#if EXPORT
    ctx->export_mode();
#endif
    ::create(pn, i);
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
  werror("Protocol handlers ... ");
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
#if !constant(HTTPLoop.prog)
    if( s == "fhttp" ) continue;
#endif
    werror( s+" " );

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
    werror( s+" " );
    catch {
#ifdef DEBUG
      protocols[ s ] = (program)("../local/protocols/prot_"+s+".pike");
#else
      protocols[ s ] = lazy_load( ("../local/protocols/prot_"+s+".pike"),s );
#endif
    };
  }
  werror(" [%.1fms]\n", (gethrtime()-st)/1000.0 );
  return protocols;
}


mapping protocols;

mapping(string:mapping) open_ports = ([ ]);
mapping(string:object) urls = ([]);
array sorted_urls = ({});

array(string) find_ips_for( string what )
{
  if( what == "*" || lower_case(what) == "any" )
    return 0;

  if( is_ip( what ) )
    return ({ what });

  array res = gethostbyname( what );
  if( !res || !sizeof( res[1] ) )
    report_error(LOC_M(46, "Cannot possibly bind to %O, that host is "
		       "unknown. Substituting with ANY")+"\n", what);
  else
    return Array.uniq(res[1]);
}

void unregister_url( string url )
{
  string ourl = url;
  url = lower_case( url );
  string host, path, protocol;
  int port;
  if (!sizeof (url - " " - "\t")) return;

  url = replace( url, "/ANY", "/*" );
  url = replace( url, "/any", "/*" );

  sscanf( url, "%[^:]://%[^/]%s", protocol, host, path );
  if (!host || !stringp(host))   return;
  if( !protocols[ protocol ] )    return;

  sscanf(host, "%[^:]:%d", host, port);

  if( !port )
  {
    port = protocols[ protocol ]->default_port;
    url = protocol+"://"+host+":"+port+path;
  }

  report_debug("Unregister "+url+"\n");

  if( urls[ url ] && urls[ url ]->port )
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

  if( urls[ url ] && urls[ url ]->conf )
  {
    if( urls[ url ]->conf != conf )
    {
      report_error(LOC_M(20, "Cannot register URL %s, "
			    "already registered by %s!")+"\n",
		   url, urls[ url ]->conf->name);
      return 0;
    }
    urls[ url ]->port->ref(url, urls[url]);
    return 1;
  } 
  else if( urls[ url ] ) 
  {
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

  array(string) required_hosts;

  if (is_ip(host))
    required_hosts = ({ host });
  else
    required_hosts = find_ips_for( host );

  if (!required_hosts)
    required_hosts = ({ 0 });	// ANY

  mapping m;
  if( !( m = open_ports[ protocol ] ) )
    // always add 'ANY' (0) here, as an empty mapping, for speed reasons.
    // There is now no need to check for both open_ports[prot][0] and
    // open_ports[prot][0][port], we can go directly to the latter
    // test.
    m = open_ports[ protocol ] = ([ 0:([]) ]); 

  if( sizeof( required_hosts - ({ 0 }) ) // not ANY
      && m[ 0 ][ port ]
      && prot->supports_ipless )
    // The ANY port is already open for this port, and since this
    // protocol supports IP-less virtual hosting, there is no need to
    // open yet another port, that would mosts probably only conflict
    // with the ANY port anyway. (this is true on most OSes, it works
    // on Solaris, but fails on linux)
    required_hosts = ({ 0 });


  urls[ url ] = ([ "conf":conf, "path":path ]);
  urls[ ourl ] = ([ "conf":conf, "path":path ]);
  sorted_urls += ({ url });

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
      report_error(sprintf("Initializing the port handler for URL " +
			   url + " failed!\n"
			   "%s\n",
			   describe_backtrace(err)));
      continue;
    }

    if( !( m[ required_host ][ port ] ) )
    {
      m_delete( m[ required_host ], port );
      failures++;
      if (required_host) {
	report_warning(LOC_M(22, "Binding the port on IP %s "
			      "failed\n   for URL %s!\n"),
		       url, required_host);
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
    if( !mod->error_log )
      mod->error_log = ([]);
    mod->error_log[log_index] += ({ log_time });
  }
  if( conf )
  {
    if( !conf->error_log )
      conf->error_log = ([]);
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
  //werror("New unique id: "+current_user_id_number+"\n");
  current_user_id_file->seek(0);
  current_user_id_file->write((string)current_user_id_number);
  current_user_id_file_last_mod = current_user_id_file->stat()[2];
  return current_user_id_number;
}

private int unique_id_counter;
string create_unique_id()
{
  object md5 = Crypto.md5();
  md5->update(query("server_salt") + (unique_id_counter++) + time(1));
  return Crypto.string_to_hex(md5->digest());
}
#endif

#ifndef __NT__
static int abs_started;

void restart_if_stuck (int force)
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
  signal(signum("SIGALRM"),
	 lambda( int n ) {
	   report_debug("**** %s: ABS engaged!\n"
			"Trying to dump backlog: \n",
			ctime(time()) - "\n");
	   catch {
	     // Catch for paranoia reasons.
	     describe_all_threads();
	   };
	   report_debug("**** %s: ABS exiting roxen!\n\n",
			ctime(time()));
	   _exit(1); 	// It might now quit correctly otherwise, if it's
	   //  locked up
	 });
  alarm (60*query("abs_timeout")+10);
}
#endif


class ImageCache
//! The image cache handles the behind-the-scenes caching and
//! regeneration features of graphics generated on the fly. Besides
//! being a cache, however, it serves a wide variety of other
//! interesting image conversion/manipulation functions as well.
{
  Sql.Sql db;
  string name;
  string dir;
  function draw_function;
  mapping meta_cache = ([]);

  string documentation(void|string tag_n_args) {
    string doc = Stdio.read_file("base_server/image_cache.xml");
    if(!doc) return "";
    if(!tag_n_args)
      return Parser.HTML()->add_container("ex", "")->finish(doc)->read();
    return replace(doc, "###", tag_n_args);
  }

  static mapping meta_cache_insert( string i, mapping what )
  {
    return meta_cache[i] = what;
  }

  static mixed frommapp( mapping what )
  {
    if( !zero_type(what[""]) ) return what[""];
    return what;
  }

  static void draw( string name, RequestID id )
  {
    mixed args = Array.map( Array.map( name/"$", argcache->lookup, id->client ), frommapp);
    mapping meta;
    string data;
    array guides;
    mixed reply = draw_function( @copy_value(args), id );

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
      void sort_guides()
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
	  case "auto":
	    [ x0, y0, x1, y1 ] = reply->find_autocrop();
	    x1 -= x0;
	    y1 -= y0;
	}
      }

#define SCALEI 1
#define SCALEF 2
#define CROP   4

      void do_scale_and_crop( int x0, int y0,
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


	if( type & SCALEF )
	{
	  reply = reply->scale( w );
	  if( alpha )
	    alpha = alpha->scale( w );
	}
	if( (type & SCALEI) &&
	    ((reply->xsize() != w)  || (reply->ysize() != h)) )
	{
	  if( !(w && reply->xsize() > w) ) { if( h ) w = 0; } else h=0;
	  if( !(h && reply->ysize() > h) ) { if( w ) h = 0; } else w=0;
	  reply = reply->scale( w,h );
	  if( alpha )
	    alpha = alpha->scale( w,h );
	}
      };
      
      if( args->scale )
      {
        int x, y;
        if( sscanf( args->scale, "%d,%d", x, y ) == 2)
	  do_scale_and_crop( x0, y0, x1, y1, x, y, SCALEI|CROP );
        else if( (float)args->scale < 3.0)
	  do_scale_and_crop( x0, y0, x1, y1,
			     ((float)args->scale), ((float)args->scale),
			     SCALEF|CROP );
      }
      else
	if( args->maxwidth || args->maxheight ||
	    args["max-width"] || args["max-height"] )
      {
        int x = (int)args->maxwidth|| (int)args["max-width"];
        int y = (int)args->maxheight||(int)args["max-height"];
	do_scale_and_crop( x0, y0, x1, y1, x, y, SCALEI|CROP );
      }
      else
	do_scale_and_crop( x0, y0, x1, y1, 0, 0, CROP );

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
           error("Image format "+format+" unknown\n");
	 data = Image[upper_case( format )]->encode( reply, enc_args );
      }

      meta =
      ([
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
              "Expected ([ \"meta\": ([metadata]), \"data\":\"data\" ])\n"
	      "Got %O\n", reply);
    }
    // Avoid throwing and error if the same image is rendered twice.
    catch(store_data( name, data, meta ));
  }

  static void store_data( string id, string data, mapping meta )
  {
    if(!stringp(data)) return;
    meta_cache_insert( id, meta );
    string meta_data = encode_value( meta );
    db->query( "INSERT INTO "+name+"_data VALUES (%s,%s,%s)",
               id,meta_data,data);
    db->query( "INSERT INTO "+name+" VALUES ('"+id+"', "+strlen(data)+
	       ", UNIX_TIMESTAMP(), UNIX_TIMESTAMP())" );
  }

  static mapping restore_meta( string id )
  {
    if( meta_cache[ id ] )
      return meta_cache[ id ];

    array(mapping(string:string)) q = db->query("SELECT meta FROM "+
                                                name+"_data WHERE id='"+
                                                id+"'");
    if(!sizeof(q))
      return 0;

    db->query("UPDATE "+name+" SET atime=UNIX_TIMESTAMP() WHERE id='"+id+"'" );

    string s = q[0]->meta;
    mapping m;
    if (catch (m = decode_value (s)))
    {
      report_error( "Corrupt data in cache-entry "+id+".\n" );
      db->query( "DELETE FROM "+name+" WHERE id='"+id+"'" );
      db->query( "DELETE FROM "+name+"_data WHERE id='"+id+"'" );
      return 0;
    }
    return meta_cache_insert( id, m );
  }

  void flush(int|void age)
  //! Flush the cache. If an age (an integer as returned by
  //! <pi>time()</pi>) is provided, only images with their latest access before
  //! that time are flushed.
  {
    report_debug("Flushing "+name+" image cache.\n");
    if( !age )
    {
      db->query( "DELETE FROM "+name );
      db->query( "DELETE FROM "+name+"_data" );
      return;
    }

    array(string) ids = db->query( "SELECT id FROM "+name+" WHERE atime < "+age)->id;

    int q;
    while(q<sizeof(ids)) {
      string list = ids[q..q+100] * "','";
      q+=100;

      db->query( "DELETE FROM "+name+     " WHERE id in ('"+list+"')" );
      db->query( "DELETE FROM "+name+"_data WHERE id in ('"+list+"')" );
    }

    catch
    {
      // Old versions of Mysql lacks OPTIMIZE. Not that we support
      // them, really, but it might be nice not to throw an error, at
      // least.
      db->query( "OPTIMIZE TABLE "+name+"_data" );
      db->query( "OPTIMIZE TABLE "+name );
    };

    meta_cache = ([]);
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

    q=db->query("SHOW TABLE STATUS");
    foreach(q, mapping qq)
      if(has_prefix(qq->Name, name)) {
	imgs = (int)qq->Rows;
	size += (int)qq->Data_length;
      }

    if(age) {
      q=db->query("select SUM(1) as num from "+name+" where atime < "+age);
      aged = (int)q[0]->num;
    }
    return ({ imgs, size, aged });
  }

  static mapping rst_cache = ([ ]);
  static mapping restore( string id )
  {
    if( rst_cache[ id ] )
      return rst_cache[ id ] + ([]);

    array q = db->query( "SELECT data FROM "+name+"_data WHERE id=%s",id);
    if( sizeof(q) )
    {
      string f = q[0]->data;
      // Caches. Thus, it's faster than doing decode_value each time here.
      mapping m = restore_meta( id );
      if( !m ) return 0;

      m = Roxen.http_string_answer( f, m->type||("image/gif") );
      
      if( strlen( f ) > 6000 )
	return m;
      rst_cache[ id ] = m;
      if( sizeof( rst_cache ) > 100 )
	rst_cache = ([ "id":m ]);
      return rst_cache[ id ] + ([]);
    }
  }


  string data( array|string|mapping args, RequestID id, int|void nodraw )
  //! Returns the actual raw image data of the image rendered from the
  //! `data' instructions.
  //!
  //! A non-zero `nodraw' parameter means an image not already in the
  //! cache will not be rendered on the fly, but instead return zero.
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

  mapping http_file_answer( array|string|mapping data,
                            RequestID id,
                            int|void nodraw )
  //! Returns a <ref>result mapping</ref> like one generated by
  //! <ref>Roxen.http_file_answer()</ref> but for the image file
  //! rendered from the `data' instructions.
  //!
  //! Like <ref>metadata</ref>, a non-zero `nodraw' parameter means an
  //! image not already in the cache will not be rendered on the fly,
  //! but instead return zero (for request not handled).
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

  mapping metadata( array|string|mapping data,
		    RequestID id,
		    int|void nodraw )
  //! Returns a mapping of image metadata for an image generated from
  //! the data given (as sent to <ref>store()</ref>). If a non-zero
  //! `nodraw' parameter is given and the image was not in the cache,
  //! it will not be rendered on the fly to get the correct data.
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
  //! Store the data your draw callback expects to receive as its
  //! first argument(s). If the data is an array, the draw callback
  //! will be called like <pi>callback( @data, id )</pi>.
  {
    string ci;
    if( mappingp( data ) ) {
      if (!data->format) {
	//  Make implicit format choice explicit
#if constant(Image.GIF) && constant(Image.GIF.encode)
	data->format = "gif";
#else
	data->format = "png";
#endif
      }
      ci = argcache->store( data );
    } else if( arrayp( data ) ) {
      if (!data[0]->format) {
	//  Make implicit format choice explicit
#if constant(Image.GIF) && constant(Image.GIF.encode)
	data[0]->format = "gif";
#else
        data[0]->format = "png";
#endif
      }
      ci = map( map( data, tomapp ), argcache->store )*"$";
    } else
      ci = data;
    return ci;
  }

  void set_draw_function( function to )
  //! Set a new draw function.
  {
    draw_function = to;
  }

  static void setup_tables()
  {
    if(catch(db->query("select id from "+name+" where id=-1")))
    {
      db->query("CREATE TABLE "+name+" ("
                "id CHAR(64) NOT NULL PRIMARY KEY, "
                "size INT UNSIGNED NOT NULL DEFAULT 0, "
                "ctime INT UNSIGNED NOT NULL DEFAULT 0, "
                "atime INT UNSIGNED NOT NULL DEFAULT 0)");

      db->query("CREATE TABLE "+name+"_data ("
                "id CHAR(64) NOT NULL PRIMARY KEY, "
		"meta MEDIUMBLOB NOT NULL DEFAULT '',"
                "data MEDIUMBLOB NOT NULL DEFAULT '')");
    }
  }


  static void init_db( )
  {
    meta_cache = ([]);
    db = master()->resolv( "DBManager.get" )( "local" );
    if( !db )
      report_fatal("No 'shared' database!\n");
    catch(setup_tables());
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
    // Support that the 'shared' database moves.
    master()->resolv( "DBManager.add_dblist_changed_callback" )( init_db );
  }
}


class ArgCache
//! Generic cache for storing away a persistent mapping of data to be
//! refetched later by a short string key. This being a cache, your
//! data may be thrown away at random when the cache is full.
{
  static Sql.Sql db;
  static string name;

#define CACHE_VALUE 0
#define CACHE_SKEY  1
#define CACHE_SIZE  600
#define CLEAN_SIZE  100

  static string lq, ulq;
  class DBLock
  {
    static void create()
    {
      if(!lq)
      {
	lq = "select GET_LOCK('"+name+"', 4)";
	ulq = "select RELEASE_LOCK('"+name+"')";
      }
      db->query( lq );
    }
    static void destroy()
    {
      db->query( ulq );
    }
  }
  
# define LOCK() DBLock __ = DBLock()

  static mapping (string:mixed) cache = ([ ]);

  static void setup_table()
  {
    if(catch(db->query("SELECT id FROM "+name+" WHERE id=-1")))
      db->query("CREATE TABLE "+name+" ("
                "id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, "
                "hash INT NOT NULL DEFAULT 0, "
                "atime INT UNSIGNED NOT NULL DEFAULT 0, "
                "contents BLOB NOT NULL DEFAULT '', "
                "INDEX hind (hash))");
  }

  static void init_db()
  {
    // Delay DBManager resolving to before the 'roxen' object is
    // compiled.
    cache = ([]);
    db = master()->resolv( "DBManager.get" )( "shared" );
    setup_table( );
  }

  static void create( string _name )
  {
    name = _name;
    init_db();
    // Support that the 'local' database moves (not really nessesary,
    // but it won't hurt either)
    master()->resolv( "DBManager.add_dblist_changed_callback" )( init_db );
  }

  static string read_args( string id )
  {
    array res = db->query("SELECT contents FROM "+name+" WHERE id="+id);
    if( sizeof(res) )
    {
      db->query("UPDATE "+name+" SET atime='"+time(1)+"' WHERE id="+id);
      return res[0]->contents;
    }
    return 0;
  }

  static string create_key( string long_key )
  {
    array data = db->query("SELECT id,contents FROM "+name+" WHERE hash=%d",
			   hash(long_key));
    foreach( data, mapping m )
      if( m->contents == long_key )
        return m->id;

    db->query( "INSERT INTO "+name+" (contents,hash,atime) VALUES "
	       "(%s,%d,UNIX_TIMESTAMP())",
	       long_key, hash(long_key) );
    return (string)db->master_sql->insert_id();
  }


  int key_exists( string key )
  //! Does the key 'key' exist in the cache? Returns 1 if it does, 0
  //! if it was not present.
  {
    return sizeof( db->query( "SELECT id FROM "+name+" WHERE id="+(int)key));
  }

  string store( mapping args )
  //! Store a mapping (of purely encode_value:able data) in the
  //! argument cache. The string returned is your key to retrieve the
  //! data later.
  {
    array q;
#if 1
    array b = values(args), a = sort(indices(args),b);
    string data = encode_value(({a,b}));
#else
    string data = encode_value_canonic( args );
#endif
    if( q = cache[ data ] )
      return q[ CACHE_SKEY ];

    LOCK();
    if( q = cache[ data ] )
      return q[ CACHE_SKEY ];

    if( sizeof( cache ) >= CACHE_SIZE )
    {
      array i = indices(cache);
      while( sizeof(cache) > CACHE_SIZE-CLEAN_SIZE ) {
        string idx=i[random(sizeof(i))];
        if(arrayp(cache[idx])) {
          m_delete( cache, cache[idx][CACHE_SKEY] );
          m_delete( cache, idx );
        }
        else {
          m_delete( cache, cache[idx] );
          m_delete( cache, idx );
        }
      }
    }

    string id = create_key( data );
    cache[ data ] = ({ 0, 0 });
    cache[ data ][ CACHE_VALUE ] = copy_value( args );
    cache[ data ][ CACHE_SKEY ] = id;
    cache[ id ] = data;
    return id;
  }

  mapping lookup( string id, array|void client )
  //! Recall a mapping stored in the cache. The optional client array
  //! may be supplied to get an error message stating the browser name
  //! in the event of the key not being present any more in the cache.
  {
    mixed v ;
    if( (v=cache[id]) && (v=cache[ v ]) )
      return v[CACHE_VALUE];

    string q = read_args( id );

    if(!q) error("Requesting unknown key\n");

    mixed data = decode_value(q);

    if( !mappingp( data ) )
      data = mkmapping( data[0],data[1] );
     
    cache[ q ] = ({data,id});
    cache[ id ] = q;
    return data;
  }

  void delete( string id )
  //! Remove the data element stored under the key 'id'.
  {
    if(cache[id])
    {
      m_delete( cache, cache[id] );
      m_delete( cache, id );
    }
    db->query( "DELETE FROM "+name+" WHERE id="+(int)id );
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
  __REG_PROJ("roxen_start",   "translations/%L/roxen_start.xml");
  __REG_PROJ("roxen_config",  "translations/%L/roxen_config.xml");
  __REG_PROJ("roxen_message", "translations/%L/roxen_message.xml");
  __REG_PROJ("admin_tasks",   "translations/%L/admin_tasks.xml");
  Locale.set_default_project_path("translations/%L/%P.xml");
#undef __REG_PROJ

  define_global_variables();

  // This is currently needed to resolve the circular references in
  // RXML.pmod correctly. :P
  master()->resolv ("RXML.refs");
  master()->resolv ("RXML.PXml");
  master()->resolv ("RXML.PEnt");
  foreach(({ "module.pmod","PEnt.pike", "PExpr.pike","PXml.pike",
	     "refs.pmod","utils.pmod" }), string q )
    dump( "etc/modules/RXML.pmod/"+ q );
  dump( "etc/modules/RXML.pmod/module.pmod" );
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


  // for module encoding stuff

  add_constant( "CFUserDBModule",config_userdb_module );
  
  add_constant( "ArgCache", ArgCache );
  //add_constant( "roxen.load_image", load_image );

  add_constant( "roxen", this_object());
  //add_constant( "roxen.decode_charset", decode_charset);

//   add_constant( "DBManager", ((object)"base_server/dbs.pike") );

  DDUMP( "etc/modules/DBManager.pmod");
  DDUMP( "base_server/roxenlib.pike");
  DDUMP( "base_server/html.pike");
  DDUMP( "etc/modules/Dims.pmod");
  DDUMP( "config_interface/boxes/Box.pmod" );
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

int set_u_and_gid()
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

  u=query("User");
  sscanf(u, "%s:%s", u, g);
  if(strlen(u))
  {
    if(getuid())
    {
      report_error(LOC_M(24, "It is only possible to change uid and gid "
			 "if the server is running as root.")+"\n");
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
      Thread.MutexKey mutex_key;
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
	if (u) report_notice(CALL_M("setting_uid_gid_permanently",  "eng")
			     (uid, gid, u, g));
#else
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
	if (u) report_notice(CALL_M("setting_uid_gid", "eng")(uid, gid, u, g));
#else
	report_warning(LOC_M(32, "Setting effective uid not supported on "
			     "this system.")+"\n");
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
      sp( "shared", conf,  2 );
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
  Configuration cf = _configuration( name );
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
  shutdown();
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

mapping low_load_image(string f, RequestID id)
{
  string data;
  Stdio.File file;
  if(id->misc->_load_image_called < 5)
  {
    // We were recursing very badly with the demo module here...
    id->misc->_load_image_called++;
    if(!(data=id->conf->try_get_file(f, id)))
    {
      file=Stdio.File();
      if(!file->open(f,"r") || !(data=file->read()))
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

array(Image.Layer) load_layers(string f, RequestID id, mapping|void opt)
{
  string data;
  Stdio.File file;
  if(id->misc->_load_image_called < 5)
  {
    // We were recursing very badly with the demo module here...
    id->misc->_load_image_called++;
    if(!(data=id->conf->try_get_file(f, id)))
    {
      file=Stdio.File();
      if(!file->open(f,"r") || !(data=file->read()))
#ifdef THREADS
        catch
        {
          data = Protocols.HTTP.get_url_nice( f )[1];
        };
#endif
      if( !data )
	return 0;
    }
  }
  id->misc->_load_image_called = 0;
  if(!data) return 0;
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
  where = replace(where, ({ "$pid", "$uid" }),
		  ({ (string)getpid(), (string)getuid() }));

  r_rm(where);
  if(catch(Stdio.write_file(where, sprintf("%d\n%d", getpid(), getppid()))))
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


static private int _recurse;
// FIXME: Ought to use the shutdown code.
void exit_when_done()
{
  report_debug("Interrupt request received.\n");
  die_die_die=1;

  if(++_recurse > 4)
  {
    report_debug("Exiting roxen (spurious signals received).\n");
    stop_all_configurations();
#ifdef THREADS
    stop_handler_threads();
#endif /* THREADS */
    exit(-1);	// Restart.
  }

  report_debug("Exiting roxen.\n");
  stop_all_configurations();
#ifdef THREADS
  stop_handler_threads();
#endif /* THREADS */
  exit(-1);	// Restart.
}

void exit_it()
{
  report_debug("Recursive signals.\n");
  exit(-1);	// Restart.
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

  report_debug("Describing all threads:\n");
  int i;
  for(i=0; i < sizeof(all_backtraces); i++) {
    report_debug("Thread %d:\n"
		 "%s\n",
		 i+1,
		 describe_backtrace(all_backtraces[i]));
  }
}

constant dump = roxenloader.dump;

program slowpipe, fastpipe;

void initiate_argcache()
{
  int t = gethrtime();
  report_debug( "Initiating argument cache ... ");
  if( mixed e = catch( argcache = ArgCache("arguments") ) )
  {
    report_fatal( "Failed to initialize the global argument cache:\n"
                  + (describe_backtrace( e )/"\n")[0]+"\n");
    exit(1);
  }
  add_constant( "roxen.argcache", argcache );
  report_debug("Done [%.2fms]\n", (gethrtime()-t)/1000.0);
}

array argv;
int main(int argc, array tmp)
{
  tmp = 0;
  argv = tmp;
  slowpipe = ((program)"base_server/slowpipe");
  fastpipe = ((program)"base_server/fastpipe");
  dump( "base_server/slowpipe.pike" );
  dump( "base_server/fastpipe.pike" );
  dump( "base_server/throttler.pike" );

  add_constant( "Protocol", Protocol );
#if constant(SSL.sslfile)
  add_constant( "SSLProtocol", SSLProtocol );
#endif

  dump( "etc/modules/Variable.pmod/module.pmod" );
  dump( "etc/modules/Variable.pmod/Language.pike" );

  DDUMP(  "base_server/state.pike" );
  DDUMP(  "base_server/highlight_pike.pike" );
  DDUMP(  "base_server/wizard.pike" );
  DDUMP(  "base_server/proxyauth.pike" );
  DDUMP(  "base_server/module.pike" );
  DDUMP(  "base_server/throttler.pike" );

  mark_fd(0, "Stdin");
  mark_fd(1, "Stdout");
  mark_fd(2, "Stderr");

  configuration_dir =
    Getopt.find_option(argv, "d",({"config-dir","configuration-directory" }),
	     ({ "ROXEN_CONFIGDIR", "CONFIGURATIONS" }), "../configurations");

  if(configuration_dir[-1] != '/')
    configuration_dir += "/";

  restore_global_variables(); // restore settings...

  // Dangerous...
  mixed tmp_root;
  if(tmp_root = Getopt.find_option(argv, "r", "root")) fix_root(tmp_root);

  argv -= ({ 0 });
  argc = sizeof(argv);

  add_constant( "roxen.fonts",
                (fonts = ((program)"base_server/fonts.pike")()) );


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



  protocols = build_protocols_mapping();  
  enable_configurations();

  set_u_and_gid(); // Running with the right [e]uid:[e]gid from this point on.

  create_pid_file(Getopt.find_option(argv, "p", "pid-file", "ROXEN_PID_FILE")
		  || query("pidfile"));

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
  catch( this_thread()->set_name("Backend") );
  backend_thread = this_thread();
#endif /* THREADS */

  // Signals which cause a restart (exitcode != 0)
  foreach( ({ "SIGINT", "SIGTERM" }), string sig)
    catch( signal(signum(sig), async_sig_start(exit_when_done,0)) );

  catch(signal(signum("SIGHUP"),async_sig_start(reload_all_configurations,1)));

  // Signals which cause Roxen to dump the thread state
  foreach( ({ "SIGQUIT", "SIGUSR1", "SIGUSR2", "SIGTRAP" }), string sig)
    catch( signal(signum(sig),async_sig_start(describe_all_threads,-1)));

  start_time=time();		// Used by the "uptime" info later on.


  if (query("suicide_engage"))
    call_out (restart,60*60*24*max(1,query("suicide_timeout")));
#ifndef __NT__
  restart_if_stuck( 0 );
#endif
#ifdef __RUN_TRACE
  trace(1);
#endif
  return -1;
}

// Called from the administration interface.
string check_variable(string name, mixed value)
{
  switch(name)
  {
#ifndef __NT__
   case "abs_engage":
    if (value)
      restart_if_stuck(1);
    else
      remove_call_out(restart_if_stuck);
    break;
#endif

   case "suicide_engage":
    if (value)
      call_out(restart,60*60*24*max(1,query("suicide_timeout")));
    else
      remove_call_out(restart);
    break;
  }
}

int is_ip(string s)
{
  return (sscanf(s,"%*d.%*d.%*d.%*d")==4 && s[-1]>47 && s[-1]<58);
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
  ({ "referer",     "%s",    
     "sizeof(request_id->referer||({}))?request_id->referer[0]:\"-\"", 0 }),
  ({ "user_agent",  "%s",    
     "request_id->client?request_id->client*\"%20\":\"-\"", 0 }),
  ({ "user_id",     "%s",    "(request_id->cookies&&request_id->cookies->RoxenUserID)||\"0\"",0 }),
  ({ "user",        "%s",    "extract_user( request_id->realauth )",0 }),
  ({ "request-time","%1.2f",  "time(request_id->time )",0 }),
  ({ "host",        "\4711",    0, 1 }), // unlikely to occur normally
});

void run_log_format( string fmt, function c, RequestID id, mapping file )
{
  (compiled_formats[ fmt ] || compile_log_format( fmt ))(c,id,file);
}

function compile_log_format( string fmt )
{
  if( compiled_formats[ fmt ] )
    return compiled_formats[ fmt ];

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

  add_constant( "___LogFormat", LogFormat );
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
  return compiled_formats[ fmt ] = compile_string( code )()->log;
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

