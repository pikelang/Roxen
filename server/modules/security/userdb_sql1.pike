inherit UserDB;
constant name = "sql";

inherit "module";
#include <module.h>

static int inited;

constant cvs_version =
  "$Id: userdb_sql1.pike,v 1.2 2004/05/23 14:14:41 _cvs_dirix Exp $";

constant module_type = MODULE_USERDB | MODULE_TAG;
constant module_name = "Authentication: SQL extuser database";
constant module_doc  = "This module implements an extended user"
			     " database via an SQL server.\n";

// ----------------- Entities ----------------------

class EntityExtDB {
  inherit RXML.Value;
  static string idx;
  void create(string i) {
    idx=i;
  }
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name, void|RXML.Type type) {
    c->id->misc->cacheable=0;
    User u = c->id->conf->authenticate( c->id );
    return u?ENCODE_RXML_TEXT(
	idx=="gecos"?u->gecos():
	idx=="homedir"?u->homedir():
	 (string)u->gid(),type):RXML.nil;
  }
}

mapping client_scope=([
  "edb_owner":EntityExtDB("gecos"),
  "edb_parent":EntityExtDB("gid"),
  "edb_function":EntityExtDB("homedir"),
]);

void set_entities(RXML.Context c) {
  c->extend_scope("client", client_scope);
}

// ----------------- Rest ----------------------

static int successuc,badpass,baduser,successcached;

string status() {
  return sprintf("Authenticated: %d<br>"
		 "Wrong password: %d<br>"
                 "Wrong username: %d<br>"
		 "Authenticated and cached: %d",
		 successuc,badpass,baduser,successcached);
}
  
class SqlUser
{
  inherit User;
  static mapping ent;

  string name()             { return ent->id; }
  string crypted_password() { return ent->password; }
  int    uid()              { return (int)ent->id; }
  int    gid()              { return (int)ent->parent; }
  string gecos()            { return ent->owner; }
  string real_name()        { return ent->rootuser; }
  string homedir()          { return ent["function"]; }
  string shell()            { return ent->nick&&ent->nick>""
				 ?ent->nick:ent->id; }

  array(string) groups()
  {
    return get_user_groups( uid() );
  }

  int password_authenticate(string password)
  //! Return 1 if the password is correct, 0 otherwise.
  { int retval;
    string ip=ent->ip;
    if(ip)
      m_delete(ent,"ip");
    if(!inited||!sizeof(password))	// empty passwords not allowed
      return 0;
    switch(query("passwd_type")) {
      case "password":
	retval=sizeof(sql_query("SELECT PASSWORD(%s) as psw WHERE psw=%s",
				password,crypted_password()));
	break;
      case "crypt":
	retval=(crypt(password, crypted_password()));
	break;
      case "clear text":
	retval=(password == crypted_password());
	break;
#if constant(Crypto.crypt_md5)
      case "md5 crypt":
	retval=Crypto.crypt_md5( password, crypted_password()) == crypted_password();
	break;
#endif
    }
    if(retval) {
      if(ip) {
	array r;
	int secs;
        string u=real_name()||(string)uid();
	successuc++;
	r=sql_query("SELECT UNIX_TIMESTAMP(NOW())"
	    " -UNIX_TIMESTAMP(lastactive) AS ds"
	  "\nFROM statehist WHERE id=%s AND historyidx=0",u);
	if (sizeof(r))
	  secs=(int)r[0]->ds;
	else
	  secs=(int)QUERY(nextsession)+1;
	if (secs>(int)QUERY(nextsession)) {
	  string maxses=(string)((int)QUERY(maxsessions)*2);
	  sql_query("UPDATE IGNORE statehist "
	      " SET historyidx=historyidx+3,lastactive=lastactive "
	      " WHERE id=%s AND ( historyidx<%s OR UNIX_TIMESTAMP(lastactive)"
	      "-UNIX_TIMESTAMP(firstactive)>=%d<<(historyidx-%s>>1) AND "
	      " historyidx-%s<16*2 )",
		u,maxses,QUERY(coalesce),maxses,maxses);
	  sql_query("UPDATE IGNORE statehist "
	      " SET historyidx=historyidx-1,lastactive=lastactive "
	      " WHERE id=%s AND historyidx&1", u);
	  sql_query("INSERT INTO statehist (id,lastactive,firstactive,ip)"
	      " VALUES (%s,NULL,NULL,%s)",u,ip);
	  sql_query("CREATE TEMPORARY TABLE tstate ( "
	      " historyidx tinyint unsigned not null, "
	      " lastactive timestamp not null,"
	      " firstactive timestamp not null,"
	      " secondsused mediumint not null,"
	      " ip varchar(32) not null)");
	  sql_query("INSERT INTO tstate "
	      " SELECT historyidx&~1 AS historyidx,"
	      "MAX(lastactive) AS lastactive,"
	      "MIN(firstactive) AS firstactive,"
	      "SUM(secondsused) AS secondsused, ip"
	      " FROM statehist WHERE id=%s AND "
	      " historyidx>=%s GROUP BY historyidx&~1 HAVING COUNT(*)>1",
		u,maxses);
	  sql_query("DELETE FROM statehist "
	      " WHERE id=%s AND ( historyidx&1 OR historyidx-%s>16*2)",
		u,maxses);
	  sql_query("REPLACE INTO statehist "
	      "SELECT %s AS id,tstate.* FROM tstate",u);
	  sql_query("DROP TABLE tstate");
	} else {
	  if (secs>(int)QUERY(sessiongap))
	    secs=(int)QUERY(usecache)/2;
	  if (secs)
	    sql_query("UPDATE statehist "+
	      "\nSET secondsused=secondsused+%d ,lastactive=NULL "
		"WHERE id=%s AND historyidx=0",
		secs,u);
	}
      } else
	successcached++;
    } else
      badpass++;
    return retval;
  }

