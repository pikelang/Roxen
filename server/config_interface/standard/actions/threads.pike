#include <config.h>
#if constant(all_threads)
inherit "roxenlib";

constant name= "Thread backtrace";
constant doc = ("Shows a backtrace (stack) for each and every thread in roxen.");
constant action="debug_info";

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
    return ("<a href=\""+id->raw+"&file="+file+"&fun="+fun+"&off="+qq+"\">");
  }
  return "<a>";
}

string format_backtrace(array bt, object id)
{
  int q = sizeof(bt);
  string res="";
  foreach(bt-({""}), string line)
  {
    line += get_id( (line/":")[0] );
    res += ("<li value="+(--q)+"> "+html_encode_string(line)+"<br />\n");
  }
  return res;
}


constant ok_label = " Refresh ";
constant cancel_label = " Done ";

mixed parse(object id)
{
  string res="";
  int thr=1;

  foreach(all_threads(), object t)
    res += (t==roxen->backend_thread?"<h3>Backend thread</h3>":
            ("<h3>Thread "+(thr++)+"</h3>"))+"<ol> "+
      format_backtrace(describe_backtrace(t->backtrace())/"\n",id)+
        "</ol>";
  return res+"<p><cf-ok>";
}
#endif
