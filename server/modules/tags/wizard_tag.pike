/* This is a Roxen Challenger(r) module. Copyright (c) Idonex 1997.
 * Released under GPL
 * made by Per Hedbor
 */

constant cvs_version = "$Id: wizard_tag.pike,v 1.3 1998/02/03 22:51:08 per Exp $";
constant thread_safe=1;
#include <module.h>
inherit "module";
inherit "wizard";

mixed *register_module()
{
  return ({MODULE_PARSER,"Wizard generator",
	   ("Generates wizards<p>\n"
	    "Syntax:<br>\n"
"<br>"
"&lt;wizard name=\"A Name\" done=\"url to go to when ok or cancel is pressed\"&gt;<br>"
"&nbsp;&nbsp;&lt;page&gt;<br>"
"&nbsp;&nbsp;&nbsp;&nbsp;A page (RXML code, with two extra tags, &lt;var&gt; and &lt;cvar&gt;, see below)<br>"
"&nbsp;&nbsp;&lt;/page&gt;<br>"
"&nbsp;&nbsp;&lt;page&gt;<br>"
"&nbsp;&nbsp;&nbsp;&nbsp;Another page...<br>"
"&nbsp;&nbsp;&lt;/page&gt;<br>"
"&lt;/wizard&gt;<br>"
"<br>"
"&lt;var <br>"
"&nbsp;&nbsp; <nobr>type=\"string|password|list|text|radio|checkbox|int|float|color|font|toggle|select|select_multiple\"</nobr><br>"
"&nbsp;&nbsp;   name=\"var_name\"<br>"
"&nbsp;&nbsp;   options=\"foo,bar,gazonk\"    -- (for select and select_multiple) --<br>"
"&nbsp;&nbsp;   default=\"default value\"<br>"
"&nbsp;&nbsp;   rows=num and cols=num       -- (for text) --<br>"
"&nbsp;&nbsp;   size=chars                  -- (for most) --&gt;<br>"
"&lt;cvar -- same as var,but the default value is the contents of the container --&gt;<br>"
"&lt;/cvar&gt;<br>"),({}),1,});
}

string internal_page(string t, mapping args, string contents, mapping f)
{
  f->pages += ({contents});
}

string tag_wizard(string t, mapping args, string contents, object id)
{
  mapping f = ([ "pages":({}) ]);
  string pike = ("inherit \"wizard\";\n"
		 "string name=\""+(args->name||"unnamed")+"\";\n");
  int p;
  parse_html(contents, ([]), (["page":internal_page]),f);
  foreach(f->pages, string d)
  {
    pike += ("string page_"+p+"(object id) {" +
	     "return \""+replace(d, ({"\"","\n","\r", "\\"}), 
				 ({"\\\"", "\\n", "\\r", "\\\\"}))+"\";}\n");
    p++;
  }
  mixed res = compile_string(pike)()->wizard_for(id,args->done);
  if(mappingp(res))
  {
    id->misc->defines[" _error"] = res->error;
    id->misc->defines[" _extra_heads"] = res->extra_heads;
    return "";
  }
  return res;
}


mapping query_container_callers()
{
  return ([ "wizard" : tag_wizard ]);
}

void start()
{
  
} 
