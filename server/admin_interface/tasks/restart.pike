/*
 * $Id: restart.pike,v 1.16 2002/11/07 12:47:01 agehall Exp $
 */

#include <admin_interface.h>

constant task = "maintenance";
constant name = "Restart or shutdown";
constant doc  = "";

mixed parse( RequestID id )
{
  switch( id->variables->what )
  {
  case "restart":
     if( config_perm( "Restart" ) )
     {
       roxen->restart(0.5);
       return
	 "<input type='hidden' name='task' value='restart.pike' />"
	 "<font color='&usr.warncolor;'><h1>Restart</h1></font>"
	 "ChiliMoon will restart automatically.\n\n<p><i>"
	 "You might see the old process for a while in the process table "
	 "when doing 'ps' or running 'top'. This is normal. ChiliMoon waits for a "
	 "while for all connections to finish, the process will go away after "
	 "at most 15 minutes.</i></p>";
     }
     return "Permission denied";

   case "shutdown":
     if( config_perm( "Shutdown" ) )
     {
       roxen->shutdown(0.5);
       return
	 "<font color='&usr.warncolor;'><h1>Shutdown</h1></font>"
	 "ChiliMoon will <b>not</b> restart automatically.\n\n<p><i>"
	 "You might see the old process for a while in the process table "
	 "when doing 'ps' or running 'top'. This is normal. ChiliMoon waits for a "
	 "while for all connections to finish, the process will go away after "
	 "at most 15 minutes.</i></p>";
     }
     return "Permission denied";

  default:
    return Roxen.http_string_answer(
#"<blockquote><br />

 <cf-perm perm='Restart'>
   <gbutton href='?what=restart&task=restart.pike&class=maintenance' 
            width=300 icon_src=&usr.err-2;> Restart </gbutton>
 </cf-perm>

<cf-perm not perm='Restart'>
  <gbutton dim width=300 icon_src=&usr.err-2;> Restart </gbutton>
</cf-perm>

<cf-perm perm='Shutdown'>
  <gbutton href='?what=shutdown&task=restart.pike&class=maintenance' 
           width=300  icon_src=&usr.err-3;> Shutdown </gbutton>
</cf-perm>

<cf-perm not perm='Shutdown'>
  <gbutton dim width=300 icon_src=&usr.err-3;> Shutdown </gbutton>
</cf-perm>

</blockquote>

<p><cf-cancel href='?class=&form.class;'/></p>" );
     }
}
