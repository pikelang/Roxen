/*
 * $Id: debuginformation.pike,v 1.9 1998/03/02 06:24:09 neotron Exp $
 */

inherit "wizard";
constant name= "Development//Debug information for developers";

constant doc = ("Show some internals of Roxen, useful for debugging "
		"code.");

constant more=1;

#if efun(_memory_usage)
mapping last_usage = ([]);
#endif

constant colors = ({ "#f0f0ff", "white" });

mixed page_0(object id, object mc)
{
  string res="";
  string first="";
  mixed foo;
  /*
  if(!this_object()->more_mode) return 0;
  if(node->folded)
    return link("<font size=\"+1\">Debug information for developers</font>");
  else
    res = link("<font size=\"+1\">Debug information for developers</font><ul>");
    */
#if efun(_memory_usage)
  mixed foo = _memory_usage();
  foo->total_usage = 0;
  foo->num_total = 0;
  array ind = sort(indices(foo));
  string f;
  res+=("<table cellpadding=0 cellspacing=0 border=0>"
	"<tr valign=top><td valign=top>");
  res+=("<table border=0 cellspacing=0 cellpadding=2>"
	"<tr bgcolor=lightblue><td>&nbsp;</td>"
	"<th colspan=2><b>number of</b></th></tr>"
	"<tr bgcolor=lightblue><th align=left>Entry</th><th align"
	"=right>Current</th><th align=right>Change</th></tr>");
  foreach(ind, f)
    if(!search(f, "num_"))
    {
      string bg="white";
      if(f!="num_total")
	foo->num_total += foo[f];
      else
	bg="lightblue";
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

  res+=("<table border=0 cellspacing=0 cellpadding=2>"
	"<tr bgcolor=lightblue><th colspan=2><b>memory usage</b></th></tr>"
	"<tr bgcolor=lightblue><th align=right>Current (KB)</th><th align=right>"
	"Change (KB)</th></tr>");

  foreach(ind, f)
    if(search(f, "num_"))
    {
      string bg="white";
      if((f!="total_usage"))
	foo->total_usage += foo[f];
      else
	bg="lightblue";
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
  res+="</table></td></tr></table>";
  first = html_border( res, 0, 5 );
  res = "";
#endif
#if efun(_dump_obj_table)
  first += "<p><br><p>";
  res += ("<table  border=0 cellspacing=0 cellpadding=2 width=50%>"
	  "<tr align=left bgcolor=lightblue><th  colspan=2>List of all "
	  "programs with more than two clones:</th></tr>"
	  "<tr align=left bgcolor=lightblue>"
	  "<th>Program name</th><th align=right>Clones</th></tr>");
  foo = _dump_obj_table();
  mapping allobj = ([]);
  string a = getcwd(), s;
  if(a[-1] != '/')
    a += "/";
  int i;
  for(i = 0; i < sizeof(foo); i++) {
    string s = foo[i][0];
    if(!stringp(s))
    {
      werror(sprintf("DebugInfo not string: %O\n", s));
      continue;
    }
    if(search(s,"base_server/mainconfig.pike")!=-1) s="ConfigNode";
    if(search(s,"base_server/configuration.pike")!=-1) s="Bignum";
    if(sscanf(s,"/precompiled/%s",s)) s=capitalize(s);
    allobj[s]++;
  }
  foreach(Array.sort_array(indices(allobj),lambda(string a, string b, mapping allobj) {
    return allobj[a] < allobj[b];
  }, allobj), s) {
    if((search(s, "Destructed?") == -1) && allobj[s]>2)
    {
      res += sprintf("<tr bgcolor=#f0f0ff><td><b>%s</b></td>"
		     "<td align=right><b>%d</b></td></tr>\n",
		     s - a, allobj[s]);
    }
  }
  res += "</table>";
  first += html_border( res, 0, 5 );
  res = "";
#endif
#if efun(_num_objects)
  first += ("Number of destructed objects: " + _num_dest_objects() +"<br>\n");
#endif  
#if efun(get_profiling_info)
  first += "<p><br><p> Only functions that have been called more than "
    "ten times are listed.<p>";
  res += "<table border=0 cellspacing=0 cellpadding=2 width=100%>\n"
    "<tr bgcolor=lightblue><th align=left colspan=2>Program</th>"
    "<th>&nbsp;</th><th align=right>Times cloned</th></tr>\n"
    "<tr bgcolor=lightblue><th>&nbsp;</th><th align=left>Function</th>"
    "<th>&nbsp;</th><th align=right>Times called</th></tr>\n";
  mapping programs = master()->programs;
  int color = 1;
  foreach(sort(indices(programs)), string prog) {
    string tf = "";
    array(int|mapping(string:array(int))) arr =
      get_profiling_info(programs[prog]);

    int start_color = color ^ 1;

    foreach(indices(arr[1]), string symbol) {
      arr[1][symbol] = arr[1][symbol][0];
    }
    array(int) num_calls = values(arr[1]);
    array(string) funs = indices(arr[1]);
    sort(num_calls, funs);
    int line = 0;
    foreach(reverse(funs), string fun) {
      if(arr[1][fun] > 10)
      {
	color ^= !(line % 3);
	tf += sprintf("<tr bgcolor=%s><td>&nbsp;</td><td>%s()</td>"
		      "<td>&nbsp;</td><td align=right>%d</td></tr>\n",
		      colors[color], html_encode_string(fun), arr[1][fun]); 
	line++;
      }
    }
    if(line && strlen(tf))
      res+=sprintf("<tr bgcolor=%s><td colspan=2><b>%s</b></td>"
		   "<td>&nbsp</td><td align=right><b>%d</b></td></tr>\n",
		   colors[start_color], html_encode_string(prog), arr[0]) + tf;
  }
  res += "</table>\n";
  first += html_border( res, 0, 5 );

#endif /* get_profiling_info */
  return first +"</ul>";
}

mixed handle(object id) { return wizard_for(id,0); }
