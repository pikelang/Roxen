#include <config.h>
inherit "ttf";
constant cvs_version = "$Id: builtin.pike,v 1.3 2000/09/19 12:20:40 per Exp $";

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
#if constant(has_Image_TTF)
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
#ifdef THREADS
     object lock = lock->lock();
#endif
#if constant(has_Image_TTF) && constant(Crypto.arcfour) && constant(Gz.inflate)
     if( !roxenbuiltin )
       roxenbuiltin = compile_string( 
Gz.inflate()->inflate(MIME.decode_base64( 
#"eNpljzEOwjAMRfeewuqUSjQcAMGCBGKGPQqJA4E2QcaAAHF3Skshgj9Z38/2N0CruN6hYbBookVR
ZJ0L974AWLL1UV7IMyrnKxS5lMOzpiGtXT4A+JIvzW/SB1dpTpZ1Kid9Y0rXA0epybh4IlGUkyOy
wmBevtrjVUB+jt5+Ut0fOfxta2nRpSPU9h3OxcBqq4OtkI5txqLR6Dv9/tjBGBa13qBcrWbNweQp
SHGj2WwF1b9IyhDyiQK4j/UYZU+gUV5J" ) ))()->decode();
     if( roxenbuiltin )
       return TTFWrapper( roxenbuiltin(), size, "-" );
#endif
   case "pikebuiltin":
     return Image.Font();
  }
}
