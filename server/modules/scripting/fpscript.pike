// This is a roxen module. Copyright © 1996 - 1998, Idonex AB.
//
// This module is basically the CGI module with some different
// defaults and a new variable, to make it possible to use Frontpage
// with Roxen when using virtual hosting.

string cvs_version = "$Id: fpscript.pike,v 1.1 1998/07/15 10:05:28 neotron Exp $";

#include <module.h>
inherit "modules/scripting/cgi.pike";

mapping my_build_env_vars(string f, object id, string|void path_info)
{
  mapping new = ::my_build_env_vars(f, id, path_info);
  werror(sprintf("%O\n", new));
  
  if (QUERY(FrontPagePort))
    new->SERVER_PORT = (string)QUERY(FrontPagePort);

  return new;
}


void create()
{
  ::create();
  defvar("FrontPagePort", 0, "Frontpage Server Port", TYPE_INT,
	 "If this variable is set (ie not zero) ");
  killvar("mountpoint");
  defvar("mountpoint", "/_vti-bin/", "Frontpage Mountpath", TYPE_LOCATION, 
	 "This is where the module will be inserted in the "
	 "namespace of your server. Please note that the default value "
	 "should be what it is, unless you figure out a way to reconfigure "
	 "this in Frontpage as well.");
 
  killvar("searchpath");
  defvar("searchpath", "<SERVER_ROOT>/_vti_bin/", "Search Path", TYPE_DIR,
	 "This is where the module will find the files in the <b>real</b> "
	 "file system. In a normal setup, this would mean the directory "
	 "_vti_bin/ in the same directory as the root is mounted on. ");

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
    MODULE_LOCATION,
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

