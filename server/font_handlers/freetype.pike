// This file is part of Roxen WebServer.
// Copyright © 2000 - 2001, Roxen IS.

#if constant(Image.FreeType.Face)
constant name = "FreeType fonts";
constant doc = "Freetype 2.0 font loader. Uses freetype to render text from, among other formats, TrueType, OpenType and Postscript Type1 fonts.";
constant scalable = 1;

inherit FontHandler;

static mapping ttf_font_names_cache;

static string translate_ttf_style( string style )
{
  //  Check for weight. Default is "n" for normal/regular/roman.
  style = lower_case((style - "-") - " ");
  string weight = "n"; 
  if (has_value(style, "bold"))
    weight = "b";
  else if (has_value(style, "black"))
    weight = "B";
  else if (has_value(style, "light"))
    weight = "l";
  
  //  Check for slant. Default is "n" for regular.
  string slant = "n";
  if (has_value(style, "italic") ||
      has_value(style, "oblique"))
    slant = "i";

  //  Combine to full style
  return weight + slant;
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
        Image.FreeType.Face ttf;
        if(catch(ttf = Image.FreeType.Face( combine_path(dir+"/",fname) )))
          continue;
        if(ttf)
        {
          mapping n = ttf->info();
          string f = lower_case(n->family);
          if(!new_ttf_font_names_cache[f])
            new_ttf_font_names_cache[f] = ([]);
          new_ttf_font_names_cache[f][ translate_ttf_style(n->style) ]
                                   = combine_path(dir+"/",fname);
        }
      }
    }
  };
  map( roxen->query("font_dirs"), traverse_font_dir );

  ttf_font_names_cache = new_ttf_font_names_cache;
}

Thread.Mutex lock = Thread.Mutex();

class FTFont
{
  inherit Font;
  static int size;
  static Image.FreeType.Face face;
  static object encoder;

  array text_extents( string what )
  {
    Image.Image o = write( what );
    return ({ o->xsize(), o->ysize() });
  }
  
  int height( )
  {
    return size;
  }

  static mixed do_write_char( int c )
  {
    if (mixed err = catch{ return face->write_char( c ); })
      werror (describe_error (err));
    return 0;
  }

  static int line_height;
  static Image.Image write_row( string text )
  {
    Image.Image res;
    int xp, ys;
    if( !strlen( text ) )
      text = " ";
    array(int) tx = (array(int))text;
    array chars = map( tx, do_write_char );
    int i;

    for( i = 0; i<sizeof( chars ); i++ )
      if( !chars[i] )
	tx[ i ] = 0;
      else if( !tx[i] )
	tx[ i ] = 20;

    tx  -= ({ 0 });
    chars  -= ({ 0 });
    
    if( !sizeof( chars ) )
      return Image.Image(1,1);

    int oc;
    array kerning = ({});
    foreach( tx, int c  )
    {
      if( oc )
        kerning += ({ face->get_kerning( oc, c )>>6 });
      else
        kerning += ({ 0 });
      oc = c;
    }
    kerning += ({ 0 });
    int w;

    for(int i = 0; i<sizeof(chars)-1; i++ )
      w += (int)(chars[i]->advance*x_spacing + kerning[i+1])+(fake_bold>0?1:0);

    w += (int)(chars[-1]->img->xsize()+chars[-1]->x);
    
    ys = chars[0]->ascender-chars[0]->descender;
    line_height = (int)chars[0]->height;
			   
    res = Image.Image( w, ys );

    if( x_spacing < 0 )
      xp = w-(chars[0]->xsize+chars[0]->x);

#ifdef FREETYPE_RENDER_DEBUG
    res->setcolor( 0,128,200 );
    res->line( 0,0, res->xsize()-1, 0 );
    res->line( 0,ys+chars[0]->descender, res->xsize()-1,
	       ys+chars[0]->descender );
    res->line( 0,res->ysize()-1, res->xsize()-1, res->ysize()-1 );
#endif
    for( int i = 0; i<sizeof( chars); i++ )
    {
      mapping c = chars[i];
#ifdef FREETYPE_RENDER_DEBUG
       res->paste_alpha_color( c->img->copy()->clear( 100,100,100 ),
 			      ({255,255,255}),
 			      xp+c->x,
 			      ys+c->descender-c->y );
#endif
      res->paste_alpha_color( c->img, ({255,255,255}),
                              xp+c->x,
                              ys+c->descender-c->y );
      xp += (int)(c->advance*x_spacing) + kerning[i+1]+(fake_bold>0?1:0);
    }  
    return res;
  }

