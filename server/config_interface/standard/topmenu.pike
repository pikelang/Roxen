#include <config_interface.h>
inherit "roxenlib";

constant tablist = #"<tablist preparse
	 bgcolor=&usr.toptabs-bgcolor;
	 font=&usr.toptabs-font;
	 dimcolor=&usr.toptabs-dimcolor;
	 textcolor=&usr.toptabs-textcolor;
	 dimtextcolor=&usr.toptabs-dimtextcolor;
	 selcolor=&usr.toptabs-selcolor;>";


constant selections =
({
  ({ "configiftab",    "home",  "",                 0 }),
  ({ "sites",       "sites",  "sites/",           0 }),
  ({ "globals",   "globals",  "global_settings/", 0 }),
  ({ "ports",       "ports",  "ports/",           0 }),
  ({ "eventlog","event_log",  "event_log/",       0 }),
  ({ "actions",   "actions",  "actions/",         "Tasks" }),
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
      res += make_container( "tab", a, " <cf-locale get="+t[0]+"> " );
    }
  }
  return res+"</tablist>";
}
