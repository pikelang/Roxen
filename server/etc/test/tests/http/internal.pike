inherit "http_common";

string md5( string what )
{
  return Gmp.mpz(Crypto.MD5()->update( what )->digest(),256)
    ->digits(32);
}

void main(int argc, array argv)
{
  if( argc < 2 )
    exit( BADARG );

  Stdio.File f = connect(  argv[1] );

  write_fragmented( f,
		    "GET "+argv[2]+" HTTP/1.1\r\n"
		    "Host: "+argv[1]+"\r\n"
		    "Connection: close\r\n"
		    "User-Agent: Roxen Testscript\r\n\r\n",
		    100000 );

  string _d = f->read();

  array q = _d/"\r\n\r\n";
  if( sizeof( q ) < 2 )
    exit( BADHEADERS );

  verify_headers( q[0], strlen(q[1]), "HTTP/1.1", 200, 0);

  if(argc == 4 && md5(q[1]) != argv[3]) {
    write("Expected MD5 %O, got %O.\n", argv[3], md5(q[1]));
    exit( BADDATA );
  }

  exit( OK );
}  
