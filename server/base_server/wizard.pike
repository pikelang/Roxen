/* $Id: wizard.pike,v 1.28 1997/08/22 19:25:41 per Exp $
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

   case "list": // String....
    string n = m->name, res="<table cellpadding=0 cellspacing=0 border=0>";
    if(!id->variables[n]) id->variables[n]=current;
    
    m->type = "string";
    if(!m->size)m->size="60,1";
    m_delete(m,"default");
    foreach((current||"")/"\0"-({""}), string v)
    {
      res+="<tr><td>"+v+"</td><td><font size=-2>";
      m->name="_delete_"+n+":"+v;
      m->value = " Remove ";
      m->type = "submit";
      res+=make_tag("input",m)+"</td></tr>";
    }
    m->name = "_new_"+n;
    m->type = "string";
    m->value = "";
    res+= "<tr><td>"+make_tag("input", m)+"</td><td><font size=-2>";
    m->name="_Add";
    m->value = " Add ";
    m->type = "submit";
    res+=make_tag("input",m)+"</font></td></tr>";
    res+="</table>";
    return res;

   case "text":
    m_delete(m,"type");
    m_delete(m,"default");
    m->value = current||"";
    if(!m->rows)m->rows="6";
    if(!m->cols)m->cols="40";
    return make_container("textarea", m, html_encode_string(current||""));

   case "radio":
    m_delete(m,"default");
    return make_tag("input "+((!id->variables[m->name] && current) ||
			      (current==m->value)?" checked":""), m);

   case "checkbox":
    string res;
    m_delete(m,"default");
    m_delete(m, m->name);
    m_delete(id->variables, m->name);
    if(search(lower_case(current||""),"on")+1) current="1";
    if((int)current) m->checked="checked";
    res=make_tag("input", m);
    m->type="hidden";
    m->value="0";
    return res+make_tag("input", m);

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

//  werror(sprintf("State=%O\n", state));

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

string make_title()
{
  string s = (this_object()->wizard_name||this_object()->name) - "<p>";
  sscanf(s, "%*s//%s", s);
  sscanf(s, "%*d:%s", s);
  return s;
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
	 "  <tr><td><table bgcolor=#eeeeee cellpadding=0 "
	 "         cellspacing=0 border=0 width=100%>\n"
	 "    <tr><td valign=top><table width=100% height=100% cellspacing=0 cellpadding=5>\n<tr><td valign=top>\n"
	 "<font size=+2>"+make_title()+"</font>"
	 " </td>\n<td align=right>"+
	 (max_page?"Page "+(page+1)+"/"+(max_page+1):"")+"</td>\n"
	  " \n<td align=right>"+
	 (foo->help && !id->variables->help?
	  "<font size=-1><input type=image name=help src="+
	  (id->conf?"/internal-roxen-help":"/image/help.gif")+
	  " border=0 value=\"Help\"></font>":"")
	 +"</td>\n"
	 " </tr><tr><td colspan=3><table cellpadding=0 cellspacing=0 border=0 width=100%><tr  bgcolor=#000000><td><img src="+
	 (id->conf?"/internal-roxen-unit":"/image/unit.gif")+
	 " width=1 height=1></td></tr></table></td></tr>\n"
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

mapping|string wizard_for(object id,string cancel,mixed ... args)
{
  string data;
  int offset = 1;
  mapping v=id->variables;
  string wiz_name = "page_";

  if(v->next_page)
  {
    function c;
    if(!functionp(c=this_object()["verify_"+v->_page]) || (!c( id, @args )))
	v->_page = PAGE(1);
  }
  else if(v->prev_page)
  {
    function c;
    if(!functionp(c=this_object()["verify_"+v->_page]) || (!c( id, @args )))
      v->_page = PAGE(-1);
    offset=-1;
  }
  else if(v->ok)
  {
    function c;
    if(!functionp(c=this_object()["verify_"+v->_page]) || (!c( id, @args )))
      return (((c=this_object()->wizard_done)?c(id,@args):0)
	      || http_redirect(cancel||id->not_query, @(id->conf?({id}):({}))));
  }
  else if(v["help.x"])
  {
    m_delete(v, "help.x");
    m_delete(v, "help.y");
    v->help="1";
  } else if(v->cancel) {
    return http_redirect(cancel||id->not_query, @(id->conf?({id}):({})));
  }
  mapping s = decompress_state(v->_state);
  foreach(indices(s), string q)
    v[q] = v[q]||s[q];


  foreach(indices(id->variables), string n)
  {
    string q,on=n;
    if(sscanf(n, "_new_%s", n))
    {
      if((v->_Add) && strlen(v[on]-"\r"))
      {
	if(v[n]) v[n]+="\0"+v[on];
	else v[n]=v[on];
	m_delete(v, on);
	m_delete(v, "_Add");
      }
    } else if(sscanf(n, "_delete_%s:%s", n,q)==2) {
      if(v[n]) v[n]=replace(replace(v[n]/"\0",q,"")*"\0","\0\0","\0");
      m_delete(v, on);
    } 
  }

  for(; !data; v->_page=PAGE(offset))
  {
    function pg=this_object()[wiz_name+((int)v->_page)];
    if(!pg) return "Error: Invalid page ("+v->_page+")!";
    if(data = pg(id,@args)) break;
  }
  return parse_wizard_page(data,id,wiz_name);
}

mapping wizards = ([]);

object get_wizard(string act, string dir, mixed ... args)
{
  act-="/";
  if(!wizards[dir+act]) wizards[dir+act]=compile_file(dir+act)(@args);
  return wizards[dir+act];
}

int zonk=time();
mapping get_actions(string base,string dir, array args)
{
  mapping acts = ([  ]);
  foreach(get_dir(dir), string act)
  {
    mixed err;
    err = catch
    {
      if(act[0]!='#' && act[-1]=='e')
      {
	string sm,rn = (get_wizard(act,dir,@args)->name||act), name;

	if(sscanf(rn, "%*s:%s", name) != 2) name = rn;
	sscanf(name, "%s//%s", sm, name);
	if(!acts[sm]) acts[sm] = ({ });
	acts[sm]+=
	  ({"<!-- "+rn+" --><dt><font size=\"+2\">"
	      "<a href=\""+base+"?action="+act+"&unique="+(zonk++)+"\">"+
	      name+"</a></font><dd>"+(get_wizard(act,dir,@args)->doc||"")});
      }
    };
//  if(err) report_error(describe_backtrace(err));
  }
  return acts;
}

string act_describe_submenues(array menues, string base,string sel)
{
  if(sizeof(menues)==1) return "";
  string res = "<font size=+3>";
  foreach(sort(menues), string s)
    res+=
      (s==sel?"<li>":"<font color=#eeeeee><li></font><a href=\""+base+"?sm="+replace(s||"Misc"," ","%20")+
       "&uniq="+(++zonk)+"\">")+(s||"Misc")+
      (s==sel?"<br>":"</a><br>")+"";
  return res + "</font>";
}

string focused_wizard_menu;
mixed wizard_menu(object id, string dir, string base, mixed ... args)
{
  mapping acts;
  if(id->pragma["no-cache"]) wizards=([]);
  
  if(!id->variables->sm)
    id->variables->sm = focused_wizard_menu;
  else
    focused_wizard_menu = id->variables->sm=="0"?0:id->variables->sm;
  
  if(!id->variables->action)
  {
    mapping acts = get_actions(base, dir, args);
    return ("<table cellpadding=10><tr><td valign=top bgcolor=#eeeeee>"+
	    act_describe_submenues(indices(acts),base,id->variables->sm)+
	    "</td>\n\n<td valign=top>"+
	    (sizeof(acts)>1 && acts[id->variables->sm]?"<font size=+3>"+
	     (id->variables->sm||"Misc")+"</font><dl>":"<dl>")+
	    (sort(acts[id->variables->sm]||({}))*"\n")+
	    "</dl></td></tr></table>");
  }
  return get_wizard(id->variables->action,dir)->wizard_for(id,base,@args);
}

/*** Additional Action Functions ***/

