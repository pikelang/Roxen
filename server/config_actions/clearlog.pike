/*
 * $Id: clearlog.pike,v 1.6 1997/08/30 22:57:56 peter Exp $
 */

inherit "wizard";
constant name= "Maintenance//Clear Event Log...";
constant wizard_name= "Clear Event Log";

constant doc = ("Clear all or specified (on type) events from the Event Log.");

mixed page_0(object id)
{
  return ("<font size=+2>Select type(s) of messages to delete:</font><p>"
	  "<table><tr><td>"
	  "<var name=types type=select_multiple default='' choices='"
	  "Informational messages,Warning messages,Error messages'></td><td>"+
	  html_notice("Example Informational Message", id)+
	  html_warning("Example Warning Message", id)+
	  html_error("Example Error Message", id)+
	  "</td></tr></table>");
}

mixed wizard_done(object id)
{
  array types=Array.map(id->variables->types/"\0",
			lambda(string s){return (s[0]=='I'?1:s[0]=='W'?2:3);});
  foreach(indices(roxen->error_log), string err)
  {
    int type;
    sscanf(err, "%d,%*s", type);
    if(search(types,type) != -1) m_delete(roxen->error_log, err);
  }
  roxen->last_error = "";
  report_notice("Event log cleared by admin from "+
		roxen->blocking_ip_to_host(id->remoteaddr)+".");

  return http_redirect(roxen->config_url()+"Errors/?"+time());
}

string handle(object id)
{
  return wizard_for(id,0);
}

