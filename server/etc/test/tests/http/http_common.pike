constant OK         =   0;

constant BADHEADERS =   2;
constant BADDATA    =   3;
constant NOCONN     =   4;

constant HEADERS    =  11;
constant DATA       =  12;
constant CONN       =  13;

constant TIMEOUT    =  99;
constant BADARG     = 100;

void setup_timeout( )
{
  void timeout() {  exit( TIMEOUT ); };
#ifndef __NT__
  signal( 14, timeout );
  alarm( 5 );
#endif
}

array get_host_port( string url )
{
  string host;
  int port;

  if( sscanf( url, "http://%s:%d/", host, port ) != 2 )
    exit( BADARG );
  return ({ host, port });
}

Stdio.File connect( string url )
{
  setup_timeout( );

  Stdio.File f = Stdio.File();
  [string host, int port] = get_host_port( url );
  if( !f->connect( (host=="*"?"127.0.0.1":host), port ) )
    exit( NOCONN );

  return f;
}


void verify_headers( string headers, int content_length )
{
  
}

