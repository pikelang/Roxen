// This file is part of Roxen WebServer.
// Copyright © 1996 - 2000, Roxen IS.

#include <config.h>
constant cvs_version = "$Id: old.pike,v 1.11 2001/08/29 18:42:29 nilsson Exp $";

constant name = "Compatibility bitmap fonts";
constant doc = 
"Compatibility (bitmapped) fonts for Roxen 1.3 and earlier."
" Compact image file fonts are preferable to this format, since they are "
"almost always smaller, and easier to create.";

inherit FontHandler;

array available_fonts()
{
  array res = ({});
  foreach(roxen->query("font_dirs"), string dir)
  {
    dir+="32/";
    if(array d = r_get_dir(dir))
    {
      foreach(d,string f)
      {
        if(f=="CVS") continue;
        Stat a;
        if((a=r_file_stat(dir+f)) && (a[1]==-2)) 
        {
	  array d=r_get_dir(dir+f);
	  foreach( ({ "nn", "ni", "li", "ln", "Bi", "Bn", "bi", "bn" }),
		   string style)
	    if(has_value(d, style)) 
            {
              res |= ({ replace(f,"_", " ") });
              break;
            }
        }
      }
    }
  }
  return res;
}

array(mapping) font_information( string fnt )
{
  string ofnt = fnt;
  fnt = replace(lower_case( fnt ), " ", "_");
  array font_infos=({});
  foreach(roxen->query("font_dirs"), string dir)
  {
    dir+="32/";
    if( r_file_stat( dir+fnt ) )
    // the font file exists in this dir..
    {
      array d = r_get_dir(dir+fnt);
      foreach( ({ "nn", "ni", "li", "ln", "Bi", "Bn", "bi", "bn" }),
               string style)
        if(has_value(d, style)) 
        {
	  mapping font_info = ([ "name":fnt,
				 "family":ofnt,
				 "path":dir+fnt,
                                 "style":"",
				 "format":"bitmap dump" ]);
	  switch(style[0]) {
	  case 'l': font_info->style+="light"; break;
	  case 'b': font_info->style+="bold"; break;
	  case 'B': font_info->style+="black"; break;
	  }
	  if(style[1]=='i') font_info->style+="italic";
	  if(style[1]=='I') font_info->style+="oblique";
	  font_infos+=({ font_info });
        }
    }
  }
  return font_infos;
}

string fix_name( string what )
{
  return replace( lower_case(what), " ", "_" );
}

array has_font( string name, int size )
{
  string base_dir;
  array available, fallback_available;
  if( String.width( name ) > 8 )
    return 0;
  foreach(roxen->query("font_dirs"), string dir)
  {
    base_dir = dir+size+"/"+fix_name(name);
    if (available = r_get_dir(base_dir))
      break;
    if (!fallback_available) {
      base_dir=dir+"/32/"+fix_name(name);
      fallback_available = r_get_dir(base_dir);
    }
  }
  if(!available && !fallback_available) return 0;
  return (available ? available : fallback_available) - ({ "CVS" });
}

class MyFont {
  inherit Image.Font;

  void set_x_spacing(int|float delta) {
    if(intp(delta))
      ::set_x_spacing( (100.0+delta)/100.0 );
    else
      ::set_x_spacing( delta );
  }

  void set_y_spacing(int|float delta) {
    if(intp(delta))
      ::set_y_spacing( (100.0+delta)/100.0 );
    else
      ::set_y_spacing( (float)delta );
  }

  string _sprintf() {
    return sprintf( "OldFont" );
  }

}

Font open( string name, int size, int bold, int italic )
{
  if( String.width( name ) > 8 )
    return 0;
  string f = make_font_name( name, size, bold, italic );
  Image.Font fn = MyFont();
  foreach( roxen->query( "font_dirs"), string dir )
    foreach( ({ size, 32 }), int sz )
    {
      if( r_file_stat( dir+"/"+sz+"/"+f ) )
      {
        if( fn->load( roxen_path( dir+"/"+sz+"/"+f ) ) )
          return fn;
      }
    }
}
