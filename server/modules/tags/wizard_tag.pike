// This is a roxen module. Copyright © 1997 - 2009, Roxen IS.
// Released under GPL
// made by Per Hedbor

constant cvs_version = "$Id$";
constant thread_safe=1;
#include <module.h>
inherit "module";
inherit "wizard";

constant module_type = MODULE_TAG;
constant module_name = "Tags: Wizard generator";
constant module_doc  = 
#"Provides the <tt>&lt;wizard&gt;</tt> tag that is used to create wizard
like user interface. Each wizard can contain several pages with form. The
user moves through each page in order and the module keeps track of all
the user's choices.";

string internal_verify(string t, mapping args, string contents, int l, int ol,
		       mapping m)
{
  if(sizeof(args))
    contents = make_container("if", args, contents);
  m->verify += ({ ({ contents, ol + l, m->id }) });
  return "<__wizard_error__ id=\"id_"+(m->id++)+"\">";
}

string internal_page(string t, mapping args, string contents, int l, int ol,
		     mapping f, RequestID id)
{
  mapping m = ([ "verify":({ }) ]);

  f->pages += ({ ({
    parse_html_lines(contents, ([]), ([ "verify":internal_verify ]), l, m),
    ol + l, m->verify }) });
}

string internal_done(string t, mapping args, string contents, int l, int ol,
		     mapping f, RequestID id)
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

  if (args->method || args->enctype) {
    string method = "";
    if (args->method)
      method += " method=" + Roxen.html_encode_tag_value (args->method);
    if (args->enctype)
      method += " enctype=" + Roxen.html_encode_tag_value (args->enctype);
    pike += sprintf ("constant wizard_method = %O;\n", method);
  }

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
		   (int)id->misc->line, f, id);
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

    // Code to enable verification of wizard pages.
    if(q[2] && sizeof(q[2])) {
      // FIXME line numbers for verify sections.
      pike += "int verify_"+p+"(object id) {\n"
	      "  int c;\n"
	      "  string s = \"\";\n"
	      "  id->misc->__wizard_error__ = ([ ]);\n";
      foreach(q[2], array v)
	pike += sprintf("  s = parse_rxml(%O, id);\n"
			"  if(id->misc->defines[\" _ok\"]) {\n"
			"    id->misc->__wizard_error__->id_%d = s;\n"
			"    c++;\n"
			"  }\n", v[0], v[2]);

      pike += "  if(c)\n"
	      "    return 1;\n"
	      "}\n";
    }

    p++;
  }
  //werror("Wiz: %s\n", pike);
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
    RXML_CONTEXT->set_misc (" _error", res->error);
    RXML_CONTEXT->extend_scope ("header", res->extra_heads);
    return res->data||(res->file&&res->file->read())||"";
  }
  return res;
}

string tag_wizard_error(string t, mapping args, object id,
			object file, mapping defines)
{
  if(id->misc->__wizard_error__ && args->id &&
     id->misc->__wizard_error__[args->id])
    return id->misc->__wizard_error__[args->id];
  return "";
}

mapping query_tag_callers()
{
  return ([ "__wizard_error__" : tag_wizard_error ]);
}

mapping query_container_callers()
{
  return ([ "wizard" : tag_wizard ]);
}

