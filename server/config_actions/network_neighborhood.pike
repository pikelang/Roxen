inherit "wizard";

string name = "Neighborhood//Roxen Neighborhood...";
string doc = "";

string page_0()
{
  return html_table(({"Config URL", "Host", "Sequence", "Last Reboot",
			({"Server info"})}),
		    Array.map(indices(neighborhood), lambda(string s) {
     mapping ns = neighborhood[s];
     return({(string)s,
	     (string)ns->host,
	     (string)ns->sequence,
	     (string)(ns->seq_reboots>1?"<font fg=red><blink>":"")+
	     (string)roxen->language("en","date")(ns->last_reboot)+
   	     (string)(ns->seq_reboots>1?"</blink></font>":""),
	       ({ns->comment||"No comments"})});
    }));
}

mixed handle(object id)
{
  return wizard_for(id,0);
}
