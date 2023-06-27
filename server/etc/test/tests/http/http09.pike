inherit "http_common";

void main(int argc, array argv)
{
  string sep = "\r\n";
  int psize = 10000000;
  if( argc < 4 )  exit( BADARG );
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

  Stdio.File f = connect( argv[1] );

  write_fragmented( f, "GET "+argv[2]+sep,psize );
  
  string data = f->read();

  if( sizeof( data / "\r\n\r\n" ) != 1 )
    exit( HEADERS );

  if( (int)argv[3] )
    if( data != ("\0" * (int)argv[3]) )
      exit( BADDATA );

  exit( OK );
}
