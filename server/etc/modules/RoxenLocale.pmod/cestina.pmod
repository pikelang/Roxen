#charset iso-8859-2
/*
 * $Id: cestina.pmod,v 1.2 2000/03/10 22:30:21 hop Exp $
 *
 * Roxen locale support -- Cestina (Czech)
 *
 * Honza Petrous 1999-12-15
 *
 * Poznamka: Preklad neni nic moc, chtelo by to nejaky
 *           slovnik odbornych vyrazu :-(
 */
inherit RoxenLocale.standard;
constant name="cestina";
constant language = "Jazyk";
constant latin1_name = "cestina"; //"Èe¹tina";
constant encoding = "iso-8859-2";

class _base_server {
  inherit standard::_base_server;       // Fallback.

  // base_server/roxen.pike
  string uncaught_error(string bt) {
    return("Nezachytitelná chyba v ovladaèi vlákna: " + bt +
	   "Klient nedostane ¾ádnou odpovìï.\n");
  }
  string supports_bad_include(string file) {
    return("Supports: Nelze naèíst/vlo¾it soubor "+file+"\n");
  }
  string supports_bad_regexp(string bt) {
    return(sprintf("Chyba pøi interpretaci databáze supports regexp:\n%s\n", bt));
  }
  string replacing_supports() { return("Nahra¾en soubor etc/supports"); }
  string unique_uid_logfile() { return("Unikátní user ID logfile.\n"); }
  string no_servers_enabled() { return("<B>®ádný virtuální server není aktivován.</B>\n"); }
  string full_status(string real_version, int boot_time,
		     int days, int hrs, int min, int sec, string sent_data,
		     float kbps, string sent_headers, int num_requests,
		     float rpm, string received_data) {
    return(sprintf("<table>"
		   "<tr><td><b>Verze:</b></td><td colspan=2>%s</td></tr>\n"
		   "<tr><td><b>Start:</b></td><td colspan=2>%s</td></tr>\n"
		   "<tr><td><b>On-line:</b></td>"
		   "<td colspan=2>%d dní%s, %02d:%02d:%02d</td></tr>\n"
		   "<tr><td colspan=3>&nbsp;</td></tr>\n"
		   "<tr><td><b>Data out:</b></td><td>%s"
		   "</td><td>%.2f Kbit/sec</td></tr><tr>\n"
		   "<td><b>Hlavièky out:</b></td><td>%s</td></tr>\n"

		   "<tr><td><b>Poèet pøístupù:</b></td>"
		   "<td>%8d</td><td>%.2f/min</td></tr>\n"
		   "<tr><td><b>Data in:</b></td>"
		   "<td>%s</td></tr>\n"
		   "</table>",
		   real_version, ctime(boot_time),
		   days, "", hrs, min, sec,
		   sent_data, kbps, sent_headers,
		   num_requests, rpm, received_data));
  }

  string setting_uid_gid_permanently(int uid, int gid, string uname, string gname) {
    return("Permanentnì nastaveno uid na "+uid+" ("+uname+")"+
	   (gname ? " a gid na "+gid+" ("+gname+")" : "")+" .\n");
  }

  string setting_uid_gid(int uid, int gid, string uname, string gname) {
    return("Nastaveno uid na "+uid+" ("+uname+")"+
	   (gname ? " a gid na "+gid+" ("+gname+")" : "")+".\n");
  }

  string error_enabling_configuration(string config, string bt) {
    return("Chyba pøi startu konfigurace "+config+
	   (bt ? ":\n" + bt : "\n"));
  }

  string disabling_configuration(string config) {
    return("Zastavení staré konfigurace " + config + "\n");
  }

  string enabled_server(string server) {
    return("Enabled the virtual server \"" +server + "\".\n");
  }

  string opening_low_port() {
    return("Otevøení portu pod 1024");
  }

  string url_format() {
    return("URL musí být v následujícím formátu: protocol://computer[:port]/");
  }

