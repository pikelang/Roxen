// $Id: demo.pike,v 1.8 1999/04/24 16:35:54 js Exp $
//
// (c) 1998 Idonex AB
#include <module.h>

inherit "module";
inherit "roxenlib";

// import Array;

constant cvs_version = "$Id: demo.pike,v 1.8 1999/04/24 16:35:54 js Exp $";

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
"<form action=%d>\n" \
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
"<table><tr><td>"\
"<form action=%d>" \
"<input type=submit value=' <-- previous '>" \
"</form>" \
"</td><td>"\
"<form>Position: <input size=4 type=string name=pos value='"+(int)f+"'>"\
"<input type=submit name=go value='Go!'></form>"\
"</td><td>"\
"</td><td>"\
"<form action=%d>" \
"<input type=submit value=' next --> '>" \
"</form>" \
"</td></tr></table>" \
"</body>"

object mdb;

mixed find_file( string f, object id )
{
  if(id->variables->go)
    return http_redirect(query("location")+id->variables->pos,id);
  if (!mdb) {
    mdb = Yabu.db(".demo-bookmarks", "wcCr")["demo"];
    if(!mdb[42])
      mdb[42]=
#"<for variable=i from=99 to=1 step=-1>
  <if not variable=\"i is 1\">
    <set variable=s value=\"s\">
  </if>
  <else>
    <set variable=s value=\"\">
  </else>
  <formoutput>
    #i# bottle#s# of beer on the wall,<br><br>
    #i# bottle#s# of beer on the wall,<br>
    #i# bottle#s# of beer,<br>
    Take one down, pass it around,<br><br>
  </formoutput>
</for>
No more bottles of beer on the wall";
  }
  string data = mdb[ (int)f ];

  if (id->variables->_submit == "Clear")
    mdb[ id->not_query ] = data = "";
  else if (id->variables->_data)
  {
    data = id->variables->_data;

    data = data / "\r\n" * "\n";
    data = data / "\r" * "\n";
    mdb[ (int)f ] = data;
  }
  if (!stringp( data ))
    data = "";
  return http_string_answer( parse_rxml( sprintf( FOO, (int)f,
						  data,
						  replace(data, ({ "<", ">", "&" }),
							  ({"&lt;","&gt;","&amp;"})),
						  ((int)f)-1,
						  ((int)f)+1), id));
}
