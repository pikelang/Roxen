/*
 * $Id: svenska.pmod,v 1.2 2000/03/14 02:22:11 per Exp $
 *
 * Roxen locale support -- Svenska (Swedish)
 *
 * Henrik Grubbström 1998-10-10
 */

inherit RoxenLocale.standard;
constant name="svenska";
constant language = "Språk";
constant user = "Användare";
constant latin1_name = "svenska";

class _base_server {
  inherit standard::_base_server;	// Fallback.

  // base_server/roxen.pike
  string uncaught_error(string bt) {
    return("Ofångat fel i en hanterartåd: " + bt +
	   "Klienten kommer inte att få något svar från Roxen.\n");
  }
  string supports_bad_include(string file) {
    return("Supports: Kan inte inkludera filen "+file+"\n");
  }
  string supports_bad_regexp(string bt) {
    return(sprintf("Misslyckades att tolka supportsdatabasen\n%s\n", bt));
  }
  string replacing_supports() { return("Byter ut etc/supports"); }
  string unique_uid_logfile() { return("Unik användaridlogfil.\n"); }
  string no_servers_enabled() { return("<B>Inga virtuella servrar skapade</B>\n"); }
  string full_status(string real_version, int boot_time, int time_to_boot,
		     int days, int hrs, int min, int sec, string sent_data,
		     float kbps, string sent_headers, int num_requests,
		     float rpm, string received_data) {
    return(sprintf("<table>"
		   "<tr><td><b>Version:</b></td><td colspan=2>%s</td></tr>\n"
		   "<tr><td><b>Startad:</b></td><td colspan=2>%s</td></tr>\n"
		   "<tr><td><b>Upstarttid:</b></td>"
		   "<td>%d s</td></tr>\n"
		   "<tr><td><b>Upptid:</b></td>"
		   "<td colspan=2>%d dag%s, %02d:%02d:%02d</td></tr>\n"
		   "<tr><td colspan=3>&nbsp;</td></tr>\n"
		   "<tr><td><b>Sänd data:</b></td><td>%s"
		   "</td><td>%.2f Kbit/s</td></tr><tr>\n"
		   "<td><b>Sända headrar:</b></td><td>%s</td></tr>\n"
		   "<tr><td><b>Antal förfrågningar:</b></td>"
		   "<td>%8d</td><td>%.2f/min</td></tr>\n"
		   "<tr><td><b>Emottagen data:</b></td>"
		   "<td>%s</td></tr>\n"
		   "</table>",
		   real_version, ctime(boot_time), time_to_boot,
		   days, (days==1?"":"ar"), hrs, min, sec,
		   sent_data, kbps, sent_headers,
		   num_requests, rpm, received_data));
  }
  string setting_uid_gid_permanently(int uid, int gid, string uname, string gname) {
    return("Sätter uid till "+uid+" ("+uname+")"+
	   (gname ? " och gid till "+gid+" ("+gname+")" : "")+" permanent.\n");
  }
  string setting_uid_gid(int uid, int gid, string uname, string gname) {
    return("Sätter uid till "+uid+" ("+uname+")"+
	   (gname ? " och gid till "+gid+" ("+gname+")" : "")+".\n");
  }
  string disabling_configuration(string config) {
    return("Tar bort servern " + config + "\n");
  }
  string enabled_server(string server) {
    return("Startade den virtuella servern \"" +server + "\".\n");
  }
  string opening_low_port() {
    return("Öppnar en port under 1024");
  }
  string url_format() {
    return("URL'en ska ha följande format: protokoll://dator[:port]/");
  }

// base_server/configuration.pike
  string failed_to_open_logfile(string logfile) {
    return("Missyckades att öppna loggfilen \""+logfile+"\".\n" +
	   "Ingen loggning kommer att ske!\n");
  }
  string config_status(float sent_data, float kbps, float sent_headers,
		       int num_requests, float rpm, float received_data) {
    return(sprintf("<tr align=right><td><b>Sänd data:</b></td><td>%.2fMB"
		  "</td><td>%.2f Kbit/s</td>"
		   "<td><b>Sända headrar:</b></td><td>%.2fMB</td></tr>\n"
		   "<tr align=right><td><b>Antal förfrågningar:</b></td>"
		   "<td>%8d</td><td>%.2f/min</td>"
		   "<td><b>Emottagen data:</b></td><td>%.2fMB</td></tr>\n",
		   sent_data, kbps, sent_headers,
  		   num_requests, rpm, received_data));
  }
  string ftp_status(int total_users, float upm, int num_users) {
    return(sprintf("<tr align=right><td><b>FTPanvändare (totalt):</b></td>"
		   "<td>%8d</td><td>%.2f/min</td>"
		   "<td><b>FTPanvändare (nu):</b></td><td>%d</td></tr>\n",
		   total_users, upm, num_users));
  }
  string ftp_statistics() {
    return("<b>FTPstatistik:</b>");
  }
  string ftp_stat_line(string cmd, int times) {
    return(sprintf("<tr align=right><td><b>%s</b></td>"
		   "<td align=right>%d</td><td> gång%s</td></tr>\n",
		   cmd, times, (times == 1)?"":"er"));
  }
  string no_auth_module() {
    return("Autoriseringsmodul saknas.");
  }
  string module_security_error(string bt) {
    return(sprintf("Ett fel inträffade under modulsäkerhetskontrollen:\n"
		   "%s\n", bt));
  }
  string returned_redirect_to(string location) {
    return("Returnerade redirect to "+location+"\n");
  }
  string returned_redirect_no_location() {
    return("Returnerade redirect, men locationheadern saknas\n");
  }
  string returned_authenticate(string auth) {
    return("Returnerade authentication failed; "+auth+"\n");
  }
  string returned_auth_failed() {
    return("Returnerade authentication failed.\n");
  }
  string returned_ok() {
    return("Returnerade ok\n");
  }
  string returned_error(int errcode) {
    return("Returnerade "+errcode+"\n");
  }
  string returned_no_data() {
    return("Ingen data ");
  }
  string returned_bytes(int len) {
    return(len + " bytes ");
  }
  string returned_unknown_bytes() {
    return("? bytes");
  }
  string returned_static_data() {
    return(" (statisk)");
  }
  string returned_open_file() {
    return "(öppen fil)";
  }
  string returned_type(string type) {
    return(" av typen " + type + "\n");
  }
  string request_for(string path) {
    return("Förfrågan efter " + path);
  }
  string magic_internal_gopher() {
    return("Magisk intern gopherbild");
  }
  string magic_internal_roxen() {
    return("Magisk intern roxenbild");
  }
  string magic_internal_module_location() {
    return("Magisk intern modullocation");
  }
  string directory_module() {
    return("Katalogmodul");
  }
  string returning_data() {
    return("Returnerar data");
  }
  string url_module() {
    return("URLmodul");
  }
  string too_deep_recursion() {
    return("För djup rekursion");
  }
  string extension_module(string ext) {
    return("Extensionsmodul [" + ext + "] ");
  }
  string returned_fd() {
    return("Returnerade en öppen fildeskriptor.");
  }
  string seclevel_is_now(int slevel) {
    return(" Säkerhetsnivån är nu " + slevel + ".");
  }
  string location_module(string loc) {
    return("Locationmodul [" + loc + "] ");	// FIXME!
  }
  string module_access_denied() {
    return("Åtkomst till modulen nekad.");
  }
  string request_denied() {
    return("Request denied.");			// FIXME!
  }
  string calling_find_file() {
    return("Anropar find_file()...");
  }
  string find_file_returned(mixed fid) {
    return(sprintf("find_file() returnerade %O", fid));
  }
  string calling_find_internal() {
    return("Anropar find_internal()...");
  }
  string find_internal_returned(mixed fid) {
    return(sprintf("find_internal() returnerade %O", fid));
  }
  string returned_directory_indicator() {
    return("Returnerade katalogindikator.");
  }
  string automatic_redirect_to_location() {
    return("Automatisk redirect till location_module.");
  }
  string no_magic() {
    return("Ingen magi begärd. Returnerar -1.");
  }
  string no_directory_module() {
    return("Katalog(directory)-modul saknas. Returnerar 'no such file'");
  }
  string permission_denied() {
    return("Åtkomst nekad");
  }
  string returned_new_fd() {
    return("Returnerade en ny öppen fil.");
  }
  string content_type_module() {
    return("Content-type mappningsmodul");
  }
  string returned_mime_type(string t1, string t2) {
    return("Returnerade typen " + t1 + " " + t2 + ".");
  }
  string missing_type() {
    return("Typ saknas.");
  }
  string returned_not_found() {
    return("Returnerade 'no such file'.");
  }
  string filter_module() {
    return("Filtermodul");
  }
  string rewrote_result() {
    return("Skrev om resultatet.");
  }
  string list_directory(string dir) {
    return(sprintf("Lista katalogen %O.", dir));
  }
  string returned_no_thanks() {
    return("Returnerade 'No thanks'.");
  }
  string recursing() {
    return("Rekurserar");
  }
  string got_exclusive_dir() {
    return("Fick exklusiv katalog.");
  }
  string returning_file_list(int num_files) {
    return("Returnerar en lista med " + num_files + " filer.");
  }
  string got_files() {
    return("Fick filer.");
  }
  string added_module_mountpoint() {
    return("Adderade en modulmountpoint.");
  }
  string returning_no_dir() {
    return("Returnerar 'No such directory'.");
  }
  string stat_file(string file) {
    return(sprintf("Stat file %O.", file));	// FIXME!
  }
  string exact_match() {
    return("Exakt träff.");
  }
  string stat_ok() {
    return("Stat ok.");				// FIXME!
  }
  string find_dir_stat(string file) {
    return("Förfrågan efter katalog och stat's för \""+file+"\".");
  }
  string returned_mapping() {
    return("Returnerade mapping.");
  }
  string empty_dir() {
    return("Tom katalog.");
  }
  string returned_object() {
    return("Returnerade ett objekt.");
  }
  string returning_it() {
    return("Returnerar det.");
  }
  string has_find_dir_stat() {
    return("Har find_dir_stat().");
  }
  string returned_array() {
    return("Returnerade en array.");
  }
  string file_on_mountpoint_path(string file, string path) {
    return(sprintf("Filen %O är på pathen till mountpointen %O.",
		   file, path));
  }
  string error_disabling_module(string name, string bt) {
    return("Fel under borttagandet av modulen " + name +
	   (bt ? ":\n" + bt : "\n"));
  }
  string error_initializing_module_copy(string name, string bt) {
    return("Fel under initieringen av modulkopian av " + name +
	   (bt ? ":\n" + bt : "\n"));
  }
  string disable_nonexistant_module(string name) {
    return("Misslyckades att ta bort en modul:\n"
	   "Ingen modul med namnet: \"" +name + "\".\n");
  }
  string disable_module_failed(string name) {
    return("Misslyckades att ta bort modulen \"" + name + "\".\n");
  }
  string enable_module_failed(string name, string bt) {
    return("Misslyckades att starta modulen " + name + ". Skippar den." +
	   (bt ? "\n" + bt : "\n"));
  }
};

