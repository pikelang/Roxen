#if efun(seteuid)
#include <module.h>
string cvs_version = "$Id: privs.pike,v 1.23 1997/10/08 15:30:44 grubba Exp $";

int saved_uid;
int saved_gid;

#if !constant(report_notice)
#define report_notice werror
#define report_debug werror
#endif

#define LOGP (roxen && roxen->variables && roxen->variables->audit && GLOBVAR(audit))

#define error(X) do{array Y=backtrace();throw(({(X),Y[..sizeof(Y)-2]}));}while(0)

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
  if(sizeof(t)<2) return "";
  return (((t[0]||"Unknown program")-(_getcwd()+"/"))-"base_server/")+":"+t[1]+"\n";
}

#ifdef THREADS
mixed mutex_key;	// Only one thread may modify the euid/egid at a time.
#endif /* THREADS */

void create(string reason, int|string|void uid, int|void gid)
{
#ifdef HAVE_EFFECTIVE_USER
  array u;

#ifdef THREADS
  if (roxen->euid_egid_lock) {
    catch { mutex_key = roxen->euid_egid_lock->lock(); };
  }
#endif /* THREADS */

  if(getuid()) return;

  /* Needs to be here since root-priviliges may be needed to
   * use getpw{uid,nam}.
   */
  saved_uid = geteuid();
  saved_gid = getegid();
  seteuid(0);

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
      error("Unknown user: "+uid+"\n");
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
  catch { initgroups(u[0], u[3]); };
  gid = gid || getgid();
  int err = (int)setegid(gid);
  if (err < 0) {
    report_debug(sprintf("privs.pike: WARNING: Failed to set the effective group id to %d!\n"
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
      perror("privs.pike: WARNING: Assuming nobody-group.\n"
	     "Trying some alternatives...\n");
      // Assume we want the nobody group, and try a couple of alternatives
      foreach(({ 60001, 65534, -2 }), gid2) {
	perror("%d... ", gid2);
	if (initgroups(u[0], gid2) >= 0) {
	  if ((err = setegid(gid2)) >= 0) {
	    perror("Success!\n");
	    break;
	  }
	}
      }
    }
#endif /* HPUX_KLUDGE */
    if (err < 0) {
      perror("privs.pike: Failed\n");
      throw(({ sprintf("Failed to set EGID to %d\n", gid), backtrace() }));
    }
    perror("privs.pike: WARNING: Set egid to %d instead of %d.\n",
	   gid2, gid);
    gid = gid2;
  }
  if(getgid()!=gid) setgid(gid||getgid());
  seteuid(uid);
#endif /* HAVE_EFFECTIVE_USER */
}

void destroy()
{
#ifdef HAVE_EFFECTIVE_USER
  if(LOGP)
    report_notice(sprintf("Change back to uid#%d, from %s",saved_uid,
			  dbt(backtrace()[-2])));

  if(getuid()) return;

  seteuid(0);
  array u = getpwuid(saved_uid);
  if(u) initgroups(u[0], u[3]);
  setegid(saved_gid);
  seteuid(saved_uid);
#endif /* HAVE_EFFECTIVE_USER */
}
#endif
