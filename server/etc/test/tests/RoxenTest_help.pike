inherit "pike_test_common.pike";
inherit "rxmlhelp";

void run_tests( Configuration c ) {

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
}
