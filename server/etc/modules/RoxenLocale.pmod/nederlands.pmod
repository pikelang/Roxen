/*
 * $Id: nederlands.pmod,v 1.2 2000/03/14 02:22:11 per Exp $
 *
 * Roxen locale support -- Dutch
 *
 * Fred van Dijk (f.vandijk@scintilla.utwente.nl)
 */
inherit RoxenLocale.standard;
constant name="nederlands";
constant language = "Taal";
constant user = "Gebruiker";
constant latin1_name = "nederlands";
constant encoding = "iso-8859-1";

class _base_server {
  inherit standard::_base_server;	// Fallback.

  // base_server/roxen.pike
  string uncaught_error(string bt) {
    return("Niet gedeceteerde fout in de handler thread: " + bt +
	   "De client zal geen reactie krijgen van Roxen.\n");
  }
  string supports_bad_include(string file) {
    return("Supports: kan bestand niet invoegen "+file+"\n");
  }
  string supports_bad_regexp(string bt) {
    return(sprintf("parsen van reguliere expressies in supports-bestand mislukt:\n%s\n", bt));
  }
  string replacing_supports() { return("Vervangen van etc/supports"); }
  string unique_uid_logfile() { return("Unique user ID logfile.\n"); }
  string no_servers_enabled() { return("<B>No virtual servers enabled</B>\n"); }
  string full_status(string real_version, int boot_time,
		     int days, int hrs, int min, int sec, string sent_data,
		     float kbps, string sent_headers, int num_requests,
		     float rpm, string received_data) {
    return(sprintf("<table>"
		   "<tr><td><b>Versie:</b></td><td colspan=2>%s</td></tr>\n"
		   "<tr><td><b>Gestart op</b></td><td colspan=2>%s</td></tr>\n"
		   "<tr><td><b>Draaitijd:</b></td>"
		   "<td colspan=2>%d dag%s, %02d:%02d:%02d</td></tr>\n"
		   "<tr><td colspan=3>&nbsp;</td></tr>\n"
		   "<tr><td><b>Verstuurde gegevens:</b></td><td>%s"
		   "</td><td>%.2f Kbit/sec</td></tr><tr>\n"
		   "<td><b>Verstuurde headers:</b></td><td>%s</td></tr>\n"

		   "<tr><td><b>Aantal verzoeken</b></td>"
		   "<td>%8d</td><td>%.2f/min</td></tr>\n"
		   "<tr><td><b>Ontvangen gegevens:</b></td>"
		   "<td>%s</td></tr>\n"
		   "</table>",
		   real_version, ctime(boot_time),
		   days, (days==1?"":"gen"), hrs, min, sec,
		   sent_data, kbps, sent_headers,
		   num_requests, rpm, received_data));
  }

  string setting_uid_gid_permanently(int uid, int gid, string uname, string gname) {
    return("Vast instellen van uid op "+uid+" ("+uname+")"+
	   (gname ? " en gid op "+gid+" ("+gname+")" : "")+".\n");
  }

  string setting_uid_gid(int uid, int gid, string uname, string gname) {
    return("Instellen van  uid op "+uid+" ("+uname+")"+
	   (gname ? " en gid op "+gid+" ("+gname+")" : "")+".\n");
  }

  string error_enabling_configuration(string config, string bt) {
    return("Fout opgetreden tijdens het activeren van de configuratie"+config+
	   (bt ? ":\n" + bt : "\n"));
  }

  string disabling_configuration(string config) {
    return("Uitschakelen van oude configuratie " + config + "\n");
  }

  string enabled_server(string server) {
    return("De virtuele server \"" +server + "\" is geactiveerd.\n");
  }

  string opening_low_port() {
    return("Openen van een poort  onder de 1024");
  }

  string url_format() {
    return("Het URL adres moet er als volgt uitzien: protocol://computer[:port]/ .");
  }

