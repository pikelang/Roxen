inherit Protocol;
constant supports_ipless = 1;
constant name = "http";
constant requesthandlerfile = "protocols/http.pike";
constant default_port = 80;

int set_cookie, set_cookie_only_once;

void fix_cvars( Variable.Variable a )
{
  set_cookie = query( "set_cookie" );
  set_cookie_only_once = query( "set_cookie_only_once" );
}

void create( mixed ... args )
{
  roxen.set_up_http_variables( this_object() );
  if( variables[ "set_cookie" ] )
    variables[ "set_cookie" ]->set_changed_callback( fix_cvars );
  if( variables[ "set_cookie_only_once" ] )
    variables[ "set_cookie_only_once" ]->set_changed_callback( fix_cvars );
  fix_cvars(0);
  ::create( @args );
}
