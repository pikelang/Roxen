// This is a ChiliMoon module which provides an extended user database
// utilising a PostsreSQL database.
// Copyright (c) 2002-2005, Stephen R. van den Berg, The Netherlands.
//                         <srb@cuci.nl>
//
// This module is open source software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
// by the Free Software Foundation; either version 2, or (at your option) any
// later version.
//

constant cvs_version =
 "$Id: userdb_sql2.pike,v 1.5 2005/11/26 15:01:51 _cvs_dirix Exp $";
constant thread_safe = 1;

#include <module.h>

inherit UserDB;
inherit "module";

constant module_type = MODULE_USERDB | MODULE_TAG;
constant module_name =
 "Authentication: PostgreSQL extended user database";
constant module_doc  = 
 "This module implements an extended user database via an SQL Server.<br>"
 "<p>Copyright &copy; 2002-2005, by "
 "<a href='mailto:srb@cuci.nl'>Stephen R. van den Berg</a>, "
 "The Netherlands.</p>"
 "<p>This module is open source software; you can redistribute it and/or "
 "modify it under the terms of the GNU General Public License as published "
 "by the Free Software Foundation; either version 2, or (at your option) any "
 "later version.</p>";

constant name = "edb_sql";

static int usecache;
static object cmdb;
object mdb;

class getdb
{ static int inuse;
  int dropdb;
  
  void create()
  { ;{ Thread.Mutex lock = Thread.Mutex();
       if(!(dropdb=inuse))
          inuse=1;
     }
    mdb=dropdb?DBManager.get(query("db"), my_configuration()):cmdb;
  }

  void destroy()
  { if(dropdb)
       destruct(mdb),mdb=0;
    else
       inuse=0;
  }
}

private void initvars() {
  if(catch {
    array r=
     mdb->query("SELECT vint FROM globals WHERE gname='usecache' LIMIT 1");
    if( r && sizeof(r))
      usecache=(int)r[0]->vint||1;
   })
    report_error("userdb_sql2 PostgreSQL database not properly initialised\n");
}

void create()
{
  set_module_creator("Stephen R. van den Berg <srb@cuci.nl>");
  defvar( "db",
   DatabaseVar( "sql_users",({}),0,
    "Database",
    "This is the database that this module will store it's users in."));
  defvar( "passwd_type",
   Variable.StringChoice("clear text",
	([
	  "clear text":"Clear text",
	  "crypt":"Unix crypt",
#if constant(Crypto.MD5)
	  "md5 crypt":"MD5 crypt",
#endif
	]), 0,
	"Password type",
	"Password hashing method. "
	  "By changing this variable you can "
	  "select the meaning of password field. "
	));
  defvar( "allowemptypassword",
   Variable.StringChoice("no",
	([
	  "yes":"Yes",
	  "no":"No",
	]), 0,
	"Allow emptypasswords",
	"By setting this to yes, users are permitted "
	  "to use empty passwords. "
	));
}

// ----------------- Entities ----------------------

