/*
 * $Id: debug_info.pike,v 1.13 2001/08/28 15:55:35 mast Exp $
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
		"Function glob: <input type=string name=subnode value='"+
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
           ="'&usr.warncolor;'";
      if((foo[f]-last_usage[f]) < foo[f]/60)
	col="'&usr.warncolor;'";
      if((foo[f]-last_usage[f]) == 0)
	col="'&usr.fgcolor;'  ";
      if((foo[f]-last_usage[f]) < 0)
	col="'&usr.fade2;'    ";

      string bn = f[4..sizeof(f)-2]+"_bytes";
      foo->total_bytes += foo[ bn ];
      if( bn == "tota_bytes" )
        bn = "total_bytes";
      table += ({ ({
        "<font color="+col+">"+f[4..], foo[f], foo[f]-last_usage[f],
        sprintf( "%.1f",foo[bn]/1024.0),
        sprintf( "%.1f",(foo[bn]-last_usage[bn])/1024.0 )+"</font>",
      }) });
    }
  roxen->set_var("__memory_usage", foo);


  mapping bar = roxen->query_var( "__num_clones" )||([]);

  object t = ADT.Table->table(table,
                              ({ "<font color='&usr.fgcolor;'  >"+
				 (string)LOCALE(3,"Type"), 
				 (string)LOCALE(4,"Number"),
                                 (string)LOCALE(5,"Change"), 
				 "Kb", (string)LOCALE(5,"Change") + "</font>"}),
                              ({
                                0,
                                ([ "type":"num" ]),
                                ([ "type":"num" ]),
                                ([ "type":"num" ]),
                                ([ "type":"num" ]),
                              }));
  res += "<pre>"+ADT.Table.ASCII.encode( t )+"</pre>";

  mapping(string:array(string)) allobj = ([]);
  int destructed = 0;

  object start = this_object();
  for (object o = start; o; o = _prev (o))
    if (program p = object_program (o))
      allobj[Program.defined (p)] += ({sprintf ("%O", o)});
    else
      destructed++;
  start = _next (start);
  for (object o = start; o; o = _next (o))
    if (program p = object_program (o))
      allobj[Program.defined (p)] += ({sprintf ("%O", o)});
    else
      destructed++;

  table = (array) allobj;

  string cwd = getcwd() + "/";
  for (int i = 0; i < sizeof (table); i++) {
    [string progstr, array(string) objs] = table[i];

    if (sizeof (objs) > 2) {
      if (has_prefix (progstr, cwd))
	progstr = progstr[sizeof (cwd)..];

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

      int change = sizeof (objs) - bar[progstr];
      bar[progstr] = sizeof (objs);

      table[i] = ({progstr, objstr, sizeof (objs), change});
    }
    else table[i] = 0;
  }

  table = Array.sort_array (table - ({0}),
			    lambda (array a, array b) {
			      return a[2] < b[2] || a[2] == b[2] && (
				a[1] < b[1] || a[1] == b[1] && (
				  a[0] < b[0]));
			    });

  constant inc_font  = "<font color='&usr.warncolor;'>";
  constant dec_font  = "<font color='&usr.fade2;'    >";
  constant same_font = "<font color='&usr.fgcolor;'  >";

  foreach (table, array entry) {
    string font;
    if (entry[3] > 0) font = inc_font, entry[3] = "+" + entry[3];
    else if (entry[3] < 0) font = dec_font;
    else font = same_font;
    entry[0] = font + entry[0];
    entry[3] += "</font>";
  }

  roxen->set_var("__num_clones", bar);
  t = ADT.Table->table(table, ({ "<font color='&usr.fgcolor;'  >Source", "Program",  "Clones", "Change</font>"}),
		       ({ 0, 0, ([ "type":"num" ]),([ "type":"num" ])}));
  res += "<pre>"+ADT.Table.ASCII.encode( t ) + "</pre>";

  res += "Number of destructed objects: " + destructed +"<br />\n";

  return res;
}

mixed parse( RequestID id )
{
  return page_0( id )
#if 0
#if constant( get_profiling_info )
         + page_1( id )
#endif
#endif
    + "<p><cf-ok/></p>";
}
