inherit "wizard";
#define UID id->misc->_automail_user

mixed parse( object id )
{
  id->misc->defines = ([]);
  if(strlen(parse_rxml("<mail-verify-login></mail-verify-login>",id)))
    return http_auth_required("E-mail");

  mixed res =wizard_for( id, fix_relative("",id) );

  if(stringp(res))
    return ("<body bgcolor=darkblue><br><p><center>"+res+
	    "</center></body>");

  return res;
}
