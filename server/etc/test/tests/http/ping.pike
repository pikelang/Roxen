inherit "http_common";

void main(int argc, array argv)
{
  if( argc < 4 )  exit( BADARG );

  Stdio.File f = connect( argv[1] );

  f->write( "PING" + (argc==5?"\n":"\r\n") );
  
  string data = f->read();

  if( data != "PONG\r\n" )
    exit( BADDATA );

  exit( OK );
}
