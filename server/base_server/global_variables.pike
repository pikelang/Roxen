// This file is part of Roxen Webserver.
// Copyright © 1996 - 2000, Roxen IS.
// $Id: global_variables.pike,v 1.34 2000/07/11 17:24:58 lange Exp $

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

//<locale-token project="base_server">LOCALE</locale-token>
static inline object GETLOCOBJ() {
 return roxenp()->locale->get()->base_server;
}
#define LOCALE(X,Y)  _DEF_LOCALE(X,Y)

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


// And why put these functions here, you might rightully ask.

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
	  LOCALE("", "Welcome text"), TYPE_TEXT,
          LOCALE("", "The text shown the the user on connect") );

  defvar( "ftp_user_session_limit", 0, LOCALE("", "User session limit"), TYPE_INT,
          LOCALE("", "The maximum number of times a user can connect at once."
          " 0 means unlimited.") );

  defvar( "named_ftp", 1,  LOCALE("", "Allow named ftp"), TYPE_FLAG,
          LOCALE("", "If yes, non-anonymous users can connect") );

  defvar( "guest_ftp", 1, LOCALE("", "Allow login with incorrect password/user"), TYPE_FLAG,
          LOCALE("", "If yes, users can connect with the wrong password and/or username"
          ". This is useful since things like .htaccess files can later on "
          "authenticate the user."));

  defvar( "anonymous_ftp", 1, LOCALE("", "Allow anonymous ftp"), TYPE_FLAG,
          LOCALE("", "If yes, anonymous users is allowed to connect.") );

  defvar( "shells", "",  LOCALE("", "Shell database"), TYPE_FILE,
          LOCALE("", "If this string is set to anything but the empty string, "
          "it should point to a file containing a list of valid shells. "
          "Users with shells that does not figure in this list will not "
          "be allowed to log in.") );
}


void set_up_http_variables( object o, int|void fhttp )
{
  function(DEFVAR) defvar =
    [function(DEFVAR)] o->defvar;
  function(string,string,string,string:void) deflocaledoc =
    [function(string,string,string,string:void)] o->deflocaledoc;

  defvar("show_internals", 1, LOCALE("", "Show internal errors"), TYPE_FLAG,
	 LOCALE("", "Show 'Internal server error' messages to the user. "
		"This is very useful if you are debugging your own modules "
		"or writing Pike scripts."));

  if(!fhttp)
  {
    defvar("set_cookie", 0, LOCALE("", "Logging: Set unique user id cookies"), TYPE_FLAG,
	   LOCALE("", "If set to Yes, all users of your server whose clients support "
		  "cookies will get a unique 'user-id-cookie', this can then be "
		  "used in the log and in scripts to track individual users."));

    defvar("set_cookie_only_once", 1, LOCALE("", "Logging: Set ID cookies only once"),
           TYPE_FLAG,
	   LOCALE("", "If set to Yes, Roxen will attempt to set unique user ID cookies "
		  "only upon receiving the first request (and again after some minutes). Thus, if "
		  "the user doesn't allow the cookie to be set, she won't be bothered with "
		  "multiple requests."),0 ,
	   lambda() {return !QUERY(set_cookie);});
  }
}

