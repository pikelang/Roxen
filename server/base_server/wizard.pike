// This file is part of Roxen WebServer.
// Copyright © 1997 - 2009, Roxen IS.
//
// Wizard generator
// $Id$

/* wizard_automaton operation (old behavior if it isn't defined):

   mapping(string:array) wizard_automaton = ([
     "foo": ({dispatch, prev_page, next_page, page_name}),
     ...
   ]);

   dispatch:	A string redirects the wizard to that page. 0 or the
		name of this page continues with it.
   prev_page:	A string is the page for the previous button. 0 if none.
   next_page:	A string is the page for the next button. 0 makes an
		ok button instead. -1 gives neither button.
   page_name:	Optional page name. Defaults to "".

   Any of these may be a function that returns the value:

   lambda (RequestID id, string page, mixed ... args);

   id:		Request id.
   page:	The entry in wizard_automaton.
   args:	The extra args to wizard_menu() or wizard_for().

   Other callbacks:

   o  string|mapping page_foo (RequestID id, mixed ... args);

      The function that produces page "foo". May return 0 to cause a
      redirect to the next page (or the previous one if the user
      pressed previous to enter it). Goes to the done page if there
      isn't any such page.

   o  int verify_foo (RequestID id, mixed ... args);

      A verify function that's run when the user presses next or ok in
      page "foo". Returns 0 if it's ok to leave the page, anything
      else re-runs the page function to redisplay the page.

   o  string|mapping wizard_done (RequestID id, mixed ... args);

      The function for the done page, from which it's not possible to
      return to the other wizard pages. May return 0 to skip the page.
      (Differences from old behavior: -1 is not a meaningful return
      value and a string is run through parse_wizard_page().)

   The dispatch function is always run before any other function for a
   page. That makes it suitable to contain all page init stuff and
   also state sanity checks, since it can bail to other pages on
   errors etc. The intention is also that it should be shared between
   several pages that has init code in common.

   Special pages:

   "start":	Start page.
   "done":	Finish page. The page function is wizard_done(). Only
		dispatch is used in the wizard_automaton entry.
   "cancel":	Cancels the wizard. Has no wizard_automaton entry.

   Bugs: There's no good way to share variables between the functions.
   Can we say id->misc? :P */

inherit "roxenlib";
#include <roxen.h>

//<locale-token project="roxen_message">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_message",X,Y)

#ifdef DEBUG_WIZARD
# define DEBUGMSG(msg) report_debug(msg)
#else
# define DEBUGMSG(msg)
#endif


string loc_encode(string val, void|mapping args, void|string def)
{
  string quote = args->quote || def || "html";

  switch (quote) {
  case "html": return html_encode_string(val); break;
  case "none": return val; break;
  }
  return val;
}


