/* $Id: describers.pike,v 1.34 1997/08/12 22:28:33 peter Exp $ */

#include <module.h>
int zonk=time();
#define link(d) ("<a href=\""+node->path(1)+"?"+(zonk++)+"\">\n"+(d)+"\n</a>\n")

inherit "low_describers";
inherit "config/low_describers";

import Array;
import String;
#define ABS(X) ((X)<0?-(X):(X))
string describe_configuration_global_variables(object node)
{
  return link("<font size=\"+1\"><b>Server variables</b></font>");
}

string describe_holder(object node)
{
  object o, foo;
  int num;

  o=node->down;
  while(o)
  {
    if(!((functionp(o->data[VAR_CONFIGURABLE])&&o->data[VAR_CONFIGURABLE]())
       ||((o->data[VAR_CONFIGURABLE]==VAR_EXPERT)&&!this_object()->expert_mode)
       ||((o->data[VAR_CONFIGURABLE]==VAR_MORE)&&!this_object()->more_mode)))
    {
      num++;
      foo=o;
    }
    o=o->next;
  }
  if(num==1)
  {
    foo->folded = 0;
    return link(node->data);
  }
  if(num)
    return link(node->data + "...");
}

string describe_builtin_variables(object node)
{
  return link("<b>Builtin variables (security, comments etc.)</b>");
}

string describe_time(int t)
{
  return capitalize(roxen->language("en","date")(t));
}

string describe_interval(int i)
{
  switch(i)
  {
   case 0..1:        return "second";
   case 2..50:       return i+" seconds";
   case 51..66:      return "minute";
   case 67..3560:    return ((i+20)/60)+" minutes";
   case 3561..3561*2:return "hour";
   default: return ((i+300)/3600)+" hours";
  }
}

string describe_times(array (int) times)
{
  
  if(sizeof(times) < 6)
    return implode_nicely(map(times, describe_time));

  int d, every=1;
  int ot = times[0];
  foreach(times[1..], int t)
    if(d)
    {
      if(ABS(t-ot-d)>(d/4))
      {
	every=0;
	break;
      }
      ot=t;
    } else
      d = t-ot;
  if(every && (times[-1]+d) >= time(1)-10)
    return "every "+describe_interval(d)+" since "+describe_time(times[0]);
  return implode_nicely(map(times[..4], describe_time)+({"..."})+
			map(times[sizeof(times)-3..], describe_time));
}

string fix_err(string s)
{
  while(s[-1]=='\n' || s[-1]==' ' || s[-1]=='\t') s=s[..strlen(s)-2];
  if(!(<'.','!','?'>)[s[-1]]) s+=".";
  return capitalize(s);
}

int last_time;
string describe_error(string err, array (int) times)
{
  int code, nt;
  if(sizeof(times)==1 && times[0]/60==last_time) nt=1;
  last_time=times[0]/60;
  sscanf(err, "%d,%s", code, err);
  return ("<table><tr><td valign=top><img src=/image/err_"+code+".gif>"
	  "</td><td>"+(nt?"":describe_times(times)+"<br>")+
	  replace(fix_err(err),"\n","<br>\n")+"</table>");
}

mapping actions = ([]);
object get_action(string act)
{
  if(!actions[act]) actions[act]=compile_file("config_actions/"+act)();
  return actions[act];
}

mixed describe_actions(object node, object id)
{
  if(id->pragma["no-cache"]) actions=([]);
  if(!id->variables->action)
  {
    string res="<dl>";
    array acts = ({});
    foreach(get_dir("config_actions"), string act)
      catch {
	if(act[0]!='#' && act[-1]=='e')
	  if(!get_action(act)->more || this_object()->more_mode)
	    acts+=({"<!-- "+get_action(act)->name+" --><dt><font size=\"+2\">"
		      "<a href=\"/Actions/?action="+act+"\">"+
		      get_action(act)->name+"</a></font><dd>"+
		      (get_action(act)->doc||"") });
      };
    return res+(sort(acts)*"\n")+"</dl>";
  }
  mixed res;
  res=get_action(id->variables->action)->handle(id,this_object());
  return res;
}

string describe_errors(object node)
{
//  if(node->folded)
//    return (link("<font size=+2>&nbsp;Event log</font>"));
  array(string) report = ({ });
  last_time=0;
  string err;
  array report = ({ }), r1=indices(node->data), r2;
  r2 = map(values(node->data), lambda(array a){ return a[0]; });

  sort(r2,r1);
  
  foreach(r1, err)
    report += ({ describe_error(err, node->data[err]) });

//  return (link("<font size=+2>&nbsp;Event log")+"</font><dd><pre>"+
  return (sizeof(report)?(report*""):"Empty");
//+"</pre>");
}

