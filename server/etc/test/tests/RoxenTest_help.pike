inherit "pike_test_common.pike";
inherit "rxmlhelp";

#include <module_constants.h>

void run_tests( Configuration c ) {

  array(string) new = ({});
  foreach(roxen->all_modules(), ModuleInfo m) {
    if( (< "roxen_test", "config_tags", "update",
	   "compat", "configtablist", "flik", "lpctag",
	   "xmig" >)[m->sname] )
      continue;
    if( (m->type & MODULE_TAG) &&
	!c->enabled_modules[m->sname]) {
      c->enable_module(m->sname);
      new += ({ m->sname });
    }
  }

  // Make a list of all tags and PI:s
  array tags=map(indices(c->rxml_tag_set->get_tag_names()),
		 lambda(string tag) {
		   if(tag[..3]=="!--#" || !has_value(tag, "#"))
		     return tag;
		   return "";
		 } ) - ({ "" });
  tags += map(indices(c->rxml_tag_set->get_proc_instr_names()),
	      lambda(string tag) { return "?"+tag; } );

  // Create a context.
  RXML.set_context(RXML.Context(c->rxml_tag_set));

  foreach(tags, string tag)
    test(find_tag_doc, tag);

  foreach(new, string m)
    c->disable_module(m);
}
