// This is a roxen module. (c) Honza Petrous 1998,9

/* LDAP User authentification. Reads the directory and use it to
   authentificate users.

   Basic authentication names and passwords are mapped onto attributes
   in entries in preselected portions of an LDAP DSA.

   Uses 'uid' and 'userPassword' from entries with 'objectclass=person'.
   OR
   Tries to authenticate against ldap-server
   =====================================================================

  History:

  1998-03-05 v1.0	initial version
  1998-07-03 v1.1	added support for Protocols.LDAP module
  1998-07-03 v1.2	added authenticate against server
			(instead of using userpassword)
  			bonis@bonis.de
  1998-12-01 v1.3	added required attribute, more caching (bonis@bonis.de)
  1999-02-08 v1.4	more changes:
			 - incorporated 'user' type of authentication by Wim
			 - optimized
			 - removed support for old LDAP API
			 - added some templates
			 - changed perror() to werror()
			 - added logging of unsuccessful connections
			 - added checking of 'geteuid()' /not exists on NT/
  1999-07-26 v1.5	changed possibility of opened connection to the LDAP
			server - now disabled for 'user' access mode
  1999-08-07 v1.6	added more config options (i.e. attribute names)
			fields like uid,gid,gecos,homedir,shell now works
  1999-08-12 v1.7	added hack for pseudouser "A. Nonymous", now he isn't
			checked at all
  1999-08-14 v1.8a	- modified default attribute names to be compatible
			  with RFC2307
			- changed labels for 'Attribute names: ...' to
			  to more readable ' ... map'
  1999-08-18 v1.9	added catching errors in search op.
  1999-08-20 v1.10	- added logging all attempts of authenification
			- added id->misc[uid,gid,gecos,home,shell] update -now
			  works 'access as logged user'
			- added uid->name mapping
			! known bug: 1. unsuc. auth. is logged twice - status()
			  function returns incorrect values !!!

*/

constant cvs_version = "$Id: ldapuserauth.pike,v 1.4 1999/08/23 18:43:45 peter Exp $";
constant thread_safe=0; // FIXME: ??

#include <module.h>
inherit "module";
inherit "roxenlib";

import Stdio;
import Array;

#define LDAPAUTHDEBUG
#ifdef LDAPAUTHDEBUG
#define DEBUGLOG(s) werror("LDAPuserauth: "+s+"\n")
#else
#define DEBUGLOG(s)
#endif

#define LOG_ALL 1

/*
 * Globals
 */
object dir=0;
int dir_accesses=0, last_dir_access=0, succ=0, att=0, nouser=0;
mapping failed  = ([ ]);
mapping accesses = ([ ]);

mapping uids = ([ ]);
mapping gids = ([ ]);

int access_mode_is_user() {

  return (QUERY(CI_access_mode) != "user");
}

int access_mode_is_guest() {

  return (QUERY(CI_access_mode) != "guest");
}

