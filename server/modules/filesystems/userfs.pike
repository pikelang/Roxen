// This is a roxen module. Copyright © 1996 - 1998, Idonex AB.

// User filesystem. Uses the userdatabase (and thus the system passwd
// database) to find the home-dir of users, and then looks in a
// specified directory in that directory for the files requested.

// Normaly mounted under /~, but / or /users/ would work equally well.
// / is quite useful for IPPs, enabling them to have URLs like
// http://www.hostname.of.provider/customer/.

 

#include <module.h>

inherit "filesystem";

constant cvs_version="$Id: userfs.pike,v 1.30 1998/07/02 07:47:58 neotron Exp $";

// import Array;
// import Stdio;

int uid_was_zero()
{
  return !(getuid() == 0); // Somewhat misnamed function.. :-)
}

int hide_searchpath()
{
  return QUERY(homedir);
}

int hide_pdir()
{
  return !QUERY(homedir);
}

void create()
{
  ::create();
  killvar("searchpath");
  defvar("searchpath", "NONE", "Search path", TYPE_DIR,
	 "This is where the module will find the files in the real "+
	 "file system",
	 0, hide_searchpath);

  set("mountpoint", "/~");
  
  defvar("only_password", 1, "Password users only",
	 TYPE_FLAG, "Only users who have a valid password can be accessed "
	 "through this module");
  
  defvar("banish_list", ({ "root", "daemon", "bin", "sys", "admin", 
			   "lp", "smtp", "uucp", "nuucp", "listen", 
			   "nobody", "noaccess", "ftp", "news", 
			   "postmaster" }), "Banish list",
	 TYPE_STRING_LIST, "None of these users are valid.");
  
  defvar("own", 0, "Only owned files", TYPE_FLAG, 
	 "If set, users can only send files they own through the user "
	 "filesystem. This can be a problem if many users are working "
	 "together with a project, but it will enhance security, since it "
	 "will not be possible to link to some file the user does not own.");

  defvar("virtual_hosting", 0, "Virtual User Hosting", TYPE_FLAG, 
	 "If set, virtual user hosting is enabled. This means that "
	 "the module will look at the \"host\" header to determine "
	 "which users directory to access. If this is set, you access "
	 "the users directory with http://user.domain.com/<mountpath> "
	 "instead of http://user.domain.com/<mountpath>user. To set this up "
	 "you need to add CNAME entries for all your users pointing to the "
	 "IP(s) of this virtual server.");

  defvar("useuserid", 1, "Run user scripts as the owner of the script",
	 TYPE_FLAG|VAR_MORE,
	 "If set, users cgi and pike scripts will be run as the user who "
	 "owns the file, that is, not the actual file, but the user"
	 " in whose dir the file was found. This only works if the server"
	 " was started as root "
	 "(however, it doesn't matter if you changed uid/gid after startup).",
	 0, uid_was_zero);
  
  defvar("pdir", "html/", "Public directory",
	 TYPE_STRING, "This is where the public directory is located. "
	 "If the module is mounted on /~, and the file /~per/foo is "
	 "accessed, and the home-dir of per is /home/per, the module "
	 "will try to file /home/per/&lt;Public dir&gt;/foo.",
	 0, hide_pdir);

  defvar("homedir" ,1, "Look in users homedir", TYPE_FLAG,
	 "If set, the user's files are looked for in the home directory "
	 "of the user, according to the <em>Public directory</em> variable. "
	 "Otherwise, the <em>Search path</em> is used to find a directory "
	 "with the same name as the user.");
}

multiset banish_list;
mapping dude_ok;
multiset banish_reported = (<>);

void start()
{
  ::start();
  // We fix all file names to be absolute before passing them to
  // filesystem.pike
  path="";
  banish_list = mkmultiset(QUERY(banish_list));
  dude_ok = ([]);
  // This is needed to override the inherited filesystem module start().
}

mixed *register_module()
{
  return ({ 
    MODULE_LOCATION, 
    "User Filesystem", 
      "User filesystem. Uses the userdatabase (and thus the system passwd "
      "database) to find the home-dir of users, and then looks in a "
      "specified directory in that directory for the files requested. "
      "<p>Normaly mounted under /~, but / or /users/ would work equally well. "
      " is quite useful for IPPs, enabling them to have URLs like "
      " http://www.hostname.of.provider/customer/. "
    });
}

