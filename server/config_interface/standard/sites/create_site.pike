string parse(object id )
{
  if( !id->misc->config_user->auth( "Create New Site" ) )
    return "No such luck, dude";

  string name = id->variables->name;
  object conf = roxen.enable_configuration( name );
  conf->save( 1 );
  return "ok";
}
