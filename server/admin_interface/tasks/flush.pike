/*
 * $Id: flush.pike,v 1.14 2002/11/07 18:07:33 mani Exp $
 */
#include <admin_interface.h>

constant task = "maintenance";
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
  Locale.flush_cache();

  gc();
}

mixed parse( RequestID id )
{
  // NGSERVER: Make this a three button view;
  // [Flush memory caches] [Flush persistant caches] [Return]
  doit();
  return "All memory caches have been flushed."
    "<p><cf-ok/></p>";
}