void set_up_fhttp_variables( object o )
{
  function(BDEFVAR) defvar =
    [function(BDEFVAR)] o->defvar;
  function(string,string,string,string:void) deflocaledoc =
    [function(string,string,string,string:void)] o->deflocaledoc;

  defvar( "log", "None",
	  [mapping(string:string)]
          (["standard":"Logging method",
            "svenska":"Loggmetod",
            "deutsch": "Logging-Methode", ]), TYPE_STRING_LIST,
          (["standard":
            "None - No log<br />"
            "CommonLog - A common log in a file<br />"
            "Compat - Log though roxen's normal logging format.<br />"
            "<p>Please note that compat limits roxen to less than 1k "
            "requests/second.</p>",
            "svenska":
            "Ingen - Logga inte alls<br />"
            "Commonlog - Logga i en commonlogfil<br />"
            "Kompatibelt - Logga som vanligt. Notera att det inte går "
            "speciellt fort att logga med den här metoden, det begränsar "
            "roxens hastighet till strax under 1000 requests/sekund på "
            "en normalsnabb dator år 1999.",
            "deutsch":
            "Keine - Kein Logfile<br />"
            "CommonLog - Logging nach dem CommonLog-Format<br />"
            "Compat - Mit Roxen's normalem Format arbeiten.<br />"
            "<p>Hinweis: Die Compat-Methode beschränkt Roxen auf "
            "1000 Zugriffe/Sekunde.",
          ]),
          ({ "None", "CommonLog", "Compat" }),
          ([ "svenska":
             ([
               "None":"Ingen",
               "CommonLog":"Commonlog",
               "Compat":"Kompatibel",
             ]),
             "deutsch":
             ([
               "None":"Keine",
               "CommonLog":"CommonLog",
               "Compat":"Compat",
             ]),
          ]) );

  defvar( "log_file", "$LOGDIR/clog-"+[string]o->ip+":"+[string]o->port,
          ([ "standard":"Log file",
             "svenska":"Logfil",
             "deutsch":"Logdatei", ]), TYPE_FILE,
          ([ "svenska":"Den här filen används om man loggar med "
             " commonlog metoden.",
             "standard":"This file is used if logging is done using the "
             "CommonLog method.",
             "deutsch":"Diese Datei wird zum Logging im CommonLog-Format "
             "benutzt."
          ]));

  defvar( "ram_cache", 20,
          (["standard":"Ram cache",
            "svenska":"Minnescache",
            "deutsch":"Speicher-Cache"]), TYPE_INT,
          (["standard":"The size of the ram cache, in MegaBytes",
            "svenska":"Storleken hos minnescachen, i Megabytes",
            "deutsch":"Die Größe des Speicher-Caches, in Megabytes"]));

  defvar( "read_timeout", 120,
          ([ "standard":"Client timeout",
             "svenska":"Klienttimeout",
             "deutsch":"Client-Timout" ]),TYPE_INT,
          ([ "standard":"The maximum time roxen will wait for a "
             "client before giving up, and close the connection, in seconds",
             "svenska":"Maxtiden som roxen väntar innan en klients "
             "förbindelse stängs, i sekunder",
             "deutsch":"Die maximale Zeit in Sekunden, die Roxen wartet, "
             "bevor die Verbindung zum Client abgebrochen wird" ]) );


  set_up_http_variables( o,1 );

}

