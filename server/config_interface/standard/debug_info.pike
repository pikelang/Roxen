/*
 * $Id: debug_info.pike,v 1.3 1999/11/17 15:13:32 per Exp $
 */

// inherit "wizard";
// inherit "configlocale";
inherit "roxenlib";

mapping last_usage;

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
  return res;// + "\n\n<pre><font size=-20>"+ADT.Table.ASCII.encode( t )+"</font></pre>";
}
#endif


int wizard_done()
{ 
  return -1;
}

mixed page_0( object id )
{
  if(!last_usage) last_usage = roxen->query_var("__memory_usage");
  if(!last_usage) last_usage = ([]); 

  string res="";
  string first="";
  mixed foo = _memory_usage();
  foo->total_usage = 0;
  foo->num_total = 0;
  array ind = sort(indices(foo));
  string f;
  res+=("<table width=100% cellpadding=0 cellspacing=0 border=0>"
	"<tr valign=top><td valign=top>");
  res+=("<table border=0 width=100% cellspacing=0 cellpadding=2>"
	"<tr bgcolor=#d9dee7><td>&nbsp;</td>"
	"<th colspan=2><b>number of</b></th></tr>"
	"<tr bgcolor=#d9dee7><th align=left>Entry</th><th align"
	"=right>Current</th><th align=right>Change</th></tr>");
  int row=0;
  foreach(ind, f)
    if(!search(f, "num_"))
    {
      string bg="white";
      if( row++ % 2 )
        bg = "#eeeeee";
      if(f!="num_total")
	foo->num_total += foo[f];
      else
	bg="#d9dee7";
      string col="darkred";
      if((foo[f]-last_usage[f]) < foo[f]/60)
	col="brown";
      if((foo[f]-last_usage[f]) == 0)
	col="black";
      if((foo[f]-last_usage[f]) < 0)
	col="darkgreen";
      
      res += "<tr bgcolor="+bg+"><td><b><font color="+col+">"+f[4..]+"</font></b></td><td align=right><b><font color="+col+">"+
	(foo[f])+"</font></b></td><td align=right><b><font color="+col+">"+
	((foo[f]-last_usage[f]))+"</font></b><br></td>";
    }
  res+="</table></td><td>";

  res+=("<table width=100% border=0 cellspacing=0 cellpadding=2>"
	"<tr bgcolor=#d9dee7><th colspan=2><b>memory usage</b></th></tr>"
	"<tr bgcolor=#d9dee7><th align=right>Current (KB)</th><th align=right>"
	"Change (KB)</th></tr>");

  row = 0;
  foreach(ind, f)
    if(search(f, "num_"))
    {
      string bg="white";
      if( row++ % 2 )
        bg = "#eeeeee";
      if((f!="total_usage"))
	foo->total_usage += foo[f];
      else
	bg="#d9dee7";
      string col="darkred";
      if((foo[f]-last_usage[f]) < foo[f]/60)
	col="brown";
      if((foo[f]-last_usage[f]) == 0)
	col="black";
      if((foo[f]-last_usage[f]) < 0)
	col="darkgreen";
      res += sprintf("<tr bgcolor="+bg+"><td align=right><b><font "
		     "color="+col+">%.1f</font></b></td><td align=right>"
		     "<b><font color="+col+">%.1f</font></b><br></td>",
		     (foo[f]/1024.0),((foo[f]-last_usage[f])/1024.0));
    }
  last_usage=foo;
  roxen->set_var("__memory_usage", last_usage);
  res+="</table></td></tr></table>";
  first = res;
  res = "";

  return first +"</ul>";
}

mixed parse(object id) 
{ 
  return page_0( id, id->conf ) 
#if constant( get_profiling_info )
         + page_1( id, id->conf )
#endif
         ;
}
