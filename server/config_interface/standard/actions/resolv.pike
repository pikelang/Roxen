/*
 * $Id: resolv.pike,v 1.13 2000/08/16 11:20:58 jhs Exp $
 */

inherit "wizard";
inherit "../logutil";

constant action="maintenance";
constant name= "Resolve path...";
constant doc = ("Check which modules handles the path you enter in the form");

string link(string to, string name)
{
  return sprintf("<a href=\"%s\">%s</a>", to, name);
}

string link_configuration(Configuration c)
{ 
  return link(@get_conf_url_to_virtual_server(c,"standard")); 
}

string module_name(function|RoxenModule|RXML.Tag m)
{
  m = Roxen.get_owning_module (m);
  if(!m) return "";

  string name;
  catch (name = Roxen.get_modfullname (m));
  if (!name) return "<font color=red>Unavailable</font>";

  Configuration c;
  if(functionp(m->my_configuration) && (c = m->my_configuration()))
  {
    foreach(indices(c->modules), string mn)
    {
      int w;
      mapping mod = c->modules[mn];
      if(mod->enabled == m)
      {
	name = sprintf("<a href=\"%s\">%s</a> (%s)",
		       @get_conf_url_to_module(c->name+"/"+mn), roxen->filename(m));
	break;
      }
      else if(mod->copies && !zero_type(search(mod->copies, m)))
      {
	name = sprintf("<a href=\"%s\">%s</a> (%s)",
		       @get_conf_url_to_module(c->name+"/"+mn+"#"+search(mod->copies, m)),
		       roxen->filename(m));
	break;
      }
    }
  }

  return "<font color=darkgreen>"+name+"</font>";
}

string resolv;
int level, prev_level;

string anchor(string title)
{
  while(level < prev_level)
    m_delete(et, (string)prev_level--);
  prev_level = level;
  et[(string)level]++;

  array(string) anchor = allocate(level);
  for(int i=0; i<level; )
    anchor[i] = (string)et[(string)++i];
  return sprintf("<a name=\"%s\" href=\"#%s\">%s</a>", anchor*".", anchor*".", title);
}


mapping et = ([]);
#if efun(gethrvtime)
mapping et2 = ([]);
#endif

void trace_enter_ol(string type, function|object module)
{
  level++;

  string efont="", font="";
  if(level>2) {efont="</font>";font="<font size=-1>";}
  resolv += (font+anchor("<b><li></b> ")+type+" "+module_name(module)+"<ol>"+efont);
#if efun(gethrvtime)
  et2[level] = gethrvtime();
#endif
#if efun(gethrtime)
  et[level] = gethrtime();
#endif
}

void trace_leave_ol(string desc)
{
#if efun(gethrtime)
  int delay = gethrtime()-et[level];
#endif
#if efun(gethrvtime)
  int delay2 = gethrvtime()-et2[level];
#endif
  level--;
  string efont="", font="";
  if(level>1) {efont="</font>";font="<font size=-1>";}
  resolv += (font+"</ol>"+
#if efun(gethrtime)
	     "Time: "+sprintf("%.5f",delay/1000000.0)+
#endif
#if efun(gethrvtime)
	     " (CPU = "+sprintf("%.2f)", delay2/1000000.0)+
#endif /* efun(gethrvtime) */
	     "<br />"+html_encode_string(desc)+efont)+"<p>";

}

void trace_enter_table(string type, function|object module)
{
  level++;
  string efont="", font="";
  if(level>2) {efont="</font>";font="<font size=-1>";}
  resolv += ("<tr>"
	     +(level>1?"<td width=1 bgcolor=blue><img src=/image/unit.gif alt=|></td>":"")
	     +"<td width=100%>"+font+type+" "+module_name(module)+
	     "<table width=100% border=0 cellspacing=10 border=0 cellpadding=0>");
#if efun(gethrtime)
  et[level]= gethrtime();
#endif
}

void trace_leave_table(string desc)
{
#if efun(gethrtime)
  int delay = gethrtime()-et[level];
#endif
  level--;
  string efont="", font="";
  if(level>1) {font="<font size=-1>";}
  resolv += ("</td></tr></table><br />"+font+
#if efun(gethrtime)
	     "Time: "+sprintf("%.5f",delay/1000000.0)+
#endif
	     "<br />"+html_encode_string(desc)+efont)+"</td></tr>";
}

