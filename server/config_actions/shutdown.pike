/*
 * $Id: shutdown.pike,v 1.11 1997/09/03 01:23:32 peter Exp $
 */

inherit "wizard";
constant name= "Shutdown//Shut down Roxen...";
constant doc = ("Restart or shut down Roxen.");

string page_0(object id)
{
  return ("<font size=+1>How do you want to shut down Roxen?</font><p>"
	  "<var type=radio name=how checked value=reset> Restart Roxen<br>"
	  "<var type=radio name=how value=shutdown> Shut down Roxen "
	  "(no automatic restart)");
}

mapping wizard_done(object id)
{
  if(id->variables->how == "shutdown")
    return http_redirect(roxen->config_url()+"(shutdown)/Actions/");
  return http_redirect(roxen->config_url()+"(restart)/Actions/");
}

mixed handle(object id) { return wizard_for(id,0); }