void set_up_ssl_variables( object o )
{
  function(DEFVAR) defvar =
    [function(DEFVAR)] o->defvar;
  function(string,string,string,string:void) deflocaledoc =
    [function(string,string,string,string:void)] o->deflocaledoc;

  defvar( "ssl_cert_file", "demo_certificate.pem",
          ([
            "standard":"SSL certificate file",
            "svenska":"SSL-certifikatsfil",
            "deutsch":"SSL-Zertifikatsdatei"
          ]), TYPE_STRING,
          ([
            "standard":"The SSL certificate file to use. The path "
            "is relative to "+getcwd()+"\n",
            "svenska":"SSLcertifikatfilen som den här porten ska använda."
            " Filnamnet är relativt "+getcwd()+"\n",
            "deutsch":"Die SSL-Zertifikatsdatei, die verwendet werden soll. "
            "Der Pfad ist relativ zu "+getcwd()+"\n"
          ]) );


  defvar( "ssl_key_file", "",
          ([
            "standard":"SSL key file",
            "svenska":"SSL-nyckelfil",
            "deutsch":"SSL-Schlüsseldatei"
          ]),          TYPE_STRING,
          ([
            "standard":"The SSL key file to use. The path "
            "is relative to "+getcwd()+", you do not have to specify a key "
            "file, leave this field empty to use the certificate file only\n",
            "svenska":"SSLnyckelfilen som den här porten ska använda."
            " Filnamnet är relativt "+getcwd()+". Du behöver inte ange en "
            "nyckelfil, lämna det här fältet tomt om du bara har en "
            "certifikatfil\n",
            "deutsch":"Die SSL-Schlüsseldatei, die verwendet werden soll. "
            "Der Pfad ist relativ zu "+getcwd()+".  Die Schlüsseldatei muß "
            "nicht angeben werden, sondern man kann dieses Feld leer lassen "
            "und nur mit der Zertifikatsdatei arbeiten\n",
          ]) );
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
	  LOCALE("", "Logging: Log entire file length in restored connections"),
	  TYPE_TOGGLE,
	  LOCALE("", "If this toggle is enabled log entries for restored connections "
	  "will log the amount of sent data plus the restoration location. "
	  "Ie if a user has downloaded 100 bytes of a file already, and makes "
	  "a Range request fetching the remaining 900 bytes, the log entry "
	  "will log it as if the entire 1000 bytes were downloaded. "
	  "<p>This is useful if you want to know if downloads were successful "
	  "(the user has the complete file downloaded). The drawback is that "
	  "bandwidth statistics on the log file will be incorrect. The "
	  "statistics in Roxen will continue being correct."));

  defvar("default_font", "franklin_gothic_demi", LOCALE("", "Default font"), TYPE_FONT,
	  LOCALE("", "The default font to use when modules request a font."));

  defvar("font_dirs", ({"../local/nfonts/", "nfonts/" }),
	  LOCALE("", "Font directories"), TYPE_DIR_LIST,
	  LOCALE("", "This is where the fonts are located."));

  defvar("logdirprefix", "../logs/", LOCALE("", "Logging: Log directory prefix"),
	  TYPE_STRING|VAR_MORE,
	  LOCALE("", "This is the default file path that will be prepended to the log "
		 "file path in all the default modules and the virtual server."));

  defvar("cache", 0, LOCALE("", "Cache: Proxy Disk Cache Enabled"), TYPE_FLAG,
	  LOCALE("", "If set to Yes, caching will be enabled."));

  defvar("garb_min_garb", 1, LOCALE("", "Cache: Proxy Disk Cache Clean size"), TYPE_INT,
	 LOCALE("", "Minimum number of Megabytes removed when a garbage collect is done."),
	  0, cache_disabled_p);

  defvar("cache_minimum_left", 5, LOCALE("", "Cache: Proxy Disk Cache Minimum "
	  "available free space and inodes (in %)"), TYPE_INT,
	 LOCALE("", "If less than this amount of disk space or inodes (in %) is left, "
		"the cache will remove a few files. This check may work "
		"half-hearted if the diskcache is spread over several filesystems."),
	 0,
#if constant(filesystem_stat)
	 cache_disabled_p
#else
	 1
#endif /* filesystem_stat */
	 );

  defvar("cache_size", 25, LOCALE("", "Cache: Proxy Disk Cache Size"), TYPE_INT,
	  LOCALE("", "How many MB may the cache grow to before a garbage collect is done?"),
	  0, cache_disabled_p);

  defvar("cache_max_num_files", 0, LOCALE("", "Cache: Proxy Disk Cache Maximum number "
	  "of files"), TYPE_INT, LOCALE("", "How many cache files (inodes) may "
	  "be on disk before a garbage collect is done ? May be left "
	  "zero to disable this check."),
	  0, cache_disabled_p);

  defvar("bytes_per_second", 50, LOCALE("", "Cache: Proxy Disk Cache bytes per second"),
	  TYPE_INT,
	  LOCALE("", "How file size should be treated during garbage collect. "
	  " Each X bytes counts as a second, so that larger files will"
	  " be removed first."),
	  0, cache_disabled_p);

  defvar("cachedir", "/tmp/roxen_cache/",
	  LOCALE("", "Cache: Proxy Disk Cache Base Cache Dir"),
	  TYPE_DIR,
	  LOCALE("", "This is the base directory where cached files will reside. "
	  "To avoid mishaps, 'roxen_cache/' is always prepended to this "
	  "variable."),
	  0, cache_disabled_p);

  defvar("hash_num_dirs", 500,
	  LOCALE("", "Cache: Proxy Disk Cache Number of hash directories"),
	  TYPE_INT|VAR_MORE,
	  LOCALE("", "This is the number of directories to hash the contents of the disk "
	  "cache into.  Changing this value currently invalidates the whole "
	  "cache, since the cache cannot find the old files.  In the future, "
	  " the cache will be recalculated when this value is changed."),
	  0, cache_disabled_p);

  defvar("cache_keep_without_content_length", 1, LOCALE("", "Cache: "
	  "Proxy Disk Cache Keep without Content-Length"),
          TYPE_FLAG, LOCALE("", "Keep files "
	  "without Content-Length header information in the cache?"),
	  0, cache_disabled_p);

  defvar("cache_check_last_modified", 0, LOCALE("", "Cache: "
	  "Proxy Disk Cache Refreshes on Last-Modified"), TYPE_FLAG,
	  LOCALE("", "If set, refreshes files without Expire header information "
	  "when they have reached double the age they had when they got "
	  "cached. This may be useful for some regularly updated docs as "
	  "online newspapers."),
	  0, cache_disabled_p);

  defvar("cache_last_resort", 0, LOCALE("", "Cache: "
	  "Proxy Disk Cache Last resort (in days)"), TYPE_INT,
	  LOCALE("", "How many days shall files without Expires and without "
	  "Last-Modified header information be kept?"),
	  0, cache_disabled_p);

  defvar("cache_gc_logfile",  "",
	  LOCALE("", "Cache: "
	  "Proxy Disk Cache Garbage collector logfile"), TYPE_FILE,
	  LOCALE("", "Information about garbage collector runs, removed and refreshed "
	  "files, cache and disk status goes here."),
	  0, cache_disabled_p);

  /// End of cache variables..

  defvar("pidfile", "/tmp/roxen_pid_$uid", LOCALE("", "PID file"),
	  TYPE_FILE|VAR_MORE,
	  LOCALE("", "In this file, the server will write out it's PID, and the PID "
	  "of the start script. $pid will be replaced with the pid, and "
	  "$uid with the uid of the user running the process.\n"
	  "<p>Note: It will be overridden by the command line option.</p>"));

  // FIXME: Should mention real_version.
  defvar("default_ident", 1, LOCALE("", "Identify, Use default identification string"),
	  TYPE_FLAG|VAR_MORE,
	  LOCALE("", "Setting this variable to No will display the \"Identify as\" node "
	  "where you can state what Roxen should call itself when talking "
	  "to clients.<br />"
	  "It is possible to disable this so that you can enter an "
	  "identification-string that does not include the actual version of "
	  "Roxen, as recommended by the HTTP/1.0 draft 03:<p><blockquote><i>"
	  "Note: Revealing the specific software version of the server "
	  "may allow the server machine to become more vulnerable to "
	  "attacks against software that is known to contain security "
	  "holes. Server implementors are encouraged to make this field "
	  "a configurable option.</i></blockquote></p>"));

  defvar("ident", replace(real_version," ","·"), LOCALE("", "Identify, Identify as"),
	  TYPE_STRING /* |VAR_MORE */,
	  LOCALE("", "Enter the name that Roxen should use when talking to clients. "),
	  0, ident_disabled_p);

  defvar("User", "", LOCALE("", "Change uid and gid to"), TYPE_STRING,
	  LOCALE("", "When roxen is run as root, to be able to open port 80 "
	  "for listening, change to this user-id and group-id when the port "
	  " has been opened. If you specify a symbolic username, the "
	  "default group of that user will be used. "
	  "The syntax is user[:group]."));

  defvar("permanent_uid", 0, LOCALE("", "Change uid and gid permanently"),
	  TYPE_FLAG,
	  LOCALE("", "If this variable is set, roxen will set it's uid and gid "
	  "permanently. This disables the 'exec script as user' fetures "
	  "for CGI, and also access files as user in the filesystems, but "
	  "it gives better security."));

  // FIXME: Should mention getcwd()
  defvar("ModuleDirs", ({ "../local/modules/", "modules/" }),
	  LOCALE("", "Module directories"), TYPE_DIR_LIST,
	  LOCALE("", "This is a list of directories where Roxen should look for "
	  "modules. Can be relative paths, from the "
	  "directory you started roxen."
	  " The directories are searched in order for modules."));

  defvar("Supports", "#include <etc/supports>\n",
	  LOCALE("", "Client supports regexps"), TYPE_TEXT_FIELD|VAR_MORE,
	  LOCALE("", "What do the different clients support?\n<br />"
	  "The default information is normally fetched from the file "
	  "server/etc/supports in your roxen directory."));

  defvar("audit", 0, LOCALE("", "Logging: Audit trail"), TYPE_FLAG,
	  LOCALE("", "If Audit trail is set to Yes, all changes of uid will be "
	  "logged in the Event log."));

