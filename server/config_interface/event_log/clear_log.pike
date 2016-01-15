#include <roxen.h>
//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

mapping parse( RequestID id )
{
  User u = id->conf->authenticate( id, roxen.config_userdb_module );
  roxen->error_log = ([]);
  report_notice(sprintf(LOCALE(298, 
			       "Event log cleared by %s from %s")+"\n",
			u?u->name():"a user",
			(gethostbyaddr(id->remoteaddr)    ? 
			 gethostbyaddr(id->remoteaddr)[0] : id->remoteaddr))
		);
  return Roxen.http_redirect( "../global_settings/?section=event_log&amp;&usr.set-wiz-id;", id );
}
