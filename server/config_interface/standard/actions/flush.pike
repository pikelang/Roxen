/*
 * $Id: flush.pike,v 1.5 2000/07/21 04:57:10 lange Exp $
 */
#include <config_interface.h>
#include <roxen.h>

constant action = "maintenance";

constant name= "Flush caches";
constant name_svenska= "Töm cacher";

constant doc = ("Flush all memory caches.");
constant doc_svenska = ("Töm alla minnescacher.");

//<locale-token project="roxen_config"> LOCALE </locale-token>
#define LOCALE(X,Y)  _STR_LOCALE("roxen_config",X,Y)

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

  gc();
}

mixed parse( RequestID id )
{
  doit();
  return LOCALE(232,"All memory caches have been flushed.") + 
         "<p><cf-ok>";
}
