
void run(object env)
{
  write("\n   Configuring port number for external access to the internal\n"
	"   MySQL database (leave empty for no external access).\n"
	"\n");
  
  Stdio.File infd = Stdio.stdin, outfd = Stdio.stdout;
  Stdio.Terminfo.Termcap term = Stdio.Terminfo.getTerm();
  Tools.Install.Readline rl = Tools.Install.Readline();
  string in = rl->edit(env->get("ROXEN_MYSQL_TCP_PORT") || "",
		       "MySQL port number: ");
  write("\n");
  sscanf(in, "%d", int port);
  if(port)
  {
    if((string)port != env->get("ROXEN_MYSQL_TCP_PORT"))
      env->set("ROXEN_MYSQL_TCP_PORT", port);
  }
  else
    env->remove("ROXEN_MYSQL_TCP_PORT");
}
