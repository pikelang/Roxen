string parse( RequestID id )
{
  if( id->variables->create_user_name &&
      strlen( id->variables->create_user_name ) )
    core.create_admin_user(  id->variables->create_user_name );
  return "";
}
