constant cvs_version =
  "$Id: auth_httpbasic.pike,v 1.1 2001/01/19 16:35:46 per Exp $";
inherit AuthModule;
inherit "module";

constant name = "httpbasic";

//<locale-token project="mod_auth_httpbasic">_</locale-token>
#define _(X,Y)	_DEF_LOCALE("mod_auth_httpbasic",X,Y)

#include <module.h>

LocaleString module_name_locale =
  _(0,"HTTP Basic authentication (username/password");

LocaleString module_doc_locale =
  _(0,"Authenticate users using basic username/password authentication.");

static User low_authenticate( RequestID id,
			      string user, string password,
			      User DB db )
{
  if( User u = db->find_user( user ))
    if( u->password_authenticate( password ) )
      return u;
}

User authenticate( RequestID id, UserDB db )
//! Try to authenticate the request with users from the specified user
//! database. If no @[db] is specified, all datbases in the current
//! configuration are searched in order, then the configuration user
//! database.
//!
//! The return value is the autenticated user.
{
  string password = id->misc->password;
  string user     = id->misc->user;

  if( !user )
    if( id->realauth )
      [user,password] = (id->realauth/":");
    else
      return 0; // Not very likely to work...
    
  if( !db )
  {
    int res;
    foreach( id->conf->user_databases(), UserDB db )
      if( res = low_authenticate( id, user, password, db ) )
	return res;
    return 0;
  }
  return low_authenticate( id, user, password, db );
}


mapping authenticate_throw( RequestD id, string realm, UserDB db )
//! Returns a reply mapping, similar to @[Roxen.http_rxml_reply] with
//! friends. If no @[db] is specified,  all datbases in the current
//! configuration are searched in order, then the configuration user
//! database.
{
  return Roxen.http_auth_required( realm );
}