class _config_interface
{
  inherit standard::_config_interface;
  // config/low_describers.pike

  constant all_memory_caches_flushed = "Alla minnescachar har tömts.";
  constant font_test_string = "Gud hjälpe W Zorns mö qvickt få byxa!";

  string module_hint() {
    return "(Modul)";
  }
  string font_hint() {
    return "(Typsnitt)";
  }
  string location_hint() {
    return "(Filnamn i roxens virtuella filsystem)";
  }
  string file_hint() {
    return "(Filnamn i det riktiga filsystemet)";
  }
  string dir_hint() {
    return "(Directory i det riktiga filsystemet)";
  }
  string float_hint() {
    return "(Ett decimaltal)";
  }
  string int_hint() {
    return "(Ett heltal)";
  }
  string stringlist_hint() {
    return "(En kommaseparerad lista)";
  }
  string intlist_hint() {
    return "(En kommaseparerad lista av heltal)";
  }
  string floatlist_hint() {
    return "(En kommaseparerad lista av flyttal)";
  }
  string dirlist_hint() {
    return "(En kommaseparerad lista av kataloger)";
  }
  string password_hint() {
    return "(Ett lösenord, tecken du skriver kommer inte att synas)";
  }
  string unkown_variable_type() {
    return "Okänd variabeltyp";
  }
  string lines( int n ) {
    if(!n) return "tom";
    if(n == 1) return "en rad";
    return _whatevers("rader", n);
  }

