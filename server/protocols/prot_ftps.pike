// This is a roxen protocol module.
// Copyright © 2001 - 2009, Roxen IS.

// cf http://en.wikipedia.org/wiki/FTPS
inherit SSLProtocol;
constant supports_ipless = 0;
constant name = "ftps";
constant prot_name = "ftps";
constant requesthandlerfile = "protocols/ftp.pike";
constant default_port = 990;


// Some statistics
int sessions;
int ftp_users;
int ftp_users_now;

mapping(string:int) ftp_sessions = ([]);

void create( mixed ... args )
{
  roxen.set_up_ftp_variables( this_object() );
  ::create( @args );
}
