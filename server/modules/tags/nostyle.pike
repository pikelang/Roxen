#include <module.h>
inherit "module";
inherit "roxenlib";

constant module_name = "Stylesheet remover";
constant module_doc = "Removes stylesheets for non-stylesheet capable browsers";
constant module_type = MODULE_PARSER;

mixed container_style( string t, mapping m, string c, object id )
{
  if( !id->supports->stylesheets ) return "";
  return ({ make_container( t, m, parse_rxml( c,id ) ) });
}
