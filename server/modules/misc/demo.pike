// (c) 1998 Idonex AB
#include <module.h>

inherit "module";
inherit "roxenlib";

import Array;

void create()
{
  defvar("location", "/demo/", "Mount point", TYPE_LOCATION, 
	 "This is where the module will be inserted in the "+
	 "namespace of your server.");
}


mixed *register_module()
{
  return ({ 
    MODULE_LOCATION, 
    "Demo module", 
    "This module makes it possible to develop, RXML code interactively." });
}

#define FOO "<title>Demo</title>\n" \
"<body bgcolor=white>\n" \
"<form>\n" \
"<input type=submit name=_submit value=Clear>\n" \
"</form>\n" \
"<p><br><p><br><p>\n" \
"%s" \
"<p><br><p><br><p>\n" \
"<form>\n" \
"<textarea name=_data cols=60 rows=14>%s</textarea>\n" \
"<br><input type=submit name=_submit value=Clear> " \
"<input type=submit value=Show>\n" \
"</form>\n" \
"</body>"

object mdb = PDB.db("hilfisar", "wcCr")["demo"];

mixed find_file( string f, object id )
{
  string data = mdb[ id->not_query ];

  if (id->variables->_submit == "Clear")
    mdb[ id->not_query ] = data = "";
  else if (id->variables->_data)
    mdb[ id->not_query ] = data = id->variables->_data;
  return http_string_answer( parse_rxml( sprintf( FOO, data,
		 	     replace( data, ({ "<", ">", "&" }),
					    ({ "&lt;", "&gt;", "&amp;" }) ),
			     ), id ) );
}
