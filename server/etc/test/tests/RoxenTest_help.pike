inherit "pike_test_common.pike";
inherit "rxmlhelp";

array(string) new = ({});
#include <module_constants.h>

void run_tests( Configuration c )
{
  // Create a new server
  test( roxen.enable_configuration, "helptestserver" );

  c = test_generic( check_is_configuration,
		    roxen.find_configuration,
		    "helptestserver" );

  if( !c )  {
    report_error( "Failed to find test configuration\n");
    return;
  }
  test(DBManager.set_permission, "local", c, DBManager.WRITE);
  test(c->set, "URLs", ({ "http://*:17372" }) );
  test(c->start, 0);
  
  // Add all modules except wrapper modules and other funny stuff.
  array modules = roxen->all_modules();
  sort(modules->sname, modules);
  foreach(modules, ModuleInfo m) {
    if( (< "roxen_test", "config_tags", "update",
	   "compat", "configtablist", "flik", "lpctag",
	   "ximg", "userdb", "htmlparse", "directories2",
	   "fastdir" >)[m->sname] )
      continue;
    current_test++;
    new += ({ m->sname });
    test_generic( check_is_module, c->enable_module, m->sname );
  }

  // Wait for everything to settle down.
  sleep(5);
  test( c->disable_module, "ac_filesystem" );
  //test( c->disable_module, "auth" );
  sleep(5);

  // Make a list of all tags and PI:s
  array tags=map(indices(c->rxml_tag_set->get_tag_names()),
		 lambda(string tag) {
		   if(tag[..3]=="!--#" || !has_value(tag, "#"))
		     return tag;
		   return "";
		 } ) - ({ "" });
  tags += map(indices(c->rxml_tag_set->get_proc_instr_names()),
	      lambda(string tag) { return "?"+tag; } );

  RequestID id = roxen.InternalRequestID( );
  id->conf = c;
  id->set_url( "http://localhost:80/" );

  foreach(tags, string tag)
    test_true(find_tag_doc, tag, id);

  foreach(new, string m)
    test( c->disable_module, m );

  test(c->stop);
  test( roxen.disable_configuration, "usertestconfig" );
}
