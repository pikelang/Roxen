// This is a roxen module. Copyright © 1998 - 2009, Roxen IS.
//
// This module is basically the CGI module with some different
// defaults and a new variable, to make it possible to use Frontpage
// with Roxen when using virtual hosting.

constant cvs_version = "$Id$";

#include <module.h>
inherit "modules/scripting/cgi.pike";

void create(Configuration c)
{
  ::create(c);

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
	 TYPE_DIR|VAR_INITIAL,
	 "This is where the module will find the files in the <b>real</b> "
	 "file system. In a normal setup, this would mean the same directory "
	 "as the root filesystem is mounted from.");

  killvar("ex");
  killvar("ext");
  killvar("cgi_tag");
}

void start() {
  if (query("FrontPagePort"))
    global_env->SERVER_PORT = (string)query("FrontPagePort");
}

constant module_type = MODULE_LOCATION | MODULE_DEPRECATED;
constant module_name = "Frontpage Script support";
constant module_doc  = "This module is an extension to the normal CGI module. "
  "This module's default mountpoint is <tt>/</tt>. "
  "The "
  "reason for this is that we need to be able to handle Frontpage sub-webs. "
  "<p>Another feature is that you easily can modify the value of the "
  "environment variable SERVER_PORT. The reason for doing that is that "
  "Frontpage uses it to figure out which configuration file to use. "
  "Without it you wouldn't be able to use Frontpage and Roxen when doing "
  "virtual hosting (where many servers will have the same port number).</p>";

int|object(Stdio.File)|mapping find_file(string f, RequestID id)
{
#ifdef FPSCRIPT_DEBUG
  werror("FPScript: find_file(%O)\n", f);
#endif
  if(search(f, "_vti_bin/") == -1)
    return 0;
  return ::find_file(f, id);
}

array(string) find_dir(string f, RequestID id)
{
#ifdef FPSCRIPT_DEBUG
  werror("FPScript: find_dir(%O)\n", f);
#endif
  if(search(f, "_vti_bin/") == -1)
    return 0;
  return ::find_dir(f, id);
}
