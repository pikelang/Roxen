// This file is part of Roxen WebServer.
// Copyright © 1996 - 2001, Roxen IS.
// $Id: global_variables.pike,v 1.91 2002/06/13 14:17:41 nilsson Exp $

// NGSERVER: Move protocol settings to their own files.

// #pragma strict_types
#define DEFVAR mixed...:object
#define BDEFVAR mixed...:object

#define IN_ROXEN
inherit "read_config";
inherit "basic_defvar";
#include <version.h>
#include <module.h>

mixed save()
{
  store( "Variables", variables, 0, 0 );
}

// The following three functions are used to hide variables when they
// are not used. This makes the user-interface clearer and quite a lot
// less clobbered.

private int(0..1) cache_disabled_p() { return !query("cache");         }
private int(0..1) syslog_disabled()  { return query("LogA")!="syslog"; }
private int(0..1) ident_disabled_p() { return [int(0..1)]query("default_ident"); }

#ifdef SNMP_AGENT
private int(0..1) snmp_disabled() { return !query("snmp_agent"); }
private string snmp_get_cif_domain() {
  //return(Standards.URI(roxenp()->configurations[0]->get_url()||"http://0.0.0.0")->host);
  return("");
}
#endif

// And why put these functions here, you might righfully ask.

// The answer is that there is actually a reason for it, it's for
// performance reasons. This file is dumped to a .o file, roxen.pike
// is not.
void set_up_hilfe_variables( Protocol o )
{
  function(DEFVAR) defvar = o->defvar;

  defvar( "require_auth", 1,
	  "Require user with the 'hilfe' permission", TYPE_FLAG,
	  ("If yes, require a user with the hilfe permission "
	   "set, otherwise, any configuration interface user will "
	   "be allowed, even one with only the view settings permission." ) );
}


void set_up_ftp_variables( Protocol o )
{
  function(DEFVAR) defvar = o->defvar;


  defvar( "FTPWelcome",
          "              +------------------------------------------------\n"
          "              +--      Welcome to the Roxen FTP server      ---\n"
          "              +------------------------------------------------\n",
	  "Welcome text", TYPE_TEXT,
          "The text shown to the user on connect." );

  defvar( "ftp_user_session_limit", 0, "User session limit",
	  TYPE_INT,
          "The maximum number of times a user can connect at once."
          " 0 means unlimited." );

  defvar( "named_ftp", 1, "Allow named ftp", TYPE_FLAG,
          "If yes, non-anonymous users can connect." );

  defvar( "guest_ftp", 1, 
	  "Allow login with incorrect password/user",
	  TYPE_FLAG,
          ("If yes, users can connect with the wrong password "
	   "and/or username. This is useful since things like .htaccess "
	   "files can later on authenticate the user."));

  defvar( "anonymous_ftp", 1, "Allow anonymous ftp",
	  TYPE_FLAG, "If yes, anonymous users are allowed to connect." );

  defvar( "shells", "", "Shell database",
	  TYPE_FILE,
          ("If this string is set to anything but the empty string, "
	   "it should specify a file containing a list of valid shells. "
	   "Users with shells that are not in this list will not "
	   "be allowed to log in.") );

  defvar( "passive_port_min", 0, "Passive port minimum",
	  TYPE_INT, "Minimum port number to use in the PASV/EPSV response." );

  defvar( "passive_port_max", 65535, "Passive port maximum",
	  TYPE_INT, "Maximum port number to use in the PASV/EPSV response." );
}


