/*
 * $Id: restart.pike,v 1.20 2004/05/31 23:01:45 _cvs_stephen Exp $
 */

#include <admin_interface.h>

constant task = "maintenance";
constant name = "Restart or shutdown...";
constant doc  = "";

mixed parse( RequestID id )
{
  string res = "<font size='+1'><b>Restart or shutdown</b></font><p />";
  switch( id->variables->what )
  {
  case "restart":
     if( config_perm( "Restart" ) )
     {
       core->restart(0.5);
       return res +
	 "<input type='hidden' name='task' value='restart.pike' />"
	 "<font color='&usr.warncolor;'><h1>Restart</h1></font>"
	 "ChiliMoon will restart automatically.\n\n<p><i>"
	 "You might see the old process for a while in the process table "
	 "when doing 'ps' or running 'top'. This is normal. ChiliMoon waits for a "
	 "while for all connections to finish, the process will go away after "
	 "at most 15 minutes.</i></p>";
     }
     return res + "Permission denied";

   case "shutdown":
     if( config_perm( "Shutdown" ) )
     {
       core->shutdown(0.5);
       return res +
	 "<font color='&usr.warncolor;'><h1>Shutdown</h1></font>"
	 "ChiliMoon will <b>not</b> restart automatically.\n\n<p><i>"
	 "You might see the old process for a while in the process table "
	 "when doing 'ps' or running 'top'. This is normal. ChiliMoon waits for a "
	 "while for all connections to finish, the process will go away after "
	 "at most 15 minutes.</i></p>";
     }
     return res + "Permission denied";

  default:
    return Roxen.http_string_answer(res +
#"<blockquote><br />

 <cf-perm perm='Restart'>
   <gbutton href='?what=restart&task=restart.pike&class=maintenance' 
            width=250 icon_src=&usr.err-2;> Restart </gbutton>
 </cf-perm>

<cf-perm not perm='Restart'>
  <gbutton dim width=250 icon_src=&usr.err-2;> Restart </gbutton>
</cf-perm>

<br /><br />

<cf-perm perm='Shutdown'>
  <gbutton href='?what=shutdown&task=restart.pike&class=maintenance' 
           width=250  icon_src=&usr.err-3;> Shutdown </gbutton>
</cf-perm>

<cf-perm not perm='Shutdown'>
  <gbutton dim width=250 icon_src=&usr.err-3;> Shutdown </gbutton>
</cf-perm>

</blockquote>

<br />

<p><cf-cancel href='?class=&form.class;'/></p>" );
     }
}
