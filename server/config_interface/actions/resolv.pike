/*
 * $Id$
 */
inherit "wizard";
inherit "../logutil";
#include <roxen.h>
#include <request_trace.h>
//<locale-token project="admin_tasks">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("admin_tasks",X,Y)

constant action = "debug_info";

string name= LOCALE(27, "Resolve path...");
string doc = LOCALE(28, 
		    "Check which modules handles the path you enter in "
		    "the form");

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
  catch (name = Roxen.html_encode_string(Roxen.get_modfullname (m)));
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

mapping et = ([]);

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

RequestID nid;

mapping rtimes = ([]);
mapping vtimes = ([]);

void trace_enter_ol(string type, function|object module, void|int timestamp)
{
  level++;
  resolv +=
    (/*((prev_level >= level ? "<br />\n" : "")*/ "" +
     anchor("") +
     "<li class='timing open'>" +
     "<span class='toggle' onmousedown='return toggle_vis(event, this.parentNode);'></span>" +
     Roxen.html_encode_string(type) + " " + module_name(module) +
     "<div class='inner'>"
     "<ol class='timing'>");

#if efun(gethrvtime)
  // timestamp is cputime.
#if efun (gethrtime)
  rtimes[level] = gethrtime();
#endif
  vtimes[level] = (timestamp || gethrvtime()) - nid->misc->trace_overhead;
#elif efun (gethrtime)
  // timestamp is realtime.
  rtimes[level] = (timestamp || gethrtime()) - nid->misc->trace_overhead;
#endif
}

#if efun(gethrtime) || efun(gethrvtime)
#define HAVE_TRACE_TIME
string format_time (int hrrstart, int hrvstart, int timestamp)
{
  int hrnow, hrvnow;

#if efun (gethrvtime)
  // timestamp is cputime.
#if efun (gethrtime)
  hrnow = gethrtime();
#endif
  hrvnow = (timestamp || gethrvtime()) - nid->misc->trace_overhead;
#else
  // timestamp is realtime.
  hrnow = (timestamp || gethrtime()) - nid->misc->trace_overhead;
#endif

  return ({
    hrvnow && ("CPU time: " + Roxen.format_hrtime (hrvnow - hrvstart)),
    hrnow && ("Real time: " + Roxen.format_hrtime (hrnow - hrrstart))
  }) * ", ";
}
#endif

void trace_leave_ol(string desc, void|int timestamp)
{
  string html_desc = Roxen.html_encode_string(desc || "");
  if (has_value(html_desc, "\n"))
    html_desc = "<pre>" + html_desc + "</pre>\n";
  else if (html_desc != "")
    html_desc += "<br />\n";
  resolv +=
    "</ol>\n" + html_desc +
#ifdef HAVE_TRACE_TIME
    "<i class='timing'>" + format_time (rtimes[level], vtimes[level], timestamp) + "</i>"
#endif
    "</div></li>";
  level--;
}

string resolv_describe_backtrace(mixed err)
{
  catch {
    return describe_backtrace(err);
  };
  catch {
    return sprintf("Thrown value: %O\n", err);
  };
  return sprintf("Unformatable %t value.\n", err);
}

