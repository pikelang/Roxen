inherit "http_common";

void main(int argc, array argv)
{
  string  sep = "\r\n";
  int     psize = 100000;
  if( argc < 4 )
    exit( BADARG );

  if( argc == 5 )
  {
    switch( (int)argv[4] )
    {
      case 1:
	break;
      case 2:
	sep = "\n";
	break;
      case 3:
	psize = 1;
	break;
      case 4:
	psize = 10;
	break;
    }
  }

  Stdio.File f = connect(  argv[1] );


  write_fragmented( f, 
		    "GET "+argv[2]+" HTTP/1.0"+sep+
		    "Connection: close"+sep+
		    "User-Agent: testcript"+sep+sep,
		    psize );

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