  // base_server/configuration.pike
  string failed_to_open_logfile(string logfile) {
    return("Nelze otevøít ¾urnál. ("+logfile+")\n" +
	   "®urnálování nebude aktivní!\n");
  }
  string config_status(float sent_data, float kbps, float sent_headers,
		       int num_requests, float rpm, float received_data) {
    return(sprintf("<tr align=right><td><b>Data out:</b></td><td>%.2fMB"
                   "</td><td>%.2f Kbit/sec</td>"
		   "<td><b>Hlavièky out:</b></td><td>%.2fMB</td></tr>\n"
		   "<tr align=right><td><b>Poèet pøístupù:</b></td>"
		   "<td>%8d</td><td>%.2f/min</td>"
		   "<td><b>Data in:</b></td><td>%.2fMB</td></tr>\n",
		   sent_data, kbps, sent_headers,
  		   num_requests, rpm, received_data));
  }
  string ftp_status(int total_users, float upm, int num_users) {
    return(sprintf("<tr align=right><td><b>FTP u¾ivatelé (celkem):</b></td>"
		   "<td>%8d</td><td>%.2f/min</td>"
		   "<td><b>FTP u¾ivatelé (nyní):</b></td><td>%d</td></tr>\n",
		   total_users, upm, num_users));
  }
  string ftp_statistics() {
    return("<b>FTP statistika:</b>");
  }
  string ftp_stat_line(string cmd, int times) {
    return(sprintf("<tr align=right><td><b>%s</b></td>"
		   "<td align=right>%d</td><td> time%s</td></tr>\n",
		   cmd, times, ""));
  }
  string no_auth_module() {
    return("Není autorizaèní modul");
  }
  string module_security_error(string bt) {
    return(sprintf("Chyba pøi kontrole bezpeènosti modulu:\n"
		   "%s\n", bt));
  }
  string clear_memory_cache_error(string modname, string bt) {
    return(sprintf("clear_memory_caches() pro modul %O:\n"
		   "%s neprobìhlo\n", modname, bt));
  }
  string returned_redirect_to(string location) {
    return("Vráceno pøesmìrování (redirect) na " + location+"\n" );
  }
  string returned_redirect_no_location() {
    return("Vráceno pøesmìrování (redirect), ale chybí hlavièka Location\n");
  }
  string returned_authenticate(string auth) {
    return("Vrácena chybná autentizace: " + auth + "\n");
  }
  string returned_auth_failed() {
    return("Vrácena chybná authentizace.\n");
  }
  string returned_ok() {
    return("Vráceno ok\n");
  }
  string returned_error(int errcode) {
    return("Vráceno " + errcode + ".\n");
  }
  string returned_no_data() {
    return("Chybí data ");
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
    return "(open file)";
  }
  string returned_type(string type) {
    return(" of " + type + "\n");
  }
  string request_for(string path) {
    return("Request for " + path);
  }
  string magic_internal_gopher() {
    return("Magic internal gopher image");
  }
  string magic_internal_roxen() {
    return("Magic internal roxen image");
  }
  string magic_internal_module_location() {
    return("Magic internal module location");
  }
  string directory_module() {
    return("Directory module");
  }
  string returning_data() {
    return("Returning data");
  }
  string url_module() {
    return("URL module");
  }
  string too_deep_recursion() {
    return("Moc hluboká rekurze");
  }
  string extension_module(string ext) {
    return("Extension module [" + ext + "] ");
  }
  string returned_fd() {
    return("Returned open filedescriptor.");
  }
  string seclevel_is_now(int slevel) {
    return(" Bezpeènostní úroveò je nyní " + slevel + ".");
  }
  string location_module(string loc) {
    return("Location module [" + loc + "] ");
  }
  string module_access_denied() {
    return("Pøístup k modulu odepøen.");
  }
  string request_denied() {
    return("Request denied.");
  }
  string calling_find_file() {
    return("Calling find_file()...");
  }
  string find_file_returned(mixed fid) {
    return(sprintf("find_file has returned %O", fid));
  }
  string calling_find_internal() {
    return("Calling find_internal()...");
  }
  string find_internal_returned(mixed fid) {
    return(sprintf("find_internal has returned %O", fid));
  }
  string returned_directory_indicator() {
    return("Returned directory indicator.");
  }
  string automatic_redirect_to_location() {
    return("Automatic redirect to location_module.");
  }
  string no_magic() {
    return("No magic requested. Returning -1.");
  }
  string no_directory_module() {
    return("Chybí directory modul. Vráceno 'no such file'");
  }
  string permission_denied() {
    return("Pøístup odepøen");
  }
  string returned_new_fd() {
    return("Vrácen novì otevøený soubor.");
  }
  string content_type_module() {
    return("Content-type mapping module");
  }
  string returned_mime_type(string t1, string t2) {
    return("Vrácen typ " + t1 + " " + t2 + ".");
  }
  string missing_type() {
    return("Typ chybí.");
  }
  string returned_not_found() {
    return("Vráceno 'no such file'.");
  }
  string filter_module() {
    return("Filter module");
  }
  string rewrote_result() {
    return("Výsledek pøepsán.");
  }
  string list_directory(string dir) {
    return(sprintf("Výpis adresáøe %O.", dir));
  }
  string returned_no_thanks() {
    return("Vráceno 'No thanks'.");
  }
  string recursing() {
    return("Recurze");
  }
  string got_exclusive_dir() {
    return("Got exclusive directory.");
  }
  string returning_file_list(int num_files) {
    return("Vrácen výpis " + num_files + " souborù.");
  }
  string got_files() {
    return("Got files.");
  }
  string added_module_mountpoint() {
    return("Added module mountpoint.");
  }
  string returning_no_dir() {
    return("Vráceno 'No such directory'.");
  }
  string stat_file(string file) {
    return(sprintf("Stat file %O.", file));
  }
  string exact_match() {
    return("Exact match.");
  }
  string stat_ok() {
    return("Stat ok.");
  }
  string find_dir_stat(string file) {
    return("Request for directory and stat's \""+file+"\".");
  }
  string returned_mapping() {
    return("Returned mapping.");
  }
  string empty_dir() {
    return("Prázdný adresáø.");
  }
  string returned_object() {
    return("Returned object.");
  }
  string returning_it() {
    return("Returning it.");
  }
  string has_find_dir_stat() {
    return("Has find_dir_stat().");
  }
  string returned_array() {
    return("Returned array.");
  }
  string file_on_mountpoint_path(string file, string path) {
    return(sprintf("Soubor %O je v cestì k mountpointu %O.",
		   file, path));
  }

