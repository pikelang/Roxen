/*
 * $Id: linuxproc.pike,v 1.1 1997/10/11 02:51:28 neotron Exp $
 */

inherit "wizard";

constant name= "Status//Extended pstree status";
constant doc = "Shows detailed process status on Solaris 2.5 and 2.6.";

constant more=1;

void create()
{
  if(!file_stat("/usr/bin/pstree")) {
    throw("You need /usr/bin/pstree to be installed\n");
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


mixed page_0(object id, object mc)
{
  object p = ((program)"privs")("Process status");
  int pid = (int)id->variables->pid || roxen->roxenpid || roxen->startpid;
  
  string tree = Array.map(popen("/usr/bin/pstree -pa "+pid)/"\n",
			  format_proc_line, pid)*"";

  return ("<font size=+1>Process Tree for "+(id->variables->pid||getpid())+"</font><pre>\n"+
	  tree+
#if 0
	  "</pre><font size=+1>Misc status for "+(id->variables->pid||getpid())
	  +"</font><pre>Memory Usage: "+map+"\n\nCredentials:<br>"+cred(id)+
	  "\nCurrent working directory: "+
	  ((proc("wdx",id->variables->pid)/":")[1..]*":")+
//	  "Stack: "+(proc("stack",id->variables->pid)/":")[1..]*":"+
#endif
	  "</pre>");
}

mixed handle(object id) { return wizard_for(id,0); }
