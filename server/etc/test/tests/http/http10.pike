inherit "http_common";

void main(int argc, array argv)
{
  string sep;
  if( argc < 4 )  exit( BADARG );
  if( argc == 5 )  sep = "\n"; else  sep = "\r\n";

  Stdio.File f = connect(  argv[1] );

  f->write( "GET "+argv[2]+" HTTP/1.0"+sep+
	    "User-Agent: testcript"+sep+
	    sep );

  string _d = f->read();

  array q = _d/"\r\n\r\n";
  if( sizeof( q ) < 2 )
    exit( BADHEADERS );

  verify_headers( q[0], strlen(q[1]), "HTTP/1.0",
		  (argv[2] != "/nofile" ? 200 : 404),
		  (argv[2][strlen(argv[2])-3..]=="raw"));

  if( (int)argv[3] )
    if( q[1] != ("\0" * (int)argv[3]) )
      exit( BADDATA );

  exit( OK );
}  
