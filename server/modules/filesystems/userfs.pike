// This is a roxen module. Copyright © 1996 - 2004, Roxen IS.

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

//<locale-token project="mod_userfs">_</locale-token>
#define _(X,Y)	_DEF_LOCALE("mod_userfs",X,Y)
// end of the locale related stuff

inherit "filesystem" : filesystem;

constant cvs_version="$Id$";
constant module_type = MODULE_LOCATION;
LocaleString module_name = _(1,"File systems: User file system");
LocaleString module_doc  = 
_(2,"A file system that gives access to files in the users' home\n"
"directories.  The users and home directories are found through the\n"
"current authentication module. The files from the home directories are\n"
"mounted either in the virtual file system of the site or as sites of\n"
"their own. So on one server the user Anne's files might be mounted on\n"
"<tt>http://domain.com/home/anne/</tt> while another server might give\n"
"Anne a web site of her own at <tt>http://anne.domain.com/</tt>.\n");
constant module_unique = 0;

#define BAD_PASSWORD(us)	(query("only_password") && \
                                 ((us[1] == "") || (us[1][0] == '*')))

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
  defvar("searchpath", "NONE", _(3,"Search path"), TYPE_DIR|VAR_INITIAL,
	 (0,"This is where the module will find the files in the real "
	  "file system"),
	 0, hide_searchpath);

  set("mountpoint", "/~");

  defvar("only_password", 1, _(4,"Password users only"),
	 TYPE_FLAG|VAR_INITIAL,
         _(5,"Mount only home directories for users with valid passwords."));

  defvar("user_listing", 0, _(6,"Enable userlisting"), TYPE_FLAG|VAR_INITIAL,
	 _(7,"If set a listing of all users will be shown when you access the "
	   "mount point."));

  defvar("banish_list", ({ "root", "daemon", "bin", "sys", "admin",
			   "lp", "smtp", "uucp", "nuucp", "listen",
			   "nobody", "noaccess", "ftp", "news",
			   "postmaster" }), _(8,"Banish list"),
	 TYPE_STRING_LIST, 
	 _(9,"This is a list of users who's home directories will not be "
	   "mounted."));

  defvar("own", 0, _(10,"Only owned files"), TYPE_FLAG,
	 _(11,"If set, only files actually owned by the user will be sent "
	   "from her home directory. This prohibits users from making "
	   "confidental files available by symlinking to them. On the other "
	   "hand it also makes it harder for user to cooperate on projects."));
  
  defvar("virtual_hosting", 0, _(12,"Virtual user hosting"),
	 TYPE_FLAG|VAR_INITIAL,
	 _(13,"If set, each user will get her own site. You access the user's "
	 "with "
	 "<br><tt>http://&lt;user&gt;.domain.com/&lt;mountpoint&gt;</tt> "
	 "<br>instead of "
	 "<br><tt>http://domain.com/&lt;mountpoint&gt;&lt;user&gt;</tt>. "
	 "<p>This means that you normally set the mount point to '/'. "
	 "<p>You need to set up CNAME entries in DNS for all users, or a "
	 "regexp CNAME that matches all users, to get this to "
	 "work."));

  defvar("useuserid", 1, _(14,"Run user scripts as the owner of the script"),
	 TYPE_FLAG|VAR_MORE,
	 _(15,"If set, users' CGI and Pike scripts will be run as the user whos"
	   " home directory the file was found in. This only works if the "
	 " server was started as root."),
	 0, uid_was_zero);

  defvar("pdir", "html/", _(16,"Public directory"),
	 TYPE_STRING|VAR_INITIAL,
         _(17,"This is the directory in the home directory of the users which "
	 "contains the files that will be shown on the web. "
	 "If the module is mounted on <tt>/home/</tt>, the file "
	 "<tt>/home/anne/test.html</tt> is accessed and the home direcory "
	 "of Anne is <tt>/export/users/anne/</tt> the module will fetch "
	 "the file <tt>/export/users/anne/&lt;Public dir&gt;/test.html</tt>."),
	 0, hide_pdir);

  defvar("homedir" ,1,_(18,"Look in users homedir"), TYPE_FLAG|VAR_INITIAL,
	 _(19,"If set, the module will look for the files in the user's home "
	 "directory, according to the <i>Public directory</i> variable. "
	 "Otherwise the files are fetched from a directory with the same "
	 "name as the user in the directory configured in the "
	 "<i>Search path</i> variable." ));
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
  normalized_path="";
  banish_list = mkmultiset(query("banish_list"));
  dude_ok = ([]);
  // This is needed to override the inherited filesystem module start().
}

