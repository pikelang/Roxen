#if efun(seteuid)
#include <module.h>
string cvs_version = "$Id: privs.pike,v 1.5 1996/12/10 04:47:33 per Exp $";

int saved_uid;
int saved_gid;

#define LOGP (roxen && roxen->variables && roxen->variables->audit && GLOBVAR(audit))

static private string dbt(array t)
{
  if(sizeof(t)<2) return "";
  return (((t[0]||"Unknown program")-(getcwd()+"/"))-"base_server/")+":"+t[1]+"\n";
}


void create(string reason, int|void uid, int|void gid)
{
  if(LOGP)
    perror("Change to ROOT privs wanted ("+reason+"), from "+dbt(backtrace()[-2]));

  saved_uid = geteuid();
  saved_gid = getegid();

  if(getuid()) return;

  saved_uid = geteuid();
  saved_gid = getegid();
  seteuid(0);
  seteuid(uid);
  setegid(gid||getgid());
}

void destroy()
{
  if(LOGP)
    perror("Change back to uid#"+saved_uid+" requested, from "+
	   dbt(backtrace()[-2]));

  if(getuid()) return;

  seteuid(0);
  setegid(saved_gid);
  seteuid(saved_uid);
}
#endif
