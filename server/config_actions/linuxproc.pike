/*
 * $Id: linuxproc.pike,v 1.2 1997/10/11 07:37:11 neotron Exp $
 */

inherit "wizard";
constant name= "Status//Extended process status";
constant doc = "Shows detailed process status and process tree on Linux machines.";

constant more=1;

void create()
{
  if(!file_stat("/usr/bin/pstree")) {
    throw("You need /usr/bin/pstree to be installed\n");
  }
  if(!file_stat("/proc/1/status")) {
    throw("You need a kernel with the proc filesystem mounted.\n");
  }
}

string format_proc_line(string in, int ipid)
{
  string pre;
  int pid;
  sscanf(in, "%*s(%d)%*s", pid);
  sscanf(in,"%[ ]%s",pre,in);
//  pre=replace(pre,"  "," |");
  if(search(in,"/proc/")==-1)
    return (pre+
	    "<a href=/Actions/?action=linuxproc.pike&pid="+pid+"&unique="+time()+">"+
	    (ipid==pid?"<b>":"")+
	    html_encode_string(in)+
	    (ipid==pid?"</b>":"")+
	    "</a>\n");
  return "";
}

string get_status(int pid)
{
  string wd = getcwd();
  string cwd, status, state = "unknown", name = "who knows";
  int vmsize, vmrss, vmdata, vmstack, vmexe, vmlib, vmstk, vmlck, ppid;
  array (string) uid, gid;
  cd("/proc/"+pid+"/cwd/"); 
  cwd = getcwd();
  cd(wd);
  status = Stdio.read_file("/proc/"+pid+"/status");
  if(!status || !strlen(status))
    return "<i>Failed to read /proc/. Process died?</i>";
  foreach(status / "\n", string line)
  {
    array tmp = line / ":";
    if(sizeof(tmp) != 2)
      continue;
    string unmod = tmp[1];
    tmp[1] -= " ";
    tmp[1] -= "\t";
    switch(lower_case(tmp[0]))
    {
     case "name":
      name = tmp[1];
      break;
      
     case "state":
      sscanf(tmp[1], "%*s(%s)", state);
      break;

     case "ppid":
      ppid = (int)tmp[1];
      break;
      
     case "vmrss":
      vmrss = (int)tmp[1];
      break;

     case "vmdata":
      vmdata = (int)tmp[1];
      break;
     
     case "vmstk":
      vmstk = (int)tmp[1];
      break;

     case "vmexe":
      vmexe = (int)tmp[1];
      break;

     case "vmlck":
      vmlck = (int)tmp[1];
      break;

     case "vmlib":
      vmlib = (int)tmp[1];
      break;

     case "vmsize":
      vmsize = (int)tmp[1];
      break;

     case "uid":
      uid = unmod / "\t" - ({""});
#if efun(getpwuid)
      for(int i = 0; i < sizeof(uid); i++)
	catch {
	  uid[i] = getpwuid((int)uid[i])[0];
	};
#endif
      break;

     case "gid":
      gid = unmod / "\t" - ({""});
#if efun(getgrgid)
      for(int i = 0; i < sizeof(gid); i++)
	catch {
	  gid[i] = getgrgid((int)gid[i])[0];
	};
#endif
      break;
      
    }
  }
  return sprintf("<b>Process name:</b>  %s\n"
		 "<b>Process state:</b> %s\n"
		 "<b>Parent pid:</b>    <a href="
		 "/Actions/?action=linuxproc.pike&pid=%d&unique=%d>%d</a>\n"
 		 "<b>CWD:</b>           %s\n\n"
	 	 "<b>Memory usage</b>:\n\n"
		 "  Virtual:      %6d kB"
		 "    RSS:          %6d kB\n"
		 "  Data:         %6d kB"
		 "    Stack:        %6d kB\n"
		 "  Locked:       %6d kB"
		 "    Executable:   %6d kB\n"
		 "  Libraries:    %6d kB\n\n"
		 "<b>User and group information:</b>\n\n"
		 "  <b>    %8s  %12s</b>\n"
		 "  <b>uid</b> %8s  %12s\n"
		 "  <b>gid</b> %8s  %12s  \n",
		 name, state,
		 ppid, time(), ppid, 
		 cwd, vmsize,
		 vmrss, vmdata, vmstk, vmlck,
		 vmexe, vmlib,
		 "real", "effective",
		 uid[0], uid[1], 
		 gid[0], gid[1]);
}

mixed page_0(object id, object mc)
{
  object p = ((program)"privs")("Process status");
  int pid = (int)id->variables->pid || roxen->roxenpid || roxen->startpid;
  
  string tree = Array.map(popen("/usr/bin/pstree -pa "+pid)/"\n",
			  format_proc_line, pid)*"";

  return ("<h2>Process Tree for "+pid+"</h2><pre>\n"+
	  tree+"</pre>"+
	  (roxen->euid_egid_lock ? 
	   "<p><i>Please note that when using threads on Linux, each "
	   "thread is more or less<br> a separate process, with the exception "
	   "that they share all their memory.</b>" : "")+
	  "<h3>Misc status for "+pid
	  +"</h3><pre>"+get_status(pid)+"</pre>");
}

mixed handle(object id) { return wizard_for(id,0); }



