// This is a roxen module. Copyright © 2000 - 2001, Roxen IS.
//

#include <module.h>
inherit "module";

constant cvs_version = "$Id: html_wash.pike,v 1.28 2004/05/27 18:28:44 _cvs_stephen Exp $";
constant thread_safe = 1;
constant module_type = MODULE_TAG;
constant module_name = "Tags: HTML washer";
constant module_doc  =
#"<p>This module provides a &lt;wash-html&gt; tag that is perhaps most
useful for turning user freetext input from a form into HTML
intelligently; perhaps turning sections separated by more than one
newline into &lt;p&gt;paragraphs&lt;/p&gt;, filtering out or
explicitly allowing some HTML tags in the input</p>

<p>Usage example:</p>

<pre>&lt;form&gt;
 &lt;textarea name=input&gt;&amp;form.input;&lt;/textarea&gt;
 &lt;input type='submit'&gt;
&lt;form&gt;

&lt;wash-html link-dwim='yes'
 paragraphify='yes'&gt;&amp;form.input:none;&lt;/wash-html&gt;</pre>";

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
    return replace(replace(s, ({ "<P>", "</P>" }), ({ "<p>", "</p>" })),
		   ({ "</p>\n<p>", "</p>\r\n<p>", "</p><p>", "<p>", "</p>" }),
		   ({ "\n\n",      "\n\n",        "\n\n",    "",    "" }) );
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
    return replace(RXML.t_xml->format_tag(tag, m, 0, (close_tags?0:
						      RXML.FLAG_COMPAT_PARSE|
						      RXML.FLAG_EMPTY_ELEMENT)),
		   ({ "<",">" }), ({ "\0[","\0]" }) );
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

  string linkify(string s)
  {
    string fix_link(string l)
    {
      if(l[0..6] == "http://" || l[0..7] == "https://" || l[0..5] == "ftp://")
	return l;
      
      if(l[0..3] == "ftp.")
	return "ftp://"+l;

      return "http://"+l;
    };

    Parser.HTML parser = Parser.HTML();

    parser->add_container("a", lambda(Parser.HTML p, mapping args)
			       { return ({ p->current() }); });
    parser->_set_data_callback(
      lambda(Parser.HTML p, string data)
      { return ({ utf8_to_string(link_regexp->
		  replace(string_to_utf8(data), lambda(string link)
				{
				  link = fix_link(link);
				  return "<a href='"+link+"'>"+
				    link+"</a>";
				}) ) }); });

    return parser->finish(s)->read();
  }

  string unlinkify(string s)
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
      result = content||"";

      if(args->unparagraphify)
	result = unparagraphify(result);

      if(args["unlinkify"])
	result = unlinkify(result);

      if(!args["keep-all"])
	result = filter_body(result,
			     parse_arg_array(args["keep-tags"]),
			     parse_arg_array(args["keep-containers"]),
			     args["close-tags"]);

      if(args->paragraphify)
	result = paragraphify(result);

      if(args["linkify"])
	result = linkify(result);

      return 0;
    }
  }

  void create()
  {
    req_arg_types = ([ ]);
    opt_arg_types = ([ "keep-all":RXML.t_text(RXML.PXml),
		       "keep-tags":RXML.t_text(RXML.PXml),
		       "keep-containers":RXML.t_text(RXML.PXml),
		       "paragraphify":RXML.t_text(RXML.PXml),
                       "unparagraphify":RXML.t_text(RXML.PXml),
                       "linkify":RXML.t_text(RXML.PXml),
                       "unlinkify":RXML.t_text(RXML.PXml),
		       "close-tags":RXML.t_text(RXML.PXml) ]);

    link_regexp =
      Regexp("(((http)|(https)|(ftp))://([^ \t\n\r<]+)(\\.[^ \t\n\r<>\"]+)+)|"
	     "(((www)|(ftp))(\\.[^ \t\n\r<>\"]+)+)");
  }
}