  // base_server/configuration.pike
  string failed_to_open_logfile(string logfile) {
    return("Kon logbestand ("+logfile+") niet openen.\n" +
	   "Er wordt niets gelogd!\n");
  }
  string config_status(float sent_data, float kbps, float sent_headers,
		       int num_requests, float rpm, float received_data) {
    return(sprintf("<tr align=right><td><b>Verstuurde gegevens:</b></td><td>%.2fMB"
		  "</td><td>%.2f Kbit/sec</td>"
		   "<td><b>Vestuurde headers:</b></td><td>%.2fMB</td></tr>\n"
		   "<tr align=right><td><b>Aantal verzoeken:</b></td>"
		   "<td>%8d</td><td>%.2f/min</td>"
		   "<td><b>Ontvangen gegevens:</b></td><td>%.2fMB</td></tr>\n",
		   sent_data, kbps, sent_headers,
  		   num_requests, rpm, received_data));
  }
  string ftp_status(int total_users, float upm, int num_users) {
    return(sprintf("<tr align=right><td><b>FTP users (total):</b></td>"
		   "<td>%8d</td><td>%.2f/min</td>"
		   "<td><b>FTP gebruikers (n):</b></td><td>%d</td></tr>\n",
		   total_users, upm, num_users));
  }
  string ftp_statistics() {
    return("<b>FTP statistieken:</b>");
  }
  string ftp_stat_line(string cmd, int times) {
    return(sprintf("<tr align=right><td><b>%s</b></td>"
		   "<td align=right>%d</td><td> keer</td></tr>\n",
		   cmd, times));
  }
  string no_auth_module() {
    return("Geen authorisatie-module");
  }
  string module_security_error(string bt) {
    return(sprintf("fout tijdens controle van module beveiliging:\n"
		   "%s\n", bt));
  }
  string clear_memory_cache_error(string modname, string bt) {
    return(sprintf("clear_memory_caches() is mislukt voor module: %O:\n"
		   "%s\n", modname, bt));
  }
  string returned_redirect_to(string location) {
    return("Antwoord door een omleiding naar " + location+"\n" );
  }
  string returned_redirect_no_location() {
    return("Antwoord door een omleiding, maar zonder Location-header.\n");
  }
  string returned_authenticate(string auth) {
    return("Antwoorden authenticatie mislukt: " + auth + "\n");
  }
  string returned_auth_failed() {
    return("Antwoorden authenticatie mislukt.\n");
  }
  string returned_ok() {
    return("Antwoord: Ok\n");
  }
  string returned_error(int errcode) {
    return("Antwoord:" + errcode + ".\n");
  }
  string returned_no_data() {
    return("Geen gegevens ");
  }
  string returned_bytes(int len) {
    return(len + " bytes ");
  }
  string returned_unknown_bytes() {
    return("? bytes");
  }
  string returned_static_data() {
    return(" (static)");
  }
  string returned_open_file() {
    return "(geopend bestand)";
  }
  string returned_type(string type) {
    return(" van " + type + "\n");
  }
  string request_for(string path) {
    return("Verzoek om " + path);
  }
  string magic_internal_gopher() {
    return("Interne gopher afbeelding");
  }
  string magic_internal_roxen() {
    return("Interne roxen afbeelding");
  }
  string magic_internal_module_location() {
    return("Interne module locatie");
  }
  string directory_module() {
    return("Directory module");
  }
  string returning_data() {
    return("Bezig met antwoorden");
  }
  string url_module() {
    return("URL module");
  }
  string too_deep_recursion() {
    return("Te diepe recursie");
  }
  string extension_module(string ext) {
    return("Extensie-module [" + ext + "] ");
  }
  string returned_fd() {
    return("Open filedescriptor teruggegeven.");
  }
  string seclevel_is_now(int slevel) {
    return(" Het beveiligins-niveaus is nu " + slevel + ".");
  }
  string location_module(string loc) {
    return("Locatie-module [" + loc + "] ");
  }
  string module_access_denied() {
    return("Niet toegestaan om toegangs-module te benaderen.");
  }
  string request_denied() {
    return("Verzoek afgewezen.");
  }
  string calling_find_file() {
    return("Aanroepen van find_file()...");
  }
  string find_file_returned(mixed fid) {
    return(sprintf("find_file gaf %O terug", fid));
  }
  string calling_find_internal() {
    return("Aanroepen find_internal()...");
  }
  string find_internal_returned(mixed fid) {
    return(sprintf("find_internal gaf %O terug", fid));
  }
  string returned_directory_indicator() {
    return("Antwoorrd van directory indicator.");
  }
  string automatic_redirect_to_location() {
    return("Automatische omleiding naar location_module.");
  }
  string no_magic() {
    return("\" magic\" niet gevraagd. Antwoord -1.");
  }
  string no_directory_module() {
    return("Geen directory module. Antwoord 'no such file'");
  }
  string permission_denied() {
    return("Niet toegestaan");
  }
  string returned_new_fd() {
    return("Een nieuw bestand teruggegeven.");
  }
  string content_type_module() {
    return("Content-type mapping module");
  }
  string returned_mime_type(string t1, string t2) {
    return("Antwoord van type  " + t1 + " " + t2 + ".");
  }
  string missing_type() {
    return("type ontbreekt.");
  }
  string returned_not_found() {
    return("'no such file' teruggegeven.");
  }
  string filter_module() {
    return("Filter module");
  }
  string rewrote_result() {
    return("Resultaat herschreven.");
  }
  string list_directory(string dir) {
    return(sprintf("Directory lijst %O.", dir));
  }
  string returned_no_thanks() {
    return("'No thanks' teruggegeven.");
  }
  string recursing() {
    return("Recursief");
  }
  string got_exclusive_dir() {
    return("Exclusive directory gekregen.");
  }
  string returning_file_list(int num_files) {
    return("Geef een lijstt terug van " + num_files + " bestanden.");
  }
  string got_files() {
    return("Heb bestanden gerkregen.");
  }
  string added_module_mountpoint() {
    return("module mount-locatie toegevoegd.");
  }
  string returning_no_dir() {
    return("Geantwoord: 'No such directory'.");
  }
  string stat_file(string file) {
    return(sprintf("Bestandsstatus %O.", file));
  }
  string exact_match() {
    return("Exacte match.");
  }
  string stat_ok() {
    return("Stat ok."); // FIXME
  }
  string find_dir_stat(string file) {
    return("Verzoek voor  directory and stat's van \""+file+"\".");
  }
  string returned_mapping() {
    return("mapping teruggegeven.");
  }
  string empty_dir() {
    return("Lege directory.");
  }
  string returned_object() {
    return("object teruggegeven.");
  }
  string returning_it() {
    return("Terugggeven.");
  }
  string has_find_dir_stat() {
    return("Heeft find_dir_stat().");
  }
  string returned_array() {
    return("array teruggegeven.");
  }
  string file_on_mountpoint_path(string file, string path) {
    return(sprintf("Het bestand  %O zit in het pad naar mountpoint %O.",
		   file, path));
  }

