
mapping parse( RequestID id )
{
  if( id->variables->uid == id->auth[1] )
    return Roxen.http_auth_required( "Roxen Administration Interface" );
  return Roxen.http_redirect( "/"+id->misc->cf_locale+"/", id );
}