array|string describe_module_variable(object node)
{
  string res, err;

  if((node->data[VAR_CONFIGURABLE] == VAR_EXPERT)&&!this_object()->expert_mode)
    return 0;
  if((node->data[VAR_CONFIGURABLE] == VAR_MORE)&&!this_object()->more_mode)
    return 0;
  if(functionp(node->data[VAR_CONFIGURABLE]) && node->data[VAR_CONFIGURABLE]())
    return 0;
    
  if(node->folded)
    if(node->error)
      return "<b>Error in:</b> "+link("<b>"+node->data[VAR_NAME]+"</b>");
    else
      return link(node->data[VAR_NAME])
	+ ": <i>" + describe_variable_as_text(node->data) + "</i>";

  if(node->error)
    err = "<font size=\"+1\"><b>"+node->error+"</b></font><br>";

  res = describe_variable_low(node->data, node->path(1));

  if(res)
    return ({ "<form action=/(set)"+node->path(1)+">" 
		, (err?err:"")+res+"</form>" });

}

string describe_open_files(object node)
{
  if(!this_object()->more_mode) return 0;
  string res = link("<font size=\"+1\">Open files</font><dd>");
  if(node->folded)
    return res;
#if 0
#ifndef DEBUG
  res += "<br><i>Define DEBUG in config/config.h for more accurate debug</i><p>";
#endif
#endif
  res += roxen->checkfd(0);
  return res;
}

string describe_module_copy_status(object node)
{
  string q;

  if(node->data) q=node->data();

  if(!q || !strlen(q)) return 0;

  if(!node->folded)
    return link("<b>Status and debug info</b>")+"<dd>" + q+"<br>";
  return link("<b>Status and debug info</b><br>");
}

string describe_module_copy_variables(object node)
{
  return link("Variables");
}  

string describe_module_subnode(object node)
{
  if(node->folded) return link(node->data[VAR_NAME]);
  return link(node->data[VAR_NAME])+"<blockquote>"+node->data[VAR_DOC_STR]+"</blockquote>";
}  


#define DOTDOT(node) ("<a href=/(moredocs)"+node->path(1)+"><img border=0 src=/auto/button/lm/More%20Documentation><img border=0 alt=\"\" hspacing=0 vspacing=0 src=/auto/button/rm/%20></a>")
#define NODOTDOT(node) ("<a href=/(lessdocs)"+node->path(1)+"><img border=0 src=/auto/button/lm/Less%20Documentation><img border=0 alt=\"\" hspacing=0 vspacing=0 src=/auto/button/rm/%20></a>")

string shorten(string in, object node)
{
  if(sizeof(in/"<hr>")<3 && sizeof(in/"<p>")<2) return in;
  if(strlen(in)<250) return in;
  if((search(in,"\n")<0) || (search(in,"\n")==strlen(in)-1)) return in;
  if(node->moredocs)
    return in+"<p>"+NODOTDOT(node);
//  for(int i=100;i<strlen(in);i++)
//    if(in[i]=='>' || in[i]=='\n')
//      break;
  return "<table><tr><td>"+replace((in/"\n")[0],({"<br>","<p>"}),({" "," "}))+
    "<p>"+DOTDOT(node)+"</td></tr></table>";
}

string describe_module_copy(object node)
{
  string name, com;
  object o;

  if(!node->data)
  {
    node->dest();
    return "";
  }


  if((name=node->data->query("_name")) && strlen(name))
    ;
  else if(node->data->query_name) 
    name = node->data->query_name();
  else if(node->data->comment) 
    name = node->data->comment();

  if(!name || !strlen(name)) 
    name=node->_path[sizeof(node->_path)-2..sizeof(node->_path)-1]*" copy ";

  if(node->folded)
    return  ("<font size=\"+1\">" + link( name ) + "</font>");

  com = (node->data->file_name_and_stuff()+
	 (node->data->query("_comment")||""));

  return ("<font size=\"+1\">" + link( name ) + "</font><dd>" 
	  + shorten((roxen->QUERY(DOC)?node->data->info():""), node)
	  + (strlen(com)?"<p><i>"+com+"</i></p>":"")
	  +"<dd>");
}

string describe_module(object node)
{
  string name, com;
  if(!(node->data->enabled 
       && (name=node->data->enabled->query("_name")) 
       && strlen(name)))
    name = node->data->name;

  if(node->data->enabled)
    com = (node->data->master->file_name_and_stuff()+
	   (node->data->master->query("_comment")||""));

  if(node->data->copies)
    return ("<font size=\"+1\">" + link(name) + "</font>");
  if(node->folded)
    return ("<font size=\"+1\">" + link(name) + "</font>");

  if (!node->data->master) {
    return("Module without copies:"+name);
  }
  return ("<font size=\"+1\">" + link(name) +  "</font><dd>" +
          shorten(node->data->master->info(),node) 
	  + (strlen(com)?"<p><i>"+com+"</i></p>":""));

}

