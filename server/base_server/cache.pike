// This file is part of Roxen WebServer.
// Copyright © 1996 - 2004, Roxen IS.
// $Id: cache.pike,v 1.92 2008/10/12 22:15:08 mast Exp $

// #pragma strict_types

#include <roxen.h>
#include <config.h>

// Base the cache retention time on the time it took to
// generate the entry.
/* #define TIME_BASED_CACHE */

#ifdef TIME_BASED_CACHE
// A cache entry is an array with six elements
#define ENTRY_SIZE 6
#else /* !TIME_BASED_CACHE */
// A cache entry is an array with four elements
#define ENTRY_SIZE 4
#endif /* TIME_BASED_CACHE */
// The elements are as follows:
// A timestamp when the entry was last used
#define TIMESTAMP 0
// The actual data
#define DATA 1
// A timeout telling when the data is no longer valid.
#define TIMEOUT 2
// The size of the entry, in bytes.
#define SIZE 3
#ifdef TIME_BASED_CACHE
// The approximate time in µs it took to generate the data for the entry.
#define HRTIME 4
// The number of hits for this entry.
#define HITS 5
#endif /* TIME_BASED_CACHE */

#undef CACHE_WERR
#ifdef CACHE_DEBUG
# define CACHE_WERR(X...) report_debug("CACHE: "+X);
#else
# define CACHE_WERR(X...)
#endif

#undef MORE_CACHE_WERR
#ifdef MORE_CACHE_DEBUG
# define MORE_CACHE_WERR(X...) report_debug("CACHE: "+X);
#else
# define MORE_CACHE_WERR(X...)
#endif

// The actual cache along with some statistics mappings.
protected mapping(string:mapping(string:array)) cache;
protected mapping(string:int) hits=([]), all=([]);

#ifdef TIME_BASED_CACHE
protected Thread.Local deltas = Thread.Local();
#endif /* TIME_BASED_CACHE */

#ifdef CACHE_DEBUG
protected array(int) memory_usage_summary()
{
  int count, bytes;
  foreach (_memory_usage(); string descr; int amount)
    if (has_prefix (descr, "num_")) count += amount;
    else if (has_suffix (descr, "_bytes")) bytes += amount;
  return ({count, bytes});
}
#endif

#ifdef DEBUG_COUNT_MEM
int count_memory (int|mapping opts, mixed what)
{
  if (intp (opts))
    opts = (["lookahead": opts,
	     "collect_stats": 1,
	     //"collect_direct_externals": 1,
	   ]);
  else
    opts += (["collect_stats": 1]);
  float t = gauge (Pike.count_memory (opts, what));
  if (!stringp (what))
    werror ("%s: size %d time %g int %d cyc %d ext %d vis %d revis %d "
	    "rnd %d wqa %d\n",
	    (arrayp (what) && sizeof (what) == 4 && objectp (what[1]) ?
	     sprintf ("%O", what[1]) : sprintf ("%t", what)),
	    opts->size, t, opts->internal, opts->cyclic, opts->external,
	    opts->visits, opts->revisits, opts->rounds, opts->work_queue_alloc);
#if 0
  werror ("externals: %O\n", opts->collect_direct_externals);
#endif
  return opts->size;
}
#else
#define count_memory Pike.count_memory
#endif

void flush_memory_cache (void|string in)
{
  CACHE_WERR ("flush_memory_cache(%O)\n", in);

  if (in) {
    m_delete (cache, in);
    m_delete (hits, in);
    m_delete (all, in);
  }

  else {
#ifdef CACHE_DEBUG
    //gc();
    [int before_count, int before_bytes] = memory_usage_summary();
#endif
    foreach (cache; string cache_class; mapping(string:array) subcache) {
#ifdef CACHE_DEBUG
      int num_entries_before= sizeof (subcache);
#endif
      m_delete (cache, cache_class);
      m_delete (hits, cache_class);
      m_delete (all, cache_class);
#ifdef CACHE_DEBUG
      //gc();
      [int after_count, int after_bytes] = memory_usage_summary();
      CACHE_WERR ("  Flushed %O that had %d entries: "
		  "Freed %d things and %d bytes\n",
		  cache_class, num_entries_before,
		  before_count - after_count, before_bytes - after_bytes);
      before_count = after_count;
      before_bytes = after_bytes;
#endif
    }
  }

  CACHE_WERR ("flush_memory_cache() done\n");
}

void cache_clear_deltas()
{
#ifdef TIME_BASED_CACHE
  deltas->set(([]));
#endif /* TIME_BASED_CACHE */
}

constant svalsize = 4*4;

// Expire a whole cache
void cache_expire(string in)
{
  CACHE_WERR("cache_expire(%O)\n", in);
  m_delete(cache, in);
}

