// This file is part of Roxen WebServer.
// Copyright © 1996 - 2009, Roxen IS.

#include <config.h>
constant cvs_version = "$Id$";

constant name = "Compatibility bitmap fonts";
constant doc = 
"Compatibility (bitmapped) fonts for Roxen 1.3 and earlier."
" Compact image file fonts are preferable to this format, since they are "
"almost always smaller, and easier to create.";

inherit FontHandler;

Thread.Mutex lock = Thread.Mutex();

protected mapping font_cache;

protected void build_font_cache()
{
  mapping res = ([ ]);
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
	      res["32/" + f + "/" + style] = replace(f, "_", " ");
            }
        }
      }
    }
  }
  font_cache = res;
}

array available_fonts(int(0..1)|void force_reload)
{
  Thread.MutexKey key = lock->lock();
  if (!font_cache || force_reload)
    build_font_cache();
  return Array.uniq(values(font_cache));
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
  array available;
  if( String.width( name ) > 8 )
    return 0;

  Thread.MutexKey key = lock->lock();
  if (!font_cache)
    build_font_cache();

  string match_prefix = size + "/" + fix_name(name) + "/";
  array matches = filter(indices(font_cache), has_prefix, match_prefix);
  if (sizeof(matches))
    return map(matches, `[], sizeof(match_prefix), 99999);
  
  if (size != 32) {
    foreach(roxen->query("font_dirs"), string dir) {
      string key = size + "/" + fix_name(name);
      base_dir = dir + key;
      if (available = r_get_dir(base_dir)) {
	foreach(available - ({ "CVS" }), string style)
	  font_cache[key + "/" + style] = name;
	return available;
      }
    }
    key = 0;
    return has_font(name, 32);
  }
  return 0;
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
