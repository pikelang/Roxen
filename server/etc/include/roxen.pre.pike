mapping make_mapping(string *f)
{
  mapping foo=([ ]);
  string s, a, b;
  foreach(f, s)
  {
    sscanf(s, "%s=%s", a, b);
    foo[a]=b;
  }
  return foo;
}

int low_spawne(string s,string *args, mapping|array env, object stdin, 
	   object stdout, object stderr, void|string wd)
{
  object p;
  int pid;
  string t;

  if(arrayp(env))
    env = make_mapping(env);
  if(!mappingp(env)) 
    env=([]);
  
  
  stdin->dup2(File("stdin"));
  stdout->dup2(File("stdout"));
  stderr->dup2(File("stderr"));
  if(stringp(wd) && sizeof(wd))
    cd(wd);
  exece(s, args, env);
  perror(sprintf("Spawne: Failed to exece %s\n", s));
  exit(0);
}

int spawne(string s,string *args, mapping|array env, object stdin, 
	   object stdout, object stderr, void|string wd, void|array (int) uid)
{
  int pid, *olduid = allocate(2, "int");
  if(pid=fork())
    return pid;
  if(arrayp(uid) && sizeof(uid) == 2)
  {
#if efun(seteuid)
    olduid = ({ geteuid(), getegid() });
    seteuid(0);
#endif
#if efun(setegid)
    setegid(getgid());
#endif
    setgid(uid[1]);
    setuid(uid[0]);
    if(!getuid())
    {
#if efun(seteuid)
      setgid(olduid[1]);
      setuid(olduid[0]);
#else
      setgid(-1);
      setuid(-1);
#endif
    } else {
      olduid = ({ geteuid(), getegid() });
#if efun(seteuid)
      seteuid(0);
#endif
#if efun(setegid)
      setegid(getgid());
#endif
      setgid(olduid[1]);
      setuid(olduid[0]);
    }
  }
  catch(low_spawne(s, args, env, stdin, stdout, stderr, wd)); 
  exit(0); 
}

void create()
{
   add_constant("spawne",spawne);
   add_constant("perror",werror);
}