
#include <config_interface.h>
inherit "roxenlib";

string|mapping parse( object id )
{
  if( !config_perm( "Create Site" ) )
    return "No permission to do that";

  Configuration cf = roxen->find_configuration( id->variables->site );

  if( !cf ) return "No such configuration: "+id->variables->site;

  report_notice(roxen->locale->get()->
                base_server->
                disabling_configuration(cf->name));

  string cfname = roxen.configuration_dir + "/" + cf->name;
  mv (cfname, cfname + "~");
  roxen->configurations -= ({ cf });
  roxen->remove_configuration( cf->name );
  cf->stop();
  destruct( cf );
  return http_redirect( "", id );
}