  static void create( UserDB p, mapping e )
  {
    ::create( p );
    ent = e;
  }
}

class SqlGroup
{
  inherit Group;
  static mapping ent;

  int gid() { return (int)ent->id; }
  string name() { return ent->nick>""?ent->nick:ent->id; }
  array(string) members()
  {
    return get_group_users( gid() );
  }

  static void create( UserDB p, mapping e )
  {
    ::create( p );
    ent = e;
  }
}

constant db_defs =
([
  "namedata":({
    "id        int unsigned not null auto_increment primary key",
    "owner     int unsigned not null",
    "parent    int unsigned not null",
    "password  char(16) not null",
    "nick      varchar(32) not null",
    "function  enum('user','root')",
    "key(parent)",
    "key(owner)",
    "key(nick)",
  }),
  "statehist":({
    "id          int not null",
    "historyidx  tinyint unsigned not null",
    "lastactive  timestamp not null",
    "firstactive timestamp not null",
    "secondsused mediumint not null",
    "ip          varchar(32) not null",
    "unique key(id,historyidx)",
  }),
]);
  
array(string) get_user_groups( int user )
{
  if(!inited) return ({});
  return 
    sql_query( "SELECT "
	       "  IF(gr.nick>'',gr.nick,gr.id) as name "
	       "FROM namedata AS nd, namedata AS gr "
	       "WHERE "
	       "  nd.id=%d AND gr.id=nd.parent "
	       "LIMIT 1", user )
    ->name;
}

array(string) get_group_users( int group )
{
  if(!inited) return ({});
  return 
    sql_query( "SELECT "
	       "  IF(nick>'',nick,id) as name FROM namedata "
	       "WHERE "
	       "  parent=%d AND function IS NULL ", group )
    ->name;
}

User find_user( string s, RequestID id )
{
  string cachemap="edb_"+query("db");;
  ;{ User fcache;
     if( fcache=cache_lookup(cachemap, s))
       return fcache;
   }
  if(!inited) return 0;
  string superuser,usrname,passwrd;
  array r;
  usrname=s;
  if(2==sscanf( s, "%s.%s", superuser, usrname)) {
    r = sql_query("SELECT password FROM namedata "
                  "WHERE function='root' AND "+
                  " ( id=%s OR %s>'' AND nick=%s ) "
		  "LIMIT 1",superuser,superuser,superuser);
    if ( sizeof( r ) )
      passwrd=r[0]->password;
  }
  r = sql_query( "SELECT id,password,parent,owner,function,nick "
		 "FROM namedata WHERE ( id=%s OR "
		 " %s>'' AND nick=%s ) "
		 " AND function IS NOT NULL LIMIT 1",
		usrname,usrname,usrname);
  if( sizeof( r ) ) {
    User ucache;
    if (passwrd)
      r[0]->password=passwrd,r[0]+=(["rootuser":superuser]);
    ucache=SqlUser( this, r[0]);
    cache_set(cachemap, s, ucache, QUERY(usecache));
    return SqlUser( this, r[0]+(["ip":id->remoteaddr]));
  }
  baduser++;
}