protected array(string) find_user(string f, RequestID id)
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

protected string low_real_path(string f, RequestID id)
{
  string norm_f;

  [string u, string rel_f] = find_user(f, id);

  if(!u || banish_reported[u]) {
    return 0;
  }

  string dir;
  if (!(dir = dude_ok[u])) {
    array(string) us = id->conf->userinfo( u, id );

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
    if(query("homedir"))
    {
      if(us[5][-1] != '/')
	dir = us[ 5 ] + "/" + encode_path(query("pdir"));
      else
	dir = us[ 5 ] + encode_path(query("pdir"));
    } else
      dir = encode_path(query("searchpath") + u + "/");
    dude_ok[u] = dir;
  }

  // For the benefit of the PHP4 module. Will set the DOCUMENT_ROOT
  // environment variable to this instead of the path to /.
  id->misc->user_document_root = dir;
  norm_f = dir + encode_path(rel_f);

  return norm_f;
}

int|mapping|Stdio.File find_file(string f, RequestID id)
{
  string u;

  USERFS_WERR(sprintf("find_file(%O)", f));

  [u, string rel_f] = find_user(f, id);

  if(!u)
    return -1;

  string norm_f = real_path(f, id);

  if (!norm_f) {
    return 0;
  }

  array(string) us;
  Stdio.Stat stat;

  if(query("own") || query("useuserid"))
  {
    us = id->conf->userinfo( u, id );
    if(!us)
    {
      USERFS_WERR(sprintf("No userinfo for %O!", u));
      return 0;
    }

    stat = file_stat(norm_f);

    if (!stat) {
      USERFS_WERR("File not found.");
      return 0;
    }
    if (stat[5] == (int)us[2]) {
      if(query("useuserid"))
	id->misc->is_user = norm_f;
    } else if (query("own")) {
      USERFS_WERR("File not owned by user.");
      return 0;
    }
  }

  USERFS_WERR(sprintf("Forwarding request to inherited filesystem.", u));
  return filesystem::find_file( f, id );
}

string real_file(string f, RequestID id)
{
  USERFS_WERR(sprintf("real_file(%O, X)", f));

  return ::real_file(f, id);
}

mapping|array find_dir(string f, RequestID id)
{
  USERFS_WERR(sprintf("find_dir(%O, X)", f));

  if (f == "" || f == "/") {
    if (query("user_listing")) {
      array l;
      l = id->conf->userlist(id);

      if(l) return(l - query("banish_list"));
    }
    return 0;
  }

  return filesystem::find_dir(f, id);
}

Stdio.Stat stat_file(string f, RequestID id)
{
  USERFS_WERR(sprintf("stat_file(%O)", f));

  string norm_f = real_path(f, id);

  if (!norm_f) {
    return Stdio.Stat(({ 0, -2, 0, 0, 0, 0, 0 }));
  }

  Stdio.Stat st = file_stat(norm_f);
  if(!st) return 0;
  if(query("own")) {
    [string u, string rel_f] = find_user(f, id);
    if (!u) return 0;
    array(string) us = id->conf->userinfo(u, id);
    if (!us || ((int)us[2] != st[-2])) return 0;
  }
  return st;
}


string query_name()
{
  return "UserFS "+query("mountpoint")+" from "+
    (query("homedir")?"~*/"+query("pdir"):query("searchpath"));
}

string status()
{
  if(sizeof(my_configuration()->user_databases()) == 0)
    return "<font color='&usr.warncolor;'>"+
      _(20,"You need at least one user database module in this virtual server "
	"to resolve your users' homedirectories.")+
      "</font>";
}

mapping query_action_buttons()
{
  if(sizeof(my_configuration()->user_databases()) == 0)
    return ([ _(21,"Add system user database module to server")
	      : add_standard_userdb ]);
  return ([]);
}

void add_standard_userdb()
{
  module_dependencies(my_configuration(), ({ "userdb_system" }) );
}
