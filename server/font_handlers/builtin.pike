// This file is part of Roxen WebServer.
// Copyright © 2000 - 2009, Roxen IS.

#include <config.h>
#if constant(Image.FreeType.Face)
inherit "freetype";
#else
inherit "ttf";
#endif
constant cvs_version = "$Id$";

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
     return ({ "nn" });
   case "roxenbuiltin":
     return ({ "nn", "bn", "bi" });
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
     Configuration conf = roxen->current_configuration->get();
     License.Key license_key = conf && conf->getvar("license")->get_key();
     if (license_key && license_key->type() == "personal")
       return Image.Font();
#if constant(__rbf) && constant(grbf)
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
#endif
   case "pikebuiltin":
     return Image.Font();
  }
}
