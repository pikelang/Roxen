/*
 * $Id$
 */
#include <stat.h>
#include <roxen.h>
//<locale-token project="admin_tasks">LOCALE</locale-token>
#define LOCALE(X,Y)	_DEF_LOCALE("admin_tasks",X,Y)

constant action = "debug_info";

LocaleString name= LOCALE(181,"Request profiling information");
LocaleString doc = LOCALE(182,"Show some information about how how much time "
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
    if (id->variables->reset) {
      conf->profile_map = ([]);
      continue;
    }
    mapping(string:array(int)) prof = conf->profile_map;
    if (sizeof(prof)) {
      array(string) ind = indices(prof);
      array(array(int)) val = values(prof);
      // Make sure we get a nice, deterministic order.
      sort(ind, val);			// Sort after not_query.
      sort(0-column(val, 0)[*], ind, val);	// Sort after number of requets
      array(array(string)) data = (array(array(string)))
	(((ind[*]/"?method=")[*]+val[*])[*]+((val[*][1][*]/val[*][0][*])/({}))[*]);
      array(int) sizes = allocate(4);
      map(data, lambda(array(string) row) {
		  for(int i=2;i<=5;i++) {
		    row[i] = reverse(reverse((string)row[i])/3.0*".");
		    sizes[i-2] = max(sizes[i-2], sizeof(row[i]));
		  }
		  return row;
		});
      map(data, lambda(array(string) row) {
		  for(int i=2;i<=5;i++)
		    row[i] = sprintf("%:*s", sizes[i-2], row[i]);
		  return row;
		});
      res += "<br />\n"
	"Configuration: "
	"<b>"+Roxen.html_encode_string(conf->name)+"</b><br />\n"
	"<pre>"+
    	ADT.Table.ASCII.encode(ADT.Table.table(data,
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
    "<cf-title>"+
    LOCALE(181,"Request profiling information")+
    "</cf-title><p />\n";
  if (roxen->configurations[0]->profile_map) {
    ret +=
      LOCALE(183,"All times are in microseconds.") + "<br />\n"
      "<p />"
      "<input type='hidden' name='action' value='request_profiling.pike' />\n"
      "<p /><submit-gbutton2 name='refresh' width='75' align='center'>" +
      LOCALE(186, "Refresh") +
      "</submit-gbutton2>\n"
      "<submit-gbutton2 name='reset' width='75' align='center'>" +
      LOCALE(187,"Reset") +
      "</submit-gbutton2>\n"
      "<cf-cancel href='?class=&form.class;&amp;&usr.set-wiz-id;'/>\n"
      "<p />\n" +
      page_0( id );
  } else {
    ret +=
      "<p />\n"
      "<div class='notify error'>" +
      LOCALE(184,"NOTE: This information is only available if the "
	     "server has been stared with <tt>-DPROFILE</tt>.") +
      "</div>"
      "<p />\n"
      "<cf-ok-button href='?class=&form.class;&amp;&usr.set-wiz-id;'/>";
  }
  return ret;
}
