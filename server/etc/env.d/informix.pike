
void run(object env)
{
  string infdir;
  write("Checking for Informix...");
  if(!(infdir=getenv("INFORMIXDIR")))
    foreach(({"/opt/informix","/usr/opt/informix","/usr/informix",
	      "/usr/local/informix","/mp/informix"}), string dir)
      if(file_stat(combine_path(dir, "bin/oninit"))) {
	infdir = dir;
	break;
      }
  if(!infdir)
    infdir = env->get("INFORMIXDIR");
  if(!infdir) {
    write("no\n");
    return;
  }
  write("\n  => INFORMIXDIR="+infdir+"\n");
  env->set("INFORMIXDIR", infdir);
  env->append("LD_LIBRARY_PATH", infdir+"/cli/dlls:"+infdir+"/lib/esql:"+
	      infdir+"/lib");
}