int default_uid() {

#if efun(geteuid)
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
        defvar ("CI_access_mode","user","Access mode",
                   TYPE_STRING_LIST, "There are two generic mode:"
		   "<p><b>user</b><br>"
                   "The user is authenticated against his own entry"
		   " in directory."
		   "<br>Optional you can specify attribute/value"
		   " pair must contained in."
		   "<p><b>guest</b><br>"
		   "The mode assume public access to the directory entries."
		   "<br>This mode is for testing purpose. It's not recommended"
		   " for real using.",
		({ "user", "guest" }) );
        defvar ("CI_access_type","search","Access type",
                   TYPE_STRING_LIST, "Type of LDAP operation used "
		   "for authorization  checking."
		   "<p>Only 'search' type implemented, yet ;-)",
		({ "search" }) );
		//({ "search", "compare" }) );
        defvar ("CI_search_templ","(&(objectclass=person)(uid=%u%))","Defaults: Search template",
                   TYPE_STRING, "Template used by LDAP search operation"
		   " as filter."
		   "<p><b>%u%</b> : Will be replaced by entered username." );
        defvar ("CI_level","subtree","LDAP query depth",
                   TYPE_STRING_LIST, "Scope used by LDAP search operation."
                   "",
		({ "base", "onelevel", "subtree" }) );

	// LDAP server:
        defvar ("CI_dir_server","localhost","LDAP server: Location",
                   TYPE_STRING, "This is the host running the LDAP server with "
                   "the authentication information.");
        defvar ("CI_basename","","LDAP server: Base name",
                   TYPE_STRING, "The distinguished name to use as a base for queries.<br>"
		   "<p>Typically, this would be an 'o' or 'ou' entry "
		   "local to the DSA which contains the user entries.");


	// "user" access type
        defvar ("CI_required_attr","memberOf","LDAP server: Required attribute",
                   TYPE_STRING|VAR_MORE,
		   "Which attribute must be present to successfully"
		   " authenticate user (can be empty)",
		   0,
		   access_mode_is_user
		   );
        defvar ("CI_required_value","cn=KISS-PEOPLE","LDAP server: Required value",
                   TYPE_STRING|VAR_MORE,
		   "Which value must be in required attribute (can be empty)",
		   0,
		   access_mode_is_user
		   );
        defvar ("CI_bind_templ","uid=%u%","LDAP server: Bind template",
                   TYPE_STRING|VAR_MORE,
		   "If <b>Base name</b> is not null will be added as suffix"
		   "<p>For example: <br>Base name is 'c=CZ' and user is 'hop',"
		   " then bind DN will be 'uid=hop, c=CZ'.",
		   0,
		   access_mode_is_user
		   );

	// "guest" access type
        defvar ("CI_dir_username","","LDAP server: Directory search username",
                   TYPE_STRING|VAR_MORE,
		   "This username will be used to authenticate "
                   "when connecting to the LDAP server. Refer to your LDAP "
                   "server documentation, this could be irrelevant.",
		   0,
		   access_mode_is_guest
		   );
        defvar ("CI_dir_pwd","", "LDAP server: Directory user's password",
		    TYPE_STRING|VAR_MORE,
		    "This is the password used to authenticate "
		    "connection to directory.",
		   0,
		   access_mode_is_guest
		    );
//        defvar ("dirattrs","", "LDAP server: Directory authentication attributes",
//		    TYPE_STRING, "These are the attributes that the entered "
//		    "name and password are compared against.  The defaults are "
//		    "'cn' and 'userPassword'.");

	// Defaults:
        defvar ("CI_default_uid",default_uid(),"Defaults: User ID", TYPE_INT,
                   "Some modules require an user ID to work correctly. This is the "
                   "user ID which will be returned to such requests if the information "
                   "is not supplied by the directory search.");
        defvar ("CI_default_attrname_uid", "uidnumber",
		   "Defaults: User ID map", TYPE_STRING,
                   "The mapping between passwd:uid and LDAP.");
        defvar ("CI_default_gid", getegid(), "Defaults: Group ID", TYPE_INT,
                   "Same as User ID, only it refers rather to the group.");
        defvar ("CI_default_attrname_gid", "gidnumber",
		   "Defaults: Group ID map", TYPE_STRING,
                   "The mapping between passwd:gid and LDAP.");
        defvar ("CI_default_gecos", "", "Defaults: Gecos", TYPE_STRING,
                   "The default Gecos.");
        defvar ("CI_default_attrname_gecos", "gecos",
		   "Defaults: Gecos map", TYPE_STRING,
                   "The mapping between passwd:gecos and LDAP.");
        defvar ("CI_default_home","/", "Defaults: Home Directory", TYPE_DIR,
                   "It is possible to specify an user's home "
                   "directory. This is used if it's not provided.");
        defvar ("CI_default_attrname_homedir", "homedirectory",
		   "Defaults: Home Directory map", TYPE_STRING,
                   "The mapping between passwd:homedir and LDAP.");
        defvar ("CI_default_shell","/bin/false", "Defaults: Shell", TYPE_STRING,
                   "The shell name for entries without own defined.");
        defvar ("CI_default_attrname_shell", "loginshell",
		   "Defaults: Shell map", TYPE_STRING,
                   "The mapping between passwd:shell and LDAP.");
        defvar ("CI_default_addname",0,"Defaults: Username add",TYPE_FLAG,
                   "Setting this will add username to path to default directory.");

	// Etc.
        defvar ("CI_use_cache",1,"Cache entries", TYPE_FLAG,
                   "This flag defines whether the module will cache the directory "
                   "entries. Makes accesses faster, but changes in the directory will "
                   "not show immediately. <B>Recommended</B>.");
        defvar ("CI_close_dir",1,"Close the directory if not used",
		   TYPE_FLAG|VAR_MORE,
                   "Setting this will save one filedescriptor without a small "
                   "performance loss.",0,
		   access_mode_is_guest);
        defvar ("CI_timer",60,"Directory connection close timer",
		   TYPE_INT|VAR_MORE,
                   "The time after which the directory is closed",0,
                   lambda(){return !QUERY(CI_close_dir) || !(QUERY(CI_access_mode) == "guest");});

}


void close_dir() {

    if (!QUERY(CI_close_dir))
	return;
    if( (time(1)-last_dir_access) > QUERY(CI_timer) ) {
	dir->unbind();
	dir=0;
	DEBUGLOG("closing the directory");
	return;
    }
    call_out(close_dir,QUERY(CI_timer));
}