  string error_disabling_module(string name, string bt) {
    return("Fout tijdens het uitschakelen van module " + name +
	   (bt ? ":\n" + bt : "\n"));
  }
  string error_initializing_module_copy(string name, string bt) {
    return("Fout tijdens het initialiseren van kopie van module " + name +
	   (bt ? ":\n" + bt : "\n"));
  }
  string disable_nonexistant_module(string name) {
    return("Kon module niet uitschakelen :\n"
	   "Geen modules met de naam: \"" +name + "\".\n");
  }
  string disable_module_failed(string name) {
    return("Kon module \"" + name + "\" niet uitschakelen.\n");
  }
  string enable_module_failed(string name, string bt) {
    return("Kon module " + name + ". niet inschakelen. Deze wordt overgeslagen." +
	   (bt ? "\n" + bt : "\n"));
  }
};

object(_base_server) base_server = _base_server();

class _config_interface
{
  inherit standard::_config_interface;
  // config/low_describers.pike
  constant all_memory_caches_flushed = "Alle geheugen caches zijn geleegd.";

  constant font_test_string = "The quick brown fox jumped over the lazy dog.";

  string module_hint() {
    return "(Module)";
  }
  string font_hint() {
    return "(Lettertype)";
  }
  string location_hint() {
    return "(Een lokatie in het virtuele bestandssysteem van roxen)";
  }
  string file_hint() {
    return "(Een bestandsnaam in het werkelijke bestandssyssteem)";
  }
  string dir_hint() {
    return "(Een directory in het werkelijke bestandssysteem)";
  }
  string float_hint() {
    return "(een nummer)";
  }
  string int_hint() {
    return "(Een integer.)";
  }
  string stringlist_hint() {
    return "(Een lijst gescheiden door komma's)";
  }
  string intlist_hint() {
    return "(Een lijst van integers, gescheiden door komma's)";
  }
  string floatlist_hint() {
    return "(Een lijst van floats, gescheiden door komma's)"; //FIXME
  }
  string dirlist_hint() {
    return "(Een lijst van directories, gescheiden door komma's)";
  }
  string password_hint() {
    return "(een wachtwoord. Uw invoer wordt niet zichtbaar)";
  }
  string ports_configured( int n )
  {
    if(!n) return "geen poorten geconfigureerd";
    if(n == 1) return "een poort geconfigureerd"; //FIXME
    return _whatevers("poorten geconfigureerd", n);
  }
  string unkown_variable_type() {
    return "onbekend type variable";
  }
  string lines( int n )
  {
    if(!n) return "leeg";
    if(n == 1) return "een lijn"; //FIXME
    return _whatevers("lijnen", n);
  }


