// This file is part of Roxen WebServer.
// Copyright © 2000 - 2009, Roxen IS.
//
// RXML Help by Martin Nilsson
//

// inherited by configuration.pike
#define parse_rxml Roxen.parse_rxml

#include <module.h>

#ifdef RXMLHELP_DEBUG
# define RXMLHELP_WERR(X) report_debug("RXML help: %s\n", X);
#else
# define RXMLHELP_WERR(X)
#endif

// --------------------- Layout help functions --------------------

#define TDBG "#d9dee7"

string mktable(array table) {
  string ret= "<table style='"
    "border: 1px solid black; "
    "border-collapse: collapse; "
    "background: " TDBG "; "
    "width: 100%; "
    "margin: 2px 0'>"
    "<tbody style='vertical-align: top'>\n";

  foreach(table, array row)
    ret+="<tr>"
      "<td style='border: 1px solid'>"+
      row * "</td><td style='border: 1px solid'>" +
      "</td></tr>\n";

  ret+="</tbody></table>";
  return ret;
}

string available_languages(object id) {
  string pl;
  if(id && id->misc->pref_languages && (pl=id->misc->pref_languages->get_language()))
    if(!has_value(roxen->list_languages(),pl)) pl="en";
  else
    pl="en";
  mapping languages=roxen->language_low(pl)->list_languages();
  return mktable( map(sort(indices(languages) & roxen->list_languages()),
		      lambda(string code) { return ({ code, languages[code] }); } ));
}

// --------------------- Help layout functions --------------------

protected class TagdocParser (int level)
{
  inherit Parser.HTML;
  mapping misc = ([]);

  TagdocParser clone()
  {
    TagdocParser c = ::clone (level);
    xml_tag_syntax (2);
    c->misc = misc;
    return c;
  }
}

// Header tags for different levels.
protected array(array(array(string))) hdr_tags = ({
  // Top level (0).
  ({({"<h2>", "</h2>"}), // Top header
    ({"<h3>", "</h3>"}), // Subheaders (Attributes/Defined in content/etc)
    ({"<h4>", "</h4>"})}), // <h1> inside doc.

  // Sublevel 1.
  ({({"<h3>", "</h3>"}),
    ({"<h4>", "</h4>"}),
    ({"<h5>", "</h5>"})}),

  // Sublevel 2.
  ({({"<h4>", "</h4>"}),
    ({"<h5>", "</h5>"}),
    ({"<h6>", "</h6>"})}),

  // Sublevel 3 (shouldn't occur).
  ({({"<h5>", "</h5>"}),
    ({"<h6>", "</h6>"}),
    ({"<h6>", "</h6>"})}),
});

#define NEXT_HDR_LEVEL(LEVEL) min ((LEVEL) + 1, sizeof (hdr_tags) - 1)

protected array desc_cont(TagdocParser parser, mapping m, string c, string rt)
{
  string type;
  if(m->tag)	type = "tag";
  if(m->cont)	type = "cont";
  if(m->cont &&
     m->tag)	type = "both";
  if(m->plugin)	type = "plugin";
  if(m->ent)	type = "entity";
  if(m->scope)	type = "scope";
  if(m->pi)	type = "pi";
  if(m->type)	type = m->type;
  switch(type)
  {
    case "tag":    rt = sprintf("&lt;%s/&gt;", rt); break;
    case "cont":   rt = sprintf("&lt;%s&gt;&lt;/%s&gt;", rt, rt); break;
    case "both":   rt = sprintf("&lt;%s/&gt; or "
				"&lt;%s&gt;&lt;/%s&gt;",
				rt, rt, rt); break;
    case "plugin": rt = String.capitalize (replace(rt, "#", " plugin ")); break;
  //case "entity": rt = rt; break;
    case "scope":  rt = rt[..sizeof(rt)-2] + " ... ;";
    case "pi":     rt = "&lt;" + rt + " ... ?&gt;";
  }
  return ({sprintf("\n%s%s%s\n<p>%s</p>\n",
		   hdr_tags[parser->level][0][0],
		   parser->clone()->finish(rt)->read(),
		   hdr_tags[parser->level][0][1],
		   parser->clone()->finish(c)->read())});
}

