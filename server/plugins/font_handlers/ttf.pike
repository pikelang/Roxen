// This file is part of Internet Server.
// Copyright © 1996 - 2000, Roxen IS.

#if !constant(Image.FreeType.Face)
#if constant(has_Image_TTF)
#include <config.h>
constant cvs_version = "$Id: ttf.pike,v 1.15 2002/09/26 22:15:13 nilsson Exp $";

constant name = "TTF fonts";
constant doc = "True Type font loader. Uses freetype to render text.";
constant scalable = 1;

inherit FontHandler;

static mapping ttf_font_names_cache;

static string trimttfname( string n )
{
  n = lower_case(replace( n, "\t", " " ));
  return ((n/" ")*"")-"'";
}

static string translate_ttf_style( string style )
{
  switch( lower_case( (style-"-")-" " ) )
  {
   case "normal": case "regular":        return "nn";
   case "italic":                        return "ni";
   case "oblique":                       return "ni";
   case "bold":                          return "bn";
   case "bolditalic":case "italicbold":  return "bi";
   case "black":                         return "Bn";
   case "blackitalic":case "italicblack":return "Bi";
   case "light":                         return "ln";
   case "lightitalic":case "italiclight":return "li";
  }
  if(search(lower_case(style), "oblique"))
    return "ni"; // for now.
  return "nn";
}

static void build_font_names_cache( )
{
  mapping ttf_done = ([ ]);
  mapping new_ttf_font_names_cache=([]);
  void traverse_font_dir( string dir ) 
  {
    foreach(r_get_dir( dir )||({}), string fname)
    {
      string path=combine_path(dir+"/",fname);
      if(!ttf_done[path]++)
      {
        Stat a=file_stat(path);
        if(a && a[1]==-2) {
          if( !file_stat( path+"/fontname" ) ) 
            // no, we do not want to try this dir. :-)
            traverse_font_dir( path );
          continue;
        }
        // Here is a good place to impose the artificial restraint that
        // the file must match *.ttf
        Image.TTF ttf;
        if(catch(ttf = Image.TTF( combine_path(dir+"/",fname) )))
          continue;
        if(ttf)
        {
          mapping n = ttf->names();
          string f = lower_case(trimttfname(n->family));
          if(!new_ttf_font_names_cache[f])
            new_ttf_font_names_cache[f] = ([]);
          new_ttf_font_names_cache[f][ translate_ttf_style(n->style) ] =
	    combine_path(dir+"/",fname);
        }
      }
    }
  };
  map( roxen->query("font_dirs"), traverse_font_dir );

  ttf_font_names_cache = new_ttf_font_names_cache;
}



class TTFWrapper
{
  inherit Font;
  static int size, rsize;
  static object real;
  static object encoder;
  static function(string ...:Image.image) real_write;
  static int fake_bold, fake_italic;

  int height( )
  {
    return rsize ? rsize : (rsize = text_extents("W")[1] );
  }

  static string _sprintf()
  {
    return sprintf( "TTF(%O,%d)", real, size );
  }

  static Image.image write_encoded(string ... what)
  {
    return real->write(@(encoder?
                         Array.map(what, lambda(string s) {
                                           return encoder->clear()->
                                                  feed(s)->drain();
                                         }):what));
  }

