// This is a roxen module. Copyright © 2000, Roxen IS.
//

#include <module.h>
inherit "module";

constant cvs_version = "$Id: html_wash.pike,v 1.1 2000/07/07 11:24:24 wellhard Exp $";
constant thread_safe = 1;
constant module_type = MODULE_PARSER;
constant module_name = "HTML washer";
constant module_doc  = ("This module provides a tag for washing HTML.");
constant module_unique = 1;

class TagWashHtml
{
  inherit RXML.Tag;
  constant name = "wash-html";

  string paragraphify(string s)
  {
    // more than one newline is considered a new paragraph
    return
      "<p>"+
      ((replace(replace(s - "\r" - "\0", "\n\n", "\0"),
		"\0\n", "\0")/"\0") - ({ "\n", "" }))*"</p>\n<p>"
      +"</p>";
  }
  
  array parse_arg_array(string s)
  {
    if(!s)
      return 0;

    return ((s - " ")/",") - ({ "" });
  }
  
  string safe_container(string tag, mapping m, string cont)
  {
    return replace(Roxen.make_tag(tag, m),
		   ({ "<",">" }), ({ "\0[","\0]" }) ) + cont+"\0[/"+tag+"\0]";
  }
  
  string safe_tag(string tag, mapping m)
  {
    return replace(Roxen.make_tag(tag, m), ({ "<",">" }), ({ "\0[","\0]" }) );
  }
  
  string filter_body(string s, array keep_tags, array keep_containers)
  {
    s -= "\0";
    mapping allowed_tags =
      mkmapping(keep_tags, allocate(sizeof(keep_tags), safe_tag));
    
    mapping allowed_containers =
      mkmapping(keep_containers,
		allocate(sizeof(keep_containers), safe_container));
    
    return replace(
      parse_html(s, allowed_tags, allowed_containers),
      ({ "<",    ">",    "&",     "\0[", "\0]" }),
      ({ "&lt;", "&gt;", "&amp;", "<",   ">" }));
  }
  
  class Frame
  {
    inherit RXML.Frame;
    
    array do_return(RequestID id)
    {
      string res = 
	filter_body(content,
		    parse_arg_array(args["keep-tags"]) || ({ "br" }),
		    parse_arg_array(args["keep-containers"]) || ({ "b", "i"}));
      
      res = paragraphify(res);

      if(args->doublequote)
	res = Roxen.html_encode_string(res);
      
      return ({ res });
    }
  }
  
  void create()
  {
    req_arg_types = ([ ]);
    opt_arg_types = ([ "keep-tags":RXML.t_text(RXML.PXml),
		       "keep-containers":RXML.t_text(RXML.PXml),
		       "doublequote":RXML.t_text(RXML.PXml) ]);
  }
}


