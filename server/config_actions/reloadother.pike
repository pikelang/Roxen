/*
 * $Id: reloadother.pike,v 1.1 1997/08/21 10:50:38 per Exp $
 */

inherit "roxenlib";
constant name= "Cache//Flush other caches";

constant doc = ("Force a flush of the memory cache (the one described under the Status -&gt; Memory cache system node) and all directory module caches.");

mixed handle(object id, object mc)
{
  gc();
  function_object(cache_set)->cache = ([]);
  foreach(roxen->configurations, object c)
    if(c->modules["directories"] && (c=c->modules["directories"]->enabled))
    {
      catch{c->_root->dest();};
      c->_root = 0;
    }
  gc();
  return http_redirect(roxen->config_url()+"Actions/");
}
