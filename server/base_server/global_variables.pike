// This file is part of Roxen Webserver.
// Copyright © 1996 - 2000, Roxen IS.
// $Id: global_variables.pike,v 1.29 2000/04/13 19:01:55 per Exp $

#pragma strict_types
#define DEFVAR string,int|string,string|mapping,int,string|mapping(string:string),void|array(string),void|function:void
#define BDEFVAR string,int|string,string|mapping,int,string|mapping(string:string),void|array(string),void|mapping(string:mapping(string:string)):void

#include <module.h>
#include <roxen.h>
#include <config.h>
inherit "read_config";
inherit "module_support";
#include <version.h>

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
           "Welcome text",TYPE_TEXT,
          "The text shown the the user on connect" );

  defvar( "ftp_user_session_limit", 0, "User session limit", TYPE_INT,
          "The maximum number of times a user can connect at once."
          " 0 means unlimited" );

  defvar( "named_ftp", 1,  "Allow named ftp", TYPE_FLAG,
          "If yes, non-anonymous users can connect" );

  defvar( "guest_ftp", 1,"Allow login with incorrect password/user", TYPE_FLAG,
          "If yes, users can connect with the wrong password and/or username"
          ". This is useful since things like .htaccess files can later on "
          "authenticate the user.");

  defvar( "anonymous_ftp", 1, "Allow anonymous ftp", TYPE_FLAG,
          "If yes, anonymous users can connect" );

  defvar( "shells", "",  "Shell database", TYPE_FILE,
          "If this string is set to anything but the empty string, "
          "it should point to a file containing a list of valid shells. "
          "Users with shells that does not figure in this list will not "
          "be allowed to log in." );
}


