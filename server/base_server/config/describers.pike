/* $Id: describers.pike,v 1.56 1998/07/07 17:03:20 grubba Exp $ */

#include <module.h>
int zonk=time();
#define link(d) ("<a href=\""+node->path(1)+"?"+(zonk++)+"\">\n"+(d)+"\n</a>\n")

inherit "low_describers";
//inherit "config/low_describers";

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
    if(!((functionp(o->data[VAR_CONFIGURABLE]) && o->data[VAR_CONFIGURABLE]()) ||
	 (intp(o->data[VAR_CONFIGURABLE]) && 
	  (((o->data[VAR_CONFIGURABLE] & VAR_EXPERT) && !this_object()->expert_mode) ||
	   ((o->data[VAR_CONFIGURABLE] & VAR_MORE) && !this_object()->more_mode)))))
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

int __lt;
string describe_time(int t)
{
  int full;
  if(localtime(__lt)->yday != localtime(t)->yday)
  {
    __lt = t;
    full=1;
  }

  if(full)
    return capitalize(roxen->language("en","date")(t));
  else
    return sprintf("%02d:%02d",localtime(t)->hour,localtime(t)->min);
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
  __lt=0;
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
  array(string) codetext=({ "Notice:", "Warning:", "Error:" });
  
  if(sizeof(times)==1 && times[0]/60==last_time) nt=1;
  last_time=times[0]/60;
  sscanf(err, "%d,%s", code, err);
  return ("<table><tr><td valign=top><img src=/image/err_"+code+".gif \n"
	  "alt="+codetext[code-1]+">"
	  "</td><td>"+(nt?"":describe_times(times)+"<br>")+
	  replace(fix_err(err),"\n","<br>\n")+"</table>");
}

mapping actions = ([]);
object get_action(string act,string dir)
{
  if(!actions[act]) {
    object o = compile_file(dir+act)();
    if (o && !o->action_disabled) {
      actions[act]=o;
    }
  }
  return actions[act];
}

mapping get_actions(string base,string dir)
{
  mapping acts = ([  ]);
  foreach(get_dir(dir), string act)
  {
    mixed err;
    err = catch
    {
      if(act[0]!='#' && act[-1]=='e')
      {
	if(!get_action(act,dir)->more || this_object()->more_mode)
	{
	  string sm,rn = (get_action(act,dir)->name||act), name;

	  if(sscanf(rn, "%*s:%s", name) != 2)
	    name = rn;
	  sscanf(name, "%s//%s", sm, name);
	  sm = sm || "Misc";
	  if(!acts[sm]) acts[sm] = ({ });
	  acts[sm]+=
	    ({"<!-- "+rn+" --><dt><font size=\"+2\">"
		"<a href=\""+base+"?action="+act+"&unique="+(zonk++)+"\">"+
	      name+"</a></font><dd>"+(get_action(act,dir)->doc||"")});
	}
      }
    };
//    if(err) report_error(describe_backtrace(err));
  }
  return acts;
}

string act_describe_submenues(array menues, string base, string sel)
{
  if(sizeof(menues)==1) return "";
  string res = "<font size=+3>";
  foreach(sort(menues), string s) {
    s = s || "Misc";
    res+=
      (s==sel?"<li>":"<font color=#eeeeee><li></font><a href=\""+base+"?sm="+replace(s," ","%20")+
       "&uniq="+(++zonk)+"\"><font color=#888888>")+s+
      (s==sel?"<br>":"</font></a><br>");
  }
  return res + "</font>";
}

string focused_action_menu="Maintenance";
mixed describe_actions(object node, object id)
{
  if(id->pragma["no-cache"] && !id->variables->render) {
    foreach(indices(actions), string w)
    {
      destruct(actions[w]);
      m_delete(actions,w);
    }
    actions=([]);
  }
  if(!id->variables->sm)
    id->variables->sm = focused_action_menu||"Misc";
  else
    focused_action_menu = id->variables->sm=="0"?"Misc":id->variables->sm;
  
  if(!id->variables->action)
  {
    mapping acts = get_actions("/Actions/", "config_actions/");
    return "</dl><table cellpadding=10><tr><td valign=top bgcolor=#eeeeee>"+
      act_describe_submenues(indices(acts),"/Actions/",id->variables->sm)+
      "</td><td valign=top>"+
      (acts[id->variables->sm]?"<font size=+3>"+id->variables->sm+"</font><dl>":"<dl>")+
      (sort(acts[id->variables->sm]||({}))*"\n")+"</dl></td></tr></table><dl>";
  }
  if(id->pragma["no-cache"])
    m_delete(actions,!id->variables->action);

  return (get_action(id->variables->action,"config_actions/")
	  ->handle(id,this_object()));
}

