// This file is part of Roxen Webserver.
// Copyright © 1996 - 2000, Roxen IS.
// $Id: global_variables.pike,v 1.40 2000/08/17 16:54:19 lange Exp $

/*
#pragma strict_types
*/
#define DEFVAR string,int|string,string|mapping,int,string|mapping(string:string),void|array(string),void|function:void
#define BDEFVAR string,int|string,string|mapping,int,string|mapping(string:string),void|array(string),void|mapping(string:mapping(string:string)):void

#include <module.h>
#include <roxen.h>
#include <config.h>
inherit "read_config";
inherit "basic_defvar";
#include <version.h>

//<locale-token project="roxen_config">LOCALE</locale-token>
static inline string GETLOCLANG() {
  return roxenp()->locale->get();
}
#define LOCALE(X,Y)  _DEF_LOCALE("roxen_config",X,Y)

mixed save()
{
  store( "Variables", variables, 0, 0 );
}

// The following three functions are used to hide variables when they
// are not used. This makes the user-interface clearer and quite a lot
// less clobbered.

private int cache_disabled_p() { return !QUERY(cache);         }
private int syslog_disabled()  { return QUERY(LogA)!="syslog"; }
private int ident_disabled_p() { return [int(0..1)]QUERY(default_ident); }


// And why put these functions here, you might righfully ask.

// The answer is that there is actually a reason for it, it's for
// performance reasons. This file is dumped to a .o file, roxen.pike
// is not.


void set_up_ftp_variables( object o )
{
  function(DEFVAR) defvar =
   [function(DEFVAR)] o->defvar;


  defvar( "FTPWelcome",
          "              +------------------------------------------------\n"
          "              +--      Welcome to the Roxen FTP server      ---\n"
          "              +------------------------------------------------\n",
	  LOCALE(60, "Welcome text"), TYPE_TEXT,
          LOCALE(61, "The text shown to the user on connect") );

  defvar( "ftp_user_session_limit", 0, LOCALE(62, "User session limit"), 
	  TYPE_INT,
          LOCALE(63, "The maximum number of times a user can connect at once."
          " 0 means unlimited.") );

  defvar( "named_ftp", 1,  LOCALE(64, "Allow named ftp"), TYPE_FLAG,
          LOCALE(65, "If yes, non-anonymous users can connect") );

  defvar( "guest_ftp", 1, 
	  LOCALE(66, "Allow login with incorrect password/user"), 
	  TYPE_FLAG,
          LOCALE(67, "If yes, users can connect with the wrong password "
		 "and/or username. This is useful since things like .htaccess "
		 "files can later on authenticate the user."));

  defvar( "anonymous_ftp", 1, LOCALE(68, "Allow anonymous ftp"), 
	  TYPE_FLAG,
          LOCALE(69, "If yes, anonymous users is allowed to connect.") );

  defvar( "shells", "",  LOCALE(70, "Shell database"), 
	  TYPE_FILE,
          LOCALE(71, "If this string is set to anything but the empty string, "
          "it should point to a file containing a list of valid shells. "
          "Users with shells that does not figure in this list will not "
          "be allowed to log in.") );
}


void set_up_http_variables( object o, int|void fhttp )
{
  function(DEFVAR) defvar =
    [function(DEFVAR)] o->defvar;

  defvar("show_internals", 1, LOCALE(72, "Show internal errors"), 
	 TYPE_FLAG,
	 LOCALE(73, "Show 'Internal server error' messages to the user. "
		"This is very useful if you are debugging your own modules "
		"or writing Pike scripts."));

  if(!fhttp)
  {
    defvar("set_cookie", 0, LOCALE(74, "Logging: Set unique user id cookies"),
	   TYPE_FLAG,
	   LOCALE(75, "If set to Yes, all users of your server whose clients "
		  "support cookies will get a unique 'user-id-cookie', this "
		  "can then be used in the log and in scripts to track "
		  "individual users."));

    defvar("set_cookie_only_once", 1, 
	   LOCALE(76, "Logging: Set ID cookies only once"),
           TYPE_FLAG,
	   LOCALE(77, "If set to Yes, Roxen will attempt to set unique user "
		  "ID cookies only upon receiving the first request (and "
		  "again after some minutes). Thus, if the user doesn't allow "
		  "the cookie to be set, she won't be bothered with "
		  "multiple requests."),0 ,
	   lambda() {return !QUERY(set_cookie);});
  }
}

