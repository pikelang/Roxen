string help_cont(string t, mapping m, string c, string rt)
{
  switch(t){
  case "desc":
    m->type=m->type||"";
    switch(m->type) {
    case "tag":
      rt=sprintf("&lt;%s&gt;", rt);
      break;
    case "container":
    case "cont":
      rt=sprintf("&lt;%s&gt;&lt;/%s&gt;", rt, rt);
      break;
    default:
      if(m->type!="") rt=rt+", "+m->type;
    }
    return sprintf("<h2>%s</h2><p>%s</p>",rt,c);
  case "attr":
    string p="";
    if(!m->name) m->name="(Not entered)";
    if(m->value) p=sprintf("<i>%s=%s</i><br>",m->name,attr_vals(m->value));
    return sprintf("<p><b>%s</b><br>%s%s</p>",m->name,p,c);
  default:
    return c;
  }
}

string attr_vals(string v)
{
  if(search(v,",")!=-1) return "{"+v+"}";
  return v;
}

string find_module_doc( string cn, string mn, object id )
{
  object c = roxen.find_configuration( cn );

  if(!c)
    return "";

  object m = c->find_module( replace(mn,"!","#") );

  if(!m)
    return "";

  string ret="";
  mapping doc=m->tagdocumentation();
  foreach(indices(doc), string tmp) {
    ret+=parse_html(doc[tmp],([]),(["desc":help_cont, "attr":help_cont]), tmp);
  }
  return ret;
}

string parse( object id )
{
  array q = id->misc->path_info / "/";
  if( sizeof( q ) >= 5 )
    return find_module_doc( q[1], q[3], id );
} 





