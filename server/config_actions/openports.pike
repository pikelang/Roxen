#ifndef __NT__
/*
 * $Id: openports.pike,v 1.10 1998/04/29 03:57:55 grubba Exp $
 */

inherit "wizard";
constant name = "Maintenance//Show all open ports...";

constant doc = ("Show all open ports on "+gethostname()+".");

mixed page_1(object id)
{
  array(string) path = (getenv("PATH")||"/sbin:/bin:/usr/sbin:/usr/bin")/":";

  array(string) lsofs =
    Array.filter(Array.uniq(Array.map(path, combine_path, "lsof")),
		 lambda(string f) {
		   array st;
		   return ((st = file_stat(f)) &&
			   (st[0] & 0111));
		 });
  if (!sizeof(lsofs)) {
    return("You will need to install <a href=\""
	   "ftp://vic.cc.purdue.edu/pub/tools/unix/lsof/lsof.tar.gz\">"
	   "'lsof'</a> for full info.\n");
  }
  return(sprintf("Use this lsof binary:\n"
		 "<var type=select name=lsof default='%s'\n"
		 "choices='%s'><p>\n", id->variables->lsof || lsofs[0],
		 lsofs * ","));
}

mixed page_2(object id)
{
  string res = "<h1>All open ports on this computer</h1><br>\n";
  mapping ports_by_ip = ([ ]);
  string s;

  if (id->variables->lsof) {
    s = sprintf("%s -i -P -n -b -F cLpPnf", id->variables->lsof);
  }

  if(!s || !(s=popen(s)) || !strlen(s))
  {
    s = popen("netstat -n -a");
    if(!s || !strlen(s)) {
      return "I cannot understand the output of netstat -a\n";
    }
    foreach(s/"\n", s)
    {
      string ip,tmp;
      int port;
      if(search(s, "LISTEN")!=-1)
      {
	s=((replace(s,"\t"," ")/" "-({""})))[0];
	sscanf(reverse(s), "%[^.].%s", tmp, ip);
	ip=reverse(ip);
	port=(int)reverse(tmp);
	if(ip=="*") ip="ANY";
	if(!ports_by_ip[ip])
	  ports_by_ip[ip]=({({ port, 0, "Install <a href=\""
			       "ftp://vic.cc.purdue.edu/pub/tools/unix/lsof/"
			       "lsof.tar.gz\">'lsof'</a>","for this info"})});
	else
	  ports_by_ip[ip]+=({({ port, 0, "Install <a href=\""
				"ftp://vic.cc.purdue.edu/pub/tools/unix/lsof/"
				"lsof.tar.gz\">'lsof'</a>","for this info"})});
      }
    }
  } else {
    int pid, port, last, ok;
    string cmd, ip;
    string user;
    mapping used = ([]);
    foreach(s/"\n", s)
    {
      if(!strlen(s)) continue;
      switch(s[0])
      {
       case 'P':
	if(s[1..]=="TCP") ok=1; else ok=0;
	break;
       case 'p': pid = (int)s[1..];break;
       case 'c': cmd = s[1..];break;
       case 'L': user = s[1..]; break;
       case 'n':
	last=0;
	s=s[1..];
	if(ok && search(s,"->")==-1)
	{
//	  write(s+"\n");
	  sscanf(s, "%s:%d", ip, port);
	  if(ip=="*") ip="ANY";
	  if(!used[ip] || !used[ip][port])
	  {
	    if(!used[ip]) used[ip]=(<>);
	    used[ip][port]=1;
	    last=1;
	    if(!ports_by_ip[ip])
	      ports_by_ip[ip]=({({port,pid,cmd,user})});
	    else
	      ports_by_ip[ip]+=({({port,pid,cmd,user})});
	  }
	}
      }
    }
  }


  foreach(sort(indices(ports_by_ip)), string ip)
  {
    string su;
    string oip = ip;
    if(ip != "ANY") ip = su = roxen->blocking_ip_to_host(ip);
    else { su = gethostname(); ip="All interfaces"; }
    res += "<h2>"+ip+"</h2>";

    array a = ports_by_ip[oip], tbl=({});
    sort(column(a,0),a);
    int i;
    foreach(a, array port)
    {
      if(port[1]==getpid())
	tbl += ({({"<b>"+port[0]+"</b>","<b>"+port[2]+"</b>",
		   "<b>"+port[3]+"</b>","<b>"+port[1]+"</b>"})});
      else
	tbl += ({({port[0],port[2],port[3],port[1]})});
    }
    res+=html_table(({"Port", "Program", "User", "PID"}),tbl);
  }
  return res;
}

