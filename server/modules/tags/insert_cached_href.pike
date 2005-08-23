// This is a roxen module. Copyright © 2000 - 2004, Roxen IS.
//

#include <module.h>
inherit "module";

//<locale-token project="mod_insert_cached_href">LOCALE</locale-token>
#define LOCALE(X,Y)	_DEF_LOCALE("mod_insert_cached_href",X,Y)

constant thread_safe = 1;
constant module_type = MODULE_TAG;
LocaleString module_name = LOCALE(0, "'insert cached-href and split-xml-data'");
LocaleString module_doc  = LOCALE(0, "This module contains the rxml-tags 'insert "
				     "cached-href' and 'split-xml-data'");

#if DEBUG_INSERT_CACHED_HREF
#define DWRITE(x)	report_debug("INSERT_CACHED_HREF: " + x + "\n")
#else
#define DWRITE(x)
#endif

#ifdef THREADS
private roxen.BackgroundProcess bg_process;
private array(HTTPClient) initiated; /* Contains initiated but unfinished data fetches */
private Thread.Mutex mutex;
private Thread.MutexKey mutex_key;
#endif

private HrefDatabase href_database;
private constant unavailable = "The requested page is unavailable at the moment. "
			       "Please try again later";

void create() {
  defvar("fetch-interval", "5 minutes", LOCALE(0, "Fetch interval"),
	 TYPE_STRING|VAR_MORE,
	 LOCALE(0, "States how often the data of an URL should be updated. "
		   "In seconds, minutes, hours or days."));
  
  defvar("fresh-time", "20 minutes", LOCALE(0, "Fresh time"),
	 TYPE_STRING|VAR_MORE,
	 LOCALE(0, "States how long data in the database can be considered fresh enough"
		   " to display. In seconds, minutes, hours or days."));
  
  defvar("ttl", "7 days", LOCALE(0, "Time to live"),
	 TYPE_STRING|VAR_MORE,
	 LOCALE(0, "States how long unrequested data can exist in the database"
		   " before being removed. In seconds, minutes, hours or days."));
 
  defvar("timeout", "10 seconds", LOCALE(0, "Timeout"),
	 TYPE_STRING|VAR_MORE,
	 LOCALE(0, "The timeout when fetching data from a server. In seconds, minutes, "
		   "hours or days."));
  
  defvar("update-interval", "1 minute", LOCALE(0, "Update interval"),
	 TYPE_STRING|VAR_MORE,
	 LOCALE(0, "States how often the module will check if the database needs to "
		   "be updated. In seconds, minutes, hours or days."));
  
  defvar("recursion_limit", 2, LOCALE(0, "Maximum recursion depth"),
	 TYPE_INT|VAR_MORE,
	 LOCALE(0,"Maxumum number of nested <tt>&lt;insert cached-href&gt;</tt>'s "
		  "allowed. May be set to zero to disable the limit."));
}


void start(int occasion, Configuration conf) {
  DWRITE("start(), occasion: " + occasion);
  
  if (occasion == 0) {
    href_database = HrefDatabase();
#ifdef THREADS
    initiated = ({});
    mutex = Thread.Mutex();
#endif
  }
  
#ifdef THREADS
  if (occasion == 2)
    bg_process->stop();
  
  bg_process = roxen.BackgroundProcess(get_time_in_seconds(query("update-interval")), 
				       href_database->update_db, 0); 
#endif
}

void stop() {
  DWRITE("stop()");
    
#ifdef THREADS
  bg_process->stop();
  bg_process = 0;
  mutex_key = mutex->lock();
  
  /* Removing registered callbacks for unfinished data fetches to avoid having the
     back-end thread call them after the module has been destructed: */
  foreach(initiated, HTTPClient client) {
    client->con->request_ok = 0;
    client->con->request_fail = 0;
  }
  
  mutex_key = 0;
  initiated = 0;
  mutex = 0;
#endif
  
  href_database = 0;
}

