#include <config.h>
#include <stat.h>
constant cvs_version = "$Id: imagedir.pike,v 1.3 2000/09/04 06:49:34 per Exp $";

constant name = "Image directory fonts";
constant doc = ("Handles a directory with images (in almost any format), each "
                "named after the character they will represent. Characters "
                "with codes larger than 127 or less than 48 are encoded like "
                "0xHEX where HEX is the code in hexadecimal");

inherit FontHandler;

#ifdef THREADS
Thread.Mutex lock = Thread.Mutex();
#endif

static mapping nullchar = ([ "image":Image.Image(1,1),
                             "alpha":Image.Image(1,1) ]);
static mapping spacechar = ([ "image":Image.Image(10,1),
                              "alpha":Image.Image(10,1) ]);
static mapping smallspacechar = ([ "image":Image.Image(2,1),
                                   "alpha":Image.Image(2,1) ]);
class myFont
{
  inherit Font;
  static string path;
  static int size, rsize;
  static array files;


  static string _sprintf()
  {
    return sprintf( "FontDir(%O,%d)", path, height() );
  }
  
  static string encode_char( string c )
  {
    int cc = c[0];
    if( (cc < 48) || (cc > 127) ) return sprintf( "0x%x", cc );
    return c;
  }

  static mapping(string:Image.Image) load_char( string c )
  {
    if( c[0] == 0x120 ) return smallspacechar;
    if(!files)
      files = get_dir( path ) - ({ "fontname" });

    array possible = ({ encode_char(c) })+
          glob(encode_char( c )+".*", files);
    sort( map(possible,strlen), possible );
    foreach( possible, string pf )
      if( mapping r = Image._load( path+pf ) )
        return r;
    if( c == " " ) return spacechar;
    return nullchar;
  }
  mapping(string:mapping(string:Image.Image)) char_cache = ([]);
  static mapping(string:Image.Image) write_char( string c )
  {
    if( char_cache[ c ] ) return char_cache[ c ];
    return char_cache[ c ] = load_char( c );
  }

  static Image.Image write_row( string text )
  {
    array(mapping(string:Image.Image)) res = map( text/"", write_char );
    
    Image.Image rr=Image.Image((int)abs(`+(0,@res->image->xsize())*x_spacing),
                               max(0,@res->image->ysize()));

    float start;
    if( x_spacing < 0 )  start = (float)rr->xsize()-res[0]->image->xsize();

    foreach( res, mapping(string:Image.Image) r )
    {
      if( !r->image ) continue;
      if( r->alpha )
        rr->paste_mask(r->image,r->alpha,
                       (int)start,rr->ysize()-r->image->ysize() );
      else
        rr->paste(r->image,(int)start,rr->ysize()-r->image->ysize());
      start += r->image->xsize()*x_spacing;
    }
    return rr;
  }

  int height()
  {
    return rsize ? rsize : (rsize = text_extents("0WjI|9")[1] );
  }

  Image.Image write( string ... what )
  {
    array(Image.Image) res = map( what, write_row );
    Image.Image rr = Image.Image( max(0,@res->xsize()),
                                  (int)abs(`+(0,@res->ysize())*y_spacing) );

    float start;
    if( y_spacing < 0 )  start = (float)rr->ysize()-res[0]->ysize();

    foreach( res, object r )
    {
      if( j_right )       rr->paste(r,rr->xsize()-r->xsize(),(int)start);
      else if( j_center ) rr->paste(r,(rr->xsize()-r->xsize())/2,(int)start);
      else                rr->paste( r, 0, (int)start );
      start += r->ysize()*y_spacing;
    }
    return rr;
  }

  array text_extents( string what )
  {
    Image.Image o = write( what );
    return ({ o->xsize(), o->ysize() });
  }

  void create( string _path, int _size )
  {
    path = _path;
    size = _size;
  }
}

mapping font_list;
static string font_name( string what )
{
  return (lower_case( replace(what," ","_") )/"\n")[0]-"\r";
}

void update_font_list()
{
  font_list = ([]);  
  foreach(roxen->query("font_dirs"), string dir)
    foreach( (get_dir( dir )||({})), string d )
      if( file_stat( dir+d )[ ST_SIZE ] == -2 ) // isdir
        if( file_stat( dir+d+"/fontname" ) )
          font_list[font_name(Stdio.read_bytes(dir+d+"/fontname"))]=dir+d+"/";
}

array available_fonts()
{
#ifdef THREADS
  object key = lock->lock();
#endif
  array res = ({});
  if( !font_list ) update_font_list();
  return indices( font_list );
}

array(mapping) font_information( string fnt )
{
#ifdef THREADS
  object key = lock->lock();
#endif
  if( !font_list ) update_font_list();
  if( font_list[ fnt ] )
    return ({ ([
      "name":fnt,
      "family":fnt,
      "path":font_list[fnt],
      "format":"imagedir",
    ])
   });
  return ({});
}

array has_font( string name, int size )
{
#ifdef THREADS
  object key = lock->lock();
#endif
  if( !font_list ) update_font_list();
  if( font_list[ name ] )
    return ({ "nn" });
}

Font open( string name, int size, int bold, int italic )
{
#ifdef THREADS
  object key = lock->lock();
#endif
  if( !font_list ) update_font_list();
  if( font_list[ name ] )
    return myFont( font_list[name], size );
}


void create()
{
  roxen.getvar( "font_dirs" )
      ->add_changed_callback( lambda(Variable.Variable v){
                                font_list = 0;
                              } );
}
