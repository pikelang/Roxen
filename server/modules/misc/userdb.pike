// This is a roxen module. (c) Informationsvävarna AB 1996.

// User database. Reads the system password database and use it to
// authentificate users.

string cvs_version = "$Id: userdb.pike,v 1.4 1996/11/27 13:48:08 per Exp $";
#include <module.h>
inherit "module";
inherit "roxenlib";

mapping users, uid2user;
array fstat;

void read_data();


void try_find_user(string|int u) 
{
  array uid;
  switch(QUERY(method))
  {
string cvs_version = "$Id: userdb.pike,v 1.4 1996/11/27 13:48:08 per Exp $";
#if efun(getpwuid) && efun(getpwnam)
  case "getpwent":
    if(intp(u)) uid = getpwuid(u);
    else        uid = getpwnam(u);
    break;
    if(uid)
    {
      if(users[uid[0]])
      {
	uid2user[uid[2]][5] = uid[5];
	users[uid[0]][5] = uid[5];
      } else {
	uid2user[uid[2]] = uid;
	users[uid[0]] = uid;
      }
    }
string cvs_version = "$Id: userdb.pike,v 1.4 1996/11/27 13:48:08 per Exp $";
#endif

  case "file":
    if(!equal(file_stat(QUERY(file)), fstat))
      read_data();
    break;

  case "ypmatch":
  case "niscat":
  }
}

string *userinfo(string u) 
{
  if(!users[u])
    try_find_user(u);
  return users[u];
}

string *userlist() { 
  return indices(users);
}

string user_from_uid(int u) 
{ 
  if(!uid2user[u])
    try_find_user(u);
  return uid2user[u]; 
}

string cvs_version = "$Id: userdb.pike,v 1.4 1996/11/27 13:48:08 per Exp $";
#define ipaddr(x,y) (((x)/" ")[y])

int method_is_not_file()
{
  return QUERY(method) != "file";
}

int method_is_file_or_getpwent()
{
  return (QUERY(method) == "file") || (QUERY(method)=="getpwent");
}

void create()
{
  defvar("file", "/etc/passwd", "Password database file",
	 TYPE_FILE,
	 "This file will be used if method is set to file.", 0, 
	 method_is_not_file);

string cvs_version = "$Id: userdb.pike,v 1.4 1996/11/27 13:48:08 per Exp $";
#if efun(getpwent)
  defvar("method", "getpwent", "Password database request method",
	 TYPE_STRING_LIST, 
	 "What method to use to maintain the passwd database. "
	 "'getpwent' is by far the slowest of the methods, but it "
	 "should work on all systems, and it will work with /etc/shadow (if "
	 "roxen is allowed to read it.). It will also enable an automatic "
	 "passwd information updating process. Every 10 seconds the "
	 "information about one user from the password database will be "
	 "updated. There will also be call performed if a user is not in the "
	 "in-memory copy of the passwd database."
	 " The other methods are "
	 "ypcat, on Solaris 2.x systems niscat, none and file"
	 ". If none is selected, all auth requests will succeed, "
	 "regardless of user name and password.",

	 ({ "ypcat", "file", "niscat", "getpwent", "none" }));
string cvs_version = "$Id: userdb.pike,v 1.4 1996/11/27 13:48:08 per Exp $";
#else
  defvar("method", "file", "Password database request method",
	 TYPE_STRING_LIST, 
	 "What method to use to maintain the passwd database. Typically "+
	 "ypcat, on Solaris 2.x systems niscat, and sometimes file"+
	 ". If none is selected, all auth requests will succeed, "+
	 "regardless of user name and password.",
	 ({ "ypcat", "file", "niscat", "none" }));
string cvs_version = "$Id: userdb.pike,v 1.4 1996/11/27 13:48:08 per Exp $";
#endif

  defvar("args", "", "Password command arguments",
	 TYPE_STRING,
	 "Extra arguments to pass to either ypcat or niscat."
	 "For ypcat the full command line will be 'ypcat <args> passwd'."
	 " for niscat 'niscat <args> passwd.org_dir'"
	 "If you do not want the passwd part, you can end your args with '#'",
	 0,
	 method_is_file_or_getpwent);
  

  defvar("Swashii", 1, "Turn }{| into åäö", TYPE_FLAG,
	 "Will make the module turn }{| into åäö in the Real Name "+
	 "field in the userinfo database. This is useful in a european "+
	 "country, Sweden.");

  defvar("Strip", 1, "Strip finger information from fullname", TYPE_FLAG,
	 "This will strip everyting after the first ',' character from "
	 "the GECOS field of the user database.");
}

private static int last_password_read = 0;

string cvs_version = "$Id: userdb.pike,v 1.4 1996/11/27 13:48:08 per Exp $";
#if efun(getpwent)
private static array foo_users;
private static int foo_pos;

void slow_update()
{
  if(!foo_users || sizeof(foo_users) != sizeof(users))
  {
    foo_users = indices(users);
    foo_pos = 0;
  }

  if(!sizeof(foo_users))
    return;
  
  if(foo_pos >= sizeof(foo_users))
    foo_pos = 0;
  try_find_user(foo_users[foo_pos++]);

  remove_call_out(slow_update);
  call_out(slow_update, 30);
}
string cvs_version = "$Id: userdb.pike,v 1.4 1996/11/27 13:48:08 per Exp $";
#endif