class EntityExtDB {
  inherit RXML.Value;
  static string idx;
  void create(string i) {
    idx=i;
  }
  mixed rxml_const_eval(RXML.Context c, string var, string scope_name,
   void|RXML.Type type) {
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
  initvars();
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
  string shell()            { return ent->nick>""?ent->nick:ent->id; }

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
    if(!cmdb||("no"==QUERY(allowemptypassword)&&!sizeof(password)))
      return 0;
    getdb gdb=getdb();
    switch(query("passwd_type")) {
      case "password":
	retval=sizeof(mdb->query("SELECT PASSWORD(%s) as psw WHERE psw=%s",
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
	retval=
         Crypto.crypt_md5( password, crypted_password()) == crypted_password();
	break;
#endif
    }
    if(retval) {
      if(ip) {
	successuc++;
	mdb->query("SELECT updatestatehist(%s,%s) LIMIT 1",
          real_name()||(string)uid(),ip);
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
#if 0
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
    "creationdate timestamp not null",
    "secondsused mediumint not null",
    "ip          varchar(32) not null",
    "unique key(id,historyidx)",
  }),
#endif
]);
  
array(string) get_user_groups( int user )
{
  string cachemap="edb_"+query("db")+".ugs";
  array groups;
  if( groups=cache_lookup(cachemap, user))
    return groups;
  if(!cmdb)
    return ({});
  getdb gdb=getdb();
  groups=mdb->query( "SELECT CASE WHEN gr.nick>'' THEN gr.nick "
	       " ELSE TO_CHAR(gr.id,'FM999999999') END AS name "
	       "FROM namedata AS nd, namedata AS gr "
	       "WHERE nd.id=%d AND gr.id=nd.parent LIMIT 1", user )->name;
  cache_set(cachemap, user, groups, usecache);
  return groups;
}

array(string) get_group_users( int group )
{
  if(!cmdb)
    return ({});
  getdb gdb=getdb();
  return mdb->query( "SELECT CASE WHEN nick>'' THEN nick "
	       " ELSE TO_CHAR(id,'FM999999999') END AS name FROM namedata "
	       "WHERE parent=%d AND function IS NULL", group )->name;
}

User find_user( string s, RequestID id )
{
  string cachemap="edb_"+query("db");;
  ;{ User fcache;
     if( fcache=cache_lookup(cachemap, s))
       return fcache;
   }
  if(!cmdb) return 0;
  getdb gdb=getdb();
  string superuser,usrname,passwrd;
  array r;
  usrname=s;
  if(2==sscanf( s, "%s.%s", superuser, usrname)) {
    r = mdb->query("SELECT id,password FROM namedata "
                  "WHERE function=0 AND ( id=%d OR %s>'' AND nick=%s ) "
		  "LIMIT 1",(int)superuser,superuser,superuser);
    if ( sizeof( r ) ) {
      superuser=r[0]->id;
      passwrd=r[0]->password;
    }
  }
  r = mdb->query( "SELECT id,password,parent,owner,function,nick "
		 "FROM namedata WHERE ( id=%d OR %s>'' AND nick=%s ) "
		 " AND function IS NOT NULL LIMIT 1",
		(int)usrname,usrname,usrname);
  if( sizeof( r ) ) {
    User ucache;
    if (passwrd)
      r[0]->password=passwrd,r[0]+=(["rootuser":superuser]);
    ucache=SqlUser( this, r[0]);
    cache_set(cachemap, s, ucache, usecache);
    return SqlUser( this, id?r[0]+(["ip":id->remoteaddr]):r[0]);
  }
  baduser++;
}

User find_user_from_uid( int id )
{
  if(!cmdb) return 0;
  getdb gdb=getdb();
  array r = mdb->query( "SELECT id,password,parent,owner,function,nick "
		       "FROM namedata WHERE id=%d AND function IS NOT NULL "
		       "LIMIT 1", id );
  if( sizeof( r ) )
    return SqlUser( this, r[0] );
}

array(string) list_users( )
{
  if(!cmdb)
    return ({});
  getdb gdb=getdb();
  return
    mdb->query( "SELECT CASE WHEN nick>'' THEN nick "
		    " ELSE TO_CHAR(id,'FM999999999') END AS name FROM namedata "
		    "WHERE function IS NOT NULL" )->name;
}

Group find_group( string s )
{
  if(!cmdb) return 0;
  getdb gdb=getdb();
  array r = mdb->query( "SELECT id,parent,owner,nick FROM namedata "
		       "WHERE ( parent=%d )"
		       " AND function IS NULL LIMIT 1", (int)s );
  if( sizeof( r ) )
    return SqlGroup( this, r[0] );
}

Group find_group_from_gid( int i )
{
  if(!cmdb) return 0;
  getdb gdb=getdb();
  array r = mdb->query( "SELECT id,parent,owner,nick FROM namedata "
		       "WHERE id=%d AND function IS NULL LIMIT 1", i );
  if( sizeof( r ) )
    return SqlGroup( this, r[0] );
}

array(string) list_groups( )
{
  if(!cmdb)
    return ({});
  getdb gdb=getdb();
  return
    mdb->query( "SELECT CASE WHEN nick>'' THEN nick "
		    " ELSE TO_CHAR(id,'FM999999999') END AS name FROM namedata "
		    "WHERE function IS NULL" )->name;
}


void start()
{
  string db=query("db");
  if( !(cmdb=DBManager.get(db, my_configuration())))
  {
#if 0
    if( DBManager.get(db) )
    {
      cmdb = 0;
      report_error( db+" exists, but cannot be written to from this module\n" );
      return;
    }
    DBManager.create_db( db, 0, 1 );
    DBManager.is_module_db( this_module(), db,
			    "This database contains the user database" );
    DBManager.set_permission( db, my_configuration(), DBManager.WRITE );
#else
    return;
#endif
  }
  set_my_db(db);
  getdb gdb=getdb();
  create_sql_tables( db_defs, "Extended user database table", 1);
  query_tag_set()->prepare_context=set_entities;
  initvars();
}

class DatabaseVar
{
  inherit Variable.StringChoice;
  array get_choice_list( )
  {
    return sort(DBManager.list( my_configuration() ));
  }
}

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"&client.edb_function;":#"<desc type='entity'><p><short>
 Contains the function of the logged in person.</short>
 <i>root</i> has special priviliges and can login using
   <i>hislogin.someuserlogin</i> for the username and his
  own password to authenticate</i>.</p>
</desc>",
"&client.edb_parent;":#"<desc type='entity'><p><short>
 Contains the parent id the logged in person belongs to.</short>
 Typically this is the outlet the person is working.</p>
</desc>",
"&client.edb_owner;":#"<desc type='entity'><p><short>
 Contains the owner id the logged in person belongs to.</short>
 Typically this is the firm the person is working.</p>
</desc>",
]);
#endif