string wizard_tag_var(string n, mapping m, mixed a, mixed|void b)
{
  RequestID id;
  if(n=="cvar") // Container. Default value in 'a', id in 'b'.
  {
    id = b;
    if(m->type == "select" || m->type == "select_multiple")
      if (m->parse)
        m->options = (replace(parse_rxml( a, id ), ",", "__CoMma__") / "\n" -
		      ({ "" })) * ",";
      else
	m->options = (a / "\n") * ",";
    else if (m->parse)
      m["default"] = parse_rxml( a, id );
    else
      m["default"] = a;
  } else // tag. No contents, id in 'a'.
    id = a;

  string current = id->variables[m->name] || m["default"];
  if(current)
    current = current +"";
  switch(m->type)
  {
   default: // String or password field or hidden value....
    if((m->type != "password") && (m->type != "hidden"))
      m->type = "text";
    m_delete(m,"default");
    m->value = loc_encode(current||m->value||"", m, "none");
    if(!m->size)m->size="60";
    m_delete(m,"quote");
    return make_tag("input", m);

   case "list": // String....
    string n = m->name, res="<table cellpadding=\"0\" cellspacing=\"0\" border=\"0\">";
    if(!id->variables[n]) id->variables[n]=current;

    m->type = "text";
    if(!m->size)m->size="60";
    m_delete(m,"default");
    foreach((current||"")/"\0"-({""}), string v)
    {
      res+="<tr><td>"+loc_encode(v, m, "html")+"</td><td><font size=\"-2\">";
      m->name="_delete_"+n+":"+v;
      m->value = " " + LOCALE(16, "Remove") + " ";
      m->type = "submit";
      res+=make_tag("input",m-(["quote":""]))+"</td></tr>";
    }
    m->name = "_new_"+n;
    m->type = "text";
    m->value = "";
    res+= "<tr><td>"+make_tag("input", m)+"</td><td><font size=\"-2\">";
    m->name="_Add";
    m->value = " " + LOCALE(18, "Add") + " ";
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
    return make_container("textarea", m-(["quote":""]), loc_encode(current||"", m, "html"));

   case "radio":
    m_delete(m,"default");
    if((!id->variables[m->name] && current) || (current==m->value))
      m->checked="checked";
    return make_tag("input",m);

   case "checkbox":
    m_delete(m,"default");
    if (!m->value) m->value="on";
    if (current && current != "0" &&
	(current == "1"||mkmultiset(current/"\0")[m->value]))
      m->checked="checked";
    res=make_tag("input",m);
    m->type="hidden";   //  Yes, this hidden var is needed! Cleared boxes may
    m->value="0";       //  otherwise revert to their initial set state.
    m_delete(m, "id");  //  Can't have the same ID twice
    return res+make_tag("input", m);

   case "int":
    m->type = "number";
    m_delete(m,"default");
    m->value = (string)((int)current);
    if(!m->size)m->size="8";
    return make_tag("input", m);

   case "float":
    m->type = "number";
    m_delete(m,"default");
    m->value = (string)((float)current);
    if(!m->size)m->size="14,1";
    return make_tag("input", m);

   case "color":
     int h, s, v;
     array a;
     if(id->variables[m->name+".hsv"])
       sscanf(id->variables[m->name+".hsv"], "%d,%d,%d", h, s, v);
     else
     {
       a = parse_color(current||"black");
       [h,s,v] = rgb_to_hsv(@a);
     }
     if(id->variables[m->name+".foo.x"]) {
       h = (int)id->variables[m->name+".foo.x"];
       v = 255-(int)id->variables[m->name+".foo.y"];
     } else if(id->variables[m->name+".bar.y"])
       s=255-(int)id->variables[m->name+".bar.y"];
     else if(id->variables[m->name+".entered"] &&
	     strlen(current=id->variables[m->name+".entered"]))
     {
       a = parse_color(current||"black");
       [h,s,v] = rgb_to_hsv(@a);
     }

     m_delete(id->variables, m->name+".foo.x");
     m_delete(id->variables, m->name+".foo.y");
     m_delete(id->variables, m->name+".bar.x");
     m_delete(id->variables, m->name+".bar.y");
     id->variables[m->name+".hsv"] = h+","+s+","+v;

     if(!a)
       a = hsv_to_rgb(h,s,v);
     string bgcol = sprintf("#%02x%02x%02x",a[0],a[1],a[2]);
     id->variables[m->name] = bgcol;
     return
     ("<table><tr>\n"
      "<td width=\"258\" rowspan=\"2\">\n"
      "  <table bgcolor=\"#000000\" cellpadding=\"1\" border=\"0\" cellspacing=\"0\" width=\"258\"><tr><td>\n"
      "  <input type=\"image\" name=\""+m->name+".foo\" src=\"/internal-roxen-colsel\""
        " width=\"256\" height=\"256\" border=\"0\"></td>\n"
      "</table>\n"
      "</td>\n"
      "<td width=\"30\" rowspan=\"2\"></td>\n"
      "<td width=\"32\" rowspan=\"2\">\n"
      "  <table bgcolor=\"#000000\" cellpadding=\"1\" border=\"0\" cellspacing=\"0\" width=\"32\"><tr><td>\n"
      "<input type=\"image\" src=\"/internal-roxen-colorbar:"+
      (string)h+","+(string)v+","+(string)s+"\" "
      "name=\""+m->name+".bar\" width=\"30\" height=\"256\" border=\"0\"></td>"
      "</table>\n"
      "</td>\n"
      "<td width=\"32\" rowspan=\"2\"></td>\n"
      "<td width=\"120\">\n"
      "  <table bgcolor=\"#000000\" cellpadding=\"1\" border=\"3\" cellspacing=\"0\" width=\"90\">\n"
      "  <tr><td height=\"90\" width=\"90\" bgcolor=\""+bgcol+"\">&nbsp;"+
      (m->tt?"<font color=\""+m->tc+"\">"+m->tt+"</font>":"")
      +"</td></table>\n"
      "</td><tr>\n"
      "<td width=\"120\">\n"
      "<b>R:</b> "+(string)a[0]+"<br />\n"
      "<b>G:</b> "+(string)a[1]+"<br />\n"
      "<b>B:</b> "+(string)a[2]+"<br />\n"
      "<hr size=\"2\" align=\"left\" noshade=\"noshade\" width=\"70\" />\n"
      "<b>H:</b> "+(string)h+"<br />\n"
      "<b>S:</b> "+(string)s+"<br />\n"
      "<b>V:</b> "+(string)v+"<br />\n"
      "<hr size=\"2\" align=\"left\" noshade=\"noshade\" width=\"70\" />\n"+
      "<font size=\"-1\"><input type=\"string\" name=\""+
      m->name+".entered\" size=\"8\" value=\""+
      color_name(a)+"\"> <input type=\"submit\" value=\"OK\"></font></td></table>\n");

   case "color-small":
     if(id->variables[m->name+".hsv"])
       sscanf(id->variables[m->name+".hsv"], "%d,%d,%d", h, s, v);
     else
     {
       a = parse_color(current||"black");
       [h,s,v] = rgb_to_hsv(@a);
     }
     if(id->variables[m->name+".foo.x"]) {
       h = ((int)id->variables[m->name+".foo.x"])*2;
       v = 255-((int)id->variables[m->name+".foo.y"])*2;
     } else if(id->variables[m->name+".bar.y"])
       s = 255-((int)id->variables[m->name+".bar.y"])*2;
     else if(id->variables[m->name+".entered"] &&
	     strlen(current=id->variables[m->name+".entered"]))
     {
       a = parse_color(current||"black");
       [h,s,v] = rgb_to_hsv(@a);
     }

     m_delete(id->variables, m->name+".foo.x");
     m_delete(id->variables, m->name+".foo.y");
     m_delete(id->variables, m->name+".bar.x");
     m_delete(id->variables, m->name+".bar.y");
     id->variables[m->name+".hsv"] = h+","+s+","+v;

     if(!a)
       a = hsv_to_rgb(h,s,v);
     bgcol = sprintf("#%02x%02x%02x",a[0],a[1],a[2]);
     id->variables[m->name] = bgcol;
     return
     ("<table border=\"0\" cellpadding=\"0\" cellspacing=\"0\"><tr>\n"
      "<td rowspan=\"2\">\n"
      "  <table bgcolor=\"#000000\" cellpadding=\"1\" border=\"0\" cellspacing=\"0\"><tr><td>\n"
      "    <input type=\"image\" name=\""+m->name+".foo\" "
            "src=\"/internal-roxen-colsel-small\" "
            "width=\"128\" height=\"128\" border=\"0\"></td>\n"
      "  </table>\n"
      "</td>\n"
      "<td width=\"8\" rowspan=\"2\"><img src=\"/internal-roxen-unit\" width=\"8\" /></td>\n"
      "<td width=\"18\" rowspan=\"2\">\n"
      "  <table bgcolor=\"#000000\" cellpadding=\"1\" border=\"0\" cellspacing=\"0\"><tr><td>\n"
      "    <input type=\"image\" src=\"/internal-roxen-colorbar:"+
             (string)h+","+(string)v+","+(string)s+"\" "
            "name=\""+m->name+".bar\" width=\"16\" height=\"128\" border=\"0\"></td>\n"
      "  </table>\n"
      "</td>\n"
      "<td width=\"8\" rowspan=\"2\"><img src=\"/internal-roxen-unit\" width=\"8\" /></td>\n"
      "<td>\n"
      "  <table bgcolor=\"#000000\" width=\"64\" border=\"3\" "
               "cellpadding=\"1\" cellspacing=\"0\"><tr>\n"
      "    <td height=\"64\" width=\"64\" bgcolor=\""+bgcol+"\">&nbsp;"+
             (m->tt?"<font color=\""+m->tc+"\">"+m->tt+"</font>":"")+"\n"
      "    </td></tr>\n"
      "  </table>\n"
      "</td>\n"
      "<tr><td width=\"110\">\n"
      "<font size=\"-1\"><input type=\"string\" name=\""+
      m->name+".entered\" size=\"8\" value=\""+
      color_name(a)+"\"> <input type=\"submit\" value=\"" + LOCALE(38, "OK") + "\"></font>"
      "</td></tr>\n"
      "</table>\n");

   case "color-js":
     //  Note: This code requires ColorSelector.js
     if (string color_input = id->variables[m->name])
       current = color_input;
     a = parse_color(current || "black");
     [h, s, v] = rgb_to_hsv(@a);
     if(!h && !s && !v)
       s = 255;
     current = upper_case(sprintf("#%02x%02x%02x", a[0], a[1], a[2]));
     id->variables[m->name] = current;

     int mark_x_left = 5 + (int) (h / 2);
     int mark_y_top = 5 + (int) ((255 - v) / 2);
     int mark_y_small_top = 5 + (int) ((255 - s) / 2);
     string output =
       "<script language='javascript'>\n"
       "  var PREFIX_h = " + h + ";\n"
       "  var PREFIX_s = " + s + ";\n"
       "  var PREFIX_v = " + v + ";\n"
       "  function PREFIX_colsel_click(event, in_bar, in_cross)\n"
       "  {\n"
       "    var hsv = colsel_click(event, \"PREFIX_\", PREFIX_h,\n"
       "                           PREFIX_s, PREFIX_v, in_bar, in_cross);\n"
       "    PREFIX_h = hsv[0];\n"
       "    PREFIX_s = hsv[1];\n"
       "    PREFIX_v = hsv[2];\n"+
       (m->onChange||"")+
       "  }\n"
       "  function PREFIX_colsel_type(value, update_field)\n"
       "  {\n"
       "    var hsv = colsel_type(\"PREFIX_\", value, update_field);\n"
       "    PREFIX_h = hsv[0];\n"
       "    PREFIX_s = hsv[1];\n"
       "    PREFIX_v = hsv[2];\n"+
       (m->onChange||"")+
       "  }\n"
       "</script>"
       "<js-popup args-variable='__popup' event='onClick' props='color_props'>"
       "  <img src='/internal-roxen-colsel-mark-x' id='PREFIX_mark_x'"
       "       onClick='PREFIX_colsel_click(event, 0, \"x\"); return false;'"
       "       style='position: absolute;"
       "              cursor:   crosshair;"
       "              z-index:  2'>"
       "  <img src='/internal-roxen-colsel-mark-y' id='PREFIX_mark_y'"
       "       onClick='PREFIX_colsel_click(event, 0, \"y\"); return false;'"
       "       style='position: absolute;"
       "              cursor:   crosshair;"
       "              z-index:  2'>"
       "  <img src='/internal-roxen-colsel-mark-y-small'"
       "       id='PREFIX_mark_y_small'"
       "       style='position: absolute;"
       "              cursor:   pointer;"
       "              z-index:  2'>"
       "  <table border='0' cellspacing='0' cellpadding='4' bgcolor='#ffffff'"
       "         class='roxen-color-selector'"
       "         style='border-top:    1px solid #888888;"
       "                border-left:   1px solid #888888;"
       "                border-bottom: 2px solid #888888;"
       "                border-right:  2px solid #888888'>"
       "    <tr>"
       "      <td style='border-right: 1px solid #888888'"
       "        ><img src='/internal-roxen-colsel-small'"
       "             width='128' height='128' style='cursor: crosshair'"
       "             onClick='PREFIX_colsel_click(event, 0); return false;'"
       "        /></td>"
       "      <td><img id='PREFIX_colorbar' width='16' height='128'"
       " src='/internal-roxen-colorbar-small:" + h + "," + v + ",-1'"
       "               style='cursor: pointer'"
       "               onClick='PREFIX_colsel_click(event, 1); return false;'"
       "        /></td>"
       "    </tr><tr>"
       "      <td colspan='2' style='border-top: 1px solid #888888'"
       "        ><img src='/internal-roxen-pixel-000000'"
       "              class='black'"
       "              width='76' height='10' style='cursor: pointer'"
       "              onClick='PREFIX_colsel_type(\"#000000\", 1);' "
       "        /><img src='/internal-roxen-pixel-ffffff'"
       "               class='white'"
       "               width='76' height='10' style='cursor: pointer'"
       "               onClick='PREFIX_colsel_type(\"#FFFFFF\", 1);' "
       "        /></td>"
       "    </tr>"
       "  </table>"
       "</js-popup>"

       //  These initializations used to be in the style attributes above
       //  but MSIE 6.0 failed to recognize them so we execute them explicitly
       //  instead.
       "<script language='javascript'>"
       "getObject('PREFIX_mark_x').style.top = '5px';"
       "getObject('PREFIX_mark_x').style.left = '" + mark_x_left + "px';"
       "getObject('PREFIX_mark_y').style.top = '" + mark_y_top + "px';"
       "getObject('PREFIX_mark_y').style.left = '5px';"
       "getObject('PREFIX_mark_y_small').style.top = '" + mark_y_small_top + "px';"
       "getObject('PREFIX_mark_y_small').style.left = '143px';"
       "</script>"

       "<table border='0' cellspacing='0' cellpadding='2'>"
       "<tr>"
       "  <td>"
       "    <input type='text' size='10' value='" + current + "' id='PREFIX_color_input' "
       "           name='" + m->name + "' onChange='PREFIX_colsel_type(this.value, 1);"+(m->onChange||"")+"' />"
       "  </td>"
       "  <td>"
       "    <table border='0' cellspacing='0' cellpadding='0' bgcolor='#ffffff'>"
       "      <tr>"
       "      	<td style='background: " + current + "; border: 1px solid #888888' "
       "      	    id='PREFIX_preview'"
       "      	  ><img src='/internal-roxen-colsel-arrow'"
       "                width='49' height='16' border='0'"
       "      	        style='border: 4px solid #ffffff; cursor: pointer'"
       "                ::='&form.__popup;'"
       "        ></td>"
       "      </tr>"
       "    </table>"
       "  </td>"
       "</tr>"
       "</table>";
     string clean_name = replace(m->name, "-", "_");
     return replace(output, "PREFIX", clean_name);

   case "font":
     m->type = "select";
     m->lines = "20";
     m->choices = roxen.fonts->available_fonts() * ",";
     if(id->conf && id->conf->modules["graphic_text"] && !m->noexample)
       res = ("<input type=\"submit\" value=\"" + LOCALE(47, "Example") + "\"><br />"+
	      ((current&&strlen(current))?
	       "<gtext font=\""+current+"\">" + LOCALE(48, "Example Text") + "</gtext><br />"
	       :""));
     m_delete(m, "noexample");
     return wizard_tag_var("var", m, id) + res;

   case "toggle":
    m_delete(m,"default");
    return make_container("select", m,
			  "<option"+((int)current?" selected=\"selected\"":"")+" value=\"1\">" +
			  LOCALE(49, "Yes") + "</option>\n"
			  "<option"+(!(int)current?" selected=\"selected\"":"")+" value=\"0\">" +
			  LOCALE(50, "No") + "</option>\n");

   case "select":
     if(!m->choices && m->options)
       m->choices = m->options;
     m_delete(m,"default");
     m_delete(m,"type");
     mapping m2 = copy_value(m);
     if (m->select_override) {
       if (!m->id) {
	 m->id = "wizard-select-" + random(65536) + "-" + random(65536);
       }
       m_delete(m2, "select_override");
       m2->id = m->id + "-selector";
       m2->onchange =
	 "var field = document.getElementById('" + m->id + "-field');"
	 "if (field) { ";
       if (m->select_none) {
	 m2->onchange +=
	   "  if (this.value == '" + m2->select_none +"') {"
	   "    field.setAttribute('disabled', 'yes');"
	   "    field.disabled = 'disabled';"
	   "    field.value = '';"
	   "  } else {"
	   "    field.disabled = '';"
	   "    field.removeAttribute('disabled');";
       }
       m2->onchange +=
	 "  if (this.value != '" + m->select_override +"') {"
	 "    field.value = this.value;"
	 "  }";
       if (m->select_none) {
	 m2->onchange +=
	   "  }";
       }
       m2->onchange +=
	 "}";
       if (m->autosubmit) {
	 m2->onchange += "submit();";
	 m_delete(m2, "autosubmit");
       }
     } else if (m->autosubmit) {
       m2->onchange = "javascript:submit();";
       m_delete(m2, "autosubmit");
     }
     m_delete(m2, "choices");
     m_delete(m2, "options");
     //escape the characters we need for internal purposes..
     m->choices=replace(m->choices,
			({"\\,", "\\:"}),
			({"__CoMma__", "__CoLon__"}));
     string tc = current && replace(current,
				    ({"\\,", "\\:"}),
				    ({"__CoMma__", "__CoLon__"}));

     array(string) choices = m->choices/",";

     foreach(choices, string c) {
       sscanf(c, "%[^:]", c);
       if (c == tc) {
	 tc = 0;
	 break;
       }
     }
     if (!tc) {
       tc = current;
     } else if (m->select_override) {
       tc = m->select_override;
     } else {
       // Unlisted choice selected!
       if (tc != "")
	 choices += ({ tc + ":" + tc });
       tc = current;
     }

     string selector =
       make_container("select", m2,
		      map(choices,
			  lambda(string s, string c, mapping m) {
        string t;
        if(sscanf(s, "%s:%s", s, t) != 2)
	  t = s;
	s=replace(s,({"__CoMma__",
		      "__CoLon__"}),({",",":"})); //can't be done before.
	t=replace(t,({"__CoMma__",
		      "__CoLon__"}),({",",":"}));

        return "<option value=\"" + s + "\" " +
	  (s==c ? " selected=\"selected\"":"") + ">" +
	  loc_encode(t, m, "html") + "</option>\n";
     }, tc, m)*"");

     if (m->select_override) {
       m2->id = m->id + "-field";
       m2->onchange =
	 "var selector = document.getElementById('" + m->id + "-selector');"
	 "if (selector) { "
	 "  selector.value = this.value;"
	 "  if (selector.value != this.value) {"
	 "    selector.value = '" + m->select_override + "';"
	 "  }"
	 "}";
       m2->value = "";
       if (current == m->select_none) {
	 m2->disabled = "yes";
       } else if (current != m->select_override) {
	 m2->value = current;
       }

       selector +=
	 "&nbsp;" + make_tag("input", m2) +
	 "<input type='hidden' name='__select_override_vars' "
	 "       value='" + m2->name + ":" + m->select_override + "' />";
     }

     return selector;

   case "select_multiple":
     if(!m->choices && m->options)
       m->choices = m->options;
    m_delete(m,"default");
    m_delete(m,"type");
    m2 = copy_value(m);
    m_delete(m2, "choices");
    m_delete(m2, "options");
    m2->multiple="1";
    //escape the characters we need for internal purposes..
    m->choices=replace(m->choices,
		       ({"\\,", "\\:"}),
		       ({"__CoMma__", "__CoLon__"}));

    return make_container("select", m2, map(m->choices/"," - ({ "" }),
				 lambda(string s, array c, mapping m) {
      string t;
      if(sscanf(s, "%s:%s", s, t) != 2)
        t = s;
      s=replace(s,({"__CoMma__",
		    "__CoLon__"}),({",",":"})); //can't be done before.
      t=replace(t,({"__CoMma__",
		    "__CoLon__"}),({",",":"}));

      return "<option value=\""+s+"\" "+(search(c,s)!=-1?"selected=\"selected\"":"")+">"+
	loc_encode(t, m, "html")+"</option>\n";
    },(current||"")/"\0",m)*"");
  }
}

