// This is a part of the language system developed by Mattias Wingstedt, ask
// him if you want more info.

string cvs_version = "$Id: variable.pike,v 1.4 1996/12/02 04:32:51 per Exp $";
#include <module.h>

inherit "module";
inherit "roxenlib";

mapping vars = ([ ]);

void create()
{
  defvar( "variables", "", "Variables", TYPE_TEXT_FIELD, 
	 "Syntax:\n"
	 + "<br>dir [URL]\n"
	 + "<br>[variable name] [variable value]" );
}

mixed *register_module()
{
  return ({ MODULE_URL | MODULE_PARSER, 
	    "Variable", 
	    ("Variable, makes it possible to define variables based on "
	     "URL/location of the request. Currently only used by the "
	     "header and footer module"),
	    ({ }),
	    1
	  });
}

void start()
{
  string *lines, line;
  string variable, value, *foo;
  string dir = "";
  mapping all = ([ ]);

  vars = ([ ]);
  if (lines = query( "variables" ) /"\n")
    foreach (lines, line)
      if (sscanf( line, "%s=%s", variable, value ) >= 2)
      {
	foo = value / " ";

	while (sizeof( foo ) && foo[0] == "")
	  foo = foo[1..sizeof( foo )-1 ];
	while (sizeof( foo ) && foo[ sizeof( foo )-1 ] == "")
	  foo = foo[0..sizeof( foo )-2 ];
	if (sizeof( foo ))
	  if (dir == "")
	    all[ variable - " " ] = foo * " ";
	  else
	    vars[ dir ][ variable - " " ] = foo * " ";
      }
      else
	if (strlen( line - " " ))
	{
	  dir = (line - " ");
	  if (dir[0] == "/")
	    dir = dir[ 1..strlen( dir )-1 ];
	  vars[ dir ] = copy_value( all );
	}
  if (!vars[ "" ])
    vars[ "" ] = all;
}

mixed remap_url( mapping id, string url )
{
  string *dirs, dir;
  int c;

  dirs = url / "/";
  for (c=sizeof( dirs )-1; c >= 0; c--)
  {
    dir = dirs[0..c] * "/" + "/";
    if (vars[ dir ])
    {
      id->misc += vars[ dir ];
      return 0;
    }
  }
  id->misc += vars [ "" ];
  return 0;
}

string tag_variable( string tag, mapping m, object id ) 
{ 
  id->misc += m;
}

mapping query_tag_callers()
{
  return ([ "var" : tag_variable ]);
}

mapping query_container_callers()
{
  return ([]);
}