protected array attr_cont(TagdocParser parser, mapping m, string c)
{
  string p="";
  if(!m->name) m->name="(Not entered)";
  if(m->value) p=sprintf("<i>%s=%s</i>%s<br />",
			 m->name,
			 attr_vals(m->value),
			 m->default?" ("+m->default+")":""
			 );
  if(m->required) p+="<i>This attribute is required.</i><br />";
  p = sprintf("<p><dl><dt><b>%s</b></dt><dd>%s%s</dd></dl></p>",m->name,p,c);

  if (!parser->misc->got_attrs) {
    parser->misc->got_attrs = 1;
    p = hdr_tags[parser->level][1][0] +
      "Attributes" +
      hdr_tags[parser->level][1][1] +
      p;
  }

  return ({parser->clone()->finish(p)->read()});
}

protected string attr_vals(string v)
{
  if(has_value(v,"|")) return "{"+(v/"|")*", "+"}";
  // FIXME Use real config url
  // if(v=="langcodes") return "<a href=\"/help/langcodes.pike\">language code</a>";
  return v;
}

protected string noex_cont(TagdocParser parser, mapping m, string c) {
  return Parser.HTML()->add_container("ex","")->
    add_quote_tag("!--","","--")->feed(c)->read();
}

protected string ex_quote(string in)
{
  sscanf (reverse (in), "%[ \t\n\r]", string trailing_ws);
  if (has_prefix (in, "\n"))
    in = in[1..<sizeof (trailing_ws)];
  else
    in = in[..<sizeof (trailing_ws)];

  // FIXME: Find out why we have the "&lt;" inconsistency and eliminate it.
  return "<div style='white-space: pre; font-family: monospace'>" +
    replace(in,
	    ({"<",    ">",    "&",     "&lt;"}),
	    ({"&lt;", "&gt;", "&amp;", "&lt;"}) )+"</div>";
}

protected string ex_cont(TagdocParser parser, mapping m, string c, string rt, void|object id)
{
  c=Parser.HTML()->add_container("ent", lambda(Parser.HTML parser, mapping m, string c) {
					  return "&amp;"+c+";"; 
					} )->feed(c)->read();
  string quoted = ex_quote(c);
  if(m->type=="box")
    return mktable( ({ ({ quoted }) }) );

  if (m->type != "hr")
    c = "<colorscope bgcolor="+TDBG+">"+c+"</colorscope>";

  string parsed;

  if (!m["keep-var-scope"])
    RXML_CONTEXT->add_scope ("var", ([]));

  if (m["any-result"]) {
    // Use if the example returns a non-xml result, e.g. an array.
    RXML.Parser p = RXML.t_any (id->conf->default_content_type->parser_prog)->
      get_parser (RXML_CONTEXT, RXML_CONTEXT->tag_set);
    p->write_end (c);
    mixed res = p->eval();
    parsed = String.capitalize (sprintf ("%t result: ", res)) +
      Roxen.html_encode_string (RXML.utils.format_short (res, 1024));
  }
  else {
    RXML.Parser p =
      id->conf->default_content_type->
      get_parser (RXML_CONTEXT, RXML_CONTEXT->tag_set);
    p->write_end (c);
    parsed = p->eval();
  }

  switch(m->type) {
  case "hr":
    return quoted+"<hr />"+parsed;
  case "svert":
    return mktable( ({ ({ quoted }), ({ ex_quote(parsed) }) }) );
  case "shor":
    return mktable( ({ ({ quoted, ex_quote(parsed) }) }) );
  case "vert":
  default:
    return mktable( ({ ({ quoted }), ({ parsed }) }) );
  case "hor":
    return mktable( ({ ({ quoted, parsed }) }) );
  }
}

