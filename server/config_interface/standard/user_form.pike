#include <config_interface.h>
string parse( RequestID id )
{
  string res="";

  if( id->misc->orig )
    id = id->misc->orig;

  if(! id->misc->config_user->auth( "Edit Users" ) )
    return "No such luck (permission denied)";

  foreach( sort( id->misc->list_config_users() ), string uid )
  {
    object u  = id->misc->get_config_user( uid );
    res += "<table width='100%'><tr><td bgcolor='"+config_setting2("bgcolor")+
           "'><font size='+2'>&nbsp;&nbsp;<b>"+uid+"</b></font></td></tr></table>";
    res += u->form( id );
  }
  return res;
}
