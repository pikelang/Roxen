/*
 * $Id: proc.pike,v 1.8 1998/08/05 18:51:54 grubba Exp $
 */

inherit "wizard";

constant name= "Status//Extended process status";
constant doc = "Shows detailed process status on Solaris 2.5 and 2.6.";

constant more=1;

void create()
{
  if(!file_stat("/usr/proc/bin/")) {
    throw("Only available under Solaris 2.5 and newer\n");
  }
}

string proc(string prog, int pid )
{
  if(!pid) pid=getpid();
  object p = ((program)"privs")("Process status");
  return popen("/usr/proc/bin/p"+prog+" "+pid);
}

string process_map(string in)
{
  string q="<table>";
  mapping map = ([]);
  foreach((in/"\n")[1..], string m)
  {
    string a,b;
    while(sscanf(m, "%s: %s", a,b)==2) m=a+":"+b;
    m=replace(m,"[ heap ]","Heap&nbsp(malloced&nbsp;memory)");
    m=replace(m,"[ stack ]","Stack");
    array row = (replace(m,"\t"," ")/" "-({""}))[1..];
    row=replace(row, "read/exec", "read/exec/shared");
    row=replace(row, "read/shared", "read/exec/shared");
    row=replace(row, "read/exec/shared", "Shared");
    row=replace(row, "read/write/shared", "Shared");
    row=replace(row, "read/write/exec/shared", "Shared");
    row=replace(row, "read/write", "Private");
    row=replace(row, "read/write/exec", "Private");

    if(sizeof(row)>1)
      map[row[1]] += (int)row[0];
  }
  foreach(sort(indices(map)), string s)
    if(map[s]>1024)
      q += "<tr><td>"+s+"</td><td>"+sprintf("%.1f%s",map[s]/1024.0,"Mb")+"</td>";
    else
      q += "<tr><td>"+s+"</td><td>"+sprintf("%d%s",map[s],"Kb")+"</td>";
  return q+"</table>";
}

string process_map2(string in)
{
  string kbytes,resident,shared,priv;
  if(sscanf(((in/"\n")[-2]/" "-({""}))[2..]*" ",
            "%[^ ] %[^ ] %[^ ] %[^ ]",kbytes,resident,shared,priv)==4)
    return sprintf("%d Kbytes, %d Kb shared, %d Kb private, %d Kb resident",
		   (int)kbytes,(int)shared,(int)priv,(int)resident);
  return "Failed to parse output from pmap.";
}

string format_proc_line(string in, int ipid)
{
  string pre;
  int pid;
  sscanf(in, "%*s%d%*s", pid);
  sscanf(in,"%[ ]%s",pre,in);
  pre=replace(pre,"  "," |");
  if(strlen(pre))pre=" "+pre[1..];
  if(search(in,"/proc/")==-1)
    return (pre+
	    "<a href=/Actions/?action=proc.pike&pid="+pid+"&unique="+time()+">"+
	    (ipid==pid?"<b>":"")+
	    html_encode_string(in)+
	    (ipid==pid?"</b>":"")+
	    "</a>\n");
  return "";
}

#if !constant(getpwuid)
array(string) getpwuid(int uid) { return ({ (string)uid }); }
#endif

string cred(object id)
{
  string r = "", s;
  int uid, gid;
  if(sscanf(proc("cred",id->variables->pid), "%*d:\te/r/suid=%d  "
	    "e/r/sgid=%d\n\tgroups:%s\n", uid, gid, s) != 4)
    return "-<br>";
  array groups = ((s||"")/" ") - ({ "" });
#if constant(getgrgid)
  for(int i = 0; i < sizeof(groups); i++)
    groups[i] = (getgrgid((int)groups[i]) || ({ (string)groups[i] }))[0];
  return sprintf("e/r/suid: %s<br>e/r/sgid: %s<br>groups: %O\n",
		 (getpwuid(uid) || ({ (string)uid }))[0],
		 (getgrgid(gid) || ({ (string)gid }))[0],
		 String.implode_nicely(groups));
#else
  return sprintf("e/r/suid: %s<br>e/r/sgid: %d<br>groups: %O\n",
		 (getpwuid(uid) || ({ (string)uid }))[0],
		 gid,
		 String.implode_nicely(groups));
#endif /* constant(getgrgid) */
}

mixed page_0(object id, object mc)
{
  string map = proc("map -x",(int)id->variables->pid);
  if(sscanf(map, "%*sShared%*s") != 2)
    map = process_map(proc("map",(int)id->variables->pid));
  else
    map = process_map2(map);
  
  string tree = Array.map(proc("tree -a",(int)id->variables->pid)/"\n",format_proc_line,
			  (int)id->variables->pid||getpid())*"";

  return ("<font size=+1>Process Tree for "+(id->variables->pid||getpid())+"</font><pre>\n"+
	  tree+
	  "</pre><font size=+1>Misc status for "+(id->variables->pid||getpid())
	  +"</font><pre>Memory Usage: "+map+"\n\nCredentials:<br>"+cred(id)+
	  "\nCurrent working directory: "+
	  ((proc("wdx",id->variables->pid)/":")[1..]*":")+
//	  "Stack: "+(proc("stack",id->variables->pid)/":")[1..]*":"+
	  "</pre>");
}

mixed handle(object id) { return wizard_for(id,0); }

