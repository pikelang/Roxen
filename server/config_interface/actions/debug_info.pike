/*
 * $Id: debug_info.pike,v 1.26 2003/01/20 10:36:20 anders Exp $
 */
#include <stat.h>
#include <roxen.h>
//<locale-token project="admin_tasks">LOCALE</locale-token>
#define LOCALE(X,Y)	_DEF_LOCALE("admin_tasks",X,Y)

constant action = "debug_info";

LocaleString name= LOCALE(1,"Pike memory usage information");
LocaleString doc = LOCALE(2,
		    "Show some information about how pike is using the "
		    "memory it has allocated. Mostly useful for developers.");

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
//   sort(values(as_functions), q);
  foreach(q, string i) if(as_functions[i][0])
    res += ({({i,
	       sprintf("%d",as_functions[i][1]),
               sprintf("%5.2f",
                       as_functions[i][0]/1000000.0),
               sprintf("%5.2f",
                       as_functions[i][2]/1000000.0),
	       sprintf("%7.3f",
		       (as_functions[i][0]/1000.0)/as_functions[i][1]),
	       sprintf("%7.3f",
                       (as_functions[i][2]/1000.0)/as_functions[i][1])})});
  sort((array(float))column(res,3),res);
  return reverse(res);
}


mixed page_1(object id)
{
  string res = ("<font size=+1>Profiling information</font><br />"
		"All times are in seconds, and real-time. Times incude"
		" time of child functions. No callgraph is available yet.<br />"
		"Function glob: <input type=text name=subnode value='"+
                Roxen.html_encode_string(id->variables->subnode||"")
                +"'><br />");

  object t = ADT.Table->table(get_prof_info("*"+
                                            (id->variables->subnode||"")+"*"),
			      ({ "Function",
                                 "Calls",
                                 "Time",
                                 "+chld",
                                 "t/call(ms)",
				 "+chld(ms)"}));
  return res + "\n\n<pre>"+ADT.Table.ASCII.encode( t )+"</pre>";
}
#endif


mapping class_cache = ([]);

string fix_cname( string what )
{
  if( what == "`()()" )
    what = "()";
  return what;
}

string find_class( string f, int l )
{
  if( l < 2 )
    return 0;
  if( class_cache[ f+":"+l ] )
      return class_cache[ f+":"+l ];
  string data = Stdio.read_bytes( f );
  if( !data )
    return 0;
  array lines = data/"\n";
  if( sizeof( lines ) < l )
    return 0;
  string cname;
  if( sscanf( lines[l], "%*sclass %[^ \t]", cname ) == 2)
    return class_cache[ f+":"+l ] = fix_cname(cname+"()");
  if( sscanf( lines[l-1], "%*sclass %[^ \t]", cname ) == 2)
    return class_cache[ f+":"+l ] = fix_cname(cname+"()");
  if( sizeof( lines ) <= l+1 )
    return 0;
  if( sscanf( lines[l+1], "%*sclass %[^ \t]", cname ) == 2)
    return class_cache[ f+":"+l ] = fix_cname(cname+"()");
  return 0;
}

