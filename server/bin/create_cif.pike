Stdio.File outf;
string input, output;

void add_to_cif( int char, string data, string prefix )
{
  if( char < 0xffffff )
    data = data[sizeof(prefix)..];
  outf->write( "%4c%4c%s", char, sizeof(data), data );
}

void name_cif( string n )
{
  while( sizeof( n ) < 64 ) n += "\0\0\0\0\0\0\0\0\0";
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

array(string) font_name( string what )
{
  string name = what;
  string info = Parser.HTML()->
    add_container("name", lambda(string t, mapping m, string c) {
			    name=c; return "";
			  } )->finish(what)->read();
  if(info==name) info=0;
  name = (lower_case( replace(name," ","_") )/"\n")[0]-"\r";
  info = info - "\r" - "\n";
  return ({ name, info });
}

string find_prefix( string dir )
{
  string prefix;
  werror("Finding longest common prefix ... ");
  foreach( get_dir( dir ), string f )
  {
    if( f!="prefix" &&  f!= "fontinfo" && f!="fontname" && f[0] != '.' )
    {
      if( !prefix )
        prefix = Stdio.read_bytes( dir+"/"+f );
      else
      {
        string against = Stdio.read_bytes( dir+"/"+f );
        while( !has_prefix( against, prefix ) )
          prefix = prefix[..sizeof(prefix)-2];
      }
    }
  }
  werror( "Done, "+sizeof(prefix)+" bytes\n" );
  return prefix;
}

void use_image_dir( )
{
  input += "/";
  string prefix = find_prefix( input );

  string name, info;
  if( file_stat( input + "fontinfo" ) )
    [name, info] = font_name( Stdio.read_bytes( input + "fontinfo" ) );
  else if( file_stat( input + "fontname" ) )
    name = font_name( Stdio.read_bytes( input + "fontname" ) ) [0];
  else {
    werror("Not a imagedir font\n");
    abort_cif();
    exit(1);
  }

  name_cif( name );
  foreach( get_dir( input )-({ "fontname","fontinfo" }), string fn )
  {
    int wc;
    string of = fn;
    sscanf( fn, "%s.", fn );
    if( fn == "prefix" )
      wc = 0xfffffffe;
    else if( sizeof(fn) > 2 )
      sscanf( fn, "0x%x", wc );
    else if( sizeof(fn) == 1 )
      wc=fn[ 0 ];
    werror(" %x\n", wc );
    add_to_cif( wc, Stdio.read_bytes( input+of ), prefix );
  }
  if( sizeof( prefix ) )
    add_to_cif( 0xfffffffe, prefix, "" );
  if( info )
    add_to_cif( 0xffffffff, info, "");

  // EOF marker. Not really needed, but somewhat nice.
  add_to_cif( 0, "", prefix );
}

void use_image_tar( )
{
  Filesystem.Tar it = Filesystem.Tar( input );
  Stdio.File da_f;
  string name, info;
  if(da_f = it->open( "fontinfo", "r" ))
    [name, info] = font_name( da_f->read() );
  else if(da_f = it->open( "fontname", "r" ))
    name = font_name( da_f->read() ) [0];
  else {
    werror("Not a imagetar font\n");
    abort_cif();
    exit(1);
  }

  name_cif( name );
  foreach( it->get_dir() - ({ "fontname", "/fontname", "fontinfo", "/fontinfo" }),
	   string fn )
  {
    int wc;
    string of = fn;
    fn -= "/";
    sscanf( fn, "%s.", fn );
    if( sizeof(fn) > 2 ) 
      sscanf( fn, "0x%x", wc ); 
    else if( sizeof(fn) == 1 )
      wc=fn[ 0 ];
    werror(" %x\n", wc );
    add_to_cif( wc, it->open( of, "r" )->read(), "" );
  }
  // EOF marker. Not really needed, but somewhat nice.
  add_to_cif( 0, "", "" );
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
