/*
 * $Id$
 */

#include <config_interface.h>
#include <roxen.h>

//<locale-token project="admin_tasks"> LOCALE </locale-token>
#define LOCALE(X,Y)  _DEF_LOCALE("admin_tasks",X,Y)

constant action = "maintenance";

LocaleString name= LOCALE(34, "Restart or shutdown")+"...";
constant doc = "";


mixed parse( RequestID id )
{
  string pid = (string) getpid();

  string res = "<cf-title>" +
    LOCALE(34, "Restart or shutdown") + "</cf-title>";

  //  Verify pid for possibly repeated request (browser restart etc)
  string what = id->variables->what;
  string ignore_msg = "";
  if (string form_pid = id->variables->pid)
    if (form_pid != pid) {
      ignore_msg =
	"<div class='notify warn'>" +
	LOCALE(406, "Repeated action request ignored &ndash; "
	       "server process ID is different.") +
	"</div>";
      what = 0;
    }

  switch (what) {
  case "restart":
     if( config_perm( "Restart" ) )
     {
       roxen->restart(0.5, UNDEFINED, -1);
       return res +
"<input type=hidden name=action value=restart.pike>"
"<h3>"+LOCALE(197,"Restart")+"</h3><p class='notify info inline'>"+
 LOCALE(233, "Roxen will restart automatically.")+
"</p>\n\n<p><i>"+
LOCALE(234, "You might see the old process for a while in the process table "
       "when doing 'ps' or running 'top'. This is normal. Roxen waits for a "
       "while for all connections to finish, the process will go away after "
       "at most 15 minutes.")+ "</i></p>";
     }
     return res + LOCALE(226,"Permission denied");

   case "shutdown":
     if( config_perm( "Shutdown" ) )
     {
       roxen->shutdown(0.5, -1);
       return res +
"<h3>"+LOCALE(198,"Shutdown")+"</h3><p class='notify inline warn'>"+
LOCALE(235,"Roxen will <b>not</b> restart automatically.")+
"</p>\n\n<p><i>"+
LOCALE(234, "You might see the old process for a while in the process table "
       "when doing 'ps' or running 'top'. This is normal. Roxen waits for a "
       "while for all connections to finish, the process will go away after "
       "at most 15 minutes.")+ "</i></p>";
     }
     return res + LOCALE(226,"Permission denied");

  default:
    return Roxen.http_string_answer(res +
#"<hr class='section'>
<blockquote>

 <cf-perm perm='Restart'>
   <link-gbutton href='?what=restart&amp;action=restart.pike&amp;class=maintenance&amp;pid=" +
        pid + #"&amp;&usr.set-wiz-id;' type='reload fixed-width'>"+
       LOCALE(197,"Restart")+#"</link-gbutton>
 </cf-perm>

<cf-perm not perm='Restart'>
  <disabled-gbutton type='reload fixed-width'>" +
        LOCALE(197,"Restart") +
 #"</disabled-gbutton>
</cf-perm>

<p></p>

<cf-perm perm='Shutdown'>
  <link-gbutton href='?what=shutdown&amp;action=restart.pike&amp;class=maintenance&amp;pid=" +
        pid + #"&amp;&usr.set-wiz-id;' type='error fixed-width'>"+
       LOCALE(198,"Shutdown")+#"</link-gbutton>
</cf-perm>

<cf-perm not perm='Shutdown'>
  <disabled-gbutton type='error fixed-width'>" +
       LOCALE(198,"Shutdown")+#" </disabled-gbutton>
</cf-perm>" + ignore_msg + #"

</blockquote>

<hr class='section'>

<p><cf-cancel href='?class=&form.class;&amp;&usr.set-wiz-id;'/></p>" );
     }
}
