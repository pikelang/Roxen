constant cvs_version = "$Id: httpbasic.pike,v 1.1 2001/01/19 12:41:40 per Exp $";
inherit AuthModule;
inherit "module";

constant name = "httpbasic";

//<locale-token project="mod_httpbasic">_</locale-token>
#define _(X,Y)	_DEF_LOCALE("mod_httpbasic",X,Y)

#include <module.h>

LocaleString module_name_locale =
  _(0,"HTTP Basic authentication (username/password");

LocaleString module_doc_locale =
  _(0,"Authenticate users using basic username/password authentication.");
    

User authenticate( RequestID id, UserDB db )
//! Try to authenticate the request with users from the specified user
//! database. If no @[db] is specified, all datbases in the current
//! configuration are searched in order, then the configuration user
//! database.
//!
//! The return value is the autenticated user.
{
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
