/* $Id: wizard.pike,v 1.54 1998/02/27 07:12:23 per Exp $
 *  name="Wizard generator";
 *  doc="This file generats all the nice wizards";
 */

inherit "roxenlib";
string wizard_tag_var(string n, mapping m, mixed a, mixed b)
{
  object id;
  if(n=="cvar") // Container. Default value in 'a', id in 'b'.
  {
    id = b;
    m["default"] = a;
  } else // tag. No contents, id in 'b'.
    id = a;

  string current = id->variables[m->name] || m["default"];
  if(current)
    current = current +"";
  switch(m->type)
  {
   default: // String or password field....
    if(m->type != "password")
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
    m_delete(m, "value");
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
    if(current && current!="0") m->checked="checked";
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

   case "color":
     int h, s, v;
     if(id->variables[m->name+".hsv"]) 
       sscanf(id->variables[m->name+".hsv"], "%d,%d,%d", h, s, v);
     else
     {
       array tmp = rgb_to_hsv(@parse_color(current||"black"));
       h = tmp[0]; s = tmp[1];  v = tmp[2];
     } 
     if(id->variables["foo.x"]) {
       h = (int)id->variables["foo.x"];
       v = 255-(int)id->variables["foo.y"];
     } else if(id->variables["bar.y"])
       s=255-(int)id->variables["bar.y"];
     else if(id->variables[m->name+".entered"] &&
	     strlen(current=id->variables[m->name+".entered"]))
     {
       array tmp = rgb_to_hsv(@parse_color(current||"black"));
       h = tmp[0]; s = tmp[1];  v = tmp[2];
     }

     m_delete(id->variables, "foo.x");
     m_delete(id->variables, "foo.y");
     m_delete(id->variables, "bar.x");
     m_delete(id->variables, "bar.y");
     id->variables[m->name+".hsv"] = h+","+s+","+v;

     array a=hsv_to_rgb(h,s,v);
     string bgcol=sprintf("#%02x%02x%02x",a[0],a[1],a[2]); 
     id->variables[m->name] = bgcol;
     return 
     ("<table><tr>\n"
      "<td width=258 rowspan=2>\n"
      "  <table bgcolor=black cellpadding=1 border=0 cellspacing=0 width=258><tr><td>\n"
      "  <input type=image name=foo src=/internal-roxen-colsel width=256 height=256 border=0></a>\n"
      "  </td></table>\n"
      "</td>\n"
      "<td width=30 rowspan=2></td>\n"
      "<td width=32 rowspan=2>\n"
      "  <table bgcolor=black cellpadding=1 border=0 cellspacing=0 width=32><tr><td>\n"
      "<input type=image src=\"/internal-roxen-colorbar:"+
      (string)h+","+(string)v+","+(string)s+"\" "
      "name=bar width=30 height=256 border=0></a>"
      "</td></table>\n"
      "</td>\n"
      "<td width=32 rowspan=2></td>\n"
      "<td width=120>\n"
      "  <table bgcolor=black cellpadding=1 border=3 cellspacing=0 width=90>\n"
      "  <tr><td height=90 width=90 bgcolor="+bgcol+">&nbsp;"+
      (m->tt?"<font color='"+m->tc+"'>"+m->tt+"</font>":"")
      +"</td></table>\n"
      "</td><tr>\n"
      "<td width=120>\n"
      "<b>R:</b> "+(string)a[0]+"<br>\n"
      "<b>G:</b> "+(string)a[1]+"<br>\n"
      "<b>B:</b> "+(string)a[2]+"<br>\n"
      "<hr size=2 align=left noshade width=70>\n"
      "<b>H:</b> "+(string)h+"<br>\n"
      "<b>S:</b> "+(string)s+"<br>\n"
      "<b>V:</b> "+(string)v+"<br>\n"
      "<hr size=2 align=left noshade width=70>\n"+
      "<font size=-1><input type=string name="+
      m->name+".entered size=8 value='"+
      color_name(a)+"'> <input type=submit value=Ok></font></td></table>\n");

   case "font":
     string res="";
     m->type = "select";
     m->choices = roxen->available_fonts(1)*",";
     if(id->conf && id->conf->modules["graphic_text"])
       res = ("<input type=submit value='Example'><br>"+
	      ((current&&strlen(current))?
	       "<gtext nfont='"+current+"'>Example Text</gtext><br>"
	       :""));
     return make_tag("var", m)+res;

   case "toggle":
    m_delete(m,"default");
    return make_container("select", m,
			  "<option"+((int)current?" selected":"")+" value=1>Yes"
			  "<option"+(!(int)current?" selected":"")+" value=0>No");

   case "select":
     if(!m->choices && m->options)
       m->choices = m->options;
     m_delete(m,"default");
     m_delete(m,"type");
     mapping m2 = copy_value(m);
     m_delete(m2, "choices");
     m_delete(m2, "options");
     return make_container("select", m2, Array.map(m->choices/",",
						   lambda(string s, string c) {
        string t;
        if(sscanf(s, "%s:%s", s, t) != 2)
	  t = s;
        return "<option value='"+s+"' "+(s==c?" selected":"")+">"+html_encode_string(t)+"\n";
     },current)*"");


   case "select_multiple":
     if(!m->choices && m->options)
       m->choices = m->options;
    m_delete(m,"default");
    m_delete(m,"type");
    m2 = copy_value(m);
    m_delete(m2, "choices");
    m_delete(m2, "options");
    m2->multiple="1";
    return make_container("select", m2, Array.map(m->choices/",",
				 lambda(string s, array c) {
      string t;
      if(sscanf(s, "%s:%s", s, t) != 2)
        t = s;
      return "<option value='"+s+"' "+(search(c,s)!=-1?"selected":"")+">"+html_encode_string(t)+"\n";
    },(current||"")/"\0")*"");
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

int num_pages(string wiz_name)
{
  int max_page;
  for(int i=0; i<100; i++)
    if(!this_object()[wiz_name+i])
    {
      max_page=i-1;
      break;
    }
  return max_page+1;
}
#define Q(X) replace(X,({"<",">","&","\""}),({"&lt;","&gt;","&amp;","&quote;"}))

#define PAGE Q((this_object()->page_label?this_object()->page_label:"Page "))
#define OK Q((this_object()->ok_label?this_object()->ok_label:"Ok"))
#define CANCEL Q((this_object()->cancel_label?this_object()->cancel_label:"Cancel"))
#define NEXT Q((this_object()->next_label?this_object()->next_label:"Next ->"))
#define PREVIOUS Q((this_object()->previous_label?this_object()->previous_label:"<- Previous"))
#define COMPLETED Q((this_object()->completed_label?this_object()->completed_label:"Completed"))

string parse_wizard_page(string form, object id, string wiz_name)
{
  int max_page = num_pages(wiz_name)-1;
  string res;
  int page = ((int)id->variables->_page);
  mapping foo = ([]);
  // Cannot easily be inlined below, believe me... Side-effects.
  form = parse_html(form,([ "var":wizard_tag_var, ]),
		    ([ "cvar":wizard_tag_var, 
		       "help":parse_wizard_help]), id, foo );
  
  res = ("<!--Wizard-->\n"
         "<form method=post>\n"
	 " <input type=hidden name=action value=\""+id->variables->action+"\">\n"
	 " <input type=hidden name=_page value=\""+page+"\">\n"
	 " <input type=hidden name=_state value=\""+compress_state(id->variables)+"\">\n"
	 "<table bgcolor=black cellpadding=1 border=0 cellspacing=0 width=80%>\n"
	 "  <tr><td><table bgcolor=#eeeeee cellpadding=0 "
	 "         cellspacing=0 border=0 width=100%>\n"
	 "    <tr><td valign=top><table width=100% height=100% cellspacing=0 cellpadding=5>\n<tr><td valign=top>\n"
	 "<font size=+2>"+make_title()+"</font>"
	 " </td>\n<td align=right>"+
	 (wiz_name=="done"
	  ?COMPLETED
	  :(max_page?PAGE+(page+1)+"/"+(max_page+1):""))+
	 "</td>\n"
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
	 ((page>0 && wiz_name!="done")?
	  "        <input type=submit name=prev_page value=\""+PREVIOUS+"\">":"")+
	 "</td><td width=33% align=center >"+
	 (wiz_name!="done"
	  ?((page==max_page
	     ?"        <input type=submit name=ok value=\" "+OK+" \">"
	     :"")+
	    "         <input type=submit name=cancel value=\" "+CANCEL+" \">")
	  :"         <input type=submit name=cancel value=\" "+OK+" \">")+
	  "</td>"
	 "</td><td width=33% align=right >"+
	 ((page!=max_page && wiz_name!="done")?
	  "        <input type=submit name=next_page value=\""+NEXT+"\">":"")+
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

  mapping s = decompress_state(v->_state);
  foreach(indices(s), string q)
     v[q] = v[q]||s[q];

  if(v->next_page)
  {
    function c;
    if(!functionp(c=this_object()["verify_"+v->_page]) || (!c( id, @args )))
	v->_page = PAGE(1);
  }
  else if(v->prev_page)
  {
    v->_page = PAGE(-1);
    offset=-1;
  }
  else if(v->ok)
  {
    function c;

    if(!functionp(c=this_object()["verify_"+v->_page]) || (!c( id, @args )))
    {
      mixed res;
      if(c=this_object()->wizard_done)
	res = c(id,@args);
      if(res != -1) 
	return (res
		|| http_redirect(cancel||id->not_query, 
				 @(id->conf?({id}):({}))));
    }
  }
  else if(v["help.x"])
  {
    m_delete(v, "help.x");
    m_delete(v, "help.y");
    v->help="1";
  } else if(v->cancel) {
    return http_redirect(cancel||id->not_query, @(id->conf?({id}):({})));
  }

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
    if(!pg) return "Internal error in wizard code: Invalid page ("+v->_page+")!";
    if(data = pg(id,@args)) break;
  }
  return parse_wizard_page(data,id,wiz_name);
}

mapping wizards = ([]);
string err;
object get_wizard(string act, string dir, mixed ... args)
{
  act-="/";
  if(!wizards[dir+act]) wizards[dir+act]=compile_file(dir+act)(@args);
  return wizards[dir+act];
}

int zonk=time();
mapping get_actions(object id, string base,string dir, array args)
{
  mapping acts = ([  ]);
  foreach(get_dir(dir), string act)
  {
    mixed err;
    _master->set_inhibit_compile_errors(0);
    err = catch
    {
      if(act[0]!='#' && act[-1]=='e')
      {
	string sm,rn = (get_wizard(act,dir,@args)->name||act), name;
	if(sscanf(rn, "%*s:%s", name) != 2) name = rn;
	sscanf(name, "%s//%s", sm, name);
	if(!acts[sm]) acts[sm] = ({ ([]) });

	if(id->misc->raw_wizard_actions)
 	  acts[sm][0][name]=
 	    ({ name, base, (["action":act,"unique":(string)(zonk++) ]),
 		  (get_wizard(act,dir,@args)->doc||"") });
 	else
	  acts[sm]+=
	    ({"<!-- "+rn+" --><dt><font size=\"+2\">"
	      "<a href=\""+base+"?action="+act+"&unique="+(zonk++)+"\">"+
	      name+"</a></font><dd>"+(get_wizard(act,dir,@args)->doc||"")});
      }
    };
    if(err) report_error(describe_backtrace(err));
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
    mixed wizbug;
    wizbug = catch {
      mapping acts = get_actions(id, base, dir, args);
      if(id->misc->raw_wizard_actions)
	return acts[id->variables->sm];
      string res;
      res= ("<table cellpadding=3><tr><td valign=top bgcolor=#eeeeee>"+
	    act_describe_submenues(indices(acts),base,id->variables->sm)+
	    "</td>\n\n<td valign=top>"+
	    (sizeof(acts)>1 && acts[id->variables->sm]?"<font size=+3>"+
	     (id->variables->sm||"Misc")+"</font><dl>":"<dl>")+
	    (sort(acts[id->variables->sm]||({}))*"\n")+
	    "</dl></td></tr></table>"+
	    (err && strlen(err)?"<pre>"+err+"</pre>":""));
      err="";
      return res;
    };
    if(wizbug)
      err = describe_backtrace(wizbug);
    if(err && strlen(err)) {
      string res="<pre>"+err+"</pre>";
      err="";
      return res;
    }
  } else {
    object o = get_wizard(id->variables->action,dir);
    if(!o) {
      mixed res = "<pre>"+err+"</pre>";
      err="";
      return res;
    }
    mixed res= o->wizard_for(id,base,@args);
    err="";
    return res;
  }
  return "<pre>The Wizard is confused.</pre>";
}

/*** Additional Action Functions ***/

string format_numeric(string s, string|void sep)
{
  sep = reverse(sep||"&nbsp;");
  array(string) as = s/" ";
  string t = "";
  string s = reverse(as[0]);
  while(sizeof(s)) {
    if(sizeof(s) > 3)
      t += s[0..2]+sep;
    else
      t += s;
    s = s[3..];
  }
  return (({reverse(t)})+as[1..])*" "; 
}

string html_table(array(string) subtitles, array(array(string)) table,
		  mapping|void opt)
{
  /* Options:
   *   bgcolor, titlebgcolor, titlecolor, fgcolor0, fgcolor1, modulo
   * Containers:
   *   <fields>[num|text, ...]</fields>
   */

  string r = "";

  if(!opt) opt = ([]);
  int m = (int)(opt->modulo?opt->modulo:1);
  r += ("<table bgcolor="+(opt->bgcolor||"black")+" border=0 "
	"cellspacing=0 cellpadding=1>\n"
	"<tr><td>\n");
  r += "<table border=0 cellspacing=0 cellpadding=4>\n";
  r += "<tr bgcolor="+(opt->titlebgcolor||"#113377")+">\n";
  int cols;
  foreach(subtitles, mixed s)
  {
    if(stringp(s))
    {
      r+=("<th nowrap align=left><font color="+
	  (opt->titlecolor||"#ffffff")+">"+s+" &nbsp; </font></th>");
      cols++;
    } else {
      r+=("</tr><tr bgcolor="+(opt->titlebgcolor||"#113377")+">"
	  "<th nowrap align=left colspan="+cols+">"
	  "<font color="+(opt->titlecolor||"#ffffff")+">"+s[0]+
	  " &nbsp; </font></th>");
    }
  }      
  r += "</tr>";
  
  for(int i = 0; i < sizeof(table); i++) {
    string tr;
    r += tr = "<tr bgcolor="+((i/m)%2?opt->fgcolor1||"#ddeeff":
			      opt->fgcolor0||"#ffffff")+">";
    for(int j = 0; j < sizeof(table[i]); j++) {
      mixed s = table[i][j];
      if(arrayp(s))
	r += "</tr>"+tr+"><td colspan="+cols+">"+s[0]+" &nbsp;</td>";
      else {
	string type = "text";
	if(arrayp(opt->fields) && j < sizeof(opt->fields))
	  type = opt->fields[j];
	switch(type) {
	case "num":
	  array a = s/".";
	  r += "<td nowrap align=right>";
	  if(sizeof(a) > 1) {
	    r += (format_numeric(a[0])+"."+
		  reverse(format_numeric(reverse(a[1]), ";psbn&")));
	  } else
	    r += format_numeric(s, "&nbsp;");
	  break;
	case "text":
	default:
	  r += "<td nowrap>"+s;
	}
	r += "&nbsp;&nbsp;</td>";
      }
    }
    r += "</tr>\n";
  }
  r += "</table></td></tr>\n";
  r += "</table><br>\n";
  return r;
}


string html_notice(string notice, object id)
{
  return ("<table><tr><td valign=top><img \nalt=Notice: src=\""+
        (id->conf?"/internal-roxen-":"/image/")
        +"err_1.gif\"></td><td valign=top>"+notice+"</td></tr></table>");
}

string html_warning(string notice, object id)
{
  return ("<table><tr><td valign=top><img \nalt=Warning: src=\""+
        (id->conf?"/internal-roxen-":"/image/")
        +"err_2.gif\"></td><td valign=top>"+notice+"</td></tr></table>");
}

string html_error(string notice, object id)
{
  return ("<table><tr><td valign=top><img \nalt=Error: src=\""+
        (id->conf?"/internal-roxen-":"/image/")
        +"err_3.gif\"></td><td valign=top>"+notice+"</td></tr></table>");
}

string html_border(string what, int|void width, int|void ww,
		   string|void bgcolor, string|void bdcolor)
{
  return ("<table border=0 cellpadding="+(width+1)+" cellspacing=0 "
	  "bgcolor="+(bdcolor||"black")+
	  "><tr><td><table border=0 cellpadding="+(ww)+
	  " cellspacing=0 bgcolor="+(bgcolor||"white")+
	  "><tr><td>"+what+"</tr></td></table>"
          "</td></tr></table>");
}

void filter_checkbox_variables(mapping v)
{
  foreach(indices(v), string s)
    if(v[s]=="0")   m_delete(v,s);
    else            v[s]-="\00";
}
