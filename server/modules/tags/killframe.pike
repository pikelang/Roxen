/* This is a roxen module. Copyright © 1997, 1998, Idonex AB.
 *
 * Adds some java script that will prevent others from putting
 * your page in a frame.
 * 
 * Will also remove occuranses of "indexfiles" from the end of the URL.
 * 
 * made by Peter Bortas <peter@idonex.se> Januari -97
 *
 * Thanks for suggestions and bugreports:
 * Barry Treahy <treahy@allianceelec.com>
 * Chris Burgess <chris@ibex.co.nz>
 */

constant cvs_version = "$Id: killframe.pike,v 1.17 1998/04/03 19:20:53 peter Exp $";
constant thread_safe=1;

#include <module.h>
inherit "module";

void create()
{
  defvar( "killindex", 1, "Kill trailing 'indexfiles'?", TYPE_FLAG|VAR_MORE,
	  "When set, the killframe module will remove occurrences of "
	  "'indexfiles' (as set in the active directory module) from "
	  "the end of the URL, leaving only a slash." );
}

mixed register_module()
{
  return ({ 
    MODULE_PARSER,
    "Killframe tag",
      ("Makes pages frameproof."
       "<br>This module defines a tag,"
       "<pre>"
       "&lt;killframe&gt;: Adds some java script that will prevent others\n"
       "             from putting your page in a frame.\n\n"
       "             Will also strip any occurrences of 'indexfiles'\n"
       "             from the end of the URL."
       "</pre>"
       ), ({}), 1,
    });
}

string tag_killframe( string tag, mapping m, object id )
{
  string javascript;

  if(m->help) return register_module()[2];

  array indexfiles;
  if( id->conf->dir_module )
    indexfiles = id->conf->dir_module->query("indexfiles");

  while( id->misc->orig )
    id = id->misc->orig;
  
  if( query("killindex") )
  {
    string tmp;

    /* Links to index.html are ugly. */

    string my_url = id->conf->query("MyWorldLocation");
    if( sscanf(my_url, "%s:80/", tmp ) )
      my_url = tmp +"/"+ id->not_query[1..];
    else
      my_url += id->not_query[1..];

    int l=strlen(my_url)-1;

    foreach( indexfiles, string index )
      if( my_url[l-strlen(index)..] == "/" +index )
	my_url = my_url[..l-strlen(index)];

    javascript = ( "   if(top.location != \""+ my_url  +"\")\n"
		   "     top.location = \""+ my_url  +"\";\n"   );
  }
  else
    javascript = ( "   if (self != top) top.location = self.location;\n" );

  if (id->supports->javascript)
    return("<script language=javascript><!--\n"
	   + javascript
	   + "//--></script>\n");

  return "";
}

mapping query_tag_callers()
{
  return ([ "killframe" : tag_killframe ]);
}