mixed find_file(string f, object got)
{
  string u, of;
  of=f;

  
  if(QUERY(virtual_hosting)) {
    if(got->misc->host)
    {
      string host = (got->misc->host / ":")[0];
      if(search(host, ".") != -1)
	sscanf(host, "%s.%*s", u);
      else 
	u = host;
      werror(sprintf("find_file: %O\n", u));
    }
  } else {
    if((<"","/">)[f]) return -1;
    if(sscanf(f, "%s/%s", u, f) != 2)
      u=f; f="";
  }
  if(u)
  {
    string *us;
    array st;
    if((f == "") && (strlen(of) && of[-1] != '/'))
    {
      redirects++;
      return http_redirect(got->not_query+"/",got);
    }
    if(!dude_ok[ u ] || f == "")
    {
      us = got->conf->userinfo( u, got );
      // No user, or access denied.
      if(!us ||
	 (QUERY(only_password) && (<"","*">)[us[ 1 ]]) ||
	 banish_list[u])
      {
	if (!banish_reported[u]) {
	  banish_reported[u] = 1;
	  roxen_perror(sprintf("User %s banished (%O)...\n", u, us));
	}
	return 0;
      }

      string dir;

      if (QUERY(homedir))
	dir =  us[ 5 ] + "/" + QUERY(pdir) + "/";
      else
	dir = QUERY(searchpath) + "/" + u + "/";

      dir = replace(dir, "//", "/");

      // If public dir does not exist, or is not a directory 
      st = ::stat_file(dir, got);
      if(!st || st[1] != -2) {
	return 0;	// File not found.
      }
      dude_ok[u] = dir;	// Always '/' terminated.
    }
    f = dude_ok[u] + f;
    if(QUERY(own))
    {
      if (!us) {
	us = got->conf->userinfo( u, got );
      }

      st = ::stat_file(f, got);

      if(!st || (st[5] != (int)(us[2])))
        return 0;
    }
    if(QUERY(useuserid))
      got->misc->is_user = f;
    return ::find_file( f, got );
  }
  return 0;
}

string real_file( mixed f, mixed id )
{
  string u, of;
  if(!strlen(f) || f=="/")
    return 0;

  if(sscanf(f, "%s/%s", u, f) != 2)
  {
    u=f; 
    f="";
  }
  
  if(u)
  {
    array(int) fs;
    if(query("homedir"))
    {
      string *us;
      us = id->conf->userinfo( u, id );
      if ((!us) ||
	  (QUERY(only_password) && (<"","*">)[us[ 1 ]]) ||
	  (banish_list[u])) {
	return 0;
      }
      if(us[5][-1] != '/')
	f = us[ 5 ] + "/" + QUERY(pdir) + f;
      else
	f = us[ 5 ] + QUERY(pdir) + f;
    } else
      f = QUERY(searchpath) + u + "/" + f;

    // Use the inherited stat_file
    fs = ::stat_file( f,id );
    // FIXME: Should probably have a look at this code.
    if (fs && ((fs[1] >= 0) || (fs[1] == -2)))
      return f;
  }
  return 0;
}

array find_dir(string f, object got)
{
  string u, of;
  array l;
  
  if(QUERY(virtual_hosting)) {
    if(got->misc->host)
    {
      string host = (got->misc->host / ":")[0];
      if(search(host, ".") != -1)
	sscanf(host, "%s.%*s", u);
      else 
	u = host;
      werror(sprintf("get_dir: %O\n", u));
    }
  } else {

    if(!strlen(f) || f=="/")
    {
      l=got->conf->userlist(got);
      if(l) return (l - QUERY(banish_list));
      return 0;
    }
    
    if(sscanf(f, "%s/%s", u, f) != 2)
      u=f; f="";
  }
  if(u)
  {
    if(query("homedir"))
    {
      array(string) us;
      us = got->conf->userinfo( u, got );
      if(!us) return 0;
      if(QUERY(only_password) && (<"","*">)[us[ 1 ]])     return 0;
      if(search(QUERY(banish_list), u) != -1)             return 0;
      if(us[5][-1] != '/')
	f = us[ 5 ] + "/" + QUERY(pdir) + f;
      else
	f = us[ 5 ] + QUERY(pdir) + f;
    }
    else
      f = QUERY(searchpath) + u + "/" + f;
    return ::find_dir(f, got);
  }
  return (got->conf->userlist(got) - QUERY(banish_list));
}

mixed stat_file( mixed f, mixed id )
{
  string u, of;

  if(QUERY(virtual_hosting)) {
    if(id->misc->host)
    {
      string host = (id->misc->host / ":")[0];
      if(search(host, ".") != -1)
	sscanf(host, "%s.%*s", u);
      else 
	u = host;
      werror(sprintf("get_dir: %O\n", u));
    }
  } else {
    
    if(!strlen(f) || f=="/")
      return ({ 0, -2, 0, 0, 0, 0, 0, 0, 0, 0 });
    if(sscanf(f, "%s/%s", u, f) != 2)
      u=f; f="";
  }

  if(u)
  {
    array us, st;
    us = id->conf->userinfo( u, id );
    if(query("homedir"))
    {
      if(!us) return 0;
      if(QUERY(only_password) && (<"","*">)[us[ 1 ]])     return 0;
      if(search(QUERY(banish_list), u) != -1)             return 0;
      if(us[5][-1] != '/')
	f = us[ 5 ] + "/" + QUERY(pdir) + f;
      else
	f = us[ 5 ] + QUERY(pdir) + f;
    } else
      f = QUERY(searchpath) + u + "/" + f;
    st = ::stat_file( f,id );
    if(!st) return 0;
    if(QUERY(own) && (int)us[2] != st[-2]) return 0;
    return st;
  }
  return 0;
}



string query_name()
{
  return ("Location: <i>" + QUERY(mountpoint) + "</i>, " +
	  (QUERY(homedir)
	   ? "Pubdir: <i>" + QUERY(pdir) +"</i>"
	   : "mounted from: <i>" + QUERY(searchpath) + "</i>"));
}