  string administration_interface() {
    return("Administrationsgränssnitt");
  }
  string admin_logged_on(string who, string from) {
    return("Administratören loggade på som "+who+" från " + from + ".\n");
  }
  string no_image() {
    return("Det finns ingen sådan bild.");
  }

  string translate_cache_class( string classname )
  {
    return ([
      "supports":"supportdb",
      "fonts":"typsnitt",
      "hosts":"DNS",
    ])[ classname ] || classname;
  }

  constant disabled= "<font color=red>Otillgänglig</font>";
  constant enabled = "<font color=darkgreen>Tillgänglig</font>";
  constant na      = "N/A";

  constant features = "Features";
  constant module_disabled = "Icke tillgängliga moduler";

  constant name = "Namn";
  constant state = "Status";

  constant class_ = "Klass";
  constant entries = "Antal";
  constant size = "Storlek";
  constant hits = "Träffar";
  constant misses = "Missar";
  constant hitpct = "Träff%";

  constant maintenance = "Underhåll";
  constant developer = "Utveckling";

  constant actions = "Funktioner";
  constant clear_log = "Töm loggen";
  constant create_new_site = "Skapa ny sajt";
  constant create_user = "Skapa ny användare";
  constant debug_info = "Debuginformation";
  constant delete = "Radera ";
  constant delete_user = "Ta bort en gammal användare";
  constant empty = "Tom";
  constant error = "Fel";
  constant eventlog = "Loggbok";
  constant ports = "Portar";
  constant globals = "Globala";
  constant home = "Startsida";
  constant configiftab = "Konfiginterface";
  constant manual = "Manual";
  constant modules = "Moduler";
  constant normal =  "Normal";
  constant notice = "Notera";
  constant restart = "Starta om";
  constant reverse = "Reverserad";
  constant save = "Spara";
  constant servers = "Servrar";
  constant settings= "Inställningar";
  constant usersettings= "Dina inställningar";
  constant upgrade = "Uppgradera";
  constant shutdown = "Stäng ner";
  constant site_name = "Sitens namn";
  constant site_pre_text = "";
  constant sites =  "Sajter";
  constant status = "Status";
  constant users = "Användare";
  constant warning = "Varning";
  constant welcome = "Välkommen";
  constant with_template = "med mall";

