// RXML Help
// Copyright © 2000, Roxen IS.
// Martin Nilsson
//

//#define RXMLHELP_DEBUG

#ifdef RXMLHELP_DEBUG
# define RXMLHELP_WERR(X) werror("RXML help: %s\n", X);
#else
# define RXMLHELP_WERR(X)
#endif

// --------------------- Layout help functions --------------------

#define TDBG "#d9dee7"

string mktable(array table) {
  string ret="<table boder=\"0\" cellpadding=\"0\" border=\"0\"><tr><td bgcolor=\"#000000\">\n"
    "<table border=\"0\" cellspacing=\"1\" cellpadding=\"5\">\n";

  foreach(table, array row)
    ret+="<tr valign=\"top\"><td bgcolor=\""+TDBG+"\"><font color=\"#000000\">"+
      row*("</font></td><td bgcolor=\""+TDBG+"\"><font color=\"#000000\">")+"</font></td></tr>\n";

  ret+="</table></tr></td></table>";
  return ret;
}

string available_languages(object id) {
  string pl;
  if(id->misc->pref_languages && (pl=id->misc->pref_languages->get_language()))
    if(!has_value(roxen->list_languages(),pl)) pl="en";
  else
    pl="en";
  mapping languages=roxen->language_low(pl)->list_languages();
  return mktable( map(sort(indices(languages) & roxen->list_languages()),
		      lambda(string code) { return ({ code, languages[code] }); } ));
}

// --------------------- Help layout functions --------------------

private string desc_cont(string t, mapping m, string c, string rt)
{
  string dt=rt;
  m->type=m->type||"";
  if(m->tag) dt=sprintf("&lt;%s/&gt;", rt);
  if(m->cont) dt=(m->tag?dt+" and ":"")+sprintf("&lt;%s&gt;&lt;/%s&gt;", rt, rt);
  if(m->plugin) {
    sscanf(dt,"%*s#%s",dt);
    dt="plugin "+dt;
  }
  return sprintf("<h2>%s</h2><p>%s</p>",dt,c);
}

private string attr_cont(string t, mapping m, string c)
{
  string p="";
  if(!m->name) m->name="(Not entered)";
  if(m->value) p=sprintf("<i>%s=%s</i><br />",m->name,attr_vals(m->value));
  return sprintf("<p><b>%s</b><br />%s%s</p>",m->name,p,c);
}

private string attr_vals(string v)
{
  if(has_value(v,"|")) return "{"+(v/"|")*", "+"}";
  // FIXME Use real config url
  // if(v=="langcodes") return "<a href=\"/help/langcodes.pike\">language code</a>";
  return v;
}

private string noex_cont(string t, mapping m, string c) {
  return parse_html(c, ([]), (["ex":""]));
}

private string ex_cont(string t, mapping m, string c, string rt, void|object id)
{
  if(!id) return "";
  string parsed=
    id->conf->parse_rxml(m->type!="hr"?
			 "<colorscope bgcolor="+TDBG+">"+c+"</colorscope>":
			 c, id);
  c="<pre>"+replace(c, ({"<",">","&"}), ({"&lt;","&gt;","&amp;"}) )+"</pre>";

  switch(m->type) {
  case "box":
    return "<br />"+mktable( ({ ({ c }) }) );
  case "hr":
    return c+"<hr />"+parsed;
  case "vert":
    return "<br />"+mktable( ({ ({ c }), ({ parsed }) }) );
  case "hor":
  default:
    return "<br />"+mktable( ({ ({ c, parsed }) }) );
  }
}

private string format_doc(string|mapping doc, string name, void|object id) {
  if(mappingp(doc)) {
    if(id && id->misc->pref_languages) {
      foreach(id->misc->pref_languages->get_languages()+({"en"}), string code) {
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

  return parse_html(doc, (["lang":lambda() { return available_languages(id); } ]), ([
    "desc":desc_cont,
    "attr":attr_cont,
    "ex":ex_cont,
    "noex":noex_cont,
    "tag":lambda(string tag, mapping m, string c) { return "&lt;"+c+"&gt;"; },
    "ref":lambda(string tag, mapping m, string c) { return c; },
    "short":lambda(string tag, mapping m, string c) { m->hide?"":c; }
  ]), name, id);
}


// ------------------ Parse docs in mappings --------------

private string parse_doc(string|mapping|array doc, string name, void|object id) {
  if(arrayp(doc))
    return format_doc(doc[0], name, id)+
      "<dl><dd>"+parse_mapping(doc[1], id)+"</dd></dl>";
  return format_doc(doc, name, id);
}

private string parse_mapping(mapping doc, void|object id) {
  string ret="";
  if(!mappingp(doc)) return "";
  foreach(sort(indices(doc)), string tmp) {
    ret+=parse_doc(doc[tmp], tmp, id);
  }
  return ret;
}


// --------------------- Find documentation --------------

mapping call_tagdocumentation(RoxenModule o) {
  if(!o->tagdocumentation) return 0;

  string name;
  if(o->is_configuration)
    name="RXML Core";
  else
    name=o->register_module()[1];

  mapping doc;
  if(!zero_type(doc=cache_lookup("tagdoc", name)))
    return doc;
  doc=o->tagdocumentation();
  RXMLHELP_WERR(sprintf("tagdocumentation() returned %t.",doc));
  if(!doc || !mappingp(doc)) {
    cache_set("tagdoc", name, 0);
    return 0;
  }
  cache_set("tagdoc", name, doc);
  return doc;
}

private int generation;
multiset undocumented_tags=(<>);
string find_tag_doc(string name, void|object id) {
  RXMLHELP_WERR("Help for tag "+name+" requested.");
  RXML.TagSet tag_set=RXML.get_context()->tag_set;
  string doc;
  int new_gen=tag_set->generation;

  if(generation!=new_gen) {
    undocumented_tags=(<>);
    generation=new_gen;
  }

  array tags=tag_set->get_overridden_tags(name);
  if(!sizeof(tags)) return "<h4>That tag ("+name+") is not defined</h4>";
  string plugindoc="";

  foreach(tags, array|object|function tag) {
    if(objectp(tag)) {
      // FIXME: New style tag. Check for internal documentation.
      mapping(string:RXML.Tag) plugins=tag_set->get_plugins(name);
      if(sizeof(plugins)) {
	plugindoc="<hr /><dl><dd>";
	foreach(sort(indices(plugins)), string plugin)
	  plugindoc+=find_tag_doc(name+"#"+plugin, id);
	plugindoc+="</dd></dl>";
      }
      if(tag->is_generic_tag)
	tag=tag->_do_return;
      else
	tag=object_program(tag);
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
    if(!tagdoc || !tagdoc[name]) continue;
    return parse_doc(tagdoc[name], name, id)+plugindoc;
  }

  undocumented_tags[name]=1;
  if(has_value(name,"#")) {
    sscanf(name,"%*s#%s", name);
    name="plugin "+name;
  }
  return "<h4>No documentation available for \""+name+"\".</h4>\n";
}

string find_module_doc( string cn, string mn, RequestID id )
{
  RXMLHELP_WERR("Help for module "+mn+" requested.");
  object c = roxen.find_configuration( cn );
  if(!c) return "";

  RoxenModule o = c->find_module( replace(mn,"!","#") );
  if(!o) return "";

  return parse_mapping(o->tagdocumentation());
}
