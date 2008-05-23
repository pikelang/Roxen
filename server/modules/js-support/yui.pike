
// This is a virtual "file-system" for YUI.

inherit "roxen-module://filesystem";

#include <module.h>

//<locale-token project="mod_filesystem">LOCALE</locale-token>
#define LOCALE(X,Y)	_DEF_LOCALE("mod_filesystem",X,Y)
// end of the locale related stuff

LocaleString module_name = LOCALE(0,"JavaScript support modules: The Yahoo! User "
				    "Interface Library");
LocaleString module_doc =
LOCALE(0,"This sets The Yahoo! User Interface Library (YUI) as a virtual file system "
	 "of your site.");

string module_dir = combine_path(__FILE__, "../");
string yui_root_dir = (getenv("VARDIR") || "../var") +"/yui/";

int limit_yui_paths;

void tar_extract(string tar_file, string dest_dir) {
  object fs = Filesystem.Tar(tar_file);
  array files = fs->find();

  foreach(files, Stdio.Stat s) {
    if(s->isdir())
      Stdio.mkdirhier(yui_root_dir+s->fullpath);
    else if(s->isreg()) 
      Stdio.write_file(yui_root_dir+s->fullpath, fs->open(s->fullpath,"r")->read());
  }
}

void setup_yui() {
  multiset yui_versions = (< >);

  foreach(glob("yui-*.tar",get_dir(module_dir)), string s) {
    string ver;
    sscanf(s, "yui-%s.tar", ver);
    yui_versions[ver] = 1;
  }
  
  if(!file_stat(yui_root_dir))
    mkdir(yui_root_dir);

  multiset missing_versions = yui_versions - (multiset)get_dir(yui_root_dir);

  foreach(indices(missing_versions), string ver) {
    report_notice("Will extraxt YUI version "+ ver+".\n");
    tar_extract(combine_path(module_dir,"yui-"+ver+".tar"), yui_root_dir);
  }


}


void start(int when) {
  werror("when: %O\n", when);
  set("searchpath", yui_root_dir);
  ::start();
  limit_yui_paths = query("limit-yui-paths");
  if(when == 0)
    setup_yui();
}

void set_invisible(string var)
{
  getvar(var) && getvar(var)->
    set_invisibility_check_callback(
      lambda(RequestID id, Variable.Variable var)
      {
	return 1;
      });
}


int is_hidden(string s) {
  if(limit_yui_paths) {
    array path = s/"/";
    if(sizeof(path) > 1 && !(< "assets","build">)[path[1]])
      return 1;
  }
  return 0;
}

mixed stat_file( string f, RequestID id )
{
  if(is_hidden(f))
    return 0;
  return ::stat_file(f,id);
}

mixed find_file( string f, RequestID id )
{
  if(is_hidden(f))
    return 0;
  return ::find_file(f,id);
}

void create()
{
  ::create();
  
  defvar("mountpoint", "/yui/", LOCALE(0,"Mount point"),
	 TYPE_LOCATION,
	 LOCALE(0,"Where the module will be mounted in the site's virtual "
		"file system."));

  set("searchpath", yui_root_dir);
  set_invisible("searchpath");


  defvar("limit-yui-paths", 1, LOCALE(0, "Limit YUI paths"), TYPE_FLAG,
         LOCALE(0, "If set, access is limited to the assets and build directories."));

}

string query_name()
{
  sscanf ((string) module_name, "%*s:%*[ ]%s", string name);
  return name;
}

