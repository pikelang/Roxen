#include <config.h>
#if constant(Image.FreeType.Face)
inherit "freetype";
#else
inherit "ttf";
#endif
constant cvs_version = "$Id: builtin.pike,v 1.7 2000/12/11 12:49:58 per Exp $";

constant name = "Builtin fonts";
constant doc =  "Fonts included in pike (and roxen)";

inherit FontHandler;

array available_fonts()
{
  return ({ "pike builtin", "roxen builtin" });
}

array(mapping) font_information( string fnt )
{
  switch( replace(lower_case(fnt)," ","_")-"_" )
  {
   case "roxenbuiltin":
#if constant(__rbf) && constant(grbf)
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
   case "roxenbuiltin":
     return ({ "nn" });
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
   case "roxenbuiltin":
#if constant(__rbf) && constant(grbf)
     object key = lock->lock();
#if constant(Image.FreeType.Face)
     if( !roxenbuiltin ) catch(roxenbuiltin = grbf());
     if( roxenbuiltin )  return FTFont( roxenbuiltin, size, "-" );
#else
     if( !roxenbuiltin ) catch(roxenbuiltin = grbf());
     if( roxenbuiltin )  return TTFWrapper( roxenbuiltin(), size, "-" );
#endif
#endif
   case "pikebuiltin":
     return Image.Font();
  }
}
