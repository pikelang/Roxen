class CIF
{
  Stdio.File fd;
  array filelist ;
  mapping offsets;
  string prefix = "";
  array get_dir( string f )
  {
    if(!filelist)
    {
      offsets = ([]);
      filelist = ({ "/fontname" });
      
      fd->seek( 64 + 4 ); // header.
      int c;
      while( c = getint() )
      {
        offsets[c] = fd->tell();
        if( c < 48 || c > 127 )
          if( c == 0xffffffff )
            filelist += ({ "/fontinfo" });
          else
            filelist += ({ sprintf( "/0x%x", c ) });
        else
          filelist += ({ sprintf( "/%c", c ) });
        if( c == 0xfffffffe )
          prefix = fd->read( getint() );
        else
          fd->read( getint() );
      }
    }
    return filelist;
  }

  int getint( )
  {
    int c;
    sscanf( fd->read( 4 ), "%4c", c );
    return c;
  }

  Stdio.File open( string fname, string mode )
  {
    if(!offsets) get_dir( "foo" );
    fname -= "/";
    if( fname == "fontname" )
    {
      fd->seek( 4 );
      return Stdio.FakeFile( fd->read( 64 )-"\0" );
    }

    int wc;
    sscanf( fname, "%s.", fname );
    if( sizeof(fname) > 2 )
      sscanf( fname, "0x%x", wc );
    else
      wc=fname[0];
    int c;

    if( fname == "fontinfo" )
      wc = 0xffffffff;

    if( offsets[ wc ] )
    {
      fd->seek( offsets[ wc ] );
      if( wc <= 0x7fffffff ) // Normal character
        return Stdio.FakeFile( prefix+fd->read( getint() ) );
      return Stdio.FakeFile( fd->read( getint() ) );
    }
    return 0;
  }

  void create( string fname )
  {
    fd = Stdio.File( );
    if( !fd->open( fname, "r" ) )  error( "Illegal CIF\n");
    if( fd->read( 4 ) != "CIF1" )  error( "Illegal CIF\n");
  }
}


void main( int argc, array argv)
{
  CIF input_file = CIF( argv[-1] );
  foreach( input_file->get_dir("/")-({"/0xfffffffe"}), string f )
  {
    Stdio.File out = Stdio.File( getcwd()+f, "wct" );
    out->write( input_file->open( f,"r" )->read() );
  }
}
