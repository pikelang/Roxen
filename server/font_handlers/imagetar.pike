inherit "imagedir" : id;

constant name = "Image TAR-file fonts";
constant doc = ("Handles a tarfile with images (in almost any format), each "
                "named after the character they will represent. Characters "
                "with codes larger than 127 or less than 48 are encoded like "
                "0xHEX where HEX is the code in hexadecimal. gzipcompressed "
                "tarfiles are not handled. The images must not be in a "
                "subdirectory in the tarfile.");


mapping(string:Filesystem.Tar) tarcache = ([]);

Filesystem.Tar open_tar( string path )
{
  if( tarcache[ path ] ) return tarcache[ path ];
  return (tarcache[ path ] = Filesystem.Tar( path ));
}

class myFont
{
  inherit id::myFont;
  Filesystem.Tar mytar;

  static mapping(string:Image.Image) load_char( string c )
  {
#ifdef THREADS
    object key = lock->lock();
#endif
    if( c[0] == 0x120 ) return smallspacechar;
    if(!files)
      files = mytar->get_dir( "/" ) - ({ "fontname" });
    array possible = ({ "/"+encode_char(c) })+
          glob("/"+encode_char( c )+".*", files);
    sort( map(possible,strlen), possible );
    foreach( possible, string pf )
    {
      catch {
        if( mapping r = Image._decode( mytar->open( pf[1..], "r" )->read()) )
          return r;
      };
    }
    if( c == " " ) return spacechar;
    return nullchar;
  }

  void create( string _p, int _s )
  {
    ::create( _p, _s );
    mytar = open_tar( _p );
  }
}

void update_font_list()
{
  font_list = ([]);
  void rec_find_in_dir( string dir )
  {
    foreach( get_dir( dir )||({}), string pd )
    {
      if( file_stat( dir+pd )[ ST_SIZE ] == -2 ) // isdir
        rec_find_in_dir( dir+pd+"/" );
      else if( glob( "*.tar", pd ) )
      {
        Filesystem.Tar t = open_tar( dir+pd );
        if( Stdio.File f = t->open( "fontname", "r" ) )
          font_list[font_name( f->read() )] = dir+pd;
        else
          destruct( t );
      }
    }
  };

  foreach(roxen->query("font_dirs"), string dir)
    rec_find_in_dir( dir );
}
