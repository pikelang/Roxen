// This file is part of ChiliMoon.
// Copyright © 2000 - 2001, Roxen IS.

#include <config.h>
#if constant(Image.FreeType.Face)
inherit "freetype";
#else
inherit "ttf";
#endif

#if constant(__rbf) && constant(grbf)
#define rbuiltin
#endif

constant cvs_version = "$Id: builtin.pike,v 1.17 2002/10/25 23:55:13 nilsson Exp $";

constant name = "Builtin fonts";
constant doc =  "Fonts included in pike (and roxen)";

inherit FontHandler;

array available_fonts()
{
  return ({ "pike builtin",
#ifdef rbuiltin
	    "roxen builtin"
#endif
  });
}

array(mapping) font_information( string fnt )
{
  switch( replace(lower_case(fnt)," ","_")-"_" )
  {
#ifdef rbuiltin
   case "roxenbuiltin":
     return ({
              ([
                "name":"roxen builtin",
                "family":"Roxen builtin font",
                "path":"-",
                "style":"normal",
                "format":"scalable vector font",
              ])
            });
#endif
   case "pikebuiltin":
     return ({
              ([
                "name":"pike builtin",
                "family":"Pike builtin font",
                "path":"-",
                "style":"normal",
                "format":"bitmap dump",
              ])
            });
  }
}

array has_font( string name, int size )
{
  switch( replace(lower_case(name)," ","_")-"_" )
  {
   case "pikebuiltin":
     return ({ "nn" });
#ifdef rbuiltin
   case "roxenbuiltin":
     return ({ "nn", "bn", "bi" });
#endif
  }
  return 0;
}
object roxenbuiltin;
#ifdef THREADS
Thread.Mutex lock = Thread.Mutex();
#endif

Font open( string name, int size, int bold, int italic )
{
  switch( replace(lower_case(name)," ","_")-"_" )
  {
#ifdef rbuiltin
   case "roxenbuiltin":
#ifdef THREADS
     object key = lock->lock();
#endif
     if( !roxenbuiltin )
       if( mixed err = catch(roxenbuiltin = grbf()) )
#ifdef DEBUG
	 werror("Failed to open builtin font: %s\n",
		describe_backtrace( err ) );
#else
         ;
#endif
     if( roxenbuiltin )
#if constant(Image.FreeType.Face)
       return FTFont( roxenbuiltin, size,"-", bold, italic );
#else
       return TTFWrapper( roxenbuiltin(), size, "-", bold, italic);
#endif
#endif // rbuiltin
   case "pikebuiltin":
     return Image.Font();
  }
}
