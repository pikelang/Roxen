/*

Copyright 2001 - 2009, Roxen IS

Roxen 2.2+ LDAP directory user database module

*/

//#define LDAPAUTHDEBUG
#ifdef LDAPAUTHDEBUG
#define DEBUGLOG(s) werror("LDAPuserdb: "+s+"\n")
#else
#define DEBUGLOG(s)
#endif

#define LOG_ALL 1

#define ROXEN_HASH_SIGN		"{x-roxen-hash}"

constant cvs_version =
  "$Id$";
inherit UserDB;
inherit "module";

constant name = "ldapuserdb";
constant module_unique  = 0;

//<locale-token project="mod_userdb_ldap">_</locale-token>
#define _(X,Y)	_DEF_LOCALE("mod_userdb_ldap",X,Y)

#include <module.h>

LocaleString module_name =
  _(1,"Authentication: LDAP directory database");

LocaleString module_doc =
  _(2, "LDAP directory user database <br />\nNote: in <i>guest</i> mode are supported passwords hashed by {CRYPT}, {SHA}, {SSHA}, {MD5} and {SMD5} schemas.");


/*
 * Globals
 */
object dir=0;
int dir_accesses=0, last_dir_access=0, succ=0, att=0, nouser=0;
mapping failed  = ([ ]);
mapping accesses = ([ ]);
Thread.Mutex mt = Thread.Mutex(); // FIXME: what about unthreaded version ???

class LDAPUser
{
  inherit User;
  protected array pwent;

  string name()             { return pwent[0]; }
  string crypted_password() { return pwent[1]; }
  int uid()                 { return pwent[2]; }
  int gid()                 { return pwent[3]; }
  string gecos()            { return pwent[4]; }
  string real_name()        { return(pwent[4]/",")[0]; }
  string homedir()          { return pwent[5]; }
  string shell()            { return pwent[6]; }
  array compat_userinfo()   { return pwent[0..6];    }
  string dn()		    { return pwent[7]; }

  protected void create( UserDB p, array _pwent )
  {
    ::create( p );
    pwent = _pwent;
  }

  int password_authenticate(string password) {
    string pass = crypted_password();
    int rhs = sizeof(ROXEN_HASH_SIGN);
    int flg;

DEBUGLOG(sprintf("DEB: user->pass_auth(%s): %s <%O>", name(), password, pass));
    
    // check for nonacceptable password
    if(!stringp(pass) || sizeof(pass) < 1 || !sizeof(password)) {
      DEBUGLOG("pass_auth("+name()+") failed.");
      return 0; // FIXME: what about users with EMPTY password???
    }

    // catch of ROXEN_HASH_SIGN stuff
    if(sizeof(pass) >= rhs && lower_case(pass[..rhs-1]) == ROXEN_HASH_SIGN) {
      if(!access_mode_is_guest) {
        DEBUGLOG("pass_auth("+name()+") failed. The user has not <password> attribute.");
        return 0;
      } else { 
	if(sizeof(pass) == rhs) { // the password wasn't checked ever, so try now
	  flg = bind_dir(dn(), password);
	} else if(query("CI_cache_password"))
	  flg = pass[rhs..] == password;
	else
	  flg = bind_dir(dn(), password);
	DEBUGLOG("pass_auth("+name()+") "+(flg?"successed":"failed")+".");
	if(flg) pwent[1] = ROXEN_HASH_SIGN + password;
	return flg;
      }
    }

    if (has_prefix(pass, "{")) {
      // RFC 2307
      // Digests {CRYPT}, {SH1}, {SSHA}, {MD5} and {SMD5}.
      flg = verify_password(password, pass);
    } else {
      flg = pass == password;
    }

    if(flg) {
      DEBUGLOG("pass_auth("+name()+") successed.");
      return 1;
    }

    //return(crypt(password, pass));
    DEBUGLOG("pass_auth("+name()+") failed.");
    return 0;
  }

}

