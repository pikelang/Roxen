// This is a roxen module. Copyright © 2012, Roxen IS.

#include <module.h>
inherit "module";

constant cvs_version = "$Id$";
constant thread_safe = 1;
constant module_type = MODULE_ZERO;

LocaleString module_name = "Periodic Fetcher";
LocaleString module_doc  =
#"<p>The module fetches a list of URLs periodically. The periodicity can
be specified per URL. The main purpose is to populate caches and keep
them warm. </p>

<p>The list of URLs is specified in a file in the site itself. This
file is fetched on startup and the module has to be reloaded in order
to update the list. </p>

<p>The module uses the curl binary to simulate external requests.</p>";

constant curl_redirs = "5";


void ERROR_MSG(sprintf_format fmt, sprintf_args ... args) 
{
  report_error (module_name + ": " + fmt, @args);
}

void DEBUG_MSG(sprintf_format fmt, sprintf_args ... args) 
{
  if(query("debug"))
    report_debug (module_name + ": " + fmt, @args);
}

string status() 
{
  string res = "<p>";
  res += sprintf("Queue size: %d<br>", sizeof(event_queue));
  res += sprintf("Crawler status: %s", crawler_status);
  if(global_events)
  {
    res += "<br/><br/>\n";
    res += "<table border='1' cellpadding='2' cellspacing='0'>\n";
    res += "  <tr>\n";
    res += "    <th align='left'>URL</th>\n";
    res += "    <th align='left'>Period</th>\n";
    res += "    <th align='left'>Host</th>\n";
    res += "    <th align='left'>Low</th>\n";
    res += "    <th align='left'>High</th>\n";
    res += "    <th align='left'>Last</th>\n";
    res += "    <th align='left'>Count</th>\n";
    res += "  </tr>\n";
    foreach(global_events, Event event)
    {
      res += sprintf("<tr>\n"
		     "  <td>%s</td>\n"
		     "  <td>%d</td>\n"
		     "  <td>%s</td>\n"
		     "  <td>%f</td>\n"
		     "  <td>%f</td>\n"
		     "  <td>%f</td>\n"
		     "  <td>%d</td>\n"
		     "</tr>\n", 
		     event->url, event->period, event->host||"",
		     event->low/1000000.0,
		     event->high/1000000.0,
		     event->last/1000000.0,
		     event->count);
      
    }
    res += "</table>\n";
  }
  return res+"</p>";
}

mapping(string:function) query_action_buttons() {
  return ([ "Start Crawler": start_crawler,
	    "Stop Crawler": stop_crawler ]);
}

class Event
{
  string url;
  int period;
  string host;
  int time;
  int count;

  int last = UNDEFINED;
  int high = UNDEFINED;
  int low = UNDEFINED;

  void create(string _url, int _period, string _host)
  {
    url = _url;
    period = _period;
    host = _host;
  }

  string _sprintf()
  {
    return sprintf("Event(%O, %d, %O, %d)", url, period, host, time);
  }

  void update_statistics(int t)
  {
    if(t < low || low == UNDEFINED)
      low = t;

    if(t > high || high == UNDEFINED)
      high = t;

    last = t;
    count++;
  }
}

ADT.Priority_queue event_queue;
array(Event) global_events;
function do_fetch_co;
function start_crawler_co;
string crawler_status = "<font color='FFB700'><b>Waiting</b></font>";

void create() 
{
  defvar("crawl_src", "http://localhost/periodic-crawl.txt", 
	 "Crawl list URL", TYPE_STRING,
         "<p>The URL to the file that contains the list of URLs or paths to fetch. "
         "It should be a text file with one URL or path, and its periodicity in "
	 "seconds separated by space, per line. It is also possible to specify "
	 "an optional host header at the end of the line, e.g:</p>"
	 "<pre>"
	 "  http://localhost:8080/ 5<br/>"
	 "  http://localhost:8080/ 5 mobile.roxen.com<br/>"
	 "  http://localhost:8080/news 10<br/>"
	 "  http://localhost:8080/sports 10<br/>"
         "  /rss.xml?category=3455&id=47 20"
         "</pre>"
         "When a path is provided instead of a URL, a full URL will be constructed by "
         "prepending the path with the URL in the 'Base URL' setting.");

  defvar("base_url", "http://localhost:8080",
         "Base URL", TYPE_STRING,
         "For lines in the text file that contain a path instead of URL, "
         "this URL is prepended to construct a complete URL. This is useful "
         "if the frontends need to crawl using separate URLs.");

  defvar("crawl_delay", 60, 
	 "Crawl Delay", TYPE_INT,
	 "Wait this amount of second before starting the crawler after "
	 "the roxen server has started or the module has been reloaded.");

  defvar("curl_path", "/usr/bin/curl", 
	 "Curl Path", TYPE_STRING,
	 "The path to the curl binary.");

  defvar("curl_timeout", 300, 
	 "Curl Timeout", TYPE_INT,
	 "The timeout in seconds for each fetch.");

  defvar("debug", 0, 
	 "Debug", TYPE_FLAG,
	 "Activate to print debug messages in the debug log.");

  defvar("enable", 1, 
	 "Enable", TYPE_FLAG,
	 "Enable/Disable the crawler.");

}

