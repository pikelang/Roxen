/*
 * $Id: relayfilter.pike,v 1.2 1998/09/27 12:53:42 grubba Exp $
 *
 * Support for RBL (Real-time Blackhole List).
 *
 * Henrik Grubbström 1998-09-17
 */

#include <module.h>
inherit "module";

constant cvs_version="$Id: relayfilter.pike,v 1.2 1998/09/27 12:53:42 grubba Exp $";
constant thread_safe=1;

#define RELAYFILTER_DEBUG

/*
 * Programs
 */

class Checker
{
  static string query_variable;
  static object parent;

  static mapping(string:array(int)) cache = ([]);

  // Statistics
  static int queries;
  static int hits;
  static int misses;

  static string old_rules;
  static array(array(function|int)) compiled_rules;

  static class mkglob
  {
    static string pattern;

    int `()(string n)
    {
      return(glob(pattern, n));
    }

    void create(string g)
    {
      pattern = g;
    }
  }

  static void compile_rules(string rules)
  {
    array(string) lines = replace(rules, "\r", "\n")/"\n";

    // Remove comments.
    lines = Array.map(lines, lambda(string l) {
			       return((l/"#")[0]);
			     });

    array new_rules = ({});

    foreach(lines, string line) {
      // Remove initial white space.
      int level;
      if (sscanf(line, "%*[ \t]%d%*[ \t]%s", level, line) == 4) {
	foreach(replace(line, ({ " ", "\t" }), ({ "", "" }))/",", string n) {
	  if (sizeof(n)) {
	    if (n == replace(n, ({ "*", "?" }), ({ "", "" }))) {
	      // Verbatim match.
	      new_rules += ({ ({ n, level }) });
	    } else {
	      // Glob pattern
	      new_rules += ({ ({ mkglob(n), level }) });
	    }
	  }
	}
      }
    }
    compiled_rules = new_rules;
    old_rules = rules;
  }

  int check(string ... names)
  {
#ifdef RELAYFILTER_DEBUG
    roxen_perror(sprintf("RELAYFILTER: check(%O)\n", names));
#endif /* RELAYFILTER_DEBUG */
    queries++;

    string current_rules = parent->query(query_variable);
    if (current_rules != old_rules) {
      compile_rules(current_rules);
      cache = ([]);
    }

    foreach(names, string name) {
      array a = cache[name];
      if (a) {
	// Cached
	hits++;
#ifdef RELAYFILTER_DEBUG
	roxen_perror(sprintf("RELAYFILTER: cache-hit: %O -> %d\n",
			     name, a[1]));
#endif /* RELAYFILTER_DEBUG */
	return(a[1]);
      }
    }

    if (sizeof(cache) > parent->query("cache_size")) {
      // Invalidate the cache
      cache = ([]);
    }

    misses++;

    foreach(names, string name) {
      foreach(compiled_rules, array(function|int) rule) {
	if (stringp(rule[0])) {
	  if (rule[0] == name) {
	  // Verbatim match.
#ifdef RELAYFILTER_DEBUG
	    roxen_perror(sprintf("RELAYFILTER: verbatim: %O => %d\n",
				 name, rule[1]));
#endif /* RELAYFILTER_DEBUG */
	    return((cache[name] = ({ time(1)+60*60, rule[1] }))[1]);
	  }
	} else if (rule[0](name)) {
#ifdef RELAYFILTER_DEBUG
	  roxen_perror(sprintf("RELAYFILTER: glob: %O => %d\n",
			       name, rule[1]));
#endif /* RELAYFILTER_DEBUG */
	  return((cache[name] = ({ time(1)+60*60, rule[1] }))[1]);
	}
      }
    }
#ifdef RELAYFILTER_DEBUG
    roxen_perror(sprintf("RELAYFILTER: default\n"));
#endif /* RELAYFILTER_DEBUG */
    return(parent->query(query_variable + "_default"));
  }

  string status()
  {
    return(sprintf("Cache size: %d\n"
		   "Queries: %d\n"
		   "Hits: %d (%d%%)\n"
		   "Misses: %d (%d%%)\n",
		   sizeof(cache),
		   queries,
		   hits, ((hits * 100)/queries),
		   misses, ((misses * 100)/queries)));
  }

  void create(string qv, object p)
  {
    query_variable = qv;
    parent = p;
  }
}

/*
 * Globals
 */

static object con_checker;
static object addr_checker;

/*
 * Module interface functions
 */

array register_module()
{
  return({ MODULE_PROVIDER,
	   "SMTP relay filter",
	   "Filters the hosts that are allowed to do relaying "
	   "via this SMTP server.",
	   0, 1
  });
}

array(string)|multiset(string)|string query_provides()
{
  return(< "smtp_filter" >);
}

void create()
{
  defvar("cache_size", 1024, "Maximum cache size", TYPE_INT | VAR_MORE,
	 "Maximum size the caches may have before they are cleared.");
  
  defvar("connection_patterns", "", "Connection filter",
	 TYPE_TEXT_FIELD,
	 "Syntax:<br><blockquote><pre>"
	 "# Allow relaying from our local machines, and our friends.\n"
	 "100\t*.local.domain, *.friend.com\n"
	 "</pre></blockquote><br>\n"
	 "Rules are checked from top to bottom, left to right.<br>"
	 "Note that IP address is matched against first, "
	 "and then the resolved address (if any).");

  defvar("connection_patterns_default", 100, "Default connection level",
	 TYPE_INT | VAR_MORE,
	 "The default connection trust level.");

  defvar("recipient_patterns", "", "Recipient filter",
	 TYPE_TEXT_FIELD,
	 "Syntax:<br><blockquote><pre>"
	 "# Allow relaying to our friends domain since we are\n"
	 "# fallback MX for them\n"
	 "0\tlocal.domain, *.local.domain, friend.com, *.friend.com\n"
	 "# Don't allow relaying to enemy.com\n"
	 "200\tenemy.com, *.enemy.com\n"
	 "</pre></blockquote><br>\n"
	 "Rules are checked from top to bottom, left to right.");

  defvar("recipient_patterns_default", 100, "Default relay policy",
	 TYPE_INT | VAR_MORE,
	 "The default relay trust level.");
}

void start(int i, object c)
{
  con_checker = Checker("connection_patterns", this_object());
  addr_checker = Checker("recipient_patterns", this_object());
}

void stop()
{
  con_checker = 0;
  addr_checker = 0;
}

string status()
{
  return(sprintf("<b>Connection filter</b><br>\n"
		 "%s<br>\n"
		 "<b>Recipient filter</b><br>\n"
		 "%s<br>\n",
		 replace(con_checker->status(), "\n", "<br>\n"),
		 replace(addr_checker->status(), "\n", "<br>\n")));
}

/*
 * Callback functions
 */

/*
 * smtp_filter interface functions:
 */

int classify_address(string user, string domain)
{
  if (!addr_checker) {
    return(0);		// Paranoia
  }
  if (domain[-1] == '.') {
    domain = domain[..sizeof(domain)-2];
  }
  return(addr_checker->check(domain));
}

int classify_connection(string remoteip, int remoteport, string remotehost)
{
  if (!con_checker) {
    return(0);		// Paranoia
  }
  if (remotehost[-1] == '.') {
    // Not likely, but...
    remotehost = remotehost[..sizeof(remotehost)-2];
  }
  return(con_checker->check(remoteip, remotehost));
}
