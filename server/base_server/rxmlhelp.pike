// RXML Help 
// Copyright (c) 2000 Idonex AB
// Martin Nilsson
//

// --------------------- Help Layout --------------------

private string desc_cont(string t, mapping m, string c, string rt)
{
  string dt=rt;
  m->type=m->type||"";
  if(m->tag) dt=sprintf("&lt;%s/&gt;", rt);
  if(m->cont) dt=(m->tag?dt+" and ":"")+sprintf("&lt;%s&gt;&lt;/%s&gt;", rt, rt);
  return sprintf("<h2>%s</h2><p>%s</p>",dt,c);
}

private string attr_cont(string t, mapping m, string c)
{
  string p="";
  if(!m->name) m->name="(Not entered)";
  if(m->value) p=sprintf("<i>%s=%s</i><br>",m->name,attr_vals(m->value));
  return sprintf("<p><b>%s</b><br>%s%s</p>",m->name,p,c);
}

private string attr_vals(string v)
{
  if(search(v,",")!=-1) return "{"+(v/",")*", "+"}";
  //FIXME Use real config url
  if(v=="langcodes") return "<a href=\"/help/langcodes.pike\">language code</a>";
  return v;
}

private string ex_cont(string t, mapping m, string c, string rt, void|object id)
{
  if(!id) return "";
  string parsed=id->conf->parse_rxml(c,id);
  c=replace(c, ({"<",">","&"}), ({"&lt;","&gt;","&amp;"}) );

  switch(m->type) {
  case "hr":
    return c+"<hr>"+parsed;
  case "vert":
    return "<br><table boder=\"0\" cellpadding=\"0\" border=\"0\"><tr><td bgcolor=\"#000000\">"
      "<table border=\"0\" cellspacing=\"1\" cellpadding=\"5\">\n"
      "<tr><td bgcolor=\"#d9dee7\">"+c+"</td></tr>\n"
      "<tr><td bgcolor=\"#d9dee7\">"+parsed+"</td></tr>\n"
      "</table></tr></td></table>";
  case "hor":
  default:
    return "<br><table boder=\"0\" cellpadding=\"0\" border=\"0\"><tr><td bgcolor=\"#000000\">"
      "<table border=\"0\" cellspacing=\"1\" cellpadding=\"5\">\n"
      "<tr><td bgcolor=\"#d9dee7\">"+c+"</td><td bgcolor=\"d9dee7\">"+parsed+"</td></tr>\n"
      "</table></tr></td></table>";
  }
}

private string format_doc(string|mapping doc, string name, void|object id) {
  if(mappingp(doc)) {
    if(id && id->misc->pref_language) {
      object lang=roxen->languages[id->misc->pref_language];
      doc=doc[lang?lang->id[1]:"standard"];
    }
    else
      doc=doc->standard;
  }
  return parse_html(doc, ([]), ([
    "desc":desc_cont,
    "attr":attr_cont,
    "ex":ex_cont
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
  foreach(indices(doc), string tmp) {
    ret+=parse_doc(doc[tmp], tmp, id);
  }
  return ret;
}


// --------------------- Find documentation --------------

mapping call_tagdocumentation(RoxenModule o) {
  mapping doc;
  catch { doc=o->tagdocumentation(); };
  if(!doc || !mappingp(doc)) return 0;
  return doc;
}

private int generation;
multiset undocumented_tags=(<>);
string find_tag_doc(string name, void|object id) {
  RXML.TagSet tag_set=RXML.get_context()->tag_set;
  string doc;
  int new_gen=tag_set->generation;

  if((doc=cache_lookup("tagdoc",name)) && generation==new_gen)
    return doc;

  if(generation!=new_gen) {
    undocumented_tags=(<>);
    cache_expire("tagdoc");
    generation=new_gen;
  }

  array tags=tag_set->get_overridden_tags(name);
  if(!sizeof(tags)) return "<h4>That tag is not defined</h4>";

  foreach(tags, array|object|function tag) {
    if(objectp(tag)) {
      // FIXME: New style tag. Check for internal documentation.
      tag=object_program(tag);
    }
    if(arrayp(tag)) {
      if(tag[0])
	tag=tag[0][1];
      else if(tag[1])
	tag=tag[1][1];
    }
    tag=function_object(tag);
    if(!objectp(tag)) continue;

    mapping tagdoc=call_tagdocumentation(tag);
    if(!tagdoc || !tagdoc[name]) continue;
    cache_set("tagdoc", name, tagdoc[name]);
    doc=parse_doc(tagdoc[name], name, id);
    return doc;
  }

  undocumented_tags[name]=1;
  return "<h4>No documentation available for \""+name+"\".</h4>\n";
}

/*
string find_module_doc( string cn, string mn, object id )
{
  object c = roxen.find_configuration( cn );

  if(!c)
    return "";

  object m = c->find_module( replace(mn,"!","#") );

  if(!m)
    return "";

  return parse_mapping(m->tagdocumentation());
}
*/