#if efun(syslog)
  defvar("LogA", "file", LOCALE("", "Logging: Logging method"), TYPE_STRING_LIST|VAR_MORE,
	  LOCALE("", "What method to use for logging, default is file, but "
	  "syslog is also available. When using file, the output is really"
	  " sent to stdout and stderr, but this is handled by the "
	  "start script."),
	  ({ "file", "syslog" }));

  defvar("LogSP", 1, LOCALE("", "Logging: Log PID"), TYPE_FLAG,
	  LOCALE("", "If set, the PID will be included in the syslog."), 0,
	  syslog_disabled);

  defvar("LogCO", 0, LOCALE("", "Logging: Log to system console"), TYPE_FLAG,
	  LOCALE("", "If set and syslog is used, the error/debug message will be printed"
	  " to the system console as well as to the system log."),
	  0, syslog_disabled);

  defvar("LogST", "Daemon", LOCALE("", "Logging: Syslog type"), TYPE_STRING_LIST,
	  LOCALE("", "When using SYSLOG, which log type should be used."),
	  ({ "Daemon", "Local 0", "Local 1", "Local 2", "Local 3",
	     "Local 4", "Local 5", "Local 6", "Local 7", "User" }),
	  syslog_disabled);

  defvar("LogWH", "Errors", LOCALE("", "Logging: Log what to syslog"), TYPE_STRING_LIST,
	  LOCALE("", "When syslog is used, how much should be sent to it?<br /><hr />"
	  "Fatal:    Only messages about fatal errors<br />"
	  "Errors:   Only error or fatal messages<br />"
	  "Warning:  Warning messages as well<br />"
	  "Debug:    Debug messager as well<br />"
	  "All:      Everything<br />"),
	  ({ "Fatal", "Errors",  "Warnings", "Debug", "All" }),
	  syslog_disabled);

  defvar("LogNA", "Roxen", LOCALE("", "Logging: Log as"), TYPE_STRING,
	  LOCALE("", "When syslog is used, this will be the identification of the "
	  "Roxen daemon. The entered value will be appended to all logs."),
	  0, syslog_disabled);
