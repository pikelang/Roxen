/* This code is (C) 1997 Francesco Chemolli <kinkie@kame.usr.dsi.unimi.it>
 * It can be freely distributed and copied under the terms of the
 * GNU General Public License.
 * This code comes with NO WARRANTY of any kind, either implicit or explicit.
 *
 * This module handles a SQL-based User Database. 
 * It uses the generic-SQL pike module, so it should run on any server
 * pike supports. This includes at least MiniSQL, MySql and Postgres (more
 * could be supported in the future)
 *
 * Documentation can be found at 
 * http://kame.usr.dsi.unimi.it:1111/sw/roxen/sqlauth/
 * or should have been shipped along with the module.
 */

constant cvs_version="$Id: SQLuserdb.pike,v 1.18 2000/04/09 10:58:24 kinkie Exp $";

#include <module.h>
inherit "roxenlib";
inherit "module";

#ifdef SQLAUTHDEBUG
#define DEBUGLOG(X) werror("SQLuserdb: "+X+"\n");
#else
#define DEBUGLOG(X)
#endif

int att=0, succ=0, nouser=0, db_accesses=0, last_db_access=0;
object db=0;

/*
 * Object management and configuration variables definitions
 */
void create() 
{
  defvar ("sqlserver", "localhost", "Database URL",
	  TYPE_STRING,
	  "This database to connect to as a database URL in the format"
	  "<br><tt>driver://user name:password@host:port/database</tt>.");

  defvar ("crypted",1,"Passwords are crypted",
          TYPE_FLAG|VAR_MORE,
          "If set, passwords are stored encrypted with the Unix "
	  "<i>crypt</i> funtion. If not, passwords are stored in clear "
	  "text. "
          );

  defvar ("table", "passwd", "Table",
	  TYPE_STRING,
	  "This is the table that contains the data. It must contain the "
	  "columns <i>username</i> and <i>passwd</i> and can contain the "
	  "optional columns <i>uid</i>, <i>gid</i>, <i>gecos</i> (the full "
	  "name of the user), <i>homedir</i> and <i>shell</i>. ");

  defvar ("disable_userlist", 0, "Disable user list",
	  TYPE_FLAG,
	  "If this is turned on, it won't be possible to get a listing "
	  "of all users. Usually the <i>User file system</i> module makes "
	  "it possible to list all users on the system. If you have "
	  "a large number of users this can take a lot of resourses." );

  defvar ("usecache", 1, "Cache entries",
	  TYPE_FLAG,
	  "If set, the module will cache database entries. Without this "
	  "cache the module might well needs to make a database query per "
	  "access. This option is therefore highly recommended. The "
	  "drawback is changes to the database will not show up "
	  "immediately." );

  defvar ("closedb", 1, "Close the database if not used", TYPE_FLAG,
	  "This option closes the database connection upon to long "
	  "inactivity. Saves resourses for sites that are not used "
	  "very frequently.");

  defvar ("timer", 60, "Database close timeout", TYPE_INT,
	  "The inactivity time, in seconds, before the database connection "
	  "is closed.",0,
	  lambda(){return !QUERY(closedb);}
	  );

  defvar ("defaultuid",
#if efun(geteuid)
	  geteuid()
#else
	  0
#endif	  
	  , "Defaults: User ID", TYPE_INT,
	  "This is the uid that will be returned if a uid field is not "
	  "present in the database table."
	  );

  defvar ("defaultgid", getegid(), "Defaults: Group ID", TYPE_INT,
	  "This is the gid that will be returned is a gid field is not "
	  "present in the database table."
	  );

  defvar ("defaultgecos", "", "Defaults: Gecos", TYPE_STRING,
	  "This is the gecos that will be returned if a gecos field is "
	  "not present in the database table."
	  );

  defvar ("defaulthome", "/", "Defaults: Home directory", TYPE_DIR, 
	  "This is the home directory that will be returned if a "
	  "<i>homedir</i> field is not present in the database table."
	  );

  defvar ("defaultshell", "/bin/sh", "Defaults: Login shell", TYPE_FILE,
	  "This is the login shell that will be returned if a <i>shell</i> "
	  "field is not present in the database table."
	  );
}

/*
 * DB management functions
 */
//this gets called only by call_outs, so we can avoid storing call_out_ids
//Also, I believe storing in a local variable the last time of an access
//to the database is more efficient than removing and resetting call_outs
//This leaves a degree of uncertainty on when the DB will be effectively
//closed, but it's below the value of the module variable "timer" for sure.
void close_db() {
	if (!QUERY(closedb))
		return;
	if( (time(1)-last_db_access) > QUERY(timer) ) {
		db=0;
		DEBUGLOG("closing the database");
		return;
	}
	call_out(close_db,QUERY(timer));
}

void open_db() {
  mixed err;
  last_db_access=time(1);
  db_accesses++; //I count DB accesses here, since this is called before each
  if(objectp(db)) //already open
    return;
  err=catch{
    db=Sql.sql(QUERY(sqlserver));
  };
  if (err) {
    report_debug("SQLauth: Couldn't open authentication database!\n");
    if (db)
      report_debug("SQLauth: database interface replies: "+db->error()+"\n");
    else
      report_debug("SQLauth: unknown reason\n");
    report_debug("SQLauth: check the values in the administration interface, and "
		 "that the user\n\trunning the server has adequate permissions "
		 "to the server\n");
    db=0;
    return;
  }
  DEBUGLOG("database successfully opened");
  if(QUERY(closedb))
    call_out(close_db,QUERY(timer));
}

