#include <roxen.h>
//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

mapping parse( RequestID id )
{
  roxen->error_log = ([]);
  report_notice(sprintf(LOCALE(298, 
			       "Event log cleared by %s from %s")+"\n",
			id->auth ? id->auth[1] : "anonymous",
			(gethostbyaddr(id->remoteaddr) ? 
			 gethostbyaddr(id->remoteaddr)[0] : id->remoteaddr))
		);
  return Roxen.http_redirect( "index.html", id );
}
