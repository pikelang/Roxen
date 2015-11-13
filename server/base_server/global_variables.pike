// This file is part of Roxen WebServer.
// Copyright © 1996 - 2009, Roxen IS.
// $Id$

// #pragma strict_types
#define DEFVAR mixed...:object
#define BDEFVAR mixed...:object

#define IN_ROXEN
#include <module.h>
inherit "read_config";
inherit "basic_defvar";
#include <version.h>

//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)  _DEF_LOCALE("roxen_config",X,Y)

mixed save()
{
  store( "Variables", variables, 0, 0 );
}

// The following three functions are used to hide variables when they
// are not used. This makes the user-interface clearer and quite a lot
// less clobbered.

private int(0..1) cache_disabled_p() { return !query("cache");         }
private int(0..1) ident_disabled_p() { return [int(0..1)]query("default_ident"); }
#if constant(syslog)
private int(0..1) syslog_disabled()  { return query("LogA")!="syslog"; }
#endif

protected void cdt_changed (Variable.Variable v);
void slow_req_count_changed();
void slow_req_timeout_changed();
void slow_be_timeout_changed();

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
	  LOCALE(309,"Require user with the 'hilfe' permission"), TYPE_FLAG,
	  LOCALE(310,"If yes, require a user with the hilfe permission "
		 "set, otherwise, any configuration interface user will "
		 "be allowed, even one with only the view settings permission." ) );
}

#if 0
void set_up_snmp_variables( Protocol o )
{
  function(DEFVAR) defvar = o->defvar;

  defvar("snmp_community", ({"public:ro"}), "Community string",
         TYPE_STRING_LIST,
         "One community name per line. Default permissions are 'read-only'. "
	 "'Read-write' permissions can be specified by appending :rw to the "
	 "community name (for example mypub:rw).");
/*
  defvar("snmp_mode", "smart", "Agent mode",
         TYPE_STRING_LIST,
         "Standard SNMP server mode, muxed SNMP mode, "
         "proxy, agentx or automatic (smart) mode.",
         ({"smart", "agent", "agentx", "smux", "proxy" }));
*/
  defvar("snmp_global_traphosts", ({}),"Trap destinations",
         TYPE_STRING_LIST,
         "The SNMP traphost URL for sending common traps (like coldstart).");

  defvar("snmp_syscontact","","System MIB: Contact",
         TYPE_STRING,
         "The textual identification of the contact person for this managed "
         "node, together with information on how to contact this person.");
  defvar("snmp_sysname","","System MIB: Name",
         TYPE_STRING,
         "An administratively-assigned name for this managed node. By "
         "convention, this is the node's fully-qualified domain name.");
  defvar("snmp_syslocation","","System MIB: Location",
         TYPE_STRING,
         "The physical location of this node (e.g., `telephone closet, 3rd "
         "floor').");
  defvar("snmp_sysservices",72,"System MIB: Services",
         TYPE_INT,
         "A value which indicates the set of services that this entity "
         "primarily offers.");
#if 0
  defvar("site_id", 0,
	 LOCALE(1012, "SNMP sub-MIB"), TYPE_INT,
	 LOCALE(1013, "MIB suffix to 1.3.6.1.4.1.8614.1.1.2 "
		"identifying this site."));
#endif /* 0 */
}
#endif /* 0 */

