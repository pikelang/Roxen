#include <roxen.h>
//<locale-token project="roxen_config"> LOCALE </locale-token>
#define LOCALE(X,Y)  _STR_LOCALE("roxen_config",X,Y)

mixed parse( RequestID id )
{
  string res="<br />";
  mixed v = id->variables;
  if(! id->misc->config_user->auth( "Edit Users" ) )
    return LOCALE(226, "Permission denied");

  while( id->misc->orig ) id = id->misc->orig;

  if( v->delete_user && v->delete_user!="")
  {
    roxen.delete_admin_user( v->delete_user );
    return Roxen.http_redirect( "users.html", id );
  }
  foreach( sort( roxen.list_admin_users() ), string uid )
  {
    object u = roxen.find_admin_user( uid );
    if( u == id->misc->config_user )
      res += ("<gbutton font='&usr.gbutton-font;' "
	      "dim='1' width='300'> " +
	      LOCALE(227, "Delete") +" "+ u->real_name+" ("+uid+") "
	      "</gbutton><br />");
    else
      res += 
          ("<gbutton width='300' font='&usr.gbutton-font;' href='user_delete.pike?delete_user="
           + Roxen.html_encode_string(uid) +"&page=delete_user'>"
           + LOCALE(227, "Delete") +" "+ u->real_name+" ("+uid+")"
           + "</gbutton><br />\n\n");
  }
  return Roxen.http_string_answer( res );
}
