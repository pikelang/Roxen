// This file is part of Roxen WebServer.
// Copyright © 2001, Roxen IS.

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
    catch
    {
      return
	sQUERY( "SELECT dat_content FROM "+cache->name+
		" WHERE server=%s AND id=%d", secret, id )[0]->dat_content;
    };
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
	    "   server varchar(80) not null, "
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
	    "   secret varchar(255) not null primary key"
	    ")" );
  };
  catch {
    sQUERY( "INSERT INTO servers (secret) VALUES (%s)",
	    cache->secret );
  };

  // Populate with entries created when the shared table was down.

  Thread.MutexKey key;
  catch( key = cache->mutex->lock() );
  array have = (array(int))
    cache->db->query( "SELECT id from "+cache->name )->id;

  array shave = (array(int))
    sQUERY( "SELECT id FROM "+cache->name+
	    " WHERE server=%s", cache->secret )->id;
  werror("Synchronizing remote arg-cache with local cache... ");
  foreach( have-shave, int id )
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
	  " remote    VARCHAR(255) NOT NULL, "
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
    off = -1;
    return -1;
  }
  return cache->create_key( data, 0, index_id );
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
    if( catch( get_sdb() ) )						\
      off = -1;								\
    if(off)return X;							\
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

array(int) get_local_ids(int|void from_time)
{
#ifdef THREADS
  Thread.MutexKey key = cache->mutex->lock();
#endif  
  array have = (array(int))
    cache->db->query( "SELECT id from "+cache->name+
		      " WHERE atime >= %d", from_time )->id;

  ENSURE_NOT_OFF( have );
  array shave = (array(int))
    sQUERY( "SELECT id FROM "+cache->name+
	    " WHERE server!=%s", cache->secret )->id;
  return have-shave;
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
#else
constant disabled = 1;
#endif