int reverse_report = 1;
string describe_errors(object node)
{
  array report = indices(node->data), r2;

  last_time=0;
  r2 = map(values(node->data),lambda(array a){
     return reverse_report?-a[-1]:a[0];
  });
  sort(r2,report);
  for(int i=0;i<sizeof(report);i++) 
     report[i] = describe_error(report[i], node->data[report[i]]);
  return "</dl>"+(sizeof(report)?(report*""):"Empty")+"<dl>";
}

string module_var_name(object n)
{
  string na = n->data[VAR_NAME];
  if(n->up->describer==describe_holder) {
    sscanf(na, "%*s:%*[ ]%s", na);
  }
  return na;
}

array|string describe_module_variable(object node)
{
  string res, err;

  if(functionp(node->data[VAR_CONFIGURABLE]) && node->data[VAR_CONFIGURABLE]())
    return 0;
  else if (intp(node->data[VAR_CONFIGURABLE])) {
    if((node->data[VAR_CONFIGURABLE] & VAR_EXPERT) && !this_object()->expert_mode)
      return 0;
    if((node->data[VAR_CONFIGURABLE] & VAR_MORE) && !this_object()->more_mode)
      return 0;
  }
    
  if(node->folded)
    if(node->error)
      return "<b>Error in:</b> "+link("<b>"+module_var_name(node)+"</b>");
    else
      return link(module_var_name(node))+": <i>" +
	describe_variable_as_text(node->data) + "</i>";

  if(node->error)
    err = "<font size=\"+1\"><b>"+node->error+"</b></font><br>";

  res = describe_variable_low(node->data, node->path(1),0,module_var_name(node));

  if(res)
    return ({ "<form method=post action=/(set)"+node->path(1)+">" 
		, (err?err:"")+res+"</form>" });

}

string describe_module_copy_status(object node)
{
  string q;

  if(node->data) {
    mixed err;
    if (err = catch {
      q=node->data();
    }) {
      q = "<font color=red><pre>"+html_encode_string(describe_backtrace(err))+
	"</pre></font>";
    }
  }

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


#define DOTDOT(node) ("<a href=/(moredocs)"+node->path(1)+"><img border=0 src=/auto/button/lm/rm/More%20Documentation></a>")
#define NODOTDOT(node) ("<a href=/(lessdocs)"+node->path(1)+"><img border=0 src=/auto/button/lm/rm/Less%20Documentation></a>")

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

  if(node->data->master)
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
  return "</dl>";
}

string describe_root(object root)
{
  return "How did you find this node?";
}

string describe_configurations(object node)
{
  return "</dl>";
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

mapping docs = ([]);
mixed describe_docs(object node, object id)
{
  if ((!sizeof(docs)) || (id->pragma["no-cache"]) ||
      (id->variables->manual && !docs[id->variables->manual])) {
    array(string) dirs = filter(get_dir("./manuals/")||({}),
				lambda(string d) {
				  return (!(< ".", "..">)[d]);
				});

    /* Should do more here... */
    docs = mkmapping(dirs, dirs);
  }
  if (!id->variables->manual) {
    if (!sizeof(docs)) {
      return("<h1>No manuals installed</h1>");
    } else {
      return("</dl><table cellpadding=10>\n" +
	     (map(indices(docs),
		  lambda(string s, object node) {
		    return("<tr><td valign=top bgcolor=#eeeeee>"
			   "<a href=\"/" +
			   (node->_path * "/") + "?manual=" + s +"\">" + s +
			   "</a></td></tr>\n");
		  }, node) * "") +
	     "</table><dl>");
    }
  } else {
    return("<h1>Manual for " + id->variables->manual + " here</h1>" +
	   html_encode_string(sprintf("<pre>%O</pre>\n",
				      mkmapping(indices(node), values(node))))
	   );
  }
}
