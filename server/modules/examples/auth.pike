#include <module.h>
inherit "module";
// All roxen modules must inherit module.pike

constant cvs_version = "$Id: auth.pike,v 1.1 2000/08/28 16:05:26 jhs Exp $";
constant module_type = MODULE_AUTH;
constant module_name = "RefDoc for MODULE_AUTH";
constant module_doc = #"This module does nothing, but its inlined documentation
gets imported into the roxen programmer manual. You definetely don't want to use
this module in your virtual servers, since anybody with access to your admin
interface or server configuration file automatically gains access to all your
passwords. For a budding roxen programmer, the module however does show the
basics of making an authentication module.";

void create()
{
  defvar("users", Variable.StringList(({}), VAR_INITIAL, "Users and Passwords",
				      "A list of username:password pairs the "
				      "module should grant access for."));
}

array|int auth(array(string) auth, RequestID id)
//! The auth method of your MODULE_AUTH type module is called when the
//! browser sent either of the <tt>Authorization</tt> or
//! <tt>Proxy-Authorization</tt> HTTP headers (see RFC 2617).
//!
//! The auth argument passed is calculated as header_content/" ", but
//! where the second element is base64-decoded (meaning that you won't
//! need to do so yourself). A typical auth array you might receive
//! could look like <tt>({ "Basic", "Aladdin:open sesame" })</tt>,
//! where Aladdin would be the user name the client logged in with,
//! and "open sesame" his password.
//!
//! The three elements in the returned array are, in order:
//!
//! o an int(0..1) signifying authentication failure (0) or success (1)
//!
//! o a string with the username (authenticated or not)
//!
//! o when failed, a string with the password used for the failed
//!   authentication attempt, otherwise the integer zero.
//!
//! See also <ref>Roxen.http_auth_required()</ref> and
//! <ref>Roxen.http_proxy_auth_required()</ref>.
{
  sscanf(auth[1], "%s:%s", string user, string password);
  int successful_auth = has_value(query("users"), auth[1]);
  return ({
	    successful_auth,
	    user,
	    !successful_auth && password
	  });
}

string user_from_uid(int uid, RequestID|void id)
//! Return the login name of the user with uid `uid'.
{
  return uid->digits(256); // Try 512852583713->digits(256), for instance. :-)
}

array(string) userlist(RequestID|void id)
//! Return an array of all valid user names.
{
  return Array.transpose(map(query("users"), `/, ":"))[0][0];
}

array(string|int) userinfo(string user, RequestID|void id)
//! Return /etc/passwd-style user information for the user whose login name is
//! `user'. The returned array consists of:
//!
//! <pre>({ login name,
//!     crypted password,
//!     used id,
//!     group id,
//!     name,
//!     homedirectory,
//!     login shell
//! })</pre>
//!
//! All entries should be strings, except uid and gid, who should be integers.
{
  string user, passwd, name = "J. Random Hacker", homedir, shell = "/bin/zsh";
  int uid, gid;
  array(string) matching_users = glob(user + ":*", query("users"));
  if(!sizeof(matching_users))
    return 0;
  sscanf(matching_users[0], "%*s:%s", passwd);
  sscanf(user, "%"+sizeof(user)+"c", uid);
  gid = uid;
  homedir = "/home/" + user;
  return ({ user, crypt(passwd), uid, gid, name, homedir, shell });
}