void set_up_ftp_variables( Protocol o )
{
  function(DEFVAR) defvar = o->defvar;


  defvar( "FTPWelcome",
          "              +------------------------------------------------\n"
          "              +--      Welcome to the Roxen FTP server      ---\n"
          "              +------------------------------------------------\n",
	  LOCALE(60, "Welcome text"), TYPE_TEXT,
          LOCALE(61, "The text shown to the user on connect.") );

  defvar( "ftp_user_session_limit", 0, LOCALE(62, "User session limit"), 
	  TYPE_INT,
          LOCALE(63, "The maximum number of times a user can connect at once."
          " 0 means unlimited.") );

  defvar( "named_ftp", 1,  LOCALE(64, "Allow named ftp"), TYPE_FLAG,
          LOCALE(65, "If yes, non-anonymous users can connect. "
		 "Note that for password authentication to be performed "
		 "you will need to have the \"Authentication: Password\" "
		 "module in your site.") );

  defvar( "guest_ftp", 1, 
	  LOCALE(66, "Allow login with incorrect password/user"), 
	  TYPE_FLAG,
          LOCALE(67, "If yes, users can connect with the wrong password "
		 "and/or username. This is useful since things like .htaccess "
		 "files can later on authenticate the user."));

  defvar( "anonymous_ftp", 1, LOCALE(68, "Allow anonymous ftp"), 
	  TYPE_FLAG,
          LOCALE(69, "If yes, anonymous users are allowed to connect.") );

  defvar( "shells", "",  LOCALE(70, "Shell database"), 
	  TYPE_FILE,
          LOCALE(71, "If this string is set to anything but the empty string, "
          "it should specify a file containing a list of valid shells. "
          "Users with shells that are not in this list will not "
          "be allowed to log in.") );

  defvar( "passive_port_min", 0, LOCALE(257, "Passive port minimum"),
	  TYPE_INT,
	  LOCALE(320, "Minimum port number to use in the PASV/EPSV response."));

  defvar( "passive_port_max", 65535, LOCALE(321, "Passive port maximum"),
	  TYPE_INT,
	  LOCALE(322, "Maximum port number to use in the PASV/EPSV response."));

  defvar( "rfc2428_support", 1, LOCALE(518, "Support EPRT/EPSV"),
	  TYPE_FLAG,
	  LOCALE(528, "Enable support for the EPRT and EPSV commands (RFC2428)."
		 "Some firewalls don't handle these commands properly, "
		 "so depending on your network configuration you may need "
		 "to disable them. "));
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

  defvar( "minimum_bitrate", 0, LOCALE(205, "Minimum allowed bitrate" ),
	  TYPE_INT,
	  LOCALE(215, "The minimum allowed bitrate, in bits/second. If the  "
		 "client is slower than this set bitrate, it will be "
		 "disconnected (after a timeout). Setting this higher than "
		 "14000 is not recommended if you have modem users."));

  defvar("show_internals", 0, LOCALE(72, "Show internal errors"),
	 TYPE_FLAG,
	 LOCALE(73, "Show 'Internal server error' messages to the user. "
		"This is very useful if you are debugging your own modules "
		"or writing Pike scripts."));

  defvar("set_cookie", 0, LOCALE(74, "Logging: Set unique browser id cookies"),
	 TYPE_FLAG,
	 LOCALE(75, "If set to Yes, all clients that accept cookies will get "
		"a unique 'user-id-cookie', which can then be used in the log "
		"and in scripts to track individual users."));

  defvar("set_cookie_only_once", 1,
	 LOCALE(76, "Logging: Set ID cookies only once"),
	 TYPE_FLAG,
	 LOCALE(77, "If set to Yes, Roxen will attempt to set unique browser "
		"ID cookies only upon receiving the first request (and "
		"again after some minutes). Thus, if the user doesn't allow "
		"the cookie to be set, she won't be bothered with "
		"multiple requests."),0, do_set_cookie( o ));
}