/*
#if LOG_ALL
    if(!zero_type(accesses[id->remoteaddr]) && !zero_type(accesses[id->remoteaddr]["cnt"])) {
      accesses[id->remoteaddr]->cnt++;
      if(Array.search_array(accesses[id->remoteaddr]->name, chk_name, u) < 0)
	accesses[id->remoteaddr]->name = accesses[id->remoteaddr]->name + ({ u });
    } else
      accesses[id->remoteaddr] = (["cnt" : 1, "name":({ u })]);
#endif
*/

protected string query_ldap_url()
{
  // NB: Adjust quoting for the %u% marker. Cf [WS-390].
  return replace(query("CI_dir_server"), "%u%", "%25u%25");
}

User find_user( string u )
{
  mixed key = mt->lock();
  array(string) pwent;

  DEBUGLOG ("find_user ("+u+")");
  if (u == "A. Nonymous") {
    DEBUGLOG ("A. Nonymous pseudo user catched and filtered.");
    return 0;
  }

  string ldap_url = query_ldap_url();

  if (query("CI_use_cache"))
    pwent = cache_lookup("ldapuserdb" + ldap_url, u);
    if (pwent) {
      DEBUGLOG("user ("+u+") retrieved from cache.");
      return LDAPUser(this_object(), pwent);
    }

  // connect to the server (if it is not already)
  if(!connect_dir()) {
    werror ("LDAPuserdb: Returning 'user unknown'.\n");
    return 0;
  }

  // initial binding
  if(!bind_dir()) {
    werror ("LDAPuserdb: Unsuccessfull binding, returning 'user unknown'.\n");
    return 0;
  }

  // finding entry
  pwent = get_entry_dir(u, dir->parse_url(ldap_url)->filter || "");

  // ROAMING access mode
  if(!access_mode_is_roaming()) {
    string ndn, obasedn;
    int oscope;
    if(!pwent || sizeof(pwent)<8 || !sizeof(pwent[7])) {
      werror ("LDAPuserdb: Returning 'user unknown'.\n");
      return 0;
    }
    ndn = pwent[7];
    obasedn = dir->set_basedn(ndn);
    oscope = dir->set_scope(0);
    pwent = get_entry_dir(u, query("CI_default_attrname_upw"));
    pwent[7] = ndn;
    dir->set_basedn(obasedn);
    dir->set_scope(oscope);
  }

  if(pwent) {
    if (query("CI_use_cache"))
      cache_set("ldapuserdb" + ldap_url, u, pwent);
    return LDAPUser(this_object(), pwent);
    } else {
    werror ("LDAPuserdb: Returning 'user unknown'.\n");
    return 0;
  }

  werror ("LDAPuserdb: Returning 'user unknown'.\n");
  return 0;
}
  
array(string)|int get_entry_dir(string u, string filter) {
// Returns password-like values for user entry from server
  mixed err;
  mapping tmp;
  array(string) dirinfo;
  object results;

  filter = replace(filter, "%u%", u);
  // the server connection is successfully opened and binded
  if(!username_parsing_is_positional()) {
    array elems = u / query("CI_username_delimiter");
    string udn = dir->parse_url(query_ldap_url())->basedn || "";
    for (int i=0; i<sizeof(elems); i++)
      udn = replace(udn, "%"+(string)(i+1)+"%", elems[i]);
    DEBUGLOG(sprintf("pos.parsing: base DN: %O", udn));
    dir->set_basedn(udn);
  }
  DEBUGLOG(sprintf("LDAPsearch: user: %O filter: %O", u, filter));
  err = catch(results=dir->search(filter)); // FIXME: set only interesting attrs!
  if (err || !objectp(results) || !results->num_entries()) {
    DEBUGLOG (sprintf("no entry in directory, returning unknown. More debug info: %O", err));
    return 0;
  }
  if(results->num_entries() > 1) {
    DEBUGLOG ("found more then one entry in directory, returning unknown");
    return 0;
  }
  tmp=results->fetch();
  dirinfo= ({
    u,
    access_mode_is_user_or_roaming() ?
      get_attrval(tmp, query("CI_default_attrname_upw"), ROXEN_HASH_SIGN)
    : ROXEN_HASH_SIGN,
    // ^^^^^ user&roadm mode: password will be replaced after successfull check
    //       by cleartext one
    (int)get_attrval(tmp, query("CI_default_attrname_uid"), query("CI_default_uid")),
    (int)get_attrval(tmp, query("CI_default_attrname_gid"), query("CI_default_gid")),
    get_attrval(tmp, query("CI_default_attrname_gecos"), query("CI_default_gecos")),
    query("CI_default_addname") ? query("CI_default_home")+u : get_attrval(tmp, query("CI_default_attrname_homedir"), ""),
    get_attrval(tmp, query("CI_default_attrname_shell"), query("CI_default_shell")),
    access_mode_is_roaming ? get_attrval(tmp, "dn", "") : get_attrval(tmp, query("CI_owner_attr"), "")
  });

    DEBUGLOG(sprintf("Result: %O",dirinfo)-"\n");
    return dirinfo;
}


