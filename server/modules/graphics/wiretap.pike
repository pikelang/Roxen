// This is a roxen module. Copyright © 2000-2001, Roxen IS.
//

constant cvs_version="$Id: wiretap.pike,v 1.25 2001/04/27 09:37:02 jonasw Exp $";

#include <module.h>
inherit "module";


//---------------------- Module Registration --------------------------------

constant module_type   = MODULE_TAG;
constant module_name   = "Tags: HTML color wiretap";
constant module_doc    = 
#"Parses HTML tags and tries to determine the text and background colors 
all over the page. This information can be used to let graphical modules
generate images that automatically blend into the page.";
constant thread_safe   = 1;

void create()
{
  defvar("colorparsing", ({ "td", "layer", "ilayer", "table" }),
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


TAGDOCUMENTATION
#ifdef manual
constant tagdoc = ([ "body" :
#"<desc cont='cont'><p>
<short>Initializes the wiretap color settings.</short></p>
</desc>

<attr name='wiretap' value='yes|no'>
<p>HTML Color Wiretap can be disabled for an individual web page by
adding <tt>wiretap='no'</tt> to the document's <tag>body</tag> tag.</p>
</attr>" ]);
#endif



// -------------------- The actual wiretap code  --------------------------


int is_compat_mode(Configuration conf)
{
  //  Check whether compatibility with 1.x, 2.0 or 2.1 is needed. When
  //  compatibility is requested we tap all tags all the time unlike the
  //  newer design where we require a <body> tag to enable the wiretap.
  return conf->query("compat_level") < "2.2";
}


array(RXML.Tag) get_tag_variants(string tag_name, mixed tag)
{
  return map(Array.uniq( ({ tag_name,
			    upper_case(tag_name),
			    lower_case(tag_name),
			    String.capitalize(lower_case(tag_name)) }) ),
	     tag);
}


array(RXML.Tag) get_temporary_tags(array(string) colorparsing)
{
  array(RXML.Tag) temp_tags = ({ });
  
  //  Register various combinations of spelling for each tag, but avoid
  //  <body> which many users will have left in their configuration files.
  //
  //  We choose not to cache the instantiated tag objects since the
  //  overhead for creating them is low. Also, the tag objects themselves
  //  precompute some query() lookups which would be made permanent if we
  //  cached here.
  foreach(colorparsing, string tag_name)
    if (lower_case(tag_name) != "body") {
      foreach(get_tag_variants(tag_name, TagPushColor), RXML.Tag tag)
	temp_tags += ({ tag });
      foreach(get_tag_variants(tag_name, TagPopColor), RXML.Tag tag)
	temp_tags += ({ tag });
    }
  
  return temp_tags;
}


class TagBody
{
  inherit RXML.Tag;

  string name;
  int colormode;
  array(string) colorparsing;
  constant flags = (RXML.FLAG_EMPTY_ELEMENT |
		    RXML.FLAG_COMPAT_PARSE |
		    RXML.FLAG_NO_PREFIX);
  
  void create(string _name)
  {
    name = _name;
    colormode = (int) query("colormode");
    colorparsing = query("colorparsing");
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
	if (!is_compat_mode(id->conf)) {
	  RXML.Context ctx = RXML.get_context();
	  foreach(get_temporary_tags(colorparsing), RXML.Tag tag)
	    ctx->add_runtime_tag(tag);
	}
	
	args = mkmapping(map(indices(args), lower_case), values(args));
	if (Roxen.init_wiretap_stack(args, id, colormode))
	  return ({ propagate_tag(args) });
      }
      return ({ propagate_tag() });
    }
  }
}


class TagEndBody
{
  inherit RXML.Tag;

  string name, tagname;
  array(string) colorparsing;
  constant flags = (RXML.FLAG_EMPTY_ELEMENT |
		    RXML.FLAG_COMPAT_PARSE |
		    RXML.FLAG_NO_PREFIX);
  
  void create(string _name)
  {
    tagname = _name;
    name = "/" + _name;
    colorparsing = query("colorparsing");
  }
  
  class Frame
  {
    inherit RXML.Frame;
    string raw_tag_text;
    
    array do_return(RequestID id)
    {
      //  Unregister our temporary tags unless we're in compatibility mode
      if (!is_compat_mode(id->conf)) {
	RXML.Context ctx = RXML.get_context();
	foreach(get_temporary_tags(colorparsing), RXML.Tag tag)
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
  int colormode;
  constant flags = (RXML.FLAG_EMPTY_ELEMENT |
		    RXML.FLAG_COMPAT_PARSE |
		    RXML.FLAG_NO_PREFIX);

  void create(string _name)
  {
    name = _name;
    colormode = (int) query("colormode");
  }
  
  class Frame
  {
    inherit RXML.Frame;
    string raw_tag_text;

    array do_return(RequestID id)
    {
      args = mkmapping(map(indices(args), lower_case), values(args));
      if (Roxen.push_color(name, args, id, colormode))
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

RXML.TagSet query_tag_set()
{
  if (!module_tag_set) {
    //  Register start and end tags individually so we can handle the
    //  <body> container properly. If compatibility with 2.1 or earlier
    //  is needed we register all tags at once.
    //
    //  Note that if user changes the parser compatibility level a
    //  server restart is currently needed since modules aren't
    //  re-queried for their tag sets.
    array(RXML.Tag) compat_tags = ({ });
    if (is_compat_mode(my_configuration())) {
      foreach(query("colorparsing"), string tag)
	if (lower_case(tag) != "body") {
	  compat_tags +=
	    get_tag_variants(tag, TagPushColor) +
	    get_tag_variants(tag, TagPopColor);
	}
    }

    module_tag_set = RXML.TagSet(module_identifier(),
				 compat_tags +
				 get_tag_variants("body", TagBody) +
				 get_tag_variants("body", TagEndBody));
  }
  return module_tag_set;
}
