#include <config_interface.h>

string parse( RequestID id )
{
  array res = ({});
  object ce = roxenloader.LowErrorContainer();
  master()->set_inhibit_compile_errors( ce );

  roxenloader.push_compile_error_handler( ce );
  foreach( glob( "*.pike", get_dir( dirname( __FILE__ ) ) ), string f )
  {
    object q;
    catch
    {
      if( (q = ((program)f)()) && q->action &&
	  (!config_setting2("group_tasks")
	   || (q->action == (id->variables->class||"status") )) &&
	  (!q->enabled || (q->enabled && q->enabled())))
      {
        res += ({("<action name='" + 
		  replace((string)q->name, ({"\"", "'"}), ({"&#34;", "&#39;"})) + 
		  "' fname="+f+" >" + q->doc + "</action>")});
      }
    };
  }
  roxenloader.pop_compile_error_handler( );
  master()->set_inhibit_compile_errors( 0 );

  if( config_setting( "devel_mode" ) && strlen( ce->get() ) )
    res += ({"Warning: <pre>"+Roxen.html_encode_string(ce->get())+"</pre>"});
  if( strlen( ce->get() ) )
    report_debug( "While compiling tasks: \n"+ce->get() );
  return sort(res)*"\n";
}
