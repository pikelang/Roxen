/*
 * $Id: debug_info.pike,v 1.6 1999/11/24 19:12:33 per Exp $
 */
inherit "roxenlib";
#include <stat.h>

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
  if(p = search(master()->programs,what)) return remove_cwd(p);
  return "?";
}

mapping get_prof(string|void foo)
{
  mapping res = ([]);
  foreach(all_modules(), program prog)
    res[program_name(prog)] = get_profiling_info( prog );
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
      if(!foo || !sizeof(foo) || glob(foo,c+"."+f))
      {
        string fn = c+"."+f;
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
        as_functions[fn] = ({ g[f][2],g[f][0],g[f][1] });
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
  return "";
  string res = ("<font size=+1>Profiling information</font><br>"
		"All times are in seconds, and real-time. Times incude"
		" time of child functions. No callgraph is available yet.<br>"
		"Function glob: <input type=string name=subnode value='"+
                html_encode_string(id->variables->subnode||"")
                +"'><br>");

  object t = ADT.Table->table(get_prof_info("*"+
                                            (id->variables->subnode||"")+"*"),
			      ({ "Function", 
                                 "Calls", 
                                 "Time", 
                                 "+chld",
                                 "t/call(ms)",
				 "+chld(ms)"}));
  return res + "\n\n<pre><font size=-20>"+ADT.Table.ASCII.encode( t )+"</font></pre>";
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
           ="darkred  ";
      if((foo[f]-last_usage[f]) < foo[f]/60)
	col="brown    ";
      if((foo[f]-last_usage[f]) == 0)
	col="black    ";
      if((foo[f]-last_usage[f]) < 0)
	col="darkgreen";
      
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
                              ({ "<font color=black    >Type", "Number", 
                                 "Change", "KB", "Change</font>"}),
                              ({
                                0, 
                                ([ "type":"num" ]),
                                ([ "type":"num" ]),
                                ([ "type":"num" ]),
                                ([ "type":"num" ]),
                              }));
  res += "<pre>"+ADT.Table.ASCII.encode( t )+"</pre>";

#if efun(_dump_obj_table)
  array table = ({
  });

  foo = _dump_obj_table();
  mapping allobj = ([]);
  string a = getcwd(), s;
  if(a[-1] != '/')
    a += "/";
  int i;
  for(i = 0; i < sizeof(foo); i++) 
  {
    string s = foo[i][0];
    if(!stringp(s))
      continue;
    allobj[s]++;
  }

  foreach(Array.sort_array(indices(allobj),lambda(string a, string b ) {
    return allobj[a] < allobj[b];
  }), s) 
    if((search(s, "Destructed?") == -1) && allobj[s]>2)
    {
      string n = s-a;
      if( sscanf( n, "%*ssrc/%s.c", n ) )
        continue;

      string f = (n/":")[0];
      int line = (int)(n/":"+({"0"}))[1];
      switch( f )
      {
       case "protocols/http.pike":
         f = "RequestID(http)";
         line=0;
         break;
       case "protocols/ftp.pike":
         f = "RequestID(ftp)";
         line=0;
         break;
       case "protocols/gopher.pike":
         f = "RequestID(gopher)";
         line=0;
         break;
       case "base_server/module_support.pike":
         f = "roxen."+find_class( f, line );
         line=0;
         break;
       case "base_server/rxml.pike":
         switch( line )
         {
          case 0..200:
            f = "rxml.Parser()";
            line=0;
            break;
         }
         if( !line )
           break;
         /* intentional */
       default:
         string fn = f - "/module.pmod";
         string n = (reverse((reverse( fn ) / "/") [0])/".")[0];
         string q = find_class( f, line );
         if( q )
           f = n+"."+q;
         else
           f = n+":"+line+"()";
         f = replace( f, ".()", "()");
         line=0;
         break;
      }
      
      string col = "darkred  ";

      if( bar[ s ] > allobj[s] )
	col="darkgreen";
      else if( bar[ s ] == allobj[s] )
	col="black    ";
      
      string color = "<font color="+col+">";
      string nocolor = "</font>";

      if( line )
        table += 
          ({
            ({ color+f+":"+line, allobj[s], 
               (allobj[ s ]-bar[ s ])+nocolor }),
          });
      else
        table += 
        ({
          ({ color+f, allobj[s], (allobj[ s ]-bar[ s ])+nocolor }),
        });
      bar[ s ] = allobj[ s ];
    }

  roxen->set_var("__num_clones", bar);
  object t = ADT.Table->table(table, ({ "<font color=black    >File",  "Clones", "Change</font>"}),
                              ({ 0, ([ "type":"num" ]),([ "type":"num" ])}));
  res += "<pre>"+ADT.Table.ASCII.encode( t ) + "</pre>";
  
#endif

#if efun(_num_objects)
  res += ("Number of destructed objects: " + _num_dest_objects() +"<br>\n");
#endif  

  return res +"</ul>";
}

mixed parse(object id) 
{ 
  return page_0( id, id->conf ) 
#if constant( get_profiling_info )
         + page_1( id, id->conf )
#endif
         ;
}
