// This is a roxen protocol module.
// Copyright © 2001 - 2009, Roxen IS.

inherit Protocol;
constant supports_ipless = 1;
constant name = "http";
constant prot_name = "http";
constant requesthandlerfile = "protocols/http.pike";
constant default_port = 80;

int set_cookie, set_cookie_only_once;
int minimum_byterate;

void fix_cvars( Variable.Variable a )
{
  set_cookie = query( "set_cookie" );
  set_cookie_only_once = query( "set_cookie_only_once" );
  minimum_byterate = query( "minimum_bitrate" ) / 8;
}

void create( mixed ... args )
{
  roxen.set_up_http_variables( this_object() );
  variables[ "set_cookie" ]->set_changed_callback( fix_cvars );
  variables[ "set_cookie_only_once" ]->set_changed_callback( fix_cvars );
  variables[ "minimum_bitrate" ]->set_changed_callback( fix_cvars );
  fix_cvars(0);
  ::create( @args );
}
