
void run(object env)
{
  object f = Stdio.File();
  array(array(string)) oracles = ({});
  string sid, home, bootstart;
  write("   Checking for Oracle...");
  if((sid = getenv("ORACLE_SID")) && (home = getenv("ORACLE_HOME")))
    oracles += ({ ({ sid, home }) });
  foreach(({"/var/opt/oracle/oratab", "/etc/oratab"}), string oratab)
    if(f->open(oratab, "r"))
    {
      foreach(f->read()/"\n", string line)
	if(sizeof(line) && line[0]!='#' &&
	   3==sscanf(line, "%s:%s:%s", sid, home, bootstart) &&
	   Array.search_array(oracles, equal, ({ sid, home })))
	  oracles += ({ ({ sid, home }) });
      f->close();
    }
  if(!sizeof(oracles) &&
     (sid=env->get("ORACLE_SID")) && (home=env->get("ORACLE_HOME")))
    oracles += ({ ({ sid, home }) });
  if(!sizeof(oracles)) {
    write(" not found\n");
    return;
  }
  while(sizeof(oracles)>1) {
    write("\n   Multiple Oracle instances found.  Please select the "
	  "preferred one:\n");
    foreach(indices(oracles), int i)
      write(sprintf("     %2d) %s (in %s)\n", i+1, @oracles[i]));
    write("   Enter preference (or 0 to skip this step) > ");
    string in = Stdio.stdin.gets();
    int x;
    if(1==sscanf(in, "%d", x) && x>=0 && x<=sizeof(oracles))
      if(x==0)
	return;
      else
	oracles = ({ oracles[x-1] });
    else
      write("  Please enter a number in range 0--" + sizeof(oracles) + ".\n");
  }
  write(sprintf(" ORACLE_SID=%s, ORACLE_HOME=%s\n", @oracles[0]));
  env->set("ORACLE_SID", oracles[0][0]);
  env->set("ORACLE_HOME", oracles[0][1]);
  env->append("LD_LIBRARY_PATH", oracles[0][1]+"/lib");
}
