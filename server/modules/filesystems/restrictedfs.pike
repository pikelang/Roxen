/*
 * $Id: restrictedfs.pike,v 1.3 1997/08/08 16:26:23 grubba Exp $
 *
 * $Author: grubba $
 *
 * Implements a restricted filesystem.
 * This filesystem only allows accesses to files that are a prefix of
 * id->misc->home (ie the users home-directory).
 * Usable for eg ftp-servers allowing named ftp.
 *
 * Thanks to Zsolt Varga <redax@agria.hu> for the idea.
 */

constant cvs_version = "$Id: restrictedfs.pike,v 1.3 1997/08/08 16:26:23 grubba Exp $";

#include <module.h>
#include <roxen.h>

import Array;

inherit "filesystem";

mixed *register_module()
{
  return ({ MODULE_LOCATION, "Restricted filesystem", 
	      "This is a restricted filesystem, use it to make users home "
	      "directories available to them if they login.<br>\n"
	      "Usable for eg ftp-servers."
	      });
}

mixed stat_file(string f, object id)
{
  string home = id->misc->home;
  if (!stringp(home)) {
    // No home-directory
    return(0);
  }
  if (search("/" + f, home)) {
    // Not a prefix, or short.
    if ((home[1..sizeof(f)] != f) ||
	((home[sizeof(f)] != '/') && (home[sizeof(f)+1] != '/'))) {
      return(0);
    }
    // Short.
  }
  return(::stat_file(f, id));
}

array find_dir(string f, object id)
{
  string home = id->misc->home;
  if (!stringp(home)) {
    // No home-directory
    return(0);
  }
  if (search("/" + f, home)) {
    // Not a prefix, or short
    if (home[1..sizeof(f)] == f) {
      // Short - return the next part of the path.
      return(filter(({ ".", "..", (home[sizeof(f)+1..]/"/")[0] }),
		    dir_filter_function));
    }
  }
  return(::find_dir(f, id));
}

mixed find_file(string f, object id)
{
  string home = id->misc->home;
  if (!stringp(home)) {
    // No home-directory
    return(0);
  }
  if (search("/" + f, home)) {
    // Not a prefix, or short.
    return(0);
  }
  return(::find_file(f, id));
}
