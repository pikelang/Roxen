// This is a roxen module. Copyright © 1999 - 2000, Roxen IS.

constant cvs_version = "$Id: javascript_support.pike,v 1.27 2001/04/20 11:56:47 jonasw Exp $";
//constant thread_safe=1;

#include <module.h>
inherit "module";
inherit "roxenlib";

#define INT_TAG "_js_quote"

constant module_type = MODULE_PARSER|MODULE_FILTER|MODULE_PROVIDER;
constant module_name = "SiteBuilder: Javascript Support";
constant module_doc  = ("This module provides some tags to support "
			"javascript development (i.e. Javascript popup menus).");


//  Mapping of known callback functions. A callback is defined as
//
//    string my_callback(string token, string path, RequestID id)
//
//  where token is the token used when registering the callback and path
//  is the remaining part of the URL. The function should return the
//  JavaScript code which gets sent to the browser.
static private mapping(string:function(string,string,object:string)) callbacks = ([ ]);

//  Mapping of serverside exludes.
static private mapping(string:string) externals;

string|array(string) query_provides()
{
  return "javascript_support";
}


mapping find_internal(string f, object id)
{
  //  On-the-fly generation using callback function
  if (sscanf(f, "__cb/%s/%s", string token, string path) == 2) {
    function cb = callbacks[token];
    return http_string_answer((cb && cb(token, path, id)) || "",
			      "application/x-javascript");
  }
  
  if (sscanf(f, "__ex/%s", string key) == 1) {
    mixed error = catch {key = MIME.decode_base64(key);};
    if(error || !externals[key])
      return 0;
    return http_string_answer(externals[key], "application/x-javascript");
  }
  
  string file = combine_path(__FILE__, "../scripts", (f-".."));
  return ([ "data":Stdio.read_bytes(file),
	    "type":"application/x-javascript" ]);
}

string get_callback_url(string token)
{
  return "__cb/" + token + "/";
}

void register_callback(string token, function(string,string,object:string) cb)
{
  callbacks[token] = cb;
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
string c_js_quote(string name, mapping args, string contents)
{
  string r = "var r = \"\";\n";
  r += Array.map(replace(contents, ({"\""}), ({ "\\\"" }) )/"\n", 
		 lambda(string row) {return "r += \""+row;})*"\\n\";\n";
  r += "\";\ndocument.write(r);\n";
  return r;
};

static private
string container_js_write(string name, mapping args, string contents, object id)
{
  string c_script(string name, mapping args, string contents, mapping xargs)
  {
    // Do not js-quote contents inside a <script>-tag with the same language-arg.
    if(upper_case(args->language||"") == upper_case(xargs->language||""))
      return "</"INT_TAG">"+contents+"<"INT_TAG">";
  };
  
  // Do not js-quote contents inside a <script>-tag with the same language-arg.
  contents = parse_html(contents, ([]), ([ "script": c_script ]), args);
  contents = parse_html("<"INT_TAG">"+contents+"</"INT_TAG">",
			([]), ([ INT_TAG: c_js_quote ]), args);
  return ("<script language='"+(args->language||"javascript")+
	  "'><!--\n"+contents+"//--></script>");
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

class TagEmitJsLink {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "js-link";
  array get_dataset(mapping m, RequestID id)
  {
    string s = "clearToPopup('"+(id->misc->_popupparent||"none")+"');";
    return ({ ([
      "close-popup":s,
      "args":"onMouseOver=\""+s+"\""
    ]) });
  }
}

static private
string container_js_popup(string name, mapping args, string contents, object id)
{
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
	"left:0; top:0; visibility:hidden; "+
	(id->supports->msie?"width:1; ":"")+
	"z-index:"+
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
  id->misc->_popupname = popupname;
  //werror(" leaving.\n");
  
  if(args["args-variable"])
    id->variables[args["args-variable"]] = make_args_unquoted(largs);
  
  if(!args->label)
    return "";
  
  return make_container_unquoted("a", largs, args->label);
}

static private
string container_js_include(string name, mapping args, string contents,
			    object id)
{
  if(!id->supports["javascript1.2"] &&
     id->client_var && (float)(id->client_var->javascript) < 1.2)
    return "<!-- Client do not support Javascript 1.2 -->";;
  return ("<script language=\"javascript\" src=\""+
	  query_internal_location()+args->file+"\"></script>");
}

static private
string container_js_insert(string name, mapping args, string contents, object id)
{
  get_jss(id); // Signal that filter is necessary.
  return make_tag("js-filter-insert", args);
}

class TagJsExternal
{
  inherit RXML.Tag;
  constant name = "js-external";
  class Frame
  {
    inherit RXML.Frame;

    array do_return(RequestID id)
    {
      string key = Crypto.md5()->update(string_to_utf8(content))->digest();
      if(!externals[key])
	externals[key] = c_js_quote("", ([]), content);
      return ({ "<script language=\"javascript\" src=\""+
		query_internal_location()+"__ex/"+
		MIME.encode_base64(key)+"\"></script>" });
    }
  }
  
  void create()
  {
    externals = ([]);
  }
}

mixed filter(mapping response, RequestID id)
{
  mixed c_filter_insert(Parser.HTML parser, mapping args, object id)
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
  };

  if(!response			// 404
  || !response->type		// no response type
  || !jssp(id)			// already filtered
  || !stringp(response->data)	// got Stdio.File object
  || !glob("text/html*",	// only touch HTML files
	   response->type))
    return 0;			// signal "didn't rewrite result"

  response->data = Parser.HTML()->add_tag("js-filter-insert", c_filter_insert)->
		   set_extra(id)->finish(response->data)->read();
  return response;
}

mapping query_container_callers()
{
  return ([ "js-popup"       : container_js_popup,
	    "js-write"       : container_js_write,
	    "js-include"     : container_js_include,
	    "js-insert"      : container_js_insert
  ]);
}
