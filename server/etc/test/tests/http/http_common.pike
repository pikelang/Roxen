constant OK         =   0;
// 1 is compilation failed from pike.
constant BADHEADERS =   2;
constant BADDATA    =   3;
constant NOCONN     =   4;

constant BADPROT    =   5;
constant BADCODE    =   6;
constant NODATE     =   7;
constant BADLENGTH  =   8;
constant BADMODIFIED=   9;
// 10 is error-in-execution from pike.
constant HEADERS    =  11;
constant DATA       =  12;
constant CONN       =  13;

constant TIMEOUT    =  99;
constant BADARG     = 100;

void setup_timeout( )
{
#ifndef __NT__
  void timeout() {  exit( TIMEOUT ); };
  signal( 14, timeout );
  alarm( 30 );
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

void write_fragmented( Stdio.File to,
		       string what,
		       int chars )
{
  foreach( what/((float)chars), string w )
  {
    to->write( w );
    sleep( 0.01 );
  }
}

#define EXIT(X)  while(1){write("\n\n\nThe offending response header:\n%O\n\n" \
				"Protocol: %O (%O)\n" \
				"Return code: %d (%d)\n" \
				"Response mapping: %O\n", \
                                headers,prot,expected_prot, \
				code,expected_code,hd);exit((X));}

void verify_headers( string headers, int content_length,
		     string expected_prot, int expected_code,
		     int want_last_modified, )
{
  array q = headers / "\r\n";
  string prot;
  int code;
  string message;
  mapping hd = ([]);

  if( sscanf( q[0], "%s %d %s", prot, code, message ) != 3 ) EXIT( BADHEADERS );
  if( prot != expected_prot )    EXIT( BADPROT );
  if( code != expected_code )    EXIT( BADCODE );

  foreach( q[1..], string header )
  {
    string a, b;
    sscanf( header, "%s: %s", a, b );
    hd[ lower_case( a ) ] = b;
  }

  if( !hd->date )
    EXIT( NODATE );
  if( !hd["content-length"] || (int)hd["content-length"]  != content_length )
    EXIT( BADLENGTH );
  if( want_last_modified && !hd["last-modified"] )
    EXIT( BADMODIFIED );
}

