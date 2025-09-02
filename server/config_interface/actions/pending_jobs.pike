#include <config.h>
#include <roxen.h>
//<locale-token project="admin_tasks">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("admin_tasks",X,Y)

constant action="debug_info";

string name= LOCALE(0, "Pending jobs");
string doc = LOCALE(0,
                    "Shows a list of jobs that are currently queued "
                    "for execution.");

mixed parse( RequestID id )
{
  string res="";
  int thr=1;
  res +=
    "<h2>Pending jobs</h2>\n\n"
    "<p><cf-refresh/></p>\n\n";
  res += "<h3>Handler queue</h3>\n\n"
    "<p>These are jobs that will run as soon as there is "
    "a handler thread available.</p>\n\n"
    "<ul>\n";
  string prev_line = "";
  int count = 0;
  foreach(roxen->handle_queue->peek_array(), array entry) {
    if (!arrayp(entry) || !sizeof(entry)) continue;
    mixed val = entry[0];
    string fun = "Unknown function";
    if (!stringp(val)) {
      if (intp(val)) {
        fun = sprintf("%d", val);
      } else {
        catch {
          fun = master()->describe_function(val);
        };
      }
    } else {
      fun = val;
    }
    string args = master()->Describer()->describe_comma_list(entry[1..],
                                                             0x7fffffff);

    fun = Roxen.html_encode_string(fun);
    args = Roxen.html_encode_string(args);

    string line = sprintf("<li><tt>%s(%s)</tt></li>\n", fun, args);

    if (prev_line == line) {
      count++;
      continue;
    }

    if (count) {
      if (count > 1) {
        res += sprintf(" <i>Repeated %d times.</i>", count);
      }
      res += "</li>\n";
    }

    res += line;
    prev_line = line;
    count = 1;
  }

  if (count) {
    if (count > 1) {
      res += sprintf(" <i>Repeated %d times.</i>", count);
    }
    res += "</li>\n";
  }
  res += "</ul>\n\n";

  res += "<h3>Background queue</h3>\n\n"
    "<p>These are jobs that will run as soon as the previous background job "
    "has completed.</p>\n\n"
    "<ul>\n";
  prev_line = "";
  count = 0;
  foreach(roxen->bg_queue->peek_array(), array entry) {
    if (!arrayp(entry) || !sizeof(entry)) continue;
    mixed val = entry[0];
    string fun = "Unknown function";
    if (!stringp(val)) {
      if (intp(val)) {
        fun = sprintf("%d", val);
      } else {
        catch {
          fun = master()->describe_function(val);
        };
      }
    } else {
      fun = val;
    }
    string args = master()->Describer()->describe_comma_list(entry[1..],
                                                             0x7fffffff);

    fun = Roxen.html_encode_string(fun);
    args = Roxen.html_encode_string(args);

    string line = sprintf("<li><tt>%s(%s)</tt></li>\n", fun, args);

    if (prev_line == line) {
      count++;
      continue;
    }

    if (count) {
      if (count > 1) {
        res += sprintf(" <i>Repeated %d times.</i>", count);
      }
      res += "</li>\n";
    }

    res += line;
    prev_line = line;
    count = 1;
  }

  if (count) {
    if (count > 1) {
      res += sprintf(" <i>Repeated %d times.</i>", count);
    }
    res += "</li>\n";
  }
  res += "</ul>\n\n";

  res += "<h3>Background future queue</h3>\n\n"
    "<p>These are asynchronous jobs that will be put on the background "
    "queue one at a time when the active background futures complete.</p>\n\n"
    "<p>The number of active jobs is controlled by the global setting "
    "<b>Number of concurrent background futures</b> (currently " +
    (roxen->query("bg_futures_throttle") || "unlimited") + ").</p>\n"
    "<ul>\n";

  prev_line = "";
  count = 0;
  foreach(roxen->bg_futures->peek_array(), array entry) {
    if (!arrayp(entry) || (sizeof(entry) < 2) || !entry[0]) continue;
    string promise = sprintf("%O", entry[0]);
    entry = entry[1..];

    mixed val = entry[0];
    string fun = "Unknown function";
    if (!stringp(val)) {
      if (intp(val)) {
        fun = sprintf("%d", val);
      } else {
        catch {
          fun = master()->describe_function(val);
        };
      }
    } else {
      fun = val;
    }
    string args = master()->Describer()->describe_comma_list(entry[1..],
                                                             0x7fffffff);

    promise = Roxen.html_encode_string(promise);
    fun = Roxen.html_encode_string(fun);
    args = Roxen.html_encode_string(args);

    string line = sprintf("<li><tt><b>%s:</b> %s(%s)</tt>", promise, fun, args);

    if (prev_line == line) {
      count++;
      continue;
    }

    if (count) {
      if (count > 1) {
        res += sprintf(" <i>Repeated %d times.</i>", count);
      }
      res += "</li>\n";
    }

    res += line;
    prev_line = line;
    count = 1;
  }

  if (count) {
    if (count > 1) {
      res += sprintf(" <i>Repeated %d times.</i>", count);
    }
    res += "</li>\n";
  }
  res += "</ul>\n\n";

  return res+"<table border='0'><tr><td><cf-refresh/></td><td><cf-ok/></td></tr></table>\n";
}

