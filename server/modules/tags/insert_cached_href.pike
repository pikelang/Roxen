// This is a roxen module. Copyright © 2000 - 2009, Roxen IS.
//

#include <module.h>
inherit "module";

//<locale-token project="mod_insert_cached_href">LOCALE</locale-token>
#define LOCALE(X,Y)	_DEF_LOCALE("mod_insert_cached_href",X,Y)

constant cvs_version = "$Id$";

constant thread_safe = 1;
constant module_type = MODULE_TAG;
LocaleString module_name = LOCALE(1, "Tags: Insert cached href");
LocaleString module_doc  = LOCALE(2, "This module contains the RXML tag \"insert "
				     "cached-href\". Useful when implementing e.g."
				     " RSS syndication.");

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

constant MAX_REDIRECTS = 5;

private HrefDatabase href_database;

void create() {
  defvar("fetch-interval", "5 minutes", LOCALE(3, "Fetch interval"),
	 TYPE_STRING|VAR_MORE,
	 LOCALE(4, "States how often the data of an URL should be updated. "
		   "In seconds, minutes, hours or days."));
  
  defvar("fresh-time", "0", LOCALE(5, "Fresh time"),
	 TYPE_STRING|VAR_MORE,
	 LOCALE(6, "States how long data in the database can be considered fresh enough"
		   " to display. In seconds, minutes, hours or days. As default this"
		   " is 0, which means that this attribute is not used and that there"
		   " are no restrictions on data freshness."));
  
  defvar("ttl", "7 days", LOCALE(7, "Time to live"),
	 TYPE_STRING|VAR_MORE,
	 LOCALE(8, "States how long unrequested data can exist in the database"
		   " before being removed. In seconds, minutes, hours or days."));
 
  defvar("timeout", "10 seconds", LOCALE(9, "Timeout"),
	 TYPE_STRING|VAR_MORE,
	 LOCALE(10, "The timeout when fetching data from a server. In seconds, minutes, "
		   "hours or days."));
  
  defvar("update-interval", "1 minute", LOCALE(11, "Update interval"),
	 TYPE_STRING|VAR_MORE,
	 LOCALE(12, "States how often the module will check if the database needs to "
		   "be updated. In seconds, minutes, hours or days."));
  
  defvar("recursion_limit", 2, LOCALE(13, "Maximum recursion depth"),
	 TYPE_INT|VAR_MORE,
	 LOCALE(14,"Maximum number of nested <tt>&lt;insert cached-href&gt;</tt>'s "
		  "allowed. May be set to zero to disable the limit."));
}


void start(int occasion, Configuration conf) {
  if (occasion == 0) {
    href_database = HrefDatabase();
#ifdef THREADS
    initiated = ({});
    mutex = Thread.Mutex();
#endif
  }
  
#ifdef THREADS
  if (occasion == 2)
    bg_process && bg_process->stop();

  //  Check whether setup is ok before scheduling background task
  if (href_database) {
    if (href_database->ready_to_run()) {
      bg_process =
	roxen.BackgroundProcess(get_time_in_seconds(query("update-interval")), 
				href_database->update_db, 0); 
    } else {
      report_error("Insert cached href: Failed to initialize SQL tables. "
		   "Permission error?\n");
    }
  }
#endif
}

mapping(string:function) query_action_buttons()
{
  return ([LOCALE(15, "Clear database") : href_database->empty_db]);
}


