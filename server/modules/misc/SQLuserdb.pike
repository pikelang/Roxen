/* This code is (C) 1997 Francesco Chemolli <kinkie@comedia.it>
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

string cvs_version="$Id: SQLuserdb.pike,v 1.3 1997/12/16 16:18:21 grubba Exp $";

//#define SQLAUTHDEBUG

#include <module.h>
inherit "roxenlib";
inherit "module";

#ifdef SQLAUTHDEBUG
#define DEBUGLOG(X) perror("SQLuserdb: "+X+"\n");
#else
#define DEBUGLOG(X)
#endif

int att=0, succ=0, nouser=0, db_accesses=0, last_db_access=0;
object db=0;

/*
 * Utilities
 */

/*
 * Object management and configuration variables definitions
 */
void create() 
{
	defvar ("sqlserver","localhost","SQL server: Location",
			TYPE_STRING, "This is the host running the SQL server with the "
			"authentication information"
			);
	defvar ("database","passwd","SQL server: Database name",
			TYPE_STRING, "This is the name of the authorizations database"
			);
	defvar ("dbuser","","SQL server: Database user's username",
			TYPE_STRING, "This username will be used to authenticate when "
			"connecting to the SQL server. Refer to your SQL server documentation, "
			"this could be irrelevant."
			);
	defvar ("dbpass","", "SQL server: Database user's password",TYPE_STRING,
			"This is the password used to authenticate the server when accessing "
			"the database. Refer to your SQL server documentation, this could be "
			"irrelevant"
			);
	defvar ("table","passwd","SQL server: Passwords table",TYPE_STRING,
			"This is the table containing the data. It is  advisable not "
			"to change it once the service has been started."
			);
	defvar ("disable_userlist",0,"Disable Userlist",TYPE_FLAG,
			"If this is turned on, the module will NOT honor userlist answers. "
			"Those are used if you have an user filesystem, and try to access "
			"its mountpoint. It is recommended to turn this on if you have huge "
			"users databases, since that feature would require much memory.");
	defvar ("usecache",1,"Cache entries", TYPE_FLAG,
			"This flag defines whether the module will cache the database "
			"entries. Makes accesses faster, but changes in the database will "
			"not show immediately. <B>Recommended</B>."
			);
	defvar ("closedb",1,"Close the database if not used",TYPE_FLAG,
			"Setting this will save one filedescriptor without a small "
			"performance loss."
			);
	defvar ("timer",60,"Database close timer", TYPE_INT,
			"The timer after which the database is closed",0,
			lambda(){return !QUERY(closedb);}
			);
	defvar ("defaultuid",geteuid(),"Defaults: User ID", TYPE_INT,
			"Some modules require an user ID to work correctly. This is the "
			"user ID which will be returned to such requests if the information "
			"is not supplied by the database."
			);
	defvar ("defaultgid", getegid(), "Defaults: Group ID", TYPE_INT,
			"Same as User ID, only it refers rather to the group."
			);
	defvar ("defaultgecos", "", "Defaults: Gecos", TYPE_STRING,
			"The default Gecos."
			);
	defvar ("defaulthome","/", "Defaults: Home Directory", TYPE_DIR, 
			"It is possible to specify an user's home "
			"directory in the passwords database. This is used if it's "
			"not provided."
			);
	defvar ("defaultshell", "/bin/sh", "Defaults: Login Shell", TYPE_FILE,
			"Same as the default home, only referring to the user's login shell."
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
		db=Sql.sql(QUERY(sqlserver),QUERY(database),QUERY(dbuser),QUERY(dbpass));
	};
	if (err) {
		perror ("SQLauth: Couldn't open authentication database!\n");
		if (db)
			perror("SQLauth: database interface replies: "+db->error()+"\n");
		else
			perror("SQLauth: unknown reason\n");
		perror ("SQLauth: check the values in the configuration interface, and "
				"that the user\n\trunning the server has adequate permissions to the "
				"server\n");
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
string *userinfo (string u) {
	string *dbinfo;
	array sql_results;
	mixed err,tmp;
	DEBUGLOG ("userinfo ("+u+")");

	if (QUERY(usecache))
		dbinfo=cache_lookup("sqlauthentries",u);
	if (dbinfo)
		return dbinfo;

	open_db();

	if (!db) {
		perror ("SQLauth: Returning 'user unknown'.\n");
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
		cache_set("sqlauthentries",u,dbinfo);
	DEBUGLOG(sprintf("Result: %O",dbinfo)-"\n");
	return dbinfo;
	return 0;
}

string *userlist() {
	if (QUERY(disable_userlist))
		return ({});
	mixed err,tmp;
	array data;

	DEBUGLOG ("userlist()");
	open_db();
	if (!db) {
		perror ("SQLauth: returning empty user index!\n");
		return ({});
	}
	data=db->query("select username from "+QUERY(table));
	foreach(data,tmp)
		data=tmp->username;
	return data;
}

string user_from_uid (int u) 
{
	array data;
	if(!u)
		return 0;
	open_db(); //it's not easy to cache in this case.
	if (!db) {
		perror("SQLauth: returning no_such_user\n");
		return 0;
	}
	data=db->query("select username from "+QUERY(table)+" where uid=u");
	if(sizeof(data)!=1) //either there's noone with that uid or there's many
		return 0;
	return data[0]->username;
}

array|int auth (string *auth, object id)
{
	string u,p,*dbinfo;
	mixed err;

	att++;
	DEBUGLOG (sprintf("auth(%O)",auth)-"\n");

	sscanf (auth[1],"%s:%s",u,p);

	if (!p||!strlen(p)) {
		DEBUGLOG ("no password supplied by the user");
		return ({0, auth[1], -1});
	}

	if (QUERY(usecache))
		dbinfo=cache_lookup("sqlauthentries",u);

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

	if(!crypt (p,dbinfo[1])) {
		DEBUGLOG ("password check ("+dbinfo[1]+","+p+") failed");
		return ({0,u,p});
	}

	DEBUGLOG (u+" positively recognized");
	succ++;
	return ({1,u,0});
}

/*
 * Support Callbacks
 */
string status() {
	return "<H2>Security info</H2>"
			"Attempted authentications: "+att+"<BR>\n"
			"Failed: "+(att-succ+nouser)+" ("+nouser+" because of wrong username)"
			"<BR>\n"+
			db_accesses +" accesses to the database were required.<BR>\n"
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

array register_module() {
	return ({
	MODULE_AUTH,
	"SQL user database",
	"This module implements user authentication via a SQL server.<p>\n "
	"For setup instruction, see the comments at the beginning of the module "
	"code.<P>"
	"&copy; 1997 Francesco Chemolli, distributed freely under GPL license.",
	0,
	1
	});
};
