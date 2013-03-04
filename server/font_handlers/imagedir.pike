// This file is part of Roxen WebServer.
// Copyright © 2000 - 2009, Roxen IS.

#include <config.h>
#include <stat.h>
constant cvs_version = "$Id$";

constant name = "Image directory fonts";
constant doc = ("Handles a directory with images (in almost any format), each "
                "named after the character they will represent. Characters "
                "with codes larger than 127 or less than 48 are encoded like "
                "0xHEX where HEX is the code in hexadecimal. There must be a "
                "file named 'fontname' in the directory, the first line of "
                "that file is used as the name of the font");

inherit FontHandler;

#ifdef THREADS
Thread.Mutex lock = Thread.Mutex();
#endif

protected mapping nullchar = ([ "image":Image.Image(1,1),
				"alpha":Image.Image(1,1) ]);
protected mapping spacechar = ([ "image":Image.Image(10,1),
				 "alpha":Image.Image(10,1) ]);
protected mapping smallspacechar = ([ "image":Image.Image(2,1),
				      "alpha":Image.Image(2,1) ]);
class myFont
{
  inherit Font;
  protected string path;
  protected int size, rsize;
  protected array files;

  string _sprintf()
  {
    return sprintf( "FontDir(%O,%d)", path, height() );
  }
  
  protected string encode_char( string c )
  {
    int cc = c[0];
    if( (cc < 48) || (cc > 127) ) return sprintf( "0x%x", cc );
    return c;
  }

  protected mapping(string:Image.Image) load_char( string c )
  {
    if( c[0] == 0x120 ) return smallspacechar;
    if(!files)
      files = get_dir( path ) - ({ "fontname" });

    array possible = ({ encode_char(c) })+
          glob(encode_char( c )+".*", files);
    sort( map(possible,strlen), possible );
    catch {
      foreach( possible, string pf )
        if( mapping r = Image._load( path+pf ) )
          return r;
    };
    if( c == " " ) return spacechar;
    return nullchar;
  }
  mapping(string:mapping(string:Image.Image)) char_cache = ([]);
  protected mapping(string:Image.Image) write_char( string c )
  {
    if( char_cache[ c ] ) return char_cache[ c ];
    return char_cache[ c ] = load_char( c );
  }

  protected Image.Image write_row( string text )
  {
    array(mapping(string:Image.Image)) res = map( text/"", write_char );
    
    Image.Image rr;
    if(floatp(x_spacing))
      rr=Image.Image((int)abs(`+(0,@res->image->xsize())*x_spacing),
		     max(0,@res->image->ysize()));
    else
      rr=Image.Image(abs(`+(0,@res->image->xsize())+(sizeof(res)*x_spacing)),
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
      if(floatp(x_spacing))
	start += r->image->xsize()*x_spacing;
      else
	start += r->image->xsize()+x_spacing;
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
    Image.Image rr;
    if(floatp(y_spacing))
      rr = Image.Image( max(0,@res->xsize()),
			(int)abs(`+(0,@res->ysize())*y_spacing) );
    else
      rr = Image.Image( max(0,@res->xsize()),
    			abs(`+(0,@res->ysize())+(sizeof(res)*y_spacing)) );

    float start;
    if( y_spacing < 0 )  start = (float)rr->ysize()-res[0]->ysize();

    foreach( res, object r )
    {
      if( j_right )       rr->paste(r,rr->xsize()-r->xsize(),(int)start);
      else if( j_center ) rr->paste(r,(rr->xsize()-r->xsize())/2,(int)start);
      else                rr->paste( r, 0, (int)start );
      if(floatp(y_spacing))
	start += r->ysize()*y_spacing;
      else
	start += r->ysize()+y_spacing;
    }
    return rr;
  }

  array text_extents( string what )
  {
    Image.Image o = write( what );
    return ({ o->xsize(), o->ysize() });
  }

  void set_x_spacing( int|float value ) {
    if(value!=1.0) ::set_x_spacing(value);
  }

  void set_y_spacing( int|float value ) {
    if(value!=1.0) ::set_y_spacing(value);
  }

  void create( string _path, int _size, int xpad, int ypad )
  {
    path = _path;
    size = _size;
    x_spacing = xpad;
    y_spacing = ypad;
  }
}

mapping font_list;
mapping meta_data;
protected string font_name( string what )
{
  if(!meta_data) meta_data=([]);
  mapping _meta_data=([]);
  Parser.HTML()->
    add_containers( ([ "name":lambda(string t, mapping m, string c) {
				what=c; return ""; },
		       "meta":lambda(string t, mapping m, string c) {
				_meta_data[m->name]=c; },
		       "xpad":lambda(string t, mapping m, string c) {
				_meta_data->xpad = (int)c; },
		       "ypad":lambda(string t, mapping m, string c) {
				_meta_data->ypad = (int)c; },
    ]) )->finish(what);

  what=(lower_case( replace(what," ","_") )/"\n")[0]-"\r";
  if(sizeof(_meta_data)) meta_data[what]=_meta_data;
  return what;
}

void update_font_list()
{
  font_list = ([]);  
  foreach(roxen->query("font_dirs"), string dir) {
    dir = roxen_path (dir);
    foreach( (get_dir( dir )||({})), string d ) {
      string fpath = combine_path(dir, d);
      if( Stdio.is_dir( fpath ) ) {
        if( file_stat( fpath + "/fontinfo" ) )
          font_list[font_name(Stdio.read_bytes(fpath+"/fontinfo"))]=fpath+"/";
        else if( file_stat( fpath+"/fontname" ) )
          font_list[font_name(Stdio.read_bytes(fpath+"/fontname"))]=fpath+"/";
      }
    }
  }
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
    return ({ (meta_data[fnt] || ([])) | ([
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
  int xpad,ypad;
  if(meta_data && meta_data[name]) {
    xpad = meta_data[name]->xpad;
    ypad = meta_data[name]->ypad;
  }
  if( font_list[ name ] )
    return myFont( font_list[name], size,
		   xpad, ypad );
}


void create()
{
  roxen.getvar( "font_dirs" )
      ->add_changed_callback( lambda(Variable.Variable v){
                                font_list = 0;
                              } );
}
