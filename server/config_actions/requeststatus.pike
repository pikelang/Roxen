/*
 * $Id: requeststatus.pike,v 1.8 1998/10/10 03:41:08 per Exp $
 */

inherit "wizard";
constant name= "Status//Access / request status";

constant doc = ("Shows the amount of data handled since last restart.");

constant more=0;

constant ok_label = " Refresh ";
constant cancel_label = " Done ";

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
			     return a->requests < b->requests;
			   }), object o) {
    if(!o->requests)
      continue;
    res += sprintf("<h3><a href=%s>%s</a><br>%s</h3>\n",
		   o->query("MyWorldLocation"),
		   o->name,
		   replace(o->status(), "<table>", "<table cellpadding=4>"));
  }
  if(!strlen(res))
    return "<b>There are no active virtual servers.</b>";
  return
    "<b>These are all active virtual servers. They are sorted by the "
    "number of requests they have received - the most active being first. "
    "Servers which haven't recevied any requests are not listed.</b>" +
    res;
}

int verify_1(object id)
{
  return 1;
}

mixed handle(object id) { return wizard_for(id,0); }

