// This is a roxen module. Copyright © 1996 - 1998, Idonex AB.
//
// This module is basically the CGI module with some different
// defaults and a new variable, to make it possible to use Frontpage
// with Roxen when using virtual hosting.

string cvs_version = "$Id: fpscript.pike,v 1.3 1998/07/18 22:01:03 neotron Exp $";

// #define FPSCRIPT_DEBUG

#include <module.h>
inherit "modules/scripting/cgi.pike";

mapping my_build_env_vars(string f, object id, string|void path_info)
{
  mapping new = ::my_build_env_vars(f, id, path_info);
#ifdef FPSCRIPT_DEBUG
  werror(sprintf("%O\n", new));
#endif /* FPSCRIPT_DEBUG */
  
  if (QUERY(FrontPagePort))
    new->SERVER_PORT = (string)QUERY(FrontPagePort);

  return new;
}


void create()
{
  ::create();

  defvar("FrontPagePort", 0, "Frontpage: Server Port", TYPE_INT,
	 "If this variable is set (ie not zero) ");
  killvar("mountpoint");
  defvar("mountpoint", "/", "Frontpage: Root Mountpoint", TYPE_LOCATION, 
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

  // We don't need these, and they might confuse poor Frontpage. Might
  // as well disable completely.
  killvar("Enhancements");
  variables->Enhancements = allocate(8);
}


mixed *register_module()
{
  return ({ 
    MODULE_LOCATION|MODULE_FIRST,
    "Frontpage Script support", 
    "This module is an extension to the normal CGI module. "
    "It has different default values for some variables. It also makes "
    "it possible to configure the value of the environment variable "
    "SERVER_PORT. The reason for doing that is that that is how Frontpage "
    "figures out which configuration to use. Without it you wouldn't be able "
    "to use Frontpage and Roxen to do virtual hosting (where many servers "
    "will have the same port number).",  ({}), 1
  });
}

string query_name() 
{ 
  return sprintf("FPScript mounted on <i>%s</i>, Search Path: <i>%s</i>",
		 QUERY(mountpoint), QUERY(searchpath));
}

mixed first_try(object id)
{
#ifdef FPSCRIPT_DEBUG
  werror("FPScript: first_try(%O)\n", id->not_query);
#endif
  int pos;
  if(search(id->not_query, QUERY(mountpoint)) ||
     search(id->not_query, "_vti_bin/") == -1)
    return 0;
  mixed res = ::find_file(id->not_query[strlen(QUERY(mountpoint))..], id);
  if(mappingp(res))
    return res;
  return 0;
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
