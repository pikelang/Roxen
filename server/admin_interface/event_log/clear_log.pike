
mapping parse( RequestID id )
{
  User u = id->conf->authenticate( id, core.admin_userdb_module );
  core->error_log = ([]);
  report_notice(sprintf("Event log cleared by %s from %s\n",
			u?u->name():"a user",
			(gethostbyaddr(id->remoteaddr)    ? 
			 gethostbyaddr(id->remoteaddr)[0] : id->remoteaddr))
		);
  return Roxen.http_redirect( "../global_settings/?section=event_log", id );
}