  // FIXME: Handle x_spacing
  Image.Image write( string ... what )
  {
    if( !sizeof( what ) )
      return Image.Image( 1,height() );

    // nbsp -> ""
    what = map( (array(string))what, replace, " ", "" );

    // cannot write "" with Image.TTF.
    what = replace( what, "", " " );

    array(Image.Image) res = map( what, real_write );

    Image.Image rr = Image.Image( max(0,@res->xsize()),
                                  (int)abs(`+(0,0,@res[..sizeof(res)-2]->ysize())*y_spacing)+res[-1]->ysize() );

    float start;
    if( y_spacing < 0 )
      start = (float)rr->ysize()-res[0]->ysize();

    foreach( res, object r )
    {
      if( j_right )
        rr->paste_alpha_color( r, 255,255,255, rr->xsize()-r->xsize(), (int)start );
      else if( j_center )
        rr->paste_alpha_color( r, 255,255,255,(rr->xsize()-r->xsize())/2, (int)start );
      else
        rr->paste_alpha_color( r, 255,255,255, 0, (int)start );
      start += r->ysize()*y_spacing;
    }
    if( fake_bold )
    {
      object r2 = Image.Image( rr->xsize()+2, rr->ysize() );
      object r3 = rr*0.3;
      for( int i = 0; i<2; i++ )
	for( int j = 0; j<2; j++ )
	  r2->paste_alpha_color( r3,  255, 255, 255, i, j );
      rr = r2->paste_alpha_color( rr, 255,255,255, 1,1 );
    }
    rr->setcolor( 0,0,0 );
    if( fake_italic )
      rr = rr->skewx( -(rr->ysize()/3) );
    if( roxen->query("font_oversampling") )
      return rr->scale(0.5);
    else
      return rr;
  }

  array text_extents( string what )
  {
    Image.Image o = write( what );
    return ({ o->xsize(), o->ysize() });
  }

  void create(object r, int s, string fn, int fb, int fi)
  {
    string encoding;
    fake_bold = fb;
    fake_italic = fi;
    real = r;
    size = s;
    if( roxen->query("font_oversampling") )
      real->set_height( (int)(size*64/34.5) ); // aproximate to pixels
    else
      real->set_height( (int)(size*32/34.5) ); // aproximate to pixels

    if(r_file_stat(fn+".properties"))
      parse_html(lopen(fn+".properties","r")->read(), ([]),
                 (["encoding":lambda(string tag, mapping m, string enc) {
                                encoding = enc;
                              }]));

    if(encoding)
      encoder = Locale.Charset.encoder(encoding, "");

    real_write = (encoder? write_encoded : real->write);
  }
}

#ifdef THREADS
Thread.Mutex lock = Thread.Mutex();
#endif

array available_fonts(int(0..1)|void force_reload)
{
#ifdef THREADS
  object key = lock->lock();
#endif
  if( !ttf_font_names_cache || force_reload ) build_font_names_cache( );
  return indices( ttf_font_names_cache );
}

array(mapping) font_information( string font )
{
  if( !has_font( font, 0 ) )
    return ({});

  mapping res = ([ 
    "name":font,
    "format":"ttf",
  ]);
  Image.TTF f;
  if( font[0] == '/' )
    f = Image.TTF( font );
  else
    f = Image.TTF( (font=values(ttf_font_names_cache[ font ])[0]) );

  res->path = font;
  res |= f->names();
  return ({ res });
}

array(string) has_font( string name, int size, int(0..1)|void force )
{
#ifdef THREADS
  object key = lock->lock();
#endif
  if( !ttf_font_names_cache  )
    build_font_names_cache( );
  if( ttf_font_names_cache[ name ] )
    return indices(ttf_font_names_cache[ name ]);
  if (force) {
    build_font_names_cache();
    if( ttf_font_names_cache[ name ] )
      return indices(ttf_font_names_cache[ name ]);
  }
}

Font open(string f, int size, int bold, int italic )
{
  string tmp;
  int|string style = font_style( f, size, bold, italic );
  object fo;

  if( style == -1 ) // exact file
  {
    if( fo = Image.TTF( name ) )
      return TTFWrapper( fo, size, f,0,0 );
    return 0;
  }

  if (!ttf_font_names_cache) {
    build_font_names_cache();
  }

  if(ttf_font_names_cache[ lower_case(f) ])
  {
    f = lower_case(f);
    if( tmp = ttf_font_names_cache[ f ][ style ] )
    {
      fo = Image.TTF( tmp );
      if( fo ) return TTFWrapper( fo(), size, tmp,0,0 );
    }
    if( fo = Image.TTF( roxen_path(f = values(ttf_font_names_cache[ f ])[0])))
      return TTFWrapper( fo(), size, f, bold, italic );
  }
  return 0;
}




void create()
{
  roxen.getvar( "font_dirs" )
      ->add_changed_callback( lambda(Variable.Variable v){
                                ttf_font_names_cache=0;
                              } );
}
#endif
#endif
