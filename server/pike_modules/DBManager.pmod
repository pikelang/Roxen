// Symbolic DB handling.
//
// $Id: DBManager.pmod,v 1.60 2002/12/01 23:25:05 mani Exp $

//! Manages database aliases and permissions

#include <roxen.h>
#include <config.h>


#define CN(X) string_to_utf8( X )
#define NC(X) utf8_to_string( X )


constant NONE  = 0;
//! No permissions. Used in @[set_permission] and @[get_permission_map]

constant READ  = 1;
//! Read permission. Used in @[set_permission] and @[get_permission_map]

constant WRITE = 2;
//! Write permission. Used in @[set_permission] and @[get_permission_map]


private
{
  mixed query( mixed ... args )
  {
    return connect_to_my_mysql( 0, "roxen" )->query( @args );
  }

  string short( string n )
  {
    return lower_case(sprintf("%s%4x", CN(n)[..6],(hash( n )&65535) ));
  }

  void clear_sql_caches()
  {
#if DBMANAGER_DEBUG
    werror("DBManager: clear_sql_caches():\n"
	   "  dead_sql_cache: %O\n"
	   "  sql_cache: %O\n"
	   "  connection_cache: %O\n",
	   dead_sql_cache,
	   sql_cache,
	   connection_cache);
#endif /* DMBMANAGER_DEBUG */
    /* Rotate the sql_caches.
     *
     * Perform the rotation first, to avoid thread-races.
     */
    sql_url_cache = ([]);
    connection_user_cache = ([]);
    clear_connect_to_my_mysql_cache();
    gc( );
  }
  
  array changed_callbacks = ({});
  void changed()
  {
    changed_callbacks-=({0});
    clear_sql_caches();
    
    foreach( changed_callbacks, function cb )
      catch( cb() );
    gc( );
  }

  static void low_ensure_has_users( Sql.Sql db, Configuration c, string host,
				    string|void password )
  {
    array q = db->query( "SELECT User FROM user WHERE User=%s AND Host=%s",
			 short(c->name)+"_rw", host );
    
    if( sizeof( q ) )
    {
      db->query("DELETE FROM user WHERE User=%s AND Host=%s",
		short(c->name)+"_rw", host );
      db->query("DELETE FROM user WHERE User=%s AND Host=%s",
		short(c->name)+"_ro", host );
    }
    
    if( password )
    {
      db->query( "INSERT INTO user (Host,User,Password) "
		 "VALUES (%s, %s, PASSWORD(%s))",
		 host, short(c->name)+"_rw", password ); 
      db->query( "INSERT INTO user (Host,User,Password) "
		 "VALUES (%s, %s, PASSWORD(%s))",
		 host, short(c->name)+"_ro", password );
    }
    else
    {
      db->query( "INSERT INTO user (Host,User,Password) "
		 "VALUES (%s, %s, '')",
		 host, short(c->name)+"_rw" ); 
      db->query( "INSERT INTO user (Host,User,Password) "
		 "VALUES (%s, %s, '')",
		 host, short(c->name)+"_ro" );
    }
  }
  
  void ensure_has_users( Sql.Sql db, Configuration c )
  {
    low_ensure_has_users( db, c, "localhost" );
  }

  void ensure_has_external_users( Sql.Sql db, Configuration c,
				  string password )
  {
    low_ensure_has_users( db, c, "127.0.0.1", password );
  }

  static void low_set_user_permissions( Configuration c, string name,
					int level, string host,
					string|void password )
  {
    Sql.Sql db = connect_to_my_mysql( 0, "mysql" );

    low_ensure_has_users( db, c, host, password );

    db->query("DELETE FROM db "
	      "  WHERE User LIKE '"+short(c->name)+"%%' "
	      "    AND Db=%s"
	      "    AND Host=%s", name, host);

    if( level > 0 )
    {
      db->query("INSERT INTO db (Host,Db,User,Select_priv) "
                "VALUES (%s, %s, %s, 'Y')",
                host, name, short(c->name)+"_ro");
      if( level > 1 )
        db->query("INSERT INTO db VALUES (%s, %s, %s,"
                  "'Y','Y','Y','Y','Y','Y','N','Y','Y','Y')",
                  host, name, short(c->name)+"_rw");
      else 
        db->query("INSERT INTO db  (Host,Db,User,Select_priv) "
                  "VALUES (%s, %s, %s, 'Y')",
                  host, name, short(c->name)+"_rw");
    }
    db->query( "FLUSH PRIVILEGES" );
  }
  
  void set_user_permissions( Configuration c, string name, int level )
  {
    low_set_user_permissions( c, name, level, "localhost" );
  }
  
  void set_external_user_permissions( Configuration c, string name, int level,
				      string password )
  {
    low_set_user_permissions( c, name, level, "127.0.0.1", password );
  }

  // FIXME: This is a horrible kludge
  constant blarg = error;

  class ROWrapper( static Sql.Sql sql )
  {
    static int pe;
    static array(mapping(string:mixed)) query( string query, mixed ... args )
    {
      if( has_prefix( lower_case(query), "select" ) ||
          has_prefix( lower_case(query), "show" ) ||
          has_prefix( lower_case(query), "describe" ))
        return sql->query( query, @args );
      pe = 1;
      blarg( "Permission denied\n" );
    }
    static object big_query( string query, mixed ... args )
    {
      if( has_prefix( lower_case(query), "select" ) ||
          has_prefix( lower_case(query), "show" ) ||
          has_prefix( lower_case(query), "describe" ))
        return sql->big_query( query, @args );
      pe = 1;
      blarg( "Permission denied\n" );
    }
    static string error()
    {
      if( pe )
      {
        pe = 0;
        return "Permission denied";
      }
      return sql->error();
    }

    static string host_info()
    {
      return sql->host_info()+" (read only)";
    }

    static mixed `[]( string i )
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
    static mixed `->( string i )
    {
      return `[](i);
    }
  }

  mapping(string:mapping(string:string)) sql_url_cache = ([]);
  Sql.Sql low_get( string user, string db )
  {
    if( !user )
      return 0;
    mixed res;
    mapping(string:mixed) d = sql_url_cache[ db ];
    if( !d )
    {
      res = query("SELECT path,local FROM dbs WHERE name=%s", db );
      if( !sizeof( res ) )
	return 0;
      sql_url_cache[db] = d = res[0];
    }

    if( (int)d->local )
      return connect_to_my_mysql( user, db );

    // Otherwise it's a tad more complex...  
    if( user[strlen(user)-2..] == "ro" )
      // The ROWrapper object really has all member functions Sql.Sql
      // has, but they are hidden behind an overloaded index operator.
      // Thus, we have to fool the typechecker.
      return [object(Sql.Sql)](object)ROWrapper( sql_cache_get( d->path ) );
    return sql_cache_get( d->path );
  }
};

mixed sql_cache_get(string what)
{
  mixed key = loader.sq_cache_lock();
  string i = replace(what,":",";")+":-";
  mixed res = loader.sq_cache_get( i ) ||
    loader.sq_cache_set( i, Sql.Sql( what ) );
  // Fool the optimizer so that key is not released prematurely
  if( res )
    return res; 
}

void add_dblist_changed_callback( function(void:void) callback )
//! Add a function to be called when the database list has been
//! changed. This function will be called after all @[create_db] and
//! @[drop_db] calls.
{
  changed_callbacks |= ({ callback });
}

int remove_dblist_changed_callback( function(void:void) callback )
//! Remove a function previously added with @[add_dblist_changed_callback].
//! Returns non-zero if the function was in the callback list.
{
  int s = sizeof( changed_callbacks );
  changed_callbacks -= ({ callback });
  return s-sizeof( changed_callbacks );
}

array(string) list( void|Configuration c )
//! List all database aliases.
//!
//! If @[c] is specified, only databases that the given configuration can
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
                   " AND db_permissions.config=%s"
                   " AND db_permissions.permission!='none'",
                   CN(c->name))->name
#ifndef YES_I_KNOW_WHAT_I_AM_DOING
      -({"roxen","mysql"})
#endif
      ;
  return query( "SELECT name from dbs" )->name
#ifndef YES_I_KNOW_WHAT_I_AM_DOING
      -({"roxen","mysql"})
#endif
    ;
}

mapping(string:mapping(string:int)) get_permission_map( )
//! Get a list of all permissions for all databases.
//! Return format:
//! ([
//!  "dbname":([ "configname":level, ... ])
//!   ...
//!  ])
//!
//! Level is as for @[set_permission()].
{
  mapping(string:mapping(string:int)) res = ([]);

  foreach( list(), string n )
  {
    mixed m = query( "SELECT * FROM db_permissions WHERE db=%s", n );
    if( sizeof( m ) )
      foreach( m, m )
      {
        if( !res[m->db] )res[m->db] = ([]);
        switch( m->permission )
        {
         case "none":    res[m->db][NC(m->config)] = NONE; break;
         case "read":    res[m->db][NC(m->config)] = READ; break;
         case "write":   res[m->db][NC(m->config)] = WRITE; break;
        }
      }
    else
      res[n] = ([]);
  }
  foreach( indices(res), string q )
    foreach( roxenp()->configurations, Configuration c )
      if( zero_type( res[q][c->name] ) )
        res[q][c->name] = 0;
  return res;
}

string db_driver( string db )
//! Returns the name of the protocol used to connect to the database 'db'.
//! This is the part before :// in the database URL.  
{
  if( !(db = db_url( db )) ) return "mysql";
  sscanf( db, "%[^:]:", db );
  return db;
}

int is_mysql( string db )
//! Returns true if the specified database is a MySQL database.
{
  return !(db = db_url( db )) || has_prefix( db, "mysql://" );
}

array(mapping(string:mixed)) db_table_fields( string name, string table )
//! Returns a mapping of fields in the database, if it's supported by
//! the protocol handler. Otherwise returns 0.
{
  Sql.Sql db = cached_get( name );
  catch {
    if( db->list_fields )
    {
      mixed res = db->list_fields( table );
      if( res ) return res;
    }
  };
  // Now, this is slow, but very generic. :-)
  mixed err = catch {
    array res = ({});
    foreach( db->big_query( "SELECT * FROM "+table )->fetch_fields(),
	     object q )
    {
      res += ({
	([
	  "name":q->name,
	  "type":q->type,
	])
      });
    }
    return res;
  };
  // No dice.
  return 0;
}

array(string) db_tables( string name )
//! Attempt to list all tables in the specified DB, and then return
//! the list.
{
  object db = get(name);
  array(string) res;
  if( db->list_tables )
  {
    catch {
      if( res =  db->list_tables() )
	return res;
    };
  }

  // Well, let's try some specific solutions then. The main problem if
  // we reach this stage is probably that we are using a ODBC driver
  // which does not support the table enumeration interface, this
  // causing list_tables to throw an error.

  switch( db_driver( name ) )
  {
    case "mysql":
      return ({});

    case "odbc":
      // Oracle.
      catch {
	res = db->query( "select TNAME from tab")->TNAME;
	return res;
      };
      // fallthrough.

      // Microsoft SQL (7.0 or newer)
      catch {
	res = ({});
	foreach( db->query("SELECT * FROM information_schema.tables"),
		 mapping row )
	  if( has_prefix( lower_case(row->TABLE_TYPE), "base" ) )
	    res += ({ row->TABLE_NAME });
	return res;
      };

      
    case "postgres":
      // Postgres
      catch {
	res = db->query("SELECT a.relname AS name FROM pg_class a, "
			"pg_user b WHERE ( relkind = 'r') and "
			"relname !~ '^pg_' "
			"AND relname !~ '^xin[vx][0-9]+' AND "
			"b.usesysid = a.relowner AND "
			"NOT (EXISTS (SELECT viewname FROM pg_views "
			"WHERE viewname=a.relname)) ")->name;
	return res;
      };
  }

  return ({});
}

mapping db_table_information( string db, string table )
//! Return a mapping with at least the indices rows, data_length
//! and index_length, if possible. Otherwise returns 0.
{
  switch( db_driver( db ) )
  {
    case "mysql":
    {
      foreach( get(db)->query( "SHOW TABLE STATUS" ), mapping r )
      {
	if( r->Name == table )
	  return ([ "rows":(int)r->Rows,
		    "data_length":(int)r->Data_length,
		    "index_length":(int)r->Index_length ]);
      }
    }
    default:
      mixed err = catch{
	return ([
	  "rows":
	  (int)(get(db)->query( "SELECT COUNT(*) AS C FROM "+table )[0]->C),
	]);
      };
  }
  return 0;
}


mapping db_stats( string name )
//! Return statistics for the specified database (such as the number
//! of tables and their total size). If the database is not an
//! internal database, or the database does not exist, 0 is returned
{
  mapping res = ([]);
  Sql.Sql db = cached_get( name );
  array d;

  switch( db_driver( name ) )
  {
    case "mysql":
      if( !catch( d = db->query( "SHOW TABLE STATUS" ) ) )
      {
	foreach( d, mapping r )
	{
	  res->size += (int)r->Data_length+(int)r->Index_length;
	  res->tables++;
	  res->rows += (int)r->Rows;
	}
	return res;
      }

      // fallthrough to generic interface.
    default:
      catch
      {
	foreach( db_tables( name ), string n )
	{
	  mapping i  = db_table_information( name, n );
	  res->tables++;
	  if( i )
	  {
	    res->rows += i->rows;
	    res->size += i->data_length+i->index_length;
	  }
	}
	return res;
      };
  }
  return 0;
}


int is_internal( string name )
//! Return true if the DB @[name] is an internal database
{
  array(mapping(string:mixed)) d =
           query("SELECT path,local FROM dbs WHERE name=%s", name );
  if( !sizeof( d ) ) return 0;
  return (int)d[0]["local"];
}

string db_url( string name,
	       int|void force )
//! Returns the URL of the db, or 0 if the DB @[name] is an internal
//! database and @[force] is not specified. If @[force] is specified,
//! a URL is always returned unless the database does not exist.
{
  array(mapping(string:mixed)) d =
           query("SELECT path,local FROM dbs WHERE name=%s", name );

  if( !sizeof( d ) )
    return 0;

  if( (int)d[0]["local"] )
  {
    if( force )
      return replace( loader->my_mysql_path,
		      ([
			"%user%":"rw",
			"%db%":name
		      ]) );
    return 0;
  }
  return d[0]->path;
}

static mapping connection_user_cache  = ([]);

string get_db_user( string name, Configuration c, int ro )
{
  string key = name+"|"+(c&&c->name)+"|"+ro;
  if( !zero_type( connection_user_cache[ key ] ) )
    return connection_user_cache[ key ];

  array(mapping(string:mixed)) res;
  if( c )
  {
    res = query( "SELECT permission FROM db_permissions "
                 "WHERE db=%s AND config=%s",  name, CN(c->name));
    if( sizeof( res ) && res[0]->permission != "none" )
      return connection_user_cache[ key ]=short(c->name) +
	((ro || res[0]->permission!="write")?"_ro":"_rw");
    return connection_user_cache[ key ] = 0;
  }
  return connection_user_cache[ key ] = ro?"ro":"rw";
}

Sql.Sql get( string name, void|Configuration c, int|void ro )
//! Get the database @[name]. If the configuration @[c] is specified,
//! only return the database if the configuration has at least read
//! access.
{
  return low_get( get_db_user( name,c,ro ), name );
}

Sql.Sql cached_get( string name, void|Configuration c, void|int ro )
{
  return low_get( get_db_user( name,c,ro ), name );
}

void drop_db( string name )
//! Drop the database @[name]. If the database is internal, the actual
//! tables will be deleted as well.
{
  if( (< "local", "mysql", "roxen"  >)[ name ] )
    error( "Cannot drop the 'local' database\n" );

  array q = query( "SELECT name,local FROM dbs WHERE name=%s", name );
  if(!sizeof( q ) )
    error( "The database "+name+" does not exist\n" );
  if( sizeof( q ) && (int)q[0]["local"] )
    query( "DROP DATABASE `"+name+"`" );
  query( "DELETE FROM dbs WHERE name=%s", name );
  query( "DELETE FROM db_groups WHERE db=%s", name );
  query( "DELETE FROM db_permissions WHERE db=%s", name );
  changed();
}

void set_url( string db, string url, int is_internal )
//! Set the URL for the specified database.
//! No data is copied.
//! This function call only works for external databases. 
{
  query( "UPDATE dbs SET path=%s, local=%d WHERE name=%s",
	 url, is_internal, db );
//   changed();
}

void copy_db_md( string oname, string nname )
//! Copy the metadata from oname to nname. Both databases must exist
//! prior to this call.
{
  mapping m = get_permission_map( )[oname];
  foreach( indices( m ), string s )
    if( Configuration c = roxenp()->find_configuration( s ) )
      set_permission( nname, c, m[s] );
  changed();
}

array(mapping) backups( string dbname )
{
  if( dbname )
    return query( "SELECT * FROM db_backups WHERE db=%s", dbname );
  return query("SELECT * FROM db_backups"); 
}

array(mapping) restore( string dbname, string directory, string|void todb,
			array|void tables )
//! Restore the contents of the database dbname from the backup
//! directory. New tables will not be deleted.
//!
//! The format of the result is as for the second element in the
//! return array from @[backup]. If todb is specified, the backup will
//! be restored in todb, not in dbname.
{
  Sql.Sql db = cached_get( todb || dbname );

  if( !directory )
    error("Illegal directory\n");

  if( !db )
    error("Illegal database\n");

  directory = combine_path( getcwd(), directory );

  array q =
    tables ||
    query( "SELECT tbl FROM db_backups WHERE db=%s AND directory=%s",
	   dbname, directory )->tbl;

  array res = ({});
  foreach( q, string table )
  {
    db->query( "DROP TABLE IF EXISTS "+table);
    directory = combine_path( getcwd(), directory );
    res += db->query( "RESTORE TABLE "+table+" FROM %s", directory );
  }
  return res;
}

void delete_backup( string dbname, string directory )
//! Delete a backup previously done with @[backup].
{
  // 1: Delete all backup files.
  directory = combine_path( getcwd(), directory );

  foreach( query( "SELECT tbl FROM db_backups WHERE db=%s AND directory=%s",
		  dbname, directory )->tbl, string table )
  {
    rm( directory+"/"+table+".frm" );
    rm( directory+"/"+table+".MYD" );
  }
  // 2: Delete the information about this backup.
  query( "DELETE FROM db_backups WHERE db=%s AND directory=%s",
	 dbname, directory );
}

array(string|array(mapping)) backup( string dbname, string directory )
//! Make a backup of all data in the specified database.
//! If a directory is not specified, one will be created in $VARDIR.
//! The return value is ({ "name of the directory", result }).
//!
//! The format of result is:
//!  ({([ "Table":tablename,
//!      "Msg_type":one of "status" "error" "info" or "warnign",
//!      "Msg_text":"The message"
//!  ])})
//!
//! Currently this function only works for internal databases.
{
  Sql.Sql db = cached_get( dbname );

  if( !db )
    error("Illegal database\n");

  if( !directory )
    directory = roxen_path( "$VARDIR/"+dbname+"-"+isodate(time(1)) );
  directory = combine_path( getcwd(), directory );

  if( is_internal( dbname ) )
  {
    mkdirhier( directory+"/" );
    array tables = db_tables( dbname );
    array res = ({});
    foreach( tables, string table )
    {
      query( "DELETE FROM db_backups WHERE "
	     "db=%s AND directory=%s AND tbl=%s",
	     dbname, directory, table );
      query( "INSERT INTO db_backups (db,tbl,directory,whn) "
	     "VALUES (%s,%s,%s,%d)",
	     dbname, table, directory, time() );
      res += db->query( "BACKUP TABLE "+table+" TO %s",directory);
    }
    return ({ directory,res });
  }
  else
  {
    error("Currently only handles internal databases\n");
    // Harder. :-)
  }
}


void rename_db( string oname, string nname )
//! Rename a database. Pleae note that the actual data (in the case of
//! internal database) is not copied. The old database is deleted,
//! however. For external databases, only the metadata is modified, no
//! attempt is made to alter the external database.
{
  query( "UPDATE dbs SET name=%s WHERE name=%s", oname, nname );
  query( "UPDATE db_permissions SET db=%s WHERE db=%s", oname, nname );
  if( is_internal( oname ) )
  {
    Sql.Sql db = connect_to_my_mysql( 0, "mysql" );
    db->query("CREATE DATABASE IF NOT EXISTS %s",nname);
    db->query("UPDATE db SET Db=%s WHERE Db=%s",oname, nname );
    db->query("DROP DATABASE IF EXISTS %s",oname);
    query( "FLUSH PRIVILEGES" );
  }
  changed();
}

mapping get_group( string name )
{
  array r= query( "SELECT * FROM groups WHERE name=%s", name );
  if( sizeof( r ) )
    return r[0];
}

array(string) list_groups()
{
  return query( "SELECT name FROM groups" )->name;
}

int create_group( string name,    string lname,
		     string comment, string pattern )
{
  if( get_group( name ) )
  {
    query( "UPDATE groups SET comment=%s, pattern=%s, lname=%s "
	   "WHERE name=%s",  comment, pattern, lname, name );
  }
  else
  {
    query("INSERT INTO groups (comment,pattern,lname,name) "
	  "VALUES (%s,%s,%s,%s)", comment, pattern, lname, name );
  }
}

int delete_group( string name )
{
  if( !get_group( name ) )
    return 0;
  if( sizeof(group_dbs( name )) )
    return 0;
  query( "DELETE FROM groups WHERE name=%s", name );
  return 1;
}

array(string) group_dbs( string group )
{
  return query( "SELECT db FROM db_groups WHERE groupn=%s", group )
    ->db
#ifndef YES_I_KNOW_WHAT_I_AM_DOING
      -({"roxen","mysql"})
#endif
    ;
}

string db_group( string db )
{
  array q =query( "SELECT groupn FROM db_groups WHERE db=%s", db );
  if( sizeof( q )  )
    return q[0]->groupn;
  return "internal";
}

string get_group_path( string db, string group )
{
  mapping m = get_group( group );
  if( !m )
    error("The group %O does not exist.", group );
  if( strlen( m->pattern ) )
  {
    catch
    {
      Sql.Sql sq = Sql.Sql( m->pattern+"mysql" );
      sq->query( "CREATE DATABASE "+db );
    };
    return m->pattern+db;
  }
  return 0;
}

void set_db_group( string db, string group )
{
  query("DELETE FROM db_groups WHERE db=%s", db);
  query("INSERT INTO db_groups (db,groupn) VALUES (%s,%s)",
	db, group );
}

void create_db( string name, string path, int is_internal,
		string|void group )
//! Create a new symbolic database alias.
//!
//! If @[is_internal] is specified, the database will be automatically
//! created if it does not exist, and the @[path] argument is ignored.
//!
//! If the database @[name] already exists, an error will be thrown
//!
//! If group is specified, the @[path] will be generated
//! automatically using the groups defined by @[create_group]
{
  if( get( name ) )
    error("The database "+name+" already exists\n");
  if( sizeof((array)name & ({ '@', ' ', '-', '&', '%', '\t',
			      '\n', '\r', '\\', '/', '\'', '"',
			      '(', ')', '*', '+', }) ) )
    error("Please do not use any of the characters @, -, &, /, \\ "
	  "or %% in database names.\nAlso avoid whitespace characters\n");
  if( has_value( name, "-" ) )
    name = replace( name, "-", "_" );
  if( group )
  {
    set_db_group( name, group );
    if( is_internal )
    {
    path = get_group_path( name, group );
    if( path )
      is_internal = 0;
    }
  }
  else
    query("INSERT INTO db_groups (db,groupn) VALUES (%s,%s)",
	  name, "internal" );

  query( "INSERT INTO dbs values (%s,%s,%s)", name,
	 (is_internal?name:path), (is_internal?"1":"0") );
  if( is_internal )
    catch(query( "CREATE DATABASE `"+name+"`"));
  changed();
}

int set_external_permission( string name, Configuration c, int level,
			     string password )
//! Set the permission for the configuration @[c] on the database
//! @[name] to @[level] for an external tcp connection from 127.0.0.1
//! authenticated via password @[password].
//!
//! Levels:
//!  @int
//!    @value DBManager.NONE
//!      No access
//!    @value DBManager.READ
//!      Read access
//!    @value DBManager.WRITE
//!      Write access
//!  @endint
//!
//! @returns
//!  This function returns 0 if it fails. The only reason for it to
//!  fail is if there is no database with the specified @[name].
//!
//! @note
//!  This function is only valid for local databases.
//!
//! @seealso
//!  @[set_permission()], @[get_db_user()]
{
  array(mapping(string:mixed)) d =
           query("SELECT path,local FROM dbs WHERE name=%s", name );

  if( !sizeof( d ) )
      return 0;

  if( (int)d[0]["local"] )
    set_external_user_permissions( c, name, level, password );
  
  return 1;
}

int set_permission( string name, Configuration c, int level )
//! Set the permission for the configuration @[c] on the database
//! @[name] to @[level].
//!
//! Levels:
//!  @int
//!    @value DBManager.NONE
//!      No access
//!    @value DBManager.READ
//!      Read access
//!    @value DBManager.WRITE
//!      Write access
//!  @endint
//!
//!  Please note that for non-local databases, it's not really
//!  possible to differentiate between read and write permissions,
//!  roxen does try to do that anyway by checking the requests and
//!  disallowing anything but 'select' and 'show' from read only
//!  databases. Please note that this is not really all that secure.
//!
//!  From local (in the mysql used by Roxen) databases, the
//!  permissions are enforced by using different users, and should be
//!  secure as long as the permission system in mysql is not modified
//!  directly by the administrator.
//!
//! @returns
//!  This function returns 0 if it fails. The only reason for it to
//!  fail is if there is no database with the specified @[name].
{
  array(mapping(string:mixed)) d =
           query("SELECT path,local FROM dbs WHERE name=%s", name );

  if( !sizeof( d ) )
      return 0;

  query( "DELETE FROM db_permissions WHERE db=%s AND config=%s",
         name,CN(c->name) );

  query( "INSERT INTO db_permissions VALUES (%s,%s,%s)", name,CN(c->name),
	 (level?level==2?"write":"read":"none") );
  
  if( (int)d[0]["local"] )
    set_user_permissions( c, name, level );

  clear_sql_caches();

  return 1;
}

mapping module_table_info( string db, string table )
{
  array td;
  if( sizeof(td=query("SELECT * FROM module_tables WHERE db=%s AND tbl=%s",
		      db, table ) ) )
    return td[0];
  return ([]);
}

string insert_statement( string db, string table, mapping row )
//! Convenience function.
{
  function q = cached_get( db )->quote;
  string res = "INSERT INTO "+table+" ";
  array(string) vi = ({});
  array(string) vv = ({});
  foreach( indices( row ), string r )
    if( !has_value( r, "." ) )
    {
      vi += ({r});
      vv += ({"'"+q(row[r])+"'"});
    }
  return res + "("+vi*","+") VALUES ("+vv*","+")";
}

void is_module_table( RoxenModule module, string db, string table,
		   string|void comment )
//! Tell the system that the table 'table' in the database 'db'
//! belongs to the module 'module'. The comment is optional, and will
//! be shown in the administration interface if present.
{
  string mn = module ? module->sname(): "";
  string cn = module ? module->my_configuration()->name : "";
  catch(query("DELETE FROM module_tables WHERE "
	      "module=%s AND conf=%s AND tbl=%s AND db=%s",
	      mn,cn,table,db ));

  query("INSERT INTO module_tables (conf,module,db,tbl,comment) VALUES "
	"(%s,%s,%s,%s,%s)",
	cn,mn,db,table,comment||"" );
}

void is_module_db( RoxenModule module, string db, string|void comment )
//! Tell the system that the databse 'db' belongs to the module 'module'.
//! The comment is optional, and will be shown in the configuration
//! interface if present.
{
  is_module_table( module, db, "", comment );
}
  

static void create()
{
  mixed err = 
  catch {
    query("CREATE TABLE IF NOT EXISTS db_backups ("
	  " db varchar(80) not null, "
	  " tbl varchar(80) not null, "
	  " directory varchar(255) not null, "
	  " whn int unsigned not null, "
	  " INDEX place (db,directory))");
       
  query("CREATE TABLE IF NOT EXISTS db_groups ("
	" db varchar(80) not null, "
	" groupn varchar(80) not null)");

  query("CREATE TABLE IF NOT EXISTS groups ( "
	"  name varchar(80) not null primary key, "
	"  lname varchar(80) not null, "
	"  comment blob not null, "
	"  pattern varchar(255) not null default '')");

  catch(query("INSERT INTO groups (name,lname,comment,pattern) VALUES "
      " ('internal','Uncategorized','Databases without any group','')"));

  query("CREATE TABLE IF NOT EXISTS module_tables ("
	"  conf varchar(80) not null, "
	"  module varchar(80) not null, "
	"  db   varchar(80) not null, "
	"  tbl varchar(80) not null, "
	"  comment blob not null, "
	"  INDEX place (db,tbl), "
	"  INDEX own (conf,module) "
	")");
    
  multiset q = (multiset)query( "SHOW TABLES" )->Tables_in_roxen;
  if( !q->dbs )
  {
    query( #"
CREATE TABLE dbs (
 name VARCHAR(64) NOT NULL PRIMARY KEY,
 path VARCHAR(100) NOT NULL, 
 local INT UNSIGNED NOT NULL )
 " );
    create_db( "local",  0, 1 );
    create_db( "roxen",  0, 1 );
    create_db( "mysql",  0, 1 );

    is_module_db( 0, "local",
		  "The local database contains data that "
		  "should not be shared between multiple-frontend servers" );
  }
  
  if( !q->db_permissions )
  {
    query(#"
CREATE TABLE db_permissions (
 db VARCHAR(64) NOT NULL, 
 config VARCHAR(80) NOT NULL, 
 permission ENUM ('none','read','write') NOT NULL,
 INDEX db_conf (db,config))
" );
    // Must be done from a call_out -- the configurations does not
    // exist yet (this code is called before 'main' is called in
    // roxen)
    call_out(
      lambda(){
	foreach( roxenp()->configurations, object c )
	{
	  set_permission( "local", c, WRITE );
	}
      }, 0 );
  }

	
  if( file_stat( "data/docs.frm" ) )
  {
    if( !sizeof(query( "SELECT tbl FROM db_backups WHERE "
		       "db=%s AND directory=%s",
		       "docs", getcwd()+"/etc" ) ) )
      query("INSERT INTO db_backups (db,tbl,directory,whn) "
	    "VALUES ('docs','docs','"+getcwd()+"/etc','"+time()+"')");
  }
  
  return;
  };

  werror( describe_backtrace( err ) );
}
