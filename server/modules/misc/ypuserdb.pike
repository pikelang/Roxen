// This is a roxen module. (c) Informationsvävarna AB 1996.

// YP User database. Reads the system password database and use it to
// authentificate users.

string cvs_version = "$Id: ypuserdb.pike,v 1.1 1997/06/09 17:52:00 grubba Exp $";

#include <module.h>
inherit "module";
inherit "roxenlib";

import Stdio;
import Array;
import Yp;

/*
 * Globals
 */
object(YpMap) users;		// passwd.byname
object(YpMap) uid2user;		// passwd.byuid

/*
 * Statistics
 */

int succ, fail, nouser, emptypasswd;
mapping(string:int) failed = ([]);

string status()
{
  return("<h1>Security info</h1>\n"
	 "<b>YP-server:</b> " + users->server() + "<br>\n"
	 "<b>YP-domain:</b> " + default_yp_domain() + "<br>\n"
	 "<p>\n"
	 "<b>Successful auths:</b> " + (string)succ +
	 ", " + (string)emptypasswd + " had empty password fields.<br>\n"
	 "<b>Failed auths:</b> " + (string)fail +
	 ", " + (string)nouser + " had the wrong username.<br>\n"
	 "<p>\n"
	 "<h3>Failure by host</h3>" +
	 (map(indices(failed), lambda(string s) {
	   return roxen->quick_ip_to_host(s) + ": " + failed[s] + "<br>\n";
	 }) * "") +
	 "<p>The database has " + sizeof(users->all()) + " entries."
}

/*
 * Auth functions
 */

array(string) userinfo(string u)
{
  string s = users->match(u);
  if (s) {
    return(s/":");
  }
  return(0);
}

array(string) userlist()
{
  mapping(string:string) m = users->all();
  if (m) {
    return(indices(m));
  }
  return(0);
}

string user_from_uid(int u)
{
  string s = uid2user->match((string)u);
  if (s) {
    return((s/":")[0]);
  }
  return(0);
}

array|int auth(array(string) auth, object id)
{
  array(string) arr = auth[1]/":";
  string u, p;

  u = arr[0];
  if (sizeof(arr) <= 1) {
    p = "";
  } else {
    p = arr[1..]*":";
  }
  string s = users->match(u);
  if (!s) {
    fail++;
    nouser++;
    failed[id->remoteaddr]++;
    return(({ 0, auth[1], -1 }));
  }
  arr = s/":";
  if ((!sizeof(arr[1])) || crypt(p, arr[1])) {
    // Valid user
    id->misc->uid = arr[2];
    id->misc->gid = arr[3];
    id->misc->gecos = arr[4];
    id->misc->home = arr[5];
    id->misc->shell = arr[6];
    succ++;
    emptypasswd += !sizeof(arr[1]);
    return(({ 1, u, 0 }));
  }
  fail++;
  failed[id->remoteaddr]++;
  return(({ 0, auth[1], -1 }));
}

/*
 * Registration and initialization
 */

array register_module()
{
  return(({ MODULE_AUTH,
	      "YP (NIS) authorization",
	      "Experimental module for authorization using "
	      "Pike's internal YP-database interface.",
	      ({}), 1 }));
}

void start(int i)
{
  if (!users) {
    users = YpMap("passwd.byname");
  }
  if (!uid2user) {
    uid2user = YpMap("passwd.byuid");
  }
}

