inherit "http_common";

void main(int argc, array argv)
{
  if( argc != 4 )  exit( BADARG );

  Stdio.File f = connect(  argv[1] );

  f->write( "GET "+argv[2]+"\r\n" );
  
  string data = f->read();

  if( sizeof( data / "\r\n\r\n" ) != 1 )
    exit( HEADERS );

  if( (int)argv[3] )
    if( data != ("\0" * (int)argv[3]) )
      exit( BADDATA );

  exit( OK );
}
