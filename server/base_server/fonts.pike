// This file is part of Roxen WebServer.
// Copyright © 1996 - 2009, Roxen IS.
// $Id$

#include <module_constants.h>
#include <module.h>

//!
class Font
{
  protected int j_right, j_center;
  protected float|int x_spacing=1.0, y_spacing=1.0;

  Image.Image write( string ... what );
  //! non-breakable spaces in any of the strings in 'what' is to be
  //! considered as width("m")/64 spaces wide characters instead of 
  //! full-width spaces.

  array(int) text_extents( string ... what );
  //! return ({ xsize, ysize }) of the string

  int height();
  //! returns the height of one row of text. Should be more or less equal 
  //! to the size specified to open.

  void right()
  //! Right justify
  {
    j_right = 1;
    j_center=0;
  }

  void left()
  //! Left justify
  {
    j_right = j_center = 0;
  }

  void center()
  //! Center in image
  {
    j_center = 1;
    j_right = 0;
  }
  
  void set_x_spacing( float|int delta )
  //! Multiply real char spacing with this value for each character.
  {
    x_spacing = delta;
  }

  void set_y_spacing( float|int delta )
  //! Multiply real row spacing with this value.
  {
    y_spacing = delta;
  }

  optional string _sprintf() {
    return "Font";
  }
}

class FontHandler
//! A fontname -> font object resolver.
{
  int has_font( string name, int size );
  //! Return true if the font (with the specified size) 
  //! exists in this namespace.

  Font open( string name, 
             int size,
             int bold,
             int italic );
  //! Open a new font object

  void flush_caches();
  //! Flush all memory caches that are used to save some memory

  array(string) available_fonts(int(0..1)|void force_reload);
  //! return a list of all valid font names
  
  array(mapping(string:mixed)) font_information( string font );
  //! return a mapping with information about the specified font

  protected int|string font_style( string name, int size, int bold, int italic )
  {
    if( r_file_stat( name ) )
      return -1;

    mixed available = has_font( name, size );

    if(!available) 
      return 0;
    available = mkmultiset(available);

    string bc = (bold>=0?(bold==2?"B":(bold==1?"b":"n")):"l"), 
           ic = (italic?"i":"n");

    if(available[bc+ic]) return bc+ic;
    if(bc=="l")  bc="n";
    if(available[bc+ic]) return bc+ic;
    if(bc=="B") bc="b";
    if(available[bc+ic]) return bc+ic;
    if(bc=="b") bc="n";
    if(available[bc+ic]) return bc+ic;
    if(ic=="i") ic="n";
    if(available[bc+ic]) return bc+ic;

    foreach(({ "n","l","b", "B", }), bc)
      foreach(({ "n", "i" }), ic)
        if(available[bc+ic])
          return bc+ic;
  }

  protected string make_font_name(string name, int size, int bold, int italic)
  {
    mixed style = font_style( name, size, bold, italic );
    if( style == -1 ) return name;
    return name+"/"+style;
  }

  string _sprintf() {
    return "FontHandler";
  }
}



array(FontHandler) font_handlers = ({});


array available_font_versions(string name, int size)
{
  array res = ({});
  foreach( font_handlers, FontHandler a )
  {
    mixed hh = a->has_font( name, size );
    if( hh ) res |= hh;
  }
  if( sizeof( res ) )
    return res;
}

string describe_font_type(string n)
{
  string res;
  if(n[1]=='i') res = "italic";
  else res="";

  switch(n[0])
  {
   case 'n': if(!strlen(res)) res="normal"; break;
   case 'B': res+=" black";  break;
   case 'b': res+=" bold";  break;
   case 'l': res+=" light";  break;
  }
  return res;
}

protected Font get_font_3(string f, int size, int bold, int italic)
{
  Font fnt;
  foreach( font_handlers, FontHandler fh )
    if( fh->has_font( f,size ) &&
	(fnt = fh->open(f,size,bold,italic)))
      return fnt;
  return 0;
}

protected Font get_font_2(string f, int size, int bold, int italic)
{
  if (Font fnt = get_font_3 (f, size, bold, italic))
    return fnt;

  if( has_value( f, "_" ) ) {
    string f2 = f - "_";
    if (Font fnt = get_font_3 (f2, size, bold, italic))
      return fnt;
    if( has_value( f2, " " ) ) {
      // The old code tested this as a side effect of the tail
      // recursion thingies, but I doubt it was really intended. Keep
      // it to avoid compatibility trouble (although that's unlikely).
      f2 = replace (f2, " ", "_");
      if (Font fnt = get_font_3 (f2, size, bold, italic))
	return fnt;
    }
  }

  if( has_value( f, " " ) ) {
    f = replace (f, " ", "_");
    if (Font fnt = get_font_3 (f, size, bold, italic))
      return fnt;
    return get_font_3 (f - "_", size, bold, italic);
  }

  return 0;
}

Font get_font(string f, int size, int bold, int italic,
	      string justification, float|int xspace, float|int yspace)
{
  f = lower_case( f );
  Font fnt = get_font_2 (f, size, bold, italic);
  if (!fnt) {
    fnt = get_font_2 (roxen->query ("default_font"), size, bold, italic);
    if (!fnt) {
      report_error("Failed to load the default font (%O)\n",
		   roxen->query("default_font"));
      return 0;
    }
  }

  if(justification=="right") fnt->right();
  else if(justification=="center") fnt->center();

  if(floatp(xspace))
    fnt->set_x_spacing((100.0+xspace)/100.0);
  else
    fnt->set_x_spacing(xspace);

  if(floatp(yspace))
    fnt->set_y_spacing((100.0+yspace)/100.0);
  else
    fnt->set_y_spacing(yspace);

  return fnt;
}