#endif

#ifdef THREADS
  defvar("numthreads", 5, LOCALE("", "Number of threads to run"), TYPE_INT,
	  LOCALE("", "The number of simultaneous threads roxen will use.\n"
	  "<p>Please note that even if this is one, Roxen will still "
	  "be able to serve multiple requests, using a select loop based "
	  "system.\n"
	  "<i>This is quite useful if you have more than one CPU in "
	  "your machine, or if you have a lot of slow NFS accesses.</i></p>"));
#endif

  defvar("AutoUpdate", 1, LOCALE("", "Update the supports database automatically"),
	  TYPE_FLAG,
	  LOCALE("", "If set to Yes, the etc/supports file will be updated automatically "
	  "from www.roxen.com now and then. This is recomended, since "
	  "you will then automatically get supports information for new "
	  "clients, and new versions of old ones."));

  defvar("next_supports_update", time()+3600, "", TYPE_INT,"",0,1);

#ifndef __NT__
  defvar("abs_engage", 0, LOCALE("", "ABS: Enable Anti-Block-System"), TYPE_FLAG|VAR_MORE,
	 LOCALE("", "If set, the anti-block-system will be enabled. "
		"This will restart the server after a configurable number of minutes if it "
		"locks up. If you are running in a single threaded environment heavy "
		"calculations will also halt the server. In multi-threaded mode bugs such as "
		"eternal loops will not cause the server to reboot, since only one thread is "
		"blocked. In general there is no harm in having this option enabled. "));

  defvar("abs_timeout", 5, LOCALE("", "ABS: Timeout"),
	  TYPE_INT_LIST|VAR_MORE,
	 LOCALE("", "If the server is unable to accept connection for this many "
		"minutes, it will be restarted. You need to find a balance: "
		"if set too low, the server will be restarted even if it's doing "
		"legal things (like generating many images), if set too high you might "
		"get a long downtime if the server for some reason locks up."),
	 ({1,2,3,4,5,10,15}),
	 lambda() {return !QUERY(abs_engage);});
