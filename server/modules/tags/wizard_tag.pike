/* This is a Roxen Challenger(r) module. Copyright (c) Idonex 1997.
 * Released under GPL
 * made by Per Hedbor
 */

constant cvs_version = "$Id: wizard_tag.pike,v 1.11 1998/07/19 17:16:38 grubba Exp $";
constant thread_safe=1;
#include <module.h>
inherit "module";
inherit "wizard";

mixed *register_module()
{
  return ({MODULE_PARSER,"Wizard generator",
          "Generates wizards<p>See &lt;wizard help&gt; for more information\n",
          ({}),1,});
}

string internal_page(string t, mapping args, string contents, int l, int ol,
		     mapping f)
{
  f->pages +=({({contents,ol+l})});
}

string fix_relative(string file, object id)
{
  if(file != "" && file[0] == '/') return file;
  file = combine_path(dirname(id->not_query) + "/",  file);
  return file;
}

string old_pike = "";
object old_wizard = 0;

string tag_wizard(string t, mapping args, string contents, object id,
		  object file, mapping defines)
{
  if(!defines->line)
    defines->line=-1;
  mapping f = ([ "pages":({}) ]);
  string pike = ("inherit \"wizard\";\n" +
#if (__VERSION__ >= 0.6)
		 sprintf("# "+defines->line+" %O\n"
			 "string name = %O;\n",
			 id->not_query, (args->name||"unnamed"))
#else
		 "# "+defines->line+" \""+id->not_query+"\"\n"
		 "string name=\""+(args->name||"unnamed") + "\";\n"
#endif /* __VERSION__ >= 0.6 */
		 );
  int p;
  foreach(glob("*-label", indices(args)), string a)
  {
#if __VERSION__ >= 0.6
    pike += sprintf("# "+defines->line+" %O\n",
		    id->not_query);
    pike += sprintf("  string "+replace(replace(a,"-","_"),({"(",")","+",">"}),
					({"","","",""}))+ 
		    " = %O;\n", args[a]);
#else
    pike += ("# "+defines->line+" \""+id->not_query+"\"\n");
    pike += "  string "+replace(replace(a,"-","_"),({"(",")","+",">"}),
				({"","","",""}))+ 
      " = \""+replace(args[a], ({"\"","\n","\r", "\\"}), 
		      ({"\\\"", "\\n", "\\r", "\\\\"}))+"\";\n";
#endif /* __VERSION__ >= 0.6 */
  }


  if(args->ok)
  {
#if __VERSION__ >= 0.6
    pike += sprintf("# "+defines->line+" %O\n", id->not_query);
    pike += sprintf("mixed wizard_done(object id)\n"
		    "{\n"
		    "  id->not_query = %O;\n\""+
		    "  return roxen->get_file( id );\n"
		    "}\n\n",
		    fix_relative(args->ok, id));
#else
    pike += ("# "+defines->line+" \""+id->not_query+"\"\n");
    pike += ("mixed wizard_done(object id)\n"
	     "{\n"
	     "  id->not_query = \""+
	     fix_relative(replace(args->ok, ({"\"","\n","\r", "\\"}), 
				  ({"\\\"", "\\n", "\\r", "\\\\"})),id)+"\";\n"
	     "  return roxen->get_file( id );\n"
	     "}\n\n");
#endif /* __VERSION__ >= 0.6 */
  }
  parse_html_lines(contents, ([]), (["page":internal_page]), 
		   (int)defines->line,f);
  foreach(f->pages, array q)
  {
#if __VERSION__ >= 0.6
    pike += sprintf("# "+q[1]+" %O\n", id->not_query);
    pike += sprintf("string page_"+p+"(object id) {" +
		    "  return %O;\n"
		    "}\n", q[0]);
#else
    pike += ("# "+q[1]+" \""+id->not_query+"\"\n");
    pike += ("string page_"+p+"(object id) {" +
	     "return \""+replace(q[0], ({"\"","\n","\r", "\\"}), 
				 ({"\\\"", "\\n", "\\r", "\\\\"}))+"\";}\n");
#endif /* __VERSION__ >= 0.6 */
    p++;
  }
  object w;
  if(pike == old_pike)
    w = old_wizard;
  else
  {
    old_wizard = w = compile_string(pike)();
    old_pike = pike;
  }


  mixed res = w->wizard_for(id,fix_relative(args->cancel||args->done,id));

  if(mappingp(res))
  {
    defines[" _error"] = res->error;
    defines[" _extra_heads"] = res->extra_heads;
    return res->data||(res->file&&res->file->read())||"";
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