protected string ex_box_cont(TagdocParser parser, mapping m, string c, string rt) {
  return mktable( ({ ({ ex_quote(c) }) }) );
}

protected string ex_html_cont(TagdocParser parser, mapping m, string c, string rt) {
  return mktable( ({ ({ c }) }) );
}

protected string ex_src_cont(TagdocParser parser, mapping m, string c, string rt, void|object id) {
  string quoted = ex_quote(c);
  string parsed = parse_rxml("<colorscope bgcolor="+TDBG+">"+c+"</colorscope>", id);
  return mktable( ({ ({ quoted }), ({ ex_quote(parsed) }) }) );
}

protected string list_cont( TagdocParser parser, mapping m, string c )
{
  string type = m->type || "ul";
  return "<"+type+">"+
    Parser.HTML()->
    add_containers( ([ "item":lambda(Parser.HTML p, mapping m, string c) {
				return ({
				  "<li>"+
				  (m->name ? "<b>"+m->name+"</b><br />" : "")+
				  c+"</li>" });
			      } ]) )->finish(c)->read()+
    "</"+type+">";
}

protected string xtable_cont( mixed a, mixed b, string c )
{
  return "<table>"+c+"</table>";
}

protected string module_cont( mixed a, mixed b, string c )
{
  return "<i>"+c+"</i>";
}

protected string xtable_row_cont( mixed a, mixed b, string c )
{
  return "<tr>"+c+"</tr>";
}

protected string xtable_c_cont( mixed a, mixed b, string c )
{
  return "<td>"+c+"</td>";
}

protected string xtable_h_cont( mixed a, mixed b, string c )
{
  return "<th>"+c+"</th>";
}

protected string help_tag( TagdocParser p, mapping m, string c )
{
  if( m["for"] )
    return find_tag_doc( m["for"], RXML.get_context()->id,0,
			 NEXT_HDR_LEVEL (p->level));
  return 0; // keep.
}

protected string webserver_tag( mixed a, mixed b, string c )
{
  return roxen_product_name;
}


protected string format_doc(string|mapping doc, string name, object id, int level)
{
  if(mappingp(doc)) {
    if(id->misc->pref_languages) {
      foreach(id->misc->pref_languages->get_languages()+({"en"}), string code)
      {
	object lang=roxen->language_low(code);
	if(lang) {
	  array lang_id=lang->id();
	  if(doc[lang_id[2]]) {
	    doc=doc[lang_id[2]];
	    break;
	  }
	  if(doc[lang_id[1]]) {
	    doc=doc[lang_id[1]];
	    break;
	  }
	}
      }
    }
    else
      doc=doc->standard;
  }

  name=replace(name, ({ "<", ">", "&" }), ({ "&lt;", "&gt;", "&amp;" }) );

  return TagdocParser (level)->
         add_tag( "lang",lambda() { return available_languages(id); } )->
         add_tag( "help", help_tag )->
         add_tag( "webserver", webserver_tag )->
         add_containers( ([
           "list":list_cont,
           "xtable":xtable_cont,
           "row":xtable_row_cont,
           "c":xtable_c_cont,
           "h":xtable_h_cont,
           "module":module_cont,
           "desc":desc_cont,
           "attr":attr_cont,
           "ex":ex_cont,
	   "ex-box":ex_box_cont,
	   "ex-src":ex_src_cont,
	   "ex-html":ex_html_cont,
           "noex":noex_cont,
           "tag":lambda(TagdocParser p, mapping m, string c) {
                   return ({ "&lt;"+c+"&gt;" });
                 },
	   "ent":lambda(TagdocParser p, mapping m, string c) {
		   return ({ "&amp;" + c + ";" });
		 },

	   "xref":lambda(TagdocParser p, mapping m, string c) {
		    string ref = m->href;
		    if( ref ) {
		      int is_tag = sscanf(ref, "%s.tag", ref);

		      if (!is_tag && has_suffix (ref, "/")) {
			// There are references that look like <xref
			// href='../if/'/>. Assume it's the tag name
			// in the path.
			ref = (ref/"/")[-2];
			is_tag = 1;
		      }
		      else
			ref = (ref/"/")[-1];

		      if (!c || !sizeof (c))
			c = Roxen.html_encode_string (replace(ref, "_", " "));

		      if (is_tag && ref != "")
			c = "<a href='#tag_doc_" +
			  Roxen.http_encode_url (ref) + "'>"
			  "&lt;" + c + "&gt;"
			  "</a>";
		    }

		    return c;
		  },

           "short":lambda(TagdocParser p, mapping m, string c) {
                     return m->hide?"":c; 
                   },
	   "note":lambda(TagdocParser p, mapping m, string c) {
		    return c;
		  },
	   "h1": lambda (TagdocParser p, mapping m, string c) {
		   return ({hdr_tags[p->level][2][0],
			    p->clone()->finish(c)->read(),
			    hdr_tags[p->level][2][1]});
		 },
	 ]) )->
    add_quote_tag("!--","","--")->
    set_extra(name, id)->finish(doc)->read();
}