/*
 * Module Callbacks
 */
array(string) userinfo (string u) {
	array(string) dbinfo;
	array sql_results;
	mixed err,tmp;
	DEBUGLOG ("userinfo ("+u+")");

	if (QUERY(usecache))
		dbinfo=cache_lookup("sqlauth"+QUERY(table),u);
	if (dbinfo)
		return dbinfo;

	open_db();

	if (!db) {
		report_debug("SQLauth: Returning 'user unknown'.\n");
		return 0;
	}
	sql_results=db->query("select username,passwd,uid,gid,homedir,shell "
			"from "+QUERY(table)+" where username='"+u+"'");
	if (!sql_results||!sizeof(sql_results)) {
		DEBUGLOG ("no entry in database, returning unknown")
		return 0;
	}
	tmp=sql_results[0];
//	DEBUGLOG(sprintf("userinfo: got %O",tmp));
	dbinfo= ({
			u,
			tmp->passwd,
			tmp->uid||QUERY(defaultuid),
			tmp->gid||QUERY(defaultgid),
			QUERY(defaultgecos),
			tmp->homedir||QUERY(defaulthome),
			tmp->shell||QUERY(defaultshell)
			});
	if (QUERY(usecache))
		cache_set("sqlauth"+QUERY(table),u,dbinfo);
	DEBUGLOG(sprintf("Result: %O",dbinfo)-"\n");
	return dbinfo;
	return 0;
}

array(string) userlist() {
	if (QUERY(disable_userlist))
		return ({});
	mixed err;
	array data;
  int j;

	DEBUGLOG ("userlist()");
	open_db();
	if (!db) {
		report_debug("SQLauth: returning empty user index!\n");
		return ({});
	}
	data=db->query("select username from "+QUERY(table));
  for (j=0;j<sizeof(data);j++)
    data[j]=data[j]->username;
  DEBUGLOG(sprintf("%O",data));
	return data;
}

string user_from_uid (int u) 
{
	array data;
	if(!u)
		return 0;
	open_db(); //it's not easy to cache in this case.
	if (!db) {
		report_debug("SQLauth: returning no_such_user\n");
		return 0;
	}
	data=db->query("select username from " + QUERY(table) +
		       " where uid='" + (int)u +"'");
	if(sizeof(data)!=1) //either there's noone with that uid or there's many
		return 0;
	return data[0]->username;
}

array|int auth (array(string) auth, object id)
{
	string u,p;
	array(string) dbinfo;
	mixed err;

	att++;
	DEBUGLOG (sprintf("auth(%O)",auth)-"\n");

	sscanf (auth[1],"%s:%s",u,p);

	if (!p||!strlen(p)) {
		DEBUGLOG ("no password supplied by the user");
		return ({0, auth[1], -1});
	}

	if (QUERY(usecache))
		dbinfo=cache_lookup("sqlauth"+QUERY(table),u);

	if (!dbinfo) {
		open_db();

		if(!db) {
			DEBUGLOG ("Error in opening the database");
			return ({0, auth[1], -1});
		}
		dbinfo=userinfo(u); //cache is already set by userinfo
	}

	// I suppose that the user's password is at least 1 character long
	if (!dbinfo) {
		DEBUGLOG ("no such user");
		nouser++;
		return ({0,u,p});
	}
  
  if (QUERY(crypted)) {
    if (!crypt (p,dbinfo[1])) {
      DEBUGLOG ("password check ("+dbinfo[1]+","+p+") failed");
      return ({0,u,p});
    }
  } else {
    if (p != dbinfo[1]) {
      DEBUGLOG ("clear password check (XXX,"+p+") failed");
      return ({0,u,p});
    }
  }

	DEBUGLOG (u+" positively recognized");
	succ++;
	id->misc+=mkmapping(
			({"uid","gid","gecos","home","shell"}),
			dbinfo[2..6]
			);
	return ({1,u,0});
}

/*
 * Support Callbacks
 */
string status() {
	return "<h2>Security info</h2>"
			"Attempted authentications: "+att+"<br />\n"
			"Failed: "+(att-succ+nouser)+" ("+nouser+" because of wrong username)"
			"<br />\n"+
			db_accesses +" accesses to the database were required.<br />\n"
			;
}

string|void check_variable (string name, mixed newvalue)
{
	switch (name) {
		case "timer":
			if (((int)newvalue)<=0) {
				set("timer",QUERY(timer));
				return "What? Have you lost your mind? How can I close the database"
					" before using it?";
			}
			return 0;
		default:
			return 0;
	}
	return 0; //should never reach here...
}

constant module_type = MODULE_AUTH;
constant module_name = "SQL user database";
constant module_doc  = "This module implements user authentication via a SQL server.\n"
  "<p>For setup instruction, see the comments at the beginning of the module "
  "code.</p>"
  "&copy; 1997 Francesco Chemolli, distributed freely under GPL license.";