void resolv_handle_request(object c, object nid)
{
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
      nid->misc->trace_leave("");
    }
  } while(again);

  if(!c->get_file(nid))
  {
    foreach(c->last_modules(), funp)
    {
      nid->misc->trace_enter("Last try module", funp);
      if(file = funp(nid)) {
	if (file == 1) {
	  nid->misc->trace_enter("Returned recurse", 0);
	  resolv_handle_request(c, nid);
	  nid->misc->trace_leave("Recurse done");
	  nid->misc->trace_leave("Last try done");
	  return;
	}
	nid->misc->trace_leave("Returns data");
	break;
      } else
	nid->misc->trace_leave("");
    }
  }
}

string parse(object id)
{
  //"<nobr>Allow Cache <input type=checkbox></nobr>\n";
  string res = #"
<input type=hidden name=action value=resolv.pike /><br />
URL: <input name=path value='&form.path;' size=60 />
<table cellpadding=0 cellspacing=10 border=0><tr><td align=left>
User: <input name=user value='&form.user;' size=12/></td>
<td align=left>&nbsp;&nbsp;&nbsp;
Password: <input name=password value='&form.password;' type=password size=12/>
</td></tr></table>
<cf-ok/> <cf-cancel href='?class=&form.class;'/>
";

  string p,a,b;
  object nid, c;
  string file, op = id->variables->path;

  if( id->variables->path )
  {
    sscanf( id->variables->path, "%*s://%*[^/]/%s", file );
    file = "/"+file;
    foreach( values(roxen->urls), mapping q )
    {
      nid = id->clone_me();
      nid->raw_url = file;
      nid->not_query = (http_decode_string((file/"?")[0]));
      if( (c=q->port->find_configuration_for_url( op, nid, 1 )) )
      {
        nid->conf = c;
        break;
      }
    }

    if(!c)
      return "There is no configuration available that matches this URL.\n";

    id->variables->path = nid->not_query;
    nid->variables = ([]);

    if(!(int)id->variables->cache)
      nid->pragma = (<"no-cache">);
    else
      nid->pragma = (<>);

    resolv = "Resolving " + link(op, id->variables->path) + " in " + link_configuration(c) +
           "<br /><hr noshade size=1 width=100%>";

    nid->misc->trace_enter = trace_enter_ol;
    nid->misc->trace_leave = trace_leave_ol;
    resolv += "<p><ol>";
    nid->raw_url = id->variables->path;
    string f = nid->scan_for_query(nid->raw_url);
    string a;

//     nid->misc->trace_enter("Checking for cookie.\n", 0);
    if (sscanf(f, "/<%s>/%s", a, f)==2)
    {
      nid->config_in_url = 1;
      nid->mod_config = (a/",");
      f = "/"+f;
//       nid->misc->trace_leave(sprintf("Got cookie %O.\n", a));
    } else {
//       nid->misc->trace_leave("No cookie.\n");
    }

//     nid->misc->trace_enter("Checking for prestate.\n", 0);
    if ((sscanf(f, "/(%s)/%s", a, f)==2) && strlen(a))
    {
      nid->prestate = aggregate_multiset(@(a/","-({""})));
      f = "/"+f;
//       nid->misc->trace_leave(sprintf("Got prestate %O\n", a));
    } else {
//       nid->misc->trace_leave("No prestate.\n");
    }

    nid->misc->trace_enter(sprintf("Simplifying path %O\n", f), 0);
    nid->not_query = simplify_path(f);
    nid->misc->trace_leave(sprintf("Got path %O\n", f));
    nid->conf = c;
    nid->method = "GET";
    if (id->variables->user && id->variables->user!="")
    {
      array(string) y;
      nid->misc->trace_enter(sprintf("Checking auth %O\n", 
                                     id->variables->user), 0);
      nid->rawauth
        = "Basic "+MIME.encode_base64(id->variables->user+":"+
                                      id->variables->password);

      nid->realauth=id->variables->user+":"+id->variables->password;

      nid->auth=({0,nid->realauth});
      if(c && c->auth_module)
        nid->auth = c->auth_module->auth( nid->auth, nid );
      nid->misc->trace_leave(sprintf("Got auth %O\n", nid->auth));
    }
    else {
      nid->rawauth = 0;
      nid->realauth = 0;
      nid->auth = 0;
    }

    resolv_handle_request(c, nid);
    while(level>0)
      nid->misc->trace_leave("");
    resolv += "</ol>";
    res += "<p><blockquote>"+resolv+"</blockquote>";
  }
  id->variables->path = op || "";
  return res;
}
