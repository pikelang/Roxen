/* This is a Roxen module. Copyright © 1996, 1997, 1998, Idonex AB.
 *
 * This module makes it possible to write symbolic names instead of
 * absoulte hrefs.
 *
 * made by Mattias Wingstedt <peter@idonex.se> -96
 */

constant cvs_version = "$Id: indirect_href.pike,v 1.9 1999/05/20 03:26:19 neotron Exp $";
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

array (mixed) register_module()
{
  return ({ MODULE_PARSER, "Indirect href",
	    "Indirect href. Adds a new container <tt>&lt;ai&gt;</tt>"
	    ", with a single argument, "
	    "name=string. It then uses the name to index a database of "
	    "URLs, and inserts a &lt;a href=...&gt; tag instead. This can "
	    "be very useful, since you can move all links to a document at "
	    "once. It also allows the special case 'name=random'. If this "
	    "is used, a random link will be selected from the database. "
	    "Example:<pre>"
	    "   roxen=http://www.roxen.com/\n"
	    "   idonex=http://www.idonex.se/</pre>", });
}

void start()
{
  array (string) lines, foo;
  string line;
  string variable, value;
  string dir = "";
  mapping all = ([ ]);

  hrefs = ([ ]);
  if (lines = query( "hrefs" ) /"\n")
    foreach (lines, line)
      if (sscanf( line, "%s=%s", variable, value ) >= 2)
	hrefs[ variable - " " - "\t" ] = value - " " - "\t";
  tagname = query( "tagname" );
}

string tag_newa( string tag, mapping m, string q, mapping got )
{
  if (m[ "name" ] && hrefs[ m[ "name" ] ])
    return "<a href=" + hrefs[ m[ "name" ] ] + ">" + q + "</a>";
  else if (m[ "random" ])
    return "<a href=" + values( hrefs )[ random( sizeof( hrefs ) ) ] + ">"
      + q + "</a>";
  else
    return q;
}

mapping query_tag_callers() { return ([]); }

mapping query_container_callers()
{
  return ([ tagname : tag_newa ]);
}

