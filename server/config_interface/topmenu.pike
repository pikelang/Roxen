#include <config_interface.h>
#include <roxen.h>

//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_DEF_LOCALE("roxen_config",X,Y)

#define  tablist ("<xtablist topmenu='1'>")

array selections =
({
  ({ LOCALE(360, "Home"),    "hype",      ".",                0 }),
  ({ LOCALE(212, "Admin"),   "home",      "settings.html",   0 }),
  ({ LOCALE(213, "Sites"),   "sites",     "sites/",          "View Settings"}),
  ({ LOCALE(214, "Globals"), "globals",   "global_settings/","View Settings"}),
//({ LOCALE(215, "Ports"),   "ports",     "ports/",          "View Settings"}),
//({ LOCALE(216, "Events"),  "event_log", "event_log/",      "View Settings"}),
  ({ LOCALE(196, "Tasks"),   "actions",   "actions/",        "Tasks" }),
  ({ LOCALE(218, "DBs"),     "dbs",       "dbs/",            "View Settings"}),
  ({ LOCALE(217, "Docs"),    "docs",      "docs/",           0 }),
});

// Reloading this program zaps the last-visited info, which is rather
// irritating. Thus, when it's changed the server has to be restarted
// instead. Since this file changes on average once every month or so,
// that's not too much of a problem.
int no_reload() { return 1; }

mapping last_seen_on = ([]);

//  Some page visits have undesired side-effects so we list some
//  exceptions here.
mapping(Regexp:string) suppress_last_seen = ([
  Regexp("/actions/(index\.html|)?action=(.*)&") : "/actions/?",
  Regexp("/dbs/create_(.*)")                     : "/dbs/",
  Regexp("/dbs/browser.pike(.*)action=(.*)")     : "/dbs/"
]);

string parse( RequestID id )
{
  string res = tablist;
  foreach( selections, array t )
  {
    if(t[3] && !config_perm( t[3] ) ) {
      if (!id->misc->config_user || (t[1] != "sites")) continue;
      // Allow access to the sites tab even without "View Settings"
      // if there are permissions for any site.
      int access_ok;
      foreach(id->misc->config_user->permissions; string perm;) {
	if (has_prefix(perm, "Site:")) {
	  access_ok = 1;
	  break;
	}
      }
      if (!access_ok) continue;
    }
    if (t[1] == "docs") {
      // Hide the docs tab if there are no docs.
      Sql.Sql docs = DBManager.get("docs", id->conf);
      if (!docs || !sizeof(docs->query("SHOW TABLES LIKE 'docs'"))) {
	continue;
      }
      docs = UNDEFINED;
    }

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
	if( id->method == "GET" ) {
	  string url = id->raw_url;
	  foreach(suppress_last_seen; Regexp pattern; string replacement) {
	    if (pattern->match(url)) {
	      url = pattern->replace(url, replacement);
	      break;
	    }
	  }
	  last_seen_on[t[1]] = url;
	}
        default_href();
      }
      if( !a->href )
        default_href();
      res += Roxen.make_container( "a", a, t[0] );
    }
  }
  return res+"</xtablist>";
}
