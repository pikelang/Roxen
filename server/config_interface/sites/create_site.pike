#include <roxen.h>
//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

string decode_site_name( string what )
{
  if( (int)what && (search(what, ",") != -1))
    return (string)((array(int))(what/","-({""})));
  return what;
}

string parse( RequestID id )
{
  if( !id->misc->config_user->auth( "Create New Site" ) )
    return LOCALE(226, "Permission denied");

  string name = decode_site_name(id->variables->name);
  object conf = roxen.enable_configuration( name );
  conf->save( 1 );
  return "ok";
}
