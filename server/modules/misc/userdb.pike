// This is a roxen module. Copyright � 1996 - 2000, Roxen IS.

// User database. Reads the system password database and use it to
// authentificate users.

constant cvs_version = "$Id: userdb.pike,v 1.47 2000/08/23 18:44:34 per Exp $";

inherit "module";
#include <module.h>

// Fairly weak check of password for portability.
#define CRYPTWD_CHECK(cryptwd) \
  (!!(cryptwd) && sizeof (cryptwd) >= 10 && \
   search ((cryptwd), "*") < 0 && search ((cryptwd), "!") < 0)

mapping users, uid2user;
array fstat;
void read_data();

void report_io_error (string f, mixed... args)
{
  f = sprintf (f, @args);
#if constant (strerror)
  f += ": " + strerror (errno()) + "\n";
#else
  f += ": errno " + errno() + "\n";
#endif
  report_error (f);
}


void try_find_user(string|int u)
{
  array uid;
  switch(query("method"))
  {
#if efun(getpwuid) && efun(getpwnam)
  case "getpwent":
    if(intp(u)) 
      uid = getpwuid(u);
    else        
      uid = getpwnam(u);

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
#endif
    break;

  case "file":
    if(!equal(file_stat(query("file")), fstat))
      read_data();
    break;

  case "ypmatch":
  case "niscat":
  }
}

array(string) userinfo(string u)
{
  if(!users[u])
    try_find_user(u);
  return users[u];
}

array(string) userlist() {
  return indices(users);
}

array(string) user_from_uid(int u)
{
  if(!uid2user[u])
    try_find_user(u);
  return uid2user[u];
}

#define ipaddr(x,y) (((x)/" ")[y])

int method_is_not_file()
{
  return !(query("method") == "file" || query("method") == "shadow");
}

int method_is_not_shadow()
{
  return query("method") != "shadow";
}

int method_is_file_or_getpwent()
{
  return (query("method") == "file") || (query("method")=="getpwent") ||
    (query("method") == "shadow");
}

void create()
{
  defvar("file", "/etc/passwd", "Password database file",
	 TYPE_FILE|VAR_INITIAL,
	 "This file will be used if method is set to file.", 0,
	 method_is_not_file);

  defvar("shadowfile", "/etc/shadow", "Password database shadow file",
	 TYPE_FILE|VAR_INITIAL,
	 "This file will be used if method is set to shadow.", 0,
	 method_is_not_shadow);

#if efun(getpwent)
  defvar("method", "getpwent", "Password database request method",
	 TYPE_STRING_LIST|VAR_INITIAL,
	 "What method to use to maintain the passwd database. "
	 "'getpwent' is by far the slowest of the methods, but it "
	 "should work on all systems. It will also enable an automatic "
	 "passwd information updating process. Every 10 seconds the "
	 "information about one user from the password database will be "
	 "updated. There will also be call performed if a user is not in the "
	 "in-memory copy of the passwd database."
	 " The other methods are "
	 "ypcat, on Solaris 2.x systems niscat, file, shadow and none"
	 ". If none is selected, all auth requests will succeed, "
	 "regardless of user name and password.",

	 ({ "ypcat", "file", "shadow", "niscat", "getpwent", "none" }));
#else
  defvar("method", "file", "Password database request method",
	 TYPE_STRING_LIST|VAR_INITIAL,
	 "What method to use to maintain the passwd database. The methods are "+
	 "ypcat, on Solaris 2.x systems niscat, file, shadow and none"+
	 ". If none is selected, all auth requests will succeed, "+
	 "regardless of user name and password.",
	 ({ "ypcat", "file", "shadow", "niscat", "none" }));
#endif

  defvar("args", "", "Password command arguments",
	 TYPE_STRING|VAR_MORE,
	 "Extra arguments to pass to either ypcat or niscat."
	 "For ypcat the full command line will be 'ypcat <args> passwd'."
	 " for niscat 'niscat <args> passwd.org_dir'"
	 "If you do not want the passwd part, you can end your args with '#'",
	 0,
	 method_is_file_or_getpwent);


  defvar("Swashii", 0, "Turn }{| into ���", TYPE_FLAG|VAR_MORE,
	 "Will make the module turn }{| into ��� in the Real Name "+
	 "field in the userinfo database. This is useful in a european "+
	 "country, Sweden.");

  defvar("Strip", 1, "Strip finger information from fullname",
	 TYPE_FLAG|VAR_MORE,
	 "This will strip everyting after the first ',' character from "
	 "the GECOS field of the user database.");

  defvar("update", 60,
	 "Interval between automatic updates of the user database",
	 TYPE_INT|VAR_MORE,
	 "This specifies the interval in minutes between automatic updates "
	 "of the user database.");
}

private static int last_password_read = 0;

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
#endif

