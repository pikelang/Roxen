
mapping parse( RequestID id )
{
  User u = id->conf->authenticate( id, roxen.admin_userdb_module );
  if( !u || (id->variables->uid == u->name()) )
    return id->conf->authenticate_throw( id,
					 "ChiliMoon Administration Interface",
				       roxen.admin_userdb_module );
  return Roxen.http_redirect( "/", id );
}
