/*
 * $Id$
 */
#include <config_interface.h>
#include <stat.h>
#include <roxen.h>
//<locale-token project="admin_tasks">LOCALE</locale-token>
#define LOCALE(X,Y)     _DEF_LOCALE("admin_tasks",X,Y)

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

  string tmpl = #"
  <h2 class='section'>{{ name }}</h2>
  <table class='nice'>
    <thead>
      <tr>
        <th>Path</th>
        <th>Method</th>
        <th class='num'>Count</th>
        <th class='num'>Total(µs)</th>
        <th class='num'>Max(µs)</th>
        <th class='num'>Average(µs)</th>
      </tr>
    </thead>
    <tbody>
    {{ #data }}
      <tr>
        <td>{{ path }}</td>
        <td>{{ method }}</td>
        <td class='num'>{{ count }}</td>
        <td class='num'>{{ total }}</td>
        <td class='num'>{{ max }}</td>
        <td class='num'>{{ avg }}</td>
      </tr>
    {{ /data }}
    </tbody>
  </table>";

  Mustache stache = Mustache();
  stache->parse(tmpl);

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
      sort(ind, val);                   // Sort after not_query.
      sort(0-column(val, 0)[*], ind, val);      // Sort after number of requets
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

      mapping mctx = ([
        "name" : conf->name,
        "data" : map(data, lambda (array x) {
          return ([
            "path"   : x[0],
            "method" : x[1],
            "count"  : (string)x[2],
            "total"  : (string)x[3],
            "max"    : (string)x[4],
            "avg"    : (string)x[5],
          ]);
        })
      ]);

      res += stache->render(tmpl, mctx);
    }
  }

  destruct(stache);

  return res;
}

mixed parse( RequestID id )
{
  string ret =
    "<cf-title>"+
    LOCALE(181,"Request profiling information")+
    "</cf-title><p />\n";
  if (roxen->configurations[0]->profile_map) {
    ret += "<p>" +
      LOCALE(183,"All times are in microseconds.") + "\n"
      "</p>"
      "<input type='hidden' name='action' value='request_profiling.pike' />\n"
      "<p /><submit-gbutton2 name='refresh' type='refresh'>" +
      LOCALE(186, "Refresh") +
      "</submit-gbutton2>\n"
      "<submit-gbutton2 name='reset' type='reset'>" +
      LOCALE(187,"Reset") +
      "</submit-gbutton2>\n"
      "<cf-cancel href='?class=&form.class;&amp;&usr.set-wiz-id;'/>\n" +
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
