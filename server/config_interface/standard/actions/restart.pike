#include <config_interface.h>

constant name="Restart or shutdown";
constant name_svenska = "Starta om eller stäng av roxen";
constant doc = "";
constant action="maintenance";

string parse(object id)
{
  switch( id->variables->what )
  {
   case "restart":
     if( config_perm( "Restart" ) )
     {
       roxen->restart(0.1);
       return
#"<input type=hidden name=action value=restart.pike>
<font color=darkred><h1>&locale.restart;</h1></font>
Roxen will restart automatically.

<p><i>You might see the old process for a while in the process table
when doing 'ps' or running 'top'. This is normal. Roxen waits for a
while for all connections to finish, the process will go away after at
most 15 minutes.</i> </font>";
     }
     return "Permission denied";

   case "shutdown":
     if( config_perm( "Shutdown" ) )
     {
       roxen->shutdown(0.1);
       return
#"<font color=darkred><h1>&locale.shutdown;</h1></font>
Roxen will <b>not</b> restart automatically.

<p><i>You might see the old process for a while in the process table
when doing 'ps' or running 'top'. This is normal. Roxen waits for a
while for all connections to finish, the process will go away after at
most 15 minutes.</i> </font>";
     }
     return "Permission denied";

  default:
     return
#"<blockquote><br>

 <cf-perm perm='Restart'>
   <gbutton href='?what=restart&action=restart.pike&class=maintenance' width=300
           icon_src=/internal-roxen-err_2 preparse> &locale.restart; </gbutton>
 </cf-perm>

<cf-perm not perm='Restart'>
  <gbutton dim width=300  preparse
           icon_src=/internal-roxen-err_2> &locale.restart; </gbutton>
</cf-perm>

<cf-perm perm='Shutdown'>
  <gbutton href='?what=shutdown&action=restart.pike&class=maintenance' width=300  preparse
          icon_src=/internal-roxen-err_3> &locale.shutdown; </gbutton>
</cf-perm>

<cf-perm not perm='Shutdown'>
  <gbutton dim width=300  preparse
           icon_src=/internal-roxen-err_3> &locale.shutdown; </gbutton>
</cf-perm>";
     }
}