string html_table(array(string) subtitles, array(array(string)) table)
{
  string r = "";

  r += ("<table bgcolor=black border=0 cellspacing=0 cellpadding=1>\n"
	"<tr><td>\n");
  r += "<table border=0 cellspacing=0 cellpadding=4>\n";
  r += "<tr bgcolor=#113377>\n";
  int cols;
  foreach(subtitles, mixed s)
  {
    if(stringp(s))
    {
      r+="<th nowrap align=left><font color=#ffffff>"+s+" &nbsp; </font></th>";
      cols++;
    } else {
      r+="</tr><tr bgcolor=#113377><th nowrap align=left colspan="+cols+">"
	"<font color=#ffffff>"+s[0]+" &nbsp; </font></th>";
    }
  }      
  r += "</tr>";


  for(int i = 0; i < sizeof(table); i++) {
    r += "<tr bgcolor="+(i%2?"#ddeeff":"#ffffff")+">";
    foreach(table[i], mixed s)
      if(stringp(s))
	r += "<td nowrap>"+s+"&nbsp;&nbsp;</td>";
      else
	r += "</tr><tr bgcolor="+(i%2?"#ddeeff":"#ffffff")+
	  "><td colspan="+cols+">"+s[0]+" &nbsp;</td>";
    r += "</tr>\n";
  }
  r += "</table></td></tr>\n";
  r += "</table><br>\n";
  return r;
}


string html_notice(string notice, object id)
{
  return ("<table><tr><td valign=top><img src=\""+
        (id->conf?"/internal-roxen-":"/image/")
        +"err_1.gif\"></td><td valign=top>"+notice+"</td></tr></table>");
}

string html_warning(string notice, object id)
{
  return ("<table><tr><td valign=top><img src=\""+
        (id->conf?"/internal-roxen-":"/image/")
        +"err_2.gif\"></td><td valign=top>"+notice+"</td></tr></table>");
}

string html_error(string notice, object id)
{
  return ("<table><tr><td valign=top><img src=\""+
        (id->conf?"/internal-roxen-":"/image/")
        +"err_3.gif\"></td><td valign=top>"+notice+"</td></tr></table>");
}
