/*
 * $Id: requeststatus.pike,v 1.4 1998/07/20 20:38:13 neotron Exp $
 */

inherit "wizard";
constant name= "Status//Access / request status";

constant doc = ("Shows the amount of data handled since last restart.");

constant more=0;

mixed page_0(object id, object mc)
{
  return sprintf("<h2>Server Overview</h2>"
		 "This is the summary status of all virtual servers. "
		 "Click <b>[Next->]</b> to see the statistics for each "
		 "indiviual server, or <b>[Cancel]</b> to return to the "
		 "previous menu.<p>%s", 
		 roxen->full_status());
}

mixed page_1(object id)
{
  string res="";
  foreach(Array.sort_array(roxen->configurations,
			   lambda(object a, object b) {
			     return lower_case(a->name) > lower_case(b->name);
			     }), object o)
    res += sprintf("<h2>%s<br>%s</h2>\n", o->name,
		   replace(o->status(), "<table>", "<table cellpadding=4>"));
  return res;
}

mixed handle(object id) { return wizard_for(id,0); }