string describe_global_variables( object node )
{
  return "";
}

string describe_root(object root)
{
  return "";
}

string describe_configurations(object node)
{
  return "";
}

string describe_configuration(object node)
{
  if(!node->data)  
  {
    node->dest();
    return 0;
  }
  return ("<font size=\"+2\">" + link(node->data->query_name()) + "</font>"+
         (node->folded?"":"<dd>"+node->data->desc()+node->data->comment()));
}


string quote_html(string s)
{
  return(replace(s, ({ "<", ">", "&" }), ({ "&lt;", "&gt;", "&amp;" })));
}

#if efun(_memory_usage)
mapping last_usage = ([]);
#endif
string describe_global_debug(object node)
{
  string res;
  mixed foo;
  if(!this_object()->more_mode) return 0;
  if(node->folded)
    return link("<font size=\"+1\">Debug information for developers</font>");
  else
    res = link("<font size=\"+1\">Debug information for developers</font><ul>");
#if efun(_memory_usage)
  mixed foo = _memory_usage();
  foo->total_usage = 0;
  foo->num_total = 0;
  array (string) ind = sort(indices(foo));
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
#endif
#if efun(_dump_obj_table)
  res+="<p><br><p>";
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
    if(search(s,"base_server/mainconfig.pike")!=-1) s="ConfigNode";
    if(search(s,"base_server/configuration.pike")!=-1) s="Bignum";
    if(sscanf(s,"/precompiled/%s",s)) s=capitalize(s);
    allobj[s]++;
  }
  foreach(sort_array(indices(allobj),lambda(string a, string b, mapping allobj) {
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
#endif
#if efun(_num_objects)
  res += ("Number of destructed objects: " + _num_dest_objects() +"<br>\n");
#endif  
#if efun(get_profiling_info)
  res += "<p><br><p> Only functions that have been called more than "
    "ten times are listed.<p>";
  res += "<table border=0 cellspacing=0 cellpadding=2 width=50%>\n"
    "<tr bgcolor=#ddddff><th align=left colspan=2>Program</th>"
    "<th>&nbsp;</th><th align=right>Times cloned</th></tr>\n"
    "<tr bgcolor=#ddddff><th>&nbsp;</th><th align=left>Function</th>"
    "<th>&nbsp;</th><th align=right>Times called</th></tr>\n";
  mapping programs = master()->programs;
  foreach(sort(indices(programs)), string prog) {
    string tf = "";
    array(int|mapping(string:array(int))) arr =
      get_profiling_info(programs[prog]);

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
	if ((line % 6)<3) {
	  tf += sprintf("<tr bgcolor=#f0f0ff><td>&nbsp;</td><td>%s()</td>"
			 "<td>&nbsp;</td><td align=right>%d</td></tr>\n",
			 quote_html(fun), arr[1][fun]); 
	} else {
	  tf += sprintf("<tr bgcolor=white><td>&nbsp;</td><td>%s()</td>"
			 "<td>&nbsp;</td><td align=right>%d</td></tr>\n",
			 quote_html(fun), arr[1][fun]); 
	}
	line++;
      }
    }
    if(line && strlen(tf))
      res+=sprintf("<tr bgcolor=#e0e0ff><td colspan=2><b>%s</b></td>"
		   "<td>&nbsp</td><td align=right><b>%d</b></td></tr>\n",
		   quote_html(prog), arr[0]) + tf;
  }
  res += "</table>\n";
#endif /* get_profiling_info */
  return res +"</ul>";
}

#define MB (1024*1024)

string describe_string_status(object node)
{
#ifndef DEBUG
  return 0;
#endif
#if efun(_string_debug)
  if(node->folded)
    return link("<font size=\"+1\">Shared string status</font>");
  return (link("<font size=\"+1\">Shared string status</font><dd>")
	  + "<pre>"
	  + _string_debug(1)
	  + "</pre>\n");
#endif
}

string describe_request_status(object node)
{
  if(node->folded)
    return link("<font size=\"+1\">Access / request status</font>");
  return link("<font size=\"+1\">Access / request status</font>") + "<dd>"+
    roxen->full_status();
}

