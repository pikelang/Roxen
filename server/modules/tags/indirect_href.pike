// This is a roxen module. Copyright © 1996 - 2000, Roxen IS.
//
// This module makes it possible to write symbolic names instead of
// absoulte hrefs.
//
// made by Mattias Wingstedt

constant cvs_version = "$Id: indirect_href.pike,v 1.15 2000/04/06 06:16:06 wing Exp $";
constant thread_safe=1;
#include <module.h>

inherit "module";
inherit "roxenlib";

mapping hrefs;
string tagname;

void create()
{
  defvar( "hrefs", "", "Indirect hrefs", TYPE_TEXT_FIELD,
	  "The URL database with the syntax:<br>\n"
	  "[name] = [URL]\n" );

  //This pollutes namespace and makes the life hard on the manual writers.
  //Thus it's turned of for normal users.
  //  defvar( "tagname", "ai", "Tagname", TYPE_STRING|VAR_EXPERT,
  //	  "Name of the tag\n"
  //	  "&lt;tag name=[name]&gt;foo&lt;/tag&gt; will be replaced with\n"
  //	  "&lt;a href=[URL]&gt;foo&lt;/a&gt;"
  //	  "if the name is changed, the module has to be reloaded for the "
  //	  "namechange to take effect)" );
}

constant module_type = MODULE_PARSER;
constant module_name = "Indirect href";
constant module_doc  =
#"Indirect href. Adds a new tag <tt>&lt;ai name=&gt;</tt> that works like "
<tt>&lt;a href=&gt;</tt> but uses a symbolic name instead of a URL. The "
"symbolic name is translated to a proper URL and the tag rewritten to a "
"proper &lt;a href=&gt; tag. The translation between symbolic names and "
"URLs is stored in a module variable. The advantage of this module is that "
"each URL will only be stored in one place and it becomes very easy to "
"change it, no matter how many links use it. As an extra bonus the name "
"<tt>random</tt> will be replaces by a random URL from the list.";

// Dynamic tagname, hence dynamic documentation.
mapping tagdocumentation() {
  return ([tagname:"<desc cont>ai</desc>"]);
}

void start()
{
  array (string) lines;
  string variable, value;
  mapping all = ([ ]);

  hrefs = ([ ]);
  if (lines = (query( "hrefs" )-" "-"\t") /"\n")
    foreach (lines, string line)
      if (sscanf( line, "%s=%s", variable, value ) >= 2)
	hrefs[ variable ] = value;
  tagname = "ai";//query( "tagname" );
}

string newa(string tag, mapping m, string q)
{
  if(!m->name && !m->random) return q;
  if(m->name) {
    m->href=hrefs[m->name];
    m_delete(m, "name");
  }
  if(m->random) {
    m->href=values(hrefs)[random(sizeof(hrefs))];
    m_delete(m, "random");
  }
  return make_container("a",m,q);
}

mapping query_simpletag_callers()
{
  return ([ tagname : ({ 0, newa }) ]);
}

