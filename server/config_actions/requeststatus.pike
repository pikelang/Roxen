/*
 * $Id: requeststatus.pike,v 1.5 1998/07/20 20:51:16 neotron Exp $
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
  string res="<b>These are all virtual servers. They are sorted by the "
    "number of requests they have received - the most active being first.";
  foreach(Array.sort_array(roxen->configurations,
			   lambda(object a, object b) {
			     return a->requests < b->requests;
			     }), object o)
    res += sprintf("<h3><a href=%s>%s</a><br>%s</h3>\n",
		   o->query("MyWorldLocation"),
		   o->name,
		   replace(o->status(), "<table>", "<table cellpadding=4>"));
  return res;
}

mixed handle(object id) { return wizard_for(id,0); }