void set_up_http_variables( object o, int|void fhttp )
{
  function(DEFVAR) defvar =
    [function(DEFVAR)] o->defvar;
  function(string,string,string,string:void) deflocaledoc =
    [function(string,string,string,string:void)] o->deflocaledoc;

  defvar("show_internals", 1, "Show internal errors", TYPE_FLAG,
#"Show 'Internal server error' messages to the user.
This is very useful if you are debugging your own modules
or writing Pike scripts.");

  deflocaledoc( "svenska", "show_internals", "Visa interna fel",
		#"Visa interna server fel för användaren av servern.
Det är väldigt användbart när du utvecklar egna moduler eller pikeskript.");
  deflocaledoc( "deutsch", "show_internals", "Anzeige von internen Fehlern",
		#"Anzeige von internen Server-Fehlern an den Benutzer.
Dies ist bei der Entwicklung und bei der Fehlersuche von eigenen Modulen
oder Pike-Scripten nützlich.");

  if(!fhttp)
  {
    defvar("set_cookie", 0, "Logging: Set unique user id cookies", TYPE_FLAG,
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
    deflocaledoc( "deutsch", "set_cookie",
                  "Logging: Setzen eines eindeutigen Benutzer-Cookies",
#"An alle Benutzer der Website wird ein eindeutiger Benutzer-Cookie geschickt,
sofern deren Browser Cookies annimmt.  Dieser kann in Scripten und im Logfile
zur Identifizierung einzelner Benutzer verwendet werden.");

    defvar("set_cookie_only_once",1,"Logging: Set ID cookies only once",
           TYPE_FLAG,
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
    deflocaledoc( "deutsch", "set_cookie_only_once",
                  "Logging: Benutzer-Cookie nur einmal setzen",
#"Dem Benutzer wird nur beim ersten Aufruf ein eindeutiger Benutzer-Cookie
geschickt. Dadurch wird der Benutzer nur einmal aufgefordert, einen Cookie
anzunehmen.");
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


void define_global_variables( int argc, array (string) argv )
{
  int p;

  globvar("port_options", ([]), "Ports: Options", VAR_EXPERT|TYPE_CUSTOM,
	  "Mapping with options and defaults for all ports.\n",
	  ({
	    lambda(mixed value, int action) {
	      return "Edit the cofig-file by hand for now.";
	    },
            lambda(){},
	  }));

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
	       "När den här flaggan är satt så loggar Roxen hela längden på "
	       "en fil vars nerladdning återstartas. Om en användare först "
	       "laddar hem 100 bytes av en fil och sedan laddar hem de "
	       "återstående 900 bytes av filen med en Range-request så "
	       "kommer Roxen logga det som alla 1000 bytes hade laddats hem. "
	       "<p>Detta kan vara användbart om du vill se om en användare "
	       "har lyckats ladda hem hela filen. I normalfallet vill du "
	       "ha denna flagga avslagen.");
  deflocaledoc("deutsch", "RestoreConnLogFull",
               "Logging: Verzeichnen die bisher verschickten Daten "
	       "beim wiederaufgenommenen Verbindungen",
	       "Bei wiederaufgenommenen Verbindungen werden die "
               "übertragenen Daten sowie die bisher verschickten Daten "
               "verzeichnet.  Wenn ein Benutzer bereits 100 Bytes einer Datei "
               "geladen hat, und in einem späteren Download die fehlenden 900 "
               "Bytes überträgt, werden im Logfile die gesamten 1000 Bytes "
               "verzeichnet.<p>Dies ist nützlich, um erfolgreiche Downloads "
               "zu erkennen.");

  globvar("default_font", "franklin_gothic_demi", "Default font", TYPE_FONT,
	  "The default font to use when modules request a font.");

  deflocaledoc( "svenska", "default_font", "Normaltypsnitt",
		#"När moduler ber om en typsnitt som inte finns, eller skriver
grafisk text utan att ange ett typsnitt, så används det här typsnittet.");
  deflocaledoc( "deutsch", "default_font", "Standard-Schriftart",
                "#Die Schriftart, die von Modulen benutzt werden soll.");


  globvar("font_dirs", ({"../local/nfonts/", "nfonts/" }),
	  "Font directories", TYPE_DIR_LIST,
	  "This is where the fonts are located.");

  deflocaledoc( "svenska", "font_dirs", "Typsnittssökväg",
		"Sökväg för typsnitt.");
  deflocaledoc( "deutsch", "font_dirs", "Schriftarten-Verzeichnisse",
                "In diesen Verzeichnissen befinden sich Schriftarten.");

  globvar("logdirprefix", "../logs/", "Logging: Log directory prefix",
	  TYPE_STRING|VAR_MORE,
	  #"This is the default file path that will be prepended to the log
 file path in all the default modules and the virtual server.");

  deflocaledoc( "svenska", "logdirprefix", "Loggning: Loggningsmappprefix",
		"Alla nya loggar som skapas får det här prefixet.");
  deflocaledoc( "deutsch", "logdirprefix", "Logging: Logverzeichnis-Prefix",
		#"Alle Logdateien werden unterhalb dieses Verzeichnisses
                 abgelegt.");

  globvar("cache", 0, "Cache: Proxy Disk Cache Enabled", TYPE_FLAG,
	  "If set to Yes, caching will be enabled.");
  deflocaledoc( "svenska", "cache", "Cache: Proxydiskcachen är på",
		"Om ja, använd cache i alla proxymoduler som hanterar det.");
  deflocaledoc( "deutsch", "cache", "Cache: Proxy-Cache aktivieren",
		"Der Proxy-Festplatten-Cache wird benutzt.");

  globvar("garb_min_garb", 1, "Cache: Proxy Disk Cache Clean size", TYPE_INT,
  "Minimum number of Megabytes removed when a garbage collect is done.",
	  0, cache_disabled_p);
  deflocaledoc( "svenska", "garb_min_garb",
		"Cache: Proxydiskcache Minimal rensningsmängd",
		"Det minsta antalet Mb som tas bort vid en cacherensning.");
  deflocaledoc( "deutsch", "garb_min_garb",
		"Cache: Proxy Disk Cache Reinigungsgröße",
		#"Wird der Cache geleert, werden mindestens soviel Megabytes
                 entfernt.");


  globvar("cache_minimum_left", 5, "Cache: Proxy Disk Cache Minimum "
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
		"Cache: Proxydiskcache minimal fri disk",
	"Om det är mindre plats (i %) ledigt på disken än vad som "
	"anges i den här variabeln så kommer en cacherensning ske.");
  deflocaledoc( "deutsch", "cache_minimum_free",
		"Cache: Minimale Größe des Proxy-Caches",
	"Bei Unterschreiten dieses Wertes (in %) werden einige Dateien "
	"aus dem Cache entfernt.");


  globvar("cache_size", 25, "Cache: Proxy Disk Cache Size", TYPE_INT,
	  "How many MB may the cache grow to before a garbage collect is done?",
	  0, cache_disabled_p);
  deflocaledoc( "svenska", "cache_size", "Cache: Proxydiskcachens storlek",
		"Cachens maximala storlek, i Mb.");
  deflocaledoc( "deutsch", "cache_size", "Cache: Größe des Proxy-Caches",
		"Maximale Größe des Proxy-Caches auf der Festplatte, in MB.");

  globvar("cache_max_num_files", 0, "Cache: Proxy Disk Cache Maximum number "
	  "of files", TYPE_INT, "How many cache files (inodes) may "
	  "be on disk before a garbage collect is done ? May be left "
	  "zero to disable this check.",
	  0, cache_disabled_p);
  deflocaledoc( "svenska", "cache_max_num_files",
		"Cache: Proxydiskcache maximalt antal filer",
		"Om det finns fler än så här många filer i cachen "
		"kommer en cacherensning ske. Sätt den här variabeln till "
		"noll för att hoppa över det här testet.");
  deflocaledoc( "deutsch", "cache_max_num_files",
		"Cache: Maximale Anzahl an Dateien im Proxy-Cache",
		"Wie viele Dateien dürfen im Cache sein, bevor eine "
		"Reinigung (Garbage Collection) stattfindet. Durch "
		"Setzen auf Null wird diese Abfrage ignoriert.");

  globvar("bytes_per_second", 50, "Cache: Proxy Disk Cache bytes per second",
	  TYPE_INT,
	  "How file size should be treated during garbage collect. "
	  " Each X bytes counts as a second, so that larger files will"
	  " be removed first.",
	  0, cache_disabled_p);
  deflocaledoc( "svenska", "bytes_per_second",
		"Cache: Proxydiskcache bytes per sekund",
		"Normalt sätt så tas de äldsta filerna bort, men filens "
		"storlek modifierar dess 'ålder' i cacherensarens ögon. "
		"Den här variabeln anger hur många bytes som ska motsvara "
		"en sekund.");
  deflocaledoc( "deutsch", "bytes_per_second",
                "Cache: Proxy-Cache Bytes pro Sekunde",
                "Wie wichtig ist die Dateigröße beim Reinigen des Caches? "
                "Jedes Byte entspricht einem gewissen Dateialter in Sekunden. "
                "Größere Dateien werden also eher entfernt.");


  globvar("cachedir", "/tmp/roxen_cache/",
	  "Cache: Proxy Disk Cache Base Cache Dir",
	  TYPE_DIR,
	  "This is the base directory where cached files will reside. "
	  "To avoid mishaps, 'roxen_cache/' is always prepended to this "
	  "variable.",
	  0, cache_disabled_p);
  deflocaledoc("svenska", "cachedir", "Cache: Proxydiskcachedirectory",
	       "Den här variabeln anger vad cachen ska sparas. "
	       "För att undvika fatala misstag så adderas alltid "
	       "'roxen_cache/' till den här variabeln när den sätts om.");
  deflocaledoc("deutsch", "cachedir", "Cache: Proxy-Cache-Verzeichnis",
	       "In diesem Verzeichnis werden die Cache-Dateien abgelegt. "
               "Um Pannen zu vermeiden, wird 'roxen_cache' an diesen "
               "Wert angehängt.");

  globvar("hash_num_dirs", 500,
	  "Cache: Proxy Disk Cache Number of hash directories",
	  TYPE_INT|VAR_MORE,
	  "This is the number of directories to hash the contents of the disk "
	  "cache into.  Changing this value currently invalidates the whole "
	  "cache, since the cache cannot find the old files.  In the future, "
	  " the cache will be recalculated when this value is changed.",
	  0, cache_disabled_p);
  deflocaledoc("svenska", "hash_num_dirs",
	       "Cache: Proxydiskcache antalet cachesubdirectoryn",
	       "Disk cachen lagrar datan i flera directoryn, den här "
	       "variabeln anger i hur många olika directoryn som datan ska "
	       "lagras. Om du ändrar på den här variabeln så blir hela den "
	       "gamla cachen invaliderad.");
  deflocaledoc("deutsch", "hash_num_dirs",
	       "Cache: Anzahl der Hash-Verzeichnisse im Proxy-Cache",
               "Dies ist die Anzahl an Verzeichnissen, auf die die "
               "Cache-Dateien verteilt werden.  Das Ändern dieses Wertes "
               "macht den bisherigen Proxy-Cache ungültig.");

  globvar("cache_keep_without_content_length", 1, "Cache: "
	  "Proxy Disk Cache Keep without Content-Length",
          TYPE_FLAG, "Keep files "
	  "without Content-Length header information in the cache?",
	  0, cache_disabled_p);
  deflocaledoc("svenska", "cache_keep_without_content_length",
	       "Cache: Proxydiskcachen behåller filer utan angiven fillängd",
	       "Spara filer även om de inte har någon fillängd. "
	       "Cachen kan innehålla trasiga filer om den här "
	       "variabeln är satt, men fler filer kan sparas");
  deflocaledoc("deutsch", "cache_keep_without_content_length",
               "Cache: Dateien ohne Content-Length behalten",
               "Sollen Dateien ohne Content-Length im Cache behalten werden?");

  globvar("cache_check_last_modified", 0, "Cache: "
	  "Proxy Disk Cache Refreshes on Last-Modified", TYPE_FLAG,
	  "If set, refreshes files without Expire header information "
	  "when they have reached double the age they had when they got "
	  "cached. This may be useful for some regularly updated docs as "
	  "online newspapers.",
	  0, cache_disabled_p);
  deflocaledoc("svenska", "cache_check_last_modified",
	       "Cache: Proxydiskcachen kontrollerar värdet "
               "av Last-Modifed headern",
#"Om den här variabeln är satt så kommer även filer utan Expire header att tas
bort ur cachen när de blir dubbelt så gamla som de var när de hämtades från
källservern om de har en last-modified header som anger när de senast
ändrades");
  deflocaledoc("deutsch", "cache_check_last_modified",
               "Cache: Proxy-Cache benutzt Last-Modified-Information",
#"Der Cache wird anhand der Last-Modified-Information Dateien aus dem Cache
entfernen, sofern kein Expire-Header vorhanden ist.  Die Dateien verbleiben
im Cache, bis sie ihr Alter verdoppelt haben.");

  globvar("cache_last_resort", 0, "Cache: "
	  "Proxy Disk Cache Last resort (in days)", TYPE_INT,
	  "How many days shall files without Expires and without "
	  "Last-Modified header information be kept?",
	  0, cache_disabled_p);
  deflocaledoc("svenska", "cache_last_resort",
	       "Cache: Proxydiskcachen sparar filer utan datum",
	       "Hur många dagar ska en fil utan både Expire och "
	       "Last-Modified behållas i cachen? Om du sätter den "
	       "här variabeln till noll kommer de inte att sparas alls.");
  deflocaledoc("deutsch", "cache_last_resort",
               "Cache: Verweildauer (in Tagen) im Proxy-Cache",
               "Wieviel Tage sollen Dateien ohne Expire- und "
               "Last-Modifier-Informationen im Cache verbleiben?");

  globvar("cache_gc_logfile",  "",
	  "Cache: "
	  "Proxy Disk Cache Garbage collector logfile", TYPE_FILE,
	  "Information about garbage collector runs, removed and refreshed "
	  "files, cache and disk status goes here.",
	  0, cache_disabled_p);

  deflocaledoc("svenska", "cache_gc_logfile",
	       "Cache: Proxydiskcacheloggfil",
	       "Information om cacherensningskörningar sparas i den här filen"
	       ".");
  deflocaledoc("deutsch", "cache_gc_logfile",
               "Cache: Logfile für Garbage Collection",
               "Informationen über Aktivitäten der Garbage Collection: "
               "gelöschte und aktualisierte Dateien, Cache- und "
               "Festplatten-Status werden vermerkt.");

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
  deflocaledoc("deutsch", "pidfile", "PID-Datei",
               "In dieser Datei legt der Server seine eigene PID und die "
               "des start-Scripts ablegen. $pid wird mit der PID ersetzt "
               "und $uid mit der UID des ausführenden Benutzers.");

  globvar("default_ident", 1, "Identify, Use default identification string",
	  TYPE_FLAG|VAR_MORE,
	  "Setting this variable to No will display the \"Identify as\" node "
	  "where you can state what Roxen should call itself when talking "
	  "to clients, otherwise it will present it self as \""+ real_version
	  +"\".<br />"
	  "It is possible to disable this so that you can enter an "
	  "identification-string that does not include the actual version of "
	  "Roxen, as recommended by the HTTP/1.0 draft 03:<p><blockquote><i>"
	  "Note: Revealing the specific software version of the server "
	  "may allow the server machine to become more vulnerable to "
	  "attacks against software that is known to contain security "
	  "holes. Server implementors are encouraged to make this field "
	  "a configurable option.</i></blockquote>");
  deflocaledoc("svenska", "default_ident", "Identifiera roxen med "
	       "normala identitetssträngen",
	       "Ska roxen använda sitt normala namn ("+real_version+")?"
	       "Om du sätter den här variabeln till 'nej' så kommer du att "
	       "få välja vad roxen ska kalla sig.");
  deflocaledoc("deutsch", "default_ident", "Benutze Standard-Identität",
               "Bei Nein, kann eine andere Identität als der "
               "Standardwert ("+real_version+") eingetragen werden.");

  globvar("ident", replace(real_version," ","·"), "Identify, Identify as",
	  TYPE_STRING /* |VAR_MORE */,
	  "Enter the name that Roxen should use when talking to clients. ",
	  0, ident_disabled_p);
  deflocaledoc("svenska", "ident", "Identifiera roxen som",
	       "Det här är det namn som roxen kommer att använda sig av "
	       "gentemot omvärlden.");
  deflocaledoc("deutsch", "ident", "Identifiziere Roxen als",
               "Hier kann der Namen eingegeben werden, mit dem Roxen "
               "sich zu erkennen gibt, wenn ein Client Anfragen stellt.");


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
  deflocaledoc("deutsch", "User", "Wechsel von UID und GID zu",
#"Wenn Roxen unter der root-Kennung läuft, um den Port 80 
öffnen zu können, wird die User-ID und die Group-ID auf diesen Wert
gesetzt, nachdem der Port geöffnet wurde. Wenn ein Benutzername (z.B. 'www')
verwendet wird, wird die Standardgruppe dieses Benutzers verwendet.
Die Syntax ist user[:group].");

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
  deflocaledoc("deutsch", "permanent_uid",
               "Permanenter Wechsel von UID und GID",
#"Wenn diese Variable gesetzt ist, wird Roxen seine UID und GID permanent
auf die eingestellten Werte wechseln.  Dadurch können CGI-Scripte nicht
mehr unter der Kennung anderer Benutzer ausgeführt werden. Allerdings
erhöht sich so die Sicherheit des Servers.");

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
  deflocaledoc("deutsch", "ModuleDirs", "Modul-Verzeichnisse",
#"Eine Liste von Verzeichnissen, in denen Roxen nach Modulen
suchen wird. Dies können relative Pfade zu "+getcwd()+#" sein.
Die Verzeichnisse werden in der eingegeben Reihenfolge nach Modulen
durchsucht.");

  globvar("Supports", "#include <etc/supports>\n",
	  "Client supports regexps", TYPE_TEXT_FIELD|VAR_MORE,
	  "What do the different clients support?\n<br />"
	  "The default information is normally fetched from the file "+
	  getcwd()+"/etc/supports, and the format is:<pre>"
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
  Normalt sett hämtas den här databasen från filen server/etc/supports, men
  du kan om du vill specifiera fler mönster i den här variabeln. Formatet ser
  ur så här:<pre>
  reguljärt uttryck 	funktion, funktion
  reguljärt uttryck 	funktion, funktion
  ...
 </pre>Se filen server/etc/supports för en mer utförlig dokumentation");
  deflocaledoc("deutsch", "Supports", "Browser-Unterstützung",
#"Welche unterschiedlichen Möglichkeiten werden durch die verschiedenen
Webbrowser unterstützt. Die Standard-Informationen werden aus der
Datei server/etc/supports entnommen, das Format ist:<pre>
Regulärer Ausdruck    Funktion, Funktion
Regulärer Ausdruck    Funktion, Funktion
...
</pre>Wenn '-' der Funktion vorangestellt wird, wird es von der Liste
entfernt.");

  globvar("audit", 0, "Logging: Audit trail", TYPE_FLAG,
	  "If Audit trail is set to Yes, all changes of uid will be "
	  "logged in the Event log.");
  deflocaledoc("svenska", "audit", "Loggning: Logga alla användaridväxlingar",
#"Om du slår på den är funktionen så kommer roxen logga i debugloggen (eller
systemloggen om den funktionen används) så fort användaridt byts av någon
anlending.");
  deflocaledoc("deutsch", "audit", "Logging: Wechsel der Benutzerkennungen",
#"Wenn auf Ja gesetzt, werden sämtliche Wechsel von Benutzerkennungen
im Ereignis-Log verzeichnet.");

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
  deflocaledoc("deutsch", "LogA", "Logging: Logging-Methode",
#"Welche Methode soll für das Logging benutzt werden. Standard ist Datei,
aber Syslog ist ebenfalls möglich.",
                 ([ "file":"Datei",
                    "syslog":"Syslog"]));

  globvar("LogSP", 1, "Logging: Log PID", TYPE_FLAG,
	  "If set, the PID will be included in the syslog.", 0,
	  syslog_disabled);
  deflocaledoc("svenska", "LogSP", "Loggning: Logga roxens processid",
		 "Ska roxens processid loggas i systemloggen?");
  deflocaledoc("deutsch", "LogSP", "Logging: PID festhalten",
                 "Soll Roxen die eigene PID ins Syslog schreiben?");

  globvar("LogCO", 0, "Logging: Log to system console", TYPE_FLAG,
	  "If set and syslog is used, the error/debug message will be printed"
	  " to the system console as well as to the system log.",
	  0, syslog_disabled);
  deflocaledoc("svenska", "LogCO", "Loggning: Logga till konsolen",
	       "Ska roxen logga till konsolen? Om den här variabeln är satt "
	       "kommer alla meddelanden som går till systemloggen att även "
	       "skickas till datorns konsol.");
  deflocaledoc("deutsch", "LogCO", "Logging: Schreiben auf Konsole",
               "Soll Roxen auf die Konsole schreiben?  Fehler- und "
               "Debug-Meldungen werden sowohl auf die Konsole als auch "
               "in das Syslog geschrieben.");

  globvar("LogST", "Daemon", "Logging: Syslog type", TYPE_STRING_LIST,
	  "When using SYSLOG, which log type should be used.",
	  ({ "Daemon", "Local 0", "Local 1", "Local 2", "Local 3",
	     "Local 4", "Local 5", "Local 6", "Local 7", "User" }),
	  syslog_disabled);
  deflocaledoc( "svenska", "LogST", "Loggning: Systemloggningstyp",
		"När systemloggen används, vilken loggningstyp ska "
		"roxen använda?");
  deflocaledoc( "deutsch", "LogST", "Logging: Syslog-Typ",
                "Wenn Syslog verwendet wird, welcher Typ soll benutzt werden?");

  globvar("LogWH", "Errors", "Logging: Log what to syslog", TYPE_STRING_LIST,
	  "When syslog is used, how much should be sent to it?<br /><hr />"
	  "Fatal:    Only messages about fatal errors<br />"+
	  "Errors:   Only error or fatal messages<br />"+
	  "Warning:  Warning messages as well<br />"+
	  "Debug:    Debug messager as well<br />"+
	  "All:      Everything<br />",
	  ({ "Fatal", "Errors",  "Warnings", "Debug", "All" }),
	  syslog_disabled);
  deflocaledoc("svenska", "LogWH", "Loggning: Logga vad till systemloggen",
	       "När systemlogen används, vad ska skickas till den?<br /><hr />"
          "Fatala:    Bara felmeddelenaden som är uppmärkta som fatala<br />"+
	  "Fel:       Bara felmeddelanden och fatala fel<br />"+
	  "Varningar: Samma som ovan, men även alla varningsmeddelanden<br />"+
	  "Debug:     Samma som ovan, men även alla felmeddelanden<br />"+
          "Allt:     Allt<br />",
	       ([ "Fatal":"Fatala",
		  "Errors":"Fel",
		  "Warnings":"Varningar",
		  "Debug":"Debug",
		  "All":"Allt" ]));
  deflocaledoc("deutsch", "LogWH", "Logging: zu protokollierende Daten",
               "Wenn Syslog verwendet wird, welche Informationen sollen "
               "festgehalten werden?<br /><hr />"
          "Fatal:    Nur Mitteilungen über fatale Fehler<br />"+
          "Errors:   Nur Fehler und fatale Mitteilungen<br />"+
          "Warning:  wie oben, jedoch auch Warnungen<br />"+
          "Debug:    wie oben, jedoch auch Hinweise<br />"+
          "All:      Alles<br />",
               ([ "Fatal":"Fatal",
                  "Errors":"Errors",
                  "Warnings":"Warnings",
                  "Debug":"Debug",
                  "All":"All" ]));

  globvar("LogNA", "Roxen", "Logging: Log as", TYPE_STRING,
	  "When syslog is used, this will be the identification of the "
	  "Roxen daemon. The entered value will be appended to all logs.",
	  0, syslog_disabled);

  deflocaledoc("svenska", "LogNA",
	       "Loggining: Logga som",
#"När systemloggen används så kommer värdet av den här variabeln användas
  för att identifiera den här roxenservern i loggarna.");
  deflocaledoc("deutsch", "LogNA",
               "Logging: Loggen als",
#"Wenn Syslog benutzt wird, wird dieser Wert als Identifikation in allen
Logs angehängt.");
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
  deflocaledoc("deutsch", "numthreads",
               "Anzahl Threads",
#"Die Anzahl an parallelen Threads, mit denen Roxen arbeiten wird.\n
Hinweis: Auch wenn nur ein Thread eingestellt wird, können mehrere
Zugriffe gleichzeitig bearbeitet werden.\n
<i>Dies ist nützlich für Mehrprozessor-Systeme.</i>");
#endif

  globvar("AutoUpdate", 1, "Update the supports database automatically",
	  TYPE_FLAG,
	  "If set to Yes, the etc/supports file will be updated automatically "
	  "from www.roxen.com now and then. This is recomended, since "
	  "you will then automatically get supports information for new "
	  "clients, and new versions of old ones.");
  deflocaledoc("svenska", "AutoUpdate",
	       "Uppdatera bläddrarfunktionalitetsdatabasen automatiskt",
#"Ska supportsdatabasen uppdateras automatiskt från www.roxen.com en gång per
 vecka? Om den här optionen är påslagen så kommer roxen att försöka ladda ner
  en ny version av filen etc/supports från http://www.roxen.com/supports en
  gång per vecka. Det är rekommenderat att du låter den vara på, eftersom det
  kommer nya versioner av bläddrare hela tiden, som kan hantera nya saker.");
  deflocaledoc("deutsch", "AutoUpdate",
               "automatische Aktualisierung der Supports-Datenbank",
#"Die Datei /etc/supports wird automatisch von www.roxen.com aktualisiert.
Dadurch erhält man immer die aktuelle Liste aller bekannten Features.");

  globvar("next_supports_update", time()+3600, "", TYPE_INT,"",0,1);

#ifndef __NT__
  globvar("abs_engage", 0, "ABS: Enable Anti-Block-System", TYPE_FLAG|VAR_MORE,
#"If set, the anti-block-system will be enabled.
  This will restart the server after a configurable number of minutes if it
  locks up. If you are running in a single threaded environment heavy
  calculations will also halt the server. In multi-threaded mode bugs such as
  eternal loops will not cause the server to reboot, since only one thread is
  blocked. In general there is no harm in having this option enabled. ");

  deflocaledoc("svenska", "abs_engage",
	       "ABS: Slå på AntiBlockSystemet",
#"Ska antilåssystemet vara igång? Om det är det så kommer roxen automatiskt
  att starta om om den har hängt sig mer än några minuter. Oftast så beror
  hängningar på buggar i antingen operativsystemet eller i en modul. Den
  senare typen av hängningar påverkar inte en trådad roxen, medans den första
  typen gör det.");
  deflocaledoc("deutsch", "abs_engage",
               "ABS: AntiBlockSystem aktivieren",
#"Das AntiBlockSystem wird aktiviert, dies startet den Server nach einer
einstellbaren Zahl von Minuten neu, wenn ein Thread blockiert ist.  Bei
mehr als einem Thread wird der gesamte Server nicht komplett angehalten,
sondern nur der blockierte Thread.  Im allgemeinen hat diese Option keine
Nachteile.");

  globvar("abs_timeout", 5, "ABS: Timeout",
	  TYPE_INT_LIST|VAR_MORE,
#"If the server is unable to accept connection for this many
  minutes, it will be restarted. You need to find a balance:
  if set too low, the server will be restarted even if it's doing
  legal things (like generating many images), if set too high you might
  get a long downtime if the server for some reason locks up.",
  ({1,2,3,4,5,10,15}),
  lambda() {return !QUERY(abs_engage);});

  deflocaledoc("svenska", "abs_timeout",
	       "ABS: Tidsbegränsning",
#"Om servern inte svarar på några frågor under så här många
 minuter så kommer roxen startas om automatiskt.  Om du
 har en väldigt långsam dator kan en minut vara för
 kort tid för en del saker, t.ex. diagramritning kan ta
 ett bra tag.");
  deflocaledoc("deutsch", "abs_timeout",
               "ABS: Zeitbegrenzung",
#"Wenn der Server soviele Minuten nicht in der Lage ist, Anfragen
zu beantworten, wird er neu gestartet.  Zu beachten ist, daß
bei komplexen Berechnungen es durchaus normal ist, wenn eine
Anfrage eine Weile benötigt.");
#endif

  globvar("locale", "standard", "Language", TYPE_STRING_LIST,
	  "Locale, used to localise all messages in roxen.\n"
#"Standard means using the default locale, which varies according to the
value of the 'LANG' environment variable.",
          (sort(indices(RoxenLocale)) - ({ "Modules" })));
  deflocaledoc("svenska", "locale", "Språk",
	       "Den här variablen anger vilket språk roxen ska använda. "
	       "'standard' betyder att språket sätts automatiskt från "
	       "värdet av omgivningsvariabeln LANG.");
  deflocaledoc("deutsch", "locale", "Sprache",
               "Die Sprache, in der alle Roxen-Meldungen ausgeben werden.\n "
               "'standard' ist abhängig von der LANG Umgebungsvariable.");

  globvar("suicide_engage",
	  0,
	  "Auto Restart: Enable Automatic Restart",
	  TYPE_FLAG|VAR_MORE,
#"If set, Roxen will automatically restart after a configurable number of
days. Since Roxen uses a monolith, non-forking server model the process tends
to grow in size over time. This is mainly due to heap fragmentation but also
because of memory leaks."
	  );
  deflocaledoc("svenska", "suicide_engage",
	       "Automatomstart: Starta om automatiskt",
#"Roxen har stöd för att starta automatiskt då och då. Eftersom roxen är en
monolitisk icke-forkande server (en enda långlivad process) så tenderar
processen att växa med tiden.  Det beror mest på minnesfragmentation, men även
på att en del minnesläckor fortfarande finns kvar. Ett sätt att återvinna minne
är att starta om servern lite då och då, vilket roxen kommer att göra om du
slår på den här funktionen. Notera att det tar ett litet tag att starta om
 servern.");
  deflocaledoc("deutsch", "suicide_engage",
               "Automatischer Neustart: Aktivieren",
#"Wenn gesetzt, wird Roxen automatisch nach einer bestimmten Anzahl von
Tagen neugestartet. Hin und wieder wächst der Roxen-Prozess im Laufe der
Zeit an. Diese Option ist in diesem Falle dann sinnvoll.");

globvar("suicide_timeout",
	  7,
	  "Auto Restart: Timeout",
	  TYPE_INT_LIST|VAR_MORE,
	  "Automatically restart the server after this many days.",
	  ({1,2,3,4,5,6,7,14,30}),
	  lambda(){return !QUERY(suicide_engage);});
  deflocaledoc("svenska", "suicide_timeout",
	       "Automatomstart: Tidsbegränsning (i dagar)",
#"Om roxen är inställd till att starta om automatiskt, starta om
så här ofta. Tiden är angiven i dagar");
  deflocaledoc("deutsch", "suicide_timeout",
               "Automatischer Neustart: Zeitbegrenzung (in Tagen)",
#"Roxen wird nach soviel Tagen automatisch neugestartet.");

  globvar("argument_cache_in_db", 0,
         "Cache: Store the argument cache in a mysql database",
         TYPE_FLAG|VAR_MORE,
         "If set, store the argument cache in a mysql "
         "database. This is very useful for load balancing using multiple "
         "roxen servers, since the mysql database will handle "
          " synchronization");
  deflocaledoc("svenska", "argument_cache_in_db",
               "Cache: Spara argumentcachen i en databas",
               "Om den här variabeln är satt så sparas argumentcachen i en "
               "databas istället för filer. Det gör det möjligt att använda "
               "multipla frontendor, dvs, flera separata roxenservrar som "
               "serverar samma site" );
  deflocaledoc("deutsch", "argument_cache_in_db",
               "Cache: Speichern des Argumenten-Caches in eine Datenbank",
               "Wenn gesetzt, wird der Argumenten-Cache in eine "
               "SQL-Datenbank gespeichert. Dies ist sinnvoll bei mehreren "
               "Roxen-Servern, da die Datenbank die Synchronisation "
               "übernimmt.");

  globvar("argument_cache_db_path", "mysql://localhost/roxen",
          "Cache: Argument Cache Database URL to use",
          TYPE_STRING|VAR_MORE,
          "The database to use to store the argument cache",
          0,
          lambda(){ return !QUERY(argument_cache_in_db); });
  deflocaledoc("svenska", "argument_cache_db_path",
               "Cache: ArgumentcachedatabasURL",
               "Databasen i vilken argumentcachen kommer att sparas" );
  deflocaledoc("deutsch", "argument_cache_db_path",
               "Cache: Datenbank-URL für Argumenten-Cache",
               "Welche Datenbank soll für den Argumenten-Cache "
               "benutzt werden?");

  globvar("argument_cache_dir", "$VARDIR/cache/",
          "Cache: Argument Cache Directory",
          TYPE_DIR|VAR_MORE,
          "The cache directory to use to store the argument cache."
          " Please note that load balancing is not available for most modules "
          " (such as gtext, diagram etc) unless you use a mysql database to "
          "store the argument cache meta data");
  deflocaledoc("svenska", "argument_cache_dir",
               "Cache: Argumentcachedirectory",
               "Det directory i vilket cachen kommer att sparas. "
               " Notera att lastbalansering inte fungerar om du inte sparar "
               "cachen i en databas, och även om du sparar cachen i en "
               "databas så kommer det fortfarande skrivas saker i det "
               "här directoryt.");
  deflocaledoc("deutsch", "argument_cache_dir",
               "Cache: Verzeichnis für Argumenten-Cache",
               "Dieses Verzeichnis wird für die Speicherung des "
               "Argumenten-Caches benutzt.  Für Load-Balancing sollte "
               "jedoch eine SQL-Datenbank verwendet werden.");

  globvar("mem_cache_gc", 300,
	  "Cache: Memory Cache Garbage Collect Interval",
	  TYPE_INT,
	  "The number of seconds between every garbage collect "
	  "(removal of old content) from the memory cache. The "
	  "memory cache is used for various tasks like remebering "
	  "what supports flags matches what client.");
  deflocaledoc("svenska", "mem_cache_gc",
	       "Cache: Minnescachens städningsintervall",
	       "Hur många sekunder som ska gå mellan varje gång som "
	       "allt gammalt innehåll i cachen städas bort. Minnescachen "
	       "används till många olika saker som till exempel att komma "
	       "ihåg vilka supportsflaggor som hör till vilken klient.");
  deflocaledoc("deutsch", "mem_cache_gc",
               "Cache: Intervall zwischen Garbage Collections im "
               "Speicher-Cache",
               "Wieviele Sekunden sollen zwischen zwei Ausführungen "
               "einer Garbage Collection im Speicher-Cache liegen? "
               "Der Speicher-Cache enthält u.a. die Supports-Daten.");

  globvar("config_file_comments", 0,
	  "Commented config files",
	  TYPE_FLAG, #"\
Save the variable documentation strings as comments in the
configuration files. Only useful if you read or edit the config files
directly.");

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
          mixed res = ([function(void:mixed)]compile_string( "mixed f(){ return "+v+";}")()->f)();
          if(sprintf("%t", res) != sprintf("%t", variables[c][VAR_VALUE]) &&
             res != 0 && variables[c][VAR_VALUE] != 0)
            report_debug("Warning: Setting variable "+c+"\n"
                   "to a value of a different type than the default value.\n"
                   "Default was "+sprintf("%t", variables[c][VAR_VALUE])+
                   " new is "+sprintf("%t", res)+"\n");
          variables[c][VAR_VALUE]=res;
        })
        {
          report_debug("Warning: Asuming '"+v+"' should be taken "
                 "as a string value.\n");
          if(!stringp(variables[c][VAR_VALUE]))
            report_debug("Warning: Old value was not a string.\n");
          variables[c][VAR_VALUE]=v;
        }
      }
      else
	report_debug("Unknown variable: "+c+"\n");
    }
  }
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
