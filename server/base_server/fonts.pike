// This file is part of Roxen WebServer.
// Copyright © 1996 - 2000, Roxen IS.
// $Id: fonts.pike,v 1.62 2000/09/04 07:29:04 per Exp $

#include <module_constants.h>
#include <module.h>

class Font
{
  static int j_right, j_center;
  static float x_spacing=1.0, y_spacing=1.0;

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
  
  void set_x_spacing( float delta )
  //! Multiply real char spacing with this value for each character.
  {
    x_spacing = delta;
  }

  void set_y_spacing( float delta )
  //! Multiply real row spacing with this value.
  {
    y_spacing = delta;
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

  array(string) available_fonts( );
  //! return a list of all valid font names
  
  mapping(string:mixed) font_information( string font );
  //! return a mapping with information about the specified font

  static int|string font_style( string name, int size, int bold, int italic )
  {
    if( r_file_stat( name ) )
      return -1;

    string base_dir, dir;
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


  static string make_font_name(string name, int size, int bold, int italic)
  {
    mixed style = font_style( name, size, bold, italic );
    if( style == -1 ) return name;
    return name+"/"+style;
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

object get_font(string f, int size, int bold, int italic,
                string justification, float xspace, float yspace)
{
  object fnt;

  foreach( font_handlers, FontHandler fh )
    if(fnt = fh->open(f,size,bold,italic))
    {
      if(justification=="right") fnt->right();
      if(justification=="center") fnt->center();
      fnt->set_x_spacing((100.0+(float)xspace)/100.0);
      fnt->set_y_spacing((100.0+(float)yspace)/100.0);
      return fnt;
    }

  if( search( f, "_" ) != -1 )
    return get_font(f-"_", size, bold, italic, justification, xspace, yspace);
  if( search( f, " " ) != -1 )
    return get_font(replace(f," ", "_"), 
                    size, bold, italic, justification, xspace, yspace );

  if( roxen->query("default_font") == f )
  {
    report_error("Failed to load the default font\n");
    return 0;
  }
  return get_font(roxen->query("default_font"),
                  size,bold,italic,justification,xspace,yspace);
}

object resolve_font(string f, string|void justification)
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
  string nf;
  if( sscanf(f, "%s %d", nf, size) == 2 )
    f = nf;
  object fn;
  fn = get_font(f, size, bold, italic,
	      justification||"left",xspace, 0.0);
  if(!fn)
    fn = get_font(roxen->query("default_font"),size,bold,italic,
		  justification||"left",xspace, 0.0);
  if(!fn)
    report_error("failed miserably to open the default font ("+
                 roxen->query("default_font")+")\n");
  return fn;
}

array available_fonts( )
{
  return sort(`+( ({}),  @font_handlers->available_fonts() ));
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

void create()
{
  add_constant( "FontHandler", FontHandler );
  add_constant( "Font", Font );
  add_constant("get_font", get_font);
  add_constant("available_font_versions", available_font_versions);
  add_constant("describe_font_type", describe_font_type);
  add_constant("resolve_font", resolve_font);
  add_constant("available_fonts", available_fonts);


  int h = gethrtime();
  werror("Loading font handlers ...\n" );
  foreach( r_get_dir( "font_handlers" ), string fh )
  {
    catch {
      if( has_value( fh, ".pike" ) && fh[-1] == 'e' )
      {
        FontHandler f = ((program)( roxen_path( "font_handlers/"+fh ) ))( );
        roxen.dump( roxen_path( "font_handlers/"+fh ) );
        werror("    "+f->name+" ("+(f->scalable?"scalable":"bitmap")+")\n");
        if( f->scalable )
          font_handlers = ({ f }) + font_handlers;
        else
          font_handlers += ({ f });
      }
    };
  }
  werror("Done [%.1fms]\n", (gethrtime()-h)/1000.0 );
}
