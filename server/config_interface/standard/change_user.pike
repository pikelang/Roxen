inherit "roxenlib";

mapping parse( object id )
{
  if( id->variables->uid == id->auth[1] )
    return http_auth_required( "Roxen config interface" );
  return http_redirect( "/"+id->misc->cf_locale+"/", id );
}
