
static int check_jre_dir(string dir)
{
  if(!dir || dir=="" || dir[0]!='/')
    return 0;
  if(!file_stat(dir+"/lib/rt.jar"))
    return 0;
  if(!file_stat(dir+"/lib/flavormap.properties"))
    return 0;
  return 1;
}

static string findjre()
{
  string dir =
    (Process.popen("java -verbose 2>&1 | sed -n -e 's/^[^/]*//' -e "
		   "'s:/lib/rt.jar .*$::' -e p -e q")||"")-"\n";  
  if(check_jre_dir(dir))
    return dir;
  foreach(`+(@Array.map(({"/usr/local", "/usr"}),
			lambda(string s) {
			  return Array.map(Array.map(({"jre*","jdk*","java*"}),
						     glob,
						     get_dir(s)||"")*({}),
					   lambda(string sb) {
					     return s+"/"+sb;
					   });
			})), string d) {
    if(d && d!="")
      if(check_jre_dir(d+"/jre"))
	return d+"/jre";
      else if(check_jre_dir(d))
	return d;
  }
  return 0;
}

void run(object env)
{
  string jrehome, arch, threads_type="native_threads";
  write("  Checking for Java 2 (TM)...");
  if(!(jrehome=getenv("JREHOME")))
    jrehome=findjre();
  if(!jrehome)
    jrehome = env->get("JREHOME");
  if(!jrehome) {
    write(" not found\n");
    return;
  }
  write("\n  => JREHOME="+jrehome+"\n");
  env->set("JREHOME", jrehome);
  arch = (Process.popen("(/usr/bin/uname -p||uname -p) 2>/dev/null")||"")-"\n";
  if(arch=="unknown")
    arch = (Process.popen("uname -m | sed -e 's/^i[4-9]86/i386/'")||"")-"\n";
  if(arch == "")
    arch = "_";
  foreach(({arch+"/"+threads_type, arch+"/classic", arch}), string dir) {
    array(int) s = file_stat(jrehome+"/lib/"+dir);
    if(s && s[1]==-2)
      env->append("LD_LIBRARY_PATH", jrehome+"/lib/"+dir);
  }
}
