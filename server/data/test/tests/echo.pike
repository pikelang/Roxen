void main(int argc, array argv) 
{
  foreach( argv[1..], string f )
    write( f );
  write( "\n" );
  write( Stdio.stdin.read() );
}
