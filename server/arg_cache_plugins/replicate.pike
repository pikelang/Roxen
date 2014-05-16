// This file is part of Roxen WebServer.
// Copyright © 2001 - 2009, Roxen IS.

constant cvs_version="$Id$";

#if constant(WS_REPLICATE)

#define QUERY(X,Y...)    get_db()->query(X,Y)
#define sQUERY( X,Y...) get_sdb()->query(X,Y)

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
  if(!db)
    return 0;
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

protected void resilver_replicate_db()
{
  werror("Arg-cache replication thread started.\n");
  // Outer loop is for initialization and error recovery.
  while(this_object()) {
    sleep(60);
    mixed err = catch {
      Sql.Sql sdb = get_sdb();

      if (!sdb) continue;

      if (catch(sdb->query("SELECT id FROM "+cache->name+"2 LIMIT 0"))) {
	// Avoid the 'IF NOT EXISTS' feature here to be more compatible.
	sdb->query( "CREATE TABLE "+cache->name+"2 ("
		    " id        CHAR(32) PRIMARY KEY, "
		    " ctime     DATETIME NOT NULL, "
		    " atime     DATETIME NOT NULL, "
		    " contents  MEDIUMBLOB NOT NULL)");
      }

      DBManager.is_module_table( 0, "replicate", ""+cache->name+"2", 
				 "A shared arg-cache database used for "
				 "replication purposes.");

      array(mapping(string:mixed)) res = 
	sdb->query("DESCRIBE "+cache->name+"2 contents");

      if(res[0]->Type == "blob") {
	sdb->query("ALTER TABLE "+cache->name+"2 "
		   "MODIFY contents MEDIUMBLOB NOT NULL");
	werror("ArgCache replication: Extending \"contents\" field in "
	       "table \"%s2\" from BLOB to MEDIUMBLOB.\n", cache->name);
      }

      // The inner loop is for actual replication of data.
      while(this_object()) {
	sdb = UNDEFINED;
  
	sleep(60);

	sdb = get_sdb();

	constant FETCH_ROWS = 10000;
	constant CHECK_ROWS = 100;

	int t = time();

	// Populate with entries created when the shared table was down.

	int resilver;

	array(mapping) rows =
	  QUERY( "SELECT id FROM "+cache->name+"2 "
		 " WHERE sync_time IS NULL "
		 " LIMIT " + FETCH_ROWS);
	if (!sizeof(rows)) {
	  // Resilver the oldest rows that haven't been resilvered
	  // for at least one hour.
	  rows =
	    QUERY( "SELECT id FROM "+cache->name+"2 "
		   " WHERE sync_time < " + (t - 3600) + " "
		   " ORDER BY sync_time ASC "
		   " LIMIT " + CHECK_ROWS);

	  resilver = 1;
	  if (!sizeof(rows)) continue;	// All is well.
	} else {
	  werror("Synchronizing remote arg-cache with local cache:\n");
	  werror("  Found %d entries to sync ", sizeof(rows));
	}

	for(int i = 0; i < sizeof(rows); i += CHECK_ROWS) {
	  array(string) ids = rows[i .. i + CHECK_ROWS - 1]->id;
	  array(mapping) shared_rows =
	    sdb->query( "SELECT id from "+cache->name+"2 "
			" WHERE id in ('"+
			(map(ids, sdb->quote) * "','")+"')" );
	  if(sizeof(ids) != sizeof(shared_rows)) {
	    array(string) missing_ids = ids - shared_rows->id;
	    // werror("Found %O missing ids ", sizeof(missing_ids));
	    array(mapping) missing_rows =
	      QUERY( "SELECT id, contents from "+cache->name+"2 "
		     " WHERE id in ('"+
		     (map(missing_ids, get_db()->quote) * "','")+"')" );

	    if (resilver) {
	      werror("Synchronizing remote arg-cache with local cache:\n");
	      werror("  Found %d lost entries\n", sizeof(missing_rows));
	    }

	    foreach(missing_rows, mapping missing_row)
	      create_key(missing_row->id, missing_row->contents);

	    ids -= missing_ids;
	  }

	  if (sizeof(ids)) {
	    // Bump the timestamps for the already synced entries.
	    QUERY( "UPDATE "+cache->name+"2 "
		   "   SET sync_time = " + t + " "
		   " WHERE id in ('" +
		   (map(ids, get_db()->quote) * "','")+"')" );
	  }
	  if (!resilver) werror(".");
	}
	if (!resilver) werror(" done.\n");
      }
    };
    if (this_object() && err) {
      werror("\nArg-cache synchronization error:\n"
	     "%s\n"
	     "Retrying arg-cache sync in 60 seconds...\n",
	     describe_backtrace(err));
    }
  }
  werror("Arg-cache replication thread terminated.\n");
}

protected void create( object c )
{
  object d;
  cache = c;
  mixed err = catch {
    if( !(d = get_sdb()) ) {
      report_error("NOTE: You must create a database named 'replicate' in a\n"
		   "      shared MySQL for this module to work.\n" );
      off = 1;
      return;
    }
  };

  Thread.Thread(resilver_replicate_db);
  
  if( err )
  {
    off = -1;
    report_warning("NOTE: The replicate database is currently down: %O\n",
		   DBManager.db_url("replicate", 1) );
    return;
  }
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
      report_error("ArgCache.replicate.create_key(): Duplicate key found! "
		   "Please report this to support@roxen.com:\n"
		   "  id: %O\n"
		   "  old data: %O\n"
		   "  new data: %O\n"
		   "  Updating shared database with new value.\n",
		   id, row->contents, encoded_args);
      
      // Remove the old entry (probably corrupt). No need to update
      // the database since the query below uses REPLACE INTO.
      rows = ({});
    }
  
  if(sizeof(rows))
    return;

  // Use REPLACE INTO to cope with entries created by other threads as
  // well as corrupted entries that should be overwritten.
  sQUERY( "REPLACE INTO "+cache->name+"2 "
	  "  (id, contents, ctime, atime) VALUES "
	  "  (%s, %s, NOW(), NOW())", id, encoded_args );
  
  QUERY("UPDATE "+cache->name+"2 "
	"   SET sync_time = %d "
	"   WHERE id = %s", time(1), id);
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
