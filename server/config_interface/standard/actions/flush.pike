/*
 * $Id: flush.pike,v 1.3 2000/03/23 00:40:09 mast Exp $
 */
#include <config_interface.h>

constant action = "maintenance";

constant name= "Flush caches";
constant name_svenska= "Töm cacher";

constant doc = ("Flush all memory caches.");
constant doc_svenska = ("Töm alla minnescacher.");

mixed doit()
{
  /* Flush the userdb. */
  foreach(roxen->configurations, object c)
    if(c->modules["userdb"] && c->modules["userdb"]->master)
      c->modules["userdb"]->master->read_data();

  /* Flush the memory cache. */
  function_object(cache_set)->cache = ([]);

  /* Flush the dir cache. */
  foreach(roxen->configurations, object c)
    if(c->modules["directories"] && (c=c->modules["directories"]->enabled))
    {
      catch{
	c->_root->dest();
	c->_root = 0;
      };
    }

  /* Flush the module cache. */
  foreach( indices( roxen->module_cache ), string q )
    roxen->module_cache->delete( q );
  roxen->modules = ([ ]);

  gc();
}

mixed parse(object id)
{
  doit();
  return "&locale.all_memory_caches_flushed; "
         "<p><cf-ok>";
}