/* Minimal Tables needed for this module 			*

* First execute this script with superuser privileges:		
---------------------------------------------------------------------

(
plib=/usr/lib/postgresql
for clib in /lib/libc-*.*.*.so; do :; done
echo "
 CREATE OR REPLACE FUNCTION plpgsql_call_handler()
  RETURNS LANGUAGE_HANDLER AS '$plib/lib/plpgsql.so' LANGUAGE C;
 DROP LANGUAGE PLPGSQL CASCADE;
 CREATE TRUSTED PROCEDURAL LANGUAGE PLPGSQL
  HANDLER plpgsql_call_handler LANCOMPILER 'PL/pgSQL';
 CREATE OR REPLACE FUNCTION getpid() RETURNS INT AS
  '$clib','getpid' LANGUAGE C;
 CREATE OR REPLACE FUNCTION sleep(INT) RETURNS INT AS
  '$clib','sleep' LANGUAGE C;
"
cd /usr/share/postgresql/contrib
cat pgcrypto.sql tsearch.sql fuzzystrmatch.sql
cat xinetops.sql
) | psql template1 

---------------------------------------------------------------------
* Table globals
---------------------------------------------------------------------

gname		VARCHAR(32) NOT NULL PRIMARY KEY
vint		BIGINT
tstamp		TIMESTAMP WITH TIME ZONE
txt		VARCHAR(255)

---------------------------------------------------------------------
* Table namedata
---------------------------------------------------------------------


id		INT
nick		VARCHAR(32) UNIQUE
parent          INT REFERENCES namedata \
                         ON DELETE CASCADE ON UPDATE CASCADE \
                         DEFERRABLE INITIALLY DEFERRED
owner           INT REFERENCES namedata \
                         ON DELETE CASCADE ON UPDATE CASCADE \
                         DEFERRABLE INITIALLY DEFERRED
function         SMALLINT 0 owner, 1 employee, 2 supplier, 3 customer
password         VARCHAR(16)
changedby        INT REFERENCES namedata ON UPDATE CASCADE \
                         DEFERRABLE INITIALLY DEFERRED

---------------------------------------------------------------------
* Table statehist
---------------------------------------------------------------------

id		INT NOT NULL REFERENCES namedata \
                         ON DELETE CASCADE ON UPDATE CASCADE \
                         DEFERRABLE INITIALLY DEFERRED
ip              INET NOT NULL
lastactive      TIMESTAMP WITH TIME ZONE NOT NULL \
                         DEFAULT CURRENT_TIMESTAMP
secondsused     INT NOT NULL DEFAULT '0'

---------------------------------------------------------------------
* function updatestatehist(INT,INET)
---------------------------------------------------------------------

 RETURNS VOID AS '
DECLARE
 vid ALIAS FOR $1;
 vip ALIAS FOR $2;
 vlastactive TIMESTAMP WITH TIME ZONE;
 secs INT;
 nextsession INT;
 cp RECORD;
BEGIN
 SELECT INTO vlastactive,secs,nextsession
   sh.lastactive,
   CAST(EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)
    -EXTRACT(EPOCH FROM sh.lastactive) AS INT) AS ds,
   nextses.vint
  FROM globals AS nextses JOIN statehist AS sh ON sh.id=vid
  WHERE nextses.gname=''nextsession''
  ORDER BY sh.lastactive DESC
  LIMIT 1
  FOR UPDATE OF sh;
 IF secs IS NULL OR secs>nextsession
 THEN
  FOR cp IN SELECT sh.lastactive AS first,
    nsh.lastactive AS next, nsh.secondsused
   FROM statehist AS sh
    JOIN globals AS detaillog ON detaillog.gname=''detaillog''
    JOIN globals AS decay ON decay.gname=''decay''
    JOIN statehist AS nsh
     ON sh.id=vid AND nsh.id=vid
      AND sh.lastactive<CURRENT_TIMESTAMP
       -CAST(detaillog.vint||'' SECOND'' AS INTERVAL)
      AND sh.lastactive<nsh.lastactive
      AND sh.creationdate
       +CAST((EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)
       -EXTRACT(EPOCH FROM sh.creationdate))/decay.vint
       ||'' SECOND'' AS INTERVAL)>nsh.lastactive
   ORDER BY sh.lastactive DESC,nsh.lastactive
   LIMIT 2
  LOOP
   EXIT WHEN vlastactive=cp.next;
   vlastactive:=cp.next;
   UPDATE statehist
    SET secondsused=secondsused+cp.secondsused
    WHERE id=vid AND lastactive=cp.first;
   DELETE FROM statehist WHERE id=vid AND lastactive=cp.next;
  END LOOP;
  INSERT INTO statehist (id,ip) VALUES (vid,vip);
 ELSIF secs>0
 THEN
  UPDATE statehist
   SET secondsused=statehist.secondsused
     +CASE WHEN secs<=sessiongap.vint THEN secs ELSE usecache.vint/2 END,
    lastactive=CURRENT_TIMESTAMP
   FROM globals AS sessiongap,globals AS usecache
   WHERE sessiongap.gname=''sessiongap'' AND usecache.gname=''usecache''
    AND statehist.id=vid AND statehist.lastactive=vlastactive;
 END IF;
 RETURN;
END;
 ' LANGUAGE PLPGSQL STRICT;


--------------------------------------------------------------------*/