static int get_time_in_seconds(string input) {
  input = lower_case((string)input);
  input = String.trim_whites(input);
  
  int pos = 0;
  int number;
  string the_rest;
  
  for (int i = 0; i < sizeof(input) && is_number(input[i]); i++) {
    pos++;
  }
  
  number = (int)input[0..(pos - 1)];
  the_rest = String.trim_whites(input[pos..(sizeof(input) - 1)]);
  
  if (!sizeof(the_rest))
    return number;
  
  switch(the_rest[0]) {
  case 'd':
    return number * 24 * 3600;
  case 'h':
    return number * 3600;
  case 'm':
    return number * 60;
  case 's':
    return number;
  }
  
  return number;
}

static int(0..1) is_number(int char) {
  return (char >= 48 && char <= 57) ? 1 : 0;  
}

public int(0..1) already_initiated(string url) {
  foreach(initiated, HTTPClient client) {
    if (url == (string)client->url)
      return 1;
  }
  
  return 0;
}

public void|string fetch_url(mapping(string:mixed) to_fetch, void|mapping header) {
  DWRITE(sprintf("in fetch_url(): To fetch: %s, with timeout: %d", to_fetch["url"], 
		 to_fetch["timeout"]));
  
  mapping(string:mixed) args = (["timeout":to_fetch["timeout"], 
				 "cached-href":to_fetch["url"],
				 "sync":to_fetch["sync"]]);

  string method = "GET";
  object client;
  
#ifdef THREADS
  mutex_key = mutex->lock();
  
  if (!to_fetch["sync"] && already_initiated(to_fetch["url"])) {
    mutex_key = 0;
    return;
  }
  
  client = HTTPClient(method, args, header);
  initiated += ({client});
  mutex_key = 0;
  client->run();
  
  if (to_fetch["sync"]) {
    if(client->status > 0) {
      return client->data();
    } else
      return unavailable;
  }
#else
  client = Protocols.HTTP.get_url(to_fetch["url"], 0);
  
  if(client && client->status > 0) {
    href_database->update_data(to_fetch["url"], client->data());
    return client->data();
  } else
    return unavailable;
#endif
}


/* This class represents the database in which the data of the URL:s are stored */
class HrefDatabase {
  private constant request_table_def = "url VARCHAR(255) NOT NULL,"
				       "fetch_interval INT UNSIGNED NOT NULL,"
				       "fresh_time INT UNSIGNED NOT NULL,"
				       "ttl INT UNSIGNED NOT NULL,"
				       "timeout INT UNSIGNED NOT NULL,"
				       "time_of_day INT UNSIGNED NOT NULL,"
				       "next_fetch INT UNSIGNED,"
				       "latest_request INT UNSIGNED,"
				       "PRIMARY KEY (url, fetch_interval, "
				       "fresh_time, ttl, timeout, time_of_day)";
  
  private constant data_table_def = "url VARCHAR(255) NOT NULL,"
				    "data LONGBLOB,"
				    "latest_write INT UNSIGNED,"
				    "PRIMARY KEY (url)";

  private string request_table;
  private string data_table;
  
  public void create() {
    request_table = get_my_table("request", ({request_table_def}));
    data_table = get_my_table("data", ({data_table_def}));
  }

  public void update_db() {
    DWRITE(sprintf("###########  update_db(): Called every %d seconds  ##########"
		   , get_time_in_seconds(query("update-interval"))));
    
    foreach(initiated, HTTPClient client) {
      DWRITE("STILL initiated (should be empty!!!!!): " + (string)client->url);
    }
    
    remove_old_entrys();

    if (no_requests()) {
      DWRITE("There are no requests, returning from update_db()");
      return;
    }

    array(mapping(string:mixed)) to_fetch = urls_to_fetch();
    
    foreach(to_fetch, mapping next) {
      fetch_url(next);
    }
   
    foreach(initiated, HTTPClient client) {
      DWRITE("initiated: " + (string)client->url);
    }
 
    DWRITE("----------------- Leaving update_db() ------------------------");
  }
    