  constant add_module = "Addera modul";
  constant drop_module = "Ta bort modul";
  constant will_be_loaded_from = "Laddas från";

  constant reload = "Ladda om";

  constant site_name_doc =
#"Namnet måste innehålla minst ett tecken förutom mellanslag och tabsteg.
Det får inte sluta med ~, och får inte vara 'CVS' 'Global Variables'
eller 'global variables'.
Det får inte heller vara samma namn som en redan existerande site, och
tecknen / och \ får inte användas.";

  constant site_type = "Sitens grundkonfiguration";
};

// Global useful words etc.
constant ok = "Ok";
constant cancel = "Avbryt";
constant yes = "ja";
constant no  = "nej";
constant and = "och";
constant or = "eller";
constant every = "var";
constant since = "sedan";
constant next = "Nästa";
constant previous = "Föregående";

string seconds(int n)
{
  if(n == 1) return "en sekund";
  return _whatevers( "sekunder", n );
}

string minutes(int n)
{
  if(n == 1) return "en minut";
  return _whatevers( "minuter", n );
}

string hours(int n)
{
  if(n == 1) return "en timme";
  return _whatevers( "timmar", n );
}

string days(int n)
{
  if(n == 1) return "en dag";
  return _whatevers( "dagar", n );
}

string module_doc_string(mixed module, string var, int long)
{
  return (::module_doc_string(module,var,long) ||
	  RoxenLocale.standard.module_doc_string( module, var, long ));
}
