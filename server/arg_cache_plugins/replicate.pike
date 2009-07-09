// This file is part of Roxen WebServer.
// Copyright © 2001 - 2009, Roxen IS.

constant cvs_version="$Id: replicate.pike,v 1.29 2009/07/09 15:55:07 wellhard Exp $";

#if constant(WS_REPLICATE)

#define QUERY(X,Y...)    get_db()->query(X,Y)
#define sQUERY( X,Y...) get_sdb()->query(X,Y)

#define CATCH_DUPLICATE(X)                                            \
  do {                                                                \
    mixed err = catch { X };                                          \
    if(err)                                                           \
      if(!arrayp(err) || !sizeof(err) || !sizeof(err[0]) ||           \
         !glob("*duplicate entry*", lower_case(err[0])))              \
         throw(err);                                                  \
  } while(0)

#ifdef ARGCACHE_DEBUG
#define dwerror(ARGS...) werror(ARGS)
#else
#define dwerror(ARGS...) 0
#endif    

protected int off;
// The off variable can have the following values:
//   -1: The shared replicate database is temporarly down.
//    0: The shared replicate database is online.
//    1: The shared replicate database is not configured.

object cache;

Sql.Sql get_sdb()
{
  object db = DBManager.cached_get( "replicate" );
  // Make sure the db is online.
  db->query("SELECT 1;");
  // Make sure a database is selected.
  db->query("SHOW TABLES");
  return db;
}

Sql.Sql get_db()
{
  return DBManager.cached_get( "local" );
}

protected void init_replicate_db()
{
  catch {
    // Avoid the 'IF NOT EXISTS' feature here to be more compatible.
    sQUERY( "CREATE TABLE "+cache->name+"2 ("
	    " id        CHAR(32) PRIMARY KEY, "
	    " ctime     DATETIME NOT NULL, "
	    " atime     DATETIME NOT NULL, "
	    " contents  MEDIUMBLOB NOT NULL)");
  };

  catch {
      array(mapping(string:mixed)) res = 
	sQUERY("DESCRIBE "+cache->name+"2 contents");

      if(res[0]->Type == "blob") {
	sQUERY("ALTER TABLE "+cache->name+"2 MODIFY contents MEDIUMBLOB NOT NULL");
	werror("ArgCache replication: Extending \"contents\" field in table \"%s2\" from BLOB to MEDIUMBLOB.\n", cache->name);
      }
  };
  
  // Populate with entries created when the shared table was down.

  Thread.MutexKey key;
  catch( key = cache->mutex->lock() );
  
  werror("Synchronizing remote arg-cache with local cache:\n");
  constant FETCH_ROWS = 10000;
  constant CHECK_ROWS = 100;
  int cursor;
  array(mapping) rows =
    QUERY( "SELECT COUNT(id) as ids from "+cache->name+"2");
  werror("  found %d entries ", (int)rows[0]->ids);
  do {
    rows = 
      QUERY( "SELECT id from "+cache->name+"2 "
	     " LIMIT %d, %d", cursor, FETCH_ROWS );
    cursor += FETCH_ROWS;

    for(int i = 0; i < sizeof(rows); i += CHECK_ROWS) {
      array(string) ids = rows[i .. i + CHECK_ROWS - 1]->id;
      array(mapping) shared_rows =
	sQUERY( "SELECT id from "+cache->name+"2 "
		" WHERE id in ('"+(map(ids, get_db()->quote) * "','")+"')" );
      if(sizeof(ids) != sizeof(shared_rows)) {
	array(string) missing_ids = ids - shared_rows->id;
	// werror("Found %O missing ids ", sizeof(missing_ids));
	array(mapping) missing_rows =
	  QUERY( "SELECT id, contents from "+cache->name+"2 "
		 " WHERE id in ('"+(map(missing_ids, get_db()->quote) * "','")+"')" );
	
	foreach(missing_rows, mapping missing_row)
	  create_key(missing_row->id, missing_row->contents);
      }
    }
    werror(".");
  } while(sizeof(rows) == FETCH_ROWS);
  werror(" Done\n");
  key = 0;

  DBManager.is_module_table( 0, "replicate", ""+cache->name+"2", 
			     "A shared arg-cache database used for "
			     "replication purposes.");
}

protected void create( object c )
{
  object d;
  cache = c;
  mixed err = catch {
    if( !(d = get_sdb()) ) {
      report_error("You must create a database named 'replicate' in a\n"
		   "shared MySQL for this module to work.\n" );
      off = 1;
      return;
    }
  };
  
  if( err )
  {
    off = -1;
    report_warning("The replicate database is currently down: %O\n",
		   DBManager.db_url("replicate", 1) );
    return;
  }

  init_replicate_db();
}

Sql.Sql debug_get_sdb() {
  Sql.Sql db;
  if (mixed err = catch( db = get_sdb() )) {
    dwerror(describe_backtrace(err));
    return 0;
  }
  return db;
}

#define ENSURE_NOT_OFF(X)						\
  if( off )								\
  {									\
    if( off == -1 )							\
      if( !catch( get_sdb() ) )						\
      {									\
	off = 0;							\
	init_replicate_db();						\
      }									\
    if( off )								\
      return X;								\
  } else {								\
    if( !debug_get_sdb() )						\
      off = -1;								\
    if(off)return X;							\
  }

int is_functional()
// Returns 1 if the database is configured and upp and running, otherwise 0.
{
  ENSURE_NOT_OFF(0);
  return 1;
}

void create_key( string id, string encoded_args )
{
  ENSURE_NOT_OFF( 0 );
  
  array(mapping) rows =
    sQUERY("SELECT id, contents FROM "+cache->name+"2 WHERE id = %s", id );
    
  foreach( rows, mapping row )
    if( row->contents != encoded_args ) {
      report_error("ArgCache.replicate.create_key(): "
		   "Duplicate key found! Please report this to support@roxen.com: "
		   "id: %O, old data: %O, new data: %O\n",
		   id, row->contents, encoded_args);
      error("ArgCache.replicate.create_key() Duplicate shared key found!\n");
    }
  
  if(sizeof(rows))
    return;

  CATCH_DUPLICATE(
    sQUERY( "INSERT INTO "+cache->name+"2 "
	    "  (id, contents, ctime, atime) VALUES "
	    "  (%s, %s, NOW(), NOW())", id, encoded_args );
  );
  dwerror("ArgCache.replicate: Create new key %O\n", id );
}

string read_encoded_args( string id )
//! Find 'id' in the remote cache table, and return the data.
{
  dwerror("ArgCache.replicate: Request for id: %O\n", id );
  
  ENSURE_NOT_OFF( 0 );
  string encoded_args;
  if(mixed err = catch {
      array res = sQUERY("SELECT contents FROM "+cache->name+"2 "
			 " WHERE id = %s", id);
      if( sizeof(res) ) {
	sQUERY("UPDATE "+cache->name+"2 "
	       "   SET atime = NOW() "
	       " WHERE id = %s", id);
	encoded_args = res[0]->contents;
      }
    }) 
    {
      off = -1;
      dwerror(describe_backtrace(err));
      return 0;
    }
  if(!encoded_args) {
    dwerror("ArgCache.replicate: Request for unknown key: %O\n", id );
    return 0;
  }
  cache->create_key(id, encoded_args);
  return encoded_args;
}

#else
constant disabled = 1;
#endif