// Lookup an entry in a cache
mixed cache_lookup(string in, mixed what)
{
  all[in]++;
  int t=time(1);
#ifdef TIME_BASED_CACHE
  mapping deltas = this_program::deltas->get() || ([]);
  if (deltas[in]) {
    deltas[in][what] = gethrtime();
  } else {
    deltas[in] = ([ what : gethrtime() ]);
  }
#endif /* TIME_BASED_CACHE */
  // Does the entry exist at all?
  if(array entry = (cache[in] && cache[in][what]) )
    // Is it time outed?
    if (entry[TIMEOUT] && entry[TIMEOUT] < t) {
      m_delete (cache[in], what);
      MORE_CACHE_WERR("cache_lookup(%O, %O)  ->  Timed out\n", in, what);
    }
    else {
      // Update the timestamp and hits counter and return the value.
      cache[in][what][TIMESTAMP]=t;
      MORE_CACHE_WERR("cache_lookup(%O, %O)  ->  Hit\n", in, what);
      hits[in]++;
#ifdef TIME_BASED_CACHE
      entry[HITS]++;
#endif /* TIME_BASED_CACHE */
      return entry[DATA];
    }
  else
    MORE_CACHE_WERR("cache_lookup(%O, %O)  ->  Miss\n", in, what);
  return ([])[0];
}

// Return all indices used by a given cache or indices of available caches
array(string) cache_indices(string|void in)
{
  if (in)
    return (cache[in] && indices(cache[in])) || ({ });
  else
    return indices(cache);
}