void read_data()
{
  string data, *entry, u, *tmp, *tmp2;
  int foo;
  int original_data = 1; // Did we inherit this user list from another
                        //  user-database module?
  int saved_uid;
  
  users=([]);
  uid2user=([]);
string cvs_version = "$Id: userdb.pike,v 1.4 1996/11/27 13:48:08 per Exp $";
#if efun(geteuid)
  if(getuid() != geteuid())
  {
    saved_uid = geteuid();
    seteuid(0);
  }
string cvs_version = "$Id: userdb.pike,v 1.4 1996/11/27 13:48:08 per Exp $";
#endif
  switch(query("method"))
  {
   case "ypcat":
    data=popen("ypcat "+query("args")+" passwd");
    break;

   case "getpwent":
string cvs_version = "$Id: userdb.pike,v 1.4 1996/11/27 13:48:08 per Exp $";
#if efun(getpwent)
     // This could be a _lot_ faster.
     tmp2 = ({ });
     setpwent();
     while(tmp = getpwent())
       tmp2 += ({
	 map_array(tmp, lambda(mixed s) { return (string)s; }) * ":" 
               }); 
     endpwent();
     data = tmp2 * "\n";
     break;
string cvs_version = "$Id: userdb.pike,v 1.4 1996/11/27 13:48:08 per Exp $";
#endif
   case "file":
     fstat = file_stat(query("file"));
     data=read_bytes(query("file"));
     last_password_read = time();
     break;

   case "niscat":
    data=popen("niscat "+query("args")+" passwd.org_dir");
    break;
  }

  if(!data)
    data = "";
  
  if(query("Swashii"))
    data=replace(data, 
		 ({"}","{","|","\\","]","["}),
		 ({"å","ä","ö", "Ö","Å","Ä"}));

/* Two loops for speed.. */
  if(QUERY(Strip))
    foreach(data/"\n", data)
    {
      if(sizeof(entry=data/":") > 6)
      {
	entry[4]=(entry[4]/",")[0];
	uid2user[(int)(users[entry[0]] = entry)[2]]=entry;
      }
    }
  else
    foreach(data/"\n", data)
      if(sizeof(entry=data/":") > 6)
	uid2user[(int)(users[entry[0]] = entry)[2]]=entry;
string cvs_version = "$Id: userdb.pike,v 1.4 1996/11/27 13:48:08 per Exp $";
#if efun(getpwent)
  if(QUERY(method) == "getpwent" && (original_data))
    slow_update();
string cvs_version = "$Id: userdb.pike,v 1.4 1996/11/27 13:48:08 per Exp $";
#endif
string cvs_version = "$Id: userdb.pike,v 1.4 1996/11/27 13:48:08 per Exp $";
#if efun(geteuid)
  if(saved_uid) seteuid(saved_uid);
string cvs_version = "$Id: userdb.pike,v 1.4 1996/11/27 13:48:08 per Exp $";
#endif
}

void start() { (void)read_data(); }

void read_data_if_not_current()
{
  if (query("method") == "file")
    {
      string filename=query("file");
      array|int status=file_stat(filename);
      int mtime;

      if (arrayp(status))
       mtime = status[3];
      else
       return;
      
      if (mtime > last_password_read)
       read_data();
    }
}

int succ, fail, nouser;

mapping failed  = ([ ]);

array|int auth(string *auth, object id)
{
  string u,p;

  sscanf(auth[1], "%s:%s", u, p);

  if(!p)
    return ({ 0, auth[1], -1 });
  
  if(QUERY(method) == "none")
  {
    succ++;
    return ({ 1, u, 0 });
  }

  read_data_if_not_current();

  if(!users[u] || !(stringp(users[u][1]) && strlen(users[u][1]) > 6))
  {
    nouser++;
    fail++;
    failed[id->remoteaddr]++;
    return ({0, u, p}); 
  }
  
  if(!users[u][1] || !crypt(p, users[u][1]))
  {
    fail++;
    failed[id->remoteaddr]++;
    roxen->quick_ip_to_host(id->remoteaddr);
    return ({ 0, u, p }); 
  }
  id->misc->uid = users[u][2];
  id->misc->gid = users[u][3];
  id->misc->gecos = users[u][4];
  succ++;
  return ({ 1, u, 0 }); // u is a valid user.
}

string status()
{
  return 
    ("<h1>Security info</h1>"+
     "<b>Successful auths:</b> "+(string)succ+"<br>\n" + 
     "<b>Failed auths:</b> "+(string)fail
     +", "+(string)nouser+" had the wrong username<br>\n"
     + "<p>"+
     "<h3>Failure by host</h3>" +
     map_array(indices(failed), lambda(string s) {
       return roxen->quick_ip_to_host(s) + ": "+failed[s]+"<br>\n";
     }) * "" 
     + "<p>The database has "+ sizeof(users)+" entries"
//     + "<P>The netgroup database has "+sizeof(group)+" entries"
);
}

mixed *register_module()
{
  return 
    ({ MODULE_AUTH, 
       "User database and security",
       ("This module handles the security in roxen, and uses "
	"the normal system password and user database to validate "
	"users. It also maintains the user database for all other "
	"modules in roxen, e.g. the user homepage module"),
       ({  }),
       1 
     });
}

int may_disable() { return 0; }