User find_user_from_uid( int id )
{
  if(!inited) return 0;
  array r = sql_query( "SELECT id,password,parent,owner,function,nick "
		       "FROM namedata WHERE id=%d "
		       " AND function IS NOT NULL "
		       " LIMIT 1", id );
  if( sizeof( r ) )
    return SqlUser( this, r[0] );
}

array(string) list_users( )
{
  if(!inited) return ({});
  return sql_query( "SELECT IF(nick>'',nick,id) AS name FROM namedata "
		    "WHERE function IS NOT NULL" )->name;
}

Group find_group( string s )
{
  if(!inited) return 0;
  array r = sql_query( "SELECT id,parent,owner,nick "
		       "FROM namedata WHERE ( id=%s OR "
		       " %s>'' AND nick=%s ) "
		       " AND function IS NULL LIMIT 1", s );
  if( sizeof( r ) )
    return SqlGroup( this, r[0] );
}

Group find_group_from_gid( int i )
{
  if(!inited) return 0;
  array r = sql_query( "SELECT id,parent,owner,nick "
		       "FROM namedata WHERE id=%d "
		       " AND function IS NULL "
		       " LIMIT 1", i );
  if( sizeof( r ) )
    return SqlGroup( this, r[0] );
}

array(string) list_groups( )
{
  if(!inited) return ({});
  return sql_query( "SELECT IF(nick>'',nick,id) AS name FROM namedata "
		    "WHERE function IS NULL" )->name;
}


void start()
{
  if( !DBManager.get( query("db"), my_configuration() ) )
  {
    if( DBManager.get( query("db") ) )
    {
      inited = 0;
      report_error( query("db")+
		    " exists, but cannot be written to from this module" );
      return;
    }
    DBManager.create_db( query("db"), 0, 1 );
    DBManager.is_module_db( this_module(), query("db"),
			    "This database contains the user database" );
    DBManager.set_permission( query("db"), my_configuration(), DBManager.WRITE );
  }
  set_my_db( query("db") );
  create_sql_tables( db_defs, "User2 database table", 1 );
  inited = 1;
  query_tag_set()->prepare_context=set_entities;
}

class DatabaseVar
{
  inherit Variable.StringChoice;
  array get_choice_list( )
  {
    return sort(DBManager.list( my_configuration() ));
  }
}

void create()
{
  defvar( "db",
          DatabaseVar( "sql_users",({}),0,
                       "Database",
                       "This is the database that this module will "
			      "store it's users in.") );

  defvar( "passwd_type",
          Variable.StringChoice("password",
				([
				  "password":"MySQL Password",
				  "crypt":"Unix crypt",
				  "clear text":"Clear text",
#if constant(Crypto.MD5)
				  "md5 crypt":"MD5 crypt",
#endif
				]), 0,
				"Password type",
				"Password hashing method. "
				  "By changing this variable you can "
				  "select the meaning of password field. "
				  "By default the passwords are supposed "
				  "to be hashed by internal MySQL PASSWORD() "
				  "function."
				));

  defvar ("nextsession", 2048, "Next session",
          TYPE_INT,
          "When more than nextsession seconds have passed since the last "
          "update, it is considered to be a new session." );

  defvar ("sessiongap", 512, "Sessiongap",
          TYPE_INT,
          "When more than sessiongap seconds have passed since the last "
          "update, a attentiongap is assumed to have taken place." );

  defvar ("coalesce", 86400, "Coalesce starting with",
          TYPE_INT,
          "Time in seconds in excess of maxsessions will start to "
          "be coalesced." );

  defvar ("maxsessions", 16, "Maximum session history",
          TYPE_INT,
          "No more than maxsessions (<=64) sessions will be remembered.");

  defvar ("usecache", 16, "Cacheentry timeout",
          TYPE_INT,
          "The module will cache database entries for this many seconds."
          "If set to zero "
          "the module might well needs to make a database query per "
          "access. This option is therefore highly recommended. The "
          "drawback is changes to the database will not show up "
          "immediately." );
}
