// This is a roxen module. Copyright © 1998 - 2009, Roxen IS.

#include <module.h>
inherit "module";

constant cvs_version = "$Id$";

void create()
{
  defvar("location", "/demo/", "Mount point", TYPE_LOCATION,
	 "This is where the module will be inserted in the "+
	 "namespace of your server.");

  defvar("dbpath", "../var/demomodule-bookmarks", "Database path",
	 TYPE_STRING, "This is the path to the module's Yabu database.",
	 0, 1); // Don't show this variable
}

void start(int level, Configuration conf)
{
  if(conf && query("dbpath") == "../var/demomodule-bookmarks")
    set("dbpath", "../var/demomodule-bookmarks/" + conf->name);
}

constant module_type = MODULE_LOCATION;
constant module_name = "Demo module";
constant module_doc  = "This module makes it possible to develop RXML code interactively.";

#define FOO "<title>Demo</title>\n" \
"<body bgcolor='white'>\n" \
"<form action='%d'>\n" \
"<input type='submit' name='_submit' value='Clear' />\n" \
"</form>\n" \
"<p><br /></p><p><br /></p>\n" \
"%s" \
"<p><br /></p><p><br /></p>\n" \
"<form>\n" \
"<textarea name='_data' cols='60' rows='14'>%s</textarea>\n" \
"<br /><input type='submit' name='_submit' value='Clear' /> " \
"<input type='submit' value='    Show    ' />\n" \
"<br /><input type='submit' name='_submit' value='Push' />\n"+\
(sizeof(stack)?"<input type='submit' name='_submit' value='Pop' />"\
" <input type='submit' name='_submit' value='Swap' />":"")+\
" (Stack size: "+sizeof(stack)+")\n"\
"</form>\n" \
"<table><tr><td>"\
"<form action='%d'>" \
"<input type='submit' value=' <-- previous ' />" \
"</form>" \
"</td><td>"\
"<form>Position: <input size='4' type='string' name='pos' value='"+(int)f+"' />"\
"<input type='submit' name='go' value='Go!' /></form>"\
"</td><td>"\
"</td><td>"\
"<form action='%d'>" \
"<input type='submit' value=' next --> ' />" \
"</form>" \
"</td></tr></table>" \
"</body>"

object mdb;
array(string) stack=({ });

mapping find_file( string f, RequestID id )
{
  if(id->variables->go)
    return Roxen.http_redirect(query("location")+id->variables->pos,id);
  if (!mdb) {
    mdb = Yabu.db(query("dbpath"), "wcCr")["demo"];
    if(!mdb[42])
      mdb[42]=
#"<for variable=var.i from=99 to=1 step=-1>
  <if not variable=\"var.i is 1\">
    <set variable=var.s value=\"s\"/>
  </if>
  <else>
    <set variable=var.s value=\"\"/>
  </else>
  &var.i; bottle&var.s; of beer on the wall,<br><br>
  &var.i; bottle&var.s; of beer on the wall,<br>
  &var.i; bottle&var.s; of beer,<br>
  Take one down, pass it around,<br><br>
</for>
No more bottles of beer on the wall";
  }
  string data = mdb[ (int)f ];

  if (id->variables->_submit == "Clear")
    mdb[ id->not_query ] = data = "";
  else if(id->variables->_submit == "Push")
    stack=({data})+stack;
  else if(id->variables->_submit == "Pop")
  {
    data=stack[0];
    mdb[ (int)f ] = data;
    stack=stack[1..];
  }
  else if(id->variables->_submit == "Swap")
  {
    string temp=data;
    data=stack[0];
    stack[0]=data;
  }
  else if (id->variables->_data)
  {
    data = id->variables->_data;
    data = data / "\r\n" * "\n";
    data = data / "\r" * "\n";
    mdb[ (int)f ] = data;
  }
  if (!stringp( data ))
    data = "";
  return Roxen.http_string_answer( Roxen.parse_rxml
				   ( sprintf( FOO, (int)f,
					      data,
					      replace(data, ({ "<", ">", "&" }),
						      ({"&lt;","&gt;","&amp;"})),
					      ((int)f)-1,
					      ((int)f)+1), id));
}