  public string get_data(mapping args, mapping header) {
    int next_fetch = 0;
    array(mapping(string:mixed)) result;

    /* if the tag argument time-of-day is provided, the database column next_fetch
       needs to be calculated: */
    if (args["time-of-day"]) { 
      mapping now = localtime(time());
      
      now["hour"] = 0;
      now["min"] = 0;
      now["sec"] = 0;
      
      next_fetch = mktime(now) + args["time-of-day"];
      
      if (next_fetch < time())
	next_fetch += 24 * 3600;
    }
    
#ifndef THREADS
    /* When running unthreaded the database still needs to be kept up-to-date */
    remove_old_entrys();
#endif
    
    sql_query("UPDATE " + request_table + " SET latest_request=" + time() 
	      + " WHERE url='" + args["cached-href"] + "' AND fetch_interval=" 
	      + args["fetch-interval"] + " AND fresh_time=" + args["fresh-time"] 
	      + " AND ttl=" + args["ttl"] + " AND timeout=" + args["timeout"]
	      + " AND time_of_day=" + args["time-of-day"]);
    
    sql_query("INSERT IGNORE INTO " + request_table 
	      + " values (%s, %d, %d, %d, %d, %d, %d, %d)", args["cached-href"], 
	      args["fetch-interval"], args["fresh-time"], args["ttl"],	
	      args["timeout"], args["time-of-day"], next_fetch, time());
    
    sql_query("INSERT IGNORE INTO " + data_table + " values (%s, '', 0)", 
	      args["cached-href"]); 
    
    result = sql_query("SELECT data FROM " + data_table + " WHERE url='" + 
		       args["cached-href"] + "' AND " + time() + " - latest_write < " 
		       + args["fresh-time"]);
    
    if (result && sizeof(result) && result[0]["data"] != "") {
      DWRITE("in get_data(): Returning cached data");
      
      return result[0]["data"];
    } else if (!args["pure-db"]) {
      DWRITE("in get_data(): No cached data existed so performing a synchronous fetch");
      
      string data = fetch_url((["url":args["cached-href"], "timeout":args["timeout"], 
				"sync":1]), header);
      
      return data;
    } else {
      DWRITE("in get_data(): No cached data existed and pure-db data "
	     "was desired, so simply returning 'unavailable'");
      
      return unavailable;
    }
  }
  
  private array(mapping(string:mixed)) no_duplicate_add(array(mapping(string:mixed))
							to_fetch, string url, 
							int timeout) {
    foreach(to_fetch, mapping one) {
      if (search(one, url))
	return to_fetch;
    }
    
    to_fetch += ({(["url":url, "timeout":timeout])});  
    
    return to_fetch;
  }
  
  private int(0..1) no_requests() {
    array(mapping(string:mixed)) result = sql_query("SELECT url from " + request_table);
    
    return sizeof(result) == 0 ? 1 : 0;
  }

  private void remove_old_entrys() {
    sql_query("DELETE FROM " + request_table + " WHERE " + time() + " - latest_request "
								    "> ttl");
    
    sql_query("DELETE " + data_table + " FROM " + data_table + " LEFT JOIN " + 
	      request_table + " ON " + data_table + ".url=" + request_table + 
	      ".url WHERE " + request_table + ".url IS NULL");
  }
  
