string parse(object id )
{
  if( !id->misc->config_user->auth( "Create New Site" ) )
    return "No such luck, dude";

  string name = id->variables->name;
  object conf = roxen.enable_configuration( name );

  foreach( glob( "enable_module_*", indices(id->variables) ), string mod )
  {
    sscanf( mod, "enable_module_%s", mod );
    conf->enable_module( mod );
  }
  conf->save( 1 );
  return "ok";
}
