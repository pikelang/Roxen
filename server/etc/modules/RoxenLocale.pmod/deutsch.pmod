/*
 * $Id: deutsch.pmod,v 1.5 2000/07/09 18:42:42 per Exp $
 *
 * Roxen locale support -- Deutsch (German)
 *
 * Kai Voigt (k@123.org) 2000-02-04
 */

inherit RoxenLocale.standard;
constant name="deutsch";
constant language = "Sprache";
constant latin1_name = "deutsch";

class _base_server {
  inherit standard::_base_server;

  string uncaught_error(string bt) {
    return("Unbehandelter Fehler in Handler-Tread: " + bt +
           "Client wird keine Antwort von Roxen erhalten.\n");
  }
  string supports_bad_include(string file) {
    return("Supports: Datei "+file+" kann nicht eingebunden werden.\n");
  }
  string supports_bad_regexp(string bt) {
    return(sprintf("Mißglücktes Parsen der Supports-Daten:\n%s\n", bt));
  }
  string replacing_supports() { return("Austausch von etc/supports"); }
  string unique_uid_logfile() { return("Eindeutiges Benutzer-ID-Logifile.\n"); }
  string no_servers_enabled() { return("<B>Kein virtueller Server aktiviert</B>\n"); }
  string full_status(string real_version, int boot_time,
                     int days, int hrs, int min, int sec, string sent_data,
                     float kbps, string sent_headers, int num_requests,
                     float rpm, string received_data) {
    return(sprintf("<table>"
                   "<tr><td><b>Version:</b></td><td colspan=2>%s</td></tr>\n"
                   "<tr><td><b>Gestartet:</b></td><td colspan=2>%s</td></tr>\n"
                   "<tr><td><b>bisherige Laufzeit:</b></td>"
                   "<td colspan=2>%d Tag%s, %02d:%02d:%02d</td></tr>\n"
                   "<tr><td colspan=3>&nbsp;</td></tr>\n"
                   "<tr><td><b>Gesendete Daten:</b></td><td>%s"
                   "</td><td>%.2f Kbit/s</td></tr><tr>\n"
                   "<td><b> Gesendete Header:</b></td><td>%s</td></tr>\n"

                   "<tr><td><b>Anzahl der Anfragen:</b></td>"
                   "<td>%8d</td><td>%.2f/Min</td></tr>\n"
                   "<tr><td><b>Empfangene Daten:</b></td>"
                   "<td>%s</td></tr>\n"
                   "</table>",
                   real_version, ctime(boot_time),
                   days, (days==1?"":"e"), hrs, min, sec,
                   sent_data, kbps, sent_headers,
                   num_requests, rpm, received_data));
   }
  string setting_uid_gid_permanently(int uid, int gid, string uname, string gname) {
    return("Dauerhaftes Setzen der uid auf "+uid+" ("+uname+")"+
           (gname ? " und gid auf "+gid+" ("+gname+")" : "")+".\n");
  }
  string setting_uid_gid(int uid, int gid, string uname, string gname) {
    return("Setzen der uid auf "+uid+" ("+uname+")"+
           (gname ? " und gid auf "+gid+" ("+gname+")" : "")+".\n");
  }
  string error_enabling_configuration(string config, string bt) {
    return("Fehler beim Aktivieren der Konfiguration " + config +
           (bt ? ":\n" + bt : "\n"));
  }
  string disabling_configuration(string config) {
    return("Deaktivierung der alten Konfiguration " + config + "\n");
  }
  string enabled_server(string server) {
    return("Aktivierung des virtuellen Servers \"" +server + "\".\n");
  }
  string opening_low_port() {
    return("Öffnen eines Ports unterhalb von 1024");
  }
  string url_format() {
("Die URL sollte folgendes Format haben: protokoll://Rechnername[:Port]/");
  }
  string failed_to_open_logfile(string logfile) {
    return("Öffnen des Logfiles \""+logfile+"\" fehlgeschlagen.\n" +
           "Es findet kein Logging statt!\n");
  }
  string config_status(float sent_data, float kbps, float sent_headers,
                       int num_requests, float rpm, float received_data) {
    return(sprintf("<tr align=right><td><b>Gesendete Daten:</b></td><td>%.2fMB"
                  "</td><td>%.2f Kbit/s</td>"
                   "<td><b>Gesendete Header:</b></td><td>%.2fMB</td></tr>\n"
                   "<tr align=right><td><b>Anzahl der Anfragen:</b></td>"
                   "<td>%8d</td><td>%.2f/min</td>"
                   "<td><b>Empfangene Daten:</b></td><td>%.2fMB</td></tr>\n",
                   sent_data, kbps, sent_headers,
                   num_requests, rpm, received_data));
  }
  string ftp_status(int total_users, float upm, int num_users) {
    return(sprintf("<tr align=right><td><b>FTP-Benutzer (gesamt):</b></td>"
                   "<td>%8d</td><td>%.2f/min</td>"
                   "<td><b>FTP-Benutzer (derzeit):</b></td><td>%d</td></tr>\n",
                   total_users, upm, num_users));
  }
  string ftp_statistics() {
    return("<b>FTP-Statistik:</b>");
  }
  string ftp_stat_line(string cmd, int times) {
    return(sprintf("<tr align=right><td><b>%s</b></td>"
                   "<td align=right>%d</td><td> mal%s</td></tr>\n",
                   cmd, times, (times == 1)?"":""));
  }
  string no_auth_module() {
    return("Kein Authentisierungs-Modul");
  }
  string module_security_error(string bt) {
    return(sprintf("Fehler bei der Modulsicherheits-Kontrolle:\n"
                   "%s\n", bt));
  }
  string clear_memory_cache_error(string modname, string bt) {
    return(sprintf("clear_memory_caches() fehlgeschlagen bei Modul %O:\n"
                   "%s\n", modname, bt));
  }
  string returned_redirect_to(string location) {
    return("Antwort durch einen Redirect zu " + location+"\n" );
  }
  string returned_redirect_no_location() {
    return("Antwort durch einen Redirect, jedoch ohne Location-Header\n");
  }
  string returned_authenticate(string auth) {
    return("Antwort Authentizierung fehlgeschlagen: " + auth + "\n");
  }
  string returned_ok() {
    return("Antwort OK\n");
  }
  string returned_error(int errcode) {
    return("Antwort " + errcode + ".\n");
  }
  string returned_no_data() {
    return("Keine Daten ");
  }
  string returned_bytes(int len) {
    return(len + " Bytes ");
  }
  string returned_unknown_bytes() {
    return("? Bytes");
  }
  string returned_static_data() {
    return(" (statisch)");
  }
  string returned_open_file() {
    "(geöffnete Datei)";
  }
  string returned_type(string type) {
    return(" vom Typ <tt>" + type + "</tt>\n");
  }
  string request_for(string path) {
    return("Anfrage nach " + path);
  }
  string magic_internal_gopher() {
    return("Interne Gopher-Grafik");
  }
  string magic_internal_roxen() {
    return("Interne Roxen-Grafik");
  }
  string magic_internal_module_location() {
    return("Interne Modul-Position");
  }
  string directory_module() {
    return("Verzeichnis-Modul");
  }
  string returning_data() {
    return("Antwort durch Daten");
  }
  string url_module() {
    return("URL-Modul");
  }
  string too_deep_recursion() {
    return("Rekursions-Tiefe zu hoch");
  }
  string extension_module(string ext) {
    return("Dateinamenserweiterungs-Modul [" + ext + "] "); // FIXME!
  }
  string returned_fd() {
    return("Antwort durch offenen Datei-Deskriptor.");
  }
  string seclevel_is_now(int slevel) {
    return(" Sicherheits-Level ist nun " + slevel + ".");
  }
  string location_module(string loc) {
    return("Location-Modul [" + loc + "] "); // FIXME!
  }
  string module_access_denied() {
    return("Zugriff auf Modul nicht gestattet.");
  }
  string request_denied() {
    return("Anforderung verweigert.");
  }
  string calling_find_file() {
    return("Aufruf von find_file()...");
  }
  string find_file_returned(mixed fid) {
    return(sprintf("find_file() lieferte %O", fid));
  }
  string calling_find_internal() {
    return("Aufruf von find_internal()...");
  }
  string find_internal_returned(mixed fid) {
    return(sprintf("find_internal() lieferte %O", fid));
  }
  string returned_directory_indicator() {
    return("Antwort durch Direktory-Indikator."); // FIXME!
  }
  string automatic_redirect_to_location() {
    return("Automatischer Redirect zum location_module.");
  }
  string no_magic() {
    return("\"magic\" nicht angefordert, Rückgabe von -1.");
  }
  string no_directory_module() {
    return("Kein Verzeichnis-Modul. Rückgabe von 'no such file'");
  }
  string permission_denied() {
    return("Erlaubnis verweigert");
  }
  string returned_new_fd() {
    return("Rückgabe einer neuen offenen Datei.");
  }
  string content_type_module() {
    return("Content-type Mapping-Modul");
  }
  string returned_mime_type(string t1, string t2) {
    return("Rückgabe von Typ " + t1 + " " + t2 + ".");
  }
  string missing_type() {
    return("Fehlender Typ.");
  }
  string returned_not_found() {
    return("Rückgabe von 'no such file'.");
  }
  string filter_module() {
    return("Filter-Modul");
  }
  string rewrote_result() {
    return("Resultat umgeschrieben.");
  }
  string list_directory(string dir) {
    return(sprintf("Verzeichnis %O anzeigen.", dir));
  }
  string returned_no_thanks() {
    return("Rückgabe von 'No thanks'.");
  }
  string recursing() {
    return("Rekursives Absteigen");
  }
  string got_exclusive_dir() {
    return("Exklusives Verzeichnis erhalten.");
  }
  string returning_file_list(int num_files) {
    return("Rückgabe von Dateiliste mit " + num_files + " Einträgen.");
  }
  string got_files() {
    return("Dateien erhalten.");
  }
  string added_module_mountpoint() {
    return("Modul-Mountpoint hinzugefügt.");
  }
  string returning_no_dir() {
    return("Rückgabe von 'No such directory'.");
  }
  string stat_file(string file) {
    return(sprintf("Datei-Status %O.", file));
  }
  string exact_match() {
    return("Exakte Übereinstimmung.");
  }
  string stat_ok() {
    return("Stat ok."); // FIXME!
  }
  string find_dir_stat(string file) {
    return("Anfrage nach Verzeichnis und Status von \""+file+"\".");
  }
  string returned_mapping() {
    return("Rückgabe eines Mappings.");
  }
  string empty_dir() {
    return("Leeres Verzeichnis.");
  }
  string returned_object() {
    return("Rückgabe eines Objekts.");
  }
  string returning_it() {
    return("Rückgabe von Daten.");
  }
  string has_find_dir_stat() {
    return("Besitzt find_dir_stat().");
  }
  string returned_array() {
    return("Rückgabe eines Arrays.");
  }
  string file_on_mountpoint_path(string file, string path) {
    return(sprintf("Die Datei %O befindet sich im Pfad zum Mountpoint %O.",
                   file, path));
  }

