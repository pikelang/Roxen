string parse( RequestID id )
{
  if( !id->variables->create_user_name ||
      !strlen( id->variables->create_user_name ) )
    return "";
  id->misc->create_new_config_user( id->variables->create_user_name );
  return "";
}
