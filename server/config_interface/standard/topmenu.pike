#include <config_interface.h>
#include <roxen.h>

//<locale-token project="config_interface">LOCALE</locale-token>
USE_DEFERRED_LOCALE;
#define LOCALE(X,Y)	_DEF_LOCALE("config_interface",X,Y)

constant tablist = "<tablist preparse ::=&usr.toptabs-args;>";

array selections =
({
  ({ LOCALE("cC", "Admin"),   "home",      "",                 0 }),
  ({ LOCALE("cD", "Sites"),   "sites",     "sites/",           0 }),
  ({ LOCALE("cE", "Globals"), "globals",   "global_settings/", 0 }),
  ({ LOCALE("cF", "Ports"),   "ports",     "ports/",           0 }),
  ({ LOCALE("cG", "Events"),  "event_log", "event_log/",       0 }),
  ({ LOCALE("cH", "Tasks"),   "actions",   "actions/",   "Tasks" }),
  ({ LOCALE("cI", "Docs"),    "docs",      "docs/",            0 }),
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