  string error_disabling_module(string name, string bt) {
    return("Fehler beim Deaktivieren des Moduls " + name +
           (bt ? ":\n" + bt : "\n"));
  }
  string error_initializing_module_copy(string name, string bt) {
    return("Fehler beim Initialisieren der Modul-Kopie von " + name +
           (bt ? ":\n" + bt : "\n"));
  }
  string disable_nonexistant_module(string name) {
    return("Fehlgeschlagene Deaktiverung des Moduls:\n"
           "Kein Modul mit diesem Namen: \"" +name + "\".\n");
  }
  string disable_module_failed(string name) {
    return("Mißglückte Deaktivierung des Moduls \"" + name + "\".\n");
  }
  string enable_module_failed(string name, string bt) {
    return("Aktivieren des Moduls " + name + " fehlgeschlagen. Übersprungen." +
           (bt ? "\n" + bt : "\n"));
  }
}

class _config_interface {
  inherit standard::_config_interface;

  constant all_memory_caches_flushed = "Alle Speicher-Caches wurden geleert.";

  string module_hint() {
    return "(Modul)";
  }
  string font_hint() {
    return "(Schriftart)";
  }
  string location_hint() {
    return "(Der Position in Roxens virtuellem Dateibaum)";
  }
  string file_hint() {
    return "(Ein Dateiname im realen Dateibaum)";
  }
  string dir_hint() {
    return "(Ein Verzeichnis im realen Dateibaum)";
  }
  string float_hint() {
    return "(Eine Zahl)";
  }
  string int_hint() {
    return "(Eine ganze Zahl)";
  }
  string stringlist_hint() {
    return "(Komma-separierte Liste)";
  }
  string intlist_hint() {
    return "(Komma-separierte Liste von ganzen Zahlen)";
  }
  string floatlist_hint() {
    return "(Komma-separierte Liste von Fließkommazahlen)";
  }
  string dirlist_hint() {
    return "(Komma-separierte Liste von Verzeichnissen)";
  }
  string password_hint() {
    return "(Ein Passwort, die Eingabe wird nicht sichtbar sein)";
  }
  string ports_configured( int n )
  {
    if(!n) return "keine Ports konfiguriert";
    if(n == 1) return "ein Port konfiguriert";
    return _whatevers("Ports konfiguriert", n);
  }
  string unkown_variable_type() {
    return "Unbekannter Variablen-Typ";
  }
  string lines( int n )
  {
    if(!n) return "leer";
    if(n == 1) return "eine Zeile";
    return _whatevers("Zeilen", n);
  }