  private array(mapping(string:mixed)) urls_to_fetch() {
    array(mapping(string:mixed)) to_fetch = ({});
    
    array(mapping(string:mixed)) result = sql_query("SELECT " + data_table + ".url, " 
						    + request_table + ".timeout FROM " 
						    + data_table + " LEFT JOIN " + 
						    request_table + " ON " + data_table 
						    + ".url=" + request_table + 
						    ".url WHERE " + data_table + 
						    ".data='' ORDER BY "
						    "url, timeout DESC");
    
    foreach(result, mapping row) {
      to_fetch = no_duplicate_add(to_fetch, row["url"], 0);
    }

    result = sql_query("SELECT " + data_table + ".url, " + request_table + ".timeout, " 
		       + data_table + ".latest_write, " + request_table + 
		       ".fetch_interval FROM " + data_table + " LEFT JOIN " 
		       + request_table + " ON " + data_table + ".url=" + request_table + 
		       ".url WHERE " + data_table + ".data!='' AND " + request_table + 
		       ".fetch_interval > 0 AND ((" + time() + " - " + data_table + 
		       ".latest_write) > " + request_table + ".fetch_interval) ORDER BY "
		       "url, timeout DESC");
    
    foreach(result, mapping row) {
      to_fetch = no_duplicate_add(to_fetch, row["url"], 0);
    }
    
    result = sql_query("SELECT " + data_table + ".url, " + request_table + ".timeout, " 
		       + request_table + ".time_of_day, " + request_table + 
		       ".next_fetch FROM " + data_table + " LEFT JOIN " + request_table 
		       + " ON " + data_table + ".url=" + request_table + ".url WHERE " 
		       + data_table + ".data!='' AND " + request_table + 
		       ".time_of_day > 0 AND " + time() + " > " + request_table + 
		       ".next_fetch ORDER BY url, timeout DESC");
    
    foreach(result, mapping row) {
      to_fetch = no_duplicate_add(to_fetch, row["url"], 0);
    }
    
    result = sql_query("SELECT url, max(timeout) FROM " + request_table + 
		       " AS url GROUP BY url");
    
    foreach(to_fetch, mapping one) {
      foreach(result, mapping row) {
	if (one["url"] == row["url"]) {
	  one["timeout"] = (int)row["max(timeout)"];
	  break;
	}
      }
    }
    
    return to_fetch;
  }
  
  public void update_data(string url, string data) {
    DWRITE(sprintf("in update_data(): Saving the fetched data to the db for url %s"
		   ,  url));
    
    sql_query("UPDATE " + data_table + " SET data=%s, latest_write=%d WHERE url=%s", 
	      data, time(), url);
    
    sql_query("UPDATE " + request_table + " SET next_fetch=next_fetch + " + (24 * 3600) 
	      + " WHERE time_of_day > 0 AND " + time() + " > next_fetch AND url='" 
	      + url + "'");
  }
}

/* This class represents a set of attributes given to the tag 'insert cached-href' */
class Attributes {

  private mapping orig_args; /* The attributes given to the tag */
  private mapping db_args; /* Checked attributes with relevance for the database */

  void create(mapping args) {
    orig_args = args;
    db_args = (["cached-href" : 0,
		"fetch-interval" : 0,
		"fresh-time" : 0,
		"ttl" : 0,
		"timeout" : 0,
		"time-of-day" : 0,
		"pure-db" : 0]);
    check_args();
  }
  
  private int(0..1) valid_arg(string arg) {
    arg = String.trim_whites(arg);
    
    if (!sizeof(arg) || !is_number(arg[0]) || arg[0] == 48)
      return 0;
    
    return 1;
  }
  
  private void check_args() {
    if (orig_args["cached-href"][0..6] != "http://" && orig_args["cached-href"][0..7] 
	!= "https://")
      RXML.run_error("An invalid URL has been provided");
    else 
      db_args["cached-href"] = orig_args["cached-href"];

    if (orig_args["time-of-day"] && orig_args["fetch-interval"])
      RXML.run_error("Supply either time-of-day or fetch-interval, not both");
    
    if (orig_args["time-of-day"]) {
      if (sizeof(orig_args["time-of-day"]) != 5)
	RXML.run_error("Wrong timeformat. The correct format is hh:mm");
      
      if (orig_args["time-of-day"][2] != ':')
	RXML.run_error("Wrong timeformat. The correct format is hh:mm");
      
      int hour = (int)orig_args["time-of-day"][0..1];
      int minute = (int)orig_args["time-of-day"][3..4];
      
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59)
	RXML.run_error("Hour must be between 0 and 23, minutes between 0 and 59");
      
      db_args["time-of-day"] = hour * 3600 + minute * 60;
      
    } else if (orig_args["fetch-interval"] && valid_arg(orig_args["fetch-interval"])) {
      db_args["fetch-interval"] = orig_args["fetch-interval"];
    } else {
      db_args["fetch-interval"] = query("fetch-interval");
    }

