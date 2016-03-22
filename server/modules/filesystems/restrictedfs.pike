/*
 * This is a roxen module. Copyright © 1997 - 2004, Roxen IS.
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

protected string fix_slashes (string s)
{
  if (sizeof (s) && s[0] == '/') {
    s = s[1..];
  }
  if (sizeof (s) && s[-1] != '/') {
    s += "/";
  }
  return s;
}

protected string low_real_path(string f, RequestID id)
{
  string home = id->misc->home;
  if (!stringp(home)) {
    // No home-directory
    return 0;
  }
  if (query("remap_home")) {
    f = decode_path(fix_slashes(home)) + f;
  } else if (!has_prefix("/" + f, decode_path(home))) {
    // Not a prefix, or short.
    return 0;
  }
  return ::low_real_path(f, id);
}

mixed stat_file(string f, object id)
{
  TRACE_ENTER("stat_file(\"" + f + "\")", 0);
  mixed res = ::stat_file(f, id);
  TRACE_LEAVE(sprintf(" => %O => %O", f, res));
  return res;
}

array find_dir(string f, object id)
{
  string home = id->misc->home;
  if (!stringp(home)) {
    // No home-directory
    return 0;
  }
  string enc_f = "/" + encode_path(f);
  if (!has_suffix(enc_f, "/")) enc_f += "/";
  if (!query("remap_home") && !has_prefix(enc_f, home)) {
    // Not a prefix, or short
    if (!has_prefix(home, enc_f)) return 0;
    // Short - return the next part of the path.
    f = decode_path((home[sizeof(enc_f)..]/"/" - ({ "" }))[0]);
    return Array.filter(({ ".", "..", f }), dir_filter_function);
  }
  return ::find_dir(f, id);
}

string real_file(string f, object id)
{
  string home = id->misc->home;
  TRACE_ENTER("real_file(\"" + f + "\")", 0);
  string res = ::real_file(f, id);
  TRACE_LEAVE(sprintf("=> %O => %O", f, res));
  return res;
}

mixed find_file(string f, object id)
{
  return(::find_file(f, id));
}