mixed page_0( object id )
{
  mapping last_usage;
  last_usage = roxen->query_var("__memory_usage");
  if(!last_usage)
  {
    last_usage = _memory_usage();
    roxen->set_var( "__memory_usage", last_usage );
  }

  mapping(string|program:array) allobj = ([]);
  mapping(string|program:int) numobjs = ([]);

  // Collect data. Disable threads to avoid inconsistencies. Note that
  // in Pike 7.4 and earlier, we can't stop automatic gc calls in here
  // which would mess things up.
  object threads_disabled = _disable_threads();

#if constant (Pike.gc_parameters)
  int orig_enabled = Pike.gc_parameters()->enabled;
  Pike.gc_parameters ((["enabled": 0]));
#endif

  int gc_freed = id->real_variables->do_gc && gc();

  mixed foo = _memory_usage();
  object start = this_object();
  int walked_objects = 0;
  for (object o = start;
       objectp (o) ||		// It's a normal object.
       (intp (o) && o) ||	// It's a bignum object.
       zero_type (o);		// It's a destructed object.
       o = _prev (o)) {
    string|program p = object_program (o);
    p = p ? Program.defined (p) || p : "    ";
    if (++numobjs[p] <= 50) allobj[p] += ({o});
    walked_objects++;
  }
  start = _next (start);
  for (object o = start; objectp (o) || (intp (o) && o) || zero_type (o); o = _next (o)) {
    string|program p = object_program (o);
    p = p ? Program.defined (p) || p : "    ";
    if (++numobjs[p] <= 50) allobj[p] += ({o});
    walked_objects++;
  }
  int num_objs_afterwards = _memory_usage()->num_objects;

#if constant (Pike.gc_parameters)
  Pike.gc_parameters ((["enabled": orig_enabled]));
#endif
  mapping gc_status = _gc_status();
  threads_disabled = 0;

  string res = "<p>";
  if (id->real_variables->do_gc)
    res += sprintf (LOCALE(169, "The garbage collector freed %d of %d things (%f%%).\n"),
		    gc_freed, gc_freed + num_objs_afterwards,
		    (float) gc_freed / (gc_freed + num_objs_afterwards) * 100);
  else
    res += sprintf (LOCALE(170, "%d seconds since last garbage collection.\n"),
		    time() - gc_status->last_gc);
  res += "<br /><input type='checkbox' name='do_gc' value='yes'" +
    (id->real_variables->do_gc ? " checked='checked'" : "") +
    " /> " + LOCALE(171, "Run the garbage collector first.") + "</p>\n";

  string first="";
  foo->total_usage = 0;
  foo->num_total = 0;
  array ind = sort(indices(foo));
  string f;
  int row=0;

  array table = ({});

  foreach(ind, f)
    if(!search(f, "num_"))
    {
      if(f!="num_total")
	foo->num_total += foo[f];

      string col
           ="&usr.warncolor;";
      if((foo[f]-last_usage[f]) < foo[f]/60)
	col="&usr.warncolor;";
      if((foo[f]-last_usage[f]) == 0)
	col="&usr.fgcolor;";
      if((foo[f]-last_usage[f]) < 0)
	col="&usr.fade4;";

      string bn = f[4..sizeof(f)-2]+"_bytes";
      foo->total_bytes += foo[ bn ];
      if( bn == "tota_bytes" )
        bn = "total_bytes";
      table += ({ ({
	col, f[4..], foo[f], foo[f]-last_usage[f],
        sprintf( "%.1f",foo[bn]/1024.0),
        sprintf( "%.1f",(foo[bn]-last_usage[bn])/1024.0 ),
      }) });
    }
  roxen->set_var("__memory_usage", foo);

  mapping bar = roxen->query_var( "__num_clones" )||([]);

#define HCELL(thargs, color, text)					\
  ("<th " + thargs + ">"						\
   "\0240<font color='" + color + "'><b>" + text + "</b></font>\0240"	\
   "</th>")
#define TCELL(tdargs, color, text)					\
  ("<td " + tdargs + ">"						\
   "\0240<font color='" + color + "'>" + text + "</font>\0240"		\
   "</td>")

  res += "<p><table border='0' cellpadding='0'>\n<tr>\n" +
    HCELL ("align='left' ", "&usr.fgcolor;", (string)LOCALE(3,"Type")) +
    HCELL ("align='right'", "&usr.fgcolor;", (string)LOCALE(4,"Number")) +
    HCELL ("align='right'", "&usr.fgcolor;", (string)LOCALE(5,"Change")) +
    HCELL ("align='right'", "&usr.fgcolor;", "Kb") +
    HCELL ("align='right'", "&usr.fgcolor;", (string)LOCALE(5,"Change")) +
    "</tr>\n";
  foreach (table, array entry)
    res += "<tr>" +
      TCELL ("align='left' ", entry[0], entry[1]) +
      TCELL ("align='right'", entry[0], entry[2]) +
      TCELL ("align='right'", entry[0], entry[3]) +
      TCELL ("align='right'", entry[0], entry[4]) +
      TCELL ("align='right'", entry[0], entry[5]) + "</tr>\n";
  res += "</table></p>\n";

  if (walked_objects != foo->num_objects)
    if (num_objs_afterwards != foo->num_objects)
      res += "<p><font color='&usr.warncolor;'>Warning:</font> "
	"Number of objects changed during object walkthrough "
	"(probably due to automatic gc call) - "
	"the list below is not complete.</p>\n";
    else
      res += "<p><font color='&usr.warncolor;'>Warning:</font> "
	"The object walkthrough only visited " + walked_objects +
	" of " + foo->num_objects + " objects - "
	"the list below is not complete.</p>\n";

  foreach (values (allobj), array objs)
    for (int i = 0; i < sizeof (objs); i++)
      objs[i] = zero_type (objs[i]) ?
	"<destructed object>" : sprintf ("%O", objs[i]);

  table = (array) allobj;

  string cwd = getcwd() + "/";
  constant inc_color  = "&usr.warncolor;";
  constant dec_color  = "&usr.fade4;";
  constant same_color = "&usr.fgcolor;";

  for (int i = 0; i < sizeof (table); i++) {
    [string|program prog, array(string) objs] = table[i];

    if (sizeof (objs) > 2) {
      string progstr;
      if (stringp (prog)) {
	if (has_prefix (prog, cwd))
	  progstr = prog[sizeof (cwd)..];
	else
	  progstr = prog;
      }
      else progstr = "";

      string objstr = String.common_prefix (objs)[..30];
      if (!(<"", "object">)[objstr]) {
	int next = 0;
	sscanf (objstr, "%*[^]`'\")}({[]%c", next);
	if (sizeof (objstr) < max (@map (objs, sizeof))) objstr += "...";
	if (int c = (['(': ')', '[': ']', '{': '}'])[next])
	  if (objstr[-1] != c)
	    objstr += (string) ({c});
      }
      else objstr = "";

      int|string change;
      string color;
      if (zero_type (bar[prog])) {
	change = "N/A";
	color = same_color;
      }
      else {
	change = numobjs[prog] - bar[prog];
	if (change > 0) color = inc_color, change = "+" + change;
	else if (change < 0) color = dec_color;
	else color = same_color;
      }
      bar[prog] = numobjs[prog];

      table[i] = ({color, progstr, objstr, numobjs[prog], change});
    }
    else table[i] = 0;
  }

  table = Array.sort_array (table - ({0}),
			    lambda (array a, array b) {
			      return a[3] < b[3] || a[3] == b[3] && (
				a[2] < b[2] || a[2] == b[2] && (
				  a[1] < b[1]));
			    });

  roxen->set_var("__num_clones", bar);

  res += "<p><table border='0' cellpadding='0'>\n<tr>\n" +
    HCELL ("align='left' ", "&usr.fgcolor;", (string)LOCALE(141,"Source")) +
    HCELL ("align='left' ", "&usr.fgcolor;", (string)LOCALE(142,"Program")) +
    HCELL ("align='right'", "&usr.fgcolor;", (string)LOCALE(143,"Clones")) +
    HCELL ("align='right'", "&usr.fgcolor;", (string)LOCALE(5,"Change")) +
    "</tr>\n";
  string trim_path( string what )
  {
    sscanf( what, "%*s/lib/modules/%s", what );
    return what;
  };

  foreach (table, array entry)
    res += "<tr>" +
      TCELL ("align='left' ", entry[0],
	     replace (Roxen.html_encode_string (trim_path(entry[1])), " ", "\0240")) +
      TCELL ("align='left' ", entry[0],
	     replace (Roxen.html_encode_string (entry[2]), " ", "\0240")) +
      TCELL ("align='right'", entry[0], entry[3]) +
      TCELL ("align='right'", entry[0], entry[4]) + "</tr>\n";
  res += "</table></p>\n";

  if (gc_status->non_gc_time)
    gc_status->gc_time_ratio = (float) gc_status->gc_time / gc_status->non_gc_time;

  res += "<p><b>" + LOCALE(172,"Status from last garbage collection") + "</b><br />\n"
    "<table border='0' cellpadding='0'>\n";
  foreach (sort (indices (gc_status)), string field)
    res += "<tr>" +
      TCELL ("align='left'", "&usr.fgcolor;",
	     Roxen.html_encode_string (field)) +
      TCELL ("align='left'", "&usr.fgcolor;",
	     Roxen.html_encode_string (gc_status[field])) +
      "</tr>\n";
  res += "</table></p>\n";

  return res;
}

mixed parse( RequestID id )
{
  return
    "<input type='hidden' name='action' value='debug_info.pike' />\n"
    "<p><submit-gbutton name='refresh'> "
    "<translate id='520'>Refresh</translate> "// <cf-refresh> doesn't submit.
    "</submit-gbutton>\n"
    "<cf-cancel href='?class=&form.class;'/>\n" +
    page_0( id )
#if 0
#if constant( get_profiling_info )
         + page_1( id )
#endif
#endif
    ;
}
