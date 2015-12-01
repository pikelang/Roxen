/*
 * This is a roxen module. Copyright © 1997 - 2009, Roxen IS.
 * Implements a restricted filesystem.
 * This filesystem only allows accesses to files that are a prefix of
 * id->misc->home (ie the users home-directory).
 * Usable for eg ftp-servers allowing named ftp.
 *
 * Thanks to Zsolt Varga <redax@agria.hu> for the idea.
 */

inherit "filesystem";

constant cvs_version = "$Id$";

#include <module.h>
#include <roxen.h>

#include <request_trace.h>

//<locale-token project="mod_restrictedfs">_</locale-token>
#define _(X,Y)	_DEF_LOCALE("mod_restrictedfs",X,Y)
// end of the locale related stuff

constant module_type = MODULE_LOCATION;
LocaleString module_name = _(1,"File systems: Restricted file system");
LocaleString module_doc  =
  _(2,"The restricted file system makes a users real home "
    "directory available to her. Useful for FTP sites.");
constant module_unique = 0;

#if constant(system.normalize_path)
#define NORMALIZE_PATH(X)	system.normalize_path(X)
#else /* !constant(system.normalize_path) */
#define NORMALIZE_PATH(X)	(X)
#endif /* constant(system.normalize_path) */

void create()
{
  ::create();
  defvar("remap_home", 0,
	 _(3,"Hide path to the home directory"),
	 TYPE_FLAG|VAR_INITIAL,
	 _(4,"If set, the user's home directory will be available "
	  "as the root of this file system. If not set the user's home "
	  "directory will be available as its normal path, just as on an "
	  "ordinary FTP site."
	  "<p>If the users home directory is <tt>/home/me/</tt> and the "
	  "restricted file system is mounted on <tt>/ftp/</tt> the home "
	  "directory will be available as <tt>/ftp/</tt> if this option is "
	  "set and as <tt>/ftp/home/me/</tt> if it is not set."));
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
  if (query("remap_home")) {
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
  if (query("remap_home")) {
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

// Duplicate of ::real_file(), that uses ::stat_file() instead of
// stat_file(). This fixes [bug 618].
protected string low_real_file(string f, RequestID id)
{
  if (::stat_file(f, id)) {
    catch {
      return NORMALIZE_PATH(decode_path(path + f));
    };
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
  if (query("remap_home")) {
    string res = low_real_file(f = (fix_slashes(home) + f), id);
    TRACE_LEAVE(sprintf("=> %O => %O", f, res));
    return res;
  } else {
    if (!has_prefix("/" + f, home)) {
      TRACE_LEAVE("Bad prefix.");
      return(0);
    }
    string res = low_real_file(f, id);
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
  if (query("remap_home")) {
    mixed res = ::find_file((home = fix_slashes(home)) + f, id);

    // FIXME: Should readjust not_query here if it was modified.

    return res;
  } else {
    if (!has_prefix("/" + f, home)) {
      // Not a prefix, or short.
      return(0);
    }
    return(::find_file(f, id));
  }
}
