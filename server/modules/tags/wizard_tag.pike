/* This is a Roxen Challenger(r) module. Copyright (c) Idonex 1997.
 * Released under GPL
 * made by Per Hedbor
 */

constant cvs_version = "$Id: wizard_tag.pike,v 1.19 1999/05/20 03:26:23 neotron Exp $";
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

string internal_done(string t, mapping args, string contents, int l, int ol,
		     mapping f)
{
  f->done=contents;
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
  if(!id->misc->line)
    id->misc->line=-1;
  mapping f = ([ "pages":({}) ]);
  string pike = ("inherit \"wizard\";\n" +
		 sprintf("# "+id->misc->line+" %O\n"
			 "string name = %O;\n",
			 id->not_query, (args->name||"unnamed")));
  int p;
  foreach(glob("*-label", indices(args)), string a)
  {
    pike += sprintf("# "+id->misc->line+" %O\n",
		    id->not_query);
    pike += sprintf("  string "+replace(replace(a,"-","_"),({"(",")","+",">"}),
					({"","","",""}))+ 
		    " = %O;\n", args[a]);
  }


  if(args->ok)
  {
    pike += sprintf("# "+id->misc->line+" %O\n", id->not_query);
    pike += sprintf("mixed wizard_done(object id)\n"
		    "{\n"
		    "  id->not_query = %O;\n\""+
		    "  return id->conf->get_file( id );\n"
		    "}\n\n",
		    fix_relative(args->ok, id));
  }

  parse_html_lines(contents,
		   ([]),
		   ([ "page":internal_page,
		      "done":internal_done ]), 
		   (int)id->misc->line,f);
  if (f->done && !args->ok) {
    pike += sprintf("mixed wizard_done(object id)\n"
		    "{\n"
		    "  return parse_rxml(%O,id);\n"
		    "}\n", f->done);
  }
  foreach(f->pages, array q)
  {
    pike += sprintf("# "+q[1]+" %O\n", id->not_query);
    pike += sprintf("string page_"+p+"(object id) {" +
		    "  return parse_rxml(%O,id);\n"
		    "}\n", q[0]);
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


  mixed res = w->wizard_for(id,fix_relative(args->cancel||args->done||"",id));

  if(mappingp(res))
  {
    defines[" _error"] = res->error;
    defines[" _extra_heads"] = res->extra_heads;
    return res->data||(res->file&&res->file->read())||"";
  }
  return res;
}


mapping query_tag_callers() { return ([]); }

mapping query_container_callers()
{
  return ([ "wizard" : tag_wizard ]);
}

void start()
{
  
} 