// --------------------- Documentation -----------------------

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"wash-html":#"<desc type='cont'><p><short hide='hide'>
 Turns a text into HTML.</short>This tag is mostly useful for turning
 user freetext input from a form into HTML intelligently, by turning
 sections of the text separated by more than one newline into
 <tag>p</tag>paragraphs<tag>/p</tag>, filtering out or explicitly
 allowing some HTML tags in the input and creating
 <tag>a</tag>anchor-links<tag>/a</tag> out of potential www-addresses.
</p></desc>

<attr name='keep-all'><p>
 Leave all tags containing info intact. Overrides the value of
 keep-tags and keep-containers. This attribute is useful together with
 the attributes <att>unparagraphify</att> and <att>unlink</att>.</p>

<ex><wash-html keep-all='1'>
  Some text, <i>italic</i>, <b>bold</b>,
  <i><b>bold italic</b></i>.

  <hr />A little image:<imgs src='/%01/next' />.
</wash-html></ex>
</attr>

<attr name='keep-tags' value='list'><p>
 Comma-separated array of empty element <tag>tags</tag> not to
 filter. Quote all other empty element tags, i.e. transform \"&lt;\",
 \"&gt;\" and \"&amp;\" to \"&amp;lt;\", \"&amp;gt;\" and
 \"&amp;amp;\".</p>

<ex><wash-html keep-tags='hr'>
  Some text, <i>italic</i>, <b>bold</b>,
  <i><b>bold italic</b></i>.

  <hr />A litle image:<imgs src='/%01/next' />.
</wash-html></ex>
</attr>

<attr name='keep-containers' value='list'><p>
 Comma-separated array of <tag>container</tag>...<tag>/</tag> tags not
 to filter. Quote all other container tags, i.e. transform \"&lt;\",
 \"&gt;\" and \"&amp;\" to \"&amp;lt;\", \"&amp;gt;\" and
 \"&amp;amp;\".</p>

<ex><wash-html keep-containers='b'>
  Some text, <i>italic</i>, <b>bold</b>,
  <i><b>bold italic</b></i>.

  <hr />A little image:<imgs src='/%01/next' />.
</wash-html>
</ex>
</attr>

<attr name='linkify'><p>
 Makes text that looks like it might be useful as a link, e g
 http://www.roxen.com/, into a link. Text that starts with
 \"http://\", \"https://\", \"ftp://\", \"www.\" or \"http.\" will be
 converted to a clickable link with the text as the link label.</p>

<ex><wash-html linkify='a' keep-containers='a' keep-tags='br'>
  <a href=\"http://docs.roxen.com\">Roxen docs</a><br />
  http://pike.roxen.com<br />
  www.roxen.com
</wash-html></ex>
</attr>

<attr name='unlinkify'><p>
 Undo a linkify-conversion. Only the links that has the same label as
 address will be converted to plain text.</p>

<ex><wash-html unlinkify='1' keep-tags='br' keep-containers='a'>
  <a href=\"http://www.roxen.com\">http://www.roxen.com</a><br />
  <a href=\"http://www.roxen.com\">Roxen IS</a>
</wash-html></ex>
</attr>

<attr name='paragraphify'><p>
 If more than one newline exists between two text elements, this
 attribute automatically makes the next text element into a
 paragraph.</p>

<ex-src><wash-html paragraphify='1'>
A Paragraph

Another paragraph.
Some more text to the same paragraph.
</wash-html></ex-src>
</attr>

<attr name='unparagraphify'>
<p>Turn paragraph breaks into double newlines instead.</p>

<ex-src><wash-html unparagraphify='1'>
<p>A Paragraph</p>
<p>Another paragraph.
Some more text to the same paragraph.</p>
</wash-html></ex-src>

<p>The <tag>pre</tag> is only used in the example for layout-purposes.</p>
</attr>

<attr name='close-tags'><p>
 Terminate all tags with an ending slash, making them XML-compliant.</p>
</attr>",

    ]);
#endif
