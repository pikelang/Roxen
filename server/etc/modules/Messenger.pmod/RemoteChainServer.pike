Remote.Server server;
inherit .MessengerChain;

void create( string host, int port, string id )
{
  server = Remote.Server( host, port, 8 );
  server->provide( id, this_object( ) );
}
