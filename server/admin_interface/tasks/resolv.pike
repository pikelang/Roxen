/*
 * $Id: resolv.pike,v 1.32 2004/05/31 23:01:45 _cvs_stephen Exp $
 */
inherit "wizard";
inherit "../logutil";

constant task = "debug_info";
constant name = "Resolve path...";
constant  doc = "Check which modules handles the path you enter in the form";

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
		       @get_conf_url_to_module(c->name+"/"+mn), core->filename(m));
	break;
      }
      else if(mod->copies && !zero_type(search(mod->copies, m)))
      {
	name = sprintf("<a href=\"%s\">%s</a> (%s)",
		       @get_conf_url_to_module(c->name+"/"+mn+"#"+search(mod->copies, m)),
		       core->filename(m));
	break;
      }
    }
  }

  return "<font color='&usr.fade3;'>"+name+"</font>";
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
mapping et2 = ([]);

void trace_enter_ol(string type, function|object module)
{
  level++;

  string font="";
  if(level>2) font="<font size=-1>";
  resolv += ((prev_level >= level ? "<br />\n" : "") +
	     anchor("")+"<li>"+
	     type + " " + module_name(module) + "<br />\n" +
	     font + "<ol>");
#if efun(gethrvtime)
  et2[level] = gethrvtime();
#endif
#if efun(gethrtime)
  et[level] = gethrtime();
#endif
}

string format_time (int hrstart, int hrvstart)
{
  return
#if efun(gethrtime) || efun(gethrvtime)
    "<i>" +
#if efun(gethrtime)
    sprintf ("Real time: %.5f", (gethrtime() - hrstart)/1000000.0) +
#endif
#if efun(gethrvtime)
    sprintf (" CPU time: %.2f", (gethrvtime() - hrvstart)/1000000.0) +
#endif /* efun(gethrvtime) */
    "</i><br />\n"
#else
    ""
#endif
    ;
}

void trace_leave_ol(string desc)
{
#if efun(gethrtime)
  int delay = gethrtime()-et[level];
#endif
#if efun(gethrvtime)
  int delay2 = gethrvtime()-et2[level];
#endif
  string efont="";
  if(level>2) efont="</font>";
  resolv += ("</ol>" + efont + "\n" +
	     (sizeof (desc) ? Roxen.html_encode_string(desc) + "<br />\n" : "") +
	     format_time (et[level], et2[level]));
  level--;
}

void trace_enter_table(string type, function|object module)
{
  level++;
  string efont="", font="";
  if(level>2) {efont="</font>";font="<font size='-1'>";}
  resolv += ("<tr>"
	     +(level>1?("<td width='1' bgcolor='blue'>"
	      "<img src=\"/*/unit\" height=1 width=1 alt=\"|\"/></td>") :"")
	     +"<td width='100%'>"+font+type+" "+module_name(module)+
	     "<table width='100%' border='0' cellspacing='10' "
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
  res +=
    "<input type='hidden' name='task' value='resolv.pike' />\n"
    "<font size='+1'><b>"+ name + "</b></font><p />\n"
    "<table cellpadding='0' cellspacing='10' border='0'>\n"
    "<tr><td align='left'>URL: </td><td align='left'>"
    "<input name='path' value='&form.path;' size='60' /></td></tr>\n"
    "<tr><td align='left'>User: </td><td align='left'>"
    "<input name='user'  value='&form.user;' size='12' />"
    "&nbsp;&nbsp;&nbsp;Password: "
    "<input name='password' value='&form.password;' type='password' "
    "size='12' /></td></tr></table>\n"
    "<cf-ok/><cf-cancel href='?class=&form.class;'/>\n";

  core.InternalRequestID nid = core.InternalRequestID();
  nid->client = id->client;
  nid->client_var = id->client_var + ([]);
  nid->supports = id->supports;

  if( id->variables->path )
  {
    mixed err = catch(nid->set_url (id->variables->path));
    if(err || !nid->conf) {
      res += "<p><font color='red'>There is no configuration "
	"available that matches this URL.</font></p>";
      return res;
    }

    string canonic_url = nid->url_base() + nid->raw_url[1..];

    if(!(int)id->variables->cache)
      nid->pragma = (<"no-cache">);
    else
      nid->pragma = (<>);

    resolv =
      "<hr noshade size='1' width='100%'/>\nCanonic URL: " +
      Roxen.html_encode_string(canonic_url) + "<br />\n"
      "Resolving " +
      link(canonic_url, Roxen.html_encode_string (nid->not_query)) +
      " in " +
      link_configuration(nid->conf, id->misc->cf_locale) + "<br />\n"
      "<ol>";

    nid->misc->trace_enter = trace_enter_ol;
    nid->misc->trace_leave = trace_leave_ol;

    if (id->variables->user && id->variables->user!="")
    {
      nid->rawauth
        = "Basic "+MIME.encode_base64(id->variables->user+":"+
                                      id->variables->password);
      nid->realauth=id->variables->user+":"+id->variables->password;
    }

    int hrstart, hrvstart;
#if efun(gethrtime)
    hrstart = gethrtime();
#endif
#if efun(gethrvtime)
    hrvstart = gethrvtime();
#endif
    resolv_handle_request(nid->conf, nid);
    while(level>0)
      nid->misc->trace_leave("");
    res += resolv + "</ol>\n" + format_time (hrstart, hrvstart);
  }
  return res;
}
