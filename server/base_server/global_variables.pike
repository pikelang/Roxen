#include <module.h>
#include <roxen.h>
#include <config.h>
inherit "read_config";
inherit "module_support";
string real_version;
// The following three functions are used to hide variables when they
// are not used. This makes the user-interface clearer and quite a lot
// less clobbered.

private int cache_disabled_p() { return !QUERY(cache);         }
private int syslog_disabled()  { return QUERY(LogA)!="syslog"; }
private int ident_disabled_p() { return QUERY(default_ident); }

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


void define_global_variables( int argc, array (string) argv )
{
  int p;

  globvar("port_options", ([]), "Ports: Options", VAR_EXPERT|TYPE_CUSTOM,
	  "Mapping with options and defaults for all ports.<br>\n"
	  "Structure:<br>\n"
	  "<dl><pre>\n"
	  "([\n"
	  "  \"\" : ([ string : mixed ]), // Global defaults\n"
	  "  \"prot\" : ([\n"
	  "    \"\" : ([ string : mixed ]), // Defaults for prot://\n"
	  "    \"ip\" : ([\n"
	  "      \"\" : ([ string : mixed ]), // Defaults for prot://ip/\n"
	  "      port : ([ string : mixed ]), // Options for prot://ip:port/\n"
	  "    ]),\n"
	  "  ]),\n"
	  "])\n"
	  "</pre></dl>\n",
	  ({
	    lambda(mixed value, int action) {
	      return "Edit the cofig-file by hand for now.";
	    }
	  }));

  globvar("set_cookie", 0, "Logging: Set unique user id cookies", TYPE_FLAG,
	  #"If set to Yes, all users of your server whose clients support 
cookies will get a unique 'user-id-cookie', this can then be 
used in the log and in scripts to track individual users.");

  deflocaledoc( "svenska", "set_cookie", 
		"Loggning: Sätt en unik cookie för alla användare",
		#"Om du sätter den här variabeln till 'ja', så kommer 
alla användare att få en unik kaka (cookie) med namnet 'RoxenUserID' satt.  Den
här kakan kan användas i skript för att spåra individuella användare.  Det är
inte rekommenderat att använda den här variabeln, många användare tycker illa
om cookies");

  globvar("set_cookie_only_once",1,"Logging: Set ID cookies only once",TYPE_FLAG,
	  #"If set to Yes, Roxen will attempt to set unique user ID cookies
 only upon receiving the first request (and again after some minutes). Thus, if
the user doesn't allow the cookie to be set, she won't be bothered with
multiple requests.",0,
	  lambda() {return !QUERY(set_cookie);});

  deflocaledoc( "svenska", "set_cookie_only_once", 
		"Loggning: Sätt bara kakan en gång per användare",
		#"Om den här variablen är satt till 'ja' så kommer roxen bara
försöka sätta den unika användarkakan en gång. Det gör att om användaren inte
tillåter att kakan sätts, så slipper hon eller han iallafall nya frågor under
några minuter");

  globvar("RestoreConnLogFull", 0,
	  "Logging: Log entire file length in restored connections",
	  TYPE_TOGGLE,
	  "If this toggle is enabled log entries for restored connections "
	  "will log the amount of sent data plus the restoration location. "
	  "Ie if a user has downloaded 100 bytes of a file already, and makes "
	  "a Range request fetching the remaining 900 bytes, the log entry "
	  "will log it as if the entire 1000 bytes were downloaded. "
	  "<p>This is useful if you want to know if downloads were successful "
	  "(the user has the complete file downloaded). The drawback is that "
	  "bandwidth statistics on the log file will be incorrect. The "
	 "statistics in Roxen will continue being correct.");
	 
  deflocaledoc("svenska", "RestoreConnLogFull",
	       "Loggning: Logga hela fillängden vid återstartad nerladdning",
	       "När den här flaggar är satt så loggar Roxen hela längden på "
	       "en fil vars nerladdning återstartas. Om en användare först "
	       "laddar hem 100 bytes av en fil och sedan laddar hem de "
	       "återstående 900 bytes av filen med en Range-request så "
	       "kommer Roxen logga det som alla 1000 bytes hade laddats hem. "
	       "<p>Detta kan vara användbart om du vill se om en användare "
	       "har lyckats ladda hem hela filen. I normalfallet vill du att "
	       "ha denna flagga avslagen.");

  globvar("show_internals", 1, "Show internal errors", TYPE_FLAG,
#"Show 'Internal server error' messages to the user. 
This is very useful if you are debugging your own modules 
or writing Pike scripts.");
  
  deflocaledoc( "svenska", "show_internals", "Visa interna fel",
		#"Visa interna server fel för användaren av servern. 
Det är väldigt användbart när du utvecklar egna moduler eller pikeskript.");

  globvar("default_font_size", 32, 0, TYPE_INT, 0, 0, 1);
  globvar("default_font", "lucida", "Fonts: Default font", TYPE_FONT,
	  "The default font to use when modules request a font.");
  
  deflocaledoc( "svenska", "default_font", "Typsnitt: Normaltypsnitt",
		#"När moduler ber om en typsnitt som inte finns, eller skriver 
grafisk text utan att ange ett typsnitt, så används det här typsnittet.");

  globvar("font_dirs", ({"../local/nfonts/", "nfonts/" }),
	  "Fonts: Font directories", TYPE_DIR_LIST,
	  "This is where the fonts are located.");

  deflocaledoc( "svenska", "font_dirs", "Typsnitt: Typsnittssökväg",
		"Sökväg för typsnitt.");


  globvar("logdirprefix", "../logs/", "Logging: Log directory prefix",
	  TYPE_DIR|VAR_MORE,
	  #"This is the default file path that will be prepended to the log 
 file path in all the default modules and the virtual server.");

  deflocaledoc( "svenska", "logdirprefix", "Loggning: Loggningsmappprefix",
		"Alla nya loggar som skapas får det här prefixet.");
  
  globvar("cache", 0, "Proxy disk cache: Enabled", TYPE_FLAG,
	  "If set to Yes, caching will be enabled.");
  deflocaledoc( "svenska", "cache", "Proxydiskcache: På", 
		"Om ja, använd cache i alla proxymoduler som hanterar det.");
  
  globvar("garb_min_garb", 1, "Proxy disk cache: Clean size", TYPE_INT,
  "Minimum number of Megabytes removed when a garbage collect is done.",
	  0, cache_disabled_p);
  deflocaledoc( "svenska", "garb_min_garb",
		"Proxydiskcache: Minimal rensningsmängd", 
		"Det minsta antalet Mb som tas bort vid en cacherensning.");
  

  globvar("cache_minimum_left", 5, "Proxy disk cache: Minimum "
	  "available free space and inodes (in %)", TYPE_INT,
#"If less than this amount of disk space or inodes (in %) is left, 
 the cache will remove a few files. This check may work 
 half-hearted if the diskcache is spread over several filesystems.",
	  0,
#if constant(filesystem_stat)
	  cache_disabled_p
#else
	  1
#endif /* filesystem_stat */
	  );
  deflocaledoc( "svenska", "cache_minimum_free", 
		"Proxydiskcache: Minimal fri disk", 
	"Om det är mindre plats (i %) ledigt på disken än vad som "
	"anges i den här variabeln så kommer en cacherensning ske.");
  
  
  globvar("cache_size", 25, "Proxy disk cache: Size", TYPE_INT,
	  "How many MB may the cache grow to before a garbage collect is done?",
	  0, cache_disabled_p);
  deflocaledoc( "svenska", "cache_size", "Proxydiskcache: Storlek", 
		"Cachens maximala storlek, i Mb.");

  globvar("cache_max_num_files", 0, "Proxy disk cache: Maximum number "
	  "of files", TYPE_INT, "How many cache files (inodes) may "
	  "be on disk before a garbage collect is done ? May be left "
	  "zero to disable this check.",
	  0, cache_disabled_p);
  deflocaledoc( "svenska", "cache_max_num_files", 
		"Proxydiskcache: Maximalt antal filer", 
		"Om det finns fler än så här många filer i cachen "
		"kommer en cacherensning ske. Sätt den här variabeln till "
		"noll för att hoppa över det här testet.");
  
  globvar("bytes_per_second", 50, "Proxy disk cache: Bytes per second", 
	  TYPE_INT,
	  "How file size should be treated during garbage collect. "
	  " Each X bytes counts as a second, so that larger files will"
	  " be removed first.",
	  0, cache_disabled_p);
  deflocaledoc( "svenska", "bytes_per_second", 
		"Proxydiskcache: Bytes per sekund", 
		"Normalt sätt så tas de äldsta filerna bort, men filens "
		"storlek modifierar dess 'ålder' i cacherensarens ögon. "
		"Den här variabeln anger hur många bytes som ska motsvara "
		"en sekund.");

  globvar("cachedir", "/tmp/roxen_cache/",
	  "Proxy disk cache: Base Cache Dir",
	  TYPE_DIR,
	  "This is the base directory where cached files will reside. "
	  "To avoid mishaps, 'roxen_cache/' is always prepended to this "
	  "variable.",
	  0, cache_disabled_p);
  deflocaledoc("svenska", "cachedir", "Proxydiskcache: Cachedirectory",
	       "Den här variabeln anger vad cachen ska sparas. "
	       "För att undvika fatala misstag så adderas alltid "
	       "'roxen_cache/' till den här variabeln när den sätts om.");

  globvar("hash_num_dirs", 500,
	  "Proxy disk cache: Number of hash directories",
	  TYPE_INT,
	  "This is the number of directories to hash the contents of the disk "
	  "cache into.  Changing this value currently invalidates the whole "
	  "cache, since the cache cannot find the old files.  In the future, "
	  " the cache will be recalculated when this value is changed.",
	  0, cache_disabled_p); 
  deflocaledoc("svenska", "hash_num_dirs", 
	       "Proxydiskcache: Antalet cachesubdirectoryn",
	       "Disk cachen lagrar datan i flera directoryn, den här "
	       "variabeln anger i hur många olika directoryn som datan ska "
	       "lagras. Om du ändrar på den här variabeln så blir hela den "
	       "gamla cachen invaliderad.");
  
  globvar("cache_keep_without_content_length", 1, "Proxy disk cache: "
	  "Keep without Content-Length", TYPE_FLAG, "Keep files "
	  "without Content-Length header information in the cache?",
	  0, cache_disabled_p);
  deflocaledoc("svenska", "cache_keep_without_content_length", 
	       "Proxydiskcache: Behåll filer utan angiven fillängd",
	       "Spara filer även om de inte har någon fillängd. "
	       "Cachen kan innehålla trasiga filer om den här "
	       "variabeln är satt, men fler filer kan sparas");

  globvar("cache_check_last_modified", 0, "Proxy disk cache: "
	  "Refresh on Last-Modified", TYPE_FLAG,
	  "If set, refreshes files without Expire header information "
	  "when they have reached double the age they had when they got "
	  "cached. This may be useful for some regularly updated docs as "
	  "online newspapers.",
	  0, cache_disabled_p);
  deflocaledoc("svenska", "cache_check_last_modified", 
	       "Proxydiskcache: Kontrollera värdet at Last-Modifed headern",
#"Om den här variabeln är satt så kommer även filer utan Expire header att tas
bort ur cachen när de blir dubbelt så gamla som de var när de hämtades från
källservern om de har en last-modified header som anger när de senast 
ändrades");

  globvar("cache_last_resort", 0, "Proxy disk cache: "
	  "Last resort (in days)", TYPE_INT,
	  "How many days shall files without Expires and without "
	  "Last-Modified header information be kept?",
	  0, cache_disabled_p);
  deflocaledoc("svenska", "cache_last_resort", 
	       "Proxydiskcache: Spara filer utan datum",
	       "Hur många dagar ska en fil utan både Expire och "
	       "Last-Modified behållas i cachen? Om du sätter den "
	       "här variabeln till noll kommer de inte att sparas alls.");

  globvar("cache_gc_logfile",  "",
	  "Proxy disk cache: "
	  "Garbage collector logfile", TYPE_FILE,
	  "Information about garbage collector runs, removed and refreshed "
	  "files, cache and disk status goes here.",
	  0, cache_disabled_p);

  deflocaledoc("svenska", "cache_gc_logfile", 
	       "Proxydiskcache: Loggfil",
	       "Information om cacherensningskörningar sparas i den här filen"
	       ".");
  /// End of cache variables..

  globvar("pidfile", "/tmp/roxen_pid_$uid", "PID file",
	  TYPE_FILE|VAR_MORE,
	  "In this file, the server will write out it's PID, and the PID "
	  "of the start script. $pid will be replaced with the pid, and "
	  "$uid with the uid of the user running the process.\n"
	  "<p>Note: It will be overridden by the command line option.");
  deflocaledoc("svenska", "pidfile", "ProcessIDfil",
	       "I den här filen sparas roxen processid och processidt "
	       "for roxens start-skript. $uid byts ut mot användaridt för "
	       "den användare som kör roxen");

  globvar("default_ident", 1, "Identify: Use default identification string",
	  TYPE_FLAG|VAR_MORE,
	  "Setting this variable to No will display the \"Identify as\" node "
	  "where you can state what Roxen should call itself when talking "
	  "to clients, otherwise it will present it self as \""+ real_version
	  +"\".<br>"
	  "It is possible to disable this so that you can enter an "
	  "identification-string that does not include the actual version of "
	  "Roxen, as recommended by the HTTP/1.0 draft 03:<p><blockquote><i>"
	  "Note: Revealing the specific software version of the server "
	  "may allow the server machine to become more vulnerable to "
	  "attacks against software that is known to contain security "
	  "holes. Server implementors are encouraged to make this field "
	  "a configurable option.</i></blockquote>");
  deflocaledoc("svenska", "default_ident", "Identitet: Använd roxens normala"
	       " identitetssträng",
	       "Ska roxen använda sitt normala namn ("+real_version+")."
	       "Om du sätter den här variabeln till 'nej' så kommer du att "
	       "få välja vad roxen ska kalla sig.");

  globvar("ident", replace(real_version," ","·"), "Identify: Identify as",
	  TYPE_STRING /* |VAR_MORE */,
	  "Enter the name that Roxen should use when talking to clients. ",
	  0, ident_disabled_p);
  deflocaledoc("svenska", "ident", "Identitet: Roxens identitet",
	       "Det här är det namn som roxen kommer att använda sig av.");


//   globvar("NumAccept", 1, "Number of accepts to attempt",
// 	  TYPE_INT_LIST|VAR_MORE,
// 	  "You can here state the maximum number of accepts to attempt for "
// 	  "each read callback from the main socket. <p> Increasing this value "
// 	  "will make the server faster for users making many simultaneous "
// 	  "connections to it, or if you have a very busy server. The higher "
// 	  "you set this value, the less load balancing between virtual "
// 	  "servers. (If there are 256 more or less simultaneous "
// 	  "requests to server 1, and one to server 2, and this variable is "
// 	  "set to 256, the 256 accesses to the first server might very well "
// 	  "be handled before the one to the second server.)",
// 	  ({ 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024 }));
//   deflocaledoc("svenska", "NumAccept", 
// 	       "Uppkopplingsmottagningsförsök per varv i huvudloopen",
// 	       "Antalet uppkopplingsmottagningsförsök per varv i huvudlopen. "
// 	       "Om du ökar det här värdet så kan server svara snabbare om "
// 	       "väldigt många använder den, men lastbalanseringen mellan dina "
// 	       "virtuella servrar kommer att bli mycket sämre (tänk dig att "
// 	       "det ligger 255 uppkopplingar och väntar i kön för en server"
// 	       ", och en uppkoppling i kön till din andra server, och du  "
// 	       " har satt den här variabeln till 256. Alla de 255 "
// 	       "uppkopplingarna mot den första servern kan då komma "
// 	       "att hanteras <b>före</b> den ensamma uppkopplingen till "
// 	       "den andra server.");


  globvar("User", "", "Change uid and gid to", TYPE_STRING,
	  "When roxen is run as root, to be able to open port 80 "
	  "for listening, change to this user-id and group-id when the port "
	  " has been opened. If you specify a symbolic username, the "
	  "default group of that user will be used. "
	  "The syntax is user[:group].");
  deflocaledoc("svenska", "User", "Byt UID till",
#"När roxen startas som root, för att kunna öppna port 80 och köra CGI skript
samt pike skript som den användare som äger dem, så kan du om du vill
specifiera ett användarnamn här. Roxen kommer om du gör det att byta till den
användaren när så fort den har öppnat sina portar. Roxen kan dock fortfarande
byta tillbaka till root för att köra skript som rätt användare om du inte
sätter variabeln 'Byt UID och GID permanent' till ja.  Användaren kan
specifieras antingen som ett symbolisk användarnamn (t.ex. 'www') eller som ett
numeriskt användarID.  Om du vill kan du specifera vilken grupp som ska
användas genom att skriva användare:grupp. Normalt sätt så används användarens
normal grupper.");

  globvar("permanent_uid", 0, "Change uid and gid permanently", 
	  TYPE_FLAG,
	  "If this variable is set, roxen will set it's uid and gid "
	  "permanently. This disables the 'exec script as user' fetures "
	  "for CGI, and also access files as user in the filesystems, but "
	  "it gives better security.");
  deflocaledoc("svenska", "permanent_uid",
	       "Byt UID och GID permanent",
#"Om roxen byter UID och GID permament kommer det inte gå att konfigurera nya
  portar under 1024, det kommer inte heller gå att köra CGI och pike skript som
  den användare som äger skriptet. Däremot så kommer säkerheten att vara högre,
  eftersom ingen kan få roxen att göra något som administratöranvändaren 
  root");

  globvar("ModuleDirs", ({ "../local/modules/", "modules/" }),
	  "Module directories", TYPE_DIR_LIST,
	  "This is a list of directories where Roxen should look for "
	  "modules. Can be relative paths, from the "
	  "directory you started roxen, " + getcwd() + " this time."
	  " The directories are searched in order for modules.");
  deflocaledoc("svenska", "ModuleDirs", "Modulsökväg",
#"En lista av directoryn som kommer att sökas igenom när en 
  modul ska laddas. Directorynamnen kan vara relativa från "+getcwd()+
", och de kommer att sökas igenom i den ordning som de står i listan.");

  globvar("Supports", "#include <etc/supports>\n", 
	  "Client supports regexps", TYPE_TEXT_FIELD|VAR_MORE,
	  "What do the different clients support?\n<br>"
	  "The default information is normally fetched from the file "+
	  getcwd()+"etc/supports, and the format is:<pre>"
	  "regular-expression"
	  " feature, -feature, ...\n"
	  "</pre>"
	  "If '-' is prepended to the name of the feature, it will be removed"
	  " from the list of features of that client. All patterns that match"
	  " each given client-name are combined to form the final feature list"
	  ". See the file etc/supports for examples.");
  deflocaledoc("svenska", "Supports", 
	       "Bläddrarfunktionalitetsdatabas",
#"En databas över vilka funktioner de olika bläddrarna som används klarar av.
  Normalt sätt så hämtas den här databasen från filen server/etc/supports, men
  du kan om du vill specifiera fler mönster i den här variabeln. Formatet ser
  ur så här:<pre>
  reguljärt uttryck som matchar bäddrarens namn	funktion, funktion, ...
 </pre>Se filen server/etc/supports för en mer utförlig dokumentation");

  globvar("audit", 0, "Logging: Audit trail", TYPE_FLAG,
	  "If Audit trail is set to Yes, all changes of uid will be "
	  "logged in the Event log.");
  deflocaledoc("svenska", "audit", "Loggning: Logga alla användaridväxlingar",
#"Om du slår på den är funktionen så kommer roxen logga i debugloggen (eller
systemloggen om den funktionen används) så fort användaridt byts av någon
anlending.");

#if efun(syslog) 
  globvar("LogA", "file", "Logging: Logging method", TYPE_STRING_LIST|VAR_MORE, 
	  "What method to use for logging, default is file, but "
	  "syslog is also available. When using file, the output is really"
	  " sent to stdout and stderr, but this is handled by the "
	  "start script.",
	  ({ "file", "syslog" }));
  deflocaledoc("svenska", "LogA", "Loggning: Loggningsmetod",
#"Hur ska roxens debug, fel, informations och varningsmeddelanden loggas?
  Normalt sätt så loggas de tilldebugloggen (logs/debug/defaul.1 etc), men de
  kan även skickas till systemloggen kan om du vill.",
		 ([ "file":"loggfil",
		    "syslog":"systemloggen"]));
  
  globvar("LogSP", 1, "Logging: Log PID", TYPE_FLAG,
	  "If set, the PID will be included in the syslog.", 0,
	  syslog_disabled);
  deflocaledoc("svenska", "LogSP", "Loggning: Logga roxens processid",
		 "Ska roxens processid loggas i systemloggen?");

  globvar("LogCO", 0, "Logging: Log to system console", TYPE_FLAG,
	  "If set and syslog is used, the error/debug message will be printed"
	  " to the system console as well as to the system log.",
	  0, syslog_disabled);
  deflocaledoc("svenska", "LogCO", "Loggning: Logga till konsolen",
	       "Ska roxen logga till konsolen? Om den här variabeln är satt "
	       "kommer alla meddelanden som går till systemloggen att även "
	       "skickas till datorns konsol.");

  globvar("LogST", "Daemon", "Logging: Syslog type", TYPE_STRING_LIST,
	  "When using SYSLOG, which log type should be used.",
	  ({ "Daemon", "Local 0", "Local 1", "Local 2", "Local 3",
	     "Local 4", "Local 5", "Local 6", "Local 7", "User" }),
	  syslog_disabled);
  deflocaledoc( "svenska", "LogST", "Loggning: Systemloggningstyp",
		"När systemloggen används, vilken loggningstyp ska "
		"roxen använda?");
		
  globvar("LogWH", "Errors", "Logging: Log what to syslog", TYPE_STRING_LIST,
	  "When syslog is used, how much should be sent to it?<br><hr>"
	  "Fatal:    Only messages about fatal errors<br>"+
	  "Errors:   Only error or fatal messages<br>"+
	  "Warning:  Warning messages as well<br>"+
	  "Debug:    Debug messager as well<br>"+
	  "All:      Everything<br>",
	  ({ "Fatal", "Errors",  "Warnings", "Debug", "All" }),
	  syslog_disabled);
  deflocaledoc("svenska", "LogWH", "Loggning: Logga vad till systemloggen",
	       "När systemlogen används, vad ska skickas till den?<br><hr>"
          "Fatala:    Bara felmeddelenaden som är uppmärkta som fatala<br>"+
	  "Fel:       Bara felmeddelanden och fatala fel<br>"+
	  "Varningar: Samma som ovan, men även alla varningsmeddelanden<br>"+
	  "Debug:     Samma som ovan, men även alla felmeddelanden<br>"+
          "Allt:     Allt<br>", 
	       ([ "Fatal":"Fatala", 
		  "Errors":"Fel", 
		  "Warnings":"Varningar", 
		  "Debug":"Debug", 
		  "All":"Allt" ]));

  globvar("LogNA", "Roxen", "Logging: Log as", TYPE_STRING,
	  "When syslog is used, this will be the identification of the "
	  "Roxen daemon. The entered value will be appended to all logs.",
	  0, syslog_disabled);

  deflocaledoc("svenska", "LogNA", 
	       "Loggining: Logga som",
#"När systemloggen används så kommer värdet av den här variabeln användas
  för att identifiera den här roxenservern i loggarna.");
#endif

#ifdef THREADS
  globvar("numthreads", 5, "Number of threads to run", TYPE_INT,
	  "The number of simultaneous threads roxen will use.\n"
	  "<p>Please note that even if this is one, Roxen will still "
	  "be able to serve multiple requests, using a select loop based "
	  "system.\n"
	  "<i>This is quite useful if you have more than one CPU in "
	  "your machine, or if you have a lot of slow NFS accesses.</i>");
  deflocaledoc("svenska", "numthreads",
	       "Antal trådar",
#"Roxen har en så kallad trådpool. Varje förfrågan som kommer in till roxen
 hanteras av en tråd, om alla trådar är upptagna så ställs frågan i en kö.
 Det är bara själva hittandet av rätt fil att skicka som använder de här
 trådarna, skickandet av svaret till klienten sker i bakgrunden, så du behöver
 bara ta hänsyn till evenetuella processorintensiva saker (som &lt;gtext&gt;)
 när då ställer in den här variabeln. Skönskvärdet 5 räcker för de allra 
 flesta servrar");
#endif
  
  globvar("AutoUpdate", 1, "Update the supports database automatically",
	  TYPE_FLAG, 
	  "If set to Yes, the etc/supports file will be updated automatically "
	  "from www.roxen.com now and then. This is recomended, since "
	  "you will then automatically get supports information for new "
	  "clients, and new versions of old ones.");
  deflocaledoc("svenska", "AutoUpdate",
	       "Uppdatera 'supports' databasen automatiskt",
#"Ska supportsdatabasen uppdateras automatiskt från www.roxen.com en gång per
 vecka? Om den här optionen är påslagen så kommer roxen att försöka ladda ner
  en ny version av filen etc/supports från http://www.roxen.com/supports en 
  gång per vecka. Det är rekommenderat att du låter den vara på, eftersom det
  kommer nya versioner av bläddrare hela tiden, som kan hantera nya saker.");

  globvar("next_supports_update", time()+3600, "", TYPE_INT,"",0,1);

  globvar("abs_engage", 0, "Anti-Block-System: Enable", TYPE_FLAG|VAR_MORE,
#"If set, the anti-block-system will be enabled.
  This will restart the server after a configurable number of minutes if it 
  locks up. If you are running in a single threaded environment heavy 
  calculations will also halt the server. In multi-threaded mode bugs such as 
  eternal loops will not cause the server to reboot, since only one thread is
  blocked. In general there is no harm in having this option enabled. ");

  deflocaledoc("svenska", "abs_engage",
	       "AntiBlockSystem: Slå på AntiBlockSystemet",
#"Ska antilåssystemet vara igång? Om det är det så kommer roxen automatiskt
  att starta om om den har hängt sig mer än några minuter. Oftast så beror
  hängningar på buggar i antingen operativsystemet eller i en modul. Den 
  senare typen av hängningar påverkar inte en trådad roxen, medans den första
  typen gör det.");

  globvar("abs_timeout", 5, "Anti-Block-System: Timeout", 
	  TYPE_INT_LIST|VAR_MORE,
#"If the server is unable to accept connection for this many 
  minutes, it will be restarted. You need to find a balance: 
  if set too low, the server will be restarted even if it's doing 
  legal things (like generating many images), if set too high you might 
  get a long downtime if the server for some reason locks up.",
  ({1,2,3,4,5,10,15}),
  lambda() {return !QUERY(abs_engage);});

  deflocaledoc("svenska", "abs_timeout",
	       "AntiBlockSystem: Tidsbegränsning",
#"Om servern inte svarar på några frågor under så här många 
 minuter så kommer roxen startas om automatiskt.  Om du 
 har en väldigt långsam dator kan en minut vara för 
 kort tid för en del saker, t.ex. diagramritning kan ta 
 ett bra tag.");


  globvar("locale", "standard", "Language", TYPE_STRING_LIST,
	  "Locale, used to localise all messages in roxen.\n"
#"Standard means using the default locale, which varies according to the 
value of the 'LANG' environment variable.", 
          sort(indices(master()->resolv("Locale")["Roxen"]) 
               - ({ "Modules" })));
  deflocaledoc("svenska", "locale", "Språk",
	       "Den här variablen anger vilket språk roxen ska använda. "
	       "'standard' betyder att språket sätts automatiskt från "
	       "värdet av omgivningsvariabeln LANG.");

  globvar("suicide_engage",
	  0,
	  "Automatic Restart: Enable",
	  TYPE_FLAG|VAR_MORE,
#"If set, Roxen will automatically restart after a configurable number of
days. Since Roxen uses a monolith, non-forking server model the process tends
to grow in size over time. This is mainly due to heap fragmentation but also
because of memory leaks."
	  );
  deflocaledoc("svenska", "suicide_engage",
	       "Automatisk omstart: Starta om automatiskt",
#"Roxen har stöd för att starta automatiskt då ock då. Eftersom roxen är en
monolitisk icke-forkande server (en enda långlivad process) så tenderar
processen att växa med tiden.  Det beror mest på minnesfragmentation, men även
på att en del minnesläckor fortfarande finns kvar. Ett sätt att återvinna minne
är att starta om servern lite då och då, vilket roxen kommer att göra om du
slår på den här funktionen. Notera att det tar ett litet tag att starta om
 servern.");

globvar("suicide_timeout",
	  7,
	  "Automatic Restart: Timeout",
	  TYPE_INT_LIST|VAR_MORE,
	  "Automatically restart the server after this many days.",
	  ({1,2,3,4,5,6,7,14,30}),
	  lambda(){return !QUERY(suicide_engage);});
  deflocaledoc("svenska", "suicide_timeout",
	       "Automatisk omstart: Tidsbegränsning (i dagar)",
#"Om roxen är inställd till att starta om automatiskt, starta om
så här ofta. Tiden är angiven i dagar");


  globvar("argument_cache_in_db", 0, 
         "Argument Cache: Store the argument cache in a mysql database",
         TYPE_FLAG|VAR_MORE,
         "If set, store the argument cache in a mysql "
         "database. This is very useful for load balancing using multiple "
         "roxen servers, since the mysql database will handle "
          " synchronization"); 
  deflocaledoc("svenska", "argument_cache_in_db",
               "Argumentcache: Spara cachen i en databas",
               "Om den här variabeln är satt så sparas argumentcachen i en "
               "databas istället för filer. Det gör det möjligt att använda "
               "multipla frontendor, dvs, flera separata roxenservrar som "
               "serverar samma site" );

  globvar( "argument_cache_db_path", "mysql://localhost/roxen", 
          "Argument Cache: Database URL to use",
          TYPE_STRING|VAR_MORE,
          "The database to use to store the argument cache",
          0,
          lambda(){ return !QUERY(argument_cache_in_db); });
  deflocaledoc("svenska", "argument_cache_db_path",
               "Argumentcache: Databas URL",
               "Databasen i vilken argumentcachen kommer att sparas" );

  globvar( "argument_cache_dir", "../argument_cache/", 
          "Argument Cache: Cache directory",
          TYPE_DIR|VAR_MORE,
          "The cache directory to use to store the argument cache."
          " Please note that load balancing is not available for most modules "
          " (such as gtext, diagram etc) unless you use a mysql database to "
          "store the argument caches");
  deflocaledoc("svenska", "argument_cache_dir",
               "Argumentcache: Cachedirectory",
               "Det directory i vilket cachen kommer att sparas. "
               " Notera att lastbalansering inte fungerar om du inte sparar "
               "cachen i en databas, och även om du sparar cachen i en "
               "databas så kommer det fortfarande skrivas saker i det "
               "här directoryt.");


  setvars(retrieve("Variables", 0));

  for(p = 1; p < argc; p++)
  {
    string c, v;
    if(sscanf(argv[p],"%s=%s", c, v) == 2)
    {
      sscanf(c, "%*[-]%s", c);
      if(variables[c])
      {
        if(catch{
          mixed res = compile_string( "mixed f(){ return "+v+";}")()->f();
          if(sprintf("%t", res) != sprintf("%t", variables[c][VAR_VALUE]) &&
             res != 0 && variables[c][VAR_VALUE] != 0)
            werror("Warning: Setting variable "+c+"\n"
                   "to a value of a different type than the default value.\n"
                   "Default was "+sprintf("%t", variables[c][VAR_VALUE])+
                   " new is "+sprintf("%t", res)+"\n");
          variables[c][VAR_VALUE]=res;
        })
        {
          werror("Warning: Asuming '"+v+"' should be taken "
                 "as a string value.\n");
          if(!stringp(variables[c][VAR_VALUE]))
            werror("Warning: Old value was not a string.\n");
          variables[c][VAR_VALUE]=v;
        }
      }
      else
	perror("Unknown variable: "+c+"\n");
    }
  }
}


static mapping __vars = ([ ]);

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
