/*
 * $Id: request_profiling.pike,v 1.2 2004/05/19 13:23:30 grubba Exp $
 */
#include <stat.h>
#include <roxen.h>
//<locale-token project="admin_tasks">LOCALE</locale-token>
#define LOCALE(X,Y)	_DEF_LOCALE("admin_tasks",X,Y)

constant action = "debug_info";

LocaleString name= LOCALE(0,"Request profiling information");
LocaleString doc = LOCALE(0,"Show some information about how how much time "
			  "has been spent in requests. "
			  "Mostly useful for developers.");

int creation_date = time();

int no_reload()
{
  return creation_date > file_stat( __FILE__ )[ST_MTIME];
}

mixed page_0(object id)
{
  string res = "";
  foreach(roxen->configurations, Configuration conf) {
    mapping(string:array(int)) prof = conf->profile_map;
    if (sizeof(prof)) {
      array(string) ind = indices(prof);
      array(array(int)) val = values(prof);
      // Make sure we get a nice, deterministic order.
      sort(ind, val);			// Sort after not_query.
      sort(column(val, 0), ind, val);	// Sort after number of requets
      res += "<br />\n"
	"Configuration: "
	"<b>"+Roxen.html_encode_string(conf->name)+"</b><br />\n"
	"<pre>"+
	ADT.Table.ASCII.encode(ADT.Table.table(((ind[*]/"?method=")[*]+val[*])[*]+
					       ((val[*][1][*]/val[*][0][*])/({}))[*],
					       ({ "Path", "Method",
						  "Count", "Total(µs)",
						  "Max(µs)", "Average(µs)"
					       })))+
	"</pre>";
    }
  }
  return res;
}

mixed parse( RequestID id )
{
  string ret =
    "<font size='+1'><b>"+
    LOCALE(0,"Request profiling information")+
    "</b></font><br />\n";
  if (roxen->configurations[0]->profile_map) {
    ret +=
      "All times are in microseconds.<br />\n"
      "<p />"
      "<input type='hidden' name='action' value='request_profiling.pike' />\n"
      "<p><submit-gbutton name='refresh'> "
      "<translate id='520'>Refresh</translate> "// <cf-refresh> doesn't submit.
      "</submit-gbutton>\n"
      "<cf-cancel href='?class=&form.class;'/>\n"
      "<p />\n" +
      page_0( id );
  } else {
    ret +=
      "<p />\n"
      "<font color='&usr.warncolor;'>NOTE: This information is only "
      "available if the "
      "server has been stared with <tt>-DPROFILING</tt>.</font>";
  }
  return ret;
}
