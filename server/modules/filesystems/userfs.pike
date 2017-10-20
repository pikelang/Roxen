// This is a roxen module. Copyright © 1996 - 2000, Roxen IS.

// User filesystem. Uses the userdatabase (and thus the system passwd
// database) to find the home-dir of users, and then looks in a
// specified directory in that directory for the files requested.

// Normaly mounted under /~, but / or /users/ would work equally well.
// / is quite useful for IPPs, enabling them to have URLs like
// http://www.hostname.of.provider/customer/.

// #define USERFS_DEBUG

#ifdef USERFS_DEBUG
# define USERFS_WERR(X) werror("USERFS: "+X+"\n")
#else
# define USERFS_WERR(X)
#endif

#include <module.h>

inherit "filesystem" : filesystem;

constant cvs_version="$Id$";
constant module_type = MODULE_LOCATION;
constant module_name = "User file system";
constant module_doc  = 
#"A file system that gives access to files in the users' home
directories.  The users and home directories are found through the
current authentication module. The files from the home directories are
mounted either in the virtual file system of the site or as sites of
their own. So on one server the user Anne's files might be mounted on
<tt>http://domain.com/home/anne/</tt> while another server might give
Anne a web site of her own at <tt>http://anne.domain.com/</tt>.\n";
constant module_unique = 0;

// NB: MySQL 4.1 and later prefix hashes from their internal
//     password hashing function with a single "*". cf [bug 7834].
#define BAD_PASSWORD(us)	(query("only_password") && \
                                 ((us[1] == "") || \
				  ((us[1][0] == '*') && (us[1][-1] == '*'))))

int uid_was_zero()
{
  return !(getuid() == 0); // Somewhat misnamed function.. :-)
}

int hide_searchpath()
{
  return query("homedir");
}

int hide_pdir()
{
  return !query("homedir");
}

void create()
{
  filesystem::create();
  killvar("searchpath");
  defvar("searchpath", "NONE", "Search path", TYPE_DIR|VAR_INITIAL,
	 "This is where the module will find the files in the real "+
	 "file system",
	 0, hide_searchpath);

  set("mountpoint", "/home/");

  defvar("only_password", 1, "Password users only",
	 TYPE_FLAG|VAR_INITIAL,
         "Mount only home directories for users who has valid passwords.");

  defvar("user_listing", 0, "Enable userlisting", TYPE_FLAG|VAR_INITIAL,
	 "If set a listing of all users will be shown when you access the "
	 "mount point.");

  defvar("banish_list", ({ "root", "daemon", "bin", "sys", "admin",
			   "lp", "smtp", "uucp", "nuucp", "listen",
			   "nobody", "noaccess", "ftp", "news",
			   "postmaster" }), "Banish list",
	 TYPE_STRING_LIST, 
	 "This is a list of users who's home directories will not be "
	 "mounted.");

  defvar("own", 0, "Only owned files", TYPE_FLAG,
	 "If set, only files actually owned by the user will be sent "
	 "from her home directory. This prohibits users from making "
	 "confidental files available by symlinking to them. On the other "
	 "hand it also makes it harder for user to cooperate on projects.");

  defvar("virtual_hosting", 0, "Virtual user hosting", TYPE_FLAG|VAR_INITIAL,
	 "If set, each user will get her own site. You access the user's "
	 "with "
	 "<br><tt>http://&lt;user&gt;.domain.com/&lt;mountpoint&gt;</tt> "
	 "<br>instead of "
	 "<br><tt>http://domain.com/&lt;mountpoint&gt;&lt;user&gt;</tt>. "
	 "<p>This means that you normally set the mount point to '/'. "
	 "<p>You need to set up CNAME entries in DNS for all users, or a "
	 "regexp CNAME that matches all users, to get this to "
	 "work.");

  defvar("useuserid", 1, "Run user scripts as the owner of the script",
	 TYPE_FLAG|VAR_MORE,
	 "If set, users' CGI and Pike scripts will be run as the user whos "
	 "home directory the file was found in. This only works if the server "
	 "was started as root.",
	 0, uid_was_zero);

  defvar("pdir", "html/", "Public directory",
	 TYPE_STRING|VAR_INITIAL,
         "This is the directory in the home directory of the users which "
	 "contains the files that will be shown on the web. "
	 "If the module is mounted on <tt>/home/</tt>, the file "
	 "<tt>/home/anne/test.html</tt> is accessed and the home direcory "
	 "of Anne is <tt>/export/users/anne/</tt> the module will fetch "
	 "the file <tt>/export/users/anne/&lt;Public dir&gt;/test.html</tt>.",
	 0, hide_pdir);

  defvar("homedir" ,1, "Look in users homedir", TYPE_FLAG|VAR_INITIAL,
	 "If set, the module will look for the files in the user's home "
	 "directory, according to the <i>Public directory</i> variable. "
	 "Otherwise the files are fetched from a directory with the same "
	 "name as the user in the directory configured in the "
	 "<i>Search path</i> variable." );
}