int access_mode_is_user() {

  return !(query("CI_access_mode") == "user");
}

int access_mode_is_guest() {

  return !(query("CI_access_mode") == "guest");
}

int access_mode_is_roaming() {

  return !(query("CI_access_mode") == "roaming");
}

int access_mode_is_user_or_roaming() {

  return access_mode_is_user() & access_mode_is_roaming();
}


int access_mode_is_guest_or_roaming() {

  return access_mode_is_guest() & access_mode_is_roaming();
}

int username_parsing_is_positional() {

  return !(query("CI_username_parse") == "positional");
}


int default_uid() {

#if constant(geteuid)
  return(geteuid());
#else
  return(0);
#endif
}

/*
 * Object management and configuration variables definitions
 */

void create()
{
	set_module_creator("Honza Petrous <hop@roxen.com>");

        defvar ("CI_access_mode","user","Access mode",
                   TYPE_STRING_LIST, "There are three generic mode:"
		   "<ol>"
		   "<li><b>user</b><br/>"
                   "The user is authenticated against his own entry"
		   " in directory.</li>"
		   "<li><b>guest</b><br/>"
		   "The mode assume public or superuser access to the directory "
		   "entries."
		   "<br/>This mode is for testing purpose. It's not recommended"
		   " for real using.</li>"
		   "<li><b>roaming</b><br/>"
		   "Mode designed to works with Netscape roaming LDAP"
		   " DIT tree."
		   "<br/>But can be used for generic indirect user lookup as well."
		   "</li></ol>",
		({ "user", "guest", "roaming" }) );

	defvar ("CI_username_parse", "none", "Username parsing",
		   TYPE_STRING_LIST, "Method of parsing username:"
		   "<ol>"
		   "<li><b>none</b><br/>"
		   "Parsing is disabled.</li>"
		   "<li><b>positional</b><br/>"
		   "The username is divided to arrray. The delimiter value is used "
		   " for division. Elements can be used by using macro %n%, where "
		   "'n' is the position in the array.</li>"
		   "<li><b>regexp</b><br/>"
		   "[unimplemented!].</li>",
		({ "none", "positional", "regexp" }),
		access_mode_is_user );


	defvar ("CI_username_delimiter", ".", "Username delimiter",
		   TYPE_STRING, "Delimiter used for splitting elements from username",
		   0, access_mode_is_user );

	// LDAP server:
        defvar ("CI_dir_server","ldap://localhost/??sub?(&(objectclass=person)(uid=%u%))","LDAP server URL",
                   TYPE_STRING, "LDAP URL based information for connection"
		   " to directory server which maintains "
                   "the authentication information.<br>"
		   "LDAP URL form:<p>"
		   "ldap://hostname[:port]/base_DN[?[attribute_list][?[scope][?[filter][?extensions]]]]<p>"
		   "<i>More detailed info at <a href=\"http://community.roxen.com/developers/idocs/rfc/rfc2255.html\"> RFC 2255</a>.</i><br>"
		   "Notice:<i>"
		   " <tt>%u%</tt> will be replaced by username.</i>");

        defvar ("CI_dir_pwd","", "LDAP server password",
		    TYPE_STRING|VAR_MORE,
		    "This is the password used to authenticate "
		    "connection to directory.<br>"
		    "Note: In the <i>user</i> mode an authenticating user will be "
		    "rebinded for checking its password, so password is used to "
		    "initial connection only. If password is empty, the anonymous "
		    "binding will be used.");

        defvar ("CI_cache_password",0,"Cache user passwords",
		   TYPE_FLAG|VAR_MORE,
		   "Setting this will enable caching of passwords."
                   "<br/>Note: only succesfull passwords will be cached.",
		   0,
		   access_mode_is_user_or_roaming
		   );

	// "roaming" access type
        defvar ("CI_owner_attr","owner","Indirect DN attributename",
                   TYPE_STRING|VAR_MORE,
		   "Attribute name which contains DN for indirect authorization"
                   ". Value is used as DN for binding to the directory.",
		   0,
		   access_mode_is_roaming
		   );

	// Defaults:
        defvar ("CI_default_uid",default_uid(),"Defaults: User ID", TYPE_INT,
                   "Some modules require an user ID to work correctly. This is the "
                   "user ID which will be returned to such requests if the information "
                   "is not supplied by the directory search.");
        defvar ("CI_default_gid",
#ifdef __NT__
		0,
#else		
		getegid(),
#endif		
		"Defaults: Group ID", TYPE_INT,
                   "Same as User ID, only it refers rather to the group.");
        defvar ("CI_default_gecos", "", "Defaults: Gecos", TYPE_STRING,
                   "The default Gecos.");
        defvar ("CI_default_home","/", "Defaults: Home Directory", TYPE_DIR,
                   "It is possible to specify an user's home "
                   "directory. This is used if it's not provided.");
        defvar ("CI_default_shell","/bin/false", "Defaults: Shell", TYPE_STRING,
                   "The shell name for entries without own defined.");
        defvar ("CI_default_addname",0,"Defaults: Username add",TYPE_FLAG,
                   "Setting this will add username to path to default directory.");

	// Map
        defvar ("CI_default_attrname_upw", "userPassword",
		   "Map: User password map", TYPE_STRING,
                   "The mapping between passwd:password and LDAP.");
        defvar ("CI_default_attrname_uid", "uidNumber",
		   "Map: User ID map", TYPE_STRING,
                   "The mapping between passwd:uid and LDAP.");
        defvar ("CI_default_attrname_gid", "gidNumber",
		   "Map: Group ID map", TYPE_STRING,
                   "The mapping between passwd:gid and LDAP.");
        defvar ("CI_default_attrname_gecos", "gecos",
		   "Map: Gecos map", TYPE_STRING,
                   "The mapping between passwd:gecos and LDAP.");
        defvar ("CI_default_attrname_homedir", "homeDirectory",
		   "Map: Home Directory map", TYPE_STRING,
                   "The mapping between passwd:homedir and LDAP.");
        defvar ("CI_default_attrname_shell", "loginShell",
		   "Map: Shell map", TYPE_STRING,
                   "The mapping between passwd:shell and LDAP.");

	// Etc.
        defvar ("CI_use_cache",1,"Cache entries", TYPE_FLAG,
                   "This flag defines whether the module will cache the directory "
                   "entries. Makes accesses faster, but changes in the directory will "
                   "not show immediately. <B>Recommended</B>.");
        defvar ("CI_close_dir",1,"Close the directory if not used",
		   TYPE_FLAG|VAR_MORE,
                   "Setting this will save one filedescriptor without a small "
                   "performance loss.");
        defvar ("CI_timer",60,"Directory connection close timer",
		   TYPE_INT|VAR_MORE,
                   "The time after which the directory is closed",0,
                   (!query("CI_close_dir")));
        defvar ("CI_debug_flg",0,"Debug log",
		   TYPE_FLAG|VAR_MORE,
                   "Setting this will increase logging.");

}

