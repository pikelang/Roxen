/*
 * $Id: pike_profiling.pike,v 1.3 2004/05/20 21:06:49 grubba Exp $
 */
#include <stat.h>
#include <roxen.h>
//<locale-token project="admin_tasks">LOCALE</locale-token>
#define LOCALE(X,Y)	_DEF_LOCALE("admin_tasks",X,Y)

constant action = "debug_info";

LocaleString name= LOCALE(0,"Pike profiling information");
LocaleString doc = LOCALE(0,"Show some information about how much time "
			  "has been spent in various functions. "
			  "Mostly useful for developers.");

int creation_date = time();

int no_reload()
{
  return creation_date > file_stat( __FILE__ )[ST_MTIME];
}

#if efun(get_profiling_info)
string remove_cwd(string from)
{
  string s = from-(getcwd()+"/");
  sscanf( s, "%*s/modules/%s", s );
  s = replace( s, ".pmod/", "." );
  s = replace( s, ".pmod", "" );
  s = replace( s, ".pike", "" );
  s = replace( s, ".so", "" );
  s = replace( s, "Luke/", "Luke." );
  return s;
}

array (program) all_modules()
{
  return values(master()->programs);
}

string program_name(program|object what)
{
  string p;
  if(p = master()->program_name(what)) return remove_cwd(p);
  return "?";
}

mapping get_prof()
{
  mapping res = ([]);
  foreach(all_modules(), program prog) {
    res[program_name(prog)] = prog && get_profiling_info( prog );
  }
  return res;
}

array get_prof_info(string|void foo)
{
  array res = ({});
  mapping as_functions = ([]);
  mapping tmp = get_prof();
  foreach(indices(tmp), string c)
  {
    mapping g = tmp[c][1];
    foreach(indices(g), string f)
    {
      if(g[f][2])
      {
        c = replace( c, "base_server/", "roxen." );
        c = (c/"/")[-1];
        string fn = c+"."+f;
        if(  (!foo || !sizeof(foo) || glob(foo,c+"."+f)) )
        {
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
  sort(column(values(as_functions), 2), q);	// Sort after total time.
  foreach(q, string i) if(as_functions[i][0])
    res += ({({i,
	       sprintf("%d",as_functions[i][1]),	// Calls
               sprintf("%8d",				// Time
                       as_functions[i][0]),
               sprintf("%8d",				// +Children
                       as_functions[i][2]),
	       sprintf("%7.3f",				// Average
		       ((float)as_functions[i][0])/as_functions[i][1]),
	       sprintf("%7.3f",				// +Children
                       ((float)as_functions[i][2])/as_functions[i][1])})});
  sort((array(float))column(res,3),res);
  return reverse(res);
}

mixed page_0(object id)
{
  string res = ("All times are in milliseconds, and real-time. Times include "
		"time of child functions. No callgraph is available yet.<br />"
		"Function glob: <input type=text name=subnode value='"+
                Roxen.html_encode_string(id->variables->subnode||"")
                +"'><br />");

  object t = ADT.Table->table(get_prof_info("*"+
                                            (id->variables->subnode||"")+"*"),
			      ({ "Function",
                                 "Calls",
                                 "Time(ms)",
                                 "+chld(ms)",
                                 "t/call(ms)",
				 "+chld(ms)"}));
  return res + "\n\n<pre>"+ADT.Table.ASCII.encode( t )+"</pre>";
}
#endif

mixed parse( RequestID id )
{
  return
    "<font size='+1'><b>"+
    LOCALE(0, "Pike profiling information")+
    "</b></font>"
    "<p />"
#if constant( get_profiling_info )
    "<input type='hidden' name='action' value='pike_profiling.pike' />\n"
    "<p><submit-gbutton name='refresh'> "
    "<translate id='520'>Refresh</translate> "// <cf-refresh> doesn't submit.
    "</submit-gbutton>\n"
    "<cf-cancel href='?class=&form.class;'/></br>\n" +
    page_0( id )
#else
    "<font color='&usr.warncolor;'>This information is only available if the "
    "pike binary has been compiled with <tt>--with-profiling</tt>.</font>"
#endif
    ;
}
