#include <config_interface.h>
#include <roxen.h>
USE_DEFERRED_LOCALE;
#define LOCALE(X,Y)	_DEF_LOCALE("config_interface",X,Y)


string|mapping parse( object id )
{
  if( !config_perm( "Create Site" ) )
    return "No permission to do that";

  Configuration cf = roxen->find_configuration( id->variables->site );

  if( !cf ) return "No such configuration: "+id->variables->site;

  report_notice(LOCALE("", "Disabling old configuration %s\n"), cf->name);

  string cfname = roxen.configuration_dir + "/" + cf->name;
  mv (cfname, cfname + "~");
  roxen->configurations -= ({ cf });
  roxen->remove_configuration( cf->name );
  cf->stop();
  destruct( cf );
  return Roxen.http_redirect( "", id );
}
