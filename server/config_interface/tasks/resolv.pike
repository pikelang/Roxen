/*
 * $Id: resolv.pike,v 1.26 2002/06/13 18:56:11 nilsson Exp $
 */
inherit "wizard";
inherit "../logutil";

constant task = "debug_info";
constant name = "Resolve path...";
constant doc  = "Check which modules handles the path you enter in the form";

string link(string to, string name)
{
  return sprintf("<a href=\"%s\">%s</a>", to, name);
}

string link_configuration(Configuration c, void|string cf_locale)
{ 
  return link(@get_conf_url_to_virtual_server(c, cf_locale)); 
}

string module_name(function|RoxenModule|RXML.Tag m)
{
  m = Roxen.get_owning_module (m);
  if(!m) return "";

  string name;
  catch (name = Roxen.get_modfullname (m));
  if (!name) return "<font color='red'>Unavailable</font>";

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

  return "<font color='darkgreen'>"+name+"</font>";
}

string resolv;
int level, prev_level;

string anchor(string title)
{
  while(level < prev_level)
    m_delete(et, (string)prev_level--);
  prev_level = level;
  et[(string)level]++;

  array(string) anchor = level > 0 ? allocate(level) : ({});
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
  if(level>1) {efont="</font>";font="<font size='-1'>";}
  resolv += (font+"</ol>"+
#if efun(gethrtime)
	     "Time: "+sprintf("%.5f",delay/1000000.0)+
#endif
#if efun(gethrvtime)
	     " (CPU = "+sprintf("%.2f)", delay2/1000000.0)+
#endif /* efun(gethrvtime) */
	     "<br />"+Roxen.html_encode_string(desc)+efont)+"<p>";

}

void trace_enter_table(string type, function|object module)
{
  level++;
  string efont="", font="";
  if(level>2) {efont="</font>";font="<font size='-1'>";}
  resolv += ("<tr>"
	     +(level>1?("<td width='1' bgcolor='blue'>"
			"<img src=\"/image/unit.gif\" alt=\"|\"/></td>") :"")
	     +"<td width='100%'>"+font+type+" "+module_name(module)+
	     "<table width='100%' border='0' cellspacing='10' border='0' "
	     "cellpadding='0'>");

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
  if(level>1) {font="<font size='-1'>";}
  resolv += ("</td></tr></table><br />"+font+
#if efun(gethrtime)
	     "Time: "+sprintf("%.5f",delay/1000000.0)+
#endif
	     "<br />"+Roxen.html_encode_string(desc)+efont)+"</td></tr>";
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

string parse( RequestID id )
{

  string res = "";  //"<nobr>Allow Cache <input type=checkbox></nobr>\n";
  res += "<input type='hidden' name='task' value='resolv.pike' />\n"
    "<font size='+2'>"+ name + "</font><br />\n"
    "<table cellpadding='0' cellspacing='10' border='0'>\n"
    "<tr><td align='left'>URL: </td><td align='left'>"
    "<input name='path' value='&form.path;' size='60' /></td></tr>\n"
    "<tr><td align='left'>User: </td><td align='left'>"
    "<input name='user'  value='&form.user;' size='12' />"
    "&nbsp;&nbsp;&nbsp;Password: "
    "<input name='password' value='&form.password;' type='password' "
    "size='12' /></td></tr></table>\n"
    "<cf-ok/><cf-cancel href='?class=&form.class;'/>\n";

  string p,a,b;
  object nid, c;
  string file, op = id->variables->path;

  if( id->variables->path )
  {
    sscanf( id->variables->path, "%*s://%*[^/]/%s", file );

    file = "/"+file;
    // pass 1: Do real glob matching.
    foreach( indices(roxen->urls), string u )
    {
      mixed q = roxen->urls[u];
      if( glob( u+"*", id->variables->path ) )
      {
        // werror(id->variables->path +" matches "+u+"\n");
        nid = id->clone_me();
	nid->misc -= ([ "authenticated_user" : 1 ]);
        nid->raw_url = file;
        nid->not_query = (http_decode_string((file/"?")[0]));
	string host;
	sscanf(id->variables->path, "%*s://%[^/]", host);
	if (host) {
	  nid->misc->host = host;
	}
        if( (c = q->port->find_configuration_for_url( op, nid, 1 )) )
        {
          nid->conf = c;
          break;
        }
      } 
    }

    if(!c)
    {
      // pass 2: Find a configuration with the 'default' flag set.
      foreach( roxen->configurations, c )
        if( c->query( "default_server" ) )
        {
          nid = id->clone_me();
	  nid->misc -= ([ "authenticated_user" : 1 ]);
          nid->raw_url = file;
          nid->not_query = (http_decode_string((file/"?")[0]));
          nid->conf = c;
          break;
        }
        else
          c = 0;
    }
    if(!c)
    {
      // pass 3: No such luck. Let's allow default fallbacks.
      foreach( indices(roxen->urls), string u )
      {
        mixed q = roxen->urls[u];
        nid = id->clone_me();
	nid->misc -= ([ "authenticated_user" : 1 ]);
        nid->raw_url = file;
        nid->not_query = (http_decode_string((file/"?")[0]));
        if( (c = q->port->find_configuration_for_url( op, nid, 1 )) )
        {
          nid->conf = c;
          break;
        }
      }
    }
    
    if(!c) {
      res += "<p><font color='red'>There is no configuration available that matches "
	"this URL.</font></p>";
      return res;
    }

    id->variables->path = nid->not_query;

    foreach( indices( nid->real_variables ), string x )
      m_delete( nid->real_variables, x );

    if(!(int)id->variables->cache)
      nid->pragma = (<"no-cache">);
    else
      nid->pragma = (<>);

    resolv = "Resolving " +
      link(op, id->variables->path) + " in " +
      link_configuration(c, id->misc->cf_locale) +  
      "<br /><hr noshade size='1' width='100%'/>";

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
      nid->misc->user = id->variables->user;
      nid->misc->password = id->variables->password;
      if(c && c->auth_module)
        nid->auth = c->auth_module->auth( nid->auth, nid );
      nid->misc->trace_leave(sprintf("Got auth %O\n", nid->auth));
    }
    else 
    {
      nid->rawauth = 0;
      nid->realauth = 0;
      nid->auth = 0;
    }

    resolv_handle_request(c, nid);
    while(level>0)
      nid->misc->trace_leave("");
    resolv += "</ol></p>";
    res += "<p><blockquote>"+resolv+"</blockquote></p>";
  }
  id->variables->path = op || "";
  return res;
}
