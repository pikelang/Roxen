inherit "pike_test_common.pike";
inherit "rxmlhelp";

array(string) new = ({});
#include <module_constants.h>

void run_tests( Configuration c )
{
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
  id->set_url( "http://localhost:80/" );
  id->conf = c;

  foreach(tags, string tag)
    test_true(find_tag_doc, tag, id);

  foreach(new, string m)
    test( c->disable_module, m );
}


void low_run_tests( Configuration c, function go_on )
{
  if( mixed err = catch {
    foreach(roxen->all_modules(), ModuleInfo m) {
      if( (< "roxen_test", "config_tags", "update",
	     "compat", "configtablist", "flik", "lpctag",
	     "xmig" >)[m->sname] )
	continue;
      current_test++;
      if( (m->type & MODULE_TAG) && !c->enabled_modules[m->sname])
      {
	test_generic( check_is_module, c->enable_module, m->sname );
	new += ({ m->sname });
      }
    }
  } )
  {
    go_on( current_test, tests_failed+1 );
    return;
  }
  call_out( lambda(){
	      mixed err = catch {
		run_tests( c );
	      };
	      if( err )
		write( describe_backtrace( err ) );
	      go_on( current_test, tests_failed );
	    }, 0.5 ); // enable_module does some work in a call_out
}
