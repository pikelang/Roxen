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

private string parse_doc(string|mapping doc, string name) {
  if(mappingp(doc)) doc=doc->standard;
  return parse_html(doc, ([]), ([
    "desc":desc_cont,
    "attr":attr_cont
  ]), name);
}

// ------------------ Parse docs in mappings --------------

private string parse_mapping(mapping doc) {
  string ret="";
  if(!mappingp(doc)) return "";
  foreach(indices(doc), string tmp) {
    if(arrayp(doc[tmp])) {
      ret+=parse_doc(doc[tmp][0], tmp);
      ret+="<dl><dd>"+parse_mapping(doc[tmp][1])+"</dd></dl>";
    }
    else
      ret+=parse_doc(doc[tmp], tmp);
  }
  return ret;
}

// --------------------- Find documentation --------------

RXML.TagSet rxml_tag_set = RXML.TagSet ("rxml_tag_set");
string find_tag_doc(string name) {
  RXML.PHtml parser = rxml_tag_set (RXML.t_text (RXML.PHtmlCompat));
  //  foreach(parser->get_overridden_low_tag(name), object x) {
    // 1. Determine module of origin.
    // 2. Look up module in global help cache in roxen object.
    //  2b.  If present, return help.
    // 3. Query module for documentation mapping with tagdocumentation()
    //  3b.  If returned 0, loop.
    //  3c.  If returned mapping, return help.
    // 4. Break.
  //  }
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
