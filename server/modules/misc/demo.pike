// $Id: demo.pike,v 1.7 1998/06/04 12:47:38 grubba Exp $
//
// (c) 1998 Idonex AB
#include <module.h>

inherit "module";
inherit "roxenlib";

// import Array;

constant cvs_version = "$Id: demo.pike,v 1.7 1998/06/04 12:47:38 grubba Exp $";

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

object mdb;

mixed find_file( string f, object id )
{
  if (!mdb) {
    mdb = PDB.db("hilfisar", "wcCr")["demo"];
  }
  string data = mdb[ id->not_query ];

  if (id->variables->_submit == "Clear")
    mdb[ id->not_query ] = data = "";
  else if (id->variables->_data)
  {
    data = id->variables->_data;

    data = data / "\r\n" * "\n";
    data = data / "\r" * "\n";
    mdb[ id->not_query ] = data;
  }
  if (!stringp( data ))
    data = "";
  return http_string_answer( parse_rxml( sprintf( FOO, data,
		 	     replace( data, ({ "<", ">", "&" }),
				      ({ "&lt;", "&gt;", "&amp;" }) ),
			     ), id ) );
}