void stop() {

  if (query("CI_use_cache"))
    cache_expire("ldapuserdb" + query_ldap_url());
  dir && dir->unbind();
  dir = 0;
}

void close_dir() {

    if (!query("CI_close_dir"))
	return;
    if( (time(1)-last_dir_access) > query("CI_timer") && objectp(dir)) {
	dir->unbind();
	dir=0;
	DEBUGLOG("closing the directory");
	return;
    }
    call_out(close_dir,query("CI_timer"));
}

int connect_dir() {
// Attempt to connect to the server
    mixed err;
    string serverurl = query_ldap_url();

    last_dir_access=time(1);
    dir_accesses++; //I count accesses here, since this is called before each
    if(dir && !dir->error_number())
	return 1;

    err = catch (dir = Protocols.LDAP.client(serverurl));
    if (arrayp(err)) {
	werror ("LDAPuserdb: Couldn't open authentication directory!\n[Internal: "+err[0]+"]\n");
	if (objectp(dir)) {
	    werror("LDAPuserdb: directory interface replies: "+dir->error_string()+"\n");
	}
	else
	    werror("LDAPuserdb: unknown reason\n");
	werror ("LDAPuserdb: check the values in the configuration interface, and "
		"that the user\n\trunning the server has adequate permissions "
		"to the server\n");
	dir=0;
	return 0;
    }
    if(dir->error_number()) {
	werror ("LDAPuserdb: authentication error ["+dir->error_string()+"]\n");
	dir=0;
	return 0;
    }
    DEBUGLOG("LDAPconnect OK.");
    return 1;
}

