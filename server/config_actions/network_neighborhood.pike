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

string page_0()
{
  array sn = indices(neighborhood);
  sort(Array.map(sn, lambda(string s){ return neighborhood[s]->host+":"+neighborhood[s]->uid+neighborhood[s]->config_url; }), sn);
  return html_table(({"Config URL", "User", "Host", "Uptime", "Last Reboot","Version",
			/*({"Server info"})*/}),
		    Array.map(sn, lambda(string s) {
     mapping ns = neighborhood[s];
     int re=ns->seq_reboots>1;
     string ER="",RE="";
     if(re)
     {
       RE="<font color=red><b><blink>";
       ER="</blink></b></font>";
     }
     return({  "<a href='"+s+"'>"+s+"</a></font>",
	       RE+getpwuid(ns->uid)[0]+ER,
	       RE+ns->host+ER,
	       RE+(string)(ns->sequence/2)+ER,
	       RE+roxen->language("en","date")(ns->last_reboot)+ER,
	       RE+sv(ns->version)+ER
     });
    }));
}

mixed handle(object id)
{
  return wizard_for(id,0);
}