#endif


  defvar("locale", "standard", LOCALE("", "Default language"), TYPE_STRING_LIST,
	  LOCALE("", "Locale, used to localize all messages in roxen.\n"
	  "Standard means using the default locale, which varies according to the "
          "value of the 'LANG' environment variable."),
#if constant(Locale.list_languages)
	 sort(Locale.list_languages("base_server")+({"standard"}))
#else
	 sort(RoxenLocale.list_languages("base_server")+({"standard"}))
#endif
	 );

  defvar("suicide_engage", 0,
	 LOCALE("", "Auto Restart: Enable Automatic Restart"),
	 TYPE_FLAG|VAR_MORE,
	 LOCALE("", "If set, Roxen will automatically restart after a configurable number of "
		"days. Since Roxen uses a monolith, non-forking server model the process tends "
		"to grow in size over time. This is mainly due to heap fragmentation but also "
		"because of memory leaks.")
	  );

  defvar("suicide_timeout", 7,
	  LOCALE("", "Auto Restart: Timeout"),
	  TYPE_INT_LIST|VAR_MORE,
	  LOCALE("", "Automatically restart the server after this many days."),
	  ({1,2,3,4,5,6,7,14,30}),
	  lambda(){return !QUERY(suicide_engage);});

  defvar("argument_cache_in_db", 0,
         LOCALE("", "Cache: Store the argument cache in a mysql database"),
         TYPE_FLAG|VAR_MORE,
         LOCALE("", "If set, store the argument cache in a mysql "
         "database. This is very useful for load balancing using multiple "
         "roxen servers, since the mysql database will handle "
	 " synchronization"));

  defvar("argument_cache_db_path", "mysql://localhost/roxen",
	 LOCALE("", "Cache: Argument Cache Database URL to use"),
	 TYPE_STRING|VAR_MORE,
	 LOCALE("", "The database to use to store the argument cache"),
	 0,
	 lambda(){ return !QUERY(argument_cache_in_db); });

  defvar("argument_cache_dir", "$VARDIR/cache/",
	 LOCALE("", "Cache: Argument Cache Directory"),
	 TYPE_DIR|VAR_MORE,
         LOCALE("", "The cache directory to use to store the argument cache."
         " Please note that load balancing is not available for most modules "
         " (such as gtext, diagram etc) unless you use a mysql database to "
         "store the argument cache meta data"));

  defvar("mem_cache_gc", 300,
	 LOCALE("", "Cache: Memory Cache Garbage Collect Interval"),
	 TYPE_INT,
	 LOCALE("", "The number of seconds between every garbage collect "
	 "(removal of old content) from the memory cache. The "
	 "memory cache is used for various tasks like remebering "
	 "what supports flags matches what client."));

  defvar("config_file_comments", 0,
	 LOCALE("", "Commented config files"),
	 TYPE_FLAG,
	 LOCALE("", "Save the variable documentation strings as comments in the "
	 "configuration files. Only useful if you read or edit the config files "
	 "directly."));
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
