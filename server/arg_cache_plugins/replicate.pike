// This file is part of Roxen WebServer.
// Copyright © 2001, Roxen IS.

#if constant(REPLICATE)
#define QUERY(X,Y...)    get_db()->query(X,Y)
#define sQUERY( X,Y...) get_sdb()->query(X,Y)

static int off;
object cache;

Sql.Sql get_sdb()
{
  return DBManager.cached_get( "replicate" );
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


void initiate_servers()
{
  // Locate new servers every minute.
  call_out( initiate_servers, 60 );
  
  servers = ([]);
  foreach( sQUERY( "SELECT secret FROM servers" )->secret, string s )
    servers[s] = Server( s );
}

mapping(string:Server) servers;
static mapping quick_cache = ([]);

static void init_replicate_db()
{
  mixed err = catch {
    // Avoid the 'IF NOT EXISTS' feature here to be more compatible.
    sQUERY( "CREATE TABLE "+cache->name+" ("
	    "   server varchar(80) not null, "
	    "   id int not null, "
	    "   dat_content blob not null, "
	    "   ctime int unsigned not null, "
	    "   INDEX k (id), "
	    "   INDEX s (server), "
	    "   INDEX c (ctime) "
	    ")" );
  };
  err = catch {
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
   QUERY( "CREATE TABLE IF NOT EXISTS "+cache->name+"_foreign ("
	  " remote varchar(255) not null, "
	  " id  varchar(255) not null, "
	  " INDEX k (remote) )" );

  DBManager.is_module_table( 0, "local",
			     cache->name+"_foreign",
			     "Used to cache the mapping of foreign cache keys "
			     "to local IDs");

  if( !d )
  {
    off = -1;
    report_warning("The replicate database is currently down\n" );
    return;
  }

  init_replicate_db();
}

static int get_and_store_data_from_server( Server server, int id )
{
  string data = server->lookup( id );
  if( !data )
  {
    off = -1;
    return -1;
  }
  return cache->create_key( data );
}

static array(int) server_secret_decode( string a, string secret )
{
  object crypto = Crypto.arcfour();
  crypto->set_encrypt_key( secret );
  a = Gmp.mpz( a, 36 )->digits( 256 );
  a = crypto->crypt( a );
  int i, j;
#ifdef REPLICATE_DEBUG
  werror("Decoding with %O got %O\n", secret, a );
#endif
  if( sscanf( a, "%d\327%d", i, j ) == 2 )
    return ({ i, j });
  return 0;
}

#define ENSURE_NOT_OFF(X)						\
  if( off )								\
  {									\
    if( off == -1 )							\
      if( !catch( get_sdb() ) )						\
      {									\
	init_replicate_db();						\
	off = 0;							\
      }									\
    if( off )								\
      return X;								\
  } else {								\
    if( catch( get_sdb() ) )						\
      off = -1;								\
    if(off)return X;							\
  }


int create_key( int id, string data )
{
  ENSURE_NOT_OFF( 0 );
#ifdef REPLICATE_DEBUG
  werror("Create new key %O for %O\n", id, cache->secret );
#endif
  sQUERY( "INSERT INTO "+cache->name+" (server,id,dat_content,ctime) "
	  "VALUES (%s,%d,%s,%d)", cache->secret, id, data, time() );
}

array(int) decode_id( string data )
{
  ENSURE_NOT_OFF( 0 );
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
  if( sizeof(res = QUERY( "SELECT id FROM "+cache->name+
		           "_foreign WHERE remote=%s", data ) ) )
  {
#ifdef REPLICATE_DEBUG
    werror("Found in local cache.\n" );
#endif
    return quick_cache[data]=(array(int))(res[0]->id/",");
  }

  foreach( indices(servers), string server )
  {
    string sec = servers[server]->secret;
    if( array id = server_secret_decode( data, sec ) )
    {
      id[0] = get_and_store_data_from_server( servers[server], id[0] );

      id[1] = get_and_store_data_from_server( servers[server], id[1] );

      if( off == -1 )
	return 0;
#ifdef REPLICATE_DEBUG
      werror("Found in remote cache. Server is %O\n", server );
#endif
      QUERY( "INSERT INTO "+cache->name+"_foreign (id,remote) VALUES (%s,%s)",
	     ((array(string))id)*",", data );
      return quick_cache[data] = id;
    }
  }
  return 0;
}
#else
constant disabled = 1;
#endif