// ------------------ Parse docs in mappings --------------

protected string parse_doc(string|mapping|array doc, string name, object id, int level) {
  if(arrayp(doc) && (sizeof( doc ) == 2) ) {
    string top = format_doc(doc[0], name, id, level);
    string sub = parse_mapping(doc[1], id, NEXT_HDR_LEVEL (level));
    if (sizeof (sub))
      return top +
	hdr_tags[level][1][0] + "Defined in content" + hdr_tags[level][1][1] +
	"<dl><dd>" + sub + "</dd></dl>";
    else
      return top;
  }
  if( arrayp( doc ) && sizeof(doc) )
    return format_doc( doc[0], name, id, level);
  return format_doc(doc, name, id, level);
}

protected string parse_mapping(mapping doc, object id, int level) {
  string ret="";
  if(!mappingp(doc)) return "";
  foreach(sort(indices(doc)), string tmp) {
    ret+=parse_doc(doc[tmp], tmp, id, level);
  }
  return ret;
}

string parse_all_doc(RoxenModule o, void|RequestID id) {
  mapping doc = call_tagdocumentation(o);
  if(!doc) return 0;
  string ret = "";
  foreach(sort(indices(doc)), string tagname)
    ret += parse_doc(doc[tagname], tagname, id, 0);
  return ret;
}

// --------------------- Find documentation --------------

mapping call_tagdocumentation(RoxenModule o) {
  if(!o->tagdocumentation) return 0;

  string name = o->register_module()[1];

  mapping doc;
  if(!zero_type(doc=cache_lookup("tagdoc", name)))
    return doc;
  doc=o->tagdocumentation();
  RXMLHELP_WERR(sprintf("tagdocumentation() returned %t.",doc));
  if(!doc || !mappingp(doc)) {
    cache_set("tagdoc", name, 0);
    return 0;
  }
  RXMLHELP_WERR("("+String.implode_nicely(indices(doc))+")");
  cache_set("tagdoc", name, doc);
  return doc;
}

protected int generation;
multiset undocumented_tags=(<>);

