#include <config_interface.h>
#include <roxen.h>
//<locale-token project="config_interface"> LOCALE </locale-token>
#define LOCALE(X,Y)  _STR_LOCALE("config_interface",X,Y)

mapping parse( RequestID id )
{
  string res="";

  RequestID nid = id;

  while( nid->misc->orig && !nid->my_fd )
    nid = nid->misc->orig;

  if( !nid->misc->config_user->auth( "Edit Users" ) )
    return Roxen.http_string_answer(LOCALE("dy", 
					   "No such luck (permission denied)"),
				    "text/html");

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

  return Roxen.http_string_answer(res, "text/html");
}
