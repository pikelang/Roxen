// This is a roxen module. Copyright © 2000, Roxen IS.
//

constant cvs_version="$Id: wiretap.pike,v 1.23 2001/02/06 22:39:56 nilsson Exp $";

#include <module.h>
inherit "module";


//---------------------- Module Registration --------------------------------

constant module_type   = MODULE_TAG;
constant module_name   = "HTML color wiretap";
constant module_doc    = 
#"Parses HTML tags and tries to determine the text and background colors 
all over the page. This information can be used to let graphical modules
generate images that automatically blend into the page.";
constant thread_safe   = 1;

void create()
{
  defvar("colorparsing", ({"body", "td", "layer", "ilayer", "table"}),
	 "Tags to parse for color",
	 TYPE_STRING_LIST|VAR_NOT_CFIF,
	 "Which tags should be parsed for document colors? "
	 "This will affect documents without gtext as well as documents "
	 "with it, the parsing time is relative to the number of parsed "
	 "tags in a document. You have to reload this module or restart "
	 "roxen for changes of this variable to take effect.");

  defvar("colormode", 0, "Normalize colors in parsed tags",
         TYPE_FLAG|VAR_NOT_CFIF, #"\
If set, replace 'roxen' colors (@c,m,y,k etc) with 'netscape'
colors (#rrggbb). This means that if this is enabled, Roxen will
rewrite the parsed tags, which can potentially cause problems with
quotes etc if they aren't correcly written. Setting this to off will
also lessen the performance impact of the 'Tags to parse for color'
option quite dramatically. You can try this out with the &lt;gauge&gt;
tag.");
}


// -------------------- The actual wiretap code  --------------------------

class TagBody
{
  inherit RXML.Tag;
  string name;
  constant flags = RXML.FLAG_EMPTY_ELEMENT|RXML.FLAG_COMPAT_PARSE|RXML.FLAG_NO_PREFIX;

  void create (string _name) {name = _name;}

  class Frame
  {
    inherit RXML.Frame;
    string raw_tag_text;

    array do_return (RequestID id)
    {
      args = mkmapping (map (indices (args), lower_case), values (args));
//       werror ("body " + name + " %O\n", args);
//       werror ("raw_tag_text: %O\n", raw_tag_text);
      if(Roxen.init_wiretap_stack (args, id, query("colormode")))
	return ({propagate_tag (args)});
      return ({propagate_tag()});
    }
  }
}

class TagPushColor
{
  inherit RXML.Tag;
  string name;
  constant flags = RXML.FLAG_EMPTY_ELEMENT|RXML.FLAG_COMPAT_PARSE|RXML.FLAG_NO_PREFIX;

  void create (string _name) {name = _name;}

  class Frame
  {
    inherit RXML.Frame;
    string raw_tag_text;

    array do_return (RequestID id)
    {
      args = mkmapping (map (indices (args), lower_case), values (args));
      if(Roxen.push_color (name, args, id, query("colormode")))
	return ({propagate_tag (args)});
      return ({propagate_tag()});
    }
  }
}

class TagPopColor
{
  inherit RXML.Tag;
  string name, tagname;
  constant flags = RXML.FLAG_EMPTY_ELEMENT|RXML.FLAG_COMPAT_PARSE|RXML.FLAG_NO_PREFIX;

  void create (string _name) {tagname = _name, name = "/" + _name;}

  class Frame
  {
    inherit RXML.Frame;
    string raw_tag_text;

    array do_return (RequestID id)
    {
      Roxen.pop_color (tagname, id);
      return ({propagate_tag()});
    }
  }
}


// --------------- Tag and container registration ----------------------

RXML.TagSet query_tag_set()
{
  if (!module_tag_set) {
    array(RXML.Tag) tags = ({});
    foreach(query("colorparsing"), string t)
    {
      array(string) variants =
	Array.uniq (({t, t = lower_case (t), upper_case (t), String.capitalize (t)}));
      switch(t)
      {
	case "body":
	  tags += map (variants, TagBody);
	  break;
	default:
	  tags += map (variants, TagPopColor) + map (variants, TagPushColor);
      }
    }
    module_tag_set = RXML.TagSet (module_identifier(), tags);
  }
  return module_tag_set;
}
