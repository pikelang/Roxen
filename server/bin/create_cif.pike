Stdio.File outf;
string input, output;

void add_to_cif( int char, string data )
{
  outf->write( "%4c%4c%s", char, strlen(data), data );
}

void name_cif( string n )
{
  while( strlen( n ) < 64 ) n += "\0";
  outf->write( n[..63] );
}

void init_cif( )
{
  outf->write( "CIF1" );
}

void abort_cif( )
{
  outf->close();
  rm( output );
}

string font_name( string what )
{
  Parser.HTML()->
    add_container("name", lambda(string t, mapping m, string c) {
			    what=c; return "";
			  } )->finish(what);
  return (lower_case( replace(what," ","_") )/"\n")[0]-"\r";
}

void use_image_dir( )
{
  input += "/";
  if( !file_stat( input + "fontname" ) )
  {
    werror("Not a imagedir font\n");
    abort_cif();
    exit(1);
  }
  name_cif( font_name( Stdio.read_bytes( input + "fontname" ) ) );
  foreach( get_dir( input )-({ "fontname" }), string fn )
  {
    int wc;
    string of = fn;
    sscanf( fn, "%s.", fn );
    if( fn == "fontinfo" )
      wc = 0xffffffff;
    else if( strlen(fn) > 2 ) 
      sscanf( fn, "0x%x", wc ); 
    else if( strlen(fn) == 1 )
      wc=fn[ 0 ];
    werror(" %x\n", wc );
    add_to_cif( wc, Stdio.read_bytes( input+of ) );
  }
  // EOF marker. Not really needed, but somewhat nice.
  add_to_cif( 0, "" );
}

void use_image_tar( )
{
  Filesystem.Tar it = Filesystem.Tar( input );
  Stdio.File da_f;
  if(! (da_f = it->open( "fontname", "r" ) ) )
  {
    werror("Not a imagetar font\n");
    abort_cif();
    exit(1);
  }
  name_cif( font_name( da_f->read() ) );
  foreach( it->get_dir() - ({ "fontname", "/fontname" }), string fn )
  {
    int wc;
    string of = fn;
    fn -= "/";
    sscanf( fn, "%s.", fn );
    if( strlen(fn) > 2 ) 
      sscanf( fn, "0x%x", wc ); 
    else if( strlen(fn) == 1 )
      wc=fn[ 0 ];
    werror(" %x\n", wc );
    add_to_cif( wc, it->open( of, "r" )->read() );
  }
  // EOF marker. Not really needed, but somewhat nice.
  add_to_cif( 0, "" );
}

void main(int argc, array argv)
{
  if( argc != 3 )
    werror("Syntax: create_cif input output\n"
           "  input is either a imagedirectory or an imagetar font\n"
           "  output will be the cif font\n" );
  input = argv[1];
  outf = Stdio.File( (output = argv[2]), "wct" );
  init_cif();
  switch( file_stat( input )[ 1 ] )
  {
   case -2: // image dir
     use_image_dir( );
     break;
   default:
     use_image_tar( );
     break;
  }
}
