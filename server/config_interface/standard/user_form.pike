inherit "roxenlib";

#include <config_interface.h>
mapping parse( RequestID id )
{
  string res="";

  RequestID nid = id;

  while( nid->misc->orig && !nid->my_fd )
    nid = nid->misc->orig;

  if( !nid->misc->config_user->auth( "Edit Users" ) )
    return http_string_answer("No such luck (permission denied)", "text/html");

  foreach( sort( nid->misc->list_config_users() ), string uid )
  {
    object u  = nid->misc->get_config_user( uid );
    res += "<table width='100%'><tr><td bgcolor='"+config_setting2("bgcolor")+
           "'><font size='+2'>&nbsp;&nbsp;<b>"+uid+"</b></font></td></tr></table>";
    res += u->form( nid );
  }

  do
  {
    id->variables = nid->variables;
    id = id->misc->orig;
  } while( id );

  return http_string_answer(res, "text/html");
}
