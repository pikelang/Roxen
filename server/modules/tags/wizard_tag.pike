/* This is a Roxen Challenger(r) module. Copyright (c) Idonex 1997.
 * Released under GPL
 * made by Per Hedbor
 */

constant cvs_version = "$Id: wizard_tag.pike,v 1.1 1997/11/14 06:51:15 per Exp $";
constant thread_safe=1;
#include <module.h>
inherit "module";
inherit "wizard";

mixed *register_module()
{
  return ({MODULE_PARSER,"Wizard generator",("Generates wizards"),({}),1,});
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