mapping decompress_state(string from)
{
  if(!from) return ([]);
  from = MIME.decode_base64(from);
  catch
  {
    object gz = Gz;
    if(sizeof(indices(gz)))
      from = gz->inflate()->inflate(from);
    return decode_value(from);
  };
  return ([]);
}


string compress_state(mapping state)
{
  // NOTE: Variables which begin with "!_" will
  //       not be compressed in the state.

  state = copy_value(state);
  m_delete(state,"_state");
  m_delete(state,"next_page");
  m_delete(state,"next_page.x");
  m_delete(state,"next_page.y");
  m_delete(state,"prev_page");
  m_delete(state,"prev_page.x");
  m_delete(state,"prev_page.y");
  m_delete(state,"help");
  m_delete(state,"action");
  m_delete(state,"unique");

  foreach(glob("!_*", indices(state)), string s)
    m_delete(state, s);
  
//  report_debug(sprintf("State=%O\n", state));

  string from = encode_value(state);
  object gz = Gz;
  if(sizeof(indices(gz)))
    from = gz->deflate()->deflate(from);
  return MIME.encode_base64( from );
}

string parse_wizard_help(string|Parser.HTML t, mapping m, string contents,
			 RequestID id, void|mapping v)
{
  if(v)
    v->help=1;
  else
    id->misc->wizard_help=1;
  if(!id->variables->help) return "";
  return contents;
}

