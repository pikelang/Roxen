// Symbolic DB handling. 
Sql.sql db = connect_to_my_mysql( 0, "roxen" );
function(string,mixed...:array(mapping(string:string))) query = db->query;

constant NONE  = 0;
constant READ  = 1;
constant WRITE = 2;

static string short( string n )
{
  return lower_case(sprintf("%s%4x", n[..6],(hash( n )&65535) ));
}

static void ensure_has_users( Sql.sql db, Configuration c )
{
  array q = db->query( "SELECT User FROM user WHERE User='%s_rw'",
                       short(c->name) );
  if( !sizeof( q ) )
  {
    db->query( "INSERT INTO user (Host,User,Password) "
               "VALUES ('localhost','%s_rw','')",
               short(c->name) ); 
    db->query( "INSERT INTO user (Host,User,Password) "
               "VALUES ('localhost','%s_ro','')",
               short(c->name) ); 
  }
}

static void set_user_permissions( Configuration c, string name, int level )
{
  Sql.sql db = connect_to_my_mysql( 0, "mysql" );

  ensure_has_users( db, c );

  db->query("DELETE FROM db WHERE User LIKE '%s%%' AND Db='%s'",
            short(c->name), name );

  if( level > 0 )
  {
    db->query("INSERT INTO db (Host,Db,User,Select_priv) "
              "VALUES ('localhost','%s','%s_ro','Y')", name, short(c->name));
    if( level > 1 )
      db->query("INSERT INTO db VALUES ('localhost','%s','%s_rw',"
                "'Y','Y','Y','Y','Y','Y','N','Y','Y','Y')",
              name, short(c->name));
    else 
      db->query("INSERT INTO db  (Host,Db,User,Select_priv) "
                "VALUES ('localhost','%s','%s_rw','Y')",
                name, short(c->name));
  }
  db->query( "FLUSH PRIVILEGES" );
}

array(string) list( void|Configuration c )
//! List all database aliases.
//!
//! If c is specified, only databases the given configuration can
//! access will be visible.
{
  array(mapping(string:string)) res;
  if( c )
    return  query( "SELECT "
                   " dbs.name AS name "
                   "FROM "
                   " dbs,db_permissions "
                   "WHERE"
                   " dbs.name=db_permissions.db"
                   " AND db_permissions.config='%s'"
                   " AND db_permissions.permission!='none'",
                   c->name)->name;
  return query( "SELECT name from dbs" )->name;
}

mapping(string:mapping(string:int)) get_permission_map( )
//! Get a list of all permissions for all databases.
//! Return format:
//!   ([
//!      "dbname":([ "configname":level, ... ])
//!      ...
//!    ])
//!
//!  Level is as for set_permission.
{
  mapping(string:mapping(string:int)) res = ([]);

  foreach( query("SELECT name FROM dbs"), mapping(string:string) n )
  {
    mixed m = query( "SELECT * FROM db_permissions WHERE db='%s'",
                     n->name );
    if( sizeof( m ) )
      foreach( m, m )
      {
        if( !res[m->db] )res[m->db] = ([]);
        switch( m->permission )
        {
         case "none":    res[m->db][m->config] = NONE; break;
         case "read":    res[m->db][m->config] = READ; break;
         case "write":   res[m->db][m->config] = WRITE; break;
        }
      }
    else
      res[n->name] = ([]);
  }
  foreach( indices(res), string q )
    foreach( roxen->configurations, Configuration c )
      if( zero_type( res[q][c->name] ) )
        res[q][c->name] = 0;
  return res;
}

class ROWrapper( Sql.sql sql )
{
  static int pe;
  array(mapping(string:mixed)) query( string query, mixed ... args )
  {
    if( has_prefix( lower_case(query), "select" ) ||
        has_prefix( lower_case(query), "show" ) ||
        has_prefix( lower_case(query), "describe" ))
      return sql->query( query, @args );
    pe = 1;
    throw( ({ "Permission denied\n", backtrace()}) );
  }
  object big_query( string query, mixed ... args )
  {
    if( has_prefix( lower_case(query), "select" ) ||
        has_prefix( lower_case(query), "show" ) ||
        has_prefix( lower_case(query), "describe" ))
      return sql->big_query( query, @args );
    pe = 1;
    throw( ({ "Permission denied\n", backtrace()}) );
  }
  string error()
  {
    if( pe )
    {
      pe = 0;
      return "Permission denied";
    }
    return sql->error();
  }

  string host_info()
  {
    return sql->host_info()+" (read only)";
  }

