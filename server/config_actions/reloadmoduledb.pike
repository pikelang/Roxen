/*
 * $Id: reloadmoduledb.pike,v 1.4 1997/08/21 10:50:37 per Exp $
 */

inherit "roxenlib";
constant name= "Cache//Flush module cache";

constant doc = ("Force a flush of the module cache (used to describe modules "
		"on the 'add module' page)");

mixed handle(object id, object mc)
{
  roxen->allmodules=0;
  roxen->module_stat_cache=([]);
  gc();
  return http_redirect(roxen->config_url()+"Actions/");
}
