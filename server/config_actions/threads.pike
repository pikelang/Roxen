#include <config.h>
#if !defined(THREADS) || !constant(all_threads)
constant action_disabled = 1;
#else /* THREADS */
/*
 * $Id: threads.pike,v 1.3 1998/12/14 11:31:19 peter Exp $
 */
inherit "wizard";

constant name= "Status//Thread backtrace";
constant doc = ("Shows a backtrace (stack) for each and every thread in roxen.");
constant more = 1;

static string last_id, last_from;
string get_id(string from)
{
  if(last_from == from) return last_id;
  last_from=from;
  catch {
    object f = open(from,"r");
    string id;
    id = f->read(200);
    if(sscanf(id, "%*s$"+"Id: %*s,v %s ", id) == 3)
      return last_id=" (version "+id+")";
  };
  last_id = "";
  return "";
}

void add_id(array to)
{
  foreach(to[1], array q)
    if(stringp(q[0]))
      q[0]+=get_id(q[0]);
}

string link_to(string what, object id, int qq)
{
  int line;
  string file, fun;
  sscanf(what, "%s(%*s in line %d in %s", fun, line, file);
  if(file && fun && line)
  {
    sscanf(file, "%s (", file);
    if(file[0]!='/') file = combine_path(getcwd(), file);
//     werror("link to the function "+fun+" in the file "+
// 	   file+" line "+line+"\n");
// "<a href=\"/(old_error,find_file)/error?"+
// 	    "file="+http_encode_string(file)+"&"
// 	    "fun="+http_encode_string(fun)+"&"
// 	    "off="+qq+"&"
// 	    "error="+eid+"&"


   // 	    "line="+line+"#here\">"    
    return ("<a href=\""+id->raw+"&file="+file+"&fun="+fun+"&off="+qq+"\">");
  }
  return "<a>";
}

string format_backtrace(array bt, object id)
{
  int q = sizeof(bt)-1;
  string res="";
  foreach(bt, string line)
  {
    string fun, args, where, fo;
    if((sscanf(html_encode_string(line), "%s(%s) in %s",
	       fun, args, where) == 3) &&
       (sscanf(where, "%*s in %s", fo) && fo)) {
      line += get_id( fo );
      res += ("<li value="+(--q)+"> "+line-(getcwd()+"/")+"<p>\n");
    } else {
//       res += "<li value="+(q--)+"> <b><font color=darkgreen>"+
// 	line+"</font></b><p>\n";
    }
  }
  return res;
}


constant ok_label = " Refresh ";
constant cancel_label = " Done ";

int verify_0()
{
  return 1;
}

mixed page_0(object id, object mc)
{
  string res="";
  int thr=1;
//   res=sizeof(all_threads())+" threads.<p>\n";
  foreach(all_threads(), object t)
    res += ("<h3>Thread "+(thr++)+"</h3><ol> "+
      format_backtrace(describe_backtrace(t->backtrace())/"\n",id)+
	    "</ol>");
  return res;
}

mixed handle(object id) { return wizard_for(id,0); }
#endif