void set_up_http_variables( Protocol o )
{
  function(DEFVAR) defvar = o->defvar;

  function do_set_cookie(Protocol o)
  {
    return lambda() {
	     return o->query("set_cookie") == 0;
	   };
  };

  defvar( "minimum_bitrate", 0, "Minimum allowed bitrate",
	  TYPE_INT,
	  ("The minimum allowed bitrate, in bits/second. If the  "
	   "client is slower than this set bitrate, it will be "
	   "disconnected (after a timeout). Setting this higher than "
	   "14000 is not recommended if you have modem users.") );

  defvar("show_internals", 0, "Show internal errors",
	 TYPE_FLAG,
	 ("Show 'Internal server error' messages to the user. "
	  "This is very useful if you are debugging your own modules "
	  "or writing Pike scripts."));

  defvar("set_cookie", 0, "Logging: Set unique browser id cookies",
	 TYPE_FLAG,
	 ("If set to Yes, all clients that accepts cookies will get "
	  "a unique 'user-id-cookie', which can then be used in the log "
	  "and in scripts to track individual users."));

  defvar("set_cookie_only_once", 1, "Logging: Set ID cookies only once",
	 TYPE_FLAG,
	 ("If set to Yes, Roxen will attempt to set unique browser "
	  "ID cookies only upon receiving the first request (and "
	  "again after some minutes). Thus, if the user doesn't allow "
	  "the cookie to be set, she won't be bothered with "
	  "multiple requests."), 0, do_set_cookie( o ));
}

void set_up_ssl_variables( Protocol o )
{
  function(DEFVAR) defvar = o->defvar;

  defvar( "ssl_cert_file", "demo_certificate.pem", "SSL certificate file",
	  TYPE_STRING,
	  "The SSL certificate file to use. The path is relative to "+getcwd()+".\n" );


  defvar( "ssl_key_file", "", "SSL key file",
	  TYPE_STRING,
	  ("The SSL key file to use. The path is "
	   "relative to "+getcwd()+", you do not have to specify a key "
	   "file, leave this field empty to use the certificate "
	   "file only.\n") );
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

  int check_visibility(RequestID id, int a, int b, int c, int d) { return 0;  }
  void set_from_form(RequestID id ) { return; }
  void create()
  {
    ::create( ([]), 0, 0, 0 );
  }
};

array(string) old_module_dirs;
void zap_all_module_caches( Variable.Variable v ) 
{
  if( !equal( v->query(), old_module_dirs ) )
  {
    report_notice( "Module path changed - clearing all module caches\n" );
    catch(this_object()->clear_all_modules_cache());
    catch(map( this_object()->module_cache->list(),
               this_object()->module_cache->delete ));
    catch
    {
      string f = dirname( master()->make_ofilename( "tmp" ) );
      foreach( glob("*.o",get_dir( f )), string ofile )
        catch(rm( ofile ));
    };
    old_module_dirs = v->query();
  }
}