// Return some fancy cache statistics.
mapping(string:array(int)) status()
{
  mapping(string:array(int)) ret = ([ ]);
  foreach(indices(cache), string name) {
    //  We only show names up to the first ":" if present. This lets us
    //  group entries together in the status table.
    string show_name = (name / ":")[0];
    int size = count_memory (0, cache[name]);
    array(int) entry = ({ sizeof(cache[name]),
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

// Remove an entry from the cache. Removes the entire cache if no
// entry key is given.
void cache_remove(string in, mixed what)
{
  MORE_CACHE_WERR("cache_remove(%O, %O)\n", in, what);
  if(!what)
    m_delete(cache, in);
  else
    if(cache[in])
      m_delete(cache[in], what);
}

// Add an entry to a cache
mixed cache_set(string in, mixed what, mixed to, int|void tm)
{
  MORE_CACHE_WERR("cache_set(%O, %O, %O)\n", in, what, /* to */ _typeof(to));
  int t=time(1);
  if(!cache[in])
    cache[in]=([ ]);
  cache[in][what] = allocate(ENTRY_SIZE);
  cache[in][what][DATA] = to;
  if(tm) cache[in][what][TIMEOUT] = t + tm;
  cache[in][what][TIMESTAMP] = t;
#ifdef TIME_BASED_CACHE
  mapping deltas = this_program::deltas->get() || ([]);
  cache[in][what][HRTIME] = gethrtime() - (deltas[in] && deltas[in][what]);
  cache[in][what][HITS] = 1;
  CACHE_WERR("[%O] HRTIME: %d\n", in, cache[in][what][HRTIME]);
#endif /* TIME_BASED_CACHE */
  return to;
}

// Clean the cache.
void cache_clean()
{
  int gc_time=[int](([function(string:mixed)]roxenp()->query)("mem_cache_gc"));
  int now=time(1);
#ifdef CACHE_DEBUG
  [int mem_count, int mem_bytes] = memory_usage_summary();
  CACHE_WERR("cache_clean() [memory usage: %d things, %d bytes]\n",
	     mem_count, mem_bytes);
#endif

  foreach(cache; string cache_class_name; mapping(string:array) cache_class)
  {
#ifdef CACHE_DEBUG
    int num_entries_before = sizeof (cache_class);
#endif
    MORE_CACHE_WERR("  Class %O\n", cache_class_name);

    foreach(cache_class; string idx; array entry)
    {
#ifdef DEBUG
      if(!intp(entry[TIMESTAMP]))
	error("Illegal timestamp in cache ("+cache_class_name+":"+idx+")\n");
#endif
      if(entry[TIMEOUT] && entry[TIMEOUT] < now) {
	MORE_CACHE_WERR("    %O: Deleted (explicit timeout)\n", idx);
	m_delete(cache_class, idx);
      }
      else {
	if(!entry[SIZE]) {
 	  // Perform a size calculation.
#ifdef TIME_BASED_CACHE
	  if (entry[HRTIME] < 10*60*1000000) {	// 10 minutes.
	    // Valid HRTIME entry.
	    // Let an entry live for 5000 times longer than
	    // it takes to create it times the 2-logarithm of
	    // the number of hits.
	    // Minimum one second.
	    // 5000/1000000 = 1/200
	    // FIXME: Adjust the factor dynamically?
	    int t = [int](entry[HRTIME]*(entry[HITS]->size(2)))/200 + 1;
	    if ((entry[TIMESTAMP] + t) < now)
	    {
	      m_delete(cache_class, idx);
	      MORE_CACHE_WERR("    %O with lifetime %d seconds (%d hits): Deleted\n",
			      idx, t, entry[HITS]);
	    } else {
	      MORE_CACHE_WERR("    %O with lifetime %d seconds (%d hits): Ok\n",
			      idx, t, entry[HITS]);
	    }
	    continue;
	  } else {
#endif /* TIME_BASED_CACHE */
	    entry[SIZE] = (count_memory (0, idx) +
			   count_memory (0, entry)) / 100;
	    // The 100 above is an "arbitrary factor", whatever that
	    // means.. /mast
#ifdef TIME_BASED_CACHE
	  }
#endif /* TIME_BASED_CACHE */
	}
	if(entry[TIMESTAMP]+1 < now &&
	   entry[TIMESTAMP] + gc_time - entry[SIZE] < now)
	{
	  m_delete(cache_class, idx);
	  MORE_CACHE_WERR("    %O with perceived size %d bytes: Deleted\n",
			  idx, [int] entry[SIZE] * 100);
	}
	else
	  MORE_CACHE_WERR("    %O with perceived size %d bytes: Ok\n",
			  idx, [int] entry[SIZE] * 100);
      }
    }

    if(!sizeof(cache_class))
      m_delete(cache, cache_class_name);

#ifdef CACHE_DEBUG
    [int new_mem_count, int new_mem_bytes] = memory_usage_summary();
    CACHE_WERR("  Class %O: Cleaned up %d of %d entries "
	       "[freed %d things and %d bytes]\n",
	       cache_class_name,
	       num_entries_before - sizeof (cache_class),
	       num_entries_before,
	       mem_count - new_mem_count,
	       mem_bytes - new_mem_bytes);
    mem_count = new_mem_count;
    mem_bytes = new_mem_bytes;
#endif
  }

  CACHE_WERR("cache_clean() done\n");
  roxenp()->background_run (gc_time, cache_clean);
}


// --- Non-garbing "cache" -----------

private mapping(string:mapping(string:mixed)) nongc_cache;

//! Associates a @[value] to a @[key] in a cache identified with
//! the @[cache_id]. This cache does not garb, hence it should be
//! used for storing data where its size is well controled.
void nongarbing_cache_set(string cache_id, string key, mixed value) {
  if(nongc_cache[cache_id])
    nongc_cache[cache_id][key] = value;
  else
    nongc_cache[cache_id] = ([ key:value ]);
}

//! Returns the value associated to the @[key] in the cache
//! identified by @[cache_id] in the non-garbing cache.
mixed nongarbing_cache_lookup(string cache_id, string key) {
  return nongc_cache[cache_id]?nongc_cache[cache_id][key]:([])[0];
}

//! Remove a value from the non-garbing cache.
void nongarbing_cache_remove(string cache_id, string key) {
  if(nongc_cache[cache_id]) m_delete(nongc_cache[cache_id], key);
}

//! Flush a cache in the non-garbing cache.
void nongarbing_cache_flush(string cache_id) {
  m_delete(nongc_cache, cache_id);
}

mapping(string:array(int)) ngc_status() {
  mapping(string:array(int)) res = ([]);

  foreach(indices(nongc_cache), string cache) {
    int size = count_memory (0, nongc_cache[cache]);
    res[cache] = ({ sizeof(nongc_cache[cache]), size});
  }

  return res;
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
  db("local")->query("REPLACE INTO session_cache VALUES (%s," + t + ",%s)",
		     id, data);
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
  roxenp()->background_run(SESSION_SHIFT_TIME, session_cache_handler);
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
  return ([])[0];
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
  if(!id) id = ([function(void:string)]roxenp()->create_unique_id)();
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

//! Initializes the session handler.
void init_session_cache() {
  db = (([function(string:function(string:object(Sql.Sql)))]master()->resolv)
	("DBManager.cached_get"));
  setup_tables();
}

void init_call_outs()
{
  roxenp()->background_run(60, cache_clean);
  roxenp()->background_run(SESSION_SHIFT_TIME, session_cache_handler);

  CACHE_WERR("Cache garb call outs installed.\n");
}

void create()
{
  add_constant( "cache", this_object() );
  cache = ([ ]);

  nongc_cache = ([ ]);

  session_buckets = ({ ([]) }) * SESSION_BUCKETS;
  session_persistence = ([]);

  CACHE_WERR("Now online.\n");
}

void destroy() {
  session_cache_destruct();
  return;
}