int bind_dir(string|void userdn, string|void pass) {
// Bind to the server
    mapping ldapurl;
    string binddn, bindpwd;
    mixed err;
    string serverurl = query_ldap_url();

    if(!connect_dir())
      return 0;
    if(zero_type(userdn) ||		     // requested anonymous binding
       !access_mode_is_guest_or_roaming()) { // access type is "guest"/"roam."
	bindpwd = query("CI_dir_pwd");
	if (!sizeof(bindpwd))
	  return 1; // binding isn't needed
        ldapurl = dir->parse_url(serverurl);
        binddn = zero_type(ldapurl["ext"]) ? "" : zero_type(ldapurl->ext["bindname"]) ? "" : ldapurl->ext->bindname;
    } else {                      // access type is "user"
	bindpwd = pass;
	binddn = userdn;
    }

    DEBUGLOG(sprintf("Binding to the directory: DN: %O P: %O", binddn, bindpwd));
    err = catch(dir->bind(binddn, bindpwd));
    if (err) {
	werror ("LDAPuserdb: authentication error [not binded]\n");
	return 0;
    }
    if(dir->error_number())
      err = catch(dir->bind(binddn, bindpwd, 2)); // fallback to v2 protocol
    if(err || dir->error_number()) {
	werror ("LDAPuserdb: authentication error ["+(err?err[0]:dir->error_string())+"]\n");
	return 0;
    }

    if(query("CI_close_dir")) {  // refresh timeout
	remove_call_out(close_dir);
	call_out(close_dir,query("CI_timer"));
    }
    DEBUGLOG("LDAPbind OK.");
    return 1;
}



/*
 * Statistics
 */

string status() {

    return ("<H2>Security info</H2>"
	   "Attempted authentications: "+att+"<BR>\n"
	   "Failed: "+(att-succ+nouser)+" ("+nouser+" because of wrong username)"
	   "<BR>\n"+
	   dir_accesses +" accesses to the directory were required.<BR>\n" +

	     "<p>"+
	     "<h3>Failure by host</h3>" +
	     Array.map(indices(failed), lambda(string s) {
	       return roxen->quick_ip_to_host(s) + ": "+failed[s]+"<br>\n";
	     }) * ""
	     //+ "<p>The database has "+ sizeof(users)+" entries"
#ifdef LOG_ALL
	     + "<p>"+
	     "<h3>Auth attempt by host</h3>" +
	     Array.map(indices(accesses), lambda(string s) {
	       return roxen->quick_ip_to_host(s) + ": "+accesses[s]->cnt+" ["+accesses[s]->name[0]+
		((sizeof(accesses[s]->name) > 1) ?
		  (Array.map(accesses[s]->name, lambda(string u) {
		    return (", "+u); }) * "") : "" ) + "]" +
		"<br>\n";
	     }) * ""
#endif
	   );

}


/*
 * Auth functions
 */

string get_attrval(mapping attrval, string attrname, string dflt) {

    return (zero_type(attrval[attrname]) ? dflt : attrval[attrname][0]);
}

#if LOG_ALL
int chk_name(string x, string y) {

    return(x == y);
}
#endif

