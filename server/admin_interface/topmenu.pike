#include <admin_interface.h>

array selections =
({
  ({ "Home",    "hype",      ".",               0 }),
  ({ "Admin",   "home",      "settings.html",   0 }),
  ({ "Sites",   "sites",     "sites/",          "View Settings"}),
  ({ "Globals", "globals",   "global_settings/","View Settings"}),
//({ "Ports",   "ports",     "ports/",          "View Settings"}),
//({ "Events",  "event_log", "event_log/",      "View Settings"}),
  ({ "Tasks",   "tasks",     "tasks/",          "Tasks" }),
  ({ "DBs",     "dbs",       "dbs/",            "View Settings"}),
//({ "Docs",    "docs",      "docs/",           0 }),
});

// Reloading this program zaps the last-visited info, which is rather
// irritating. Thus, when it's changed the server has to be restarted
// instead. Since this file changes on average once every month or so,
// that's not too much of a problem.
int no_reload() { return 1; }


mapping last_seen_on = ([]);

string parse( RequestID id )
{
  string res = "<tablist "+config_setting2("toptabs-args")+">";
  foreach( selections, array t )
  {
    if(!t[3] || config_perm( t[3] ) )
    {
      mapping a = ([]);
      string default_href()
      {
        if( id->misc->last_tag_args->base )
          a->href = id->misc->last_tag_args->base + t[2];
        else
          a->href = "/"+t[2];
      };
      if( last_seen_on[ t[1] ] )
        a->href = last_seen_on[ t[1] ];
      if( id->misc->last_tag_args->selected == t[1] )
      {
        while( id->misc->orig )
          id = id->misc->orig;
        a->selected = "selected";
	if( id->method == "GET" )
	  last_seen_on[t[1]] = id->raw_url;
        default_href();
      }
      if( !a->href )
        default_href();
      res += Roxen.make_container( "tab", a, t[0] );
    }
  }
  return res+"</tablist>";
}