void read_data()
{
  string data, u;
  array(string) entry, tmp, tmp2;
  int foo, i;
  int original_data = 1; // Did we inherit this user list from another
                        //  user-database module?
  int saved_uid;

  users=([]);
  uid2user=([]);
  switch(query("method"))
  {
  case "ypcat":
    object privs;
#if efun(geteuid)
//  if(getuid() != geteuid()) privs = Privs("Reading password database");
#endif
    data=Process.popen("ypcat "+query("args")+" passwd");
    if (objectp(privs)) {
      destruct(privs);
    }
    privs = 0;
    if (!data) report_io_error ("Error reading passwd database with ypcat");
    break;

  case "getpwent":
#if efun(getpwent)
    // This could be a _lot_ faster.
#if efun(geteuid)
    if(getuid() != geteuid()) 
      privs = Privs("Reading password database");
#endif
    setpwent();
    while(tmp = getpwent())
      data += ((array(string))tmp) * ":" + "\n";
    endpwent();
    if (objectp(privs)) {
      destruct(privs);
    }
    privs = 0;
    break;
#endif

  case "file":
//     if(getuid() != geteuid()) privs = Privs("Reading password database");
    fstat = file_stat(query("file"));
    data = Stdio.read_bytes(query("file"));
    if (objectp(privs)) {
      destruct(privs);
    }
    privs = 0;
    if (!data) report_io_error ("Error reading passwd database from " + query("file"));
    last_password_read = time();
    break;

  case "shadow":
    string shadow;
    array pw, sh, a, b;
    mapping sh = ([]);
#if efun(geteuid)
    if(getuid() != geteuid()) privs=Privs("Reading password database");
#endif
    fstat = file_stat(query("file"));
    data=    Stdio.read_bytes(query("file"));
    if (data) shadow = Stdio.read_bytes(query("shadowfile"));
    if (objectp(privs)) {
      destruct(privs);
    }
    privs = 0;
    if (!data)
      report_io_error ("Error reading passwd database from " + query ("file"));
    else if (!shadow)
      report_io_error ("Error reading shadow database from " + query ("shadowfile"));
    else {
      foreach(shadow / "\n", shadow) {
	if(sizeof(a = shadow / ":") > 2)
	  sh[a[0]] = a[1];
      }
      pw = data / "\n";
      for(i = 0; i < sizeof(pw); i++) {
	if(sizeof(a = pw[i] / ":") && sh[a[0]])
	  pw[i] = `+(a[0..0],({sh[a[0]]}),a[2..])*":";
      }
      data = pw*"\n";
    }
    last_password_read = time();
    break;

  case "niscat":
#if efun(geteuid)
    if(getuid() != geteuid()) privs=Privs("Reading password database");
#endif
    data=Process.popen("niscat "+query("args")+" passwd.org_dir");
    if (objectp(privs)) {
      destruct(privs);
    }
    privs = 0;
    if (!data) report_io_error ("Error reading passwd database with niscat");
    break;
  }

  if(!data)
    data = "";

  if(query("Swashii"))
    data=replace(data,
		 ({"}","{","|","\\","]","["}),
		 ({"�","�","�", "�","�","�"}));

/* Two loops for speed.. */
  if(query("Strip")) {
    foreach(data/"\n", data)
    {
      if(sizeof(entry=data/":") > 6)
      {
	if (!users[entry[0]]) {
	  if (sizeof(entry[4])) {
	    entry[4]=(entry[4]/",")[0];
	  }
	  uid2user[(int)((users[entry[0]] = entry)[2])]=entry;
	}
      }
    }
  } else {
    foreach(data/"\n", data) {
      if(sizeof(entry=data/":") > 6) {
	if (!users[entry[0]]) {
	  uid2user[(int)((users[entry[0]] = entry)[2])]=entry;
	}
      }
    }
  }
#if efun(getpwent)
  if(query("method") == "getpwent" && (original_data))
    slow_update();
#endif

  // We do need to continue calling out..
  int delta = query("update");
  if (delta > 0) 
  {
    last_password_read=time(1);
    remove_call_out(read_data);
    call_out(read_data, delta*60);
  }
}

void start(int i)
{
  read_data();
  /* Automatic update */
  int delta = query("update");
  if (delta > 0) {
    last_password_read=time(1);
    remove_call_out(read_data);
    call_out(read_data, delta*60);
  }
}

void read_data_if_not_current()
{
  if (query("method") == "file" || query("method") == "shadow")
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

array|int auth(array(string) auth, object id)
{
  string u, p;
  array(string) arr = auth[1]/":";

  if (sizeof(arr) < 2) {
    return ({ 0, auth[1], -1 });
  }

  u = arr[0];
  p = arr[1..]*":";

  if(query("method") == "none")
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
  id->misc->home = users[u][5];
  id->misc->shell = users[u][6];
  succ++;
  return ({ 1, u, 0 }); // u is a valid user.
}

string status()
{
  int cryptwd_ok = 0;
  foreach (values (users), array e)
    cryptwd_ok += CRYPTWD_CHECK (e[1]);

  return
    ("<h1>Security info</h1>"+
     "<b>Successful auths:</b> "+(string)succ+"<br>\n" +
     "<b>Failed auths:</b> "+(string)fail
     +", "+(string)nouser+" had the wrong username<br>\n"
     + "<p>The database has "+ sizeof(users)+" entries, "
     "of which " + cryptwd_ok + " seems to have valid passwords."
//     + "<P>The netgroup database has "+sizeof(group)+" entries"
     + "<h3>Failure by host</h3>" +
     map(indices(failed), lambda(string s) {
       return roxen->quick_ip_to_host(s) + ": "+failed[s]+"<br>\n";
     }) * ""
);
}

constant module_type = MODULE_AUTH;
constant module_name = "User database";
constant module_doc  = "This module handles the security in roxen, it uses "
  "the normal system password and user database to validate "
  "users. It also maintains the user database for all other "
  "modules in roxen, e.g. the user homepage module.";
