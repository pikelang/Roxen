#if efun(seteuid)
#include <module.h>
string cvs_version = "$Id: privs.pike,v 1.4 1996/12/10 04:40:32 per Exp $";

int saved_uid;
int saved_gid;

#define LOGP (roxen && roxen->variables && roxen->variables->audit && GLOBVAR(audit))

void create(string reason, int|void uid, int|void gid)
{
  if(LOGP)
    perror("Change to ROOT privs wanted ("+reason+"), from\n"+describe_backtrace(backtrace()[1..2]));

  if(getuid()) return;

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