mapping|int resolv_get_file(object c, object nid)
{
  mixed err = catch {
      return c->get_file(nid);
    };

  if (!level) {
    trace_enter_ol("", this_object());
  }
  trace_leave_ol(sprintf("Uncaught exception thrown:\n\n%s\n",
			 resolv_describe_backtrace(err)));

  while(level) {
    trace_leave_ol("");
  }
  return ([]);
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

  if(!resolv_get_file(c, nid))
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
    "<input type='hidden' name='action' value='resolv.pike' />\n"
    "<font size='+1'><b>"+ name + "</b></font><p />\n"
    "<table cellpadding='0' cellspacing='10' border='0'>\n"
    "<tr><th align='left'>" +LOCALE(29, "URL")+ ": </th><td>"
    "<input name='path' value='&form.path;' size='60' /></td></tr>\n"
    "<tr><th align='left'>" + LOCALE(296, "HTTP auth") + ": </th>"
    "<td>" +LOCALE(206, "User")+ ": "
    "<input name='user'  value='&form.user;' size='12' />"
    "&nbsp;&nbsp;&nbsp;" +LOCALE(30,"Password")+ ": "
    "<input name='password' value='&form.password;' type='password' "
    "size='12' /></td></tr>\n"
    "<tr><td align='left' valign='top'>" + LOCALE(297, "Form variables") + ":</td><td align='left'>"
    "<input type='text' size='60' name='form_vars' value='&form.form_vars;' />"
    "<br/>Example: <tt>id=234&amp;page=3&amp;hidden=1</tt></td>\n"
    "</tr><tr><td align='left' valign='top'>" + LOCALE(325, "HTTP Cookies") + ": </td><td align='left'>"
    "<textarea cols='58' row='4' name='cookies'>&form.cookies;</textarea><br />"
    "Cookies are separated by a new line for each cookie you want to set. "
    "Example:"
    "<pre>UniqueUID=eIkT67lksoOe23q\nSessionID=123123:sadfi:114lj</pre></td>"
    "</tr></table>\n"
    "<table border='0'><tr><td><cf-ok/></td><td><cf-cancel href='?class=&form.class;'/></td></tr></table>\n";

  res +=
    #"<script language='javascript'>
        function toggle_vis(evt, li_elem) {
          var items = [ li_elem ];
          if (evt.shiftKey) {
            //  Include all sibling <li> elements
            items = [ ];
            var candidates = li_elem.parentNode.children;
            for (var i = 0; i < candidates.length; i++)
              if (candidates[i].nodeType == 1 &&
                  candidates[i].tagName.toLowerCase() == 'li')
                items.push(candidates[i]);
          }
          var is_open = li_elem.className.match('open');
          var from_cls = is_open ? 'open' : 'closed';
          var to_cls = is_open ? 'closed' : 'open';
          for (var j = 0; j < items.length; j++) {
            items[j].className = items[j].className.replace(from_cls, to_cls);
          }
          if (evt.preventDefault) {
            evt.preventDefault();
            evt.stopPropagation();
          } else {
            evt.cancelBubble = true;
            evt.returnValue = false;
          }
          return false;
        }
      </script>";

  nid = roxen.InternalRequestID();
  nid->client = id->client;
  nid->client_var = id->client_var + ([]);
  nid->supports = id->supports;
  string raw_vars = id->variables->form_vars;
  if( raw_vars && sizeof(raw_vars) ) {
    if( !nid->variables )
      nid->variables = ([]);
    foreach( raw_vars /"&", string val_pair ) {
      string idx, val;
      if( sscanf(val_pair, "%s=%s", idx, val) == 2 ) {
	if(nid->variables[idx]) {
	  if(arrayp(nid->variables[idx]))
	    nid->variables[idx] += ({ val });
	  else
	    nid->variables[idx] = ({ nid->variables[idx], val });
	} else {
	  nid->variables[idx] = val;
	}
      }
    }
  }
  string raw_cookies = id->variables->cookies;
  if( raw_cookies && sizeof(raw_cookies) ) {
    mapping(string:string) faked_cookies = ([]);
    foreach(raw_cookies / "\n", string raw_cookie) {
      string c_idx, c_val;
      if( sscanf( raw_cookie, "%s=%s", c_idx, c_val) == 2) {
	faked_cookies += ([ c_idx : c_val ]);
      }      
    }
    if( sizeof(faked_cookies) ) {
      if( nid->cookies && sizeof(indices(nid->cookies)) ) {
	foreach(nid->cookies; string c_idx; string c_val )
	  faked_cookies[c_idx] = c_val;
	nid->cookies = faked_cookies;
      } else
	nid->cookies = faked_cookies;
    }
  }

  if( id->variables->path )
  {
    string err_msg;
    if (mixed err = catch( nid->set_url (id->variables->path) )) {
      err_msg = LOCALE(188, "Unable to parse URL.");
      report_debug("Unable to parse URL: " + describe_backtrace(err));
    }
    else if(!nid->conf) {
      err_msg = LOCALE(31, "There is no configuration available that matches "
		       "this URL.");
    }
    if (err_msg)
      return "<p><font color='red'>" + err_msg + "</font></p>" + res; 

    string canonic_url = nid->url_base() + nid->raw_url[1..];

    if(!(int)id->variables->cache)
      nid->pragma = (<"no-cache">);
    else
      nid->pragma = (<>);

    resolv =
      "<hr />\n" +
      LOCALE(179, "Canonic URL: ") +
      Roxen.html_encode_string(canonic_url) + "<br />\n" +
      LOCALE(32, "Resolving")+" " +
      link(canonic_url, Roxen.html_encode_string (nid->not_query)) +
      " "+LOCALE(33, "in")+" " +
      link_configuration(nid->conf, id->misc->cf_locale) + "<br />\n"
      "<ol class='timing'>";

    nid->misc->trace_enter = trace_enter_ol;
    nid->misc->trace_leave = trace_leave_ol;

    if (id->variables->user && id->variables->user!="")
    {
      nid->rawauth
        = "Basic "+MIME.encode_base64(id->variables->user+":"+
                                      id->variables->password, 1);
      nid->realauth=id->variables->user+":"+id->variables->password;
    }

    int hrrstart, hrvstart;
#if efun(gethrtime)
    hrrstart = gethrtime();
#endif
#if efun(gethrvtime)
    hrvstart = gethrvtime();
#endif

    resolv_handle_request(nid->conf, nid);

    int endtime = HRTIME();
    string trace_timetype;
#if efun (gethrvtime)
    trace_timetype = "CPU time";
#elif efun (gethrtime)
    trace_timetype = "Real time";
#endif
    while(level>0)
      trace_leave_ol ("Trace nesting inconsistency!", endtime);
    res += resolv + "</ol>\n";

    if (trace_timetype) {
      res += format_time (hrrstart, hrvstart, endtime);
      if (int oh = nid->misc->trace_overhead) {
	res += ", trace overhead (" + trace_timetype + "): " +
	  Roxen.format_hrtime (oh) + "<br />\n"
	  "Note: The trace overhead has been mostly canceled out from the " +
	  trace_timetype + " values above.";
      }
    }
  }

  destruct (nid);

  return res;
}
