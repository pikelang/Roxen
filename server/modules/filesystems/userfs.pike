// This is a roxen module. (c) Informationsvävarna AB 1996.

// User filesystem. Uses the userdatabase (and thus the system passwd
// database) to find the home-dir of users, and then looks in a
// specified directory in that directory for the files requested.

// Normaly mounted under /~, but / or /users/ would work equally well.
// / is quite useful for IPPs, enabling them to have URLs like
// http://www.hostname.of.provider/customer/.

 

#include <module.h>

inherit "filesystem";

constant cvs_version="$Id: userfs.pike,v 1.17 1998/02/04 16:10:44 per Exp $";

import Array;
import Stdio;

int uid_was_zero()
{
  return !(getuid() == 0); // Somewhat misnamed function.. :-)
}

void create()
{
  ::create();
  killvar("searchpath");
  
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
	 "will try to file /home/per/&lt;Public dir&gt;/foo.");
}

void start()
{
  path="";
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

  if(!roxen->userlist(got))
    return http_string_answer("There is no user database module activated.\n");
  
  if(f=="/" || !strlen(f)) return -1;
  
  if(sscanf(f, "%s/%s", u, f) != 2)
  {
    u=f; f="";
  }

  if(u)
  {
    string *us;
    array st;
    if(!strlen(f) && of[-1] != '/')
    {
      redirects++;
      return http_redirect(got->not_query+"/",got);
    }
    us = roxen->userinfo( u, got );
    // No user, or access denied.
    if(!us
       || (QUERY(only_password) && (<"","*">)[us[ 1 ]])
       || (search( QUERY(banish_list), u ) != -1))
      return 0;

    if(us[5][-1] != '/')
	f = us[ 5 ] + "/" + QUERY(pdir) + f;
    else	
      f = us[ 5 ] + QUERY(pdir) + f;

    //  if public dir is not a directory 
    if(!strlen(f)) {
      st = file_stat(f);
      if(!st || st[1] != -2)
	return 0;
    }

    if(QUERY(own))
    {
      st = file_stat(f);
      if(!st || (st[-2] != (int)us[2])) 
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
  if(!strlen(f) || f=='/')
    return 0;

  if(sscanf(f, "%s/%s", u, f) != 2)
  {
    u=f; 
    f="";
  }
  
  if(u)
  {
    string *us;
    array(int) fs;
    us = roxen->userinfo( u, id );
    if(!us) return 0;
    if(QUERY(only_password) && (<"","*">)[us[ 1 ]])     return 0;
    if(search(QUERY(banish_list), u) != -1)             return 0;
    if(us[5][-1] != '/')
      f = us[ 5 ] + "/" + QUERY(pdir) + f;
    else
      f = us[ 5 ] + QUERY(pdir) + f;

    fs = file_stat( f );
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

  if(!strlen(f) || f=='/')
  {
    l=roxen->userlist(got);
    if(l) return (l - QUERY(banish_list));
    return 0;
  }

  if(sscanf(f, "%s/%s", u, f) != 2)
  {
    u=f; f="";
  }

  if(u)
  {
    string *us;
    us = roxen->userinfo( u, got );
    if(!us) return 0;
    if(QUERY(only_password) && (<"","*">)[us[ 1 ]])     return 0;
    if(search(QUERY(banish_list), u) != -1)             return 0;
    if(us[5][-1] != '/')
      f = us[ 5 ] + "/" + QUERY(pdir) + f;
    else
      f = us[ 5 ] + QUERY(pdir) + f;
    return ::find_dir(f, got);
  }
  return (roxen->userlist(got) - QUERY(banish_list));
}

mixed stat_file( mixed f, mixed id )
{
  string u, of;

  if(!strlen(f) || f=='/')
    return ({ 0, -2, 0, 0, 0, 0, 0, 0, 0, 0 });

  if(sscanf(f, "%s/%s", u, f) != 2)
  {
    u=f; 
    f="";
  }

  if(u)
  {
    array us, st;
    us = roxen->userinfo( u, id );
    if(!us) return 0;
    if(QUERY(only_password) && (<"","*">)[us[ 1 ]])     return 0;
    if(search(QUERY(banish_list), u) != -1)             return 0;
    if(us[5][-1] != '/')
      f = us[ 5 ] + "/" + QUERY(pdir) + f;
    else
      f = us[ 5 ] + QUERY(pdir) + f;
    st = file_stat( f );
    if(!st) return st;
    if(QUERY(own) && (int)us[2] != st[-2]) return 0;
    return st;
  }
  return 0;
}



string query_name()
{
  return ("Location: <i>" + QUERY(mountpoint) + "</i>, "
	  "Pubdir: <i>" + QUERY(pdir) +"</i>");
}
