/*
 * $Id: requeststatus.pike,v 1.3 2000/07/17 16:12:41 lange Exp $
 */

inherit "wizard";
constant action="status";
constant name= "Access / request status";
constant doc = ("Shows the amount of data handled since last restart.");


mixed parse(object id)
{
  return "<h2>Server Overview</h2>"+
         roxen->full_status()+
         "<p>"
         +page_1( id );
}

mixed page_1(object id)
{
  string res="";
  foreach(Array.sort_array(roxen->configurations,
			   lambda(object a, object b) {
			     return a->requests < b->requests;
			   }), object o)
  {
    if(!o->requests)
      continue;
    res += sprintf("<h3>%s<br />%s</h3>\n",o->query_name(),o->status() );
  }
  if(!strlen(res))
    return "<b>There are no active virtual servers.</b>";
  return
    "<b>These are all active virtual servers. They are sorted by the "
    "number of requests they have received - the most active being first. "
    "Servers which haven't recieved any requests are not listed.</b>" +
    res+"<p><cf-ok>";
}
