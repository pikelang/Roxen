// This is a roxen module. Copyright © 2000, Roxen IS.
//

#include <module.h>
inherit "module";

constant cvs_version = "$Id: html_wash.pike,v 1.4 2000/08/17 15:11:26 wellhard Exp $";
constant thread_safe = 1;
constant module_type = MODULE_PARSER;
constant module_name = "HTML washer";
constant module_doc  = ("This module provides a tag for washing HTML.");
constant module_unique = 1;

class TagWashHtml
{
  inherit RXML.Tag;
  constant name = "wash-html";
  Regexp link_regexp;
  
  string paragraphify(string s)
  {
    // more than one newline is considered a new paragraph
    return
      "<p>"+
      ((replace(replace(s - "\r" - "\0", "\n\n", "\0"),
		"\0\n", "\0")/"\0") - ({ "\n", "" }))*"</p>\n<p>"
      +"</p>";
  }
  
  string unparagraphify(string s)
  {
    return replace(s,
		   ({ "</p>\n<p>", "</p><p>", "<p>", "</p>" }),
		   ({ "\n\n",      "\n\n",    "",    "" }) );
  }
  
  array parse_arg_array(string s)
  {
    if(!s)
      return ({ });

    return ((s - " ")/",") - ({ "" });
  }
  
  string safe_container(string tag, mapping m, string cont)
  {
    return replace(Roxen.make_tag(tag, m),
		   ({ "<",">" }), ({ "\0[","\0]" }) ) + cont+"\0[/"+tag+"\0]";
  }
  
  string safe_tag(string tag, mapping m, string close_tags)
  {
    if(close_tags)
      m["/"] = "/";
    
    return replace(Roxen.make_tag(tag, m), ({ "<",">" }), ({ "\0[","\0]" }) );
  }
  
  string filter_body(string s, array keep_tags, array keep_containers,
		     string close_tags)
  {
    s -= "\0";
    mapping allowed_tags =
      mkmapping(keep_tags, allocate(sizeof(keep_tags), safe_tag));
    
    mapping allowed_containers =
      mkmapping(keep_containers,
		allocate(sizeof(keep_containers), safe_container));
    
    return replace(
      parse_html(s, allowed_tags, allowed_containers, close_tags),
      ({ "<",    ">",    "&",     "\0[", "\0]" }),
      ({ "&lt;", "&gt;", "&amp;", "<",   ">" }));
  }

  string link_dwim(string s)
  {
    Parser.HTML parser = Parser.HTML();
    
    parser->add_container("a", lambda(Parser.HTML p, mapping args)
			       { return ({ p->current() }); });
    
    parser->_set_data_callback(
      lambda(Parser.HTML p, string data)
      { return ({ link_regexp->
		  replace(data, lambda(string link)
				{ return "<a href='"+link+"'>"+
				    link+"</a>"; }) }); });
    
    return parser->finish(s)->read();
  }
  
  string unlink_dwim(string s)
  {
    string tag_a(string tag, mapping arg, string cont)
    {
      if(sizeof(arg) == 1 && arg->href == cont)
	return cont;
    };
    
    return parse_html(s, ([ ]), ([ "a":tag_a ]) );
  }
  
  class Frame
  {
    inherit RXML.Frame;
    
    array do_return(RequestID id)
    {
      string res = content;
      
      if(args->unparagraphify)
	res = unparagraphify(res);
      
      if(!args["keep-all"])
	res =
	  filter_body(res,
		      parse_arg_array(args["keep-tags"]),
		      parse_arg_array(args["keep-containers"]),
		      args["close-tags"]);
      
      if(args->paragraphify)
	res = paragraphify(res);
      
      if(args["link-dwim"])
	res = link_dwim(res);
	
      if(args["unlink-dwim"])
	res = unlink_dwim(res);
	
      if(args->quote)
	res = Roxen.html_encode_string(res);
      
      if(args->unquote)
	res = Roxen.html_decode_string(res);

      return ({ res });
    }
  }
  
  void create()
  {
    req_arg_types = ([ ]);
    opt_arg_types = ([ "keep-tags":RXML.t_text(RXML.PXml),
		       "keep-containers":RXML.t_text(RXML.PXml),
		       "quote":RXML.t_text(RXML.PXml),
		       "unquote":RXML.t_text(RXML.PXml),
		       "paragraphify":RXML.t_text(RXML.PXml),
                       "unparagraphify":RXML.t_text(RXML.PXml),
		       "keep-all":RXML.t_text(RXML.PXml) ]);
    
    link_regexp =
      Regexp("(((http)|(https)|(ftp))://([^ \t\n\r<]+)(\\.[^ \t\n\r<>\"]+)+)|"
	     "(((www)|(ftp))(\\.[^ \t\n\r<>\"]+)+)");
  }
}