  mixed `[]( string i )
  {
    switch( i )
    {
     case "query": return query;
     case "big_query": return big_query;
     case "host_info": return host_info;
     case "error": return error;
     default:
       return sql[i];
    }
  }
  mixed `->( string i )
  {
    return `[](i);
  }
}
  

static mapping sql_cache = ([]);

static Sql.sql sql_cache_get(string what)
{
  if(sql_cache[what] && sql_cache[what][this_thread()])
    return sql_cache[what][this_thread()];
  if(!sql_cache[what])
    sql_cache[what] =  ([ this_thread():Sql.sql( what ) ]);
  else
    sql_cache[what][ this_thread() ] = Sql.sql( what );
  return sql_cache[what][ this_thread() ];
}

static object low_get( string user, string db )
{
  array(mapping(string:mixed)) d =
           query("SELECT path,local FROM dbs WHERE name='%s'", db );
  if( !sizeof( d ) )
    return 0;
  if( (int)d[0]["local"] )
    return connect_to_my_mysql( user, db );

  // Otherwise it's a tad more complex...  
  if( user[strlen(user)-2..] == "ro" )
    return ROWrapper( sql_cache_get( d[0]->path ) );

  return sql_cache_get( d[0]->path );
}

ROWrapper get( string name, void|Configuration c, int|void ro )
//! Get the database 'name'. If the configuration 'c' is specified,
//! only return the database if the configuration has at least read
//! access.
//!
//! The object returned contains at least the methods query and big_query
{
  array(mapping(string:mixed)) res;
  if( c )
  {
    res = query( "SELECT permission FROM db_permissions "
                 "WHERE db='%s' AND config='%s' AND permission!='none'",
                 name,c->name);
    if( sizeof( res ) )
      return low_get( short(c->name) +
                      ((ro || res[0]->permission!="write")?"_ro":"_rw"),
                      name );
    return 0;
  }
  return low_get( (ro?"ro":"rw"), name );
}

void drop_db( string name )
//! Drop the database 'name'. If the database is internal, the actual
//! tables will be deleted as well.
{
  array q = query( "SELECT name,local FROM dbs WHERE name='%s'", name );
  if( sizeof( q ) && (int)q[0]["local"] )
    query( "DROP DATABASE '%s'", name );
  query( "DELETE FROM dbs WHERE name='%s'", name );
  query( "DELETE FROM permissions WHERE db='%s'", name );
}


void create_db( string name, string path, int is_internal )
//! Create a new symbolic database alias.
//!
//! If is_internal is specified, the database will be automatically
//! created if it does not exist, and the path argument is ignored.
//!
//! If the database 'name' already existed, it will be overwritten.
{
  query( "DELETE FROM dbs WHERE name='%s'", name );
  query( "INSERT INTO dbs values ('%s','%s',%s)",
         name, (is_internal?name:path), (is_internal?"1":"0") );
  if( is_internal )
    catch(query( "CREATE DATABASE '%s'", name ));
}


int set_permission( string name, Configuration c, int level )
//! Set the permission for the configuration 'c' on the database
//! 'name' to level.
//!
//! Levels:
//!  DBManager.NONE:  No access
//!  DBManager.READ:  Read access
//!  DBManager.WRITE: Write access
//!
//!  Please note that for non-local databases, it's not really
//!  possible to differentiate between read and write permissions,
//!  roxen does try to do that anyway by checking the requests and
//!  disallowing anything but 'select' and 'show' from read only
//!  databses. Please note that this is not really all that secure.
//!
//!  From local (in the mysql used by roxen) databases, the
//!  permissions are enforced by using different users, and should be
//!  secure as long as the permission system in mysql is not modified
//!  directly by the administrator.
//!
//!  This function returns 0 if it failed. The only reason for it to
//!  fail is if there is no database with the specified name.
{
  array(mapping(string:mixed)) d =
           query("SELECT path,local FROM dbs WHERE name='%s'", name );

  if( !sizeof( d ) )
      return 0;

  query( "DELETE FROM db_permissions WHERE db='%s' AND config='%s'",
         name,c->name );
  query( "INSERT INTO db_permissions VALUES ('%s','%s','%s')",
         name,c->name,(level?level==2?"write":"read":"none") );
  
  if( (int)d[0]["local"] )
  {
    set_user_permissions( c, name, level );
  }    
}

static void create()
{
  multiset q = (multiset)query( "SHOW TABLES" )->Tables_in_roxen;
  if( !q->dbs )
  {
    query( #"
CREATE TABLE dbs (
 name VARCHAR(20) NOT NULL PRIMARY KEY,
 path VARCHAR(100) NOT NULL, 
 local INT UNSIGNED NOT NULL )
 " );
    query( "INSERT INTO dbs values ('mysql', 'mysql', 1)" ); 
    query( "INSERT INTO dbs values ('roxen', 'roxen', 1)" ); 
    query( "INSERT INTO dbs values ('cache', 'cache', 1)" );
  }
  
  if( !q->db_permissions )
    query(#"
CREATE TABLE db_permissions (
 db VARCHAR(20) NOT NULL, 
 config VARCHAR(80) NOT NULL, 
 permission ENUM ('none','read','write') NOT NULL,
 INDEX db_conf (db,config))
" );
}
