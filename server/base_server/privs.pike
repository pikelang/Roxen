#if efun(seteuid)
#include <module.h>
string cvs_version = "$Id: privs.pike,v 1.2 1996/12/07 11:37:42 neotron Exp $";

int saved_uid;
int saved_gid;

void create(string reason, int|void uid, int|void gid)
{
  if(getuid()) return;

  if(roxen->variables->audit && GLOBVAR(audit))
    perror("Changed to ROOT privs ("+reason+"), from\n"+describe_backtrace(backtrace()));
  saved_uid = geteuid();
  saved_gid = getegid();
  seteuid(0);
  seteuid(uid);
  setegid(gid||getgid());
}

void destroy()
{
  if(getuid()) return;
  if(roxen->variables->audit && GLOBVAR(audit))
    perror("Changed back to uid#"+saved_uid+" privs, from\n"+
	   describe_backtrace(backtrace()));
  seteuid(0);
  setegid(saved_gid);
  seteuid(saved_uid);
}
#endif
