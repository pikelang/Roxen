// This is a roxen module. Copyright © 1996 - 2000, Roxen IS.
//
// This module makes it possible to write symbolic names instead of
// absoulte hrefs.
//
// made by Mattias Wingstedt

constant cvs_version = "$Id: indirect_href.pike,v 1.13 2000/03/17 00:30:48 nilsson Exp $";
constant thread_safe=1;
#include <module.h>

inherit "module";
inherit "roxenlib";

mapping hrefs;
string tagname;

void create()
{
  defvar( "hrefs", "", "Indirect hrefs", TYPE_TEXT_FIELD,
	  "Syntax:<br>\n"
	  "[name] = [URL]\n" );

  //This pollutes namespace and makes the life hard on the manual writers.
  //Thus it's turned of for normal users.
  defvar( "tagname", "ai", "Tagname", TYPE_STRING|VAR_EXPERT,
	  "Name of the tag\n"
	  "&lt;tag name=[name]&gt;foo&lt;/tag&gt; will be replaced with\n"
	  "&lt;a href=[URL]&gt;foo&lt;/a&gt;"
	  "if the name is changed, the module has to be reloaded for the "
	  "namechange to take effect)" );
}

constant module_type = MODULE_PARSER;
constant module_name = "Indirect href";
constant module_doc  =
  "Indirect href. Adds a new container <tt>&lt;ai&gt;</tt>"
  ", with a single argument, "
  "name=string. It then uses the name to index a database of "
  "URLs, and inserts a &lt;a href=...&gt; tag instead. This can "
  "be very useful, since you can move all links to a document at "
  "once. It also allows the special case 'name=random'. If this "
  "is used, a random link will be selected from the database. "
  "Example:<pre>"
  "   roxen=http://www.roxen.com/</pre>";

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
  tagname = query( "tagname" );
}

string tag_newa(string tag, mapping m, string q)
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
  return ([ tagname : ({ 0, tag_newa }) ]);
}