  string error_disabling_module(string name, string bt) {
    return("Chyba pøi zastavení modulu " + name +
	   (bt ? ":\n" + bt : "\n"));
  }
  string error_initializing_module_copy(string name, string bt) {
    return("Chyba pøi inicializaci instance modulu " + name +
	   (bt ? ":\n" + bt : "\n"));
  }
  string disable_nonexistant_module(string name) {
    return("Failed to disable module:\n"
	   "No module by that name: \"" +name + "\".\n");
  }
  string disable_module_failed(string name) {
    return("Failed to disable module \"" + name + "\".\n");
  }
  string enable_module_failed(string name, string bt) {
    return("Failed to enable the module " + name + ". Skipping." +
	   (bt ? "\n" + bt : "\n"));
  }

};


class _config_actions
{
  inherit .standard._config_actions; //Fallback

  constant all_memory_caches_flushed = "V¹echny pamì»ové cache byly vymazány.";

  constant font_test_string = "Pøíli¹ ¾lu»ouèký kùò úpìl ïábelské ódy.";
}


class _config_interface
{
  // config/low_describers.pike

  inherit .standard._config_interface; //Fallback

  string module_hint() {
    return "(Modul)";
  }
  string font_hint() {
    return "(Font)";
  }
  string location_hint() {
    return "(A location in the virtual filesystem)";
  }
  string file_hint() {
    return "(A filename in the real filesystem)";
  }
  string dir_hint() {
    return "(Adresáø v reálném filesystému)";
  }
  string float_hint() {
    return "(Èíslo)";
  }
  string int_hint() {
    return "(Celé èíslo)";
  }
  string stringlist_hint() {
    return "(Seznam oddìlený èárkami)";
  }
  string intlist_hint() {
    return "(Seznam celých èísel oddìlených èárkami)";
  }
  string floatlist_hint() {
    return "(Seznam èísel oddìlených èárkami)";
  }
  string dirlist_hint() {
    return "(Seznam adresáøù oddìlených èárkami)";
  }
  string password_hint() {
    return "(Heslo)";
  }
  string ports_configured( int n )
  {
    if(!n) return "¾ádný port není konfigurován";
    return _whatevers("portù konfigurováno", n);
  }
  string unkown_variable_type() {
    return "Neznámý typ promìnné";
  }
  string lines( int n )
  {
    if(!n) return "prázdné";
    if(n == 1) return "jeden øádek";
    return _whatevers("øádkù", n);
  }


