// This file is part of Roxen WebServer.
// Copyright © 2001 - 2006, Roxen IS.

constant cvs_version="$Id: replicate.pike,v 1.24 2006/03/15 15:58:59 wellhard Exp $";

#if constant(WS_REPLICATE)
#ifdef ENABLE_NEW_ARGCACHE
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

static int off;
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
  return db;
}

Sql.Sql get_db()
{
  return DBManager.cached_get( "local" );
}

static void init_replicate_db()
{
  catch {
    // Avoid the 'IF NOT EXISTS' feature here to be more compatible.
    sQUERY( "CREATE TABLE "+cache->name+"2 ("
	    " id        CHAR(32) PRIMARY KEY, "
	    " ctime     DATETIME NOT NULL, "
	    " atime     DATETIME NOT NULL, "
	    " contents  BLOB NOT NULL)");
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

static void create( object c )
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
    report_warning("The replicate database is currently down\n" );
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

#else // ENABLE_NEW_ARGCACHE

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

static int off;
object cache;

Sql.Sql get_sdb()
{
  object db = DBManager.cached_get( "replicate" );
  // Make sure the db is online.
  db->query("SELECT 1;");
  return db;
}

Sql.Sql get_db()
{
  return DBManager.cached_get( "local" );
}

static class Server( string secret )
{
  // find 'id' in the remote cache table, and return the
  // data.
  string lookup( int id )
  {
    mixed err = catch
    {
      return
	sQUERY( "SELECT dat_content FROM "+cache->name+
		" WHERE server=%s AND id=%d", secret, id )[0]->dat_content;
    };
    if (err) {
#ifdef REPLICATE_DEBUG
      werror(describe_backtrace(err));
#endif
    }
  }
}

void low_initiate_servers()
{
  catch {
    mapping(string:Server) tmp_servers = ([]);
    foreach( sQUERY( "SELECT secret FROM servers" )->secret, string s )
      tmp_servers[s] = Server( s );
    servers = tmp_servers;
  };
}

void initiate_servers()
{
  low_initiate_servers();
  // Locate new servers every minute.
  roxen.background_run( 60, initiate_servers );
}

mapping(string:Server) servers;
static mapping quick_cache = ([]);

static void init_replicate_db()
{
  if(catch {
    // Avoid the 'IF NOT EXISTS' feature here to be more compatible.
    sQUERY( "CREATE TABLE "+cache->name+" ("
	    "   server varchar(80) binary not null, "
	    "   id int not null, "
	    "   dat_content blob not null, "
	    "   ctime int unsigned not null, "
	    "   PRIMARY KEY(server, id), "
	    "   INDEX k (id), "
	    "   INDEX s (server), "
	    "   INDEX c (ctime) "
	    ")" );
  })
    catch {
      // If the table exists, add a primary key to the remote arguments table. 
      sQUERY( "ALTER IGNORE TABLE "+cache->name+
	      "  ADD PRIMARY KEY (server, id)" );
    };
  catch {
    sQUERY( "CREATE TABLE servers ("
	    "   secret varchar(255) binary not null primary key"
	    ")" );
  };
  catch {
    sQUERY( "INSERT INTO servers (secret) VALUES (%s)",
	    cache->secret );
  };

  // Populate with entries created when the shared table was down.

  Thread.MutexKey key;
  catch( key = cache->mutex->lock() );
  
  werror("Synchronizing remote arg-cache with local cache... ");
  int max_replicated_id = (int)
    sQUERY( "SELECT MAX(id) as max_id "
	    "  FROM "+cache->name+
	    " WHERE server = %s", cache->secret )[0]->max_id;
  
  array new_entries = (array(int))
    cache->db->query( "SELECT id "
		      "  FROM "+cache->name+
		      " WHERE id > %d", max_replicated_id )->id;

  foreach( new_entries, int id )
    create_key( id, cache->read_args( id ) );
  werror("Done\n");
  key = 0;

  DBManager.is_module_table( 0, "replicate", ""+cache->name, 
			     "A shared arg-cache database used for "
			     "replication purposes.");
  DBManager.is_module_table( 0, "replicate", "servers", 
			     "Server identities.");

  initiate_servers();
}

static void create( object c )
{
   object d;
   cache = c;
   catch {
    if( !(d=get_sdb()) )
    {
      report_error("You must create a database named 'replicate' in a\n"
		   "shared MySQL for this module to work.\n" );
      off = 1;
      return;
    }
   };
  
   // local cache.
   QUERY( "CREATE TABLE IF NOT EXISTS "+cache->name+"_replicated ("
	  " remote    VARCHAR(255) BINARY NOT NULL, "
	  " index_id  INT UNSIGNED NOT NULL, "
	  " value_id  INT UNSIGNED NOT NULL, "
	  " PRIMARY KEY (remote, index_id, value_id), "
	  " INDEX k (remote) )" );

  DBManager.is_module_table( 0, "local",
			     cache->name+"_replicated",
			     "Used to cache the mapping of replicated "
			     "cache keys to local IDs");

  if( !d )
  {
    off = -1;
    report_warning("The replicate database is currently down\n" );
    return;
  }

  init_replicate_db();
}

static int get_and_store_data_from_server( Server server, int id,
					   int|void index_id )
{
  string data = server->lookup( id );
  if( !data )
  {
#ifdef REPLICATE_DEBUG
    werror("get_and_store_data_from_server failed.\n");
#endif
    off = -1;
    return -1;
  }
  return cache->create_key( data, 0, index_id );
}

Sql.Sql debug_get_sdb() {
  Sql.Sql db;
  if (mixed err = catch( db = get_sdb() )) {
#ifdef REPLICATE_DEBUG
    werror(describe_backtrace(err));
#endif
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

int create_key( int id, string data, string|void server )
{
  ENSURE_NOT_OFF( 0 );
  if(server && !servers[server]) {
#ifdef REPLICATE_DEBUG
    werror("Adding new server %O\n", server );
#endif
    catch {
      sQUERY( "INSERT INTO servers (secret) VALUES (%s)", server );
    };
    low_initiate_servers();
  }
  string secret = server||cache->secret;
  
#ifdef REPLICATE_DEBUG
  werror("Create new remote key %O for %O\n", id, secret );
#endif
  // Catch "Duplicate entry" errors.
  catch {
    sQUERY( "INSERT INTO "+cache->name+" (server,id,dat_content,ctime) "
	    "VALUES (%s,%d,%s,%d)", secret, id, data, time() );
  };
}

static void add_replicated_key(int local_index_id, int local_value_id,
			       string remote_key)
{
  CATCH_DUPLICATE(
    QUERY( "INSERT INTO "+cache->name+"_replicated "
	   " (remote, index_id, value_id) VALUES (%s, %d, %d)",
	   remote_key, local_index_id, local_value_id );
  );
}

array(int) decode_id( string data )
{
#ifdef REPLICATE_DEBUG
  werror("Request for ID %O\n", data );
#endif
  array res;
  if( quick_cache[data] )
  {
#ifdef REPLICATE_DEBUG
    werror("Found in quick cache.\n" );
#endif
    return quick_cache[ data ];
  }
  if( sizeof(res = QUERY( "SELECT index_id, value_id FROM "+cache->name+
			  "_replicated WHERE remote=%s", data ) ) )
  {
#ifdef REPLICATE_DEBUG
    werror("Found in local cache.\n" );
#endif
    return quick_cache[data]=
      ({ (int)res[0]->index_id, (int)res[0]->value_id });
  }

  ENSURE_NOT_OFF( 0 );
  foreach( indices(servers), string server )
  {
    string sec = servers[server]->secret;
    if( array id = cache->low_decode_id( data, sec ) )
    {
      Thread.MutexKey key;
      catch ( key = cache->mutex->lock() );

      id[0] = get_and_store_data_from_server( servers[server], id[0] );
      id[1] = get_and_store_data_from_server( servers[server], id[1], id[0] );

      if( off == -1 )
	return 0;

#ifdef REPLICATE_DEBUG
      werror("Found in remote cache. Server is %O\n", server );
#endif
      add_replicated_key(id[0], id[1], data);
      return quick_cache[data] = id;
    }
  }
  return 0;
}

void create_remote_key(int id, string key,
		       int index_id, string index_key,
		       string server)
{
#ifdef THREADS
  Thread.MutexKey mutex_key = cache->mutex->lock();
#endif
  
  // Create a record in the remote database.
  create_key(id, key, server);

  // If an index id is specified create a record in the remote
  // database and create local records for index key and value
  // key. Also create a record in the arguments_replicated table.
  if(index_id >= 0 && index_key) {
    create_key(index_id, index_key, server);
    add_replicated_key(cache->create_key(index_key, 0),
		       cache->create_key(key, 0, index_id),
		       cache->encode_id(index_id, id, server));
  }
}
#endif // ENABLE_NEW_ARGCACHE

#else
constant disabled = 1;
#endif
