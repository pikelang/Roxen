/*
 * $Id: locks.pike,v 1.11 2002/06/13 00:28:52 nilsson Exp $
 */

#include <config.h>
#ifdef THREADS

inherit "wizard";
inherit "../logutil";

constant task = "debug_info";
constant name = "Module lock status";
constant doc  = "Shows various information about the module thread locks in Roxen.";

string describe_module(object q)
{
  foreach(roxen->configurations, object c)
  {
    foreach(indices(c->modules), string m)
    {
	int w;
	mapping mod = c->modules[m];
	if(mod->enabled == q)
	  return sprintf("<a href=\"%s\">%s</a></td><td>%s",
			 @get_conf_url_to_module(c->name+"/"+m), roxen->filename(q));
	else if(mod->copies && !zero_type(search(mod->copies,q)))
	  return sprintf("<a href=\"%s\">%s</a></td><td>%s",
			 @get_conf_url_to_module(c->name+"/"+m+"#"+search(mod->copies,q)),
			 roxen->filename(q));
    }
  }
  return "Unknown module</td><td>"+roxen->filename(q)+"";
}

string parse( RequestID id )
{
  mapping l = ([]), locks=([]), L=([]);
  foreach(roxen->configurations, object c) {
    if (c->locked) {
      l += c->locked;
    }
    if (c->thread_safe) {
      L += c->thread_safe;
    }
  }
  mapping res=([]);
  string data=("<font size='+2'>"
	       "Module lock status : Accesses to all modules"
	       "</font><p>"
	       "Locked means that the access was done using a "
	       "serializing lock since the module was not thread-safe, "
	       "unlocked means that there was no need for a lock."
	       "</p><p>"
	       "Locked accesses to a single module can inflict "
	       "quite a severe performance degradation of the whole "
	       "server, since a locked module will act as a bottleneck, "
	       "blocking access for all other threads that want to "
	       "access that module."
	       "</p><p>"
	       "This is only a problem if a significant percentage "
	       "of the accesses are passed through non-threadsafe "
	       "modules.</p>");
  array mods = (indices(L)+indices(l));
  mods &= mods;
  foreach(mods, object q)
  {
    res[describe_module(q)]+=l[q];
    locks[describe_module(q)]+=L[q];
  }
  array rows = ({});
  foreach(sort(indices(res)), string q)
    rows += ({ ({q,(string)(res[q]||""),(string)(locks[q]||"") }) });
  return data +
    html_table( ({ "Module", "File", "Locked", "Unlocked" }), rows ) +
    "<p><cf-ok/></p>";
}
#endif /* THREADS */
