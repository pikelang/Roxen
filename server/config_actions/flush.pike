/*
 * $Id: flush.pike,v 1.1 1997/08/24 02:20:40 peter Exp $
 */

inherit "wizard";
constant name= "Cache//Flush caches...";

constant doc = ("Flush a cache or two");

mixed page_0(object id, object mc)
{
  return ("<font size=+1>Which caches do you want to flush?</font><p>"
	  "<var name=module_cache type=checkbox> The module cache<br>\n"
	  "<help><blockquote>"
	  "Force a flush of the module cache (used to describe "
	  "modules on the 'add module' page)"
	  "</blockquote></help>"
	  "<var name=user_cache type=checkbox> The user cache<br>\n"
	  "<help><blockquote>"
	  "Force a flush of the user and password cache in all "
	  "virtual servers."
	  "</blockquote></help>"
	  "<var default=1 name=memory_cache type=checkbox> The memory cache<br>\n"
	  "<help><blockquote>"
	  "Force a flush of the memory cache (the one described "
	  "under the Actions -> Cache -> Cache status)."
	  "</blockquote></help>"
	  "<var default=1 name=other_cache type=checkbox> Directory caches<br>\n"
	  "<help><blockquote>"
	  "Force a flush of all directory module caches."
	  "</blockquote></help>");
}

mixed page_1(object id, object mc)
{
  string ret = "To flush the following caches press 'OK':\n<p>";

  if(id->variables->user_cache || id->variables->memory_cache ||
     id->variables->dir_cache  || id->variables->module_cache)
  {
    if(id->variables->user_cache != "0")   ret += "The userdb cache<br>";
    if(id->variables->memory_cache != "0") ret += "The memory cache<br>";    
    if(id->variables->dir_cache != "0")    ret += "The directory cache<br>";
    if(id->variables->module_cache != "0") ret += "The module cache<br>";
  } else
    ret += "No items selected!";

  return ret;
}

mixed wizard_done(object id, object mc)
{
  gc();

  /* Flush the userdb. */ 
  if(id->variables->user_cache != "0")
    foreach(roxen->configurations, object c)
      if(c->modules["userdb"] && c->modules["userdb"]->master)
	c->modules["userdb"]->master->read_data();

  /* Flush the memory cache. */ 
  if(id->variables->memory_cache != "0")
    function_object(cache_set)->cache = ([]);


  /* Flush the dir cache. */ 
  if(id->variables->dir_cache != "0")
  foreach(roxen->configurations, object c)
    if(c->modules["directories"] && (c=c->modules["directories"]->enabled))
    {
      catch{
	c->_root->dest();
	c->_root = 0;
      };
    }

  /* Flush the module cache. */ 
  if(id->variables->module_cache != "0")
  {
    roxen->allmodules=0;
    roxen->module_stat_cache=([]);
  }

  gc();
}

mixed handle(object id) { return wizard_for(id,0); }
