// This file is part of ChiliMoon.
// Copyright © 1996 - 2001, Roxen IS.
// $Id: cache.pike,v 1.93 2004/06/15 22:11:03 _cvs_stephen Exp $

// #pragma strict_types

#include <roxen.h>
#include <config.h>

// A cache entry is an array with four elements
#define ENTRY_SIZE 4
// The elements are as follows:
// A timestamp when the entry was last used
#define TIMESTAMP 0
// The actual data
#define DATA 1
// A timeout telling when the data is no longer valid.
#define TIMEOUT 2

#undef CACHE_WERR
#ifdef CACHE_DEBUG
# define CACHE_WERR(X ...) report_debug("CACHE: " X);
#else
# define CACHE_WERR(X ...)
#endif

#undef MORE_CACHE_WERR
#ifdef MORE_CACHE_DEBUG
# define MORE_CACHE_WERR(X ...) report_debug("CACHE: " X);
#else
# define MORE_CACHE_WERR(X ...)
#endif

// The actual cache along with some statistics mappings.
static mapping(string:mapping(string:array)) caches;
static mapping(string:int) hits=([]), all=([]);

//! Empties the memory cache from entries.
void flush_memory_cache ()
{
  caches = ([]);
  hits = ([]);
  all = ([]);
}

//! Lookup an entry in a cache.
mixed cache_lookup(string cache, mixed key)
{
  CACHE_WERR("cache_lookup(%O,%O)  ->  \n", cache, key);
  all[cache]++;
  int t=time(1);
  // Does the entry exist at all?
  if(array entry = (caches[cache] && caches[cache][key]) )
    // Is it time outed?
    if (entry[TIMEOUT] && entry[TIMEOUT] < t) {
      m_delete (caches[cache], key);
      CACHE_WERR("Timed out\n");
    }
    else {
      // Update the timestamp and hits counter and return the value.
      caches[cache][key][TIMESTAMP]=t;
      CACHE_WERR("Hit\n");
      hits[cache]++;
      return entry[DATA];
    }
  else CACHE_WERR("Miss\n");
  return UNDEFINED;
}

//! Return all indices used by a given cache or indices of available caches
array(string) cache_indices(string|void cache)
{
  if (cache)
    return (caches[cache] && indices(caches[cache])) || ({ });
  else
    return indices(caches);
}

//! Return some fancy cache statistics.
mapping(string:array(int)) status()
{
  mapping(string:array(int)) ret = ([ ]);
  foreach(caches; string name; mapping cache) {
    //  We only show names up to the first ":" if present. This lets us
    //  group entries together in the status table.
    string show_name = (name / ":")[0];
    int size = -1;
    catch( size = sizeof(encode_value(cache)) );
    array(int) entry = ({ sizeof(cache),
			  hits[name],
			  all[name],
			  size });
    if (!zero_type(ret[show_name]))
      for (int idx = 0; idx < 3; idx++)
	ret[show_name][idx] += entry[idx];
    else
      ret[show_name] = entry;
  }
  return ret;
}

//! Remove an entry from the cache. Removes the entire cache if no
//! entry key is given.
void cache_remove(string cache, void|mixed key)
{
  CACHE_WERR("cache_remove(%O,%O)\n", cache, key);
  if(!cache) {
    m_delete(caches, cache);
    m_delete(hits, cache);
    m_delete(all, cache);
  }
  else
    if(caches[cache])
      m_delete(caches[cache], key);
}

//! Add an entry to a cache
mixed cache_set(string cache, mixed key, mixed val, int|void tm)
{
#if MORE_CACHE_DEBUG
  CACHE_WERR("cache_set(%O, %O, %O)\n", cache, key, /* val */ _typeof(val));
#else
  CACHE_WERR("cache_set(%O, %O, %t)\n", cache, key, val);
#endif
  int t=time(1);
  if(!caches[cache])
    caches[cache] = ([ ]);
  array entry = allocate(ENTRY_SIZE);
  entry[DATA] = val;
  if(tm) entry[TIMEOUT] = t + tm;
  entry[TIMESTAMP] = t;
  caches[cache][key] = entry;
  return val;
}

//! Clean the cache.
void cache_clean()
{
  int gc_time=[int](([function(string:mixed)]get_core()->
		     query)("mem_cache_gc"));
  string a, b;
  array c;
  mapping(string:array) cache;
  int t=time(1);
  CACHE_WERR("cache_clean()\n");
  foreach(caches; a; cache)
  {
    MORE_CACHE_WERR("  Class  %O\n", a);
    foreach(cache; b; c)
    {
      MORE_CACHE_WERR("     %O\n", b);
#ifdef DEBUG
      if(!intp(c[TIMESTAMP]))
	error("     Illegal timestamp in cache ("+a+":"+b+")\n");
#endif
      if(c[TIMEOUT] && c[TIMEOUT] < t) {
	MORE_CACHE_WERR("     DELETED (explicit timeout)\n");
	m_delete(cache, b);
      }
      else {
	if(c[TIMESTAMP]+1 < t && c[TIMESTAMP] + gc_time)
	  {
	    MORE_CACHE_WERR("     DELETED\n");
	    m_delete(cache, b);
	  }
#ifdef MORE_CACHE_DEBUG
	else
	  CACHE_WERR("Ok\n");
#endif
      }
      if(!sizeof(cache))
      {
	MORE_CACHE_WERR("  Class DELETED.\n");
	m_delete(caches, a);
      }
    }
  }
  get_core()->background_run (gc_time, cache_clean);
}


