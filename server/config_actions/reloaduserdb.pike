/*
 * $Id: reloaduserdb.pike,v 1.3 1997/08/20 14:23:55 per Exp $
 */

inherit "roxenlib";
constant name= "Cache//Flush user cache";

constant doc = ("Force a flush of the user and password cache in all "
		"virtual servers.");

mixed handle(object id, object mc)
{
  foreach(roxen->configurations, object c)
    if(c->modules["userdb"] && c->modules["userdb"]->master)
      c->modules["userdb"]->master->read_data();
  return http_redirect(roxen->config_url()+"Actions/");
}
