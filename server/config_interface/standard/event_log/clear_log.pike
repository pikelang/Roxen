inherit "roxenlib";

#define USER( X ) (id->auth?id->auth[1]:"anonymous")
#define HOST( X ) (gethostbyaddr(id->remoteaddr)?gethostbyaddr(id->remoteaddr)[0]:id->remoteaddr)

mapping parse( object id )
{
  roxen->error_log = ([]);
  report_notice( "Event log cleared by "+USER( id ) + " from "+ HOST( id )+
                 "\n" );
  return http_redirect( "/standard/event_log", id );
}
