// This is a roxen module. Copyright © 1996 - 1998, Idonex AB.
//
// This module is basically the CGI module with some different
// defaults and a new variable, to make it possible to use Frontpage
// with Roxen when using virtual hosting.

// #define FPSCRIPT_DEBUG

#include <module.h>
inherit "modules/scripting/cgi.pike";

constant cvs_version = "$Id: fpscript.pike,v 1.5 1999/04/24 23:40:57 marcus Exp $";

mapping build_env_vars(string f, object id, string|void path_info)
{
  mapping new = ::build_env_vars(f, id, path_info);
#ifdef FPSCRIPT_DEBUG
  werror(sprintf("%O\n", new));
#endif /* FPSCRIPT_DEBUG */
  
  if (QUERY(FrontPagePort))
    new->SERVER_PORT = (string)QUERY(FrontPagePort);

  return new;
}


void create(object conf)
{
  ::create(conf);

  defvar("FrontPagePort", 0, "Frontpage: Server Port", TYPE_INT,
	 "If this variable is set (ie not zero) ");
  killvar("location");
  defvar("location", "/", "Frontpage: Root Mountpoint", TYPE_LOCATION, 
	 "This is where the module will be inserted in the "
	 "namespace of your server. In most cases this should be the root "
	 "file system. This module will only answer to requests if the "
	 "url has vti_bin in it. Some examples:<pre>\n"
	 "	/cgi-bin/         		Ignored.\n"
	 "	/_vti_bin/ 			Handled.\n"
	 "	/index.html 			Ignored.\n"
	 "	/mysubweb/_vti_bin/		Handled.\n</pre>"
	 "As you can see the only time you would want to change this is "
	 "if you don't want the root _vti_bin to be handled.");
 
  killvar("searchpath");
  defvar("searchpath", "<DOCUMENT ROOT>", "Frontpage: Document Root",
	 TYPE_DIR,
	 "This is where the module will find the files in the <b>real</b> "
	 "file system. In a normal setup, this would mean the same directory "
	 "as the root filesystem is mounted from.");

  killvar("ex");
  killvar("ext");
}


mixed *register_module()
{
  return ({ 
    MODULE_LOCATION,
    "Frontpage Script support", 
    "This module is an extension to the normal CGI module. The main "
    "differences are that this module is mainly a MODULE_FIRST. The reason "
    "for this is that otherwise you most likely would have to fight with "
    "priority levels to make it work correctly. It's there to make the setup "
    "procedure easier. Also this module's default mountpath is <tt>/<tt>. The "
    "reason for this is that we need to be able to handle Frontpage sub-webs. "
    "<p>Another feature is that you easily can modify the value of the "
    "environment variable SERVER_PORT. The reason for doing that is that "
    "Frontpage uses it to figure out which configuration file to use. "
    "Without it you wouldn't be able to use Frontpage and Roxen when doing "
    "virtual hosting (where many servers will have the same port number).",
    ({}), 1
  });
}

string query_name() 
{ 
  return sprintf("FPScript mounted on <i>%s</i>, Search Path: <i>%s</i>",
		 QUERY(location), QUERY(searchpath));
}

mixed find_file(string f, object id)
{
#ifdef FPSCRIPT_DEBUG
  werror("FPScript: find_file(%O)\n", f);
#endif
  if(search(f, "_vti_bin/") == -1)
    return 0;
  return ::find_file(f, id);
}

array find_dir(string f, object id) 
{
#ifdef FPSCRIPT_DEBUG
  werror("FPScript: find_dir(%O)\n", f);
#endif
  if(search(f, "_vti_bin/") == -1)
    return 0;
  return ::find_dir(f, id);
}
