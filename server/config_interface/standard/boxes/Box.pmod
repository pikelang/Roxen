class Fetcher
{
  Protocols.HTTP.Query query;
  function cb;
  string h, q;
  int p;

  void done( Protocols.HTTP.Query qu )
  {
    cache_set( "box_data", h+p+q, ({query->data()}),3600*2 );
    if( cb )
      cb( query->data() );
  }
  
  void fail( Protocols.HTTP.Query qu )
  {
    cache_set( "box_data", h+p+q, ({"Failed to connect to server"}) );
    if( cb )
      cb(  "Failed to connect to server" );
    call_out( start, 30 );
  }

  void start( )
  {
    remove_call_out( start );
    call_out( start, 3600 );
    query = Protocols.HTTP.Query( )->set_callbacks( done, fail );
    query->async_request( h, p, q, ([ "Host":h+":"+p ]) );
  }
  
  void create( function _cb, string _h, int _p, string _q  )
  {
    cb = _cb;
    h = _h; p = _p; q = _q;
    start();
  }
}

string get_http_data( string host, int port, string query,
		      function|void cb )
{
  mixed data;
  if( data = cache_lookup( "box_data", host+port+query ) )
  {
    return data[0];
  }
  else
  {
    cache_set( "box_data", host+port+query, ({0}), 40 );
    Fetcher( cb, host, port, query );
  }
}