  string administration_interface() {
    return("Administratie Interface");
  }
  string admin_logged_on(string who, string from) {
    return("Beheerder aangemeld als "+who+" vanaf " + from + ".\n");
  }


  string translate_cache_class( string classname ) //FIXME
  {
    return ([
      "supports":"supportdb",
      "fonts":"fonts",
      "hosts":"DNS",
    ])[ classname ] || classname;
  }

  constant name = "naam";
  constant state = "Status";

  constant features = "Opties";
  constant module_disabled = "Uitgeschakelde modules";
  constant all_modules = "Alle modules";

  constant disabled= "Uitgeschakeld";
  constant enabled = "<font color=&usr.fade4;>Ingeschakeld</font>";
  constant na      = "N/A";

  constant class_ = "Klasse";
  constant entries = "Entr";
  constant size = "Grootte";
  constant hits = "Hits";
  constant misses = "Misses";
  constant hitpct = "Hit%";

  constant reload = "Herlaad";
  constant empty = "Leeg";
  constant status = "Status";
  constant sites =  "Sites";
  constant servers = "Servers";
  constant settings= "Instellingen";
  constant usersettings= "Gebruikersprofiel";
  constant upgrade = "Upgrade";
  constant modules = "Modules";
  constant globals = "Globale Instellingen";
  constant eventlog = "Logboek";
  constant ports = "Poorten";
  constant reverse = "Omgekeerd";
  constant normal = "Normaal";
  constant notice = "Informatief";
  constant warning = "Waarschuwing";
  constant error = "Fout";
  constant actions = "Acties";
  constant manual = "Handleiding";
  constant clear_log = "Logboek opschonen";


  constant debug_info = "Debug informatie";
  constant welcome = "Welkom";
  constant restart = "Herstarten";
  constant users = "Gebruikers";
  constant shutdown = "Uitschakelen";
  constant home = "Startpagina";
  constant configiftab = "Configuratie Interface";

  constant create_user = "Maak nieuwe gebruike aan";
  constant delete_user = "Verwijder oude gebruiker";

  constant delete = "Verwijder";
  constant save = "Bewaar";

  constant add_module = "Voeg module toe";
  constant drop_module = "Verwijder module";
  constant will_be_loaded_from = "Wordt geladen vanuit ";

  constant maintenance = "Onderhoud";
  constant developer = "Ontwikkeling";

  constant create_new_site = "Maak nieuwe site";
  constant with_template = "Met template";
  constant site_pre_text = "";
  constant site_name = "Site naam";
  constant site_type = "Site type";
  constant site_name_doc =
#"De naam van de configuratie mag geen spaties, tabs of '/' bevatten, mag
niet eindigen op ~ en mag niet 'CVS', 'Global Variables' of
'global variables' zijn, noch de naam van een al bestaande configuratie";
};
object(_config_interface) config_interface = _config_interface();


// Global useful words
constant ok = "Ok";
constant cancel = "Afbreken";
constant yes = "Ja";
constant no  = "Nee";
constant and = "en";
constant or = "of";
constant every = "elke";
constant since = "sinds";
constant next = "Volgende";
constant previous = "Vorige";

constant actions = "Acties";
constant manual = "Handleiding";

string seconds(int n)
{
  if(n == 1) return "1 seconde"; //FIXME
  return _whatevers( "seconden", n );
}

string minutes(int n)
{
  if(n == 1) return "1 minuut";
  return _whatevers( "minuten", n );
}

string hours(int n)
{
  if(n == 1) return "1 uur";
  return _whatevers( "uren", n );
}

string days(int n)
{
  if(n == 1) return "1 dag";
  return _whatevers( "dagen", n );
}

string module_doc_string(mixed module, string var, int long)
{
  return (::module_doc_string(module,var,long) ||
	  RoxenLocale.standard.module_doc_string( module, var, long ));
}