  int fake_bold, fake_italic;
  Image.Image write( string ... what )
  {
    object key = lock->lock();
    int oversample = roxen->query("font_oversampling");
    if (oversample)
      face->set_size( 0, size * 2);
    else
      face->set_size( 0, size );
    if( !sizeof( what ) )
      return Image.Image( 1,height() );

    // nbsp -> ""
    what = map( (array(string))what, replace, "\240", "" );

    if( encoder )
      what = Array.map(what, lambda(string s) {
                               return encoder->clear()->feed(s)->drain();
                             });
    
    array(Image.Image) res = map( what, write_row );

    int image_width = max(0, @res->xsize());
    int image_height = (int)(res[0]->ysize() +
			     abs(line_height * (sizeof(res) - 1) * y_spacing));
    int y_add = 0;
    if (oversample) {
      //  Make sure image dimensions are a multiple of 2. If height is odd
      //  we'll offset the text baseline one pixel to get the extra line at
      //  the top of the image.
      image_width = (image_width + 1) & 0xFFFFFFFE;
      y_add = (image_height & 1);
      image_height = (image_height + 1) & 0xFFFFFFFE;
    }
    Image.Image rr = Image.Image(image_width, image_height);

    float start;
    if( y_spacing < 0 )
      start = (float)rr->ysize()-res[0]->ysize();
    start += (float) y_add;
    
    foreach( res, object r )
    {
      if( j_right )
        rr->paste_alpha_color( r, 255,255,255, rr->xsize()-r->xsize(), (int)start );
      else if( j_center )
        rr->paste_alpha_color( r, 255,255,255,(rr->xsize()-r->xsize())/2, (int)start );
      else
        rr->paste_alpha_color( r, 255,255,255, 0, (int)start );
      start += floatp(y_spacing)?line_height*y_spacing:line_height+y_spacing;
    }
    if( fake_bold > 0 )
    {
      object r2 = Image.Image( rr->xsize()+2, rr->ysize() );
      object r3 = rr*0.3;
      for( int i = 0; i<=fake_bold; i++ )
	for( int j = 0; j<=fake_bold; j++ )
	  r2->paste_alpha_color( r3,  255, 255, 255, i, j-2 );
      rr = r2->paste_alpha_color( rr, 255,255,255, 1, -1 );
    }
    rr->setcolor( 0,0,0 );
    if( fake_italic )
      rr = rr->skewx( -(rr->ysize()/3) );
    if (oversample)
      return rr->scale(0.5);
    else
      return rr;
  }

  string _sprintf() {
    return "Freetype";
  }

  static void create(object r, int s, string fn, int fb, int fi)
  {
    fake_bold = fb;
    fake_italic = fi;
    string encoding, fn2;
    face = r; size = s;

    if( (fn2 = replace( fn, ".pfa", ".afm" )) != fn && r_file_stat( fn2 ) )
      catch(face->attach_file( fn2 ));

    
    if(r_file_stat(fn+".properties"))
      parse_html(lopen(fn+".properties","r")->read(), ([]),
                 (["encoding":lambda(string tag, mapping m, string enc) {
                                encoding = enc;
                              }]));

    if(encoding)
      encoder = Locale.Charset.encoder(encoding, "");
  }
}

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
    "format":"freetype",
  ]);
  catch {
  Image.FreeType.Face f;
  if( font[0] == '/' )
    f = Image.FreeType.Face( font );
  else
    f = Image.FreeType.Face( (font=values(ttf_font_names_cache[ font ])[0]) );

  res->path = font;
  res |= f->info();
  };
  return ({ res });
}

array(string) has_font( string name, int size )
{
#ifdef THREADS
  object key = lock->lock();
#endif
  if( !ttf_font_names_cache  )
    build_font_names_cache( );
  if( ttf_font_names_cache[ name ] )
    return indices(ttf_font_names_cache[ name ]);
}

Image.FreeType.Face last;
string last_file;

Image.FreeType.Face open_face( string file )
{
  if( file == last_file )
    return last;
  last_file = file;
  return last = Image.FreeType.Face( file );
}
Font open(string f, int size, int bold, int italic )
{
  string tmp;
  int|string style = font_style( f, size, bold, italic );
  object fo;

  if( style == -1 ) // exact file
  {
    if( fo = Image.FreeType.Face( name ) )
      return FTFont( fo, size, f,0,0 );
    return 0;
  }

  if(ttf_font_names_cache[ lower_case(f) ])
  {
    f = lower_case(f);
    if( tmp = ttf_font_names_cache[ f ][ style ] )
    {
      fo = open_face( tmp );
      if( fo ) return FTFont( fo, size, tmp,0,0 );
    }
    if(fo=open_face( roxen_path(f=values(ttf_font_names_cache[ f ])[0])))
      return FTFont( fo, size, f, bold, italic );
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
