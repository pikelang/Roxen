#charset iso-8859-2
/*
 * $Id: magyar.pmod,v 1.4 2000/07/09 14:09:46 per Exp $
 *
 * Roxen locale support -- Default language (English)
 *
 * Henrik Grubbström 1998-10-10
 */
inherit RoxenLocale.standard;
constant name="magyar";
constant language = "magyar";
constant latin1_name = "magyar";
constant encoding = "iso-8859-2";

class _base_server {
  inherit standard::_base_server;       // Fallback.

  // base_server/roxen.pike
  string uncaught_error(string bt) {
    return("Uncaught error in handler thread: " + bt +
	   "Client will not get any response from Roxen.\n");
  }
  string supports_bad_include(string file) {
    return("Supports: Cannot include file "+file+"\n");
  }
  string supports_bad_regexp(string bt) {
    return(sprintf("Failed to parse supports regexp:\n%s\n", bt));
  }
  string replacing_supports() { return("Replacing etc/supports"); }
  string unique_uid_logfile() { return("Unique user ID logfile.\n"); }
  string no_servers_enabled() { return("<B>No virtual servers enabled</B>\n"); }
  string full_status(string real_version, int boot_time, int time_to_boot,
		     int days, int hrs, int min, int sec, string sent_data,
		     float kbps, string sent_headers, int num_requests,
		     float rpm, string received_data) {
    return(sprintf("<table>"
		   "<tr><td><b>Version:</b></td><td colspan=2>%s</td></tr>\n"
		   "<tr><td><b>Booted on:</b></td><td colspan=2>%s</td></tr>\n"
		   "<tr><td><b>Time to boot:</b></td>"
		   "<td>%d sec</td></tr>\n"
		   "<tr><td><b>Uptime:</b></td>"
		   "<td colspan=2>%d day%s, %02d:%02d:%02d</td></tr>\n"
		   "<tr><td colspan=3>&nbsp;</td></tr>\n"
		   "<tr><td><b>Sent data:</b></td><td>%s"
		   "</td><td>%.2f Kbit/sec</td></tr><tr>\n"
		   "<td><b>Sent headers:</b></td><td>%s</td></tr>\n"

		   "<tr><td><b>Number of requests:</b></td>"
		   "<td>%8d</td><td>%.2f/min</td></tr>\n"
		   "<tr><td><b>Received data:</b></td>"
		   "<td>%s</td></tr>\n"
		   "</table>",
		   real_version, ctime(boot_time), time_to_boot,
		   days, (days==1?"":"s"), hrs, min, sec,
		   sent_data, kbps, sent_headers,
		   num_requests, rpm, received_data));
  }
  string anonymous_user() { return("Anony Mouse"); }

  string setting_uid_gid_permanently(int uid, int gid, string uname, string gname) {
    return("Setting uid to "+uid+" ("+uname+")"+
	   (gname ? " and gid to "+gid+" ("+gname+")" : "")+" permanently.\n");
  }
  string setting_uid_gid(int uid, int gid, string uname, string gname) {
    return("Setting uid to "+uid+" ("+uname+")"+
	   (gname ? " and gid to "+gid+" ("+gname+")" : "")+".\n");
  }
  string error_enabling_configuration(string config, string bt) {
    return("Error while enabling configuration "+config+
	   (bt ? ":\n" + bt : "\n"));
  }
  string opening_low_port() {
    return("Opening listen port below 1024");
  }
  string url_format() {
    return("The URL should follow this format: protocol://computer[:port]/");
  }

  // base_server/configuration.pike
  string failed_to_open_logfile(string logfile) {
    return("Failed to open logfile. ("+logfile+")\n" +
	   "No logging will take place!\n");
  }

