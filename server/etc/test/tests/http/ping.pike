inherit "http_common";

void main(int argc, array argv)
{
  if( argc < 4 )  exit( BADARG );

  Stdio.File f = connect( argv[1] );

  if( (int)argv[-1] == 3 )
    write_fragmented( f, "PING\r\n", 1 );
  else
    f->write( "PING" + ((int)argv[-1]==2?"\n":"\r\n") );
  
  string data = f->read();

  if( data != "PONG\r\n" )
    exit( BADDATA );

  exit( OK );
}
