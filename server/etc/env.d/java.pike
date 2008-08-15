
protected int check_jre_dir(string dir)
{
  if(!dir || dir=="" || dir[0]!='/')
    return 0;
  if(!file_stat(dir+"/lib/rt.jar"))
    return 0;
  if(!file_stat(dir+"/lib/flavormap.properties"))
    return 0;
  string v = Process.popen(dir+"/bin/java -version 2>&1");
  if(2 <= sscanf(v, "java version \"%d.%d.%d", int maj, int min, int bld)) {
    if(maj < 1)
      return 0;
    if(maj > 1 || min > 2)
      return 1;
    if(min < 2)
      return 0;
    return bld >= 2;
  } else
    return 1;
}

protected string findjre()
{
  string dir = combine_path(combine_path(getcwd(), __FILE__),
			    "../../../java/jre");
  if(check_jre_dir(dir))
    return dir;

  dir =
    (Process.popen("java -verbose 2>&1 | sed -n -e 's/^[^/]*//' -e "
		   "'s:/lib/rt\\.jar.*$::' -e p -e q")||"")-"\n";  

  //  Mac OS X uses a non-standard directory
  if (has_value(dir, "JavaVM.framework"))
    return "/System/Library/Frameworks/JavaVM.framework/Versions/"
           "CurrentJDK/Home/";

  if(check_jre_dir(dir))
    return dir;
  foreach(`+(@Array.map(({"/usr/local", "/usr", "/usr/java"}),
			lambda(string s) {
			  return Array.map(Array.map(({"jre*","jdk*","java*"}),
						     glob,
						     reverse(sort(get_dir(s)||
								  ({""}))))*
					   ({}),
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
  write("   Checking for Java 2 (TM)...");
  if(!(jrehome=getenv("JREHOME")))
    jrehome=findjre();
  if(!jrehome)
    jrehome = env->get("JREHOME");
  if(!jrehome) {
    write(" not found\n");
    return;
  }
  write(" JREHOME="+jrehome+"\n");
  env->set("JREHOME", jrehome);

  array archs = ({ 
    (Process.popen("(/usr/bin/uname -p||uname -p) 2>/dev/null | sed -e 's/^i[4-9]86/i386/'")||"")-"\n",
    (Process.popen("(/usr/bin/uname -m||uname -m) 2>/dev/null | sed -e 's/^i[4-9]86/i386/'")||"")-"\n"
  });
  
  foreach(Array.uniq(archs), string arch)
  {
    if(arch == "")
      arch = "_";
    else if(arch == "x86_64")
      arch = "amd64";
  
    foreach(({arch+"/"+threads_type, arch+"/classic", arch+"/server", arch}), string dir) {
      mixed s = file_stat(jrehome+"/lib/"+dir);
      if(s && s[1]==-2)
	env->append("LD_LIBRARY_PATH", jrehome+"/lib/"+dir);
    }
  }
  
  /* AIX */
  if(file_stat(jrehome+"/bin/libjava.a"))
    env->append("LIBPATH", jrehome+"/bin/:"+jrehome+"/bin/classic/" );

  //  Only add _JAVA_OPTIONS if user hasn't got it already
  if (!env->get("_JAVA_OPTIONS"))
    env->set("_JAVA_OPTIONS", "\"-Xmx256m -Xrs\"");
}
