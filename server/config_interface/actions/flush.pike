/*
 * $Id: flush.pike,v 1.10 2002/06/12 23:47:04 nilsson Exp $
 */
#include <config_interface.h>

constant action = "maintenance";
constant name = "Flush caches";
constant doc  = "Flush all memory caches.";

mixed doit()
{
  /* Flush the userdb. */
  foreach(roxen->configurations, object c)
    if(c->modules["userdb"] && c->modules["userdb"]->master)
      c->modules["userdb"]->master->read_data();

  /* Flush the memory cache. */
  cache.flush_memory_cache();

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

  // Flush the locale cache.
#if constant(Locale.flush_cache)
  Locale.flush_cache();
#endif
  
  gc();
}

mixed parse( RequestID id )
{
  doit();
  return "All memory caches have been flushed."
    "<p><cf-ok/></p>";
}
