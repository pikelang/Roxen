/*
 * $Id: locks.pike,v 1.1 1997/09/14 20:38:45 per Exp $
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
    l += c->locked;
    L += c->thread_safe;
  }
  mapping res=([]);
  string data="<font size=+1>Module lock status</font>";
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
  return data+html_table( ({ "Config", "File", "Locked accesses", "Unlocked" }), rows );
}

mixed handle(object id) { return wizard_for(id,0); }
#endif
