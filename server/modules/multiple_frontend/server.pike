inherit "module";
inherit "common";
#include <module.h>


// -- Module glue --------------------------------------------------------

constant module_name = "MultipleFrontend Server";
constant module_doc  = "Serves multiple frontends";
constant modult_type = MODULE_FIRST;

string query_provides()
{
  return "mf_server";
}

void create()
{
  defvar( "keyfile", 
          Variables.File( "mf_key",
                          0,
                          "Key file",
                          "The file with the encryption key.\n"
                          "The key can be of any length.\n" ) ); 
  
}


void start( int n, Configuration c )
{
  // 1. Get encryption key
  string kd;
  catch ( kd = variables->keyfile->read() );
  if( !kd )
  {
    report_error( "Failed to read keyfile (%O)\n"
                  "Using non-secure communication\n", query( "keyfile" ) ); 
    kd = Stdio.read_bytes( __FILE__ );
  }
  if( key && (kd != key) )
    catch(clients->command_nb( Command( "simple_event", "key_change" ) ));
  set_key( kd );

  // 2. Register callbacks.
  foreach( glob("cb_*", indices(this_object()) ), string cb )
    set_callback( cb[3..], this_object()[ cb ] );

  // 3. Notify listening servers of configuration change
  clients->command_nb( "simple_event", "server_start" );
}

void stop( )
{
  catch(clients->command_nb( Command( "simple_event", "server_stop" ) ));
}

mapping first_try( RequestID id )
// Catch the RPC method. Otherwise, ignore all requests
{
  if( id->method == "ROXEN_FE_RPC" )
    if( (int)id->not_query != 1 )
      return Roxen.http_string_answer(Result("error", 
                                             "Illegal FE RPC version"),
                                      "text/x-roxen-rpc");
    else
      return Roxen.http_string_answer(handle_rpc_query_data( id->data ),
                                      "text/x-roxen-rpc");
  return 0;
}




// -- Actual code --------------------------------------------------------


class MFClient
{
  string host;
  int port;
  
  mixed command( Command ... c )
  {
    return do_query( host, port, @c );
  }

  void command_nb( Command ... c )
  {
    return do_nb_query( host, port, @c );
  }

  static void create( string _host, int _port )
  {
    host = _host;
    port = _port;
  }
}

array(MFClient) clients = ({});

void send_event( string evt, mixed arg )
{
  clients->command_nb( Command( evt, arg ) );
}


// -- Callbacks client->server ------------------------------------------
void cb_register_client( Command c )
{
  if( !arrayp(c->data) || sizeof( c->data ) != 2 )
    error( "Wrong number of arguments to register_client\n" );
  foreach( clients, MFClient cl )
  {
    if( cl->host == cl->data[0] &&
        cl->port == cl->data[1] )
      return;
  }
  clients += ({ MFClient( @cl->data ) });
} 


void cb_unregister_client( Command c )
{
  if( !arrayp(c->data) || sizeof( c->data ) != 2 )
    error( "Wrong number of arguments to unregister_client\n" );
  foreach( clients, MFClient cl )
    if( cl->host == cl->data[0] &&
        cl->port == cl->data[1] )
      clients -= ({ cl });
}
