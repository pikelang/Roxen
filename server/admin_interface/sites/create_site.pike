
string decode_site_name( string what )
{
  if( (int)what && (search(what, ",") != -1))
    return (string)((array(int))(what/","-({""})));
  return what;
}

string parse( RequestID id )
{
  if( !id->misc->config_user->auth( "Create New Site" ) )
    return "Permission denied";

  string name = decode_site_name(id->variables->name);
  object conf = core.enable_configuration( name );
  conf->set( "URLs", ({}) );
  conf->error_log = ([]);
  catch(DBManager.set_permission( "docs",   conf,  DBManager.READ ));
  catch(DBManager.set_permission( "replicate",  conf,  DBManager.WRITE ));
  DBManager.set_permission( "local",  conf,  DBManager.WRITE );
  conf->save( 1 );
  return "ok";
}
