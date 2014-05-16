// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.
//

constant cvs_version="$Id$";

#include <module.h>
inherit "module";


//---------------------- Module Registration --------------------------------

constant module_type   = MODULE_TAG;
constant module_name   = "Tags: HTML color wiretap";
constant module_doc    = 
#"<p>Parses HTML tags for the text and background colors all over the
page. This information can be used to let graphical modules like
\"Graphic text\" and \"GButton\" generate images that automatically
blend into the page.</p>

<p>Note that this module can degrade performance, since it causes many
common HTML tags to be parsed by the RXML parser.</p>";
constant thread_safe   = 1;

void create()
{
  defvar("colorparsing", ({ "td", "layer", "ilayer", "table" }),
	 "Tags to parse for color",
	 TYPE_STRING_LIST|VAR_NOT_CFIF,
	 "Which tags should be parsed for document colors? "
	 "This will affect documents without gtext as well as documents "
	 "with it, the parsing time is relative to the number of parsed "
	 "tags in a document.");

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


TAGDOCUMENTATION
#ifdef manual
constant tagdoc = ([ "body" :
#"<desc type='cont'><p>
<short>The color wiretap functionality is active in the content.</short></p>
</desc>

<attr name='wiretap' value='yes|no'>
<p>The color wiretap can be disabled for an individual web page by
adding <tt>wiretap='no'</tt> to the document's <tag>body</tag> tag.</p>
</attr>" ]);
#endif



// -------------------- The actual wiretap code  --------------------------


//  When < 2.2 compatibility is requested we tap all tags all the time
//  unlike the newer design where we require a <body> tag to enable
//  the wiretap. In that case this is the tag set for the runtime
//  tags.
RXML.TagSet runtime_wiretap_tags = RXML.TagSet (this_module(), "runtime");

// The currently implemented settings.
int compat_mode, colormode;
array(string) colorparsing;

array(RXML.Tag) get_tag_variants(string tag_name, mixed tag)
{
  return map(Array.uniq( ({ tag_name,
			    upper_case(tag_name),
			    lower_case(tag_name),
			    String.capitalize(lower_case(tag_name)) }) ),
	     tag);
}

void init_tag_set (int new_compat_mode,
		   array(string) new_colorparsing,
		   int new_colormode)
{
  //  Register start and end tags individually so we can handle the
  //  <body> container properly. If compatibility with 2.1 or earlier
  //  is needed we register all tags at once.

  array(RXML.Tag) body_tags =
    get_tag_variants ("body", TagBody) +
    get_tag_variants ("body", TagEndBody);
  array(RXML.Tag) non_body_tags = ({});

  foreach(new_colorparsing, string tag)
    if (lower_case(tag) != "body") {
      non_body_tags +=
	get_tag_variants(tag, TagPushColor) +
	get_tag_variants(tag, TagPopColor);
    }

  module_tag_set->clear();
  runtime_wiretap_tags->clear();

  if (new_compat_mode)
    module_tag_set->add_tags (body_tags + non_body_tags);
  else {
    module_tag_set->add_tags (body_tags);
    runtime_wiretap_tags->add_tags (non_body_tags);
  }

  compat_mode = new_compat_mode;
  colorparsing = new_colorparsing;
  colormode = new_colormode;
}


class TagBody
{
  inherit RXML.Tag;

  string name;
  constant flags = (RXML.FLAG_EMPTY_ELEMENT |
		    RXML.FLAG_COMPAT_PARSE |
		    RXML.FLAG_NO_PREFIX);

  // Cached settings.
  int body_compat_mode = compat_mode, body_colormode = colormode;
  RXML.TagSet body_runtime_wiretap_tags =runtime_wiretap_tags;
  
  void create(string _name)
  {
    name = _name;
  }

  class Frame
  {
    inherit RXML.Frame;
    string raw_tag_text;

    array do_return(RequestID id)
    {
      //  Check if <body> attribute disables wiretap
      if (args["wiretap"] != "no") {
	//  Register temporary tags unless we're running in compatibility
	//  mode.
	if (!body_compat_mode) {
	  RXML.Context ctx = RXML_CONTEXT;
	  foreach(body_runtime_wiretap_tags->get_local_tags(), RXML.Tag tag)
	    ctx->add_runtime_tag(tag);
	}
	
	args =
	  mkmapping(map(indices(args), lower_case), values(args)) -
	  ({ "wiretap" });
	if (Roxen.init_wiretap_stack(args, id, body_colormode))
	  return ({ propagate_tag(args) });
      }
      if (args["wiretap"])
	return ({ propagate_tag(args - ({ "wiretap" }) ) });
      else
	return ({ propagate_tag() });
    }
  }
}


class TagEndBody
{
  inherit RXML.Tag;

  string name, tagname;
  constant flags = (RXML.FLAG_EMPTY_ELEMENT |
		    RXML.FLAG_COMPAT_PARSE |
		    RXML.FLAG_NO_PREFIX);
  
  // Cached settings.
  int body_compat_mode = compat_mode;
  RXML.TagSet body_runtime_wiretap_tags =runtime_wiretap_tags;
  
  void create(string _name)
  {
    tagname = _name;
    name = "/" + _name;
  }
  
  class Frame
  {
    inherit RXML.Frame;
    string raw_tag_text;
    
    array do_return(RequestID id)
    {
      //  Unregister our temporary tags unless we're in compatibility mode
      if (!body_compat_mode) {
	RXML.Context ctx = RXML_CONTEXT;
	foreach(body_runtime_wiretap_tags->get_local_tags(), RXML.Tag tag)
	  ctx->remove_runtime_tag(tag);
      }
      return ({ propagate_tag() });
    }
  }
}


class TagPushColor
{
  inherit RXML.Tag;
  
  string name;
  constant flags = (RXML.FLAG_EMPTY_ELEMENT |
		    RXML.FLAG_COMPAT_PARSE |
		    RXML.FLAG_NO_PREFIX);
  
  // Cached settings.
  int body_colormode = colormode;
  
  void create(string _name)
  {
    name = _name;
  }

  class Frame
  {
    inherit RXML.Frame;
    string raw_tag_text;
    
    array do_return(RequestID id)
    {
      args = mkmapping(map(indices(args), lower_case), values(args));
      if (Roxen.push_color(name, args, id, body_colormode))
	return ({ propagate_tag(args) });
      return ({ propagate_tag() });
    }
  }
}


class TagPopColor
{
  inherit RXML.Tag;
  
  string name, tagname;
  constant flags = (RXML.FLAG_EMPTY_ELEMENT |
		    RXML.FLAG_COMPAT_PARSE |
		    RXML.FLAG_NO_PREFIX);
  
  void create(string _name)
  {
    tagname = _name;
    name = "/" + _name;
  }

  class Frame
  {
    inherit RXML.Frame;
    string raw_tag_text;

    array do_return(RequestID id)
    {
      Roxen.pop_color(tagname, id);
      return ({ propagate_tag() });
    }
  }
}


// --------------- Tag and container registration ----------------------

void start()
{
  if (module_tag_set) {
    int new_compat_mode = my_configuration()->query("compat_level") < "2.2";
    array(string) new_colorparsing = query ("colorparsing");
    int new_colormode = query ("colormode");
    if (compat_mode != new_compat_mode ||
	!equal (colorparsing, new_colorparsing) ||
	colormode != new_colormode)
      init_tag_set (new_compat_mode, new_colorparsing, new_colormode);
  }
}

RXML.TagSet query_tag_set()
{
  if (!module_tag_set) {
    module_tag_set = RXML.TagSet (this_module(), "");
    module_tag_set->add_tag_set_dependency (runtime_wiretap_tags);
  }
  init_tag_set (my_configuration()->query("compat_level") < "2.2",
		query ("colorparsing"),
		query ("colormode"));
  return module_tag_set;
}
