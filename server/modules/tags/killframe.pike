/* This is a roxen module. (c) Informationsvävarna AB 1997.
 *
 * Adds some java script that will prevent others from putting
 * your page in a frame.
 * 
 * Will also strip any occurences of the string 'index.html' 
 * from the URL. Currently this is done a bit clumsy, making
 * URLs like http://www.roxen.com/index.html/foo.html break,
 * this should be fixed.
 * 
 * made by Peter Bortas <peter@infovav.se> Januari -97
 */

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
       "             'index.html' from the URL."
       "</pre>"
       ), ({}), 1,
    });
}

string tag_killframe( string tag, mapping m, object id )
{
  //Det är fult med länkar till index.html
  string my_url = roxen->query("MyWorldLocation") + id->raw_url[1..] -
    "index.html";

  if (id->supports->javascript)
    string head = "<script language=javascript>\n"
      "<!--\n"
      "   if(top.location.href != \""+ my_url  +"\")\n"
      "     top.location.href = \""+ my_url  +"\";\n"
      "//-->"
      "</script>\n";
  
  return head;
}

mapping query_tag_callers()
{
  return ([ "killframe" : tag_killframe ]);
}