  string config_status(float sent_data, float kbps, float sent_headers,
		       int num_requests, float rpm, float received_data) {
    return(sprintf("<tr align=right><td><b>Sent data:</b></td><td>%.2fMB"
		  "</td><td>%.2f Kbit/sec</td>"
		   "<td><b>Sent headers:</b></td><td>%.2fMB</td></tr>\n"
		   "<tr align=right><td><b>Number of requests:</b></td>"
		   "<td>%8d</td><td>%.2f/min</td>"
		   "<td><b>Received data:</b></td><td>%.2fMB</td></tr>\n",
		   sent_data, kbps, sent_headers,
  		   num_requests, rpm, received_data));
  }
  string ftp_status(int total_users, float upm, int num_users) {
    return(sprintf("<tr align=right><td><b>FTP users (total):</b></td>"
		   "<td>%8d</td><td>%.2f/min</td>"
		   "<td><b>FTP users (now):</b></td><td>%d</td></tr>\n",
		   total_users, upm, num_users));
  }
  string ftp_statistics() {
    return("<b>FTP statistics:</b>");
  }
  string ftp_stat_line(string cmd, int times) {
    return(sprintf("<tr align=right><td><b>%s</b></td>"
		   "<td align=right>%d</td><td> time%s</td></tr>\n",
		   cmd, times, (times == 1)?"":"s"));
  }
  string no_auth_module() {
    return("No authorization module");
  }
  string module_security_error(string bt) {
    return(sprintf("Error during module security check:\n"
		   "%s\n", bt));
  }
  string clear_memory_cache_error(string modname, string bt) {
    return(sprintf("clear_memory_caches() failed for module %O:\n"
		   "%s\n", modname, bt));
  }
  string file_on_mountpoint_path(string file, string path) {
    return(sprintf("The file %O is on the path to the mountpoint %O.",
		   file, path));
  }
  string error_disabling_module(string name, string bt) {
    return("Error during disabling of module " + name +
	   (bt ? ":\n" + bt : "\n"));
  }
  string error_initializing_module_copy(string name, string bt) {
    return("Error while initiating module copy of " + name +
	   (bt ? ":\n" + bt : "\n"));
  }
  string disable_module_failed(string name) {
    return("Failed to disable module \"" + name + "\".\n");
  }
  string enable_module_failed(string name, string bt) {
    return("Failed to enable the module " + name + ". Skipping." +
	   (bt ? "\n" + bt : "\n"));
  }
};

class _config_interface
{
  inherit .standard._config_interface;

  string translate_cache_class( string what ) {
	switch(what) {
	 case "modules":	return "modulok";
	 case "fonts":		return "karakterkészlet";
	 case "file":		return "fájl";
	 case "stat_cache":	return "fájl-állapot";
	 case "hosts":		return "DNS";
    }
    return what;
  }


  string module_hint() {
    return "(Modul)";
  }
  string font_hint() {
    return "(Karakter)";
  }
  string location_hint() {
    return "(A roxen virtual fájlrendszeren egy elérési út)";
  }
  string file_hint() {
    return "(A valós fájlrendszeren egy fájlnév)";
  }
  string dir_hint() {
    return "(A valós fájlrendszeren egy könyvtár)";
  }
  string float_hint() {
    return "(Egy szám)";
  }
  string int_hint() {
    return "(Egy egyész szám)";
  }
  string stringlist_hint() {
    return "(Vesszõvel felsorolt lista)";
  }
  string intlist_hint() {
    return "(Vesszõvel felsorolt egész szám lista)";
  }
  string floatlist_hint() {
    return "(Vesszõvel felsorolt lebegõpontos szám lista)";
  }
  string dirlist_hint() {
    return "(Vesszõvel felsorolt könyvtár lista)";
  }
  string password_hint() {
    return "(egy jelszó, nem látható a gépelésnél)";
  }
  string color() {
    return "Szín";
  }
  string unkown_variable_type() {
    return "Ismeretlen változó tipus";
  }
  string lines( int n )
  {
    if(!n) return "üres";
    return _whatevers("sor", n);
  }

  string administration_interface() {
    return("Adminisztrációs Panel");
  }
  string admin_logged_on(string from) {
    return("Adminisztrátori belépés:" + from + ".\n");
  }

  constant add_module = "Modul hozzáadása";
  constant sites = "Szájtok";
  constant empty = "Üres";
  constant settings = "Beállítások";
  constant modules = "Modulok";
  constant globals = "Globál";
  constant eventlog = "Eseménynapló";
  constant reverse = "Fordított";
  constant normal = "Normal";
  constant notice = "Megjegyzés";
  constant warning = "Figyelmeztetés";
  constant error = "Hiba";
  constant actions = "Vezérlõ";
  constant manual = "Dokumentáció";
};



// Global useful words
constant ok = "Ok";
constant cancel = "Mégsem";
constant yes = "igen";
constant no  = "nem";
constant and = "és";
constant or = "vagy";
constant every = "minden";
constant since = "óta";
constant next = "Következõ";
constant previous = "Elõzõ";


string seconds(int n)
{
  return _whatevers( "másodperce", n );
}

string minutes(int n)
{
  return _whatevers( "perce", n );
}

string hours(int n)
{
  return _whatevers( "órája", n );
}

string days(int n)
{
  return _whatevers( "napja", n );
}

string module_doc_string(int var, int long)
{
  return (::module_doc_string(var,long) ||
	  RoxenLocale.standard.module_doc_string( var, long ));
}
