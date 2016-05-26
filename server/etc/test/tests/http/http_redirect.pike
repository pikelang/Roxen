inherit "http_common";

void main(int argc, array argv)
{
  string  sep = "\r\n";
  int     psize = 100000;
  int fail;
  if( argc < 4 )
    exit( BADARG );

  Stdio.File f = connect(  argv[1] );

  string extra_headers = "";
  if (argc > 4) {
    extra_headers = argv[4..] * sep + sep;
  }

  write_fragmented( f,
		    "GET "+argv[2]+" HTTP/1.0"+sep+
		    "Connection: close"+sep+
		    extra_headers+
		    "User-Agent: Roxen Testscript"+sep+sep,
		    psize );

  string _d = f->read();

  if ( !_d )
    if(!fail)
      _d = "HTTP/1.0 500 Internal Server Error\r\n";
    else
      exit( OK );

  array q = _d/"\r\n\r\n";
  if( sizeof( q ) < 2 )
    exit( BADHEADERS );

  mapping headers = verify_headers( q[0], strlen(q[1]), "HTTP/1.0", 302, 0);

  if (headers["location"] != argv[3]) {
    werror("Unexpected redirect location: %O != %O\n",
	   headers["location"], argv[3]);
    exit( BADHEADERS );
  }

  exit( OK );
}
