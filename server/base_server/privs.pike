#if efun(seteuid)
#include <module.h>
string cvs_version = "$Id: privs.pike,v 1.3 1996/12/08 10:55:42 neotron Exp $";

int saved_uid;
int saved_gid;

#define LOGP (roxen && roxen->variables && roxen->variables->audit && GLOBVAR(audit))

void create(string reason, int|void uid, int|void gid)
{
  if(getuid()) return;

  if(LOGP)
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
  if(LOGP)
    perror("Changed back to uid#"+saved_uid+" privs, from\n"+
	   describe_backtrace(backtrace()));
  seteuid(0);
  setegid(saved_gid);
  seteuid(saved_uid);
}
#endif
