#charset iso-8859-2
/*
 * $Id: cestina.pmod,v 1.1 2000/02/14 08:56:36 per Exp $
 *
 * Roxen locale support -- Cestina (Czech)
 *
 * Honza Petrous 1999-12-15
 */
inherit RoxenLocale.standard;
constant name="cestina";
constant language = "Jazyk";
constant latin1_name = "cestina"; //"Èe¹tina";
constant encoding = "iso-8859-2";

class _base_server {
  inherit standard::_base_server;       // Fallback.
};


class _config_actions
{
  inherit .standard._config_actions; //Fallback
}

class _config_interface
{
  // config/low_describers.pike

  inherit .standard._config_interface; //Fallback

  string module_hint() {
    return "(Module)";
  }
  string font_hint() {
    return "(Font)";
  }
  string location_hint() {
    return "(A location in roxens virtual filesystem)";
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
    return "(A integer number)";
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
  // base_server/mainconfig.pike
  string administration_interface() {
    return("Administration Interface");
  }
  string admin_logged_on(string who, string from) {
    return("Administrator se pøipojil jako "+who+" z " + from + ".\n");
  }


  string translate_cache_class( string classname )
  {
    return ([
      "supports":"supportdb",
      "fonts":"fonts",
      "hosts":"DNS",
    ])[ classname ] || classname;
  }


  constant action_cachestatus =
  ([
    "name":"Cache Status",
    "doc":"Show memory and disk cache (if enabled) status information",
    "category":"Cache",
    "more":1,
  ]);

  constant action_feature_list =
  ([
    "name":"Feature List",
    "doc":
    "Show information about which features and modules are "
    "available in the pike this roxen is using",
    "category":"Development",
    "developer":1,
  ]);

  constant name = "Name";
  constant state = "State";

  constant features = "Features";
  constant module_disabled = "Disabled modules";
  constant all_modules = "All modules";

  constant disabled= "Disabled>";
  constant enabled = "<font color=&usr.fade4;>Enabled</font>";
  constant na      = "N/A";

  constant class_ = "Class";
  constant entries = "Entries";
  constant size = "Size";
  constant hits = "Hits";
  constant misses = "Misses";
  constant hitpct = "Hit%";

  constant reload = "Reload";
  constant empty = "Prázdný";
  constant status = "Stav";
  constant sites =  "Virtuální servery";
  constant servers = "Servery";
  constant settings= "Nastavení";
  constant usersettings= "Va¹e nastavení";
  constant modules = "Moduly";
  constant globals = "Spoleèné";
  constant eventlog = "®urnál";
  constant reverse = "Reverznì";
  constant normal = "Normálnì";
  constant notice = "Poznámka";
  constant warning = "Upozornìní";
  constant error = "Chyba";
  constant actions = "Akce";  // Nastroje?
  constant manual = "Manuál";
  constant clear_log = "Smazat ¾urnál";


  constant debug_info = "Debug info"; //Servis?
  constant welcome = "Vítejte";
  constant restart = "Restart";
  constant users = "U¾ivatelé";
  constant shutdown = "Reboot";
  constant home = "Startpage";

  constant create_user = "Vytvoøit u¾ivatele";
  constant delete_user = "Smazat u¾ivatele";

  constant delete = "Smazat";
  constant save = "Ulo¾it";

  constant create_new_site = "Nový virtuální server";
  constant with_template = "s pomocí ¹ablony";
  constant site_pre_text = "";
  constant site_name = "Site name";
  constant site_type = "Site type";
  constant site_name_doc = "The name of the configuration must contain characters other than space and tab, it should not end with ~, and it must not be 'CVS', 'Global Variables' or 'global variables', nor the name of an existing configuration, and the character '/' cannot be used";
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


string module_doc_string(mixed module, string var, int long)
{
  return (::module_doc_string(module,var,long) ||
          RoxenLocale.standard.module_doc_string( module, var, long ));
}