void set_up_ssl_variables( Protocol o )
{
  function(DEFVAR) defvar = o->defvar;

  defvar( "ssl_cert_file",
	  o->CertificateListVariable
	  ( ({ "demo_certificate.pem" }), 0,
	     LOCALE(86, "SSL certificate file"),
	     LOCALE(87, "The SSL certificate file(s) to use. "
		    "If a path is relative, it will first be "
		    "searched for relative to %s, "
		    "and if not found there relative to %s. ")));

  defvar( "ssl_key_file",
	  o->KeyFileVariable
	  ( "", 0, LOCALE(88, "SSL key file"),
	    LOCALE(89, "The SSL key file to use. If the path is "
		   "relative, it will first be searched for "
		   "relative to %s, and if not found there "
		   "relative to %s. "
		   "You do not have to specify a key "
		   "file, leave this field empty to use the "
		   "certificate file only.")));

#if constant(SSL.ServerConnection)
  // Pike 8.0 and later has much more advanced support for SSL/TLS.

  // 112 bits is the maximum strength to still retain the
  // DES-3 suites, which are required in the TLS standards.
  defvar("ssl_key_bits",
	 Variable.Int(112, 0,
		      LOCALE(0, "Cipher suite minimum strength"),
		      LOCALE(0,
			     "<p>The minimum number of bits to secure "
			     "connections.</p>\n"
			     "<p>Common ciphers (subject to availability) "
			     "in order of bits:\n"
			     "<dl>\n"
			     "<dt>40</dt>\n"
			     "<dd>Export DES (aka DES-40)</dd>\n"
			     "<dd>Export RC4 (aka RC4-40)</dd>\n"
			     "<dt>56</dt>\n"
			     "<dd>DES</dd>\n"
			     "<dt>112</dt>\n"
			     "<dd>3-DES (Note that this cipher is the "
			     "minimum required cipher in many versions "
			     "of TLS)</dd>\n"
			     "<dt>128</dt>\n"
			     "<dd>AES-128</dd>\n"
			     "<dd>Camellia-128</dd>\n"
			     "<dd>RC4</dd>\n"
			     "<dt>256</dt>\n"
			     "<dd>AES-256</dd>\n"
			     "<dd>Camellia-256</dd>\n"
			     "</dl>\n"
			     "</p>\n")))->set_range(0, Variable.no_limit);

  defvar("ssl_suite_filter",
	 Variable.IntChoice(0,
			    ([
			      0: "Default",
			      4: "Ephemeral key exchanges only",
			      8: "Suite B (relaxed)",
			      12: "Suite B (ephemeral only)",
			      14: "Suite B (transitional)",
			      15: "Suite B (strict)",
			    ]),
			    0,
			    LOCALE(0, "Additional suite filtering"),
			    LOCALE(0, "<p>Selects an additional cipher suite "
				   "policy.</p>"
				   "<p>The supported filter modes are:\n"
				   "<dl>\n"
				   "<dt>Default</dt>\n"
				   "<dd>Use the default cipher suite selection "
				   "policy, and allow all cipher suites that "
				   "have sufficient strength.</dd>\n"
				   "<dt>Ephemeral key exchanges only</dt>\n"
				   "<dd>Only allow cipher suites that use a "
				   "key exchange with ephemeral keys (aka "
				   "\"Perfect Forward Security\"). Ie "
				   "either ECDHE or DHE.</dd>\n"
				   "<dt>Suite B (relaxed)</dt>\n"
				   "<dd>Same as <b>Default</b>, but prefer the "
				   "suites specified in <b>Suite B</b>.</dd>\n"
				   "<dt>Suite B (ephemeral only)</dt>\n"
				   "<dd>Same as <b>Ephemeral key exchanges "
				   "only</b>, but prefer the suites specified "
				   "in <b>Suite B</b>.</dd>\n"
				   "<dt>Suite B (transitional)</dt>\n"
				   "<dd>Support only the suites specified by "
				   "RFCs 5430 and 6460.</dd>\n"
				   "<dt>Suite B (strict)</dt>\n"
				   "<dd>Support only the suites specified by "
				   "RFC 6460.</dt>\n"
				   "</dl>\n"
				   "</p>\n"
				   "<p>Note: Full Suite B operation is not "
				   "supported in all configurations.</p>\n"
				   "<p>Note: For full Suite B compliance a "
				   "suitable certificate must also be "
				   "used.</p>")));
#endif /* SSL.ServerConnection */
#if constant(SSL.Constants.PROTOCOL_TLS_MAX)
  mapping(SSL.Constants.ProtocolVersion: string) ssl_versions = ([
    SSL.Constants.PROTOCOL_SSL_3_0: "SSL 3.0",
    SSL.Constants.PROTOCOL_TLS_1_0: "TLS 1.0 (aka SSL 3.1)",
  ]);
#if constant(SSL.Constants.PROTOCOL_TLS_1_1)
  // NB: The symbol may be available, but the Pike binary might be to old...
  for (SSL.Constants.ProtocolVersion v = SSL.Constants.PROTOCOL_TLS_1_1;
       v <= SSL.Constants.PROTOCOL_TLS_MAX; v++) {
    ssl_versions[v] = sprintf("TLS 1.%d", v - SSL.Constants.PROTOCOL_TLS_1_0);
  }
#endif
  defvar("ssl_min_version",
	 Variable.IntChoice(SSL.Constants.PROTOCOL_TLS_1_0, ssl_versions, 0,
			    LOCALE(0, "Minimum supported version of SSL/TLS"),
			    LOCALE(0, "<p>Reject clients that want to use a "
				   "version of SSL/TLS lower than the selected "
				   "version.</p>\n")));
#endif /* SSL.Constants.PROTOCOL_TLS_MAX */
}


