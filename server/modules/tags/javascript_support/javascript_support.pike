// This is a roxen module. Copyright © 1996 - 1999, Idonex AB.

constant cvs_version = "$Id: javascript_support.pike,v 1.1 1999/11/11 16:37:09 wellhard Exp $";
//constant thread_safe=1;

#include <module.h>
inherit "module";
inherit "roxenlib";

#define INT_TAG "_js_quote"

array register_module()
{
  return ({ 
    MODULE_PARSER|MODULE_FILTER,
    "Javascript", 
    "This module provides some tags to support JavaScript development.",
    0, 1, });
}

//return query_internal_location();

mapping find_internal(string f, object id)
{
  string file = combine_path(__FILE__, "../scripts", (f-".."));
  return ([ "data":Stdio.read_bytes(file),
	    "type":"application/x-javascript" ]);
}

string internal_container_js_quote(string name, mapping args, string contents)
{
  string r = "var r = \"\";\n";
  r += Array.map(replace(contents, ({"\""}), ({ "\\\"" }) )/"\n", 
		 lambda(string row) {return "r += \""+row;})*"\\n\";\n";
  r += "\";\ndocument.write(r);\n";
  return r;
}

string internal_container_script(string name, mapping args, string contents,
				 mapping xargs)
{
  if(upper_case(args->language||"") == upper_case(xargs->language||""))
    return "</"INT_TAG">"+contents+"<"INT_TAG">";
  else
    return make_container(name, args, contents);
}

string container_js_write(string name, mapping args, string contents,
			  object id)
{
  contents =
    parse_html(contents, ([]), (["script":internal_container_script]), args);
  contents = parse_html("<"INT_TAG">"+contents+"</"INT_TAG">",
		       ([]), ([INT_TAG:internal_container_js_quote]), args);
  
  return ("<noparse><script language='javascript'><!--\n"
	  // "var gt = String.fromCharCode(62);\n"
	  // "var lt = String.fromCharCode(60);\n"
	  // "var ha = String.fromCharCode(35);\n"
	  +contents+
	  "//--></script></noparse>\n");
}

string make_container_unquoted(string name, mapping args, string contents)
{
  array ind = indices(args);
  array val = values(args);
  array a = ({});
  for(int i; i < sizeof(ind); i++)
    a += ({ ind[i]+"="+"\""+val[i]+"\"" });
  return "<"+name+" " + (a*" ") + ">" + contents + "</"+name+">";
}

string get_unique_id(string name, object id)
{
  string key = "_js_"+name;
  id->misc[key]++;
  return name+sprintf("%02x", id->misc[key]);
}

void add_to_insert(string name, string content, object id)
{
  if(!id->misc->javascript)
    id->misc->javascript = ([]);
  
  if(!id->misc->javascript[name])
    id->misc->javascript[name] = "";
  
  id->misc->javascript[name] += content;
}

string container_js_popup(string name, mapping args,
			  string contents, object id)
{
  //werror("Enter");
  mapping largs = copy_value(args);
  if(largs->label) m_delete(largs, "label");
  if(largs->ox) m_delete(largs, "ox");
  if(largs->oy) m_delete(largs, "oy");
  if(!largs->href) largs->href = "javascript:void";

  //if(args["empty-variable"]) {
  //  werror("%O\n", id->variables[args["empty-variable"]]);
  //  werror("[%O]\n", ((contents - " ") - "\n"));
  //  if(id->variables[args["empty-variable"]] == ((contents - " ") - "\n")) {
  //	m_delete(largs, "empty-variable");
  //	werror(" leaving (leaf).\n");
  //	return make_container("a", largs, args->label) + "\n";
  //  }
  //  m_delete(largs, "empty-variable");
  //}
  //
  //if(largs["add-popup-title"]) {
  //  largs->title += largs["add-popup-title"];
  //  m_delete(largs, "add-popup-title");
  //}
  string popupname = get_unique_id("popup", id);
  string popupparent =
    (id->misc->_popupparent?id->misc->_popupparent:"none");
  
  string showpopup = "return showPopup('"+popupname+
		     "', '"+popupparent+"', "+args->ox+", "+args->oy;
  largs->onMouseOver = "if(isNav4) { "+showpopup+", event); } "
		       "else { "+showpopup+"); }";
  
  add_to_insert("javascript1.2", 
		"if(isNav4) document."+popupname+
		".onMouseOut = hidePopup;\n", id);
  add_to_insert("style", "<style>#"+popupname+" {position:absolute; "
		"left:0; top:0; visibility:hidden; width:1; z-index:"+
		id->misc->_popuplevel+"}</style>\n", id);
  string old_pparent = id->misc->_popupparent;
  id->misc->_popupparent = popupname;
  id->misc->_popuplevel++;
  add_to_insert("div", "<div id='"+popupname+"' "
		"onMouseOut='hidePopup(\""+popupname+"\");'>\n"+
		parse_rxml(contents, id)+"</div>\n", id);
  id->misc->_popupparent = old_pparent;
  id->misc->_popuplevel--;
  //werror(" leaving.\n");
  return make_container_unquoted("a", largs, args->label) + "\n";
}