    if (orig_args["fresh-time"] && valid_arg(orig_args["fresh-time"]))
      db_args["fresh-time"] = orig_args["fresh-time"];
    else
      db_args["fresh-time"] = query("fresh-time");

    if (orig_args["ttl"] && valid_arg(orig_args["ttl"]))
      db_args["ttl"] = orig_args["ttl"];
    else
      db_args["ttl"] = query("ttl");

    if (orig_args["timeout"] && valid_arg(orig_args["timeout"]))
      db_args["timeout"] = orig_args["timeout"];
    else
      db_args["timeout"] = query("timeout");

    db_args["fetch-interval"] = get_time_in_seconds(db_args["fetch-interval"]);
    db_args["fresh-time"] = get_time_in_seconds(db_args["fresh-time"]);
    db_args["ttl"] = get_time_in_seconds(db_args["ttl"]);
    db_args["timeout"] = get_time_in_seconds(db_args["timeout"]);
    
    if (orig_args["pure-db"])
      db_args["pure-db"] = 1;
  }
  
  public mapping get_orig_args() {
    return orig_args;
  }
  
  public mapping get_db_args() {
    return db_args;
  }
}

class TagInsertCachedHref {
  inherit RXML.Tag;
  constant name = "insert";
  constant plugin_name = "cached-href";
  
  string get_data(string var, mapping args, RequestID id) {
    int recursion_depth = (int)id->request_headers["x-roxen-recursion-depth"];
    
    if (query("recursion_limit") &&
	(recursion_depth >= query("recursion_limit")))
      RXML.run_error("Too deep insert cached-href recursion.");
    
    recursion_depth++;

    if(args->nocache)
      NOCACHE();
    else
      CACHE(60);
    
    return href_database->get_data(Attributes(args)->get_db_args(), 
				   (["x-roxen-recursion-depth":recursion_depth]));
  }
} 

class TagSplitXMLData {
  inherit RXML.Tag;
  constant name = "split-xml-data";
  constant std_xml_encoding = "utf-8";
  
  class Frame {
    inherit RXML.Frame;
    
    array do_return(RequestID id) {
      string temp = lower_case(args["input"][0..90]);
      int pos = search(temp, "encoding");
      int counter = 0;
      string from = "";
      string parsed_data = "";

      for (int i = 0; pos != -1 && temp[(pos + 10 + i)..(pos + 10 + i)] != "\""; i++)
	from += temp[(pos + 10 + i)..(pos + 10 + i)];
      
      for (int i = 0; i < sizeof(args["input"]); i++) {
	if (args["input"][i..i] == "<") {
	  parsed_data = args["input"][i..(sizeof(args["input"]) - 1)];
	  break;
	}
      }
      
      RXML.user_set_var("xml", parsed_data, "var");
      
      if (sizeof(from)) 
	RXML.user_set_var("from", from, "var");
      else
	RXML.user_set_var("from", std_xml_encoding, "var");
      
      return 0;
    }
  }
}

#ifdef THREADS

/* This class represents the retrieval of data from an URL */
class HTTPClient {
  int status, timeout, start_time;
  object con;
  Standards.URI url;
  string path, query, req_data,method;
  mapping request_headers;
  Thread.Queue queue = Thread.Queue();
  int(0..1) sync;
  
