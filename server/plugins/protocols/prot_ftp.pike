// This is a ChiliMoon protocol module.
// Copyright © 2001, Roxen IS.

inherit Protocol;
constant supports_ipless = 0;
constant name = "ftp";
constant prot_name = "ftp";
constant requesthandlerfile = "plugins/protocols/ftp.pike";
constant default_port = 21;

// Some statistics
int sessions;
int ftp_users;
int ftp_users_now;

mapping(string:int) ftp_sessions = ([]);

void create( mixed ... args )
{
  core.set_up_ftp_variables( this_object() );
  ::create( @args );
}