string internal_container_js_dragdrop_icon(string name, mapping args,
					   string contents, object id,
					   mapping xargs)
{
  return "<js-write><style>#icon"+xargs->name+args->name+
    " {position:absolute; "
    "left:0; top:0; visibility:hidden}</style>\n"
    "<div id='icon"+xargs->name+args->name+"'>"+contents+"</div></js-write>";
}

string internal_container_js_dragdrop_drag(string name, mapping args,
					   string contents, object id,
					   mapping xargs)
{
  if(!args->href) args->href = "javascript:void";
  args->onMouseDown =
    "if(isNav4) { return dragDown('"+args->name+"', '"+
    xargs->name+args->icon+"', event); } "
    "else { return dragDown('"+args->name+"', '"+
    xargs->name+args->icon+"'); }";
  
  args->onMouseUp ="return dragUp('"+args->name+"', '"+xargs->ondrop+"');";
     
  m_delete(args, "ondrop");
  m_delete(args, "icon");
  m_delete(args, "name");
  return make_container_unquoted("a", args, contents);
}

string container_js_dragdrop(string name, mapping args, string contents,
			     object id)
{
  return parse_html(contents, ([]),
		    ([ "js-dragdrop-drag":internal_container_js_dragdrop_drag,
		       "js-dragdrop-icon":internal_container_js_dragdrop_icon
		    ]), id, args);
}

string tag_js_include(string name, mapping args, object id)
{
  if(!id->supports["javascript1.2"])
    return "<!-- Client do not support Javascript 1.2 -->";;
  return ("<script language=\"javascript\" src=\""+
	  query_internal_location()+args->file+"\"></script>");
}

string tag_js_dragdrop_body(string name, mapping args, object id)
{
  args->onMouseMove="dragMove();";
  args->onMouseUp="dragCancel();";
  return make_tag("body", args);
}

mixed int_container_head(string name, mapping args, string contents,
			  object id)
{
  return ({ make_container(name, args, contents+
			   "\n<script language='javascript1.2'><!--\n"+
			   id->misc->javascript+"//--></script>") });
}

mixed int_tag_js_insert(string name, mapping args, object id, mapping m)
{
  m->done = 1;
  if(!id->misc->javascript || !id->misc->javascript[args->name])
    return "";
  if(args->name == "javascript1.2")
    return ({ "<script language='javascript1.2'><!--\n"+
	      id->misc->javascript[args->name]+"//--></script>" });
  else return id->misc->javascript[args->name];
}

mixed filter( mapping response, object id)
{
  if(!response || !response->type) return response;
  
  string type = ((response->type - " ")/";")[0];
  if(id->misc->javascript && type == "text/html"){
    mapping m = ([]);
    response->data = parse_html(response->data,
				([ "js-insert":int_tag_js_insert ]),
				([]), id, m);
    if(!m->done)
      response->data = parse_html(response->data, ([]),
				  ([ "head": int_container_head ]), id);
    return response;
  }
}

mapping query_container_callers()
{
  return ([ "js-write"    : container_js_write,
	    "js-popup"    : container_js_popup,
	    "js-dragdrop" : container_js_dragdrop ]);
}

mapping query_tag_callers()
{
  return ([ "js-include"       : tag_js_include,
            "js-dragdrop-body" : tag_js_dragdrop_body ]);
}