// --- Session cache -----------------

#ifndef SESSION_BUCKETS
# define SESSION_BUCKETS 4
#endif
#ifndef SESSION_SHIFT_TIME
# define SESSION_SHIFT_TIME 15*60
#endif

// The minimum time until which the session should be stored.
private mapping(string:int) session_persistence;
// The sessions, divided into several buckets.
private array(mapping(string:mixed)) session_buckets;
// The database for storage of the sessions.
private function(string:Sql.Sql) db;
// The biggest value in session_persistence
private int max_persistence;

// The low level call for storing a session in the database
private void store_session(string id, mixed data, int t) {
  data = encode_value(data);
  db("local")->query("REPLACE INTO session_cache VALUES (%s," +
		     t + ",%s)", id, data);
}

// GC that, depending on the sessions session_persistence either
// throw the session away or store it in a database.
private void session_cache_handler() {
  int t=time(1);
  if(max_persistence>t) {

  clean:
    foreach(indices(session_buckets[-1]), string id) {
      if(session_persistence[id]<t) {
	m_delete(session_buckets[-1], id);
	m_delete(session_persistence, id);
	continue;
      }
      for(int i; i<SESSION_BUCKETS-2; i++)
	if(session_buckets[i][id]) {
	  continue clean;
	}
      if(objectp(session_buckets[-1][id])) {
	m_delete(session_buckets[-1], id);
	m_delete(session_persistence, id);
	continue;
      }
      store_session(id, session_buckets[-1][id], session_persistence[id]);
      m_delete(session_buckets[-1], id);
      m_delete(session_persistence, id);
    }
  }

  session_buckets = ({ ([]) }) + session_buckets[..SESSION_BUCKETS-2];
  get_core()->background_run(SESSION_SHIFT_TIME, session_cache_handler);
}

// Stores all sessions that should be persistent in the database.
// This function is called upon exit.
private void session_cache_destruct() {
  int t=time(1);
  if(max_persistence>t) {
    report_notice("Synchronizing session cache");
    foreach(session_buckets, mapping(string:mixed) session_bucket)
      foreach(indices(session_bucket), string id)
	if(session_persistence[id]>t) {
	  store_session(id, session_bucket[id], session_persistence[id]);
	  m_delete(session_persistence, id);
	}
  }
  report_notice("Session cache synchronized\n");
}

//! Removes the session data assiciate with @[id] from the
//! session cache and session database.
//!
//! @seealso
//!   set_session_data
void clear_session(string id) {
  m_delete(session_persistence, id);
  foreach(session_buckets, mapping bucket)
    m_delete(bucket, id);
  db("local")->query("DELETE FROM session_cache WHERE id=%s", id);
}

//! Returns the data associated with the session @[id].
//! Returns a zero type upon failure.
//!
//! @seealso
//!   set_session_data
mixed get_session_data(string id) {
  mixed data;
  foreach(session_buckets, mapping bucket)
    if(data=bucket[id]) {
      session_buckets[0][id] = data;
      return data;
    }
  data = db("local")->query("SELECT data FROM session_cache WHERE id=%s", id);
  if(sizeof([array]data) &&
     !catch(data=decode_value( ([array(mapping(string:string))]data)[0]->data )))
    return data;
  return UNDEFINED;
}

//! Assiciates the session @[id] to the @[data]. If no @[id] is provided
//! a unique id will be generated. The session id is returned from the
//! function. The minimum guaranteed storage time may be set with the
//! @[persistence] argument. Note that this is a time stamp, not a time out.
//! If @[store] is set, the @[data] will be stored in a database directly,
//! and not when the garbage collect tries to delete the data. This
//! will ensure that the data is kept safe in case the server restarts
//! before the next GC.
//!
//! @note
//!   The @[data] must not contain any object, programs or functions, or the
//!   storage in database will throw an error.
//!
//! @seealso
//!   get_session_data, clear_session
string set_session_data(mixed data, void|string id, void|int persistence,
			void|int(0..1) store) {
  if(!id) id = ([function(void:string)]get_core()->create_unique_id)();
  session_persistence[id] = persistence;
  session_buckets[0][id] = data;
  max_persistence = max(max_persistence, persistence);
  if(store && persistence) store_session(id, data, persistence);
  return id;
}

// Sets up the session database tables.
private void setup_tables() {
  db("local")->query("CREATE TABLE IF NOT EXISTS session_cache ("
		     "id CHAR(32) NOT NULL PRIMARY KEY, "
		     "persistence INT UNSIGNED NOT NULL DEFAULT 0, "
		     "data BLOB NOT NULL)");
  master()->resolv("DBManager.is_module_table")
    ( 0, "local", "session_cache", "Used by the session manager" );
}


// --- Cache initialization ----------

void init()
{
  // Initializes the session handler.
  db = (([function(string:function(string:object(Sql.Sql)))]master()->resolv)
	("DBManager.get"));
  setup_tables();

  // Init call outs
  get_core()->background_run(60, cache_clean);
  get_core()->background_run(SESSION_SHIFT_TIME, session_cache_handler);

  CACHE_WERR("Cache garb call outs installed.\n");
}

void create()
{
  caches = ([ ]);

  session_buckets = ({ ([]) }) * SESSION_BUCKETS;
  session_persistence = ([]);

  CACHE_WERR("Now online.\n");
}

void destroy() {
  session_cache_destruct();
  return;
}
