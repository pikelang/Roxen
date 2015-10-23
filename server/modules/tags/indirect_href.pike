// This is a roxen module. Copyright © 1996 - 2009, Roxen IS.
//
// This module makes it possible to write symbolic names instead of
// absoulte hrefs.
//
// made by Mattias Wingstedt

#pragma strict_types

constant cvs_version = "$Id$";
constant thread_safe = 1;
#include <module.h>

inherit "module";

void create()
{
  defvar( "hrefs", "roxen     = http://www.roxen.com\n"
	  "community = http://community.roxen.com", "Indirect hrefs",
	  TYPE_TEXT_FIELD, "The URL database with the syntax:<br>\n"
	  "[name] = [URL]\n" );
  /*
  defvar( "tagname", "ai", "Tag name", TYPE_STRING,
	  "The name of the tag." );
  */
}

constant module_type = MODULE_TAG;
constant module_name = "Tags: Indirect href";
//constant module_unique = 0;
constant module_doc  =
#"Indirect href. Adds a new tag <tt>&lt;ai&nbsp;name=\"\"&gt;&lt;/ai&gt;</tt> that works like 
<tt>&lt;a&nbsp;href=\"\"&gt;&lt;/a&gt;</tt> but uses a symbolic name instead of a URL. The 
symbolic name is translated to a proper URL and the tag rewritten to a 
proper <tt>&lt;a&nbsp;href=\"\"&gt;&lt;/a&gt;</tt> tag. The translation between symbolic names and 
URLs is stored in a module variable. The advantage of this module is that 
each URL will only be stored in one place and it becomes very easy to 
change it, no matter how many links use it. As an extra bonus the name 
<tt>random</tt> will be replaces by a random URL from the list.";

mapping(string:string) hrefs;

void start()
{
  array(string) lines;
  string variable, value;

  hrefs = ([ ]);
  if (lines = ([string]query( "hrefs" )-" "-"\t") /"\n")
    foreach (lines, string line)
      if (sscanf( line, "%s=%s", variable, value ) >= 2)
	hrefs[ variable ] = value;
}

class TagAI {
  inherit RXML.Tag;
  string name;
  mapping(string:object(RXML.Type)) req_arg_types = (["name":RXML.t_text(RXML.PEnt)]);

  void create() {
    if(variables->tagname)
      name = [string]query("tagname");
    else
      name = "ai";
  }

  class Frame {
    inherit RXML.Frame;
    array do_return() {
      if(!args->name || !sizeof(hrefs)) {
	result = content;
	return 0;
      }

      if(!(hrefs->random) && args->name=="random")
	args->href=values(hrefs)[random(sizeof(hrefs))];
      else
	args->href=hrefs[args->name];
      m_delete([mapping(string:string)]args, "name");

      result = Roxen.make_container("a", [mapping(string:string)]args, [string]content);
      return 0;
    }
  }
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
  "ai":#"<desc type='cont'><p><short>
 Makes it possible to use a database of links.</short> Each link is referred
 to by a symbolic name instead of the URL.</p>

 <p>The database is updated through the configuration interface. The
 tag is available through the <i>Indirect href</i>
 module.</p></desc>

 <attr name='name' value='string' required='required'><p>
 Which link to fetch from the database. There is a special case,
 <att>name='random'</att> that will choose a random link from the
 database.</p>
 <ex><ai name='roxen'>Roxen Internet Software</ai></ex>
 </attr>",
    ]);
#endif
