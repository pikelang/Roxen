// This is a roxen module. Copyright © 1999 - 2000, Roxen IS.

constant cvs_version = "$Id: javascript_support.pike,v 1.20 2000/03/24 21:45:36 wellhard Exp $";
//constant thread_safe=1;

#include <module.h>
inherit "module";
inherit "roxenlib";

#define INT_TAG "_js_quote"

constant module_type = MODULE_PARSER|MODULE_FILTER|MODULE_PROVIDER;
constant module_name = "Javascript Support";
constant module_doc  = "This module provides some tags to support javascript development "
  "(i.e. Javascript popup menus).";

string|array(string) query_provides()
{
  return "javascript_support";
}

mapping find_internal(string f, object id)
{
  string file = combine_path(__FILE__, "../scripts", (f-".."));
  return ([ "data":Stdio.read_bytes(file),
	    "type":"application/x-javascript" ]);
}

class JSInsert
{
  static private string name;
  static private mapping(string:string) args;
  static private string content;

  void add(string s)
  {
    content += s;
  }

  string get()
  {
    return content;
  }
  
  string _sprintf(int i, mapping(string:int)|void m)
  {
    return sprintf("JSInsert: %s, %O", name, args);
  }

  void create(string _name, mapping(string:string) _args)
  {
    name = _name;
    args = _args;
    content = "";
  }
}

class JSSupport
{
  static private mapping(string:JSInsert) inserts;
  static private mapping(string:int) keys;

  string get_unique_id(string name)
  {
    return name+sprintf("%02x", keys[name]++); 
  }
  
  void create_insert(string name, string tag_name,
		     mapping(string:string) args)
  {
    inserts[name] = JSInsert(tag_name, args);
  }

  JSInsert get_insert(string name)
  {
    if(!inserts[name])
      create_insert(name, 0, 0);
    
    return inserts[name];
  }
  
  string _sprintf(int i, mapping(string:int)|void m)
  {
    return sprintf("JSSupport: %d, %O", filter, inserts);
  }

  void create()
  {
    inserts = ([ ]);
    keys = ([ ]);
  }
}

static private
string internal_container_js_quote(string name, mapping args, string contents)
{
  string r = "var r = \"\";\n";
  r += Array.map(replace(contents, ({"\""}), ({ "\\\"" }) )/"\n", 
		 lambda(string row) {return "r += \""+row;})*"\\n\";\n";
  r += "\";\ndocument.write(r);\n";
  return r;
}

static private
string internal_container_script(string name, mapping args, string contents,
				 mapping xargs)
{
  if(upper_case(args->language||"") == upper_case(xargs->language||""))
    return "</"INT_TAG">"+contents+"<"INT_TAG">";
  else
    return make_container(name, args, contents);
}

static private
string container_js_write(string name, mapping args, string contents,
			  object id)
{
  contents =
    parse_html(contents, ([]), (["script":internal_container_script]), args);
  contents = parse_html("<"INT_TAG">"+contents+"</"INT_TAG">",
			([]), ([INT_TAG:internal_container_js_quote]), args);
  return ((name!="js-post-write"?"<noparse>":"")+
	  "<script language='javascript'><!--\n"
	  // "var gt = String.fromCharCode(62);\n"
	  // "var lt = String.fromCharCode(60);\n"
	  // "var ha = String.fromCharCode(35);\n"
	  +contents+
	  "//--></script>"+(name!="js-post-write"?"</noparse>":""));
}

static private
string make_args_unquoted(mapping args)
{
  return map(indices(args),
	     lambda(string key)
	     { return key+"="+"\""+args[key]+"\""; })*" ";
}

static private
string make_container_unquoted(string name, mapping args, string contents)
{
  return "<"+name+" " + make_args_unquoted(args) + ">"+contents+"</"+name+">";
}

int jssp(object id)
{
  return !!id->misc->javascript_support;
}

JSSupport get_jss(object id)
{
  if(!id->misc->javascript_support)
    id->misc->javascript_support = JSSupport();
  return id->misc->javascript_support;
}

static private string container_js_link(string name, mapping args,
					string contents, object id)
{
  args->onMouseOver = "clearToPopup('"+(id->misc->_popupparent||"none")+"')";
  return make_container_unquoted("a", args, contents);
}

static private string int_cont_js_popup_label(string name, mapping args,
					      string contents, mapping m)
{
  if(m->label)
    return 0;
  
  m->label = contents;
  return "";
}