  string administration_interface() {
    return("Administrations-Interface");
  }
  string admin_logged_on(string who, string from) {
    return("Administrator eingeloggt als "+who+" von " + from + ".\n");
  }

  constant name = "Name";
  constant state = "Zustand";

  constant features = "Features";
  constant module_disabled = "Deaktivierte Module";
  constant all_modules = "Alle Module";

  constant disabled= "Deaktiviert";
  constant enabled = "<font color=&usr.fade4;>Aktiviert</font>";
  constant na      = "N/A";

  constant class_ = "Klasse";
  constant entries = "Einträge";
  constant size = "Größe";
  constant hits = "Hits";
  constant misses = "Misses";
  constant hitpct = "Hit%";

  constant reload = "Reload";
  constant empty = "Leer";
  constant status = "Status";
  constant sites =  "Sites";
  constant servers = "Server";
  constant settings= "Einstellungen";
  constant usersettings= "Benutzer-Einstellungen";
  constant upgrade = "Upgrade";
  constant modules = "Module";
  constant globals = "Globale Einstellungen";
  constant eventlog = "Ereignis-Log";
  constant ports = "Ports";
  constant reverse = "Umgekehrt";
  constant normal = "Normal";
  constant notice = "Notiz";
  constant warning = "Warnung";
  constant error = "Fehler";
  constant actions = "Aufgaben";
  constant manual = "Handbuch";
  constant clear_log = "Log löschen";

