string desc_cont(string t, mapping m, string c, string rt)
{
  string dt=rt;
  m->type=m->type||"";
  if(m->tag) dt=sprintf("&lt;%s/&gt;", rt);
  if(m->cont) dt=(m->tag?dt+" and ":"")+sprintf("&lt;%s&gt;&lt;/%s&gt;", rt, rt);
  return sprintf("<h2>%s</h2><p>%s</p>",dt,c);
}

string attr_cont(string t, mapping m, string c)
{
  string p="";
  if(!m->name) m->name="(Not entered)";
  if(m->value) p=sprintf("<i>%s=%s</i><br>",m->name,attr_vals(m->value));
  return sprintf("<p><b>%s</b><br>%s%s</p>",m->name,p,c);
}

string attr_vals(string v)
{
  if(search(v,",")!=-1) return "{"+(v/",")*", "+"}";
  if(v=="langcodes") return "<a href=\"?show=langcodes\">language code</a>";
  return v;
}

mapping helptags=(["desc":desc_cont, "attr":attr_cont]);

string parse_doc(mapping doc) {
  string ret="";
  foreach(indices(doc), string tmp) {
    if(arrayp(doc[tmp])) {
      ret+=parse_html(doc[tmp][0], ([]), helptags, tmp);
      ret+="<dl><dd>"+parse_doc(doc[tmp][1])+"</dd></dl>";
    }
    else
      ret+=parse_html(doc[tmp] ,([]), helptags, tmp);
  }
  return ret;
}

string find_module_doc( string cn, string mn, object id )
{
  object c = roxen.find_configuration( cn );

  if(!c)
    return "";

  object m = c->find_module( replace(mn,"!","#") );

  if(!m)
    return "";

  return parse_doc(m->tagdocumentation());
}

string parse( object id )
{
  array q = id->misc->path_info / "/";
  if( sizeof( q ) >= 5 )
    return find_module_doc( q[1], q[3], id );
} 