string describe_pipe_status(object node)
{
  int *ru;
  if(!this_object()->more_mode) return 0;
#if efun(_pipe_debug)
  ru=_pipe_debug();
 if(node->folded)
    return link("<font size=\"+1\">Pipe system status</font>");
 if(!ru[0])
   return (link("<font size=\"+1\">Pipe system status</font>")+"<dd>Idle");
 
 return (link("<font size=\"+1\">Pipe system status</font>")+"<dd>"
	 "<table border=0 cellspacing=0 cellpadding=-1>"
	 "<tr align=right><td colspan=2>Number of open outputs:</td><td>"
          +ru[0] + "</td></tr>"
	  "<tr align=right><td colspan=2>Number of open inputs:</td><td>"
	  +ru[1] + "</td></tr>"
	  "<tr align=right><td></td><td>strings:</td><td>"+ru[2]+"</td></tr>"
	  "<tr align=right><td></td><td>objects:</td><td>"+ru[3]+"</td></tr>"
	  "<tr align=right><td></td><td>mmapped:</td><td>"+(ru[1]-ru[2]-ru[3])
	  +"<td> ("+(ru[4]/1024)+"."+(((ru[4]*10)/1024)%10)+" Kb)</td></tr>"
	  "<tr align=right><td colspan=2>Buffers used in pipe:</td><td>"+ru[5]
          + "<td> (" + ru[6]/1024 + ".0 Kb)</td></tr>"
	  "</table>\n");
#endif
}

string describe_process_status(object node)
{
  string res;
  int *ru, tmp, use_ru;

  if(catch(ru=rusage())) return 0;

  if(ru[0])
    tmp=ru[0]/(time(1) - roxen->start_time+1);

  if(node->folded)
    return link("<font size=\"+1\">Process status</font>");

  return (link("<font size=\"+1\">Process status</font>")+"<dd><pre>"
	  "CPU-Time used             : "+roxen->msectos(ru[0]+ru[1])+
	  " ("+tmp/10+"."+tmp%10+"%)\n"
	  +(ru[-2]?(sprintf("Resident set size (RSS)   : %.3f Mb\n",
			    (float)ru[-2]/(float)MB)):"")
	  +(ru[-1]?(sprintf("Stack size                : %.3f Mb\n",
			    (float)ru[-1]/(float)MB)):"")
	  +(ru[6]?"Page faults (non I/O)     : " + ru[6] + "\n":"")
	  +(ru[7]?"Page faults (I/O)         : " + ru[7] + "\n":"")
	  +(ru[8]?"Full swaps (should be 0)  : " + ru[8] + "\n":"")
	  +(ru[9]?"Block input operations    : " + ru[9] + "\n":"")
	  +(ru[10]?"Block output operations   : " + ru[10] + "\n":"")
	  +(ru[11]?"Messages sent             : " + ru[11] + "\n":"")
	  +(ru[12]?"Messages received         : " + ru[12] + "\n":"")
	  +(ru[13]?"Number of signals received: " + ru[13] + "\n":"")
	  +"</pre>");
}

string describe_hostnames_status(object node)
{
  if(!this_object()->more_mode) return 0;

  if(node->folded)
    return link("<font size=\"+1\">Host names</font>");
  if(!sizeof(roxen->out))
    return link("<font size=\"+1\">Host names</font><dd>No processes running");
  return (link("<font size=\"+1\">Host names</font><dd>") +
	  "Number of host name lookup processes : "+sizeof(roxen->out)+"<br>"
	  "Host name lookup queue size          : "  
	  + (sizeof(roxen->do_when_found)?sizeof(roxen->do_when_found)
//	     + " (" + (string)roxen->get_size( roxen->do_when_found ) +
          + sprintf(" (%2.1f per process)<br>",
		     (float)sizeof(roxen->do_when_found)
		     / (float)sizeof(roxen->out))
	     :"empty"));
}

string describe_cache_system_status(object node)
{
  if(node->folded)
    return link("<font size=\"+1\">Memory cache system</font>");
  return (link("<font size=\"+1\">Memory cache system</font><dd>") 
	  + cache->status());
}


string describe_disk_cache_system_status(object node)
{
  if(!(roxen->QUERY(cache)))
    return 0;

  if(node->folded)
    return link("<font size=\"+1\">Persistent disk cache system</font>");
  return (link("<font size=\"+1\">Persistent disk cache system</font><dd>") 
	  + roxen->get_garb_info());
}

array describe_global_status(object node)
{
  string res;
  int *ru, tmp, use_ru;

  if(node->folded)
    return ({"", ""});
  
  res =  "<h2>&nbsp;Server uptime: " 
    + roxen->msectos((time(1) - roxen->start_time)*1000)
    + "</h2>";

  return ({ "<p>", res });
}
