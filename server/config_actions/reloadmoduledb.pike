/*
 * $Id: reloadmoduledb.pike,v 1.2 1997/08/13 22:27:29 grubba Exp $
 */

inherit "roxenlib";
constant name= "Flush module cache";

constant doc = ("Force a flush of the module cache (used to describe modules "
		"on the 'add module' page)");

mixed handle(object id, object mc)
{
  roxen->allmodules=0;
  roxen->module_stat_cache=([]);
  return http_redirect(roxen->config_url()+"Actions/");
}
