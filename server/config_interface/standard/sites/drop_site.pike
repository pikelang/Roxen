#include <config_interface.h>
#include <roxen.h>

//<locale-token project="roxen_config">LOCALE</locale-token>
USE_DEFERRED_LOCALE;
#define LOCALE(X,Y)	_DEF_LOCALE("roxen_config",X,Y)


string|mapping parse( RequestID id )
{
  if( !config_perm( "Create Site" ) )
    return LOCALE(226, "Permission denied");

  Configuration cf = roxen->find_configuration( id->variables->site );

  if( !cf ) return "No such configuration: "+id->variables->site;

  report_notice(LOCALE(255, "Disabling old configuration %s\n"), cf->name);

  string cfname = roxen.configuration_dir + "/" + cf->name;
  mv (cfname, cfname + "~");
  roxen->configurations -= ({ cf });
  roxen->remove_configuration( cf->name );
  cf->stop();
  destruct( cf );
  return Roxen.http_redirect( "", id );
}
