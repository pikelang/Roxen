/*
 * $Id: debug_info.pike,v 1.26 2004/05/20 21:45:20 _cvs_stephen Exp $
 */
#include <stat.h>

constant task = "debug_info";
constant name = "Pike memory usage information";
constant doc  = ("Show some information about how pike is using the "
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
  gc();
  last_usage = roxen->query_var("__memory_usage");
  if(!last_usage)
  {
    last_usage = _memory_usage();
    roxen->set_var( "__memory_usage", last_usage );
  }

  string res="";
  string first="";
  mixed foo = _memory_usage();
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
   "&nbsp;<font color='" + color + "'><b>" + text + "</b></font>&nbsp;"	\
   "</th>")
#define TCELL(tdargs, color, text)					\
  ("<td " + tdargs + ">"						\
   "&nbsp;<font color='" + color + "'>" + text + "</font>&nbsp;"	\
   "</td>")

  res += "<p><table border='0' cellpadding='0'>\n<tr>\n" +
    HCELL ("align='left' ", "&usr.fgcolor;", "Type") +
    HCELL ("align='right'", "&usr.fgcolor;", "Number") +
    HCELL ("align='right'", "&usr.fgcolor;", "Change") +
    HCELL ("align='right'", "&usr.fgcolor;", "Kb") +
    HCELL ("align='right'", "&usr.fgcolor;", "Change") +
    "</tr>\n";
  foreach (table, array entry)
    res += "<tr>" +
      TCELL ("align='left' ", entry[0], entry[1]) +
      TCELL ("align='right'", entry[0], entry[2]) +
      TCELL ("align='right'", entry[0], entry[3]) +
      TCELL ("align='right'", entry[0], entry[4]) +
      TCELL ("align='right'", entry[0], entry[5]) + "</tr>\n";
  res += "</table></p>\n";

  mapping(string|program:array) allobj = ([]);
  mapping(string|program:int) numobjs = ([]);

  // Go through all objects. Disable threads to avoid changes in the
  // object linked list. Note that a gc call in here will mess things
  // up, and we can't protect against that. It's however unlikely
  // since it's done explicitly above.
  object threads_disabled = _disable_threads();
  object start = this_object();
  for (object o = start;
       objectp (o) ||		// It's a normal object.
       (intp (o) && o) ||	// It's a bignum object.
       zero_type (o);		// It's a destructed object.
       o = _prev (o))
    if (string|program p = object_program (o)) {
      p = Program.defined (p) || p;
      if (++numobjs[p] <= 50) allobj[p] += ({o});
    }
  start = _next (start);
  for (object o = start; objectp (o) || (intp (o) && o) || zero_type (o); o = _next (o))
    if (string|program p = object_program (o)) {
      p = Program.defined (p) || p;
      if (++numobjs[p] <= 50) allobj[p] += ({o});
    }
  threads_disabled = 0;

  foreach (values (allobj), array objs)
    for (int i = 0; i < sizeof (objs); i++)
      objs[i] = sprintf ("%O", objs[i]);

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
    HCELL ("align='left' ", "&usr.fgcolor;", "Source") +
    HCELL ("align='left' ", "&usr.fgcolor;", "Program") +
    HCELL ("align='right'", "&usr.fgcolor;", "Clones") +
    HCELL ("align='right'", "&usr.fgcolor;", "Change") +
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

#if efun(_num_dest_objects)
  res += ("Number of destructed objects: " + _num_dest_objects() +"<br />\n");
#endif

  return res;
}

mixed parse( RequestID id )
{
  return "<p><cf-refresh/></p>\n" +
    page_0( id )
#if 0
#if constant( get_profiling_info )
         + page_1( id )
#endif
#endif
    + "<p><cf-ok/></p>";
}