void define_global_variables(  )
{
  int p;

  defvar("port_options", PortOptions());

  defvar("RestoreConnLogFull", 0,
	  "Logging: Log entire file length in restored connections",
	  TYPE_FLAG,
	  ("If this toggle is enabled log entries for restored connections "
	   "will log the amount of sent data plus the restoration location. "
	   "Ie if a user has downloaded 100 bytes of a file already, and makes "
	   "a Range request fetching the remaining 900 bytes, the log entry "
	   "will log it as if the entire 1000 bytes were downloaded. "
	   "<p>This is useful if you want to know if downloads were successful "
	   "(the user has the complete file downloaded). The drawback is that "
	   "bandwidth statistics on the log file will be incorrect. The "
	   "statistics in Roxen will still be correct.</p>"));

  defvar("default_font", "roxen builtin", "Default font",
	 TYPE_FONT,
	 "The default font to use when modules request a font.");

  defvar("font_dirs", ({"../local/fonts/", "data/fonts/" })+
#ifdef __NT__
         ({combine_path(replace(getenv("SystemRoot"),"\\","/"),"fonts/")})
#else
         ((getenv("RX_FONTPATH")||"")/","-({""}))
#endif
         , "Font directories",
	 TYPE_DIR_LIST,
	 "This is where the fonts are located.");

  defvar("logdirprefix", "../logs/",
	 "Logging: Log directory prefix",
	 TYPE_STRING|VAR_MORE,
	 ("This is the default file path that will be prepended "
	  "to the log file path in all the default modules and the "
	  "site."));

  defvar("cache", 0, "Cache: Proxy Disk Cache Enabled",
	 TYPE_FLAG,
	 "If set to Yes, caching will be enabled.");

  defvar("garb_min_garb", 1,
	 "Cache: Proxy Disk Cache Clean size",
	 TYPE_INT,
	 "Minimum number of Megabytes removed when a garbage collect is done.",
	  0, cache_disabled_p);

  defvar("cache_minimum_left", 5,
	 "Cache: Proxy Disk Cache Minimum available free space and inodes (in %)",
	 TYPE_INT,
	 ("If less than this amount of disk space or inodes (in %) "
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

  defvar("cache_size", 25, "Cache: Proxy Disk Cache Size",
	 TYPE_INT,
	 "How many MB may the cache grow to before a garbage collect is done?",
	 0, cache_disabled_p);

  defvar("cache_max_num_files", 0,
	 "Cache: Proxy Disk Cache Maximum number of files",
	 TYPE_INT, 
	 ("How many cache files (inodes) may be on disk before "
	  "a garbage collect is done? May be left at zero to disable "
	  "this check."),
	 0, cache_disabled_p);

  defvar("bytes_per_second", 50, "Cache: Proxy Disk Cache bytes per second",
	 TYPE_INT,
	 ("How file size should be treated during garbage collect. "
	  "Each X bytes count as a second, so that larger files will "
	  "be removed first."),
	  0, cache_disabled_p);

  defvar("cachedir", "/tmp/roxen_cache/",
	 "Cache: Proxy Disk Cache Base Cache Dir",
	 TYPE_DIR,
	 ("This is the base directory where cached files will "
	  "reside. To avoid mishaps, 'roxen_cache/' is always "
	  "appended to this variable."),
	 0, cache_disabled_p);

  defvar("hash_num_dirs", 500,
	 "Cache: Proxy Disk Cache Number of hash directories",
	 TYPE_INT|VAR_MORE,
	 ("This is the number of directories to hash the contents "
	  "of the disk cache into. Changing this value currently "
	  "invalidates the whole cache, since the cache cannot find "
	  "the old files. In the future, the cache will be "
	  "recalculated when this value is changed."),
	 0, cache_disabled_p);

  defvar("cache_keep_without_content_length", 1,
	 "Cache: Proxy Disk Cache Keep without Content-Length",
	 TYPE_FLAG,
	 "Keep files without Content-Length header information in the cache?",
	 0, cache_disabled_p);

  defvar("cache_check_last_modified", 0,
	 "Cache: Proxy Disk Cache Refreshes on Last-Modified",
	 TYPE_FLAG,
	 ("If set, refreshes files without Expire header "
	  "information when they have reached double the age they had "
	  "when they got cached. This may be useful for some regularly "
	  "updated docs as online newspapers."),
	 0, cache_disabled_p);

  defvar("cache_last_resort", 0,
	 "Cache: Proxy Disk Cache Last resort (in days)",
	 TYPE_INT,
	 ("How many days shall files without Expires and without "
	  "Last-Modified header information be kept?"),
	 0, cache_disabled_p);

  defvar("cache_gc_logfile",  "",
	 "Cache: Proxy Disk Cache Garbage collector logfile",
	 TYPE_FILE,
	 ("Information about garbage collector runs, removed and "
	  "refreshed files, cache and disk status goes here."),
	 0, cache_disabled_p);

  /// End of cache variables..

  // FIXME: Should mention real_version.
  defvar("default_ident", 1, 
	 "Identify, Use default identification string",
	 TYPE_FLAG|VAR_MORE,
	 ("Setting this variable to No will display the "
	  "\"Identify as\" node where you can state what Roxen "
	  "should call itself when talking to clients.<br />"
	  "It is possible to disable this so that you can enter an "
	  "identification-string that does not include the actual "
	  "version of Roxen, as recommended by the HTTP/1.0 and "
	  "HTTP/1.1 RFCs:"
	  "<p><blockquote><i>"
	  "Note: Revealing the specific software version of the server "
	  "may allow the server machine to become more vulnerable to "
	  "attacks against software that is known to contain security "
	  "holes. Server implementors are encouraged to make this field "
	  "a configurable option."
	  "</i></blockquote></p>"));
  
  defvar("ident", replace(real_version," ","·"), "Identify, Identify as",
	 TYPE_STRING /* |VAR_MORE */,
	 "Enter the name that Roxen should use when talking to clients. ",
	 0, ident_disabled_p);
  
  defvar("User", "", "Change uid and gid to",
	 TYPE_STRING,
	 #"\
When Roxen is run as root, to be able to open port 80 for listening,
change to this user-id and group-id when the port has been opened. If
you specify a symbolic username, the default group of that user will
be used. The syntax is user[:group].

<p>A server restart is necessary for a change of this variable to take
effect. Note that it also can lead to file permission errors if the
Roxen process no longer can read files it previously has written.
The start script attempts to fix this for the standard file locations.</p>");

  defvar("permanent_uid", 0, "Change uid and gid permanently",
	 TYPE_FLAG,
	 ("If this variable is set, Roxen will set it's uid and gid "
	  "permanently. This disables the 'exec script as user' features "
	  "for CGI, and also 'access files as user' in the filesystems, but "
	  "it gives better security."));

  defvar("ModuleDirs", ({ "../local/modules/", "modules/" }),
	 "Module directories",
	 TYPE_DIR_LIST,
	 ("This is a list of directories where Roxen should look "
	  "for modules. Can be relative paths, from the "
	  "directory you started Roxen. "
	  "The directories are searched in order for modules."));

  defvar("Supports",
         Variable.Text( "#include <data/supports>\n",
                        VAR_MORE, "Client supports regexps",
                        ("What do the different clients support?\n<br />"
			 "The default information is normally fetched from the file "
			 "server/data/supports in your Roxen directory.") ) )
    -> add_changed_callback( lambda(Variable.Text s) {
                               roxenp()->initiate_supports();
                               cache.cache_expire("supports");
                             } );

  defvar("audit", 0, "Logging: Audit trail",
	 TYPE_FLAG,
	 ("If Audit trail is set to Yes, all changes of uid will be "
	  "logged in the Event log."));

#if efun(syslog)
  defvar("LogA", "file", "Logging: Debug log method",
	 TYPE_STRING_LIST|VAR_MORE,
	 ("What method to use for the debug log, default is file, but "
	  "syslog is also available. When using file, the output is really"
	  " sent to stdout and stderr, but this is handled by the "
	  "start script."),
	 ({ "file", "syslog" }));

  defvar("LogSP", 1, "Logging: Log PID",
	 TYPE_FLAG,
	 "If set, the PID will be included in the syslog.", 0,
	 syslog_disabled);

  defvar("LogCO", 0, "Logging: Log to system console",
	 TYPE_FLAG,
	 ("If set and syslog is used, the error/debug message "
	  "will be printed to the system console as well as to the "
	  "system log."),
	  0, syslog_disabled);

  defvar("LogST", "Daemon", "Logging: Syslog type",
	 TYPE_STRING_LIST,
	 "When using SYSLOG, which log type should be used.",
	 ({ "Daemon", "Local 0", "Local 1", "Local 2", "Local 3",
	    "Local 4", "Local 5", "Local 6", "Local 7", "User" }),
	 syslog_disabled);

  defvar("LogWH", "Errors", "Logging: Log what to syslog",
	 TYPE_STRING_LIST,
	 ("When syslog is used, how much should be sent to it?<br /><hr />"
	  "Fatal:    Only messages about fatal errors<br />"
	  "Errors:   Only error or fatal messages<br />"
	  "Warning:  Warning messages as well<br />"
	  "Debug:    Debug messager as well<br />"
	  "All:      Everything<br />"),
	 ({ "Fatal", "Errors",  "Warnings", "Debug", "All" }),
	 syslog_disabled);

  defvar("LogNA", "Roxen", "Logging: Log as",
	 TYPE_STRING,
	 ("When syslog is used, this will be the identification "
	  "of the Roxen daemon. The entered value will be appended to "
	  "all logs."),
	 0, syslog_disabled);
#endif // efun(syslog)

#ifdef THREADS
  defvar("numthreads", 5, "Number of threads to run",
	 TYPE_INT,
	 ("The number of simultaneous threads Roxen will use.\n"
	  "<p>Please note that even if this is one, Roxen will still "
	  "be able to serve multiple requests, using a select loop based "
	  "system.\n"
	  "<i>This is quite useful if you have more than one CPU in "
	  "your machine, or if you have a lot of slow NFS accesses.</i></p>"
  	  "<p>Do not increase this over 20 unless you have a "
	  "very good reason to do so.</p>"));
#endif // THREADS

#ifndef __NT__
  defvar("abs_engage", 0, "Auto Restart: Enable Anti-Block-System",
	 TYPE_FLAG|VAR_MORE,
	 ("If set, the anti-block-system will be enabled. "
	  "This will restart the server after a configurable number of minutes if it "
	  "locks up. If you are running in a single threaded environment heavy "
	  "calculations will also halt the server. In multi-threaded mode bugs such as "
	  "eternal loops will not cause the server to reboot, since only one thread is "
	  "blocked. In general there is no harm in having this option enabled. "));

  defvar("abs_timeout", 5, "Auto Restart: ABS Timeout",
	 TYPE_INT_LIST|VAR_MORE,
	 ("If the server is unable to accept connection for this many "
	  "minutes, it will be restarted. You need to find a balance: "
	  "if set too low, the server will be restarted even if it's doing "
	  "legal things (like generating many images), if set too high you might "
	  "get a long downtime if the server for some reason locks up."),
	 ({1,2,3,4,5,10,15}),
	 lambda() {return !query("abs_engage");});
#endif // __NT__

  // Keep for now...
  defvar("locale",
	 Variable.Language("Standard", ({ "Standard" }) +
			   Locale.list_languages("roxen_config"),
			   0, "Default language",
			   ("Locale, used to localize some "
			    "messages in Roxen. Standard means using "
			    "the default locale, which varies "
			    "according to the value of "
			    "the 'LANG' environment variable.")))
    ->set_changed_callback( lambda(Variable.Variable s) {
			      roxenp()->set_default_locale(query("locale"));
			      roxenp()->set_locale();
			    } );

  string secret=Crypto.md5()->update(""+time(1)+random(100000))->digest();
  secret = MIME.encode_base64(secret,1);
  defvar("server_salt", secret[..sizeof(secret)-3], "Server secret",
	 TYPE_STRING|VAR_MORE|VAR_NO_DEFAULT,
	 ("The server secret is a string used in some "
	  "cryptographic functions, such as calculating "
	  "unique, non-guessable session id's. Change this "
	  "value into something that is hard to guess, unless "
	  "you are satisfied with what your computers random "
	  "generator has produced.") );

  secret = Crypto.md5()->update(""+time(1)+random(100000)+"x"+gethrtime())
    ->digest();

  definvisvar("argcache_secret","",TYPE_STRING|VAR_NO_DEFAULT);
  set( "argcache_secret", secret );
  // force save.

  
  defvar("suicide_engage", 0, "Auto Restart: Enable Automatic Restart",
	 TYPE_FLAG|VAR_MORE,
	 ("If set, Roxen will automatically restart after a "
	  "configurable number of days. Since Roxen uses a monolith, "
	  "non-forking server model the process tends to grow in size "
	  "over time. This is mainly due to heap fragmentation but "
	  "may also sometimes be because of memory leaks.")
	  );

  definvisvar( "last_suicide", 0, TYPE_INT );
  
  defvar("suicide_schedule",
	 Variable.Schedule( ({ 2, 1, 1, 0, 4 }), 0, "Auto Restart: Schedule",
			    "Automatically restart the "
			    "server according to this schedule." ) )
    ->set_invisibility_check_callback (
      lambda(RequestID id, Variable.Variable f)
	{return !query("suicide_engage");}
    );

  defvar("mem_cache_gc",
	 Variable.Int(300, 0, "Cache: Memory Cache Garbage Collect Interval",
		      ("The number of seconds between every garbage collect "
		       "(removal of old content) from the memory cache. The "
		       "memory cache is used for various tasks like remembering "
		       "what supports flags matches what client.")))
    ->set_range(1, 60*60*24);
  // Note that the upper limit is arbitrary.

  defvar("replicate", 0, "Enable replication system",
	 TYPE_FLAG,
	 ("If enabled, Roxen will enable various replication systems "
	  "needed to set up multiple frontend systems. You will need "
	  "a database named 'replicate' that recides in a shared mysql "
	  "server for this to work. Also, all servers has to have this "
	  "flag set. Roxen must be restarted before changes to this "
	  "variable takes effect." ) );
  
  defvar("config_file_comments", 0, "Commented config files",
	 TYPE_FLAG,
	 ("Save the variable documentation strings as comments "
	  "in the configuration files. Only useful if you read or "
	  "edit the config files directly."));


#ifdef SNMP_AGENT
  // SNMP stuffs
  defvar("snmp_agent", 0, "SNMP: Enable SNMP agent",
	 TYPE_FLAG|VAR_MORE,
	 "If set, the Roxen SNMP agent will be anabled.");

  defvar("snmp_community", ({"public:ro"}), "SNMP: Community string",
         TYPE_STRING_LIST,
         "One community name per line. Default permissions are 'read-only'. "
	 "'Read-write' permissions can be specified by appending :rw to the "
	 "community name (for example mypub:rw).",
	 0, snmp_disabled);
/*
  defvar("snmp_mode", "smart", "SNMP: Agent mode",
         TYPE_STRING_LIST,
         "Standard SNMP server mode, muxed SNMP mode, "
         "proxy, agentx or automatic (smart) mode.",
         ({"smart", "agent", "agentx", "smux", "proxy" }));
*/
  defvar("snmp_hostport", snmp_get_cif_domain(), "SNMP: IP address and port",
         TYPE_STRING,
         "Agent listening IP adress and port. Format: [[host]:port] "
         "If host isn't set then the IP address of the config interface "
	 "will be used.",
	 0, snmp_disabled);

  defvar("snmp_global_traphosts", ({}),"SNMP: Trap destinations",
         TYPE_STRING_LIST,
         "The SNMP traphost URL for sending common traps (like coldstart).",
	 0, snmp_disabled);

  defvar("snmp_syscontact","","SNMP: System MIB - Contact",
         TYPE_STRING,
         "The textual identification of the contact person for this managed "
         "node, together with information on how to contact this person.",
	 0, snmp_disabled);
  defvar("snmp_sysname","","SNMP: System MIB - Name",
         TYPE_STRING,
         "An administratively-assigned name for this managed node. By "
         "convention, this is the node's fully-qualified domain name.",
	 0, snmp_disabled);
  defvar("snmp_syslocation","","SNMP: System MIB - Location",
         TYPE_STRING,
         "The physical location of this node (e.g., `telephone closet, 3rd "
         "floor').",
	 0, snmp_disabled);
  defvar("snmp_sysservices",72,"SNMP: System MIB - Services",
         TYPE_INT,
         "A value which indicates the set of services that this entity "
         "primarily offers.",
	 0, snmp_disabled);
#endif // SNMP_AGENT

  defvar("global_position",
	 Variable.Variable(0, VAR_INVISIBLE));

}


void restore_global_variables()
{
  mapping m = retrieve("Variables", 0);
  setvars(retrieve("Variables", 0));
  if( !m->argcache_secret ) save();
  old_module_dirs = query( "ModuleDirs" );
  getvar( "ModuleDirs" )->add_changed_callback( zap_all_module_caches );
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
