/*
 * $Id: restrictedfs.pike,v 1.6 1997/08/31 03:47:20 peter Exp $
 *
 * $Author: peter $
 *
 * Implements a restricted filesystem.
 * This filesystem only allows accesses to files that are a prefix of
 * id->misc->home (ie the users home-directory).
 * Usable for eg ftp-servers allowing named ftp.
 *
 * Thanks to Zsolt Varga <redax@agria.hu> for the idea.
 */

inherit "filesystem";

string cvs_version = "$Id: restrictedfs.pike,v 1.6 1997/08/31 03:47:20 peter Exp $";

#include <module.h>
#include <roxen.h>

import Array;

mixed *register_module()
{
  return ({ MODULE_LOCATION, "Restricted filesystem", 
	      "This is a restricted filesystem, use it to make users home "
	      "directories available to them if they login.<br>\n"
	      "Usable for eg ftp-servers."
	      });
}

void create()
{
  ::create();
  defvar("remap_home", 0, "Hide path to the home-directory",
	 TYPE_FLAG, "Hides the path to the homedirectory if enabled.<br>\n"
	 "E.g.<br>\n<ul>\n"
	 "If the user <i>foo</i> has the homedirectory <i>/home/foo</i> and "
	 "this is enabled, he will see his files in <b>/</b>.<br>\n"
	 "If this is not enabled, he would see them in <b>/home/foo</b>\n"
	 "</ul>\n");
}

mixed stat_file(string f, object id)
{
  string home = id->misc->home;
  if (!stringp(home)) {
    // No home-directory
    return(0);
  }
  if (QUERY(remap_home)) {
    if (home[0] == '/') {
      home = home[1..];
    }
    if (home[-1] != '/') {
      home += "/";
    }
    return(::stat_file(home + f, id));
  } else {
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
}

array find_dir(string f, object id)
{
  string home = id->misc->home;
  if (!stringp(home)) {
    // No home-directory
    return(0);
  }
  if (QUERY(remap_home)) {
    if (home[0] == '/') {
      home = home[1..];
    }
    if (home[-1] != '/') {
      home += "/";
    }
    return(::find_dir(home + f, id));
  } else {
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
}

mixed find_file(string f, object id)
{
  string home = id->misc->home;
  if (!stringp(home)) {
    // No home-directory
    return(0);
  }
  if (QUERY(remap_home)) {
    if (home[0] == '/') {
      home = home[1..];
    }
    if (home[-1] != '/') {
      home += "/";
    }
    return(::find_file(home + f, id));
  } else {
    if (search("/" + f, home)) {
      // Not a prefix, or short.
      return(0);
    }
    return(::find_file(f, id));
  }
}
