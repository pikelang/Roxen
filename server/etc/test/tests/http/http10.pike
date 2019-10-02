inherit "http_common";

void main(int argc, array argv)
{
  string  sep = "\r\n";
  int     psize = 100000, hlen;
  int fail;
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

      case 5:
	hlen = 1024;
	break;
      case 6:
	hlen = 10240;
	break;
      case 7:
	hlen = 102400;
	break;

      case 8:
	hlen = 1024;
	sep = "\n";
	break;
      case 9:
	hlen = 10240;
	sep = "\n";
	break;
      case 10:
	sep = "\n";
	hlen = 102400;
	break;
      case 11:
	sep = "\n";
	hlen = 1024000;
	fail=1;
	break;
    }
  }

  Stdio.File f = connect(  argv[1] );
  string extra_headers="";
  while( strlen( extra_headers )+100 < hlen )
    extra_headers += "Extra-Headers: Filler"+sep;
  
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

  verify_headers( q[0], strlen(q[1]), "HTTP/1.0",
		  (fail?500:(argv[2] != "/nofile" ? 200 : 404)),
		  !fail && (argv[2][strlen(argv[2])-3..]=="raw"));

  if( (int)argv[3] )
    if( q[1] != ("\0" * (int)argv[3]) )
      exit( BADDATA );

  exit( OK );
}  
