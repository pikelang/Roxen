#define UID id->misc->_automail_user
inherit "wizard";
object clientlayer;
mapping _login = http_auth_required( "E-Mail" );

string login(object id)
{
  string force = ("Permission denied");

  if(!clientlayer)
    return "Internal server error";

  if(!id->realauth) 
  {
    id->misc->defines[" _extra_heads"] = _login->extra_heads;
    id->misc->defines[" _error"] = _login->error;
    return force;
  }

  if(!UID)
  {
    UID = clientlayer->get_user(  @(id->realauth/":") );
    if(!UID) 
    {
      id->misc->defines[" _extra_heads"] = _login->extra_heads;
      id->misc->defines[" _error"] = _login->error;
      return force;
    }
  }
}

mixed parse( object id )
{
  clientlayer = id->conf->get_providers( "automail_clientlayer" )[ 0 ];
  if(string q = login( id ))
    return q;
  mixed res =wizard_for( id, fix_relative("",id) );
  if(stringp(res))
    return ("<body bgcolor=darkblue><br><p><center>"+res+
	    "</center></body>");
  return res;
}