multiset banish_list;
mapping dude_ok;
multiset banish_reported = (<>);

void start()
{
  filesystem::start();
  // We fix all file names to be absolute before passing them to
  // filesystem.pike
  path="";
  banish_list = mkmultiset(query("banish_list"));
  dude_ok = ([]);
  // This is needed to override the inherited filesystem module start().
}

static array(string) find_user(string f, RequestID id)
{
  string of = f;
  string u;

  if(query("virtual_hosting")) {
    NOCACHE();
    if(id->misc->host) {
      string host = (id->misc->host / ":")[0];
      if(search(host, ".") != -1) {
	sscanf(host, "%s.%*s", u);
      } else {
	u = host;
      }
    }
  } else {
    if((<"", "/", ".">)[f])
      return ({ 0, 0 });

    switch(sscanf(f, "%*[/]%s/%s", u, f)) {
    case 1:
      sscanf(f, "%*[/]%s", u);
      f = "";
      break;
    default:
      u="";
      // FALL_THROUGH
    case 2:
      f = "";
      // FALL_THROUGH
    case 3:
      break;
    }
  }

  USERFS_WERR(sprintf("find_user(%O) => u:%O, f:%O", of, u, f));

  return ({ u, f });
}

int|mapping|Stdio.File find_file(string f, RequestID id)
{
  string u, of = f;

  USERFS_WERR(sprintf("find_file(%O)", f));

  [u, f] = find_user(f, id);

  if(!u)
    return -1;

  array(string) us;
  array(int) stat;

  if(!dude_ok[ u ] || f == "")
  {
    us = id->conf->userinfo( u, id );

    USERFS_WERR(sprintf("checking out %O: %O", u, us));

    if(!us || BAD_PASSWORD(us) || banish_list[u])
    { // No user, or access denied.
      USERFS_WERR(sprintf("Bad password: %O? Banished? %O",
			  (us?BAD_PASSWORD(us):1),
			  banish_list[u]));
      if(!banish_reported[u])
      {
	banish_reported[u] = 1;
	USERFS_WERR(sprintf("User %s banished (%O)...\n", u, us));
      }
      return 0;
    }
    if((f == "") && (strlen(of) && of[-1] != '/'))
    {
      redirects++;
      return Roxen.http_redirect(id->not_query+"/",id);
    }

    string dir;

    if(query("homedir"))
      dir = us[ 5 ] + "/" + query("pdir") + "/";
    else
      dir = query("searchpath") + "/" + u + "/";

    dir = replace(dir, "//", "/");

    // If public dir does not exist, or is not a directory
    stat = filesystem::stat_file(dir, id);
    if(!stat || stat[1] != -2)
    {
      USERFS_WERR(sprintf("Directory %O not found! (stat: %O)", dir, stat));
      return 0;	// File not found.
    }
    dude_ok[u] = dir;	// Always '/' terminated.
  }
  // For the benefit of the PHP4 module. Will set the DOCUMENT_ROOT
  // environment variable to this instead of the path to /.
  id->misc->user_document_root = dude_ok[u];
  
  f = dude_ok[u] + f;

  if(query("own"))
  {
    if(!us)
    {
      us = id->conf->userinfo( u, id );
      if(!us)
      {
	USERFS_WERR(sprintf("No userinfo for %O!", u));
	return 0;
      }
    }

    stat = filesystem::stat_file(f, id);

    if(!stat || (stat[5] != (int)(us[2])))
    {
      USERFS_WERR(sprintf("File not owned by user.", u));
      return 0;
    }
  }

  if(query("useuserid"))
    id->misc->is_user = f;

  USERFS_WERR(sprintf("Forwarding request to inherited filesystem.", u));
  return filesystem::find_file( f, id );
}