Font resolve_font(string f, string|void justification)
{
  int bold, italic;
  float xspace=0.0;
  string a,b;
  if( !f )
    f = roxen->query("default_font");
  f = lower_case( f );
  if(sscanf(f, "%s bold%s", a,b)==2)
  {
    bold=1;
    f = a+" "+b;
  }
  if(sscanf(f, "%s normal%s", a,b)==2)
  {
    f = a+" "+b;
  }
  if(sscanf(f, "%s black%s", a,b)==2)
  {
    bold=2;
    f = a+" "+b;
  }
  if(sscanf(f, "%s light%s", a,b)==2)
  {
    bold=-1;
    f = a+" "+b;
  }
  if(sscanf(f, "%s italic%s", a,b)==2)
  {
    italic=1;
    f = a+" "+b;
  }
  if(sscanf(f, "%s slant%s", a,b)==2)
  {
    italic=-1;
    f = a+" "+b;
  }
  if(sscanf(f, "%s compressed%s", a,b)==2)
  {
    xspace = -20.0;
    f = a+" "+b;
  }
  if(sscanf(f, "%s spaced%s", a,b)==2)
  {
    xspace = 20.0;
    f = a+" "+b;
  }
  if(sscanf(f, "%s center%s", a, b)==2)
  {
    justification="center";
    f = a+" "+b;
  }
  if(sscanf(f, "%s right%s", a, b)==2)
  {
    justification="right";
    f = a+" "+b;
  }
  if(sscanf(f, "%s left%s", a, b)==2)
  {
    justification="left";
    f = a+" "+b;
  }

  int size=32;
  array q = f / " ";
  if( sizeof(q)>1 && (int)q[-1] )
  {
    size = (int)q[-1];
    f = (q[..sizeof(q)-2]-({""}))*" ";
  }

  return get_font(f, size, bold, italic,
		  justification||"left",xspace, 0.0);
}

protected string verify_font_3 (string font, int size)
{
  foreach( font_handlers, FontHandler fh )
    if( fh->has_font( font,size ) )
      return font;
  return 0;
}

protected string verify_font_2 (string font, int size)
{
  if (verify_font_3 (font, size)) return font;

  if( has_value( font, "_" ) ) {
    string f = font - "_";
    if (verify_font_3 (f, size)) return f;
    if( has_value( f, " " ) ) {
      // The old code tested this as a side effect of the tail
      // recursion thingies, but I doubt it was really intended. Keep
      // it to avoid compatibility trouble (although that's unlikely).
      f = replace (f, " ", "_");
      if (verify_font_3 (f, size)) return f;
    }
  }

  if( has_value( font, " " ) ) {
    string f = replace (font, " ", "_");
    if (verify_font_3 (f, size)) return f;
    f -= "_";
    if (verify_font_3 (f, size)) return f;
  }

  return 0;
}

//! Returns the real name of the resolved font.
string verify_font(string font, int size)
{
  if(!font)
    return verify_font(roxen->query("default_font"), size||32);

  font = lower_case( font );

  if(size) {
    if (string f = verify_font_2 (font, size)) return f;
    return verify_font_2 (roxen->query ("default_font"), size);
  }

  // Note that we'll never get here if size != 0. I suspect the
  // fallback to default_font should be delayed longer, but I don't
  // know for sure. /mast

  string a,b;
  foreach( ({ "bold", "normal", "black", "light", "italic", "slant",
	      "compressed", "spaced", "center", "right", "left" }), string mod)
    if(sscanf(font, "%s "+mod+"%s", a,b)==2)
      font = a+" "+b;

  size = 32;
  array q = font / " ";
  if( sizeof(q)>1 && (int)q[-1] ) {
    size = (int)q[-1];
    font = q[..sizeof(q)-2]*" ";
  }

  return verify_font(font, size);
}

array(string) available_fonts(int(0..1)|void force_reload )
{
  return sort(`+( ({}),  @font_handlers->available_fonts(force_reload) ));
}

array get_font_information(void|int scalable_only) 
{
  array res=({});

  foreach( font_handlers, FontHandler fh )
  {
    if( scalable_only && !fh->scalable )
      continue;
    foreach( fh->available_fonts(), string fontname)
      res += fh->font_information(fontname);
  }
  return res;
}

protected void create()
{
  int h = gethrtime();
  // Must have this _before_ the add_contant()s
  roxen.dump( "base_server/fonts.pike", object_program(this_object()) );
  add_constant( "FontHandler", FontHandler );
  add_constant( "Font", Font );
  add_constant("get_font", get_font);
  add_constant("available_font_versions", available_font_versions);
  add_constant("describe_font_type", describe_font_type);
  add_constant("resolve_font", resolve_font);
  add_constant("available_fonts", available_fonts);
  add_constant("roxen.fonts", this_object());
  report_debug("Loading font handlers ...\n" );
  foreach( r_get_dir( "font_handlers" ), string fh )
  {
    mixed err = catch {
      if(has_suffix(fh, ".pike"))
      {
        FontHandler f = ((program)( roxen_path( "font_handlers/"+fh ) ))( );
        roxen.dump( roxen_path( "font_handlers/"+fh ) );
        if( f->name && f->open )
        {
          report_debug("    "+f->name+" ("+(f->scalable?"scalable":"bitmap")+")\n");
          if( f->scalable )
            font_handlers = ({ f }) + font_handlers;
          else
            font_handlers += ({ f });
        }
      }
    };
    if (err) {
      report_error(sprintf("Failed to initialize font handler %s:\n"
			   "%s\n", fh, describe_backtrace(err)));
    }
  }
  report_debug("Done [%.1fms]\n", (gethrtime()-h)/1000.0 );
}
