/*
 * $Id: flush.pike,v 1.15 2003/01/19 20:43:34 mani Exp $
 */
#include <admin_interface.h>

constant task = "maintenance";
constant name = "Flush caches";
constant doc  = "Flush all memory caches.";

#define ROW(X,Y) ret+="<tr><td>" X "</td><td>" Y "</td></tr>";

string doit()
{
  string ret = "<table cellpadding=\"3\" cellspacing=\"0\" border=\"0\">"
    "<tr bgcolor=\"&usr.fade3;\"><td>Cache</td><td>Action</td></tr>";

  // Flush the userdb.
  foreach(core->configurations, object c)
    if(c->modules["userdb"] && c->modules["userdb"]->master)
      c->modules["userdb"]->master->read_data();
  ROW("User Database","Reloaded");

  // Flush the memory cache.
  cache.flush_memory_cache();
  ROW("General Memeory Cache","Flushed");

  // Flush the module cache.
  foreach( indices( core->module_cache ), string q )
    core->module_cache->delete( q );
  core->modules = ([ ]);
  ROW("Module Cache","Flushed");

  // Flush the locale cache.
  Locale.flush_cache();
  ROW("Locale Cache","Flushed");

  // Flush the frontend cache.
  core->configurations->datacache->flush();
  ROW("Frontend Cache","Flushed");

  gc();

  return ret + "</table>";
}

mixed parse( RequestID id )
{
  // NGSERVER: Make this a three button view;
  // [Flush memory caches] [Flush persistant caches] [Return]
  string ret = "<input type='hidden' name='action' value='flush.pike' />";
  if(id->variables->knapp1)
    ret += doit();
  ret += "<p><submit-gbutton2 name='knapp1'>"
    "Flush memory caches</submit-gbutton2>"
    //    "<submit-gbutton2 name='knapp2'>"
    //    "Flush persistent caches</submit-gbutton2>"
    "<cf-cancel href='?class=&form.class;'/></p>";
  return ret;
}
