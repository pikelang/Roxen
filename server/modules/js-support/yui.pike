
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

string yui_root_dir = combine_path(__FILE__, "../yui/");

void set_invisible(string var)
{
  getvar(var) && getvar(var)->
    set_invisibility_check_callback(
      lambda(RequestID id, Variable.Variable var)
      {
	return 1;
      });
}

void create()
{
  ::create();
  
  defvar("mountpoint", "/yui/", LOCALE(0,"Mount point"),
	 TYPE_LOCATION|VAR_INITIAL|VAR_NO_DEFAULT,
	 LOCALE(0,"Where the module will be mounted in the site's virtual "
		"file system."));

  set("searchpath", yui_root_dir);
  set_invisible("searchpath");
}

string query_name()
{
 return (string)LOCALE(0,"YUI");
}

