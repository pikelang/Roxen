inherit "http_common";

void main(int argc, array argv)
{
  if( argc != 4 )  exit( BADARG );

  Stdio.File f = connect(  argv[1] );

  f->write( "GET "+argv[2]+" HTTP/1.0\r\n"
	    "User-Agent: testcript\r\n"
	    "\r\n" );

  string _d = f->read();

  array q = _d/"\r\n\r\n";
  if( sizeof( q ) < 2 )
    exit( BADHEADERS );

  verify_headers( q[0], strlen(q[1]) );

  if( (int)argv[3] )
    if( q[1] != ("\0" * (int)argv[3]) )
      exit( BADDATA );

  exit( OK );
}  
