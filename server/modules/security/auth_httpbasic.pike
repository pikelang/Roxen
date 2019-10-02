// This is a roxen module. Copyright © 2001 - 2009, Roxen IS.

constant cvs_version =
  "$Id$";
inherit AuthModule;
inherit "module";

constant name = "basic";

//<locale-token project="mod_auth_httpbasic">_</locale-token>
#define _(X,Y)	_DEF_LOCALE("mod_auth_httpbasic",X,Y)

#include <module.h>

LocaleString module_name =
  _(1,"Authentication: Password");

LocaleString module_doc =
  _(2,"Authenticate users using basic username/password authentication.");

protected array(string) parse_auth_header( mixed header )
{
  array(string) res;
  array(string) handle_header( string header ) 
  {
    string a, b;
    if( sscanf( header, "%[^ ] %s", a, b ) == 2 )
      switch( a )
      {
	case "Basic":
	case "basic":
	  b = MIME.decode_base64( b );
	  if( sscanf( b, "%[^:]:%s", a, b ) == 2 )
	    return ({ a, b });
      }
  };
  if( arrayp( header ) )
  {
    foreach( header, header )
      if( (res = handle_header( header )) && res[0] )
	return res;
  }
  else
    return handle_header( header );
  return ({ 0,0 });
}


protected User low_authenticate( RequestID id,
				 string user, string password,
				 UserDB db)
{
  if( User u = db->find_user( user, id ) )
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

  mixed header;
  
  if( !user )
    if( header = id->request_headers[ "authorization" ] )
      [user,password] = parse_auth_header( header ) || ({ 0,0 });
    else if( id->realauth )
      sscanf( id->realauth, "%[^:]:%s", user, password );
    else
      return 0; // Not very likely to work...
  
  if( !user || !password )
    return 0;
  
  User res;
  if( !db )
  {
    foreach( id->conf->user_databases(), UserDB db )
      if( res = low_authenticate( id, user, password, db ) )
	break;
  }
  else
    res = low_authenticate( id, user, password, db );
  if (res)
  {
    id->misc->uid = res->uid();
    id->misc->gid = res->gid();
    id->misc->gecos = res->gecos();
    id->misc->home = res->homedir();
    id->misc->shell = res->shell();
  }
  return res;
}


mapping authenticate_throw( RequestID id, string realm, UserDB db )
//! Returns a reply mapping, similar to @[Roxen.http_rxml_reply] with
//! friends. If no @[db] is specified,  all datbases in the current
//! configuration are searched in order, then the configuration user
//! database.
{
  return Roxen.http_auth_required( realm, 0, id );
}
