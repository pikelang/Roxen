/*
 * $Id: locks.pike,v 1.3 1997/09/16 01:03:54 grubba Exp $
 */
#include <config.h>

#ifdef THREADS
inherit "wizard";
constant name= "Status//Thread status";
constant doc = ("Shows various information about the threads in roxen.");
constant more=1;

string describe_module(object q)
{
  foreach(roxen->configurations, object c)
  {
    foreach(indices(c->modules), string m)
    {
	int w;
	mapping mod = c->modules[m];
	if(mod->enabled == q)
	  return c->name+"/"+m+"</td><td>"+roxen->filename(q);
	else if(mod->copies &&
		!zero_type(((mod=mkmapping(values(mod->copies),
					   indices(mod->copies)))[q])))
	  return c->name+"/"+m+"#"+mod[q]+"</td><td>"+roxen->filename(q);
    }
  }
  return "Unknown module</td><td>"+roxen->filename(q)+"";
}

mixed page_0(object id, object mc)
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
  string data=("<font size=+2>Module lock status</font><p>Accesses to all modules, "
	       "Locked means that the access was done using a serializing lock since "
	       "the module was not thread-safe, unlocked means that there was no need "
	       "for a lock.<p>Locked accesses to a single module can be a "
	       "quite severe performance degradation of the whole server");
  array mods = (indices(L)+indices(l));
  mods &= mods;
  foreach(mods, object q)
  {
    res[describe_module(q)]+=l[q];
    locks[describe_module(q)]+=L[q];
  }
  array rows = ({});
  foreach(sort(indices(res)), string q)
    rows += ({ ({q,(string)res[q],(string)locks[q] }) });
  return data+html_table( ({ "Config", "File", "Locked", "Unlocked" }), rows );
}

mixed handle(object id) { return wizard_for(id,0); }
#endif