void set_up_fhttp_variables( object o )
{
  function(BDEFVAR) defvar =
    [function(BDEFVAR)] o->defvar;

  defvar( "log", "None", LOCALE(78, "Logging method"),
	  TYPE_STRING_LIST,
	  LOCALE(79, "None - No log<br />"
		 "CommonLog - A common log in a file<br />"
		 "Compat - Log through Roxen's normal logging format.<br />"
		 "<p>Please note that compat limits Roxen to less than 1k "
		 "requests/second.</p>"),
          ({ "None", "CommonLog", "Compat" }));

  defvar( "log_file", "$LOGDIR/clog-"+[string]o->ip+":"+[string]o->port,
	  LOCALE(80, "Log file"),
	  TYPE_FILE,
	  LOCALE(81, "This file is used if logging is done using the "
		 "CommonLog method."));

  defvar( "ram_cache", 20, LOCALE(82, "Ram cache"),
	  TYPE_INT,
	  LOCALE(83, "The size of the ram cache, in MegaBytes"));

  defvar( "read_timeout", 120, LOCALE(84, "Client timeout"),
	  TYPE_INT,
	  LOCALE(85, "The maximum time Roxen will wait for a client "
		 "before giving up, and close the connection, in seconds"));

  set_up_http_variables( o,1 );

}

void set_up_ssl_variables( object o )
{
  function(DEFVAR) defvar =
    [function(DEFVAR)] o->defvar;

  defvar( "ssl_cert_file", "demo_certificate.pem",
	  LOCALE(86, "SSL certificate file"),
	  TYPE_STRING,
	  sprintf(LOCALE(87, "The SSL certificate file to use. The path "
			 "is relative to %s")+"\n", getcwd() ));


  defvar( "ssl_key_file", "", LOCALE(88, "SSL key file"),
	  TYPE_STRING,
	  sprintf(LOCALE(89, "The SSL key file to use. The path is "
			 "relative to %s, you do not have to specify a key "
			 "file, leave this field empty to use the certificate "
			 "file only")+"\n", getcwd() ));
}


// Get the current domain. This is not as easy as one could think.
string get_domain(int|void l)
{
  array f;
  string t, s;

  // FIXME: NT support.

  t = Stdio.read_bytes("/etc/resolv.conf");
  if(t)
  {
    if(!sscanf(t, "domain %s\n", s))
      if(!sscanf(t, "search %s%*[ \t\n]", s))
        s="nowhere";
  } else {
    s="nowhere";
  }
  s = "host."+s;
  sscanf(s, "%*s.%s", s);
  if(s && strlen(s))
  {
    if(s[-1] == '.') s=s[..strlen(s)-2];
    if(s[0] == '.') s=s[1..];
  } else {
    s="unknown";
  }
  return s;
}


class PortOptions
{
  inherit Variable.Variable;
  constant type = "PortOptions";

  int check_visibility(object id, int a, int b, int c, int d) { return 0;  }
  void set_from_form(object id ) { return; }
  void create()
  {
    ::create( ([]), 0, 0, 0 );
  }
};

