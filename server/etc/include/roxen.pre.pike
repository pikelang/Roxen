import files;

void roxen_perror(string format,mixed ... args);

#if !efun(error)
#define error(X) do{array Y=backtrace();throw(({(X),Y[..sizeof(Y)-2]}));}while(0)
#endif /* !error */

string popen(string s, void|mapping env, int|void uid, int|void gid)
{
  object p,p2;

  p2 = file();
  p=p2->pipe();
  if(!p) error("Popen failed. (couldn't create pipe)\n");

  if(!fork())
  {
    array (int) olduid = ({ -1, -1 });
    catch {
      if(p->query_fd() < 0)
      {
	roxen_perror("File to dup2 to closed!\n");
	exit(99);
      }
      p->dup2(file("stdout"));
      if(uid || gid)
      {
	object privs = ((program)"privs")("Executing script as non-www user");
	olduid = ({ uid, gid });
	setgid(olduid[1]);
	setuid(olduid[0]);
#if efun(initgroups)
	array pw = getpwuid((int)uid);
	if(pw) initgroups(pw[0], (int)olduid[0]);
#endif
      }
      catch(exece("/bin/sh", ({ "-c", s }), (env||getenv())));
    };
    exit(69);
  }else{
    string t;
    destruct(p);
    t=p2->read(0x7fffffff);
    destruct(p2);
    return t;
  }
}


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
  
  
  stdin->dup2(file("stdin"));
  stdout->dup2(file("stdout"));
  stderr->dup2(file("stderr"));
  if(stringp(wd) && sizeof(wd))
    cd(wd);
  exece(s, args, env);
  roxen_perror(sprintf("Spawne: Failed to exece %s\n", s));
  exit(0);
}

int spawne(string s,string *args, mapping|array env, object stdin, 
	   object stdout, object stderr, void|string wd, void|array (int) uid)
{
  int pid, *olduid = allocate(2, "int");
  object privs;

  if(pid=fork()) return pid;

  if(arrayp(uid) && sizeof(uid) == 2)
  {
    privs = ((program)"privs")("Executing program as non-www user (outside roxen)");
    setgid(uid[1]);
    setuid(uid[0]);
  } 
  catch(low_spawne(s, args, env, stdin, stdout, stderr, wd));
  exit(0); 
}

private static int perror_last_was_newline=1;

void roxen_perror(string format,mixed ... args)
{
   string s;
   int lwn;
   s=((args==({}))?format:sprintf(format,@args));
   if (s=="") return;
   if ( (lwn = (s[-1]=="\n")) )
      s=s[0..strlen(s)-2];
   string ts = getpid()+": "+(ctime(time())/" ")[-2]+": ";
   werror((perror_last_was_newline? ts: "")+
	  replace(s, "\n", "\n"+ts)+
	  (lwn?"\n":""));
   perror_last_was_newline=lwn;
}

void create()
{
   add_constant("spawne",spawne);
   add_constant("perror",roxen_perror);
   add_constant("roxen_perror",roxen_perror);
   add_constant("popen",popen);
}
