#include <config_interface.h>
#include <roxen.h>
LOCALE_PROJECT(config_interface);
#define LOCALE(X,Y)	_DEF_LOCALE(X,Y)

constant tablist = "<tablist preparse ::=&usr.toptabs-args;>";

array selections =
({
  ({ LOCALE("", "Admin"),   "home",      "",                 0 }),
  ({ LOCALE("", "Sites"),   "sites",     "sites/",           0 }),
  ({ LOCALE("", "Globals"), "globals",   "global_settings/", 0 }),
  ({ LOCALE("", "Ports"),   "ports",     "ports/",           0 }),
  ({ LOCALE("", "Events"),  "event_log", "event_log/",       0 }),
  ({ LOCALE("", "Tasks"),   "actions",   "actions/",   "Tasks" }),
  ({ LOCALE("", "Docs"),    "docs",      "docs/",            0 }),
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
