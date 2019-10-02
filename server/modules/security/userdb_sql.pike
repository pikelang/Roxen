//<locale-token project="mod_userdb_sql">_</locale-token>
#define _(X,Y)	_DEF_LOCALE("mod_userdb_sql",X,Y)

inherit UserDB;
constant name = "sql";

inherit "module";
#include <module.h>

int inited;

constant cvs_version =
  "$Id$";

LocaleString module_name = _(1,"Authentication: SQL user database");
LocaleString module_doc  = _(2,"This module implements a user database via "
			     "a SQL server.\n");

class SqlUser
{
  inherit User;
  protected mapping ent;

  string name()             { return ent->name; }
  string crypted_password() { return ent->password; }
  int    uid()              { return (int)ent->uid; }
  int    gid()              { return (int)ent->gid; }
  string gecos()            { return ent->gecos || ent->name; }
  string real_name()        { return (gecos()/",")[0]; }
  string homedir()          { return ent->homedir; }
  string shell()            { return ent->shell; }

  array(string) groups()
  {
    return get_user_groups( uid() );
  }

  int password_authenticate(string password)
  // Return 1 if the password is correct, 0 otherwise.
  {
    switch(query("passwd_type")) {
      case "password":
	return (int)sql_query("SELECT PASSWORD(%s) = %s as pswmatch",
			      password, crypted_password())[0]->pswmatch;
      case "old-password":
	return (int)sql_query("SELECT OLD_PASSWORD(%s) = %s as pswmatch",
			      password, crypted_password())[0]->pswmatch;
      case "crypt":
	return (verify_password(password, crypted_password()));
      case "clear text":
	return (password == crypted_password());
      case "md5 crypt":
	catch {return Crypto.verify_crypt_md5 (password, crypted_password());};
	return 0;
    }
  }

  protected void create( UserDB p, mapping e )
  {
    ::create( p );
    ent = e;
  }
}

class SqlGroup
{
  inherit Group;
  protected mapping ent;

  int gid() { return (int)ent->gid; }
  string name() { return ent->name; }
  array(string) members()
  {
    return get_group_users( gid() );
  }

  protected void create( UserDB p, mapping e )
  {
    ::create( p );
    ent = e;
  }
}

constant db_defs =
([
  "group_members":({
    "gid int unsigned not null",
    "uid int unsigned not null",
    "INDEX g (gid)",
    "INDEX u (uid)",
  }),
  "groups":({
    "gid  int unsigned not null primary key auto_increment",
    "name varchar(255) not null",
    "INDEX n (name)",
  }),
  "users":({
    "uid      int unsigned not null primary key auto_increment",
    "gid      int unsigned not null default 0", /*Hm. Not _really_ nessesary.*/
    "name     varchar(255) not null default ''",
    "password varchar(255) not null default '*'",
    "gecos    varchar(255) not null default ''",
    "homedir  varchar(255) not null default '/'",
    "shell    varchar(255) not null default '/bin/sh'",
    "INDEX n (name)",
  }),
]);
  
array(string) get_user_groups( int user )
{
  if(!inited) return ({});
  return 
    sql_query( "SELECT "
	       "  groups.name as name FROM groups,group_members "
	       "WHERE "
	       "  group_members.uid=%d AND groups.gid=group_members.gid "
	       "GROUP BY "
	       "  groups.name", user )
    ->name;
}

array(string) get_group_users( int group )
{
  if(!inited) return ({});
  return 
    sql_query( "SELECT "
	       "  users.name as name FROM users,group_members "
	       "WHERE "
	       "  group_members.gid=%d AND users.uid=group_members.uid "
	       "GROUP BY "
	       "  users.name", group )
    ->name;
}

User find_user( string s )
{
  if(!inited) return 0;
  array r = sql_query( "SELECT * FROM users WHERE name=%s", s );
  if( sizeof( r ) )
    return SqlUser( this_object(), r[0] );
}

User find_user_from_uid( int id )
{
  if(!inited) return 0;
  array r = sql_query( "SELECT * FROM users WHERE uid=%d", id );
  if( sizeof( r ) )
    return SqlUser( this_object(), r[0] );
}

array(string) list_users( )
{
  if(!inited) return ({});
  return sql_query( "SELECT name FROM users" )->name;
}

Group find_group( string s )
{
  if(!inited) return 0;
  array r = sql_query( "SELECT * FROM groups WHERE name=%s", s );
  if( sizeof( r ) )
    return SqlGroup( this_object(), r[0] );
}

Group find_group_from_gid( int i )
{
  if(!inited) return 0;
  array r = sql_query( "SELECT * FROM groups WHERE gid=%d", i );
  if( sizeof( r ) )
    return SqlGroup( this_object(), r[0] );
}

array(string) list_groups( )
{
  if(!inited) return ({});
  return sql_query( "SELECT name FROM groups" )->name;
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
			    "This datbase contains the user database" );
    DBManager.set_permission( query("db"), my_configuration(), DBManager.WRITE );
  }
  set_my_db( query("db") );
  create_sql_tables( db_defs, "User database table", 1 );
  inited = 1;
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
                       _(3,"Database"),
                       _(4,"This is the database that this module will "
			      "store it's users in.") ) );

  defvar( "passwd_type",
          Variable.StringChoice("password",
				([
				  "password":_(5,"MySQL Password"),
				  "old-password":_(11,"MySQL OLD_PASSWORD() "
						   "(4.0 Compat Mode)"),
				  "crypt":_(6,"Unix crypt"),
				  "clear text":_(7,"Clear text"),
				  "md5 crypt":_(8,"MD5 crypt"),
				]), 0,
				_(9,"Password type"),
				_(10,"Password hashing method. "
				  "By changing this variable you can "
				  "select the meaning of password field. "
				  "By default the passwords are supposed "
				  "to be hashed by internal MySQL PASSWORD() "
				  "function.")
				));

}
