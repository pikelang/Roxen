constant cvs_version = "$Id$";
constant thread_safe = 1;

#include <module.h>
inherit "module";

constant module_type = MODULE_FILTER;
constant module_name = "Expires modifier";
constant module_doc  = "Adds expires header of configurable time "
			   "to selected files.";
constant module_unique = 0; 

array(string) globs;
int expire_time;

void create()
{
  defvar("paths",
	 Variable.StringList(({}), VAR_INITIAL,
			     "Path globs", #"\
<p>List of glob expressions for files that should be targeted for
modification of the expire time, e.g.
<tt>/images/navigation/*.gif</tt>. The glob chars '?' and '*' match
any character, including '/'.</p>

<p>Try to keep this to a minimum in order to minimize performance
issues and avoid overcaching of other files.</p>"));

  defvar("expire_time", INITIAL_CACHEABLE,
	 "Expire time", TYPE_INT,
	 "The number of seconds the files should expire in. "
	 "Leaving this to the default value might result in that no 'Expire:' "
	 "header at all is sent to the client and should be used to "
	 "compensate for other modules that has previously lowered the "
	 "expire time.");
}

void start(int when, Configuration conf)
{
  globs = query("paths");
  expire_time = query("expire_time");
}

mapping|void filter(mapping res, RequestID id)
{
  if (!res) return;

  foreach(globs, string g) {
    if (glob(g, id->not_query)) {

#ifdef DEBUG_CACHEABLE
      report_debug("Original extra_heads: %O\n", res->extra_heads);
#endif
      
      if (res->extra_heads) {
	m_delete(res->extra_heads, "cache-control");
	m_delete(res->extra_heads, "Cache-Control");
	m_delete(res->extra_heads, "expires");
	m_delete(res->extra_heads, "Expires");
      }
      
      RAISE_CACHE(expire_time);

      id->misc->vary = (<>);

#ifdef DEBUG_CACHEABLE
      report_debug("Rewrote extra_heads: %O\n", res->extra_heads);
#endif

      return res;
    }
  }
}