void open_dir(string u, string p) {
    mixed err;
    string binddn, bindpwd;

    last_dir_access=time(1);
    dir_accesses++; //I count accesses here, since this is called before each
    //if(objectp(dir)) //already open
    if(dir) //already open
	return;
    if(dir)
	return;

    if(!access_mode_is_guest()) { // access type is "guest"
	binddn = QUERY(CI_dir_username);
	bindpwd = QUERY(CI_dir_pwd);
    } else {                      // access type is "user"
	binddn = replace(QUERY(CI_bind_templ), "%u%", u);
	if (sizeof(QUERY(CI_basename)))
	    binddn += ", " + QUERY(CI_basename);
	bindpwd = p;
    }

    err = catch {
	dir = Protocols.LDAP.client(QUERY(CI_dir_server));
	dir->bind(binddn, bindpwd);
    };
    if (arrayp(err)) {
	werror ("LDAPauth: Couldn't open authentication directory!\n[Internal: "+err[0]+"]\n");
	if (objectp(dir)) {
	    werror("LDAPauth: directory interface replies: "+dir->error_string()+"\n");
	    catch(dir->unbind());
	}
	else
	    werror("LDAPauth: unknown reason\n");
	werror ("LDAPauth: check the values in the configuration interface, and "
		"that the user\n\trunning the server has adequate permissions "
		"to the server\n");
	dir=0;
	return;
    }
    if(dir->error_code) {
	werror ("LDAPauth: authentification error ["+dir->error_string+"]\n");
	dir=0;
	return;
    }
    switch(QUERY(CI_level)) {
	case "subtree": dir->set_scope(2); break;
	case "onelevel": dir->set_scope(1); break;
	case "base": dir->set_scope(0); break;
    }
    dir->set_basedn(QUERY(CI_basename));
    DEBUGLOG("directory successfully opened");
    if(QUERY(CI_close_dir) && (QUERY(CI_access_mode) != "user"))
	call_out(close_dir,QUERY(CI_timer));
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

string *userinfo (string u,mixed p) {
    string *dirinfo;
    object results;
    mixed err;
    mapping(string:array(string)) tmp;

    DEBUGLOG ("userinfo ("+u+")");
    //DEBUGLOG (sprintf("DEB:%O\n",p));
    if (u == "A. Nonymous") {
      DEBUGLOG ("A. Nonymous pseudo user catched and filtered.");
      return 0;
    }

    if (QUERY(CI_use_cache))
	dirinfo=cache_lookup("ldapauthentries",u);
	if (dirinfo)
	    return dirinfo;

    open_dir(u, p);

    if (!dir) {
	werror ("LDAPauth: Returning 'user unknown'.\n");
	return 0;
    }

    if(QUERY(CI_access_type) == "search") {
	string rpwd = "";

	err = catch(results=dir->search(replace(QUERY(CI_search_templ), "%u%", u)));
	if (err || !objectp(results) || !results->num_entries()) {
	    DEBUGLOG ("no entry in directory, returning unknown");
	    if(access_mode_is_guest() && objectp(dir)) {
		catch(dir->unbind());
		dir=0;
	    }
	    return 0;
	}
	tmp=results->fetch();
	//DEBUGLOG(sprintf("userinfo: got %O",tmp));
	if(access_mode_is_user()) {	// mode is 'guest'
	    if(zero_type(tmp["userpassword"]))
		werror("LDAPuserauth: WARNING: entry haven't 'userpassword' attribute !\n");
	    else
		rpwd = tmp->userpassword[0];
	} else
	    rpwd = stringp(p) ? p : "{x-hop}*";
	dirinfo= ({
		u, 			//tmp->uid[0],
		rpwd,
		get_attrval(tmp, QUERY(CI_default_attrname_uid), QUERY(CI_default_uid)),
		get_attrval(tmp, QUERY(CI_default_attrname_gid), QUERY(CI_default_gid)),
		get_attrval(tmp, QUERY(CI_default_attrname_gecos), QUERY(CI_default_gecos)),
		QUERY(CI_default_addname) ? QUERY(CI_default_home)+u : get_attrval(tmp, QUERY(CI_default_attrname_homedir), ""),
		get_attrval(tmp, QUERY(CI_default_attrname_shell), QUERY(CI_default_shell))
	});
    } else {
	// Compare method is unimplemented, yet
    }
    #if 0
    if (QUERY(CI_use_cache))
	cache_set("ldapauthentries",u,dirinfo);
    #endif
    if(QUERY(CI_access_mode) == "user") { // Should be 'closedir' method?
      dir->unbind();
      dir=0;
    }

    if(zero_type(uids[(string)dirinfo[2]]))
	uids = uids + ([ dirinfo[2] : ({ dirinfo[0] }) ]);
    else
	uids[dirinfo[2]] = uids[dirinfo[2]] + ({dirinfo[0]});
#if 0
    if(zero_type(gids[(string)dirinfo[3]]))
	gids = ([ dirinfo[3]:({dirinfo[0]}) ]);
    else
	gids[dirinfo[3]] = gids[dirinfo[3]] + ({dirinfo[0]});
#endif // FIXME: hacked - returns gidname = uidname !!!

    //DEBUGLOG(sprintf("Result: %O",dirinfo)-"\n");
    return dirinfo;
}

string *userlist() {

    //if (QUERY(disable_userlist))
    return ({});
}

string user_from_uid (int u) 
{

    if(!zero_type(uids[(string)u]))
	return(uids[(string)u][0]);
    return 0;
}

#if LOG_ALL
int chk_name(string x, string y) {

    return(x == y);
}
#endif

array|int auth (string *auth, object id)
{
    string u,p,*dirinfo, pw;
    mixed attr,value;
    mixed err;

    att++;

    sscanf (auth[1],"%s:%s",u,p);

#if LOG_ALL
    if(!zero_type(accesses[id->remoteaddr]) && !zero_type(accesses[id->remoteaddr]["cnt"])) {
      accesses[id->remoteaddr]->cnt++;
      if(Array.search_array(accesses[id->remoteaddr]->name, chk_name, u) < 0)
	accesses[id->remoteaddr]->name = accesses[id->remoteaddr]->name + ({ u });
    } else
      accesses[id->remoteaddr] = (["cnt" : 1, "name":({ u })]);
#endif
    if (!p||!strlen(p)) {
	DEBUGLOG ("no password supplied by the user");
	failed[id->remoteaddr]++;
	roxen->quick_ip_to_host(id->remoteaddr);
	return ({0, auth[1], -1});
    }

    dirinfo=userinfo(u,p);
    if (!dirinfo||!sizeof(dirinfo)) {
	//DEBUGLOG ("password check ("+dirinfo[1]+","+p+") failed");
	DEBUGLOG ("password check failed");
	DEBUGLOG ("no such user");
	nouser++;
	failed[id->remoteaddr]++;
	roxen->quick_ip_to_host(id->remoteaddr);
	return ({0,u,p});
    }
    if(dirinfo[1] == "{x-hop}*")  // !!!! HACK
	dirinfo[1] = p;
    if(p != dirinfo[1]) {
	// <- Zapracovat  {CRYPT} a {SHA1} !!!
	DEBUGLOG ("password check ("+dirinfo[1]+","+p+") failed");
	//fail++;
	failed[id->remoteaddr]++;
	roxen->quick_ip_to_host(id->remoteaddr);
	return ({0,u,p});
    }

    if(!access_mode_is_user()) {
	// Check for the Atributes
	if(sizeof(QUERY(CI_required_attr))) {
	    attr=QUERY(CI_required_attr);
	    if (dirinfo[7][attr]) {
		mixed d;
		d=dirinfo[7][attr];
		// werror("User "+u+" has attr "+attr+"\n");
		if(sizeof(QUERY(CI_required_value))) {
		    mixed temp;
		    int found=0;
		    value=QUERY(CI_required_value);
		    foreach(d, mixed temp) {
			// werror("Looking at "+temp+"\n");
			if (search(temp,value)!=-1)
			    found=1;
		    }
		    if (found) {
			// werror("User "+u+" has value "+value+"\n");
		    } else {
			werror("User "+u+" has not value "+value+"\n");
			failed[id->remoteaddr]++;
			roxen->quick_ip_to_host(id->remoteaddr);
			return ({0,u,p});
		    }
		}
	    } else {
		werror("User "+u+" has no attr "+attr+"\n");
		failed[id->remoteaddr]++;
		roxen->quick_ip_to_host(id->remoteaddr);
		return ({0,u,p});
	    }

	}
    } // if access_mode_is_user

    // Its OK so save them
    if (QUERY(CI_use_cache))
	cache_set("ldapauthentries",u,dirinfo);

    id->misc->uid = dirinfo[2];
    id->misc->gid = dirinfo[3];
    id->misc->gecos = dirinfo[4];
    id->misc->home = dirinfo[5];
    id->misc->shell = dirinfo[6];

    DEBUGLOG (u+" positively recognized");
    succ++;
    return ({1,u,0});
}



/*
 * Registration and initialization
 */

array register_module()
{

    return(({ MODULE_AUTH || MODULE_EXPERIMENTAL,
	"LDAP directory authorization",
	"Experimental module for authorization using "
	"Pike's internal Ldap directory interface."
	"<p>&copy; 1998,99 Honza Petrous (with enhancements by Wim Bonis)<br>"
	"distributed freely under GPL license.",

	({}), 1 }));
}


