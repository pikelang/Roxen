// This is a roxen module. Copyright © 1999 - 2000, Roxen IS.
//
// $Id: config_userdb.pike,v 1.54 2000/09/12 14:05:52 per Exp $

inherit "module";
#include <config_interface.h>
#include <roxen.h>
#include <module.h>

//<locale-token project="roxen_config"> LOCALE </locale-token>
//<locale-token project="roxen_config"> SLOCALE </locale-token>
USE_DEFERRED_LOCALE;
#define LOCALE(X,Y)	_DEF_LOCALE("roxen_config",X,Y)
#define SLOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

constant module_type   = MODULE_AUTH | MODULE_FIRST;
constant module_name   = "Configuration UserDB";
constant module_doc    = "This user database keeps the configuration users "
                         "passwords and other settings.";
constant module_unique = 1;
constant thread_safe   = 1;

void create()
{
  roxen.add_permission( "View Settings", LOCALE(192, "View Settings"));
  roxen.add_permission( "Edit Users", 
                        LOCALE(193, "Edit Users"));
  roxen.add_permission( "Edit Global Variables", 
                        LOCALE(194, "Edit Global Variables"));
  roxen.add_permission( "Edit Module Variables", 
                        LOCALE(195, "Edit Module Variables"));
  roxen.add_permission( "Tasks", LOCALE(196, "Tasks"));
  roxen.add_permission( "Restart", LOCALE(197, "Restart"));
  roxen.add_permission( "Shutdown", LOCALE(198, "Shutdown"));
  roxen.add_permission( "Create Site", LOCALE(199, "Create Sites"));
  roxen.add_permission( "Add Module", LOCALE(200, "Add Modules"));
}



mapping logged_in = ([]);

array auth( array auth_, RequestID id, void|int silent )
{
  array auth = auth_;
  auth_ = ({ auth[0], "CENSORED:PASSWORD" });

  array arr = auth[1]/":";
  if( sizeof(arr) < 2 )
    return ({ 0, auth[1], -1 });

  string host;

  if( array h = gethostbyaddr( id->remoteaddr ) )
    host = h[0];
  else
    host = id->remoteaddr;

  string u = arr[0];
  string p = arr[1..]*":";
  if( AdminUser uo = roxen.find_admin_user( u ) )
  {
    if( !uo->valid_id( id ) )
    {
      if (!silent)
	report_notice( "Failed login attempt %s from %s\n", u, host);
      return ({ 0, u, p });
    }

    id->variables->config_user_uid = u;
    id->variables->config_user_name = uo->real_name;

    /* Compatibility. Will probably be removed soon */
    id->misc->create_new_config_user = roxen.create_admin_user;
    id->misc->delete_old_config_user = roxen.delete_admin_user;
    id->misc->list_config_users = roxen.list_admin_users;
    id->misc->get_config_user = roxen.find_admin_user;

    id->misc->remote_config_host = host;
    id->misc->config_user = uo;
    return ({ 1, u, 0 });
  }
  if (!silent)
    report_notice( "Failed login attempt %s from %s\n", u, host);
  return ({ 0, u, p });
}

void first_try( RequestID id )
{
  string u;
  if( id->misc->config_user )
    u = id->misc->config_user->name;
  else
    return;

  string host = id->misc->remote_config_host;

  if( !host )
    if( array h = gethostbyaddr( id->remoteaddr ) )
      host = h[0];
    else
      host = id->remoteaddr;

  if( (time(1) - logged_in[ u+host ]) > 1800 )
    report_notice(SLOCALE("dt", "Administrator logged on as %s from %s.\n"),
		  u, host+" ("+id->remoteaddr+")" );

  logged_in[ u+host ] = time(1);
  roxen.adminrequest_get_context( u, host, id );
}
