#include <admin_interface.h>

string parse( RequestID id )
{
  array res = ({});
  object ce = loader.LowErrorContainer();
  master()->set_inhibit_compile_errors( ce );

  loader.push_compile_error_handler( ce );
  foreach( glob( "*.pike", get_dir( dirname( __FILE__ ) ) ), string f )
  {
    object q;
    catch
    {
      if( (q = ((program)f)()) && q->task &&
	  (!config_setting2("group_tasks")
	   || (q->task == (id->variables->class||"status") )) )
      {
        res += ({("<task name='" +
		  replace((string)q->name, ({"\"", "'"}), ({"&#34;", "&#39;"})) + 
		  "' fname="+f+" >" + q->doc + "</task>")});
      }
    };
  }
  loader.pop_compile_error_handler( );
  master()->set_inhibit_compile_errors( 0 );

  if( config_setting( "devel_mode" ) && sizeof( ce->get() ) )
    res += ({"Warning: <pre>"+Roxen.html_encode_string(ce->get())+"</pre>"});
  if( sizeof( ce->get() ) )
    report_debug( "While compiling tasks: \n"+ce->get() );
  return sort(res)*"\n";
}