  string administration_interface() {
    return("Administraèní rozhraní");
  }
  string admin_logged_on(string who, string from) {
    return("Administrátor se pøipojil jako "+who+" z " + from + ".\n");
  }


  string translate_cache_class( string classname )
  {
    return ([
      "supports":"supportdb",
      "fonts":"fonty",
      "hosts":"DNS",
    ])[ classname ] || classname;
  }

  constant name = "Jméno";
  constant state = "Stav";

  constant features = "Vlastnost";
  constant module_disabled = "Zakázané moduly";
  constant all_modules = "V¹echny moduly";

  constant disabled= "Zakázán";
  constant enabled = "<font color=&usr.fade4;>Povolen</font>";
  constant na      = "N/A";

  constant class_ = "Tøída";
  constant entries = "Polo¾ky";
  constant size = "Velikost";
  constant hits = "Hits";
  constant misses = "Misses";
  constant hitpct = "Hit%";

  constant reload = "Reload";
  constant empty = "Prázdný";
  constant status = "Stav";
  constant sites =  "Servery";
  constant servers = "Servery";
  constant settings= "Nastavení";
  constant usersettings= "U¾ivatelské nastavení";
  constant upgrade = "Upgrade";
  constant modules = "Moduly";
  constant globals = "Spoleèné";
  constant eventlog = "®urnál";
  constant ports = "Porty";
  constant reverse = "Reverznì";
  constant normal = "Normálnì";
  constant notice = "Poznámka";
  constant warning = "Upozornìní";
  constant error = "Chyba";
  constant actions = "Akce";
  constant manual = "Manuál";
  constant clear_log = "Smazat ¾urnál";


  constant debug_info = "Ladící info";
  constant welcome = "Ahoj";
  constant restart = "Restart";
  constant users = "U¾ivatelé";
  constant shutdown = "Shutdown";
  constant home = "Start";
  constant configiftab = "Konfiguraèní rozhraní";

  constant create_user = "Vytvoøit u¾ivatele";
  constant delete_user = "Smazat u¾ivatele";

  constant delete = "Samazat";
  constant save = "Ulo¾it";

  constant add_module = "Pøidat modul";
  constant drop_module = "Odstranit modul";
  constant will_be_loaded_from = "Will be loaded from";

  constant maintenance = "Údr¾ba";
  constant developer = "Vývoj";

  constant create_new_site = "Vytvoøit server";
  constant with_template = "s pomocí ¹ablony";
  constant site_pre_text = "";
  constant site_name = "Jméno serveru";
  constant site_type = "Typ serveru";
  constant site_name_doc =
#"Jméno musí obsahovat pouze alfanumerické znaky,
 nesmí konèit na ~ a nesmí se jmenovat 'CVS',
 'Global Variables', 'global variables' a také
 nesmí obsahovat / .";
};

// Global useful words
constant ok = "Ok";
constant cancel = "Zru¹it";
constant yes = "Ano";
constant no  = "Ne";
constant and = "a";
constant or = "nebo";
constant every = "v¾dy";
constant since = "od";
constant next = "Dal¹í";
constant previous = "Pøedchozí";

constant actions = "Actions";
constant manual = "Manual";

string seconds(int n)
{
  if(n == 1) return "jedna sekunda";
  return _whatevers( "sekund", n );
}

string minutes(int n)
{
  if(n == 1) return "jedna minuta";
  return _whatevers( "minut", n );
}

string hours(int n)
{
  if(n == 1) return "jedna hodina";
  return _whatevers( "hodin", n );
}

string days(int n)
{
  if(n == 1) return "jeden den";
  return _whatevers( "dní", n );
}


string module_doc_string(mixed module, string var, int long)
{
  return (::module_doc_string(module,var,long) ||
          RoxenLocale.standard.module_doc_string( module, var, long ));
}
