/*
 * $Id: openports.pike,v 1.5 1997/08/20 14:23:52 per Exp $
 */

inherit "roxenlib";
constant name = "Status//Show all open ports...";

constant doc = ("Show all open ports on any, or all, interfaces.");

mixed all_ports(object id)
{
  string res = "<h1>All open ports on this computer</h1><br>\n";
  mapping ports_by_ip = ([ ]);
  string s;

  if(!(s=popen("lsof -i -P -n -b -F cLpPnf")) || !strlen(s))
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

    res += "<table cellpadding=3 cellspacing=0 border=0>\n"
      "<tr bgcolor=lightblue><td><b>Port number</b></td>\n"
      "<td><b>Program</b></td><td><b>User</b></td><td><b>PID</b></td></tr>\n";
    array a = ports_by_ip[oip];
    sort(column(a,0),a);
    int i;
    foreach(a, array port)
    {
      string bg=((i++/3)%2)?"white":"#e0e0ff";

      if(port[1]!=getpid())
	res += sprintf("<tr bgcolor=\"%s\"><td align=right>%d</td>\n"
		       "<td>%s</td><td>%s</td><td>%d</td></tr>\n",
		       bg, port[0],port[2],port[3],port[1]);
      else
	res += sprintf("<tr bgcolor=\"%s\"><td align=right><b>%d</b></td>\n"
		       "<td><b>%s</b></td><td><b>%s</b></td>\n"
		       "<td><b>%d</b></td></tr>",
		       bg, port[0],port[2],port[3],port[1]);
    }
    res+="</table>";
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

mixed roxen_ports(object id)
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

  foreach(roxen->configuration_ports, object o)
  {
    string port, ip;
    sscanf(o->query_address(1), "%s %s", ip, port);

    ip = cleanup_ip(ip);

    if(!ports_by_ip[ip])
      ports_by_ip[ip]=({({(int)port,"http",0})});
    else
      ports_by_ip[ip]+=({({(int)port,"http",0})});
  }

  res += "<table cellspacing=4>";
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
    res += ("<tr><th align=left colspan=4><br><font size=+1><b>"+ip+
	    "</b></font><br></th></tr><tr bgcolor=lightblue>"
	    "<td><b>Port number</b></td><td><b>Protocol</b></td>"
	    "<td><b>Server</b></td><td><b>URL</b></td></tr>\n");
    array a;
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

      res += sprintf("<tr><td align=right>%d</td><td>%s</td>\n"
		     "<td><a href=\"%s\">%s</a></td>\n"
		     "<td><a target=remote href=\"%s\">%s</a></td></tr>",
		     port[0],port[1],
		     port[2]?"/Configurations/"+
		     http_encode_string(port[2]->name)+"?"+time():"/Globals/",
		     port[2]?port[2]->name:"Configuration interface",
		     url, url2);
    }
  }
  res += "</table>";
  return res;
}

mixed first_form(object id)
{
  return ("<table bgcolor=black cellpadding=1><tr><td>\n"
	  "<table cellpadding=10 cellspacing=0 border=0 bgcolor=#eeeeff>\n"
	  "<tr><td align=center valign=center colspan=2>"
	  "<h1>What information do you want?</h1>\n"
	  "<form>\n"
	  "<font size=+1>Please select one of the pages below</font><br>\n"
	  "</tr><tr><td colspan=2>"
	  "<input type=hidden name=action value="+id->variables->action+">\n"
	  "<input type=radio name=page checked value=roxen_ports> "
	  "Show all ports allocated by Roxen<br>\n"
	  "<input type=radio name=page value=all_ports> Show all ports<br>\n"
	  "</tr><tr><td>"
	  "<input type=submit name=ok value=\" Ok \"></form>"
	  "</td>\n<td align=right>"
	  "<form>"
	  "<input type=submit name=cancel value=\" Cancel \"></form>"
	  "</td></tr></table></table>");
}

mixed handle(object id, object mc)
{
  function fun;
  if((fun=this_object()[id->variables->page||""])&&fun!=handle&&functionp(fun))
    return fun(id,mc);
  return first_form(id);
}