string make_title()
{
  string s = (string)(this_object()->wizard_name || 
		      this_object()->name || LOCALE(51, "No name")) -
    "<p>";
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
#define LABEL(X,Y) (this_object()->X?Q(this_object()->X):Y)

string parse_wizard_page(string form, RequestID id, string wiz_name, void|string page_name)
{
  mapping(string:array) automaton = this_object()->wizard_automaton;
  int max_page = !automaton && num_pages(wiz_name)-1;
  string res;
  string page = id->variables->_page;
  int pageno = (int)page;
  mapping foo = ([]);

  // FIXME: Add support for preparse on the page-level.
  // form = parse_rxml(form, id);

  // Cannot easily be inlined below, believe me... Side-effects.
  form = parse_html(form,(id->misc->extra_wizard_tags||([]))+
		    ([ "var":wizard_tag_var, ]),
		    (id->misc->extra_wizard_container||([]))+
		    ([ "cvar":wizard_tag_var,
		       "help":parse_wizard_help]), id, foo );

  // We commonly feed the action variable both from the URL with
  // "...?action=foo.pike" and with an <input> tag from the previous
  // page. Netscape ignores one of them, but IE sends both. Thus we
  // have to discard the extra value in the IE case. (We simply assume
  // both values are the same here; maybe it could be done better.)
  if (stringp (id->variables->action))
    id->variables->action = (id->variables->action/"\0")[0];

  //  Use custom method if caller doesn't like GET or perhaps wants other
  //  attributes included.
  string method = this_object()->wizard_method || "method=\"get\"";

#ifdef USE_WIZARD_COOKIE
  // FIXME: If this is enabled there may be trouble with the state
  // getting mixed up between wizards when one wizard initiates
  // another. The state should be extended with a wizard identifier
  // then.
  string state_form = "";
  id->add_response_header("Set-Cookie",
			  sprintf("WizardState=%s; path=/",
				  compress_state(id->real_variables) - "\r\n"));
#else
  string state_form = "<input type=\"hidden\" name=\"_state\" value=\""+
		      compress_state(id->real_variables)+"\" />\n";
#endif

  string wizard_id = id->cookies["RoxenWizardId"];
  res = ("\n<!--Wizard-->\n"
         "<form " + method + ">\n"
	 "<input type=\"hidden\" name=\"_roxen_wizard_id\" value=\"" +
	 html_encode_string(wizard_id) + "\" />\n" +
	 (stringp (id->variables->action) ?
	  "<input type=\"hidden\" name=\"action\" value=\"" +
	  html_encode_string(id->variables->action) + "\" />\n" :
	  "") +
	 "<input type=\"hidden\" name=\"_page\" value=\"" +
	 html_encode_string(page) + "\" />\n"
	 +state_form+
	 "<table bgcolor=\"#000000\" cellpadding=\"1\" border=\"0\" cellspacing=\"0\" width=\"80%\">\n"
	 "  <tr><td><table bgcolor=\"#eeeeee\" cellpadding=\"0\" "
	   "cellspacing=\"0\" border=\"0\" width=\"100%\">\n"
	 "    <tr><td valign=\"top\"><table width=\"100%\" cellspacing=\"0\" cellpadding=\"5\">\n"
         "      <tr><td valign=top><font size=\"+2\">"+make_title()+"</font></td>\n"
         "<td align=\"right\">"+
	 (wiz_name=="done"
	  ?LABEL(completed_label, LOCALE(52, "Completed"))
	  :page_name || (max_page?LABEL(page_label, LOCALE(53, "Page "))+(pageno+1)+"/"+(max_page+1):""))+
	 "</td>\n"
	  " \n<td align=\"right\">"+
	 (foo->help && !id->variables->help?
	  "<font size=-1><input type=image name=help src="+
	  (id->conf?"/internal-roxen-help":"/image/help.gif")+
	  " border=\"0\" value=\"Help\"></font>":"")
	 +"</td>\n"
	 " </tr><tr><td colspan=\"3\"><table cellpadding=\"0\" cellspacing=\"0\" border=\"0\" width=\"100%\">"
           "<tr bgcolor=\"#000000\"><td><img src=\""+
	 (id->conf?"/internal-roxen-unit":"/image/unit.gif")+
	 "\" width=\"1\" height=\"1\" alt=\"\" /></td></tr></table></td></tr>\n"
	 "  </table><table cellpadding=\"6\"><tr><td>\n"
	 "<!-- The output from the page function -->\n"
	 +form+
	 "\n<!-- End of the output from the page function -->\n"
	 "\n</td></tr></table>\n"
	 "      <table width=\"100%\"><tr><td width=\"33%\">"+
	 (((automaton ? stringp (id->variables->_prev) : pageno>0) &&
	   wiz_name!="done")?
	  "\n        <input type=submit name=prev_page value=\""+
	  LABEL(previous_label, LOCALE(54, "&lt;- Previous"))+"\" />":"")+

	 "</td><td width=\"33%\" align=\"center\">"+
	 (wiz_name!="done"
	  ?(((automaton ? !id->variables->_next : pageno==max_page)
	     ?"\n&nbsp;&nbsp;<input type=\"submit\" name=\"ok\" value=\" "+
	     LABEL(ok_label, LOCALE(55, "OK"))+" \" />&nbsp;&nbsp;"
	     :"")+
	    "\n&nbsp;&nbsp;<input type=\"submit\" name=\"cancel\" value=\" "+
	    LABEL(cancel_label, LOCALE(56, "Cancel"))+" \" />&nbsp;&nbsp;")
	  :"\n         <input type=\"submit\" name=\"cancel\" value=\" "+
	  LABEL(ok_label, LOCALE(55, "OK"))+" \" />")+
	 "</td><td width=\"33%\" align=\"right\">"+
	 (((automaton ? stringp (id->variables->_next) : pageno!=max_page) &&
	   wiz_name!="done")?
	  "\n        <input type=\"submit\" name=\"next_page\" value=\""+
	  LABEL(next_label, LOCALE(57, "Next -&gt;"))+"\" />":"")+
	 "</td></tr></table>\n"
	 "    </td></tr>\n"
	 "  </table>\n"
	 "  </td></tr>\n"
         "</table>\n"
         "</form>\n"
	  );
  return res;
}


mapping|string wizard_cancel_exit (mapping state, string default_return_url,
				   RequestID id)
{
  return http_redirect ((state->cancel_url && state->cancel_url[0]) ||
			default_return_url || id->not_query,
			// id->conf check is probably just old crud.
			id->conf && id);
}

mapping|string wizard_done_exit (mapping state, string default_return_url,
				 RequestID id)
{
  return http_redirect ((state->done_url && state->done_url[0]) ||
			default_return_url || id->not_query,
			// id->conf check is probably just old crud.
			id->conf && id);
}

#define PAGE(X)  ((string)(((int)v->_page)+(X)))

mapping(string:array) wizard_get_state (RequestID id)
//! Decodes the wizard state and incorporates it into
//! id->real_variables, letting existing variables override those from
//! the wizard state. Returns the wizard state without overrides.
{
  mapping(string:array) s = id->misc->wizard_state;
  if (s) return s;

  string state_str;
#ifdef USE_WIZARD_COOKIE
  state_str = id->real_variables->_page && id->cookies->WizardState;
#else
  state_str = id->real_variables->_state && id->real_variables->_state[0];
#endif
  if (state_str)
    s = decompress_state(state_str);
  else {
    s = ([]);
    if (this->return_to_referrer && !id->real_variables->_wiz_ret &&
	id->referer && sizeof (id->referer)) {
      // Define return_to_referrer to use the Referer to go back to
      // the previous place after the wizard is done. This currently
      // doesn't use a stack, so if we're coming here from another
      // wizard return then we ignore the referrer so that the
      // ordinary "cancel" url is used instead.
      //
      // Note that this only works with the assumption that the
      // referring wizard (or other page) doesn't retain the _wiz_ret
      // variable in later links.
      string referrer = id->referer[0];
      if (!has_value (referrer, "&_wiz_ret=") &&
	  !has_value (referrer, "?_wiz_ret=")) {
	if (has_value (referrer, "?")) referrer += "&_wiz_ret=";
	else referrer += "?_wiz_ret=";
      }
      s->cancel_url = s->done_url = ({referrer});
    }
  }

  mapping(string:array) vars = id->real_variables;
  foreach(s; string q; array var)
    if (!vars[q])
      vars[q] = var;

  return id->misc->wizard_state = s;
}

protected void reset_buttons(FakedVariables v)
{
  m_delete (v, "next_page");
  m_delete (v, "next_page.x");
  m_delete (v, "next_page.y");
  m_delete (v, "prev_page");
  m_delete (v, "prev_page.x");
  m_delete (v, "prev_page.y");
  m_delete (v, "ok");
  m_delete (v, "ok.x");
  m_delete (v, "ok.y");
}

mapping|string wizard_for(RequestID id,string cancel,mixed ... args)
{
  string data;
  int offset = 1;
  string wiz_name = "page_";

  mapping(string:array) s = wizard_get_state (id);

  if(id->real_variables->cancel || id->real_variables["cancel.x"])
    return wizard_cancel_exit (s, cancel, id);

  //  Handle double posting of variables in select override widgets
  foreach(Array.uniq(id->real_variables->__select_override_vars || ({ }) ),
	  string override_combo) {
    [string override_var, string override_marker] = override_combo / ":";
    array(string) override_info = id->real_variables[override_var];
    if (sizeof(override_info) > 1) {
      string override_value = override_info[0];
      if (override_value != override_info[1]) {
	if (override_value == override_marker) {
	  override_value = override_info[1];
#if 0
	} else if (override_info[1] == override_marker) {
	  /* Already ok. */
	} else {
	  /* Ambiguous case. Warn? */
#endif /* 0 */
	}
      }
      id->real_variables[override_var] = ({ override_value });
    }
  }

  FakedVariables v=id->variables;

  int current_page = (int) v->_page;

  string wizard_id = id->cookies["RoxenWizardId"];
  if (!sizeof(wizard_id || "")) {
    wizard_id = (string)random(0x7fffffff);
    id->add_response_header("Set-Cookie",
			    sprintf("RoxenWizardId=%s; path=/", wizard_id));
    id->cookies["RoxenWizardId"] = wizard_id;
    DEBUGMSG(sprintf("Wizard: Generated new wizard_id: %s\n", wizard_id));
  }
  if (wizard_id != id->variables["_roxen_wizard_id"]) {
    // Invalid or unset roxen_wizard_id.
    if (current_page) {
      report_warning("Wizard: Invalid wizard_id: %O != %O.\n"
		     "Resetting page from %O to 0.\n",
		     v["_roxen_wizard_id"], wizard_id,
		     current_page);
    }
    // Correct it, and return to page #0.
    id->real_variables["_roxen_wizard_id"] = ({ wizard_id });
    current_page = 0;
    m_delete(id->real_variables, "_page");
    m_delete(v, "_page");
    // Also reset some typical action buttons as a preventive measure.
    reset_buttons(v);
    // FIXME: Do we need to reset any other variables?
  }

  mapping(string:array) automaton = this_object()->wizard_automaton;
  function dispatcher;
  string oldpage, page_name;
  if (automaton && (!v->_page || v->next_page || v["next_page.x"] ||
		    v->prev_page || v["prev_page.x"] ||
		    v->ok || v["ok.x"])) {
    if (!v->_page && automaton->start) v->_page = "start";
    oldpage = v->_page;
    if (v->_page) {
      array page_state = automaton[v->_page];
      if (!page_state) return "Internal error in wizard code: "
			 "No entry " + v->_page + " in automaton.";
      function|string redirect = page_state[0];
      if (functionp (redirect)) {
	dispatcher = redirect;
	DEBUGMSG (sprintf ("Wizard: Running dispatch function %O for page %s\n",
			   redirect, v->_page));
	redirect = redirect (id, v->_page, @args);
      }
      if (stringp (redirect) && redirect != v->_page) {
	DEBUGMSG ("Wizard: Internal redirect to page " + redirect + "\n");
	// Redirect takes precedence over the user choice.
	reset_buttons(v);
	v->_page = redirect;
      }
    }
  }

  if(v->next_page || v["next_page.x"])
  {
    function c=this_object()["verify_"+v->_page];
    int fail = 0;
    if (functionp (c)) {
      fail = c (id, @args);
      DEBUGMSG (sprintf ("Wizard: Verify function %O %s\n", c,
			 fail ? "failed" : "succeeded"));
    }
    if (!fail) {
      v->_page = automaton ? v->_next : PAGE(1);
      DEBUGMSG ("Wizard: Going to next page\n");
    }
  }
  else if(v->prev_page || v["prev_page.x"])
  {
    v->_page = automaton ? v->_prev : PAGE(-1);
    DEBUGMSG ("Wizard: Going to previous page\n");
    offset=-1;
  }
  else if(v->ok || v["ok.x"])
  {
    function c=this_object()["verify_"+v->_page];
    int fail = 0;
    if (functionp (c)) {
      fail = c (id, @args);
      DEBUGMSG (sprintf ("Wizard: Verify function %O %s\n", c,
			 fail ? "failed" : "succeeded"));
    }
    if(!fail)
      if (automaton) v->_page = 0; // Handle done state in the automaton code below.
      else
      {
	mixed res;
	if(c=this_object()->wizard_done) {
	  DEBUGMSG ("Wizard: \"Ok\" pressed; running wizard_done\n");
	  res = c(id,@args);
	}
	if(res != -1)
	  return res || wizard_done_exit (s, cancel, id);
	DEBUGMSG ("Wizard: -1 from wizard_done; continuing\n");
      }
  }
  else if(v["help.x"])
  {
    m_delete(v, "help.x");
    m_delete(v, "help.y");
    v->help="1";
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

  if (automaton) {
    int i = 0;
    while (1) {
      if (++i == 4711) return "Internal error in wizard code: "
			 "Probably infinite redirect loop in automaton.";

      if (v->_page == "cancel") {
	DEBUGMSG ("Wizard: Canceling\n");
	return wizard_cancel_exit (s, cancel, id);
      }

      if (!v->_page) v->_page = "done", oldpage = 0;
      function|string redirect = 0;
      array page_state = automaton[v->_page];
      if (!page_state && v->_page != "done")
	return "Internal error in wizard code: No entry " + v->_page + " in automaton.";

      if (page_state && v->_page != oldpage) {
	redirect = page_state[0];
	if (functionp (redirect)) {
	  dispatcher = redirect;
	  DEBUGMSG (sprintf ("Wizard: Running dispatch function %O for page %s\n",
			     dispatcher, v->_page));
	  redirect = dispatcher (id, v->_page, @args);
	}
	else dispatcher = 0;
      }
      oldpage = 0;

      if (redirect && redirect != v->_page) {
	DEBUGMSG ("Wizard: Internal redirect to page " + redirect + "\n");
	v->_page = redirect;
      }
      else if (v->_page == "done") {
	function donefn = this_object()->wizard_done;
	if (!functionp (donefn))
	  return "Internal error in wizard code: No wizard_done function.";
	DEBUGMSG ("Wizard: Running wizard_done\n");
	data = donefn (id, @args);
	if (!data) return wizard_done_exit (s, cancel, id);
	wiz_name = "done";
	break;
      }
      else {
	function pagefn = this_object()[wiz_name + v->_page];
	if (!functionp (pagefn)) return "Internal error in wizard code: "
				   "No page function for " + v->_page + ".";
	DEBUGMSG (sprintf ("Wizard: Running page function %O\n", pagefn));
	data = pagefn (id, @args);
	if (data) {
	  id->variables->_prev = functionp (page_state[1]) ?
	    page_state[1] (id, v->_page, @args) : page_state[1];
	  id->variables->_next = functionp (page_state[2]) ?
	    page_state[2] (id, v->_page, @args) : page_state[2];

	  // So that dispatch functions may be used for prev/next too.
	  if ((<"cancel", "done">)[id->variables->_prev]) id->variables->_prev = 0;
	  if ((<"cancel", "done">)[id->variables->_next]) id->variables->_next = 0;

	  page_name = sizeof (page_state) < 4 ? "" : functionp (page_state[3]) ?
	    page_state[3] (id, v->_page, @args) : page_state[3];
	  DEBUGMSG ("Wizard: prev_page " + id->variables->_prev + ", next_page " +
		    id->variables->_next + ", page_name \"" + page_name + "\"\n");
	  break;
	}
	else {
	  int dir = offset > 0 ? 2 : 1;
	  v->_page =
	    functionp (page_state[dir]) ?
	    page_state[dir] (id, v->_page, @args) : page_state[dir];
	  DEBUGMSG ("Wizard: No data from page function; going to " +
		    (stringp (v->_page) ? (offset > 0 ? "next" : "previous") +
		     " page " + v->_page : "done page") + "\n");
	  if (!stringp (v->_page)) v->_page = 0;
	}
      }
    }
  }
  else {
    for(; !data; v->_page=PAGE(offset))
    {
      function pg=this_object()[wiz_name+((int)v->_page)];
      function c = !pg && this_object()["wizard_done"];
      if(functionp(c)) {
	DEBUGMSG ("Wizard: Running wizard_done\n");
	mixed res = c(id,@args);
	if(res != -1)
	  return res || wizard_done_exit (s, cancel, id);
      }
      if(!pg) return "Internal error in wizard code: Invalid page ("+v->_page+")!";
      DEBUGMSG (sprintf ("Wizard: Running page function %O\n", pg));
      if(data = pg(id,@args)) break;
      DEBUGMSG ("Wizard: No data from page function; going to " +
		(offset > 0 ? "next" : "previous") + " page\n");

      //  If going backwards and we end up on a negative page (e.g. due to
      //  intermediate pages returning 0) we remain on current page. This is
      //  done so that wizards which skip pages in the beginning won't result
      //  in wizard_done() when trying to step into hidden pages.
      if ((offset < 0) && ((int) v->_page <= 0)) {
	v->_page = current_page;
	pg = this_object()[wiz_name + ((int) v->_page)];
	if (pg && (data = pg(id, @args)))
	  break;
      }
    }
  }

  // If it's a mapping we can presume it is an http response, and return
  // it directly.
  if (mappingp(data))
    return data;

  return parse_wizard_page(data,id,wiz_name,page_name);
}

mapping wizards = ([]);
string err;
object get_wizard(string act, string dir, mixed ... args)
{
  act-="/";
  object w = wizards[dir+act];
  if(!w) w = wizards[dir+act] = compile_file(dir+act)(@args);
  return w;
}

int zonk=time(1);
mapping get_actions(RequestID id, string base,string dir, array args)
{
  mapping acts = ([  ]);
  
  //  Cannot clear wizard cache since it will trigger massive recompiles of
  //  wizards from inside SiteBuilder. It also breaks wizards which use
  //  persistent storage.
  //
  //  if(id->pragma["no-cache"]) wizards=([]);
  
  foreach(get_dir(dir) - ({ ".distignore" }), string act)
  {
    mixed err;
    object e;
    master()->set_inhibit_compile_errors(e = ErrorContainer());
    err = catch
    {
      if(!(<'#', '_'>)[act[0]] && act[-1]=='e')
      {
	string sm,rn = (get_wizard(act,dir,@args)->name||act), name;
	if(sscanf(rn, "%*s:%s", name) != 2) name = rn;
	sscanf(name, "%s//%s", sm, name);
	if(!acts[sm]) acts[sm] = ({ });

	if(id->misc->raw_wizard_actions)
	{
	  // This is probably dead code.
	  if(!sizeof(acts[sm])) acts[sm] += ({ ([]) });
 	  acts[sm][0][name]=
 	    ({ name, base, (["action":act,"unique":(string)(zonk++) ]),
 		  (get_wizard(act,dir,@args)->doc||"") });
	}
 	else
	  acts[sm]+=
	    ({"<!-- "+rn+" --><dt><font size=\"+2\">"
	      "<a href=\""+base+"?action="+act+"&unique="+(zonk++)+"\">"+
	      name+"</a></font><dd>"+(get_wizard(act,dir,@args)->doc||"")});
      }
    };
    if( strlen( e->get_warnings() ) )
      report_warning( e->get_warnings() );
    if(strlen(e->get()))
      error("While compiling wizards:\n"+e->get());
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
      (s==sel?"<li>":"<font color=\"#eeeeee\"><li></font><a href=\""+base+"?sm="+replace(s||"Misc"," ","%20")+
       "&uniq="+(++zonk)+"\">")+(s||"Misc")+
      (s==sel?"<br />":"</a><br />")+"";
  return res + "</font>";
}

string focused_wizard_menu;
mixed wizard_menu(RequestID id, string dir, string base, mixed ... args)
{
  mapping acts;

  //  Cannot clear wizard cache since it will trigger massive recompiles of
  //  wizards from inside SiteBuilder. It also breaks wizards which use
  //  persistent storage.
  //
  //  if(id->pragma["no-cache"]) wizards=([]);
  
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
      string submenus =
	act_describe_submenues(indices(acts),base,id->variables->sm);
      if (sizeof(submenus)) {
	submenus =
	  "<td valign='top' bgcolor='#eeeeee'>" +
	  submenus +
	  "</td>\n";
      }
      res= ("<table cellpadding=\"3\"><tr>" +
	    submenus +
	    "<td valign=\"top\">"+
	    (sizeof(acts)>1 && acts[id->variables->sm]?"<font size=\"+3\">"+
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
    // We commonly feed the action variable both from the URL with
    // "...?action=foo.pike" and with an <input> tag from the previous
    // page. Netscape ignores one of them, but IE sends both. Thus we
    // have to discard the extra value in the IE case. (We simply assume
    // both values are the same here; maybe it could be done better.)
    id->variables->action = (id->variables->action/"\0")[0];

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
  s = reverse(as[0]);
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
   *   bordercolor, titlebgcolor, titlecolor, oddbgcolor, evenbgcolor, modulo
   * Containers:
   *   <fields>[num|text, ...]</fields>
   */

  if(!opt) opt = ([]);

  // RXML <2.0 compatibility stuff
  if(opt->fgcolor0) {
    opt->oddbgcolor=opt->fgcolor0;
    m_delete(opt, "fgcolor0");
  }
  if(opt->fgcolor1) {
    opt->evenbgcolor=opt->fgcolor1;
    m_delete(opt, "fgcolor1");
  }
  if(opt->bgcolor) {
    opt->bordercolor=opt->bgcolor;
    m_delete(opt, "bgcolor");
  }

  string r = "";

  int m = (int)(opt->modulo?opt->modulo:1);
  r += ("<table bgcolor=\""+(opt->bordercolor||"#000000")+"\" border=\"0\" "
	"cellspacing=\"0\" cellpadding=\"1\">\n"
	"<tr><td>\n");
  r += "<table border=\"0\" cellspacing=\"0\" cellpadding=\"4\">\n";
  r += "<tr bgcolor=\""+(opt->titlebgcolor||"#113377")+"\">\n";
  int cols;
  foreach(subtitles, mixed s)
  {
    if(stringp(s))
    {
      r+=("<th nowrap=\"nowrap\" align=\"left\"><font color=\""+
	  (opt->titlecolor||"#ffffff")+"\">"+s+" &nbsp; </font></th>");
      cols++;
    } else {
      r+=("</tr><tr bgcolor=\""+(opt->titlebgcolor||"#113377")+"\">"
	  "<th nowrap=\"nowrap\" align=\"left\" colspan=\""+cols+"\">"
	  "<font color=\""+(opt->titlecolor||"#ffffff")+"\">"+s[0]+
	  " &nbsp; </font></th>");
    }
  }
  r += "</tr>";

  for(int i = 0; i < sizeof(table); i++) {
    string tr;
    r += tr = "<tr bgcolor="+((i/m)%2?opt->evenbgcolor||"#ddeeff":
			      opt->oddbgcolor||"#ffffff")+">";
    for(int j = 0; j < sizeof(table[i]); j++) {
      mixed s = table[i][j];
      if(arrayp(s))
	r += "</tr>"+tr+"<td colspan=\""+cols+"\">"+s[0]+" &nbsp;</td>";
      else {
	string type = "text";
	if(arrayp(opt->fields) && j < sizeof(opt->fields))
	  type = opt->fields[j];
	switch(type) {
	case "num":
	  array a = s/".";
	  r += "<td nowrap=\"nowrap\" align=\"right\">";
	  if(sizeof(a) > 1) {
	    r += (format_numeric(a[0])+"."+
		  reverse(format_numeric(reverse(a[1]), ";psbn&")));
	  } else
	    r += format_numeric(s, "&nbsp;");
	  break;
	case "right":
	  r += "<td align=\"right\">"+s;
	  break;
	case "center":
	  r += "<td align=\"center\">"+s;
	  break;
	case "left":
	  r += "<td align=\"left\">"+s;
	  break;
	case "text":
	default:
	  r += "<td nowrap=\"nowrap\">"+s;
	}
	//  Simple heuristics to detect cells containing a table, image etc
	//  where trailing spaces will give really ugly results
	if (!(stringp(s)
	      && (strlen(s) > 2)
	      && (< "<img ", "<tabl", "<gtex", "<var ",
		    "<pre>", "<sb-i" >)[s[0..4]]
	      && (s[-1] == '>' || s[-2] == '>'))) {
	  r += "&nbsp;&nbsp;";
	}
	r += "</td>";
      }
    }
    r += "</tr>\n";
  }
  r += "</table></td></tr>\n";
  r += "</table>" /* +(opt->noxml?"<br>":"<br />")+ */ "\n";
  return r;
}


string html_notice(string notice, RequestID id)
{
  return ("<table><tr><td valign=\"top\"><img \nalt=\"Notice:\" src=\""+
        (id->conf?"/internal-roxen-":"/image/")
        +"err_1.gif\" />&nbsp;&nbsp;</td><td valign=\"top\">"+notice+"</td></tr></table>");
}

string html_warning(string notice, RequestID id)
{
  return ("<table><tr><td valign=\"top\"><img \nalt=\"Warning:\" src=\""+
        (id->conf?"/internal-roxen-":"/image/")
        +"err_2.gif\" />&nbsp;&nbsp;</td><td valign=\"top\">"+notice+"</td></tr></table>");
}

string html_error(string notice, RequestID id)
{
  return ("<table><tr><td valign=\"top\"><img \nalt=\"Error:\" src=\""+
        (id->conf?"/internal-roxen-":"/image/")
        +"err_3.gif\" />&nbsp;&nbsp;</td><td valign=\"top\">"+notice+"</td></tr></table>");
}

string html_border(string what, int|void width, int|void ww,
		   string|void bgcolor, string|void bdcolor)
{
  return ("<table border=\"0\" cellpadding=\""+(width+1)+"\" cellspacing=\"0\" "
	  "bgcolor=\""+(bdcolor||"#000000")+
	  "\"><tr><td><table border=\"0\" cellpadding=\""+(ww)+
	  "\" cellspacing=\"0\" bgcolor=\""+(bgcolor||"#ffffff")+
	  "\"><tr><td>"+what+"</tr></td></table>"
          "</td></tr></table>");
}

void filter_checkbox_variables(mapping v)
{
  foreach(indices(v), string s) {
    if(!v[s] || (v[s]=="0"))
      m_delete(v,s);
    else
      v[s]-="\00";
  }
}
