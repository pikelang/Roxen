/*
 * $Id: resolv.pike,v 1.5 1998/02/23 01:55:19 per Exp $
 */

inherit "wizard";
constant name= "Maintenance//Resolve path...";
constant doc = ("Check which module handles the path you enter in the form");

string module_name(function|object m)
{
  if(!m)return "";
  if(functionp(m)) m = function_object(m);
  return "<font color=darkgreen>"+
    (strlen(m->query("_name")) ? m->query("_name") :
     (m->query_name&&m->query_name()&&strlen(m->query_name()))?
     m->query_name():m->register_module()[1])+"</font>";
}

string resolv;
int level;

mapping et = ([]);

void trace_enter_ol(string type, function|object module)
{
  level++; 
  et[level] = gethrtime();
  string efont="", font="";
  if(level>2) {efont="</font>";font="<font size=-1>";} 
  resolv += (font+"<b><li></b> "+type+" "+module_name(module)+"<ol>"+efont);
}

void trace_leave_ol(string desc)
{
  int delay = gethrtime()-et[level];
  level--;
  string efont="", font="";
  if(level>1) {efont="</font>";font="<font size=-1>";} 
  resolv += (font+"</ol>"+"Time: "+sprintf("%.5f",delay/1000000.0)
	     +"<br>"+desc+efont)+"<p>";

}

void trace_enter_table(string type, function|object module)
{
  level++;
  et[level]= gethrtime();
  string efont="", font="";
  if(level>2) {efont="</font>";font="<font size=-1>";} 
  resolv += ("<tr>"
	     +(level>1?"<td width=1 bgcolor=blue><img src=/image/unit.gif alt=|></td>":"")
	     +"<td width=100%>"+font+type+" "+module_name(module)+
	     "<table width=100% border=0 cellspacing=10 border=0 cellpadding=0>");
}

void trace_leave_table(string desc)
{
  int delay = gethrtime()-et[level];
  level--;
  string efont="", font="";
  if(level>1) {font="<font size=-1>";} 
  resolv += ("</td></tr></table><br>"+font+"Time: "+sprintf("%.5f",delay/1000000.0)
	     +"<br>"+desc+efont)+"</td></tr>";
}

string page_0(object id)
{
  string res = ("Virtual server <var type=select name=config options='"+
		roxen->configurations->query_name()*","+"'>")+" Use tables <var type=toggle name=table>\n";
  res += "<br>Path: <var name=path type=string>\n";
  res += "<table cellpadding=0 cellspacing=10 border=0>"
         "<tr><td align=left>User: <var name=user type=string size=12></td>\n"
         "<td align=left>&nbsp;&nbsp;&nbsp;Password: <var name=password type=password size=12>"
	 "</td></tr></table>\n";

  if(id->variables->config)
  {
    object c;
    foreach(roxen->configurations, c)
      if(c->query_name() == id->variables->config)
	break;
    
    object nid = id->clone_me();
    if((int)id->variables->table)
    {
      nid->misc->trace_enter = trace_enter_table;
      nid->misc->trace_leave = trace_leave_table;
      resolv = "Resolving "+id->variables->path+" in "+c->query_name()+"<hr noshade size=1 width=100%><p><table width=80% cellpadding=0 cellspacing=1>";
    }
    else
    {
      nid->misc->trace_enter = trace_enter_ol;
      nid->misc->trace_leave = trace_leave_ol;
      resolv = "Resolving "+id->variables->path+" in "+c->query_name()+"<hr noshade size=1 width=100%><p><ol>";
    }

    nid->not_query = id->variables->path;
    nid->conf = c;

    if (id->variables->user && id->variables->user!="")
    {
       string *y;
       nid->rawauth 
	  = 
	  "Basic "+MIME.encode_base64(id->variables->user+":"+
				      id->variables->password);

       nid->realauth=id->variables->user+":"+id->variables->password;

       nid->auth=({0,id->realauth});
       if(c && c->auth_module)
	  nid->auth = c->auth_module->auth( id->auth, nid );
    }

    int again;
    mixed file;
    function funp;
    do
    {
      again=0;
      foreach(c->first_modules(), funp)
      {
	nid->misc->trace_enter("First module", funp);
	if(file = funp( nid ))
	{
	  nid->misc->trace_leave("Returns data");
	  break;
	}
	if(nid->conf != c)
	{
	  c = nid->conf;
	  nid->misc->trace_leave("Request transfered to the virtual server "+c->query_name());
	  again=1;
	  break;
	}
      }
    } while(again);
// trace(1);
    c->get_file(nid);
// trace(0);    
    while(level) nid->misc->trace_leave("");
    if((int)id->variables->table)
      resolv += "</table>";
    else
      resolv += "</ol>";
    res += "<p><blockquote>"+html_border(resolv,0,10)+"</blockquote>";
  }
  return res;
}

int wizard_done(object id)
{
  return -1;
}

mixed handle(object id, object mc)
{
  return wizard_for( id, 0 );
}
