/*
 * $Id: shutdown.pike,v 1.7 1997/08/20 14:23:55 per Exp $
 */

inherit "roxenlib";
constant name= "Maintenance//Shut down Roxen...";

constant doc = ("Restart or shut down Roxen.");

mixed handle(object id, object mc)
{
  if(id->variables->cancel)
    return http_redirect(roxen->config_url()+"Actions/");

  if(!id->variables->ok)
  {
    return ("<table bgcolor=black cellpadding=1><tr><td>"
	    "<table cellpadding=10 cellspacing=0 border=0 bgcolor=#eeeeff>"
	    "<tr><td align=center valign=center colspan=2>"
	    "<h1>Shut down Roxen</h1>"
	    "<form>\n"
	    "<font size=+1>How do you want to shut down Roxen?</font><br>"
	    "</tr><tr><td  colspan=2>"
	    "<input type=hidden name=action value="+id->variables->action+">"
	    "<input type=radio name=how value=not> Not at all<br>"
	    "<input type=radio name=how checked value=reset> Restart Roxen<br>"
	    "<input type=radio name=how value=shutdown> Shut down Roxen (no automatic restart)<br>"
	    "</tr><tr><td>"
	    "<input type=submit name=ok value=\" Ok \"></form>"
	    "</td><td align=right>"
	    "<form>"
	    "<input type=hidden name=action value="+id->variables->action+">"
	    "<input type=submit name=cancel value=\" Cancel \"></form>"
	    "</td></tr></table></table>");
  }

  if(id->variables->how == "shutdown")
    return http_redirect(roxen->config_url()+"(shutdown)/Actions/");
  if(id->variables->how == "reset")
    return http_redirect(roxen->config_url()+"(restart)/Actions/");
  return http_redirect(roxen->config_url()+"Actions/?"+time());
}