void define_global_variables(  )
{
  int p;

  defvar("port_options", PortOptions());

  defvar("RestoreConnLogFull", 0,
	  LOCALE(90, "Logging: Log entire file length in restored connections"),
	  TYPE_FLAG,
	  LOCALE(91, "If this toggle is enabled log entries for restored connections "
	  "will log the amount of sent data plus the restoration location. "
	  "Ie if a user has downloaded 100 bytes of a file already, and makes "
	  "a Range request fetching the remaining 900 bytes, the log entry "
	  "will log it as if the entire 1000 bytes were downloaded. "
	  "<p>This is useful if you want to know if downloads were successful "
	  "(the user has the complete file downloaded). The drawback is that "
	  "bandwidth statistics on the log file will be incorrect. The "
	  "statistics in Roxen will continue being correct."));

  defvar("default_font", "franklin_gothic_demi", LOCALE(92, "Default font"), 
	 TYPE_FONT,
	 LOCALE(93, "The default font to use when modules request a font."));

  defvar("font_dirs", ({"../local/nfonts/", "nfonts/" }),
	 LOCALE(94, "Font directories"), 
	 TYPE_DIR_LIST,
	 LOCALE(95, "This is where the fonts are located."));

  defvar("logdirprefix", "../logs/", 
	 LOCALE(96, "Logging: Log directory prefix"),
	 TYPE_STRING|VAR_MORE,
	 LOCALE(97, "This is the default file path that will be prepended "
		"to the log file path in all the default modules and the "
		"virtual server."));

  defvar("cache", 0, LOCALE(98, "Cache: Proxy Disk Cache Enabled"), 
	 TYPE_FLAG,
	 LOCALE(99, "If set to Yes, caching will be enabled."));

  defvar("garb_min_garb", 1, 
	 LOCALE(100, "Cache: Proxy Disk Cache Clean size"),
	 TYPE_INT,
	 LOCALE(101, "Minimum number of Megabytes removed when a garbage collect is done."),
	  0, cache_disabled_p);

  defvar("cache_minimum_left", 5,
	 LOCALE(102, "Cache: Proxy Disk Cache Minimum available free space and inodes (in %)"), 
	 TYPE_INT,
	 LOCALE(103, "If less than this amount of disk space or inodes (in %) "
		"is left, the cache will remove a few files. This check may "
		"work half-hearted if the diskcache is spread over several "
		"filesystems."),
	 0,
#if constant(filesystem_stat)
	 cache_disabled_p
#else
	 1
#endif /* filesystem_stat */
	 );

  defvar("cache_size", 25, LOCALE(104, "Cache: Proxy Disk Cache Size"), 
	 TYPE_INT,
	 LOCALE(105, "How many MB may the cache grow to before a garbage "
		"collect is done?"),
	 0, cache_disabled_p);

  defvar("cache_max_num_files", 0,
	 LOCALE(106, "Cache: Proxy Disk Cache Maximum number of files"), 
	 TYPE_INT, 
	 LOCALE(107, "How many cache files (inodes) may be on disk before "
		"a garbage collect is done ? May be left zero to disable "
		"this check."),
	 0, cache_disabled_p);

  defvar("bytes_per_second", 50,
	 LOCALE(108, "Cache: Proxy Disk Cache bytes per second"),
	 TYPE_INT,
	 LOCALE(109, "How file size should be treated during garbage collect. "
	  "Each X bytes counts as a second, so that larger files will "
	  "be removed first."),
	  0, cache_disabled_p);

  defvar("cachedir", "/tmp/roxen_cache/",
	  LOCALE(110, "Cache: Proxy Disk Cache Base Cache Dir"),
	  TYPE_DIR,
	  LOCALE(111, "This is the base directory where cached files will "
		 "reside. To avoid mishaps, 'roxen_cache/' is always "
		 "prepended to this variable."),
	 0, cache_disabled_p);

  defvar("hash_num_dirs", 500,
	 LOCALE(112, "Cache: Proxy Disk Cache Number of hash directories"),
	 TYPE_INT|VAR_MORE,
	 LOCALE(113, "This is the number of directories to hash the contents "
		"of the disk cache into.  Changing this value currently "
		"invalidates the whole cache, since the cache cannot find "
		"the old files.  In the future, the cache will be "
		"recalculated when this value is changed."),
	 0, cache_disabled_p);

  defvar("cache_keep_without_content_length", 1,
	 LOCALE(114, "Cache: Proxy Disk Cache Keep without Content-Length"),
	 TYPE_FLAG, 
	 LOCALE(115, "Keep files without Content-Length header information "
		"in the cache?"),
	 0, cache_disabled_p);

  defvar("cache_check_last_modified", 0,
	 LOCALE(116, "Cache: Proxy Disk Cache Refreshes on Last-Modified"), 
	 TYPE_FLAG,
	 LOCALE(117, "If set, refreshes files without Expire header "
		"information when they have reached double the age they had "
		"when they got cached. This may be useful for some regularly "
		"updated docs as online newspapers."),
	 0, cache_disabled_p);

  defvar("cache_last_resort", 0,
	 LOCALE(118, "Cache: Proxy Disk Cache Last resort (in days)"), 
	 TYPE_INT,
	 LOCALE(119, "How many days shall files without Expires and without "
		"Last-Modified header information be kept?"),
	 0, cache_disabled_p);

  defvar("cache_gc_logfile",  "",
	 LOCALE(120, "Cache: Proxy Disk Cache Garbage collector logfile"), 
	 TYPE_FILE,
	 LOCALE(121, "Information about garbage collector runs, removed and "
		"refreshed files, cache and disk status goes here."),
	 0, cache_disabled_p);

  /// End of cache variables..

  defvar("pidfile", "/tmp/roxen_pid_$uid", LOCALE(122, "PID file"),
	 TYPE_FILE|VAR_MORE,
	 LOCALE(123, "In this file, the server will write out it's PID, and "
		"the PID of the start script. $pid will be replaced with the "
		"pid, and $uid with the uid of the user running the process.\n"
		"<br />Note: It can be overridden by the command line option."));
  
  // FIXME: Should mention real_version.
  defvar("default_ident", 1, 
	 LOCALE(124, "Identify, Use default identification string"),
	 TYPE_FLAG|VAR_MORE,
	 LOCALE(125, "Setting this variable to No will display "
		"the \"Identify as\" node where you can state what Roxen "
		"should call itself when talking to clients.<br />"
	  "It is possible to disable this so that you can enter an "
	  "identification-string that does not include the actual version of "
	  "Roxen, as recommended by the HTTP/1.0 draft 03:<p><blockquote><i>"
	  "Note: Revealing the specific software version of the server "
	  "may allow the server machine to become more vulnerable to "
	  "attacks against software that is known to contain security "
	  "holes. Server implementors are encouraged to make this field "
	  "a configurable option.</i></blockquote></p>"));

  defvar("ident", replace(real_version," ","·"), 
	 LOCALE(126, "Identify, Identify as"),
	 TYPE_STRING /* |VAR_MORE */,
	 LOCALE(127, "Enter the name that Roxen should use when talking to clients. "),
	 0, ident_disabled_p);
  
  defvar("User", "", LOCALE(128, "Change uid and gid to"), 
	 TYPE_STRING,
	 LOCALE(129, "When roxen is run as root, to be able to open port 80 "
		"for listening, change to this user-id and group-id when the "
		"port has been opened. If you specify a symbolic username, "
		"the default group of that user will be used. "
		"The syntax is user[:group]."));

  defvar("permanent_uid", 0, LOCALE(130, "Change uid and gid permanently"),
	 TYPE_FLAG,
	 LOCALE(131, "If this variable is set, roxen will set it's uid and gid "
	  "permanently. This disables the 'exec script as user' fetures "
	  "for CGI, and also access files as user in the filesystems, but "
	  "it gives better security."));

  // FIXME: Should mention getcwd()
  defvar("ModuleDirs", ({ "../local/modules/", "modules/" }),
	 LOCALE(132, "Module directories"), 
	 TYPE_DIR_LIST,
	 LOCALE(133, "This is a list of directories where Roxen should look "
		"for modules. Can be relative paths, from the "
		"directory you started Roxen. "
		"The directories are searched in order for modules."));

  defvar("Supports", "#include <etc/supports>\n",
	 LOCALE(134, "Client supports regexps"), 
	 TYPE_TEXT_FIELD|VAR_MORE,
	 LOCALE(135, "What do the different clients support?\n<br />"
	  "The default information is normally fetched from the file "
	  "server/etc/supports in your Roxen directory."));

  defvar("audit", 0, LOCALE(136, "Logging: Audit trail"), 
	 TYPE_FLAG,
	 LOCALE(137, "If Audit trail is set to Yes, all changes of uid will be "
		"logged in the Event log."));

#if efun(syslog)
  defvar("LogA", "file", LOCALE(138, "Logging: Logging method"), 
	 TYPE_STRING_LIST|VAR_MORE,
	 LOCALE(139, "What method to use for logging, default is file, but "
	  "syslog is also available. When using file, the output is really"
	  " sent to stdout and stderr, but this is handled by the "
	  "start script."),
	 ({ "file", "syslog" }));

  defvar("LogSP", 1, LOCALE(140, "Logging: Log PID"), 
	 TYPE_FLAG,
	 LOCALE(141, "If set, the PID will be included in the syslog."), 0,
	 syslog_disabled);

  defvar("LogCO", 0, LOCALE(142, "Logging: Log to system console"), 
	 TYPE_FLAG,
	 LOCALE(143, "If set and syslog is used, the error/debug message "
		"will be printed to the system console as well as to the "
		"system log."),
	  0, syslog_disabled);

  defvar("LogST", "Daemon", LOCALE(144, "Logging: Syslog type"), 
	 TYPE_STRING_LIST,
	 LOCALE(145, "When using SYSLOG, which log type should be used."),
	 ({ "Daemon", "Local 0", "Local 1", "Local 2", "Local 3",
	    "Local 4", "Local 5", "Local 6", "Local 7", "User" }),
	 syslog_disabled);

  defvar("LogWH", "Errors", LOCALE(146, "Logging: Log what to syslog"), 
	 TYPE_STRING_LIST,
	 LOCALE(147, "When syslog is used, how much should be sent to it?<br /><hr />"
		"Fatal:    Only messages about fatal errors<br />"
		"Errors:   Only error or fatal messages<br />"
		"Warning:  Warning messages as well<br />"
		"Debug:    Debug messager as well<br />"
		"All:      Everything<br />"),
	 ({ "Fatal", "Errors",  "Warnings", "Debug", "All" }),
	 syslog_disabled);

  defvar("LogNA", "Roxen", LOCALE(148, "Logging: Log as"), 
	 TYPE_STRING,
	 LOCALE(149, "When syslog is used, this will be the identification "
		"of the Roxen daemon. The entered value will be appended to "
		"all logs."),
	 0, syslog_disabled);
#endif

#ifdef THREADS
  defvar("numthreads", 5, LOCALE(150, "Number of threads to run"), 
	 TYPE_INT,
	 LOCALE(151, "The number of simultaneous threads Roxen will use.\n"
	  "<p>Please note that even if this is one, Roxen will still "
	  "be able to serve multiple requests, using a select loop based "
	  "system.\n"
	  "<i>This is quite useful if you have more than one CPU in "
	  "your machine, or if you have a lot of slow NFS accesses.</i></p>"));
#endif

#if 0
  defvar("AutoUpdate", 1, 
	 LOCALE(152, "Update the supports database automatically"),
	 TYPE_FLAG,
	 LOCALE(153, "If set to Yes, the etc/supports file will be updated "
		"automatically from www.roxen.com now and then. This is "
		"recomended, since you will then automatically get supports "
		"information for new clients, and new versions of old ones."));

  defvar("next_supports_update", time(1)+3600, "", TYPE_INT,"",0,1);
#endif

#ifndef __NT__
  defvar("abs_engage", 0, LOCALE(154, "ABS: Enable Anti-Block-System"), 
	 TYPE_FLAG|VAR_MORE,
	 LOCALE(155, "If set, the anti-block-system will be enabled. "
		"This will restart the server after a configurable number of minutes if it "
		"locks up. If you are running in a single threaded environment heavy "
		"calculations will also halt the server. In multi-threaded mode bugs such as "
		"eternal loops will not cause the server to reboot, since only one thread is "
		"blocked. In general there is no harm in having this option enabled. "));

  defvar("abs_timeout", 5, LOCALE(156, "ABS: Timeout"),
	 TYPE_INT_LIST|VAR_MORE,
	 LOCALE(157, "If the server is unable to accept connection for this many "
		"minutes, it will be restarted. You need to find a balance: "
		"if set too low, the server will be restarted even if it's doing "
		"legal things (like generating many images), if set too high you might "
		"get a long downtime if the server for some reason locks up."),
	 ({1,2,3,4,5,10,15}),
	 lambda() {return !QUERY(abs_engage);});
#endif


  defvar("locale", "standard", LOCALE(158, "Default language"), 
	 TYPE_STRING_LIST,
	 LOCALE(159, "Locale, used to localize all messages in Roxen.\n"
		"Standard means using the default locale, which varies "
		"according to the value of the 'LANG' environment variable."),
#if constant(Locale.list_languages)
#define LANGLIST   Locale.list_languages("roxen_config")
#else
#define LANGLIST   RoxenLocale.list_languages("roxen_config")
#endif
	 mkmapping(LANGLIST, map(LANGLIST, 
#if constant(Standards.ISO639_2)
				 Standards.ISO639_2.get_language,
#else
				 RoxenLocale.ISO639_2.get_language,
#endif
				 )) + (["standard":"Standard"])
#undef LANGLIST
	 );
	 

  defvar("suicide_engage", 0,
	 LOCALE(160, "Auto Restart: Enable Automatic Restart"),
	 TYPE_FLAG|VAR_MORE,
	 LOCALE(161, "If set, Roxen will automatically restart after a "
		"configurable number of days. Since Roxen uses a monolith, "
		"non-forking server model the process tends to grow in size "
		"over time. This is mainly due to heap fragmentation but also "
		"because of memory leaks.")
	  );

  defvar("suicide_timeout", 7,
	 LOCALE(162, "Auto Restart: Timeout"),
	 TYPE_INT_LIST|VAR_MORE,
	 LOCALE(163, "Automatically restart the server after this many days."),
	 ({1,2,3,4,5,6,7,14,30}),
	 lambda(){return !QUERY(suicide_engage);});

  defvar("argument_cache_in_db", 0,
         LOCALE(164, "Cache: Store the argument cache in a mysql database"),
         TYPE_FLAG|VAR_MORE,
         LOCALE(165, "If set, store the argument cache in a mysql "
	 "database. This is very useful for load balancing using multiple "
         "Roxen servers, since the mysql database will handle "
	 "synchronization."));

  defvar("argument_cache_db_path", "mysql://localhost/roxen",
	 LOCALE(166, "Cache: Argument Cache Database URL to use"),
	 TYPE_STRING|VAR_MORE,
	 LOCALE(167, "The database to use to store the argument cache."),
	 0,
	 lambda(){ return !QUERY(argument_cache_in_db); });

  defvar("argument_cache_dir", "$VARDIR/cache/",
	 LOCALE(168, "Cache: Argument Cache Directory"),
	 TYPE_DIR|VAR_MORE,
         LOCALE(169, "The cache directory to use to store the argument cache."
	 " Please note that load balancing is not available for most modules "
         " (such as gtext, diagram etc) unless you use a mysql database to "
         "store the argument cache meta data."));

  defvar("mem_cache_gc", 300,
	 LOCALE(170, "Cache: Memory Cache Garbage Collect Interval"),
	 TYPE_INT,
	 LOCALE(171, "The number of seconds between every garbage collect "
	 "(removal of old content) from the memory cache. The "
	 "memory cache is used for various tasks like remebering "
	 "what supports flags matches what client."));

  defvar("config_file_comments", 0,
	 LOCALE(172, "Commented config files"),
	 TYPE_FLAG,
	 LOCALE(173, "Save the variable documentation strings as comments "
		"in the configuration files. Only useful if you read or "
		"edit the config files directly."));
}


void restore_global_variables()
{
  setvars(retrieve("Variables", 0));
}

static mapping(string:mixed) __vars = ([ ]);

// These two should be documented somewhere. They are to be used to
// set global, but non-persistent, variables in Roxen.
mixed set_var(string var, mixed to)
{
  return __vars[var] = to;
}

mixed query_var(string var)
{
  return __vars[var];
}