string cleanup_ip(string ip)
{
  if(ip == "0.0.0.0") {
    ip = "any";
  } else if (ip == "127.0.0.1") {
    ip = "localhost";
  } else {
    ip = lower_case(ip);
  }
  return(ip);
}

mixed page_0(object id)
{
  string res = "<h1>All open ports in this Roxen</h1>\n";
  mapping ports_by_ip = ([ ]);

  mapping used = ([]);
  foreach(roxen->configurations, object c)
  {
    mapping p = c->open_ports;
    foreach(indices(p), object port)
    {
      // num, protocol, ip
      // Why is port 0 sometimes? *bogglefluff* / David
      if(port) {
	string ip = cleanup_ip(p[port][2]);
	if (!used[ip] || !used[ip][p[port][0]]) {
	  if(!used[ip]) {
	    used[ip] = (< p[port][0] >);
	  } else {
	    used[ip][p[port][0]] = 1;
	  }
	  if(!ports_by_ip[ip]) {
	    ports_by_ip[ip]=({({p[port][0],p[port][1],c})});
	  } else {
	    ports_by_ip[ip]+=({({p[port][0],p[port][1],c})});
	  }
	}
      }
    }
  }

  // Fool the compiler... (backward compatibility).
  function fun = roxen->get_configuration_ports;

  foreach(((fun && fun()) || roxen->configuration_ports), object o)
  {
    string port, ip;
    sscanf(o->query_address(1), "%s %s", ip, port);

    ip = cleanup_ip(ip);

    if(!ports_by_ip[ip])
      ports_by_ip[ip]=({({(int)port,"http",0})});
    else
      ports_by_ip[ip]+=({({(int)port,"http",0})});
  }

  foreach(Array.sort_array(indices(ports_by_ip), lambda(string a, string b) {
    if(a == "any")
      return -1;
    return a > b;
  }), string ip)
  {
    string su;
    string oip = ip;
    if(ip == "any") {
      su = gethostname();
      ip="All interfaces (bound to ANY)";
    } else {
      ip = su = roxen->blocking_ip_to_host(ip);
    }
    array a,tbl=({});
    a = ports_by_ip[oip];
    sort(column(a,0), a);
    foreach(a, array port)
    {
      string url, url2;
      if(port[1] == "tetris")
	url = "telnet://" + su + ":"+port[0]+"/";
      else
	url = (port[1][0]=='s'?"https":port[1]) + "://" + su + ":"+port[0]+"/";
      
      url2 = (port[1][0]=='s'?"https":port[1]) + "://" + su + ":"+port[0]+"/";

      tbl += ({({port[0],port[1],"<a href=\""+
	         (port[2]?"/Configurations/"+http_encode_string(port[2]->name)
	           +"?"+time():"/Globals/?"+time())+"\">"+
		   (port[2]?port[2]->name:"Configuration interface")+"</a>",
	         "<a href=\""+url+"\">"+ url2+"</a>" })});
    }
    res += "<font size=+1>"+ip+"</font><br>"+
      html_table(({ "Port number", "Protocol", "Server", "URL" }),tbl);

  }
  return res;
}

mixed wizard_done(){}

mixed handle(object id, object mc)
{
  return wizard_for(id,0);
}
#else
constant action_disabled = 1;
#endif