void start() 
{
}

void stop()
{
  stop_crawler();
}

void ready_to_receive_requests() 
{
  event_queue = ADT.Priority_queue();

  if(!query("enable"))
  {
    crawler_status = "<b>Crawler disabled</b>";
    return;
  }

  roxen.background_run(1, init_crawler);
}

void init_crawler() {  
  array(Event) events = fetch_events(query("crawl_src"));
  if(!events)
  {
    return;
  }

  // Populate queue
  foreach(events, Event event)
    schedule_event(event);

  global_events = events;

  // Give the server some time before starting the crawler
  start_crawler_co = roxen.background_run(query("crawl_delay"), start_crawler);
}

array(Event) fetch_events(string crawl_src)
{
  RequestID id = roxen.InternalRequestID();
  id->set_url(crawl_src);

  string path = Standards.URI(crawl_src)->path;

  // Get content of crawl file.
  string crawl_file = my_configuration()->try_get_file(path, id);
  // werror("%O\n", crawl_file);
  if (!crawl_file)
  {
    ERROR_MSG("Can't fetch crawl source file: %O\n", query("crawl_src"));
    crawler_status = 
      sprintf("<font color='BC311B'>"
	      "  <b>Can't fetch crawl source file: %O.</b>"
	      "</font>", 
	      query("crawl_src"));
    return 0;
  }

  // One URL per line.
  array(string) lines = (crawl_file-"\r") / "\n" - ({""});
  array(Event) events = ({ });
  foreach(lines, string line)
  {
    string url;
    array fields = line / " " - ({""});
    if(sizeof(fields) < 2)
    {
      ERROR_MSG("Parse error in crawl source file:\n%s\n", crawl_file);
      crawler_status = 
	sprintf("<font color='BC311B'>"
		"  <b>Parse error in crawl source file: %O.</b>"
		"</font>", 
		query("crawl_src"));
      return 0;
    }

    if (has_value(fields[0], "://")) {
      url = fields[0];
    } else {
      url = query("base_url") + fields[0];
    }

    events += ({ Event(url, (int)fields[1], (sizeof(fields) >= 3)? fields[2]:0) });
  }
  return events;
}

void start_crawler()
{
  DEBUG_MSG("Starting Crawler\n");
  if(!sizeof(event_queue))
  {
    ERROR_MSG("Queue empty\n");
    return;
  }
  crawler_status = "<font color='5BBF27'><b>Running</b></font>";
  schedule_next();
}

void stop_crawler()
{
  DEBUG_MSG("Stopping Crawler\n");
  if(start_crawler_co)
  {
    remove_call_out(start_crawler_co);
  }
  if(do_fetch_co)
  {
    remove_call_out(do_fetch_co);
  }

  crawler_status = "<b>Stopped</b>";
}

void schedule_event(Event event)
{
  event->time = time() + event->period;
  event_queue->push(event->time, event);
}

void do_fetch()
{
  Event event = event_queue->pop();
  // werror("do_fetch: %O\n", event);
  int fetch_time = fetch_url(event->url, event->host);
  if(fetch_time >= 0) 
  {
    event->update_statistics(fetch_time);
    
    DEBUG_MSG("%O Pe:%d Ho:%O Lo:%f Hi:%f La:%f Co:%d\n", 
	      event->url, event->period, event->host||"",
	      event->low/1000000.0,
	      event->high/1000000.0,
	      event->last/1000000.0,
	      event->count);
  }

  schedule_event(event);
  schedule_next();
}

void schedule_next()
{
  Event event = event_queue->peek();
  if(!event)
    return;
  do_fetch_co = roxen.background_run(event->time - time(), do_fetch);
}

int fetch_url(string url, string|void host)
{
  DEBUG_MSG("Fetching %O, host: %O\n", url, host||"");
  Stdio.File stderr = Stdio.File();
  array command_args = ({ query("curl_path"), 
                          "-o", "/dev/null",
                          "--max-redirs", (string)curl_redirs,
			  "--max-time", (string)query("curl_timeout"),
                          //"--stderr", "/dev/null",
			  "--silent",
			  "--show-error" });

  if(host)
    command_args += ({ "--header", "Host: "+host });
  
  command_args += ({ url });

  mixed err = catch 
  {
    int start_time = gethrtime();
    object process = 
      Process.create_process(command_args, ([ "stderr": stderr->pipe() ]) );
    
    int code = process->wait();
    string err_msg = stderr->read();

    if(sizeof(err_msg))
      ERROR_MSG("%O\n", err_msg);
    
    process = 0;
    
    if (code) // curl exit code = 0 for success
    {
      ERROR_MSG("Process %s failed with exit code %d\n", 
		query("curl_path"), code);
      return -1;
    }

    return gethrtime() - start_time;
  };

  if (err) 
  {
    ERROR_MSG("Failed to to fetch %s\n", url);
    ERROR_MSG(describe_backtrace(err));
    return -1;
  }
}
