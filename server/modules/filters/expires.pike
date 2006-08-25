constant cvs_version = "$Id: expires.pike,v 1.1 2006/08/25 09:26:44 wellhard Exp $";
constant thread_safe = 1;

#include <module.h>
inherit "module";

//<locale-token project="sitebuilder">LOCALE</locale-token>
//<locale-token project="sitebuilder">DLOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("sitebuilder",X,Y)
#define DLOCALE(X,Y)    _DEF_LOCALE("sitebuilder",X,Y)

constant module_type = MODULE_FILTER;
LocaleString module_name = DLOCALE(0,"Expires modifier");
LocaleString module_doc  = DLOCALE(0,
				   "Adds expires header of configurable time "
				   "to selected files.");

array(string) globs;
int expire_time;

void create()
{
  defvar("paths",
	 Variable.StringList(({}), VAR_INITIAL,
			     "Path globs",
			     "List of glob expressions for files that should "
			     "be targeted for modification of the expire "
			     "time. Ex: <tt>/images/navigation/*.gif</tt>"
			     "<br />"
			     "Try to keep this to a minimum in order to "
			     "minimize performance issues and avoid "
			     "overcaching of other files."));
  defvar("expire_time", INITIAL_CACHEABLE,
	 "Expire time", TYPE_INT,
	 "The number of seconds the files should expire in. "
	 "Leaving this to the default value might result in that no 'Expire:' "
	 "header at all is sent to the client and should be used to "
	 "compensate for other modules the has previously lowered the "
	 "expire time.");
}

void start(int when, Configuration conf)
{
  globs = query("paths");
  expire_time = query("expire_time");
}

mapping|void filter(mapping res, RequestID id)
{
  if (!res || !res->extra_heads) return;

  foreach(globs, string g) {
    if (glob(g, id->not_query)) {

#ifdef DEBUG_CACHEABLE
      report_debug("Original extra_heads: %O\n", res->extra_heads);
#endif

      m_delete(res->extra_heads, "cache-control");
      m_delete(res->extra_heads, "Cache-Control");
      m_delete(res->extra_heads, "expires");
      m_delete(res->extra_heads, "Expires");
      RAISE_CACHE(expire_time);

#ifdef DEBUG_CACHEABLE
      report_debug("Rewrote extra_heads: %O\n", res->extra_heads);
#endif

      return res;
    }
  }
}
