#include <config_interface.h>
inherit "roxenlib";

constant tablist = #"<tablist preparse ::=&usr.toptabs-args;>";

constant selections =
({
  ({ "configiftab",    "home",  "",               0 }),
  ({ "sites",       "sites",  "sites/",           0 }),
  ({ "globals",   "globals",  "global_settings/", 0 }),
  ({ "ports",       "ports",  "ports/",           0 }),
  ({ "eventlog","event_log",  "event_log/",       0 }),
  ({ "actions",   "actions",  "actions/",   "Tasks" }),
  ({ "docs",   "docs",  "docs/",   0 }),
});

string parse( object id )
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
      res += make_container( "tab", a, " &locale."+t[0]+"; " );
    }
  }
  return res+"</tablist>";
}
