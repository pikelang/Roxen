/*
 * $Id: standard.pmod,v 1.3 2000/03/07 22:47:40 mast Exp $
 *
 * Roxen locale support -- Default language (English)
 *
 * Henrik Grubbström 1998-10-10
 */
constant name="standard";
constant language = "Language";
constant user = "User";
constant latin1_name = "standard";
constant encoding = "iso-8859-1";

class _base_server
{
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
  string full_status(string real_version, int boot_time,
		     int days, int hrs, int min, int sec, string sent_data,
		     float kbps, string sent_headers, int num_requests,
		     float rpm, string received_data) {
    return(sprintf("<table>"
		   "<tr><td><b>Version:</b></td><td colspan=2>%s</td></tr>\n"
		   "<tr><td><b>Booted on:</b></td><td colspan=2>%s</td></tr>\n"
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
		   real_version, ctime(boot_time),
		   days, (days==1?"":"s"), hrs, min, sec,
		   sent_data, kbps, sent_headers,
		   num_requests, rpm, received_data));
  }

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

  string disabling_configuration(string config) {
    return("Disabling old configuration " + config + "\n");
  }

  string enabled_server(string server) {
    return("Enabled the virtual server \"" +server + "\".\n");
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
  string returned_redirect_to(string location) {
    return("Returned redirect to " + location+"\n" );
  }
  string returned_redirect_no_location() {
    return("Returned redirect, but no location header\n");
  }
  string returned_authenticate(string auth) {
    return("Returned authentication failed: " + auth + "\n");
  }
  string returned_auth_failed() {
    return("Returned authentication failed.\n");
  }
  string returned_ok() {
    return("Returned ok\n");
  }
  string returned_error(int errcode) {
    return("Returned " + errcode + ".\n");
  }
  string returned_no_data() {
    return("No data ");
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
    return("Too deep recursion");
  }
  string extension_module(string ext) {
    return("Extension module [" + ext + "] ");
  }
  string returned_fd() {
    return("Returned open filedescriptor.");
  }
  string seclevel_is_now(int slevel) {
    return(" The security level is now " + slevel + ".");
  }
  string location_module(string loc) {
    return("Location module [" + loc + "] ");
  }
  string module_access_denied() {
    return("Permission to access module denied.");
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
    return("No directory module. Returning 'no such file'");
  }
  string permission_denied() {
    return("Permission denied");
  }
  string returned_new_fd() {
    return("Returned new open file.");
  }
  string content_type_module() {
    return("Content-type mapping module");
  }
  string returned_mime_type(string t1, string t2) {
    return("Returned type " + t1 + " " + t2 + ".");
  }
  string missing_type() {
    return("Missing type.");
  }
  string returned_not_found() {
    return("Returned 'no such file'.");
  }
  string filter_module() {
    return("Filter module");
  }
  string rewrote_result() {
    return("Rewrote result.");
  }
  string list_directory(string dir) {
    return(sprintf("List directory %O.", dir));
  }
  string returned_no_thanks() {
    return("Returned 'No thanks'.");
  }
  string recursing() {
    return("Recursing");
  }
  string got_exclusive_dir() {
    return("Got exclusive directory.");
  }
  string returning_file_list(int num_files) {
    return("Returning list of " + num_files + " files.");
  }
  string got_files() {
    return("Got files.");
  }
  string added_module_mountpoint() {
    return("Added module mountpoint.");
  }
  string returning_no_dir() {
    return("Returning 'No such directory'.");
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
    return("Empty directory.");
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
    return(sprintf("The file %O is on the path to the mountpoint %O.",
		   file, path));
  }

  string error_disabling_module(string name, string bt) {
    return("Error while disabling module " + name +
	   (bt ? ":\n" + bt : "\n"));
  }
  string error_initializing_module_copy(string name, string bt) {
    return("Error while initiating module copy of " + name +
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

object(_base_server) base_server = _base_server();

class _config_actions
{
  constant all_memory_caches_flushed = "All memory caches have been flushed.";

  constant font_test_string = "The quick brown fox jumped over the lazy dog.";
}

object(_config_actions) config_actions = _config_actions();

class _config_interface
{
  // config/low_describers.pike
  string module_hint() {
    return "(Module)";
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
    return "(A directory in the real filesystem)";
  }
  string float_hint() {
    return "(A number)";
  }
  string int_hint() {
    return "(An integer number)";
  }
  string stringlist_hint() {
    return "(Comma separated list)";
  }
  string intlist_hint() {
    return "(Comma separated list of inters)";
  }
  string floatlist_hint() {
    return "(Comma separated list of floats)";
  }
  string dirlist_hint() {
    return "(Comma separated list of directories)";
  }
  string password_hint() {
    return "(A password, your input will not be visible)";
  }
  string ports_configured( int n )
  {
    if(!n) return "no ports configured";
    if(n == 1) return "one port configured";
    return _whatevers("ports configured", n);
  }
  string unkown_variable_type() {
    return "Unknown variable type";
  }
  string lines( int n )
  {
    if(!n) return "empty";
    if(n == 1) return "one line";
    return _whatevers("lines", n);
  }


  string administration_interface() {
    return("Administration Interface");
  }
  string admin_logged_on(string who, string from) {
    return("Administrator logged on as "+who+" from " + from + ".\n");
  }


  string translate_cache_class( string classname )
  {
    return ([
      "supports":"supportdb",
      "fonts":"fonts",
      "hosts":"DNS",
    ])[ classname ] || classname;
  }

  constant name = "Name";
  constant state = "State";

  constant features = "Features";
  constant module_disabled = "Disabled modules";
  constant all_modules = "All modules";

  constant disabled= "Disabled";
  constant enabled = "<font color=&usr.fade4;>Enabled</font>";
  constant na      = "N/A";

  constant class_ = "Class";
  constant entries = "Entries";
  constant size = "Size";
  constant hits = "Hits";
  constant misses = "Misses";
  constant hitpct = "Hit%";

  constant reload = "Reload";
  constant empty = "Empty";
  constant status = "State";
  constant sites =  "Sites";
  constant servers = "Servers";
  constant settings= "Settings";
  constant usersettings= "Your Settings";
  constant upgrade = "Upgrade";
  constant modules = "Modules";
  constant globals = "Globals";
  constant eventlog = "Event Log";
  constant ports = "Ports";
  constant reverse = "Reversed";
  constant normal = "Normal";
  constant notice = "Notice";
  constant warning = "Warning";
  constant error = "Error";
  constant actions = "Tasks";
  constant manual = "Manual";
  constant clear_log = "Clear Log";


  constant debug_info = "Debug information";
  constant welcome = "Welcome";
  constant restart = "Restart";
  constant users = "Users";
  constant shutdown = "Shutdown";
  constant home = "Startpage";
  constant configiftab = "Configuration Interface";

  constant create_user = "Create new user";
  constant delete_user = "Delete old user";

  constant delete = "Delete";
  constant save = "Save";

  constant add_module = "Add Module";
  constant drop_module = "Drop Module";
  constant will_be_loaded_from = "Will be loaded from";

  constant maintenance = "Maintenance";
  constant developer = "Development";

  constant create_new_site = "Create new site";
  constant with_template = "with template";
  constant site_pre_text = "";
  constant site_name = "Site name";
  constant site_type = "Site type";
  constant site_name_doc =
#"The name of the configuration must contain characters
other than space and tab, it should not end with
~, and it must not be 'CVS', 'Global Variables' or
'global variables', nor the name of an existing
configuration, and the character '/' cannot be
used";
};
object(_config_interface) config_interface = _config_interface();


// Global useful words
constant ok = "Ok";
constant cancel = "Cancel";
constant yes = "Yes";
constant no  = "No";
constant and = "and";
constant or = "or";
constant every = "every";
constant since = "since";
constant next = "Next";
constant previous = "Previous";

constant actions = "Tasks";
constant manual = "Manual";

string _whatevers( string what, int n )
{
  string as_string = roxenp()->language( name, "number" )(n);
  if(n<12)
    return as_string+" "+what;
  return n+" "+what;
}

string seconds(int n)
{
  if(n == 1) return "one second";
  return _whatevers( "seconds", n );
}

string minutes(int n)
{
  if(n == 1) return "one minute";
  return _whatevers( "minutes", n );
}

string hours(int n)
{
  if(n == 1) return "one hour";
  return _whatevers( "hours", n );
}

string days(int n)
{
  if(n == 1) return "one day";
  return _whatevers( "days", n );
}


//
//  ([  "module_name":([ "variable":({ name, doc }) ]) ])
//
mapping _module_doc_strings = ([ ]);

string module_name( object mod )
{
  string name;
  if(mod && mod->cvs_version)
  {
    sscanf(mod->cvs_version, "$Id: %s.pike", name );
    //    werror("module name is '"+name+"'\n");
    return name;
  }
}

string module_doc_string( mixed module, string var, int long )
{
  if(_module_doc_strings[module] && _module_doc_strings[module][var])
    return _module_doc_strings[module][var][long];
  object ld = RoxenLocale.Modules[latin1_name];
  if( !ld ) return 0;
  return ld->module_doc( module_name(module), var, long );
}

void register_module_doc( mixed module, string var, string name,
			  string desc, void|mapping translate_options )
{
  if(!_module_doc_strings[module])
    _module_doc_strings[module] = ([ ]);
  _module_doc_strings[module][var] = ({ name, desc, translate_options });
}







#ifdef EXPORT_MODE
#define WRITE(X) write( Locale.Charset.encoder( encoding )->feed( X )->drain() )

mapping already_done = ([]);

string format_doc( string what )
{
  string res = "";
  string current_line = "";
  foreach(replace( replace(what, "<br>", "<br>\n"), "<p>", "\n<p>\n")/" ",
          string word )
  {
    if( strlen( current_line ) )
      current_line += " "+word;
    else
      current_line = word;
    if(sizeof(current_line) && current_line[-1] == '\n')
    {
      res += current_line;
      current_line = "";
    }
    if( sizeof(current_line) > 60 )
    {
      res += current_line+"\n";
      current_line = "";
    }
  }
  res += current_line;
  return res;
}

void write_module_doc( Stdio.File f, string module, mapping ev, mapping nv )
{
  object ld = RoxenLocale.Modules[latin1_name];

  if(!ev) return;
  if(!nv) nv = ([]);
  foreach(sort( indices(ev) ), string var )
  {
      f->WRITE( "--\n"
                "--\n"
                "--- variable "+var+"\n" );

    if( !nv[var] && ld)
    {
      string s = ld->module_doc( module, var, 0 );
      string l = ld->module_doc( module, var, 1 );
      if( s && l ) nv[var] = ({ s, l });
    }

    if( already_done[ev[var][0]] && already_done[ev[var][1]]
        && already_done[ev[var][0]] == already_done[ev[var][1]])
    {
      f->WRITE( "ALIAS "+already_done[ev[var[0]]]+"\n"+
                "ALIAS "+already_done[ev[var[1]]]+"\n");
      continue;
    }

    already_done[ev[var[0]]] = module+"/"+var+"/0";
    already_done[ev[var[1]]] = module+"/"+var+"/1";


    f->WRITE( "-- English version:\n"
              "--   "+ev[var][0]+"\n"
              "--   "+replace(format_doc(ev[var][1]||""),"\n", "\n--  ")+"\n"
              "--\n"
              "-- Translated version:\n"
              "--\n"
              +(nv[var]?nv[var][0]:ev[var][0])+"\n"
              +format_doc(nv[var]?(nv[var][1]||""):(ev[var][1]||""))+"\n" );
  }
}


void export_module_doc_stuff()
{
  if( name != "standard" )
  {
    mapping oq = RoxenLocale["standard"]->_module_doc_strings;
    object f = Stdio.File( "/tmp/"+latin1_name+".in", "wct" );
    array mods = indices( oq );
    array n = sort(Array.map(indices( oq ),module_name), mods);
    multiset written = (<>);
    int i;

    f->WRITE("-*- roxen-locale-doc -*-\n"
             "- "+language+" strings for Roxen.\n"
             "--- charset "+encoding+"\n"
             "\n");

    for( i = 0; i<sizeof( mods ); i++ )
    {
      if( !written[n[i]] )
      {
        written[n[i]] = 1;
        werror("Writing module "+n[i]+"\n");
        f->WRITE( "--- module "+n[i]+"\n" );
        write_module_doc( f, n[i], oq[mods[i]], _module_doc_strings[mods[i]] );
      }
    }
  }
}

void create()
{
  call_out( export_module_doc_stuff, 10 );
}
#endif
