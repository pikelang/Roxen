/*
 * $Id: locks.pike,v 1.14 2004/05/31 23:01:45 _cvs_stephen Exp $
 */

#include <config.h>
#ifdef THREADS

inherit "wizard";
inherit "../logutil";

constant task = "debug_info";
constant name = "Module lock status";
constant doc  = "Shows various information about the module thread locks in ChiliMoon.";

string describe_module(object q)
{
  foreach(core->configurations, object c)
  {
    foreach(indices(c->modules), string m)
    {
	int w;
	mapping mod = c->modules[m];
	if(mod->enabled == q)
	  return sprintf("<a href=\"%s\">%s</a></td><td>%s",
			 @get_conf_url_to_module(c->name+"/"+m), core->filename(q));
	else if(mod->copies && !zero_type(search(mod->copies,q)))
	  return sprintf("<a href=\"%s\">%s</a></td><td>%s",
			 @get_conf_url_to_module(c->name+"/"+m+"#"+search(mod->copies,q)),
			 core->filename(q));
    }
  }
  return "Unknown module</td><td>"+core->filename(q)+"";
}

string parse( RequestID id )
{
  mapping l = ([]), locks=([]), L=([]);
  foreach(core->configurations, object c) {
    if (c->locked) {
      l += c->locked;
    }
    if (c->thread_safe) {
      L += c->thread_safe;
    }
  }
  mapping res=([]);
  string data=("<font size='+1'><b>"
	       "Module lock status : Accesses to all modules"
	       "</b></font><p>"
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
      html_table( ({ 
        "Module", "File", "Locked", 
        "Unlocked" }), rows,
		  ([ "titlebgcolor":"&usr.obox-titlebg;",
		     "bordercolor":"&usr.obox-border;",
		     "titlecolor":"&usr.obox-titlefg;",
		     "oddbgcolor":"&usr.obox-bodybg;",
		     "evenbgcolor":"&usr.fade1;",
		  ])
		  ) +
      "<p><cf-ok/></p>";
}
#endif /* THREADS */
