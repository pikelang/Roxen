Remote.Client client;
inherit .MessengerChain;

void create( string remote_host, int remote_port, string remote_id )
{
  client = Remote.Client( remote_host, remote_port, 1, 2, 1 );
  client->set_close_callback( lambda()
                              { 
                                create(remote_host, 
                                       remote_port, 
                                       remote_id ); 
                              } );
  client->get( remote_id )->connect( this_object( ) );
}
