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
 *
 * BUGS:
 * Removes document-internal links. (gazink.html#foo)
 */

constant cvs_version = "$Id: killframe.pike,v 1.19 1998/06/06 16:35:31 peter Exp $";
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
  if(m->help) return register_module()[2];

  if( !id->supports->javascript ) return "";

  string javascript;

  while( id->misc->orig )
    id = id->misc->orig;
  
  // Some versions of IE will choke on :80. (Reload and repeat..)
  string tmp;
  string my_url = id->conf->query("MyWorldLocation");
  if( sscanf(my_url, "%s:80/", tmp ) )
    my_url = tmp +"/"+ id->not_query[1..];
  else
    my_url += id->not_query[1..];
  
  // Links to index.html are ugly. All pages deserve a uniqe URL, and for
  // index-pages that URL in /.
  if( query("killindex") )
  {
    //Get indexfiles from the directory-module if there is one.
    array indexfiles = ({});
    if( id->conf->dir_module )
      indexfiles = id->conf->dir_module->query("indexfiles");

    int l=strlen(my_url)-1;
    
    foreach( indexfiles, string index )
      if( my_url[l-strlen(index)..] == "/" +index )
	my_url = my_url[..l-strlen(index)];
  }

  // Put back the variables if there were any.
  if(id->query)
    my_url += "?"+ id->query;

  // top.location = self.location is more beutiful, but it breaks some
  // version of IE
  javascript = ( "   if(top.location != \""+ my_url  +"\")\n"
		 "     top.location = \""+ my_url  +"\";\n"   );
  
  return("<script language=javascript><!--\n"
	 + javascript
	 + "//--></script>\n");
}

mapping query_tag_callers()
{
  return ([ "killframe" : tag_killframe ]);
}
