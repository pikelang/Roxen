/* $Id: wizard.pike,v 1.8 1997/08/20 08:35:28 per Exp $
 *  name="Wizard generator";
 *  doc="This plugin generats all the nice wizards";
 */

inherit "roxenlib";
string wizard_tag_var(string n, mapping m, object id)
{
    
  string current = id->variables[m->name] || m["default"];
  switch(m->type)
  {
   default: // String....
    m->type = "string";
    m_delete(m,"default");
    m->value = current||"";
    if(!m->size)m->size="60,1";
    return make_tag("input", m);

   case "text":
    m_delete(m,"type");
    m_delete(m,"default");
    m->value = current||"";
    if(!m->rows)m->rows="6";
    if(!m->cols)m->cols="40";
    return make_container("textarea", m, html_encode_string(current||""));


   case "int":
    m->type = "number";
    m_delete(m,"default");
    m->value = (string)((int)current);
    if(!m->size)m->size="8,1";
    return make_tag("input", m);

   case "float":
    m->type = "number";
    m_delete(m,"default");
    m->value = (string)((float)current);
    if(!m->size)m->size="14,1";
    return make_tag("input", m);

   case "toggle":
    m_delete(m,"default");
    return make_container("select", m,
			  "<option"+((int)current?" selected":"")+" value=1>Yes"
			  "<option"+(!(int)current?" selected":"")+" value=0>No");

   case "select":
    m_delete(m,"default");
    m_delete(m,"type");
    return make_container("select", m, Array.map(m->choices/",",
						 lambda(string s, string c) {
      return "<option"+(s==c?" selected":"")+">"+html_encode_string(s)+"\n";
    },current)*"");


   case "select_multiple":
    m_delete(m,"default");
    m_delete(m,"type");
    m->multiple="1";
    return make_container("select", m, Array.map(m->choices/",",
						 lambda(string s, array c) {
      return "<option"+(search(c,s)!=-1?" selected":"")+">"+s+"\n";
    },current/"\0")*"");
  }
}

mapping decompress_state(string from)
{
  if(!from) return ([]);
  from = MIME.decode_base64(from);
  catch {
    object gz = Gz;
    if(sizeof(indices(gz)))
      from = gz->inflate()->inflate(from);
  };
  return decode_value(from);
}
  

string compress_state(mapping state)
{
  state = copy_value(state);
  m_delete(state,"_state");
  m_delete(state,"next_page");
  m_delete(state,"prev_page");
  m_delete(state,"help");
  m_delete(state,"action");
  m_delete(state,"unique");
  m_delete(state,"help");

//  perror("State=%O\n", state);
  string from = encode_value(state);
  object gz = Gz;
  if(sizeof(indices(gz)))
  {
    string from2 = gz->deflate()->deflate(from);
    if(strlen(from2)<strlen(from)) from=from2;
  }
  return MIME.encode_base64( from );
}

string parse_wizard_help(string t, mapping m, string contents, object id,
			 mapping v)
{
  v->help=1;
  if(!id->variables->help) return "";
  return contents;
}


string parse_wizard_page(string form, object id, string wiz_name)
{
  int max_page;
  for(int i=0; i<100; i++)
    if(!this_object()[wiz_name+i])
    {
      max_page=i-1;
      break;
    }

  string res;
  int page = ((int)id->variables->_page);
  mapping foo = ([]);
  // Cannot easily be inlined below, believe me... Side-effects.
  form = parse_html(form,([ "var":wizard_tag_var, ]),
		    ([ "help":parse_wizard_help]), id, foo );
  
  res = ("<!--Wizard-->\n"
         "<form method=get>\n"
	 " <input type=hidden name=action value=\""+id->variables->action+"\">\n"
	 " <input type=hidden name=_page value=\""+page+"\">\n"
	 " <input type=hidden name=_state value=\""+compress_state(id->variables)+"\">\n"
	 "<table bgcolor=black cellpadding=1 border=0 cellspacing=0 width=80%>\n"
	 "  <tr><td><table bgcolor=#d0e0ff cellpadding=0 "
	 "         cellspacing=0 border=0 width=100%>\n"
	 "    <tr><td><table width=100%>\n"
	 "<font size=+2>"+(this_object()->wizard_name||this_object()->name)+"</font>"
	 " </td>\n<td align=right>"+
	 (max_page!=1?"Page "+(page+1)+"/"+(max_page+1):"")+"</td>\n"
	  " \n<td align=right>"+
	 (v->help && !id->variables->help?
	  "<font size=-1><input type=image name=help src="+
	  (id->conf?"/internal-roxen-help":"/image/help.gif")+
	  " border=0 value=\"Help\"></font>":"")
	 +"</td>\n"
	 " </tr><tr bgcolor=blue><td colspan=3><img src="+
	 (id->conf?"/internal-roxen-unit":"/image/unit.gif")+
	 " width=1 height=1></td></tr>\n"
	 "  </table><table cellpadding=6><tr><td>\n"
	 "<!-- The output from the page function -->\n"
	 +form+
	 "\n<!-- End of the output from the page function -->\n"
	 "\n</td></tr></table>\n"
	 "      <table width=100%><tr><td width=33%>"+
	 (page>0?
	  "        <input type=submit name=prev_page value=\"<- Previous\">":"")+
	 "</td><td width=33% align=center >"+
	 (page==max_page?
	  "        <input type=submit name=ok value=\" Ok \">":"")+
	 "         <input type=submit name=cancel value=\" Cancel \">"+
	 "</td>"
	 "</td><td width=33% align=right >"+
	 (page!=max_page?
	  "        <input type=submit name=next_page value=\"Next ->\">":"")+
	 "</td></tr></table>"
	 "    </td><tr>\n"
	 "  </table>\n"
	 "  </td></tr>\n"
         "</table>\n"
         " </form>\n"
	  );
  return res;
}


#define PAGE(X)  ((string)(((int)v->_page)+(X)))

mapping|string wizard_for(object id, string|void cancel, string|void wiz_name)
{
  string data;
  int offset = 1;
  mapping v=id->variables;
  if(!wiz_name) wiz_name = "page_";
  if(v->next_page)
    v->_page = PAGE(1);
  else if(v->prev_page)
  {
    v->_page = PAGE(-1);
    offset=-1;
  }
  else if(v->ok)
    return (this_object()->wizard_done(id)
	    || http_redirect(cancel||id->not_query, @(id->conf?({id}):({}))));
  else if(v["help.x"])
  {
    m_delete(v, "help.x");
    m_delete(v, "help.y");
    v->help="1";
  } else if(v->cancel) 
    return http_redirect(cancel||id->not_query, @(id->conf?({id}):({})));
  
  v = decompress_state(v->_state) | v;

  for(;!data;v->_page=PAGE(offset))
  {
    function pg=this_object()[wiz_name+((int)v->_page)];
    if(!pg) return "Error: Invalid page ("+v->_page+")!";
    data = pg();
  }
  return parse_wizard_page(data,id,wiz_name);
}