  constant debug_info = "Debug-Informationen";
  constant welcome = "Willkommen";
  constant restart = "Neustart";
  constant users = "Benutzer";
  constant shutdown = "Anhalten";
  constant home = "Startseite";

  constant create_user = "Neuen Benutzer anlegen";
  constant delete_user = "Bestehenden Benutzer löschen";

  constant delete = "Löschen";
  constant save = "Sichern";

  constant add_module = "Modul hinzuzfügen";
  constant drop_module = "Modul löschen";
  constant will_be_loaded_from = "Wird geladen von";
  constant maintenance = "Pflege";
  constant developer = "Entwicklung";

  constant create_new_site = "Neue Site anlegen";
  constant with_template = "Mit Template";
  constant site_pre_text = "";
  constant site_name = "Site-Name";
  constant site_type = "Site-Typ";
  constant site_name_doc =
#"Der Name der Konfiguration darf keine Leerzeichen oder Tabulatoren
enthalten und es darf nicht mit ~ enden.  'CVS', 'Global Variables',
'global variables' sowie Namen bestehender Konfigurationen sind nicht
gestattet.  Ferner darf '/' nicht benutzt werden";

}

constant ok = "OK";
constant cancel = "Abbruch";
constant yes = "Ja";
constant no  = "Nein";
constant and = "und";
constant or = "oder";
constant every = "jede";
constant since = "seit";
constant next = "Weiter";
constant previous = "Zurück";

string seconds(int n)
{
  if(n == 1) return "eine Sekunde";
  return _whatevers( "Sekunden", n );
}

string minutes(int n)
{
  if(n == 1) return "eine Minute";
  return _whatevers( "Minuten", n );
}

string hours(int n)
{
  if(n == 1) return "eine Stunde";
  return _whatevers( "Stunden", n );
}

string days(int n)
{
  if(n == 1) return "ein Tag";
  return _whatevers( "Tage", n );
}
