string parse( object id )
{
  if( !strlen(id->variables->user_name) )
    return "<error>Too short user name</error>";
  id->misc->create_new_config_user(   id->variables->user_name );
  return "";
}
