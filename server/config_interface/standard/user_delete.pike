#include <roxen.h>
//<locale-token project="roxen_config"> LOCALE </locale-token>
#define LOCALE(X,Y)  _STR_LOCALE("roxen_config",X,Y)

mixed parse( RequestID id )
{
  string res="<br />";
  mapping v = id->variables;
  if(! id->misc->config_user->auth( "Edit Users" ) )
    return LOCALE(226, "Permission denied");

  while( id->misc->orig ) id = id->misc->orig;

  if( v->delete_user && v->delete_user!="")
  {
    id->misc->delete_old_config_user( v->delete_user );
    return Roxen.http_redirect( "users.html", id );
  }
  foreach( sort( id->misc->list_config_users() ), string uid )
  {
    object u = id->misc->get_config_user( uid );
    if( u == id->misc->config_user )
      res += ("<gbutton font='&usr.gbutton-font;' "
	      "dim='1' width='300' preparse='1'> " +
	      LOCALE(227, "Delete") +" "+ u->real_name+" ("+uid+") "
	      "</gbutton><br />");
    else
      res += 
          ("<a href='user_delete.pike?delete_user="
           + Roxen.html_encode_string(uid) +"&page=delete_user'>"
           + "<gbutton width='300' font='&usr.gbutton-font;'> "
           + LOCALE(227, "Delete") +" "+ u->real_name+" ("+uid+")"
           + "</gbutton><br />\n\n");
  }
  return res;
}
