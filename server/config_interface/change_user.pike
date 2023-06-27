
mapping parse( RequestID id )
{
  User u = id->conf->authenticate( id, roxen.config_userdb_module );
  if( !u || (id->variables->uid == u->name()) )
    return id->conf->authenticate_throw( id,
                                         "Roxen Administration Interface",
                                       roxen.config_userdb_module );
  return Roxen.http_redirect( "/", id );
}
