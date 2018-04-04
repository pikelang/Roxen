#include <config.h>
#if constant(all_threads)
#include <roxen.h>
//<locale-token project="admin_tasks">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("admin_tasks",X,Y)

constant action="debug_info";

string name= LOCALE(35, "Thread backtrace");
string doc = LOCALE(36, 
		    "Shows a backtrace (stack) for each and every "
		    "thread in Roxen.");

protected string last_id, last_from;

string get_id(string from)
{
  if(last_from == from) return last_id;
  last_from=from;
  catch {
    object f = open(from,"r");
    string id;
    id = f->read(200);
    if(sscanf(id, "%*s$"+"Id: %*s,v %s ", id) == 3)
      return last_id=" ("+LOCALE(37, "version")+" "+id+")";
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
    res += ("<li value="+(--q)+"> "+Roxen.html_encode_string(line)+"<br />\n");
  }
  return res;
}


mixed parse( RequestID id )
{
  // Disable all threads to avoid potential locking problems while we
  // have the backtraces. It also gives an atomic view of the state.
  object threads_disabled = _disable_threads();

  array(Thread.Thread) threads = all_threads();

  threads = Array.sort_array (
    threads,
    lambda (Thread.Thread a, Thread.Thread b) {
      // Backend thread first, our thread last (since
      // it typically only is busy doing this page),
      // otherwise in id order.
      if (a == roxen->backend_thread)
	return 0;
      else if (b == roxen->backend_thread)
	return 1;
      else if (a == this_thread())
	return 1;
      else if (b == this_thread())
	return 0;
      else
	return a->id_number() > b->id_number();
    });

  string res =
    #"
    <style type='text/css'>
      ol.open li   { display: list-item; }
      ol.closed li { display: none; }
      h3 {
        cursor: pointer;
        background: url('&usr.fold;') -4px 60% no-repeat;
        padding-left: 18px;
      }
      h3.closed {
        background-image: url('&usr.unfold;');
      }
    </style>
    <script language='javascript'>
     function toggle_vis(div_id, h3) {
       var div = document.getElementById(div_id); 
       var is_open = (div.className == 'open');
       div.className = is_open ? 'closed' : 'open';
       h3.className = is_open ? 'closed' : 'open';
     }
     </script>" +
    "<font size='+1'><b>" + name + "</b></font>\n"
    "<p><cf-refresh/></p>\n";

  int hrnow = gethrtime();
  mapping(Thread.Thread:int) thread_task_start_times =
    roxen->get_thread_task_start_times() || ([ ]);
  int div_num = 1;
  for (int i = 0; i < sizeof (threads); i++) {
    string open_state = (threads[i] == this_thread()) ? "closed" : "open";
    string busy_time = "";
    if (int start_hrtime = thread_task_start_times[threads[i]])
      busy_time = sprintf(" &ndash; busy for %.3fs",
			  (hrnow - start_hrtime) / 1e6);
    string th_name =
      Roxen.thread_name(threads[i], 1) || 
      sprintf("%s 0x%x", LOCALE(39, "Thread"), threads[i]->id_number());
    res +=
      sprintf ("<h3 class='%s' "
	       " onclick='toggle_vis(\"%s\", this); return false;'>"
	       "%s%s</h3>\n"
	       "<ol class='%s' id='%s'> %s</ol>\n",
	       open_state,
	       "bt_" + div_num,
	       th_name,
	       busy_time,
	       open_state,
	       "bt_" + div_num,
	       format_backtrace(describe_backtrace(threads[i]->backtrace())/
				"\n", id));
    div_num++;
  }

  return res+"<p><cf-ok/></p>";
}
#endif /* constant(all_threads) */