string find_tag_doc(string name, RequestID id, int|void no_undoc,
		    int|void level, void|mapping(string:int) documented_tags)
{
  RXMLHELP_WERR("Help for tag "+name+" requested.");

  if (documented_tags) {
    if (documented_tags[name]) {
      RXMLHELP_WERR("Already documented.");
      return "";
    }
    documented_tags[name] = 1;
  }

  if( !id )
    error("find_tag_doc called without ID-object\n");

  RXML.TagSet tag_set = id->conf->rxml_tag_set;

  RXML.Context old_ctx, new_ctx;
  if (!level) {
    old_ctx = RXML.get_context();
    new_ctx = tag_set->new_context (id);
    // Fake one frame depth so that the context doesn't get finished
    // after the first parse_rxml or similar. Have to do this since no
    // real rxml parser is used on the top level here.
    new_ctx->frame_depth = 1;
    RXML.set_context (new_ctx);
  }

  int new_gen=tag_set->generation;

  if(generation!=new_gen)
  {
    undocumented_tags=(<>);
    generation=new_gen;
  }

  array tags;

  if(name[0]=='?') {
    RXMLHELP_WERR("<"+name+"?> is a processing instruction.");
    object tmp=tag_set->get_tag(name[1..], 1);
    if(tmp)
      tags=({ tmp });
    else
      tags=({});
  }
  else
    tags=tag_set->get_overridden_tags(name);

  if(!sizeof(tags))
  {
    if( !level ) {
      new_ctx->frame_depth = 0;
      new_ctx->eval_finish();
      RXML.set_context( old_ctx );
    }
    return no_undoc ? "" : "<h4>The tag (" +
      Roxen.html_encode_string(name) +
      ") is unknown</h4>";
  }

  foreach(tags, array|object|function tag) {
    if(objectp(tag)) {
      // FIXME: New style tag. Check for internal documentation.
      if(tag->is_compat_tag) {
	RXMLHELP_WERR(sprintf("CompatTag %O", tag));
	tag=tag->fn;
      }
      else if(tag->is_generic_tag) {
	RXMLHELP_WERR(sprintf("GenericTag %O", tag));
	tag=tag->_do_return;
      }
      else {
	RXMLHELP_WERR(sprintf("NormalTag %O", tag));
	tag=object_program(tag);
      }
    }
    else if(arrayp(tag)) {
      if(tag[0])
	tag=tag[0][1];
      else if(tag[1])
	tag=tag[1][1];
    }
    else
      continue;
    if(!functionp(tag)) continue;
    tag=function_object(tag);
    if(!objectp(tag)) continue;
    RXMLHELP_WERR(sprintf("Tag defined in module %O", tag));

    mapping tagdoc=call_tagdocumentation(tag);
    if(!tagdoc || !tagdoc[name]) {
      RXMLHELP_WERR(name+" not present in result.");
      continue;
    }
    string res =
      "<a name='tag_doc_" + Roxen.html_encode_string (name) + "'></a>\n" +
      parse_doc(tagdoc[name], name, id, level);

    mapping(string:RXML.Tag) plugins=tag_set->get_plugins(name);
    if(sizeof(plugins)) {
      foreach(sort(indices(plugins)), string plugin)
	res += find_tag_doc(name+"#"+plugin, id,no_undoc,
			    NEXT_HDR_LEVEL (level), documented_tags);
    }

    if( !level ) {
      new_ctx->frame_depth = 0;
      new_ctx->eval_finish();
      RXML.set_context( old_ctx );
    }
    return res;
  }

  undocumented_tags[name]=1;
  if(has_value(name,"#")) {
    sscanf(name,"%*s#%s", name);
    name="plugin "+name;
  }
  if( !level ) {
    new_ctx->frame_depth = 0;
    new_ctx->eval_finish();
    RXML.set_context( old_ctx );
  }
  return (no_undoc ? "" : 
	  "<h4>No documentation available for \"" +
	  Roxen.html_encode_string(name) +
	  "\".</h4>\n");
}

string find_module_doc( string cn, string mn, RequestID id )
{
  RXMLHELP_WERR("Help for module "+mn+" requested.");
  object c = roxen.find_configuration( cn );
  if(!c) return "";

  RoxenModule o = c->find_module( replace(mn,"!","#") );
  if(!o) return "";

  return parse_mapping(o->tagdocumentation(), 0, 0);
}
