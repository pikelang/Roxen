/*
 * $Id: flush.pike,v 1.16 2004/05/28 19:12:49 _cvs_stephen Exp $
 */
#include <admin_interface.h>

constant task = "maintenance";
constant name = "Flush caches";
constant doc  = "Flush all memory caches.";

mixed doit()
{
  /* Flush the userdb. */
  foreach(core->configurations, object c)
    if(c->modules["userdb"] && c->modules["userdb"]->master)
      c->modules["userdb"]->master->read_data();

  /* Flush the memory cache. */
  cache.flush_memory_cache();

  /* Flush the dir cache. */
  foreach(core->configurations, object c)
    if(c->modules["directories"] && (c=c->modules["directories"]->enabled))
    {
      catch{
	c->_root->dest();
	c->_root = 0;
      };
    }

  /* Flush the module cache. */
  foreach( indices( core->module_cache ), string q )
    core->module_cache->delete( q );
  core->modules = ([ ]);

  // Flush the locale cache.
#if constant(Locale.flush_cache)
  Locale.flush_cache();
#endif
  
  gc();
}

mixed parse( RequestID id )
{
  string res =
#"<font size='+1'><b>Flush caches</b></font>
<p /> 
";
  doit();
  res += "All memory caches have been flushed."
    "<p><cf-ok/></p>";
  return res;
}
