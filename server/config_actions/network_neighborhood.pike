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
  sort(Array.map(sn, lambda(string s){ return neighborhood[s]->host; }), sn);
  return html_table(({"Config URL", "User", "Host", "Uptime", "Last Reboot","Version",
			/*({"Server info"})*/}),
		    Array.map(sn, lambda(string s) {
     mapping ns = neighborhood[s];
     return({(string)"<font size=+1><a href='"+s+"'>"+s+"</a></font>",
	     (string)getpwuid(ns->uid)[0],
	     (string)"<font size=+1>"+ns->host+"</font>",
	     (string)"<font size=+1>"+(ns->sequence/2)+"</font>",
	     (string)"<font size=+1>"+(ns->seq_reboots>1?"<font fg=red><blink>":"")+
	     (string)roxen->language("en","date")(ns->last_reboot)+
   	     (string)(ns->seq_reboots>1?"</blink></font>":"")+"</font>",
	     (string)"<font size=+1>"+(sv(ns->version))+"</font>",
	       /* ({  show_servers(ns->comment,ns->server_urls||"") })*/ });
    }));
}

mixed handle(object id)
{
  return wizard_for(id,0);
}
