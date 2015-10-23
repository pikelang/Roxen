
// This is a virtual "file-system" for YUI.

inherit "roxen-module://filesystem";

#include <module.h>

//<locale-token project="mod_filesystem">LOCALE</locale-token>
#define LOCALE(X,Y)	_DEF_LOCALE("mod_filesystem",X,Y)
// end of the locale related stuff

#define EXPIRE_TIME 31536000

constant cvs_version = "$Id$";

LocaleString module_name = LOCALE(67,"JavaScript Support: The Yahoo! User "
				    "Interface Library");
LocaleString module_doc =
LOCALE(68,"This sets The Yahoo! User Interface Library (YUI) as a virtual file system "
	 "of your site.");

string module_dir = combine_path(__FILE__, "../");
string yui_root_dir = combine_path(getenv("VARDIR") || "../var", "yui/");

int limit_yui_paths;

void tar_extract(string tar_file, string dest_dir) {
  mixed err = catch {
    Filesystem.Tar(tar_file)->tar->extract("/", dest_dir);
  };
  if (err) {
    report_debug("%s: Extracting tar file %s failed: %O\n.", module_name, tar_file,
		 describe_backtrace(err));
  }
}

void setup_yui() {
  multiset yui_versions = (< >);

  foreach(glob("yui-*.tar",get_dir(module_dir)), string s) {
    string ver;
    sscanf(s, "yui-%s.tar", ver);
    yui_versions[ver] = 1;
  }

  if (!sizeof(yui_versions)) {
    report_debug("%s: No yui distributions found!\n", module_name);
  }
  
  if(!file_stat(yui_root_dir))
    mkdir(yui_root_dir);

  multiset missing_versions =
    yui_versions - (multiset) (get_dir(yui_root_dir) || ({ }) );

  foreach(indices(missing_versions), string ver) {
#ifdef RUN_SELF_TEST
    report_notice("Self-test detected: Skipping extraction of "
		  "YUI version " + ver + ".\n");
#else
    report_notice("Will extract YUI version "+ ver+".\n");
    tar_extract(combine_path(module_dir,"yui-"+ver+".tar"), yui_root_dir);
#endif
  }
}


void start(int when) {
  set("searchpath", yui_root_dir);
  set("no-parse", 1);
  ::start();
  limit_yui_paths = query("limit-yui-paths");
  if(when == 0)
    setup_yui();
}

void set_invisible(string var)
{
  if (Variable.Variable v = getvar(var)) {
    v->set_invisibility_check_callback(
      lambda(RequestID id, Variable.Variable var)
      {
	return 1;
      });
    v->set_flags(v->get_flags() & ~VAR_INITIAL);
  }
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
  mixed m = ::find_file(f,id);

  id->set_response_header ("Cache-Control",
			   sprintf ("public, max-age=%d", EXPIRE_TIME));

  RAISE_CACHE(EXPIRE_TIME);
  return m;
}

void create()
{
  ::create();
  
  defvar("mountpoint", "/yui/", LOCALE(15,"Mount point"),
	 TYPE_LOCATION,
	 LOCALE(16,"Where the module will be mounted in the site's virtual "
		"file system."));

  set("searchpath", yui_root_dir);
  set_invisible("searchpath");
  set_invisible("no-parse");

  defvar("limit-yui-paths", 1, LOCALE(69, "Limit YUI paths"), TYPE_FLAG,
         LOCALE(70, "If set, access is limited to the assets and build directories."));

}

string query_name()
{
  sscanf ((string) module_name, "%*s:%*[ ]%s", string name);
  return name;
}

