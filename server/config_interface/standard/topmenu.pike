#include <config_interface.h>
#include <roxen.h>

//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

constant tablist = "<tablist preparse ::=&usr.toptabs-args;>";

array selections =
({
  ({ LOCALE(212, "Admin"),   "home",      "",                 0 }),
  ({ LOCALE(213, "Sites"),   "sites",     "sites/",           0 }),
  ({ LOCALE(214, "Globals"), "globals",   "global_settings/", 0 }),
  ({ LOCALE(215, "Ports"),   "ports",     "ports/",           0 }),
  ({ LOCALE(216, "Events"),  "event_log", "event_log/",       0 }),
  ({ LOCALE(196, "Tasks"),   "actions",   "actions/",   "Tasks" }),
  ({ LOCALE(217, "Docs"),    "docs",      "docs/",            0 }),
});

string parse( RequestID id )
{
  string res = tablist;
  foreach( selections, array t )
  {
    if(!t[3] || config_perm( t[3] ) )
    {
      mapping a = ([]);
      a->href = id->misc->last_tag_args->base + t[2];
      if( id->misc->last_tag_args->selected == t[1] )
        a->selected = "selected";
      res += Roxen.make_container( "tab", a, " "+t[0]+" " );
    }
  }
  return res+"</tablist>";
}
