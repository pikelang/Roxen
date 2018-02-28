/*
 * $Id$
 */
#include <stat.h>
#include <roxen.h>
#include <config_interface.h>
//<locale-token project="admin_tasks">LOCALE</locale-token>
#define LOCALE(X,Y)	_DEF_LOCALE("admin_tasks",X,Y)

constant action = "debug_info";

LocaleString name= LOCALE(162,"Pike profiling information");
LocaleString doc = LOCALE(167,"Show some information about how much time "
			  "has been spent in various functions. "
			  "Mostly useful for developers.");

int creation_date = time();

int no_reload()
{
  return creation_date > file_stat( __FILE__ )[ST_MTIME];
}

#if efun(get_profiling_info)
program first_program = this_program;
mapping get_prof()
{
  program prog;
  while (programp(prog = _prev(first_program))) {
    first_program = prog;
  }
  mapping res = ([]);
  for (prog = first_program; programp(prog); prog = _next(prog)) {
    res[master()->describe_module(prog)] = get_profiling_info(prog);
  }
  return res;
}

array get_prof_info(string|void foo)
{
  array res = ({});
  mapping(string:array(int)) as_functions = ([]);
  mapping(string:array(int|mapping(string:array(int)))) tmp = get_prof();
  foreach(indices(tmp), string c)
  {
    mapping(string:array(int)) g = tmp[c][1];
    c = (c/"/")[-1];
    foreach(indices(g), string f)
    {
      if(g[f][2])	// Total time.
      {
        string fn = c+f;
        if( (!foo || !sizeof(foo) || glob(foo, fn)) )
        {
#if 0
          switch( f )
          {
           case "cast":
             fn = "(cast)"+c;
             break;
           case "__INIT":
             fn = c;
             break;
           case "create":
           case "`()":
             fn = c+"()";
             break;
           case "`->":
             fn = c+"->";
             break;
           case "`[]":
             fn = c+"[]";
             break;
          }
#endif /* 0 */
          if( !as_functions[fn] )
            as_functions[fn] = ({ g[f][2],g[f][0],g[f][1] });
          else
          {
            as_functions[fn][0] += g[f][2];
            as_functions[fn][1] += g[f][0];
            as_functions[fn][2] += g[f][1];
          }
        }
      }
    }
  }
  array q = indices(as_functions);
  array b = values(as_functions);
  sort(column(b, 1), b, q);	// Secondary sort after self time.
  sort(column(b, 2), b, q);	// Primary sort after total time.
  for (int i = 0; i < sizeof(q); i++) {
    res += ({({q[i],
	       sprintf("%d",b[i][1]),	// Calls
               sprintf("%8d",				// Time
                       b[i][0]),
               sprintf("%8d",				// +Children
                       b[i][2]),
	       sprintf("%7.3f",				// Average
		       ((float)b[i][0])/b[i][1]),
	       sprintf("%7.3f",				// +Children
                       ((float)b[i][2])/b[i][1])})});
  }
  return reverse(res);
}

mixed page_0(object id)
{
  string tmpl = #"
    <p>All times are in milliseconds, and real-time. Times include
    time of child functions. No callgraph is available yet.<p>
    <p>Function glob: <input type=text name=subnode value='{{subnode}}''></p>

    <table class='mem pike-prof'>
      <thead>
        <tr>
        {{ #header }}
          <th>{{ . }}</th>
        {{ /header }}
        </tr>
      </thead>
      <tbody>
        {{ #data }}
          <tr>
            {{ #row }}
              <td>{{ . }}</td>
            {{ /row }}
          </tr>
        {{ /data }}
      </tbody>
    </table>";

  array rows = map(get_prof_info("*"+(id->variables->subnode||"")+"*"),
    lambda (array row) {
      return ([
        "row" : map(row, lambda (string s) {
          return replace(s, "\0", "");
        })
      ]);
    });

  mapping data = ([
    "header"  : ({ "Function",
                   "Calls",
                   "Time(ms)",
                   "+chld(ms)",
                   "t/call(ms)",
                   "+chld(ms)"}),
    "subnode" : Roxen.html_encode_string(id->variables->subnode||""),
    "data"    : rows
  ]);

  string res = Roxen.render_mustache(tmpl, data);

  return res;
}
#endif

mixed parse( RequestID id )
{
  return
    "<cf-title>"+
    LOCALE(162, "Pike profiling information")+
    "</cf-title>"
#if constant( get_profiling_info )
    "<input type='hidden' name='action' value='pike_profiling.pike' />\n"
    "<submit-gbutton2 name='refresh' type='refresh'>" +
    LOCALE(186,"Refresh") +
    "</submit-gbutton2>\n"
    "<cf-cancel href='?class=&form.class;&amp;&usr.set-wiz-id;'/>\n" +
    page_0( id )
#else
    "<div class='notify error'>" +
    LOCALE(185,"This information is only available if the "
	   "pike binary has been compiled with <tt>--with-profiling</tt>.") +
    "</div>"
    "<cf-ok-button href='?class=&form.class;&amp;&usr.set-wiz-id;'/>";
#endif
    ;
}
