/*
 * $Id: clearlog.pike,v 1.3 1997/08/13 22:27:25 grubba Exp $
 */

inherit "roxenlib";
constant name= "Clear Event Log...";

constant doc = ("Clear all or specified (on type) events from the Event Log.");

mixed handle(object id, object mc)
{
  mapping v = id->variables;
  if(!v->types) {
    return sprintf("<h1>Select type of messages to delete:</h1><form>"
		   "<input type=hidden name=action value=\""+v->action+"\">"
		   "<select name=types multiple>"
		   "<option value=1>Informational messages"
		   "<option value=2>Warning messages"
		   "<option value=3>Error messages</select>"
		   "<br><input type=submit value=\"Remove selected events\">"
		   "</form");
  } else {
//    perror("%O\n", roxen->error_log);
    array types = v->types / "\0";
    int type;
    /*  if(sizeof(types) == 3)
      roxen->error_log = ([]);
    else */foreach(indices(roxen->error_log), string err)
    {
      sscanf(err, "%d,%*s", type);
      if(search(types, (string)type) != -1)
	m_delete(roxen->error_log, err);
    }
//    perror("%O\n", roxen->error_log);
    roxen->last_error = "";
    report_notice("Event log cleared by admin from "+
		  roxen->blocking_ip_to_host(id->remoteaddr)+".");
    return http_redirect(roxen->config_url()+"Errors/?"+time());
  }
}
