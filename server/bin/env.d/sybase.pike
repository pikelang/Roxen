
void run(object env)
{
  string sybdir;
  write("   Checking for Sybase...");
  if(!(sybdir=getenv("SYBASE")))
    foreach(({"/opt","/usr/opt","/usr", "/usr/local","/mp"}), string dir2)
      foreach(sort(glob("sybase*", get_dir(dir2) || ({}))), string dir)
      {
	dir = dir2+"/"+dir;
	if(file_stat(dir+"/lib"))
	{
	  sybdir = dir;
	  break;
	}
      }
  if(!sybdir)
    sybdir = env->get("SYBASE");
  if(!sybdir) {
    write(" not found\n");
    return;
  }
  write(" SYBASE="+sybdir+"\n");
  env->set("SYBASE", sybdir);
  env->append("LD_LIBRARY_PATH", sybdir+"/lib");
}
