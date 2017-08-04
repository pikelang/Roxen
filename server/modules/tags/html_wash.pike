// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.
//

#include <module.h>
inherit "module";

constant cvs_version = "$Id$";
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

  array safe_container(Parser.HTML p, mapping args, string cont,
			string close_tags, mapping keep_attrs)
  {
    string tag = lower_case(p->tag_name());
    if(keep_attrs)
      args &= (keep_attrs[tag] || ({ }));
    Parser.HTML parser = p->clone();
    string res = parser->finish(cont)->read();
    return ({ replace(Roxen.make_tag(tag, args), ({ "<",">" }), ({ "\0[","\0]" })) +
	      res + "\0[/"+tag+"\0]" });
  }

  array safe_tag(Parser.HTML p, mapping args,
		  string close_tags, mapping keep_attrs)
  {
    string tag = lower_case(p->tag_name());
    if(keep_attrs)
      args &= (keep_attrs[tag] || ({ }));
    
    return ({ replace(RXML.t_xml->format_tag(tag, args, 0, (close_tags?0:
							    RXML.FLAG_COMPAT_PARSE|
							    RXML.FLAG_EMPTY_ELEMENT)),
		      ({ "<",">" }), ({ "\0[","\0]" }) ) });
  }

  string filter_body(string s, array keep_tags, array keep_containers,
		     string close_tags, string keep_attributes, string remove_unwanted_tags)
  {
    // Replace < and > with \1 and \2 in stead of quoting with &lt; and &gt; to
    // be able regexp match on single characters.
    // \0 is used to keep allowed tags.
    s -= "\0";
    s -= "\1";
    s -= "\2";

    mapping keep_attrs;
    if(keep_attributes)
    {
      keep_attrs = ([ ]);
      foreach(keep_attributes/",", string entry)
      {
	if(sscanf(entry, "%s:%s", string tag, string attr) == 2)
	  keep_attrs[tag] = (keep_attrs[tag] || ({ })) + ({ attr });
      }
    }

    Parser.HTML parser = Parser.HTML();
    parser->case_insensitive_tag(1);
    parser->set_extra(close_tags, keep_attrs);
    
    foreach(keep_tags, string tag)
      parser->add_tag(tag, safe_tag);
    
    foreach(keep_containers, string container)
      parser->add_container(container, safe_container);
    
    if(remove_unwanted_tags)
      parser->_set_tag_callback( lambda(Parser.HTML p, string str, mixed... extra) { 
            return "";
          });

    return replace(parser->finish(s)->read(),
		   ({ "<",  ">",  "&",     "\0[", "\0]" }),
		   ({ "\1", "\2", "&amp;", "<",   ">" }));
  }

  string linkify(string s, void|mapping attrs)
  {
    string fix_link(string l)
    {
      if (has_prefix(l, "http://") ||
	  has_prefix(l, "https://") ||
	  has_prefix(l, "ftp://") ||
	  has_prefix(l, "mailto:"))
	return l;
      
      if (has_prefix(l, "ftp."))
	return "ftp://" + l;

      return "http://"+l;
    };

    string attrs_string = "";

    if (attrs && sizeof(attrs)) {
      attrs_string = Roxen.make_tag_attributes(attrs);
    }

    Parser.HTML parser = Parser.HTML();
    parser->add_container("a", lambda(Parser.HTML p, mapping args)
			       { return ({ p->current() }); });
    parser->_set_data_callback(
      lambda(Parser.HTML p, string data)
      { return ({ utf8_to_string(link_regexp->
		  replace(string_to_utf8(data), lambda(string link)
                                {
                                  link = fix_link(link);
                                  return sprintf("<a href='%s'%s>%s</a>",
                                                 link, attrs_string, link);
				}) ) }); });

    string res = parser->finish(s)->read();
    parser = 0;			// Avoid trampoline garbage.
    return res;
  }

  string remove_illegal_chars(string s)
  {
    string result = "";

    while(sizeof(s))
    {
      string rest = "";
      sscanf(s, "%s%*[\x0-\x8\xb\xc\xe-\x1f\x7f-\x84\x86-\x9f]%s", s, rest);
      result += s;
      s = rest;
    }

    return result;
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
			     args["close-tags"],
			     args["keep-attributes"],
           args["remove-unwanted-tags"]);

      if(args->paragraphify)
	result = paragraphify(result);

      if(args["linkify"]) {
        mapping attrs = ([]);

        if (args["link-target"]) {
          attrs->target = args["link-target"];
        }

        if (args["link-rel"]) {
          attrs->rel = args["link-rel"];
        }

        result = linkify(result, attrs);
      }

      if (!args["keep-all"])
	result = replace(result, ({ "\1", "\2" }), ({ "&lt;", "&gt;" }));

      if(args["remove-illegal-xml-chars"])
	result = remove_illegal_chars(result);

      return 0;
    }
  }

  void create()
  {
    req_arg_types = ([ ]);
    opt_arg_types = ([ "keep-all":RXML.t_text(RXML.PXml),
		       "keep-tags":RXML.t_text(RXML.PXml),
		       "keep-containers":RXML.t_text(RXML.PXml),
		       "keep-attributes":RXML.t_text(RXML.PXml),
		       "paragraphify":RXML.t_text(RXML.PXml),
                       "unparagraphify":RXML.t_text(RXML.PXml),
                       "linkify":RXML.t_text(RXML.PXml),
                       "link-target":RXML.t_text(RXML.PXml),
                       "link-rel":RXML.t_text(RXML.PXml),
                       "unlinkify":RXML.t_text(RXML.PXml),
           "close-tags":RXML.t_text(RXML.PXml),
           "remove-unwanted-tags":RXML.t_text(RXML.PXml) ]);

#define VALID_CHARS "[^ \t\n\r<>\"'`(){}|\1\2]"
    link_regexp =
      Regexp("(((http)|(https)|(ftp))://(" VALID_CHARS "+)(\\." VALID_CHARS "+)+)|"
	     "(((www)|(ftp))(\\." VALID_CHARS "+)+)");
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

  <hr />A little image:<img src='/internal-roxen-next' />.
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

  <hr />A litle image:<img src='/internal-roxen-next' />.
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

  <hr />A little image:<img src='/internal-roxen-next' />.
</wash-html>
</ex>
</attr>

<attr name='keep-attributes' value='list'><p>
 List of attributes to preserve in keep-containers and keep-tags.
 If the attribute is omitted all attributes for tags will be
 preserved. The format is tag1:attribute1,tag1:attribute2,tag2:attribute1...
 Useful for allowing tags but not attributes, i.e. allow the &lt;quote&gt;
 tag but not attributes such as onclick etc.</p>

<ex><wash-html keep-containers=\"a,font\">
  <a href=\"http://docs.roxen.com\">Roxen docs</a>
  <font style=\"color:red;\">Text</font>
</wash-html></ex>

<p>Note that all attributes for preserved tags are kept.</p>

<ex><wash-html keep-containers=\"a,font\" keep-attributes=\"a:href\">
  <a href=\"http://docs.roxen.com\">Roxen docs</a>
  <font style=\"color:red;\">Text</font>
</wash-html></ex>

<p>Only the href attribute for the a tag is kept.</p>

</attr>

<attr name='remove-unwanted-tags'><p>
  Removes tags not listed in keep-tags or keep-containers instead of html escaping them.
  Container content is preserved.
</p>

<ex><wash-html keep-containers=\"div\">
  <span style=\"color: blue;\">span content</span><div style=\"color: red;\">div content</div>
</wash-html></ex>
<ex><wash-html remove-unwanted-tags=\"yes\" keep-containers=\"div\">
  <span style=\"color: blue;\">span content</span><div style=\"color: red;\">div content</div>
</wash-html></ex>
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

<attr name='link-target'><p>
  If the linkify attribute is used, set the link target to this.</p> 
</attr>

<attr name='link-rel'><p>
  If the linkify attribute is used, set the link attribute 'rel' to this.</p>
</attr>

<attr name='unlinkify'><p>
 Undo a linkify-conversion. Only the links that has the same label as
 address will be converted to plain text.</p>

<ex><wash-html unlinkify='1' keep-tags='br' keep-containers='a'>
  <a href=\"http://www.roxen.com\">http://www.roxen.com</a><br />
  <a href=\"http://www.roxen.com\">Roxen IS</a>
</wash-html></ex>
</attr>

<attr name='remove-illegal-xml-chars'><p>
 Removes illegal and discouraged XML characters. Legal characters 
 include #x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] |
 [#x10000-#x10FFFF]. Discouraged characters include
 [#x7F-#x84], [#x86-#x9F], [#xFDD0-#xFDDF],
 [#1FFFE-#x1FFFF], [#2FFFE-#x2FFFF], [#3FFFE-#x3FFFF],
 [#4FFFE-#x4FFFF], [#5FFFE-#x5FFFF], [#6FFFE-#x6FFFF],
 [#7FFFE-#x7FFFF], [#8FFFE-#x8FFFF], [#9FFFE-#x9FFFF],
 [#AFFFE-#xAFFFF], [#BFFFE-#xBFFFF], [#CFFFE-#xCFFFF],
 [#DFFFE-#xDFFFF], [#EFFFE-#xEFFFF], [#FFFFE-#xFFFFF],
 [#10FFFE-#x10FFFF]</p>
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
