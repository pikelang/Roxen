/* This is a roxen module. (c) Informationsvävarna AB 1997.
 *
 * Adds some java script that will prevent others from putting
 * your page in a frame.
 * 
 * Will also remove occuranses of "index.html" at the end of the URL.
 * 
 * made by Peter Bortas <peter@infovav.se> Januari -97
 */

constant cvs_version = "$Id: killframe.pike,v 1.9 1997/08/31 21:54:44 peter Exp $";
constant thread_safe=1;

#include <module.h>
inherit "module";

void create() { }

mixed *register_module()
{
  return ({ 
    MODULE_PARSER,
    "Killframe tag",
      ("Makes pages frameproof."
       "<br>This module defines a tag,"
       "<pre>"
       "&lt;killframe&gt;: Adds some java script that will prevent others\n"
       "             from putting your page in a frame.\n\n"
       "             Will also strip any occurences of the string\n"
       "             'index.html' from the end of the URL."
       "</pre>"
       ), ({}), 1,
    });
}

string tag_killframe( string tag, mapping m, object id )
{
  /* Links to index.html are ugly. */
  string my_url = id->conf->query("MyWorldLocation") + id->raw_url[1..];
  int l=strlen(my_url);

  if( my_url[l-11..] == "/index.html" )
    my_url = my_url[..l-11];
  
  if (id->supports->javascript)
    return("<script language=javascript>\n"
	   "<!--\n"
	   "   if(top.location.href != \""+ my_url  +"\")\n"
	   "     top.location.href = \""+ my_url  +"\";\n"
	   "//-->"
	   "</script>\n");
  return "";
}

mapping query_tag_callers()
{
  return ([ "killframe" : tag_killframe ]);
}

int threadsafe(){ return 1; }