string real_file(string f, RequestID id)
{
  string u;

  USERFS_WERR(sprintf("real_file(%O, X)", f));

  array a = find_user(f, id);

  if (!a) {
    return 0;
  }

  u = a[0];
  f = a[1];

  if(u)
  {
    array(int) fs;
    if(query("homedir"))
    {
      array(string) us;
      us = id->conf->userinfo( u, id );
      if((!us) || BAD_PASSWORD(us) || banish_list[u])
	return 0;
      if(us[5][-1] != '/')
	f = us[ 5 ] + "/" + query("pdir") + f;
      else
	f = us[ 5 ] + query("pdir") + f;
    } else
      f = query("searchpath") + u + "/" + f;

    // Use the inherited stat_file
    fs = filesystem::stat_file( f,id );

    //    werror(sprintf("%O: %O\n", f, fs));
    // FIXME: Should probably have a look at this code.
    if (fs && ((fs[1] >= 0) || (fs[1] == -2)))
      return f;
  }
  return 0;
}

mapping|array find_dir(string f, RequestID id)
{
  USERFS_WERR(sprintf("find_dir(%O, X)", f));

  array a = find_user(f, id);

  if (!a) {
    if (query("user_listing")) {
      array l;
      l = id->conf->userlist(id);

      if(l) return(l - query("banish_list"));
    }
    return 0;
  }

  string u = a[0];
  f = a[1];

  if(u)
  {
    if(query("homedir"))
    {
      array(string) us;
      us = id->conf->userinfo( u, id );
      if((!us) || BAD_PASSWORD(us))
	return 0;
      // FIXME: Use the banish multiset.
      if(search(query("banish_list"), u) != -1)             return 0;
      if(us[5][-1] != '/')
	f = us[ 5 ] + "/" + query("pdir") + f;
      else
	f = us[ 5 ] + query("pdir") + f;
    }
    else
      f = query("searchpath") + u + "/" + f;
    array dir = filesystem::find_dir(f, id);
    return dir;
  }
  array(string) users = id->conf->userlist(id);
  return users && (users - query("banish_list"));
}

array(int) stat_file(string f, RequestID id)
{
  USERFS_WERR(sprintf("stat_file(%O)", f));

  array a = find_user(f, id);

  if (!a) {
    return ({ 0, -2, 0, 0, 0, 0, 0, 0, 0, 0 });
  }

  string u = a[0];
  f = a[1];

  if(u)
  {
    array us, st;
    us = id->conf->userinfo( u, id );
    if(query("homedir"))
    {
      if((!us) || BAD_PASSWORD(us))
	return 0;
      // FIXME: Use the banish multiset.
      if(search(query("banish_list"), u) != -1) return 0;
      if(us[5] == "") {
	// No home directory.
	return 0;
      }
      if(us[5][-1] != '/')
	f = us[ 5 ] + "/" + query("pdir") + f;
      else
	f = us[ 5 ] + query("pdir") + f;
    } else
      f = query("searchpath") + u + "/" + f;
    st = filesystem::stat_file( f,id );
    if(!st) return 0;
    if(query("own") && (!us || ((int)us[2] != st[-2]))) return 0;
    return st;
  }
  return 0;
}

string query_name()
{
  return "Location: <i>" + query("mountpoint") + "</i>, " +
	 (query("homedir")
	  ? "Pubdir: <i>" + query("pdir") +"</i>"
	  : "mounted from: <i>" + query("searchpath") + "</i>");
}

string status()
{
  if(!my_configuration()->auth_module)
    return "<font color='red'>You need an <i>authentication / user "
	   "database</i> module in this virtual server to resolve "
	   "your users' homedirectories.</font>";
}

mapping query_action_buttons()
{
  if(!my_configuration()->auth_module)
    return ([ "Add standard user database module to server"
	      : add_standard_userdb ]);
  return ([]);
}

void add_standard_userdb()
{
  module_dependencies(my_configuration(), ({ "userdb" }) );
}
