inherit "roxenlib";
constant name= "Shut Roxen down";

constant doc = ("Roxen will <font size=+1 color=darkred><b>not</b></font> restart automatically if you select this action.");

mixed handle(object id, object mc)
{
  if(!id->variables->ok)
  {
    return ("<table bgcolor=black cellpadding=1><tr><td><table cellpadding=10 cellspacing=0 border=0 bgcolor=#f0f0ff><tr><td align=center valign=center colspan=2><h1>Shut down Roxen</h1>"
	    "<font size=+1>Are you really sure you want to shut down "
	    "Roxen?</font><br>"
	    "</tr><tr><td>"
	    "<form>\n"
	    "<input type=submit name=nope value=\" No \"></form>"
	    "</td><td align=right>"
	    "<form>\n"
	    "<input type=hidden name=action value="+id->variables->action+">"
	    "<input type=submit name=ok value=\" Yes \"></form>"
	    "</td></tr></table></table>");
  } else
    return http_redirect(roxen->config_url()+"(shutdown)/Actions/");
}