  void do_method(string _method,
		 string|Standards.URI _url,
		 void|mapping query_variables,
		 void|mapping _request_headers,
		 void|Protocols.HTTP.Query _con, void|string _data)
  {
    if(!_con) {
      con = Protocols.HTTP.Query();
    }
    else
      con = _con;

    method = _method;

    if(!_request_headers)
      request_headers = ([]);
    else
      request_headers = _request_headers;

    req_data = _data;

    if(stringp(_url)) {
      if (mixed err = catch (url=Standards.URI(_url)))
	RXML.parse_error ("Invalid URL: %s\n", describe_error (err));
    }
    else
      url = _url;

#if constant(SSL.sslfile) 	
    if(url->scheme!="http" && url->scheme!="https")
      error("Protocols.HTTP can't handle %O or any other protocols than HTTP or HTTPS\n",
	    url->scheme);
    
    con->https= (url->scheme=="https")? 1 : 0;
#else
    if(url->scheme!="http"	)
      error("Protocols.HTTP can't handle %O or any other protocol than HTTP\n",
	    url->scheme);
    
#endif
    
    if(!request_headers)
      request_headers = ([]);
    mapping default_headers = ([
      "user-agent" : "Mozilla/4.0 compatible (Pike HTTP client)",
      "host" : url->host ]);
    
    if(url->user || url->passwd)
      default_headers->authorization = "Basic "
	+ MIME.encode_base64(url->user + ":" +
			     (url->password || ""));
    request_headers = default_headers | request_headers;
    
    query=url->query;
    if(query_variables && sizeof(query_variables))
      {
	if(query)
	  query+="&"+Protocols.HTTP.http_encode_query(query_variables);
	else
	  query=Protocols.HTTP.http_encode_query(query_variables);
      }
    
    path=url->path;
    if(path=="") path="/";
  }
  
  string data() {
    if(!con->ok)
      return 0;
    
    return con->data();
  }
  
  void req_ok() {
    DWRITE("Received headers from " + (string)url + " OK");
    status = con->status;
    int data_timeout = timeout - (time() - start_time);
    con->data_timeout = data_timeout >= 0 ? data_timeout : 0;
    con->timed_async_fetch(data_ok, data_fail);
  }
  
  void req_fail() {
    DWRITE("Receiving headers from " + (string)url + " FAILED");
    status = 0;
    mutex_key = mutex->lock();
    initiated -= ({this_object()});
    mutex_key = 0;

    if (sync)
      queue->write("@");
  }
  
  void data_ok() {
    DWRITE("Received data from " + (string)url + " OK");
    status = con->status;
    mutex_key = mutex->lock();
    initiated -= ({this_object()});
    mutex_key = 0;

    if (href_database)
      href_database->update_data((string)url, con->data());
    
    if (sync)
      queue->write("@");
  }
  
  void data_fail() {
    DWRITE("Receiving data from " + (string)url + " FAILED");
    status = 0;
    mutex_key = mutex->lock();
    initiated -= ({this_object()});
    mutex_key = 0;

    if (sync)
      queue->write("@");
  }
  
  void run() {
    con->set_callbacks(req_ok, req_fail);
    con->timeout = timeout;
    start_time = time();
    con->async_request(url->host,url->port,
		       method+" "+path+(query?("?"+query):"")+" HTTP/1.0",
		       request_headers, req_data);
    status = con->status;

    if (sync) {
      DWRITE("Waiting for fetch to complete (sync fetch)......");
      queue->read();
      DWRITE("Done waiting for fetch.");
    }
  }

  void create(string method, mapping args, mapping|void headers) {
    if(method == "POST") {
      mapping vars = ([ ]);
#if constant(roxen)
      foreach( (args["post-variables"] || "") / ",", string var) {
	array a = var / "=";
	if(sizeof(a) == 2)
	  vars[String.trim_whites(a[0])] = RXML.user_get_var(String.trim_whites(a[1]));
      }
#endif
      do_method("POST", args["cached-href"], vars, headers);
    }
    else
      do_method("GET", args["cached-href"], 0, headers);

    timeout = args["timeout"];
    sync = args["sync"];
  }
  
}
#endif




TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([

  "insert#cached-href":#"<desc type='plugin'><p>
This tag inserts the contents of the provided URL, read from a database. The
database is updated repeatedly in the background by a background process that is
initiated and run as soon as this module is loaded. If the database is empty
when the tag is executed, the standard behavior is to fetch the data immediately.
When providing values for the attributes fetch-interval, fresh-time, ttl, 
update-interval or timeout, the time can either be seconds, minutes, hours or days. 
If only a number is provided, it is interpreted as seconds, otherwise write the 
corresponding letter or word after the number, e.g: 10 days, 10d, 10 h, 10hours, 
5 min, 5m, 2 hours and so on. Spaces 
between the number and the word are allowed. The values at the settings tab for 
fetch-interval, fresh-time, ttl and timeout are the standard values that the tag 
will be assigned if an attribute is left out. update-interval on the other hand, is
central and common for all tags.
</p>
<p>
<h4>IMPORTANT:</h4> 
The data in the database for an URL is always shared by all tags at the
same site. This means that when data for an URL is updated this affects all tags
referring to this specific URL, even if the other attributes may differ. For example,
if the same URL is referenced by one tag without the pure-db attribute and another 
tag WITH the pure-db attribute, the only guarantee is that the tag with the 
attribute pure-db never will generate a data fetch. The tag without the attribute still
can. Another implication of the data being shared is for example if the same URL is 
referenced by two tags with different fetch intervals. The data will then be updated
at the smallest of these two fetch intervals. Providing the time-of-day attribute will
however always make the module fetch data when that time of day occur, without 
interference by any other tag referencing the same URL. Also important to note, is that
since the fetching of the common data is performed centrally by the module, the timeout
of every tag can not be used, of course. If several tags refer to the same URL but 
is provided with different timeouts, the longest timeout will be used. However, if there
exists no data in the database for the URL of a tag when the tag is run, and the pure-db 
attribute is not provided, then the fetching of data will be performed for that specific 
tag and with the specific timeout.
</p></desc>

<attr name='cached-href' value='string'>
<p>
 The URL of the page to be inserted.
</p>
</attr>

<attr name='fetch-interval' value='string'>
<p>
 States at which interval the background process will fetch the
 URL and update the database. 
</p>
</attr>

<attr name='time-of-day' value='string'>
<p>
 Can be provided as an alternative to fetch-interval, if a fetch should be performed once
 per day at a specific time. The provided time must be of the format hh:mm.
</p>
</attr>

<attr name='fresh-time' value='string'>
<p>
 States how long the data for the URL in the database is considered fresh.
</p>
</attr>

<attr name='ttl' value='string'>
<p>
 States how long unrequested data will exist in the database before being removed
</p>
</attr>

<attr name='timeout' value='string'>
<p>
 The timeout for the fetching of new data from a server
</p>
</attr>

<attr name='pure-db'>
<p>
 If provided, the tag will only return data stored in the database, i.e 
 never fetch data immediately if the database is empty. Instead, the 
 data will not be available until the background process has updated the database.
</p>
</attr>

<attr name='nocache' value='string'>
<p>
 If provided the resulting page will get a zero cache time in the RAM cache.
 The default time is up to 60 seconds depending on the cache limit imposed by
 other RXML tags on the same page.
</p>
</attr>",

  "split-xml-data":#"<desc><p>
 This tag takes data in XML-format, removes a potential BOM (Byte Order Mark)
 and returns the data along with the encoding.
 </p></desc>

 <attr name='input' value='string'>
 <p>
  The data to be parsed.
 </p> 
 </attr>

 <attr name='encoding' value='string'>
 <p>
  After parsing, this attribute will contain the encoding of the data
 </p>
 </attr>

 <attr name='xml-data' value='string'>
 <p>
  After parsing, this attribute will contain the data without the
  potential BOM (Byte Order Mark)
 </p>
 </attr>"
]);
#endif


