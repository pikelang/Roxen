inherit "wizard";

string name = "Neighborhood//Roxen Neighborhood...";
string doc = "";

string sv(string in)
{
  if(!in) return "?";
  sscanf(in, "%*s/%s", in);
  in = replace(in, "alpha", "a");
  in = replace(in, "beta", "ß");
  return in;
}

string show_servers(string c,array s)
{
  array res =({});
  if(strlen(c)) c+="<br>";
  foreach(s, mixed v)
  {
    if(arrayp(v))
      res += ({"<a href="+v[1]+">"+v[0]+"</a>"});
    else
      res += ({"<a href="+v+">"+v+"</a>"});
  }
  return c+String.implode_nicely(res)+"<p>";
}

string time_interval(int s)
{
  string r = "";

  int d = s/3600/24;
  int y = d/365;
  int h = (s/3600)%24;
  d %= 365;

  if(y) r += sprintf("%dy ", y);
  if(d||y) r += sprintf("%dd ", d);
  if(d||h) r += sprintf("%dh ", h);
  return r + ((s>7200)?"":sprintf("%2d min", (s%3600)/60));
}

string page_0()
{
  array sn = indices(neighborhood);
  sort(Array.map(sn, lambda(string s){ return neighborhood[s]->host+":"+getpwuid(neighborhood[s]->uid)[0]+":"+neighborhood[s]->config_url; }), sn);
  return html_table(({"Config URL", "User", "Host", "Uptime", "Last Reboot","Version",
			/*({"Server info"})*/}),
		    Array.map(sn, lambda(string s) {
     mapping ns = neighborhood[s];
     int re=ns->seq_reboots;
     string ER="",RE="";
     if(re>1)
     {
       RE="<font color=red><b><blink>";
       ER="</blink></b></font>";
     }
#if 0
     else if(re || (time()-ns->last_reboot<120)) {
       RE="<font color=orange><b>";
       ER="</b></font>";
     } else if(ns->time && (time()-ns->time)>300) {
       RE="<font color=#bbbbbb><b>";
       ER="</b></font>";
     } if(ns->time && (time()-ns->time)>600) {
       RE="<font color=#bbbbbb><i>";
       ER="</i></font>";
     }
#endif
     return({  "<a href='"+s+"'>"+s+"</a></font>",
	       RE+getpwuid(ns->uid)[0]+ER,
	       RE+ns->host+ER,
	       RE+time_interval(time()-ns->last_reboot)+ER,
	       RE+roxen->language("en","date")(ns->last_reboot)+ER,
	       RE+sv(ns->version)+ER
     });
    }));
}

mixed handle(object id)
{
  return wizard_for(id,0);
}
