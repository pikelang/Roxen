#if constant(Image.FreeType.Face)
constant name = "FreeType fonts";
constant doc = "Freetype 2.0 font loader. Uses freetype to render text from, among other formats, TrueType, OpenType and Postscript Type1 fonts.";
constant scalable = 1;

inherit FontHandler;

static mapping ttf_font_names_cache;

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
  ttf_font_names_cache=([]);
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
          if(!ttf_font_names_cache[f])
            ttf_font_names_cache[f] = ([]);
          ttf_font_names_cache[f][ translate_ttf_style(n->style) ]
                                   = combine_path(dir+"/",fname);
        }
      }
    }
  };
  map( roxen->query("font_dirs"), traverse_font_dir );
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
    catch{ return face->write_char( c ); };
    return 0;
  }

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
      w += (int)(chars[i]->advance*x_spacing + kerning[i+1]);

    w += (int)(chars[-1]->img->xsize()+chars[-1]->x);
    ys = chars[0]->height;
			   
    res = Image.Image( w, ys );

    if( x_spacing < 0 )
      xp = w-(chars[0]->xsize+chars[0]->x);
  
    for( int i = 0; i<sizeof( chars); i++ )
    {
      mapping c = chars[i];
      res->paste_alpha_color( c->img, ({255,255,255}),
                              xp+c->x,
                              ys+c->descender-c->y );
      xp += (int)(c->advance*x_spacing) + kerning[i+1];
    }  
    return res;
  }

  int fake_bold, fake_italic;
  Image.Image write( string ... what )
  {
    object key = lock->lock();
    face->set_size( 0, size );
    if( !sizeof( what ) )
      return Image.Image( 1,height() );

    // nbsp -> ""
    what = map( (array(string))what, replace, " ", "" );

    if( encoder )
      what = Array.map(what, lambda(string s) {
                               return encoder->clear()->feed(s)->drain();
                             });
    
    array(Image.Image) res = map( what, write_row );

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
    if( fake_italic )
      rr = rr->skewx( rr->ysize()/3 );
    return rr;
  }

  static void create(object r, int s, string fn, int fb, int fi)
  {
    fake_bold = fb;
    fake_italic = fi;
    string encoding, fn2;
    face = r; size = s;

    if( (fn2 = replace( fn, ".pfa", ".afm" )) != fn && r_file_stat( fn2 ) )
      catch(face->attach_file( replace( fn, ".pfa", ".afm" ) ));

    
    if(r_file_stat(fn+".properties"))
      parse_html(lopen(fn+".properties","r")->read(), ([]),
                 (["encoding":lambda(string tag, mapping m, string enc) {
                                encoding = enc;
                              }]));

    if(encoding)
      encoder = Locale.Charset.encoder(encoding, "");
  }
}

array available_fonts()
{
#ifdef THREADS
  object key = lock->lock();
#endif
  if( !ttf_font_names_cache  ) build_font_names_cache( );
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

  werror("open %s %d %d %d (%s)\n\n", f, size, bold, italic, style);
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