// Get the current domain. This is not as easy as one could think.
string get_domain(int|void l)
{
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
  Variable.Variable v;

  defvar("myisamchk",
	 Variable.Language("Fast check and repair",
			   ({ "Disable check",
			      "Fast check and repair",
			      "Normal check and repair",
			      "Medium check and repair",
			      "Extended check and repair" }),
			   0, LOCALE(1014, "MySQL table check"), 
			   LOCALE(1015, "Check MySQL tables on server start, "
				  "and automatically repair if necessary. "
				  "<b>Fast</b> checks only tables that haven't "
				  "been closed properly. "
				  "<b>Normal</b> checks for general errors. "
				  "<b>Medium</b> catches 99.99 % of all "
				  "errors. Should be good enough for most "
				  "cases. "
				  "<b>Extended</b> checks the tables VERY "
				  "throughly.  Only use this in extreme cases "
				  "as myisamchk should normally be able to "
				  "find out if the table is OK even without "
				  "this switch.")))
    ->set_changed_callback(lambda(Variable.Variable s)
			   {
			     string options = "";
			     switch(query("myisamchk"))
			     {
			       case "Disable check":
				 break;
			       case "Fast check and repair":
				 options += "--force --fast --silent\n"
					    "--myisam-recover=QUICK,FORCE\n";
				 break;
			       case "Normal check and repair":
				 options += "--force --check\n"
					    "--myisam-recover=DEFAULT,FORCE\n";
				 break;
			       case "Medium check and repair":
				 options += "--force --medium-check\n"
					    "--myisam-recover=DEFAULT,FORCE\n";
				 break;
			       case "Extended check and repair":
				 options += "--force --extend-check\n"
					    "--myisam-recover=DEFAULT,FORCE\n";
				 break;
			       default:
				 error("Unknown myisamchk level %O\n",
				       query("myisamchk"));
				 return;
			     }
			     Stdio.write_file(combine_path(roxenloader.query_configuration_dir(), "_mysql_table_check"), options);
			   });

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
	  "statistics in Roxen will still be correct.</p>"));

  defvar("default_font", "roxen builtin", LOCALE(92, "Default font"), 
	 TYPE_FONT,
	 LOCALE(93, "The default font to use when modules request a font."));

  defvar("font_dirs", roxenloader.default_roxen_font_path,
         LOCALE(94, "Font directories"), TYPE_DIR_LIST,
	 LOCALE(95, "This is where the fonts are located."));

  defvar("font_oversampling", 1, LOCALE(521, "Font oversampling"), 
	 TYPE_FLAG,
	 LOCALE(522, "If set to Yes, fonts will be oversampled resulting "
		"in higher quality but more fuzz. This will require clearing "
		"of various graphics caches like the Graphic text and "
		"GButton caches to take full effect."));

  defvar("logdirprefix", getenv("LOGDIR") || "../logs/", 
	 LOCALE(96, "Logging: Log directory prefix"),
	 TYPE_STRING|VAR_MORE,
	 LOCALE(97, "This is the default file path that will be prepended "
		"to the log file path in all the default modules and the "
		"site."));

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
		"a garbage collect is done? May be left at zero to disable "
		"this check."),
	 0, cache_disabled_p);

  defvar("bytes_per_second", 50,
	 LOCALE(108, "Cache: Proxy Disk Cache bytes per second"),
	 TYPE_INT,
	 LOCALE(109, "How file size should be treated during garbage collect. "
	  "Each X bytes count as a second, so that larger files will "
	  "be removed first."),
	  0, cache_disabled_p);

  defvar("cachedir", "/tmp/roxen_cache/",
	  LOCALE(110, "Cache: Proxy Disk Cache Base Cache Dir"),
	  TYPE_DIR,
	  LOCALE(111, "This is the base directory where cached files will "
		 "reside. To avoid mishaps, 'roxen_cache/' is always "
		 "appended to this variable."),
	 0, cache_disabled_p);

  defvar("hash_num_dirs", 500,
	 LOCALE(112, "Cache: Proxy Disk Cache Number of hash directories"),
	 TYPE_INT|VAR_MORE,
	 LOCALE(113, "This is the number of directories to hash the contents "
		"of the disk cache into. Changing this value currently "
		"invalidates the whole cache, since the cache cannot find "
		"the old files. In the future, the cache will be "
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

  // FIXME: Should mention real_version.
  defvar("default_ident", 1, 
	 LOCALE(124, "Identify, Use default identification string"),
	 TYPE_FLAG|VAR_MORE,
	 LOCALE(125, "Setting this variable to No will display the "
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
  
  defvar("ident", replace(real_version," ","·"), 
	 LOCALE(126, "Identify, Identify as"),
	 TYPE_STRING /* |VAR_MORE */,
	 LOCALE(127, "Enter the name that Roxen should use when talking to clients. "),
	 0, ident_disabled_p);
  
  defvar("config_header_string", "", 
	 LOCALE(532, "Show this string in header"),
	 TYPE_STRING /* |VAR_MORE */,
	 LOCALE(533, "Enter a identifier that will be displayed in the head of "
		   " config interface. This makes it easier to distinguish "
		   "between different site configurations. "),
	 0);
  
  defvar("User", "", LOCALE(128, "Change uid and gid to"), 
	 TYPE_STRING,
	 LOCALE(129, #"\
When Roxen is run as root, to be able to open port 80 for listening,
change to this user-id and group-id when the port has been opened. If
you specify a symbolic username, the default group of that user will
be used. The syntax is user[:group].

<p>A server restart is necessary for a change of this variable to take
effect. Note that it also can lead to file permission errors if the
Roxen process no longer can read files it previously has written.
The start script attempts to fix this for the standard file locations.</p>"));

  defvar("permanent_uid", 0, LOCALE(130, "Change uid and gid permanently"),
	 TYPE_FLAG,
	 LOCALE(131, "If this variable is set, Roxen will set it's uid and gid "
	  "permanently. This disables the 'exec script as user' features "
	  "for CGI, and also 'access files as user' in the filesystems, but "
	  "it gives better security."));

  defvar("ModuleDirs", roxenloader.default_roxen_module_path,
	 LOCALE(132, "Module directories"), 
	 TYPE_DIR_LIST,
	 LOCALE(133, "This is a list of directories where Roxen should look "
		"for modules. Can be relative paths, from the "
		"directory you started Roxen. "
		"The directories are searched in order for modules."));

  defvar("Supports",
         Variable.Text( "#include <etc/supports>\n",
                        VAR_MORE, LOCALE(134, "Client supports regexps"),
                        LOCALE(135, "What do the different clients support?\n<br />"
                               "The default information is normally fetched from the file "
                               "server/etc/supports in your Roxen directory.") ) )
    -> add_changed_callback( lambda(Variable.Text s) {
                               roxenp()->initiate_supports();
                               cache.cache_expire("supports");
                             } );

  defvar("audit", 0, LOCALE(136, "Logging: Audit trail"), 
	 TYPE_FLAG,
	 LOCALE(137, "If Audit trail is set to Yes, all changes of uid will be "
		"logged in the Event log."));

#if constant(syslog)
  defvar("LogA", "file", LOCALE(138, "Logging: Debug log method"), 
	 TYPE_STRING_LIST|VAR_MORE,
	 LOCALE(139, "What method to use for the debug log, default is file, "
	  "but "
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
#endif // constant(syslog)

  v = Variable.Flag (0, 0,
		     LOCALE(534, "Logging: Dump threads by file polling"),
		     LOCALE(535, #"\
<p>This option can be used to produce dumps of all the threads in the
debug log in situations where the Administration Interface doesn't
respond.</p>

<p>It works by checking for a file called \"<i>&lt;config
name&gt;</i>.dump_threads\" in the same directory as the debug log.
<i>&lt;config name&gt;</i> is the name of the server configuration,
i.e. the same as the base name of the debug log files (typically
\"default\"). If this file exists, a thread dump is generated and the
file is deleted. If a file on the form \"<i>&lt;config
name&gt;</i>.dump_threads.<i>&lt;n&gt;</i>\", where <i>&lt;n&gt;</i>
is an integer, exists then <i>n</i> thread dumps are generated in one
minute intervals.</p>

<p>Note that this method normally isn't necessary in unix-like
environments; there you can just send a SIGQUIT signal to the pike
process to get a thread dump.</p>

<p>Enabling this creates a dedicated thread.</p>"));
  v->set_changed_callback (cdt_changed);
  defvar ("dump_threads_by_file", v);

  definvisvar ("slow_req_bt_permanent", 0, TYPE_FLAG)->
    set_changed_callback (
      lambda (Variable.Variable v) {
	if (v->query())
	  set ("slow_req_bt_count", -1);
	else if (query ("slow_req_bt_count") < 0)
	  set ("slow_req_bt_count", 0);
      });

  v = Variable.TmpInt (
    0, 0,
    LOCALE(1016, "Logging: Dump threads for slow requests"),
    LOCALE(1017, #"\
<p>This enables a monitor that dumps all the threads in the debug log
whenever any request, background job or the backend thread has been
running for more than a set number of seconds, which is configured
with the \"Slow request timeout\" and \"Slow backend timeout\"
settings.</p>

<p>This setting is a counter: A positive number stops the monitor
after that many thread dumps have been made, -1 enables the monitor
permanently, and zero disables it. Positive numbers aren't persistent,
so will be reset to zero whenever the server is restarted.</p>

<p><b>Warning:</b> If you set the timeout too low, combined with a
high or no limit, then the debug log can fill up very quickly and the
server become very slow due to the amount of logging. If that happens
and it gets difficult to change back the value then you can force the
monitor to be disabled from the start by adding the define
\"NO_SLOW_REQ_BT\" (i.e. add \"-DNO_SLOW_REQ_BT\" to the start script
or in the DEFINES environment variable).</p>

<p>Enabling this creates a dedicated thread.</p>"));
  defvar ("slow_req_bt_count", v);
  v->set_range (-1, Variable.no_limit);
  v->set_changed_callback (
    lambda (Variable.Variable v) {
      int count = v->query();
      set ("slow_req_bt_permanent", count < 0);
#ifndef NO_SLOW_REQ_BT
      slow_req_count_changed();
#else
      v->set_warning (LOCALE(1018, "Feature disabled by NO_SLOW_REQ_BT define."));
#endif
    });

  v = defvar ("slow_req_bt_timeout", 10.0,
	      LOCALE(1019, "Logging: Slow request timeout"),
	      TYPE_FLOAT,
	      LOCALE(1020, #"\
<p>The timeout in seconds for requests or background jobs to trig a
thread dump. Zero disables monitoring of those. See the \"Dump threads
for slow requests\" setting for details.</p>"));
  v->set_range (0.0, Variable.no_limit);
  v->set_precision (3);
#ifndef NO_SLOW_REQ_BT
  v->set_changed_callback (lambda (Variable.Variable v) {
			     slow_req_timeout_changed();
			   });
#endif

  v = defvar ("slow_be_bt_timeout", 0.05,
	      LOCALE(1021, "Logging: Slow backend timeout"),
	      TYPE_FLOAT,
	      LOCALE(1022, #"\
<p>The timeout in seconds for the backend thread to trig a thread
dump. Zero disables monitoring of it. See the \"Dump threads for slow
requests\" setting for details.</p>

<p>The backend thread is a special thread that manages most I/O and
directs the incoming requests to the handler threads. It should never
be occupied for a significant amount of time since that would make the
server essentially unresponsive. Therefore this timeout should be
small.</p>

<p>Note that a good value for this is very dependent on hardware. The
default setting here is conservative and probably should be lowered to
be of real use.</p>"));
  v->set_range (0.0, Variable.no_limit);
  v->set_precision (3);
#ifndef NO_SLOW_REQ_BT
  v->set_changed_callback (lambda (Variable.Variable v) {
			     slow_be_timeout_changed();
			   });
#endif

#ifdef THREADS
  defvar("numthreads", 15, LOCALE(150, "Number of threads to run"), 
	 TYPE_INT,
	 LOCALE(151, "The number of simultaneous threads Roxen will use.\n"
	  "<p>Please note that even if this is one, Roxen will still "
	  "be able to serve multiple requests, using a select loop based "
	  "system.\n"
	  "<i>This is quite useful if you have more than one CPU in "
	  "your machine, or if you have a lot of slow NFS accesses.</i></p>"
  	  "<p>Do not increase this over 20 unless you have a "
	  "very good reason to do so.</p>"));
#endif // THREADS

#ifndef __NT__
  defvar("abs_engage", 0, LOCALE(154, "Auto Restart: Enable Anti-Block-System"), 
	 TYPE_FLAG|VAR_MORE,
	 LOCALE(155, "If set, the anti-block-system will be enabled. "
		"This will restart the server after a configurable number of minutes if it "
		"locks up. If you are running in a single threaded environment heavy "
		"calculations will also halt the server. In multi-threaded mode bugs such as "
		"eternal loops will not cause the server to reboot, since only one thread is "
		"blocked. In general there is no harm in having this option enabled. "));



  defvar("abs_timeout", 5, LOCALE(156, "Auto Restart: ABS Timeout"),
	 TYPE_INT_LIST|VAR_MORE,
	 LOCALE(157, "If the server is unable to accept connection for this many "
		"minutes, it will be restarted. You need to find a balance: "
		"if set too low, the server will be restarted even if it's doing "
		"legal things (like generating many images), if set too high you might "
		"get a long downtime if the server for some reason locks up."),
	 ({1,2,3,4,5,10,15,30,60}),
	 lambda() {return !query("abs_engage");});
#endif // __NT__

  defvar("locale",
	 Variable.Language("Standard", ({ "Standard" }) +
			   Locale.list_languages("roxen_config"),
			   0, LOCALE(158, "Default language"), 
			   LOCALE(159, "Locale, used to localize all "
				  "messages in Roxen. Standard means using "
				  "the default locale, which varies "
				  "according to the values of "
				  "the 'LC_MESSAGES' and 'LANG' environment "
				  "variables.")))
    ->set_changed_callback( lambda(Variable.Variable s) {
			      roxenp()->set_default_locale(query("locale"));
			      roxenp()->set_locale();
			    } );

  string secret=Crypto.MD5.hash(""+time(1)+random(100000));
  secret = MIME.encode_base64(secret,1);
  defvar("server_salt", secret[..sizeof(secret)-3], LOCALE(8, "Server secret"),
	 TYPE_STRING|VAR_MORE|VAR_NO_DEFAULT,
	 LOCALE(9, "The server secret is a string used in some "
		"cryptographic functions, such as calculating "
		"unique, non-guessable session id's. Change this "
		"value into something that is hard to guess, unless "
		"you are satisfied with what your computers random "
		"generator has produced.") );

  secret = Crypto.MD5.hash(""+time(1)+random(100000)+"x"+gethrtime());

  definvisvar("argcache_secret","",TYPE_STRING|VAR_NO_DEFAULT);
  set( "argcache_secret", secret );
  // force save.

  
  defvar("suicide_engage", 0,
	 LOCALE(160, "Auto Restart: Enable Automatic Restart"),
	 TYPE_FLAG|VAR_MORE,
	 LOCALE(161, "If set, Roxen will automatically restart after a "
		"configurable number of days. Since Roxen uses a monolith, "
		"non-forking server model the process tends to grow in size "
		"over time. This is mainly due to heap fragmentation but "
		"may also sometimes be because of memory leaks.")
	  );

  definvisvar( "last_suicide", 0, TYPE_INT );
  
  defvar("suicide_schedule",
	 Variable.Schedule( ({ 2, 1, 1, 0, 4 }), 0,
			    LOCALE(387,"Auto Restart: Schedule"),
			    LOCALE(388, "Automatically restart the "
				   "server according to this schedule.") ) )
    ->set_invisibility_check_callback (
      lambda(RequestID id, Variable.Variable f)
	{return !query("suicide_engage");}
    );

#ifdef NEW_RAM_CACHE

  defvar ("mem_cache_gc_2", 5 * 60,
	  LOCALE(1045, "Cache: Memory cache GC interval"),
	  TYPE_INT,
	  LOCALE(1046, #"\
<p>Interval in seconds between RAM cache garbage collector runs. This
GC removes entries from the RAM caches that have timed out or are
stale for other reasons, thereby making more room for new entries. The
configured cache size limits are enforced when entries are added, so
this GC is not required to keep the cache sizes down.</p>

<p>Running this GC too seldom causes some RAM caches to contain many
invalid cache entries, which could push out valid cache entries.
Running it too often causes unnecessary server load.</p>"))
    ->set_range (1, Variable.no_limit);

  // This was the variable that used to control the gc interval, but
  // since the effect of the gc is radically different now we
  // intentionally use a different variable name to reset the value.
  definvisvar ("mem_cache_gc", 300, TYPE_INT);

  v = defvar ("mem_cache_size", 100,
	      LOCALE(1043, "Cache: Memory cache size"),
	      TYPE_INT,
	      LOCALE(1044, #"\
<p>Maximum size in MByte for all RAM caches taken together. This limit
covers the caches visible in the <a
href='/actions/?action=cachestatus.pike&class=status'>Cache status</a>
page.</p>

<p>Note that there are many more things in the Roxen WebServer that
take space, including some caches that are not handled by the common
RAM cache. Also, there is various indirect memory overhead that is not
directly accounted for by the size calculations. All these taken
together means that the figure configured here cannot be mapped
straightly to the size of the Roxen process as reported by the OS. The
optimal setting here is the one that in general keeps the Roxen
process at a size that avoids swapping and leaves enough memory for
buffers and other processes that need to run at the same time (e.g.
the Roxen instance of the MySQL server).</p>"));
  v->set_range (1, Variable.no_limit);
  v->set_changed_callback (
    lambda (Variable.Int v) {
      cache.set_total_size_limit (v->query() * 1024 * 1024);
    });

#else  // !NEW_RAM_CACHE

  defvar("mem_cache_gc",
	 Variable.Int(300, 0, 
		      LOCALE(170, "Cache: Memory Cache Garbage Collect Interval"),
		      LOCALE(171, "The number of seconds between every garbage collect "
			     "(removal of old content) from the memory cache. The "
			     "memory cache is used for various tasks like remembering "
			     "what supports flags matches what client.")))
	 ->set_range(1, 60*60*24);
	 // Note that the upper limit is arbitrary.

#endif	// !NEW_RAM_CACHE

  defvar("replicate", 0,
	 LOCALE(163, "Enable replication system" ),
	 TYPE_FLAG,
	 LOCALE(337,"If enabled, Roxen will enable various replication systems "
		"needed to set up multiple frontend systems. You will need "
		"a database named 'replicate' that resides in a shared mysql "
		"server for this to work. Also, all servers has to have this "
		"flag set. Roxen must be restarted before changes to this "
		"variable takes effect." ) );
  
  defvar("config_file_comments", 0,
	 LOCALE(172, "Commented config files"),
	 TYPE_FLAG,
	 LOCALE(173, "Save the variable documentation strings as comments "
		"in the configuration files. Only useful if you read or "
		"edit the config files directly."));

#ifdef SMTP_RELAY
  // SMTP stuff

  defvar("mail_spooldir", "../var/spool/mqueue/",
	 "SMTP: Mail queue directory", TYPE_DIR,
	 "Directory where the mail spool queue is stored.");

  defvar("mail_maxhops", 10, "SMTP: Maximum number of hops", TYPE_INT,
	 "Maximum number of MTA hops (used to avoid loops).<br>\n"
	 "Zero means no limit.");

  defvar("mail_bounce_size_limit", 262144,
	 "SMTP: Maximum bounce size", TYPE_INT,
	 "<p>Maximum size (bytes) of the embedded message in "
	 "generated bounces.</p>"
	 "<p>Set to zero for no limit.</p>"
	 "<p>Set to -1 to disable bounces.</p>");

  // Try to get our FQDN.
  string hostname = gethostname();
  array(string) hostinfo = gethostbyname(hostname);
  if (hostinfo && sizeof(hostinfo)) {
    hostname = hostinfo[0];
  }

  defvar("mail_hostname", hostname,
	 "SMTP: Mailserver host name", TYPE_STRING,
	 "This is the hostname used by the server in the SMTP "
	 "handshake (EHLO & HELO).");

  defvar("mail_postmaster",
	 "Postmaster <postmaster@" + hostname + ">",
	 "SMTP: Postmaster address", TYPE_STRING,
	 "Email address of the postmaster.");

  defvar("mail_mailerdaemon",
	 "Mail Delivery Subsystem <MAILER-DAEMON@" + hostname + ">",
	 "SMTP: Mailer daemon address", TYPE_STRING,
	 "Email address of the mailer daemon.");
#endif /* SMTP_RELAY */

#ifdef SNMP_AGENT
  // SNMP stuffs
  defvar("snmp_agent", 0, LOCALE(999, "SNMP: Enable SNMP agent"),
	 TYPE_FLAG|VAR_MORE,
	 "If set, the Roxen SNMP agent will be anabled."
	 );
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

protected mapping(string:mixed) __vars = ([ ]);

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
