/*
 * This is a roxen module. Copyright © 1997 - 2000, Roxen IS.
 * Implements a restricted filesystem.
 * This filesystem only allows accesses to files that are a prefix of
 * id->misc->home (ie the users home-directory).
 * Usable for eg ftp-servers allowing named ftp.
 *
 * Thanks to Zsolt Varga <redax@agria.hu> for the idea.
 */

inherit "filesystem";

constant cvs_version = "$Id: restrictedfs.pike,v 1.16 2000/12/29 15:09:19 grubba Exp $";

#include <module.h>
#include <roxen.h>

#include <request_trace.h>

// import Array;

constant module_type = MODULE_LOCATION;
constant module_name = "Restricted file system";
constant module_doc  = "The restricted file system makes a users home "
"directory available to her. Very usable for FTP sites.";
constant module_unique = 0;

void create()
{
  ::create();
  defvar("remap_home", 0, "Hide path to the home directory",
	 TYPE_FLAG|VAR_INITIAL,
	 "If set, the user's home directory will be available "
	 "as the root of this file system. If not set the user's home "
	 "directory will be available as its normal path, just as on an "
	 "ordinary FTP site."
	 "<p>If the users home directory is <tt>/home/me/</tt> and the "
	 "restricted file system is mounted on <tt>/ftp/</tt> the home "
	 "directory will be available as <tt>/ftp/</tt> if this option is "
	 "set and as <tt>/ftp/home/me/</tt> if it is not set.");
}

string fix_slashes (string s)
{
  if (sizeof (s) && s[0] == '/') {
    s = s[1..];
  }
  if (sizeof (s) && s[-1] != '/') {
    s += "/";
  }
  return s;
}

mixed stat_file(string f, object id)
{
  TRACE_ENTER("stat_file(\"" + f + "\")", 0);
  string home = id->misc->home;
  if (!stringp(home)) {
    // No home-directory
    TRACE_LEAVE("No home directory.");
    return(0);
  }
  if (QUERY(remap_home)) {
    mixed res = ::stat_file(f = (fix_slashes (home) + f), id);
    TRACE_LEAVE(sprintf(" => %O => %O", f, res));
    return res;
  } else {
    if (search("/" + f, home)) {
      // Not a prefix, or short.
      if ((home[1..sizeof(f)] != f) ||
	  ((home[sizeof(f)] != '/') && (home[sizeof(f)+1] != '/'))) {
	TRACE_LEAVE("Bad prefix.");
	return(0);
      }
      // Short.
    }
    mixed res = ::stat_file(f, id);
    TRACE_LEAVE(sprintf(" => %O => %O", f, res));
    return res;
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
    return(::find_dir(fix_slashes (home) + f, id));
  } else {
    if (search("/" + f, home)) {
      // Not a prefix, or short
      if (home[1..sizeof(f)] == f) {
	// Short - return the next part of the path.
	return(Array.filter(({ ".", "..", (home[sizeof(f)+1..]/"/")[0] }),
		      dir_filter_function));
      }
    }
    return(::find_dir(f, id));
  }
}

string real_file(string f, object id)
{
  string home = id->misc->home;
  TRACE_ENTER("real_file(\"" + f + "\")", 0);
  if (!stringp(home)) {
    // No home-directory
    TRACE_LEAVE("No home directory.");
    return(0);
  }
  if (QUERY(remap_home)) {
    string res = ::real_file(f = (fix_slashes(home) + f), id);
    TRACE_LEAVE(sprintf("=> %O => %O", f, res));
    return res;
  } else {
    if (!has_prefix("/" + f, home)) {
      TRACE_LEAVE("Bad prefix.");
      return(0);
    }
    string res = ::real_file(f, id);
    TRACE_LEAVE(sprintf("=> %O => %O", f, res));
    return res;
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
    return(::find_file(fix_slashes (home) + f, id));
  } else {
    if (!has_prefix("/" + f, home)) {
      // Not a prefix, or short.
      return(0);
    }
    return(::find_file(f, id));
  }
}