void stop() {
#ifdef THREADS
  bg_process && bg_process->stop();
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

protected int get_time_in_seconds(string input) {
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

protected int(0..1) is_number(int char) {
  return (char >= 48 && char <= 57) ? 1 : 0;  
}

#ifdef THREADS
public int(0..1) already_initiated(string url) {
  foreach(initiated, HTTPClient client) {
    if (url == (string)client->url)
      return 1;
  }
  
  return 0;
}
#endif

public int(0..1) is_redirect(int status) {
  /*
    A 304 will never happen since the 
    GET is never conditional. 
  */
  if (status >= 300 && status < 400 && status != 304)
    return 1;
  
  return 0;
}

/*
  Takes action based on HTTP status codes in reply.
  Synchronous:
*/
public string get_result_sync(HTTPClient client, mapping args, mapping header) {
  if (!is_redirect(client->status) || !MAX_REDIRECTS)
    return decode_data(client->data(), client->con->headers, client->url);

  int counter;
  string location = client->con->headers->location;
  
  if (!location || !sizeof(location))
    return decode_data(client->data(), client->con->headers, client->url);

  DWRITE("Following redirect from " + (string)client->url + 
	 " to " + location);

  // Normalize; Some sites (dn.se) use relative locations.
  location = (string)Standards.URI(location, client->url);
  
  args["cached-href"] = location;
  HTTPClient new_client = HTTPClient(args, header);
  
  new_client->orig_url = (string)client->url;
  new_client->run();
  counter++;
  
  while (is_redirect(new_client->status) && counter < MAX_REDIRECTS) {
    location = new_client->con->headers->location;
    
    if (!location || !sizeof(location))
      return decode_data(new_client->data(), new_client->con->headers,
			 new_client->url);
    
    DWRITE("Following redirect from " + (string)new_client->url + 
	   " to " + location);
    
    location = (string)Standards.URI(location, new_client->url);
  
    args["cached-href"] = location;
    new_client = HTTPClient(args, header);
    new_client->orig_url = (string)client->url;
    new_client->run();
    counter++;
  }
  
  return decode_data(new_client->data(), new_client->con->headers,
		     new_client->url);
}

/*
  Takes action based on HTTP status codes in reply.
  Asynchronous:
*/
public void get_result_async(HTTPClient client, mapping args, mapping header) {
  if (!is_redirect(client->status))
    return;
  
  int redirects = client->redirects + 1;
  string location = client->con->headers->location;
  
  if (redirects > MAX_REDIRECTS ||
      !location ||
      !sizeof(location))
    return;
    
  DWRITE("Following redirect from " + (string)client->url + 
	 " to " + location);
  
  // Normalize; Some sites (dn.se) use relative locations.
  location = (string)Standards.URI(location, client->url);
  
  args["cached-href"] = location;
  HTTPClient new_client = HTTPClient(args, header);
  
  new_client->orig_url = client->orig_url;
  new_client->redirects = redirects;
  new_client->run();
}

public void|string fetch_url(mapping(string:mixed) to_fetch, void|mapping header) {
  DWRITE(sprintf("fetch_url(): To fetch: %s, with timeout: %d", to_fetch["url"], 
		 to_fetch["timeout"]));
  
  mapping(string:mixed) args = (["timeout":to_fetch["timeout"], 
				 "cached-href":to_fetch["url"],
				 "sync":to_fetch["sync"]]);

  object client;
  
#ifdef THREADS
  mutex_key = mutex->lock();
  
  if (!to_fetch["sync"] && already_initiated(to_fetch["url"])) {
    mutex_key = 0;
    return;
  }
  
  client = HTTPClient(args, header);
  initiated += ({client});
  mutex_key = 0;
  client->orig_url = (string)client->url;
  client->run();
  
  if (to_fetch["sync"]) 
    return get_result_sync(client, args, header);
#else
  client = Protocols.HTTP.get_url(to_fetch["url"], 0);

  // In practice a server never runs unthreaded. Keep it 
  // simple and only return when status code < 300:
  if(client && client->status > 0 && client->status < 300) {
    string data = decode_data(client->data(), client->headers, client->url);
    href_database->update_data(to_fetch["url"], data);
    return data;
  } else
    return "";
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
                                       "out_of_date INT UNSIGNED,"
				       "PRIMARY KEY (url, fetch_interval, "
				       "fresh_time, ttl, timeout, time_of_day)";
  
  private constant data_table_def = "url VARCHAR(255) NOT NULL,"
				    "data LONGBLOB,"
				    "latest_write INT UNSIGNED,"
				    "PRIMARY KEY (url)";

  private string request_table;
  private string data_table;
  
  public void create() {
    //  Failure to create tables will lead to zero return values.
    request_table = get_my_table("request", ({request_table_def}));
    data_table = get_my_table("data", ({data_table_def}));
    
    // If request_table exists but not the column out_of_date, create
    // indexed column out_of_date and populate it with the sum of
    // latest_request and ttl to optimize the remove_old_entrys.
    if(request_table && !sizeof(sql_query("DESCRIBE " + request_table + " out_of_date"))) {
      sql_query("ALTER TABLE " + request_table + " ADD COLUMN out_of_date INT UNSIGNED;");
      sql_query("ALTER TABLE " + request_table + " ADD INDEX " + request_table + "(out_of_date);");
    }
  }

  public void empty_db() {
    /* 
       Might as well clean up the database in a mutex section,
       just to be sure. No performance issue since this function is only
       supposed to be used when the "Clear database" button in the admin interface 
       is pressed.
    */
#ifdef THREADS
    mutex_key = mutex->lock();
#endif
    sql_query("DELETE FROM " + request_table);
    sql_query("DELETE FROM " + data_table);
    DWRITE("Database has been emptied.");
#ifdef THREADS
    mutex_key = 0;
#endif
  }
  
  public int ready_to_run()
  {
    //  Only ok to run if both tables are accessible
    return request_table && data_table && 1;
  }

  public void update_db() {
    DWRITE(sprintf("###########  update_db(): Called every %d seconds  ##########"
		   , get_time_in_seconds(query("update-interval"))));
   
#ifdef THREADS
    foreach(initiated, HTTPClient client) {
      DWRITE("STILL initiated (should be empty!!!!!): " + (string)client->url);
    }
#endif

#ifdef OFFLINE
    //  Don't alter entries when running server without network connections.
    return;
#endif
    
    remove_old_entrys();

    if (!nr_of_requests()) {
      DWRITE("There are no requests, returning from update_db()");
      return;
    }

    array(mapping(string:mixed)) to_fetch = urls_to_fetch();
    
    foreach(to_fetch, mapping next) {
      fetch_url(next, (["x-roxen-recursion-depth":1]));
    }
   
#ifdef THREADS
    foreach(initiated, HTTPClient client) {
      DWRITE("initiated: " + (string)client->url);
    }
#endif
 
    DWRITE("----------------- Leaving update_db() ------------------------");
  }
      
  public string get_data(mapping args, mapping header) {
    int next_fetch = 0;
    array(mapping(string:mixed)) result;
    int now = time();
    
    /* if the tag argument time-of-day is provided, the database column next_fetch
       needs to be calculated: */
    if (args["time-of-day"]) { 
      mapping now_lt = localtime(now);
      
      now_lt["hour"] = 0;
      now_lt["min"] = 0;
      now_lt["sec"] = 0;
      
      next_fetch = mktime(now_lt) + args["time-of-day"];
      
      if (next_fetch < now)
	next_fetch += 24 * 3600;
    }
    
#ifndef THREADS
    /* When running unthreaded the database still needs to be kept up-to-date */
    remove_old_entrys();
#endif
    
    string url = args["cached-href"];
    sql_query("UPDATE " + request_table +
	      "   SET latest_request = " + now + ", "
	      "       out_of_date = NULL "
	      " WHERE url = %s "
	      "   AND fetch_interval = %d "
	      "   AND fresh_time = %d "
	      "   AND ttl = %d "
	      "   AND timeout = %d "
	      "   AND time_of_day = %d",
	      url, args["fetch-interval"], args["fresh-time"], args["ttl"],
	      args["timeout"], args["time-of-day"]);

    
    sql_query("INSERT IGNORE INTO " + request_table +
	      " VALUES (%s, %d, %d, %d, %d, %d, %d, %d, %d)",
	      url,
	      args["fetch-interval"], args["fresh-time"], args["ttl"],
	      args["timeout"], args["time-of-day"], next_fetch, now, 
	      (args["ttl"] + now));
    
    sql_query("INSERT IGNORE INTO " + data_table +
	      " VALUES (%s, '', 0)", 
	      url);
    
    result = sql_query("SELECT data "
		       "  FROM " + data_table +
		       " WHERE url = %s " 
		       "   AND (" + now + " - latest_write < %d "
		       "    OR %d = 0)",
		       url, args["fresh-time"], args["fresh-time"]);
    
    if (result && sizeof(result) && result[0]["data"] != "") {
      DWRITE("get_data(): Returning cached data for " + url);
      
      return utf8_to_string(result[0]["data"]);
    } else if (!args["pure-db"]) {
      DWRITE("get_data(): No cached data existed for " + url +
	     " so performing a synchronous fetch");
      
      string data = fetch_url( ([ "url"     : url,
				  "timeout" : args["timeout"], 
				  "sync"    : 1]),
			       header);
      
      return data;
    } else {
      DWRITE("get_data(): No cached data existed for " + url +
	     " and pure-db data was desired, so simply returning the "
	     "empty string");
      
      return "";
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
  
  private int nr_of_requests() {
    return sizeof(sql_query("SELECT url from " + request_table));
  }
  
  private void remove_old_entrys() {
    
    sql_query("UPDATE " + request_table + 
	      " SET out_of_date = (latest_request + ttl)" + 
	      " WHERE out_of_date IS NULL" + 
	      " AND latest_request IS NOT NULL;");
    
    sql_query("DELETE FROM " + request_table +
	      "      WHERE " + time() + " > out_of_date");
    
    sql_query("    DELETE " + data_table +
	      "      FROM " + data_table +
	      " LEFT JOIN " + request_table +
	      "        ON " + data_table + ".url=" + request_table + ".url "
              "     WHERE " + request_table + ".url IS NULL");
  }
  
  private array(mapping(string:mixed)) urls_to_fetch() {
    array(mapping(string:mixed)) to_fetch = ({});
    int now = time();
    
    array(mapping(string:mixed)) result =
      sql_query("     SELECT " + data_table + ".url, " + request_table + ".timeout "
                "      FROM " + data_table +
		" LEFT JOIN " + request_table +
		"        ON " + data_table + ".url=" + request_table + ".url "
                "     WHERE " + data_table + ".data='' "
                "  ORDER BY url, timeout DESC");
    
    foreach(result, mapping row) {
      to_fetch = no_duplicate_add(to_fetch, row["url"], 0);
    }

    result = sql_query("    SELECT " + data_table + ".url, " + request_table + ".timeout, " 
		       + data_table + ".latest_write, " + request_table + 
		       ".fetch_interval "
		       "      FROM " + data_table +
		       " LEFT JOIN " + request_table +
		       "        ON " + data_table + ".url=" + request_table + ".url "
                       "     WHERE " + data_table + ".data!='' "
                       "       AND " + request_table + ".fetch_interval > 0 "
		       "       AND ((" + now + " - " + data_table + ".latest_write) > " + request_table + ".fetch_interval) "
                       "  ORDER BY url, timeout DESC");
    
    foreach(result, mapping row) {
      to_fetch = no_duplicate_add(to_fetch, row["url"], 0);
    }
    
    result = sql_query("    SELECT " + data_table + ".url, " + request_table + ".timeout, " 
		       + request_table + ".time_of_day, " + request_table + 
		       ".next_fetch "
		       "      FROM " + data_table +
		       " LEFT JOIN " + request_table +
		       "        ON " + data_table + ".url=" + request_table + ".url "
                       "     WHERE " + data_table + ".data!='' "
                       "       AND " + request_table + ".time_of_day > 0 "
                       "       AND " + now + " > " + request_table + ".next_fetch "
                       "  ORDER BY url, timeout DESC");
    
    foreach(result, mapping row) {
      to_fetch = no_duplicate_add(to_fetch, row["url"], 0);
    }
    
    result = sql_query("  SELECT url, max(timeout) "
		       "    FROM " + request_table + " AS url "
		       "GROUP BY url");
    
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
    DWRITE(sprintf("update_data(): Saving the fetched data to the db for url %s"
		   ,  url));
    
    sql_query("UPDATE " + data_table + " "
	      "   SET data=%s, latest_write=%d "
	      " WHERE url=%s", 
	      string_to_utf8(data), time(), url);
    
    sql_query("UPDATE " + request_table + " "
	      "   SET next_fetch=next_fetch + " + (24 * 3600) +
	      " WHERE time_of_day > 0 "
	      "   AND " + time(1) + " > next_fetch "
	      "   AND url=%s" , url);
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

    if (orig_args["fresh-time"] && 
	(valid_arg(orig_args["fresh-time"]) || orig_args["fresh-time"] == "0"))
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

    //  Verify that database connection is working
    if (!href_database || !href_database->ready_to_run())
      RXML.run_error("Insert cached href: Database connection not working. "
		     "Permission problems?\n");
    
    recursion_depth++;

    if(args->nocache)
      NOCACHE();
    else
      CACHE(60);

    string res = href_database->get_data(Attributes(args)->get_db_args(), 
					 (["x-roxen-recursion-depth":recursion_depth]));
    
    // DEPRECATED attribute 'decode-xml'. Keep it during transition period for upgrades, 
    // since there will be undecoded data in the database until the first fetch for each 
    // URL. The same type of decoding now occur upon saving the data in the database
    if(args["decode-xml"]) {
      // Parse xml header and recode content to internal representation.
      mixed result = catch {
        res = Parser.XML.Simple()->autoconvert(res);
      };
      
      // Remove any bytes potentially still preceeding the first '<' in the xml file
      return res[search(res, "<")..];
    }

    return res;
  }
} 

#ifdef THREADS

/* This class represents the retrieval of data from an URL */
class HTTPClient {
  int status, timeout, start_time, redirects;
  object con;
  Standards.URI url;
  string path, query, orig_url;
  mapping request_headers;
  Thread.Queue queue = Thread.Queue();
  int(0..1) sync;
  
  void create(mapping args, void|mapping _request_headers) {
    timeout = args["timeout"];
    sync = args["sync"];
    con = Protocols.HTTP.Query();

    if(!_request_headers)
      request_headers = ([]);
    else
      request_headers = _request_headers;
    
    if (mixed err = catch (url=Standards.URI(args["cached-href"])))
      RXML.parse_error ("Invalid URL: %s\n", describe_error (err));
    
#if constant(SSL.File)
    if(url->scheme!="http" && url->scheme!="https")
      error("Protocols.HTTP can't handle %O or any other protocols than HTTP or HTTPS\n",
	    url->scheme);
    
    con->https= (url->scheme=="https")? 1 : 0;
#else
    if(url->scheme!="http")
      error("Protocols.HTTP can't handle %O or any other protocol than HTTP\n",
	    url->scheme);
    
#endif
    
    if(!request_headers)
      request_headers = ([]);

    string host_header;
    if ((url->scheme == "http" && url->port == 80) ||
	(url->scheme == "https" && url->port == 443))
      host_header = sprintf("%s", url->host); // Omit ports when standard
    else
      host_header = sprintf("%s:%d", url->host, url->port);

    mapping default_headers = ([
      "user-agent" : "Mozilla/4.0 compatible (Pike HTTP client)",
      "host" : host_header ]);
    
    if(url->user)
      default_headers->authorization = "Basic "
	+ MIME.encode_base64(url->user + ":" +
			     (url->password || ""), 1);

    request_headers = default_headers | request_headers;
    query=url->query;
    path=url->path;
    
    if(path=="") path="/";
  }
  
  string data() {
    if(!con->ok)
      return "";
    
    if(status > 0 && status < 300)
      return con->data();
    
    return "";
  }
  
  void req_ok() {
    DWRITE("Received headers from " + (string)url + " OK");
    status = con->status;

    /*
      Error, abort:
    */
    if (status >= 400) {
      DWRITE("HTTP status code " + (string)status + " for " + (string)url + ", aborting.");
      finish_up();
      
      if (sync)
	queue->write("@");
      
      return;
    }

    /*
      Redirection:
    */
    if (is_redirect(status)) {
      finish_up();
      
      if (sync) {
	queue->write("@");
	return;
      }
      
      mapping args = (["cached-href" : (string)url,
		       "timeout"     : timeout,
		       "sync"        : 0]);
      get_result_async(this_object(), args, ([ "x-roxen-recursion-depth" : request_headers["x-roxen-recursion-depth"]]));
      
      return;
    }

    /*
      HTTP status code OK, continuing
      with data fetch:
    */
    int data_timeout = timeout - (time() - start_time);
    con->data_timeout = data_timeout >= 0 ? data_timeout : 0;
    con->timed_async_fetch(data_ok, data_fail);
  }
  
  void req_fail() {
    DWRITE("Receiving headers from " + (string)url + " FAILED");
    status = 0;
    finish_up();

    if (sync)
      queue->write("@");
  }
  
  void data_ok() {
    DWRITE("Received data from " + (string)url + " OK");
    status = con->status;
    finish_up();

    if (href_database)
      if (orig_url)
	href_database->update_data(orig_url,
				   decode_data(con->data(), con->headers,
					       orig_url));
      else
	href_database->update_data((string)url,
				   decode_data(con->data(), con->headers, url));
    
    if (sync)
      queue->write("@");
  }
  
  void data_fail() {
    DWRITE("Receiving data from " + (string)url + " FAILED");
    status = 0;
    finish_up();

    if (sync)
      queue->write("@");
  }
  
  private void finish_up() {
    mutex_key = mutex->lock();
    initiated -= ({this_object()});
    con->set_callbacks (0, 0);
    mutex_key = 0;
  }
  
  void run() {
    con->set_callbacks(req_ok, req_fail);
    con->timeout = timeout;
    start_time = time();

#ifdef ENABLE_OUTGOING_PROXY
    if (roxen.query("use_proxy")) {
      Protocols.HTTP.do_async_proxied_method(roxen.query("proxy_url"),
					     roxen.query("proxy_username"), 
					     roxen.query("proxy_password"),
					     "GET", url, 0,
					     request_headers, con);
    } else {
      con->async_request(url->host,url->port,
			 "GET "+path+(query?("?"+query):"")+" HTTP/1.0",
			 request_headers);
    }
#else
      con->async_request(url->host,url->port,
			 "GET "+path+(query?("?"+query):"")+" HTTP/1.0",
			 request_headers);
#endif

    status = con->status;

    if (sync) {
      DWRITE("Initiating synchronous fetch for " + (string)url);
      queue->read();
      DWRITE("Synchronous fetch for " + (string)url + " completed.");
    }
  }
}
#endif

/* 
   Decodes data based on 1) HTTP headers or 2) fallbacks on 
   data content, meta http-equiv for html and BOM + encoding='' 
   for xml 
*/
string decode_data(string data, mapping headers, string|Standards.URI url) {
  if (data == "" || !headers)
    return data;
  return Roxen.low_parse_http_response (
    headers, data, 0,
    "retrieved from " + (string) url + " by <insert cached-href>");
}

string remove_bom(string data) {
  return data[search(data, "<")..];
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([

  "insert#cached-href":#"<desc type='plugin'>
<p>
  <short>This tag inserts the contents of the provided URL,
  as read from a database.</short>
  The database is updated repeatedly in the background by a background
  process that is initiated and run as soon as this module is
  loaded. If the database is empty when the tag is executed, the
  standard behavior is to fetch the data immediately. When providing
  values for the attributes fetch-interval, fresh-time, ttl,
  update-interval or timeout, the time can either be seconds, minutes,
  hours or days. If only a number is provided, it is interpreted as
  seconds, otherwise write the corresponding letter or word after the
  number, e.g: 10 days, 10d, 10 h, 10hours, 5 min, 5m, 2 hours and so
  on. Spaces between the number and the word are allowed. The values
  at the settings tab for fetch-interval, fresh-time, ttl and timeout
  are the standard values that the tag will be assigned if an
  attribute is left out. update-interval on the other hand, is central
  and common for all tags.
</p>
<note>
 <p>
  The data in the database for an URL is always shared by all tags at
  the same site. This means that when data for an URL is updated this
  affects all tags referring to this specific URL, even if the other
  attributes may differ.  For example, if the same URL is referenced
  by one tag without the pure-db attribute and another tag WITH the
  pure-db attribute, the only guarantee is that the tag with the
  attribute pure-db never will generate a data fetch. The tag without
  the attribute still can.
 </p>
 <p>
  Another implication of the data being shared is for example if the
  same URL is referenced by two tags with different fetch
  intervals. The data will then be updated at the smallest of these
  two fetch intervals. Providing the time-of-day attribute will
  however always make the module fetch data when that time of day
  occur, without interference by any other tag referencing the same
  URL.
 </p>
 <p>
  Also important to note, is that since the fetching of the common
  data is performed centrally by the module, the timeout of every tag
  can not be used, of course. If several tags refer to the same URL
  but are provided with different timeouts, the longest timeout will
  be used. However, if there exists no data in the database for the
  URL of a tag when the tag is run, and the pure-db attribute is not
  provided, then the fetching of data will be performed for that
  specific tag and with the specified timeout.
 </p>
</note>
</desc>

<attr name='cached-href' value='string'>
<p>
 The URL of the page to be inserted.
</p>
</attr>

<attr name='fetch-interval' value='string'>
<p>
 States at what interval the background process will fetch the
 URL and update the database. 
</p>
</attr>

<attr name='time-of-day' value='string'>
<p>
 Can be provided as an alternative to fetch-interval, if a fetch should
 be performed once per day at a specific time. The provided time must be
 of the format hh:mm.
</p>
</attr>

<attr name='fresh-time' value='string'>
<p>
 States how long the data for the URL in the database is considered fresh.
</p>
</attr>

<attr name='ttl' value='string'>
<p>
 States how long unrequested data will exist in the database before being
 removed.
</p>
</attr>

<attr name='timeout' value='string'>
<p>
 The timeout for the fetching of new data from a server.
</p>
</attr>

<attr name='pure-db'>
<p>
 If provided, the tag will only return data stored in the database, i.e 
 never fetch data immediately if the database is empty. Instead, the 
 data will not be available until the background process has updated the
 database.
</p>
</attr>

<attr name='nocache' value='string'>
<p>
 If provided the resulting page will get a zero cache time in the RAM cache.
 The default time is up to 60 seconds depending on the cache limit imposed by
 other RXML tags on the same page.
</p>
</attr>

<attr name='decode-xml' value='string'>
<p>
 <i>(DEPRECATED. All text content is now decoded automatically.)</i>
 If provided the resulting content will be decoded to the internal
 charset representation by looking at a potential BOM (Byte Order
 Mark) and the specified encoding in the XML header. Defaults to UTF-8
 if no BOM or encoding was found.
</p>
</attr>",
]);
#endif


