/*
 * $Id: shutdown.pike,v 1.10 1997/08/31 21:52:00 per Exp $
 */

inherit "wizard";
constant name= "Shutdown//Shut down Roxen...";

constant doc = ("Restart or shut down Roxen.");

string page_0(object id)
{
  return ("<font size=+1>How do you want to shut down Roxen?</font><br>"
	  "<input type=hidden name=action value="+id->variables->action+">"
	  "<input type=radio name=how checked value=reset> Restart Roxen<br>"
	  "<input type=radio name=how value=shutdown> Shut down Roxen (no automatic restart)");

}

mapping wiz_done(object id)
{
  if(id->variables->how == "shutdown")
    return http_redirect(roxen->config_url()+"(shutdown)/Actions/");
  return http_redirect(roxen->config_url()+"(restart)/Actions/");
}

mixed handle(object id) { return wizard_for(id,0); }