static private string container_js_popup(string name, mapping args,
					 string contents, object id)
{
  //werror("Enter");
  if(!args->label) {
    mapping m = ([ ]);
    contents = parse_html(contents, ([ ]),
			  ([ "js-popup-label":int_cont_js_popup_label ]), m);
    if(m->label)
      args->label = m->label;
  }
  
  mapping largs = copy_value(args);
  if(largs["args-variable"]) m_delete(largs, "args-variable");
  if(largs->label) m_delete(largs, "label");
  if(largs->ox) m_delete(largs, "ox");
  if(largs->oy) m_delete(largs, "oy");
  if(largs->od) m_delete(largs, "od");
  if(!largs->href) largs->href = "javascript:void(0);";
  if(largs->event) m_delete(largs, "event");

  string popupname = get_jss(id)->get_unique_id("popup");
  string popupparent =
    (id->misc->_popupparent?id->misc->_popupparent:"none");
  if(zero_type(id->misc->_popuplevel) && args["z-index"])
    id->misc->_popuplevel = (int)args["z-index"];

  string event = "onMouseOver";
  if(lower_case(args->event||"") == "onclick")
    event = "onClick";
  
  largs[event] = "return showPopup('"+popupname+
		 "', '"+popupparent+"', "+args->ox+", "+args->oy+", "+args->od;
  
  if(id->supports->js_global_event)
    largs[event] += ", event";
  largs[event] += ");";
  
  get_jss(id)->get_insert("javascript1.2")->
    add("if(isNav4) document."+popupname+
	".onMouseOut = hidePopup;\n");
  
  get_jss(id)->get_insert("style")->
    add("#"+popupname+" {position:absolute; "
	"left:0; top:0; visibility:hidden; width:1; z-index:"+
	(id->misc->_popuplevel+1)+"}\n");
  
  string old_pparent = id->misc->_popupparent;
  id->misc->_popupparent = popupname;
  id->misc->_popuplevel++;
  
  get_jss(id)->get_insert("div")->
    add("<div id='"+popupname+"' "
	"onMouseOut='hidePopup(\""+popupname+"\");'>\n"+
	parse_rxml(contents, id)+"</div>\n");
  
  id->misc->_popupparent = old_pparent;
  id->misc->_popuplevel--;
  //werror(" leaving.\n");
  
  if(args["args-variable"])
    id->variables[args["args-variable"]] = make_args_unquoted(largs);
  
  if(!args->label)
    return "";
  
  return make_container_unquoted("a", largs, args->label);
}

static private
string internal_container_js_dragdrop_icon(string name, mapping args,
					   string contents, object id,
					   mapping xargs)
{
  return "<js-write><style>#icon"+xargs->name+args->name+
    " {position:absolute; "
    "left:0; top:0; visibility:hidden}</style>\n"
    "<div id='icon"+xargs->name+args->name+"'>"+contents+"</div></js-write>";
}

static private
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

static private
string container_js_dragdrop(string name, mapping args, string contents,
			     object id)
{
  return parse_html(contents, ([]),
		    ([ "js-dragdrop-drag":internal_container_js_dragdrop_drag,
		       "js-dragdrop-icon":internal_container_js_dragdrop_icon
		    ]), id, args);
}

static private
string tag_js_include(string name, mapping args, object id)
{
  if(!id->supports["javascript1.2"] &&
     id->client_var && (float)(id->client_var->javascript) < 1.2)
    return "<!-- Client do not support Javascript 1.2 -->";;
  return ("<script language=\"javascript\" src=\""+
	  query_internal_location()+args->file+"\"></script>");
}

static private
string tag_js_dragdrop_body(string name, mapping args, object id)
{
  args->onMouseMove="dragMove();";
  args->onMouseUp="dragCancel();";
  return make_tag("body", args);
}

static private
string tag_js_insert(string name, mapping args, object id)
{
  get_jss(id); // Fire of some side effects.
  return make_tag("js-filter-insert", args);
}

static private
mixed int_tag_js_filter_insert(string name, mapping args, object id)
{
  JSInsert js_insert = get_jss(id)->get_insert(args->name);
  
  if(!js_insert)
    return "";
  
  if(args->name == "javascript1.2")
    return ({ "<script language='javascript1.2'><!--\n"+
	      js_insert->get()+"//--></script>" });
  
  if(args->jswrite)
    return container_js_write("js-post-write", ([]), js_insert->get(), id);
  
  return js_insert->get();
}

mixed filter( mapping response, object id)
{
  if(!response || !response->type || !jssp(id)) return response;
  
  string type = ((response->type - " ")/";")[0];
  if(type != "text/html")
    return response;

  response->data =
    parse_html(response->data,
	       ([ "js-filter-insert":int_tag_js_filter_insert ]), ([]), id);
  response->data = parse_html(response->data, ([]),
			      ([ "js-post-write":container_js_write ]), id);
  return response;
}

mapping query_container_callers()
{
  return ([ "js-write"       : container_js_write,
	    "js-popup"       : container_js_popup,
	    "js-dragdrop"    : container_js_dragdrop,
	    "js-link"        : container_js_link,
  ]);
}

mapping query_tag_callers()
{
  return ([ "js-include"       : tag_js_include,
	    "js-insert"        : tag_js_insert,
            "js-dragdrop-body" : tag_js_dragdrop_body ]);
}


class TagJSFilter
{
  inherit RXML.Tag;

  constant name = "js-filter";

  class Frame
  {
    inherit RXML.Frame;
    
    array do_return(RequestID id)
    {
      if(!jssp(id))
	return ({ content });

      content = 
	parse_html(content,
		   ([ "js-filter-insert":int_tag_js_filter_insert ]),
		   ([]), id);
      
      content = parse_html(content, ([]),
			   ([ "js-post-write":container_js_write ]), id);
      id->misc->javascript_support = 0;      
      return ({ content });
    }
  }
  
  void create()
  {
    result_types = ({ RXML.t_html(RXML.PXml) });
  }
}
