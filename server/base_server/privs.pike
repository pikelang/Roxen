#if efun(seteuid)
#include <module.h>
string cvs_version = "$Id: privs.pike,v 1.9 1997/04/27 21:27:01 grubba Exp $";

int saved_uid;
int saved_gid;

#define LOGP (roxen && roxen->variables && roxen->variables->audit && GLOBVAR(audit))

#define error(X) do{array Y=backtrace();throw(({(X),Y[..sizeof(Y)-2]}));}while(0)

static private string dbt(array t)
{
  if(sizeof(t)<2) return "";
  return (((t[0]||"Unknown program")-(getcwd()+"/"))-"base_server/")+":"+t[1]+"\n";
}


void create(string reason, int|string|void uid, int|void gid)
{
  array u;

  if(getuid()) return;
  if(!stringp(uid))
    u = getpwuid(uid);
  else
  {
    u = getpwnam(uid);
    if(u) 
      uid = u[2];
  }

  if(u && !gid) gid = u[3];
  
  if(!u) error("Unknown user: "+uid+"\n");

  if(LOGP)
    perror("Change to %s privs wanted (%s), from %s",u[0],reason,
	   dbt(backtrace()[-2]));

  if(getuid()) return;

  saved_uid = geteuid();
  saved_gid = getegid();
  seteuid(0);
  initgroups(u[0], u[3]);
  setegid(gid||getgid());
  if(getgid()!=gid) setgid(gid||getgid());
  seteuid(uid);
}

void destroy()
{
  if(LOGP)
    perror("Change back to uid#%d, from %s",saved_uid, dbt(backtrace()[-2]));

  if(getuid()) return;

  seteuid(0);
  array u = getpwuid(saved_uid);
  if(u) initgroups(u[0], u[3]);
  setegid(saved_gid);
  seteuid(saved_uid);
}
#endif
