constant OK         =   0;

constant BADHEADERS =   2;
constant BADDATA    =   3;
constant NOCONN     =   4;

constant BADPROT    =   5;
constant BADCODE    =   6;
constant NODATE     =   7;
constant BADLENGTH  =   8;
constant BADMODIFIED=   9;

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


void verify_headers( string headers, int content_length,
		     string expected_prot, int expected_code,
		     int want_last_modified )
{
  array q = headers / "\r\n";
  string prot;
  int code;
  string message;
  if( sscanf( q[0], "%s %d %s", prot, code, message ) != 3 )exit( BADHEADERS );
  if( prot != expected_prot )    exit( BADPROT );
  if( code != expected_code )    exit( BADCODE );


  mapping hd = ([]);
  foreach( q[1..], string header )
  {
    string a, b;
    sscanf( header, "%s: %s", a, b );
    hd[ lower_case( a ) ] = b;
  }

  if( !hd->date )
    exit( NODATE );
  if( !hd["content-length"] || (int)hd["content-length"]  != content_length )
    exit( BADLENGTH );
  if( want_last_modified && !hd["last-modified"] )
    exit( BADMODIFIED );
}

