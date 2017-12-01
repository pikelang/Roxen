#include <module.h>

inherit "module";

constant module_type = MODULE_LOCATION;

constant module_unique = 0;

//<locale-token project="mod_fs_proxy">LOCALE</locale-token>
//<locale-token project="mod_fs_proxy">DLOCALE</locale-token>
#define LOCALE(X,Y)     _STR_LOCALE("mod_fs_proxy",X,Y)
#define DLOCALE(X,Y)    _DEF_LOCALE("mod_fs_proxy",X,Y)

LocaleString module_name = DLOCALE(1, "File systems: Proxy File System");
LocaleString module_doc =
  DLOCALE(2, "This module can be used to proxy requests to a path in a site to"
          " a filesystem module in another site. Can be useful if a module "
          "needs to handle the root path for a port, but that module needs to "
          "be loaded in a configuration where it cannot be mounted on the "
          "root path.");

class LocationModuleChoice
{
  inherit Variable.StringChoice;

  array(string) get_choice_list()
  {
    return Array.flatten (map (roxen->configurations,
                               lambda (Configuration conf)
                               {
                                 return map (conf->location_modules(),
                                             lambda (array entry)
                                             {
                                               string loc = entry[0];
                                               function ff = entry[1];
                                               RoxenModule mod =
                                                 Roxen.get_owning_module (ff);
                                               return conf->name + ": " +
                                                 mod->module_local_id();
                                             });
                               }));
  }

  protected void create(string default_value, void|int flags,
			void|LocaleString std_name, void|LocaleString std_doc)
  {
    ::create(default_value, ({}), flags, std_name, std_doc);
  }
}

protected void create (Configuration conf)
{
  defvar ("location",
          Variable.Location ("/", 0,
                             "Location",
                             "The virtual mountpoint for the module."));
  defvar ("location_module",
          LocationModuleChoice ("", 0,
                                "Destination Module",
                                "The module to forward requests to."));
}

protected Configuration get_conf (string conf_name)
{
  mapping(string:Configuration) configurations =
    mkmapping (map (roxen->configurations->name, lower_case),
               roxen->configurations);

  return configurations[lower_case (conf_name)];
}

protected RoxenModule get_mod()
{
  array(string) segments = query ("location_module") / ":";
  if (sizeof (segments) != 2)
    return 0;

  string conf_name = String.trim_all_whites (segments[0]);
  string mod_id = String.trim_all_whites (segments[1]);
  Configuration conf = get_conf (conf_name);
  return conf && conf->find_module (mod_id);
}

mapping(string:mixed)|int(-1..0)|Stdio.File find_file(string path,
						      RequestID id)
{
  RoxenModule mod = get_mod();
  return mod && mod->find_file (path, id);
}

Stat stat_file(string f, RequestID id)
{
  RoxenModule mod = get_mod();
  return mod && mod->stat_file (f, id);
}

array(string) find_dir (string f, RequestID id)
{
  RoxenModule mod = get_mod();
  return mod && mod->find_dir (f, id);
}
