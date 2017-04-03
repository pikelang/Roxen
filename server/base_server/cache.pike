// This file is part of Roxen WebServer.
// Copyright © 1996 - 2009, Roxen IS.
// $Id$

// FIXME: Add argcache, imagecache & protcache

#include <roxen.h>
#include <config.h>

#ifdef MORE_CACHE_DEBUG
# define MORE_CACHE_WERR(X...) report_debug("CACHE: "+X)
# undef CACHE_DEBUG
# define CACHE_DEBUG
#else
# define MORE_CACHE_WERR(X...) 0
#endif

#ifdef CACHE_DEBUG
# define CACHE_WERR(X...) report_debug("CACHE: "+X)
#else
# define CACHE_WERR(X...) 0
#endif

int total_size_limit = 1024 * 1024;
//! Maximum cache size for all cache managers combined. Start out with
//! a bit of space before the setting is read.

constant rebalance_adaptivity = 30 * 60;
//! Number of seconds it should take to update the size balance
//! between the cache managers for a different workload.
//!
//! Note: If this changes then the help texts in
//! config_interface/actions/cachestatus.pike should be updated.

constant rebalance_interval = 10;
//! Seconds between @[update_cache_size_balance] calls.

constant rebalance_keep_factor =
  1.0 - 1.0 / (rebalance_adaptivity / rebalance_interval);
//! Every time @[update_cache_size_balance] is called, the size
//! assigned to each cache manager is allowed to shrink to no more
//! than its currently assigned size multiplied by this factor.
//!
//! @note
//! It's possible that cache managers are rebalanced a lot quicker
//! than this: If a manager overshoots in one iteration then all
//! caches are shrunk linearly in the next, and that is not limited by
//! this value. Remains to be seen whether that is a feature or a bug.

constant rebalance_min_size = 1024 * 1024;
//! Minimum size to give a cache manager.

protected constant cm_stats_avg_period = rebalance_adaptivity;
// Approximate time period for which the decaying average/sum stats in
// CacheManager apply.

void set_total_size_limit (int size)
//! Sets the total size limit available to all caches.
{
  total_size_limit = size;

  // Rebalance immediately after setting the total size limit. This is
  // important mostly at server startup since modules otherwise might
  // do cache-intensive processing before the cache manager size has
  // been raised from its minimum value, resulting in sub-optimal
  // performance or even halting cache-filler operations
  // (e.g. Sitebuilder's workarea prefetcher.)
  update_cache_size_balance();
}

//! The SNMP lookup root for the cache.
SNMP.SimpleMIB mib = SNMP.SimpleMIB(SNMP.RIS_OID_WEBSERVER + ({ 3 }),
				    ({}),({ UNDEFINED }));

//! Base class for cache entries.
class CacheEntry (mixed key, mixed data, string cache_name)
{
  // FIXME: Consider unifying this with CacheKey. But in that case we
  // need to ensure "interpreter lock" atomicity below.

  int size;
  //! The size of this cache entry, as measured by @[Pike.count_memory].

  //! Updates the size by calling @[Pike.count_memory], and returns
  //! the difference between the new and the old measurement.
  int update_size()
  {
    int old_size = size;
#ifdef DEBUG_COUNT_MEM
    mapping opts = (["lookahead": DEBUG_COUNT_MEM - 1,
                     "collect_stats": 1,
                     "collect_direct_externals": 1,
                     "block_strings": -1 ]);
    float t = gauge {
#else
        mapping opts = (["block_strings": -1]);
#endif

        if (function(int|mapping:int) cm_cb =
            objectp (data) && data->cache_count_memory)
          this::size = cm_cb (opts) + Pike.count_memory (-1, this, key);
        else
          this::size = Pike.count_memory (opts, this, key, data);

#ifdef DEBUG_COUNT_MEM
      };
    werror ("%O: la %d size %d time %g int %d cyc %d ext %d vis %d revis %d "
            "rnd %d wqa %d\n",
            new_entry, opts->lookahead, opts->size, t, opts->internal,
            opts->cyclic, opts->external, opts->visits, opts->revisits,
            opts->rounds, opts->work_queue_alloc);

#if 0
    if (opts->external) {
      opts->collect_direct_externals = 1;
      // Raise the lookahead to 1 to recurse the closest externals.
      if (opts->lookahead < 1) opts->lookahead = 1;

      if (function(int|mapping:int) cm_cb =
          objectp (data) && data->cache_count_memory)
        res = cm_cb (opts) + Pike.count_memory (-1, entry, key);
      else
        res = Pike.count_memory (opts, entry, key, data);

      array exts = opts->collect_direct_externals;
      werror ("Externals found using lookahead %d: %O\n",
              opts->lookahead, exts);
#if 0
      foreach (exts, mixed ext)
        if (objectp (ext) && ext->locate_my_ext_refs) {
          werror ("Refs to %O:\n", ext);
          _locate_references (ext);
        }
#endif
    }
#endif

#endif	// DEBUG_COUNT_MEM
#undef opts

#ifdef DEBUG_CACHE_SIZES
    new_entry->cmp_size = cmp_sizeof_cache_entry (cache_name, new_entry);
#endif

    return size - old_size;
  }

#ifdef DEBUG_CACHE_SIZES
  int cmp_size;
  // Size without counting strings. Used to compare the size between
  // cache_set and cache_clean. Strings are excluded since they might
  // get or lose unrelated refs in the time between which would make
  // the comparison unreliable. This might make us miss significant
  // strings though, but it's hard to get around it.
#endif

  int timeout;
  //! Unix time when the entry times out, or zero if there's no
  //! timeout.

  //! @decl int|float cost;
  //!
  //! The creation cost for the entry, according to the metric used by
  //! the cache manager (provided it implements cost).

  protected string format_key()
  {
    if (stringp (key)) {
      if (sizeof (key) > 40)
	return sprintf ("%q...", key[..39 - sizeof ("...")]);
      else
	return sprintf ("%q", key);
    }
    else if (intp (key) || floatp (key) || objectp (key))
      return sprintf ("%O", key);
    else
      return sprintf ("%t", key);
  }

  protected string _sprintf (int flag)
  {
    return flag == 'O' && sprintf ("CacheEntry(%s, %db)", format_key(), size);
  }
}

class CacheStats
//! Holds statistics for each named cache.
{
  int count;
  //! The number of entries in the cache.

  int size;
  //! The sum of @[CacheEntry.size] for all cache entries in the cache.

  int hits, misses;
  //! Plain counts of cache hits and misses since the creation of the
  //! cache.

  int|float cost_hits, cost_misses;
  //! Hit and miss count according to the cache manager cost metric
  //! since the creation of the cache. Note that @[cost_misses] is
  //! determined when a new entry is added - it will not include when
  //! no new entry was created after a cache miss.

#ifdef CACHE_BYTE_HR_STATS
  int byte_hits, byte_misses;
  //! Byte hit and miss count since the creation of the cache. Note
  //! that @[byte_misses] is determined when a new entry is added - it
  //! will not include when no new entry was created after a cache
  //! miss.
#endif

  protected string _sprintf (int flag)
  {
    return flag == 'O' && sprintf ("CacheStats(%d, %dk)", count, size / 1024);
  }
}

class CacheManagerPrefs(int(0..1) extend_entries // Set if a
                                                 // cache_name may get
                                                 // existing entries
                                                 // extended even
                                                 // after cache hit.
                        ) {}

class CacheManager
//! A cache manager handles one or more caches, applying the same
//! eviction policy and the same size limit on all of them. I.e. it's
//! practically one cache, and the named caches inside only act as
//! separate name spaces.
{
  //! A unique name to identify the manager. It is also used as
  //! display name.
  constant name = "-";

  //! @decl constant string doc;
  //!
  //! A description of the manager and its eviction policy in html.

  constant has_cost = 0;
  //! Nonzero if this cache manager implements a cost metric.

  int total_size_limit = global::total_size_limit;
  //! Maximum allowed size including the cache manager overhead.

  int size;
  //! The sum of @[CacheStats.size] for all named caches.

  int size_limit = global::total_size_limit;
  //! Maximum allowed size for cache entries - @[size] should never
  //! greater than this. This is a cached value calculated from
  //! @[total_size_limit] on regular intervals.

  int entry_add_count;
  //! Number of entries added since this cache manager was created.

  int byte_add_count;
  //! Number of bytes added since this cache manager was created.

  mapping(string:mapping(mixed:CacheEntry)) lookup = ([]);
  //! Lookup mapping on the form @expr{(["cache_name": ([key: data])])@}.
  //!
  //! For functions in this class, a cache submapping does not exist
  //! only due to race, so the cache should just be ignored.

  mapping(string:CacheStats) stats = ([]);
  //! Statistics for the named caches managed by this object.
  //!
  //! For functions in this class, a @[CacheStats] object does not
  //! exist only due to race, so the cache should just be ignored.

  mapping(string:CacheManagerPrefs) prefs = ([]);
  //! Preferences for the named caches managed by this object.
  //!

  int cached_overhead_add_count;
  //! Snapshot of @[entry_add_count] at the point the manager overhead
  //! was computed.

  int cached_overhead;
  //! Cached manager overhead. Recomputed in manager_size_overhead().

  //! @decl program CacheEntry;
  //!
  //! The manager-specific class to use to create @[CacheEntry] objects.

  void clear_cache_context() {}
  //! Called to clear any thread-local state that the manager keeps to
  //! track execution times etc. This is called before a thread starts
  //! with a new request or other kind of job.

  void got_miss (string cache_name, mixed key, mapping cache_context);
  //! Called when @[cache_lookup] records a cache miss.

  protected void account_miss (string cache_name)
  {
    recent_misses++;
    if (CacheStats cs = stats[cache_name])
      cs->misses++;
  }

  void got_hit (string cache_name, CacheEntry entry, mapping cache_context);
  //! Called when @[cache_lookup] records a cache hit.

  protected void account_hit (string cache_name, CacheEntry entry)
  {
    recent_hits++;
    recent_cost_hits += entry->cost;
    if (CacheStats cs = stats[cache_name]) {
      cs->hits++;
      cs->cost_hits += entry->cost;
#ifdef CACHE_BYTE_HR_STATS
      cs->byte_hits += entry->size;
#endif
    }
  }

  int add_entry (string cache_name, CacheEntry entry,
		 int old_entry, mapping cache_context);
  //! Called to add an entry to the cache. Should also evict entries
  //! as necessary to keep @expr{@[size] <= @[size_limit]@}.
  //!
  //! If @[old_entry] is set then the entry hasn't been created from
  //! scratch, e.g. there is no prior @[got_miss] call. Returns 1 if
  //! the entry got added to the cache. Returns 0 if the function
  //! chose to evict it immediately or if the cache has disappeared.

  private void account_remove_entry (string cache_name, CacheEntry entry)
  {
    if (CacheStats cs = stats[cache_name]) {
      cs->count--;
      cs->size -= entry->size;
      ASSERT_IF_DEBUG (cs->size /*%O*/ >= 0, cs->size);
      ASSERT_IF_DEBUG (cs->count /*%O*/ >= 0, cs->count);
    }
    size -= entry->size;
    ASSERT_IF_DEBUG (size /*%O*/ >= 0, size);
  }

  protected int low_add_entry (string cache_name, CacheEntry entry)
  {
    ASSERT_IF_DEBUG (entry->size /*%O*/, entry->size);

    // Assume that the addition of the new entry came about due to a
    // cache miss.
    recent_cost_misses += entry->cost;

    if (CacheStats cs = stats[cache_name]) {
      cs->cost_misses += entry->cost;
#ifdef CACHE_BYTE_HR_STATS
      cs->byte_misses += entry->size;
#endif

      if (mapping(mixed:CacheEntry) lm = lookup[cache_name]) {
        CacheEntry old_entry;
	// vvv Relying on the interpreter lock from here.
        while (old_entry = lm[entry->key]) {
          recent_added_bytes -= old_entry->size;
          remove_entry (cache_name, old_entry);
        }
        lm[entry->key] = entry;
        // ^^^ Relying on the interpreter lock to here.

	cs->count++;
	cs->size += entry->size;
	size += entry->size;
	recent_added_bytes += entry->size;
	byte_add_count += entry->size;

	if (!(++entry_add_count & 0x3fff)) // = 16383
	  update_size_limit();
      }

      return 1;
    }

    return 0;
  }

  int remove_entry (string cache_name, CacheEntry entry);
  //! Called to delete an entry from the cache. Should use
  //! @[low_remove_entry] to do the atomic removal. Must ensure the
  //! entry is removed from any extra data structures, regardless
  //! whether it's already gone from the @[lookup] mapping or not.
  //! Returns the return value from @[low_remove_entry].

  protected int low_remove_entry (string cache_name, CacheEntry entry)
  //! Returns 1 if the entry got removed from the cache, or 0 if it
  //! wasn't found in the cache or if the cache has disappeared.
  {
    if (mapping(mixed:CacheEntry) lm = lookup[cache_name])
      if (lm[entry->key] == entry) {
	// Relying on the interpreter here.
	m_delete (lm, entry->key);
	account_remove_entry (cache_name, entry);
	return 1;
      }
    return 0;
  }

  void evict (int max_size);
  //! Called to evict entries until @expr{@[size] <= @[max_size]@}.

  void after_gc() {}
  //! Called from the periodic GC, after stale and invalid entries
  //! have been removed from the cache.

  int manager_size_overhead()
  //! Returns the size consumed by the manager itself, excluding the
  //! cache entries.
  {
    // Return the cached overhead as long as the number of added
    // entries since the last computation is less than 10% of the
    // number of entries in the cache. The cache is a workaround for
    // the horrific performance of Pike.count_memory (-1, m) on large
    // mappings (addressed in Pike 8.1).
    int num_entries;
    foreach (stats;; CacheStats stats) {
      if (stats) num_entries += stats->count;
    }

    if ((entry_add_count - cached_overhead_add_count) <
	(num_entries / 10))
      return cached_overhead;

    int res = (Pike.count_memory (-1, this, lookup) +
	       Pike.count_memory (0, stats));
    foreach (lookup;; mapping(mixed:CacheEntry) lm)
      res += Pike.count_memory (-1, lm);

    cached_overhead_add_count = entry_add_count;
    cached_overhead = res;
    return res;
  }

  float add_rate = 0.0;
  //! The number of newly added bytes per second, calculated as a
  //! decaying average over the last @[cm_stats_avg_period] seconds.
  //! Note that the returned value could become negative if entries
  //! are replaced with smaller ones.

  float hits = 0.0, misses = 0.0;
  //! Decaying sums over the hits and misses during approximately the
  //! last @[cm_stats_avg_period] seconds.

  float cost_hits = 0.0, cost_misses = 0.0;
  //! Decaying sums over the cost weighted hits and misses during
  //! approximately the last @[cm_stats_avg_period] seconds. Only
  //! applicable if @[has_cost] is set.

  protected int recent_added_bytes;
  protected int recent_hits, recent_misses;
  protected int|float recent_cost_hits, recent_cost_misses;

  void update_decaying_stats (int start_time, int last_update, int now)
  // Should only be called at regular intervals from
  // update_cache_size_balance.
  {
    // Skip updating if we did it recently (avoid division by zero below.)
    if (now == last_update)
      return;

    float last_period = (float) (now - last_update);
    float tot_period = (float) (now - start_time);
    int startup = tot_period < cm_stats_avg_period;
    if (!startup) tot_period = (float) cm_stats_avg_period;

    float our_weight = min (tot_period != 0.0 && last_period / tot_period, 1.0);
    float old_weight = 1.0 - our_weight;

    if (startup) {
      hits += (float) recent_hits;
      misses += (float) recent_misses;
      cost_hits += (float) recent_cost_hits;
      cost_misses += (float) recent_cost_misses;
    }

    else {
      hits = old_weight * hits + (float) recent_hits;
      misses = old_weight * misses + (float) recent_misses;
      cost_hits = old_weight * cost_hits + (float) recent_cost_hits;
      cost_misses = old_weight * cost_misses + (float) recent_cost_misses;
    }

    add_rate = (old_weight * add_rate +
		our_weight * (recent_added_bytes / last_period));

    recent_added_bytes = 0;
    recent_hits = recent_misses = 0;
    recent_cost_hits = recent_cost_misses = 0;
  }

  void update_size_limit()
  {
    MORE_CACHE_WERR ("%O: update_size_limit\n", this);
    int mgr_oh = manager_size_overhead();
    size_limit = max (0, total_size_limit - mgr_oh);
    if (size > size_limit) {
      CACHE_WERR ("%O: Evicting %db "
		  "(entry size limit %db, manager overhead %db, total %db)\n",
		  this, size - size_limit,
		  size_limit, mgr_oh, total_size_limit);
      evict (size_limit);
    }
  }

  int free_space()
  //! Returns the amount of unused space left. Might be negative in
  //! some narrow time windows when the cache is over its limit and
  //! @[evict] hasn't yet catched up.
  {
    return size_limit - size;
  }

  string format_cost (int|float cost) {return "-";}
  //! Function to format a cost measurement for display in the status
  //! page.

  protected string _sprintf (int flag)
  {
    return flag == 'O' &&
      sprintf ("CacheManager(%s: %dk/%dk)",
	       name, size / 1024, size_limit / 1024);
  }

  protected void create()
  {
    mib->merge(CacheManagerMIB(this));
  }
}

#if 0
class CM_Random
{
  inherit CacheManager;

  constant name = "Random";
  constant doc = #"\
This is a very simple cache manager that just evicts entries from the
cache at random. The only upside with it is that the cache management
overhead is minimal.";

  // Workaround since "constant CacheEntry = global::CacheEntry;"
  // currently causes segfault in 7.8.
  constant CacheEntry = global::CacheEntry;

  void got_miss (string cache_name, mixed key, mapping cache_context)
  {
    account_miss (cache_name);
  }

  void got_hit (string cache_name, CacheEntry entry, mapping cache_context)
  {
    account_hit (cache_name, entry);
  }

  int add_entry (string cache_name, CacheEntry entry,
		 int old_entry, mapping cache_context)
  {
    entry->cache_name = cache_name;
    int res = low_add_entry (cache_name, entry);
    if (size > size_limit) evict (size_limit);
    return res;
  }

  int remove_entry (string cache_name, CacheEntry entry)
  {
    return low_remove_entry (cache_name, entry);
  }

  void evict (int max_size)
  {
    while (size > max_size) {
      if (!sizeof (lookup)) break;
      // Relying on the interpreter lock here.
      string cache_name = random (lookup)[0];

      if (mapping(mixed:CacheEntry) lm = lookup[cache_name]) {
	if (sizeof (lm)) {
	  // Relying on the interpreter lock here.
	  CacheEntry entry = random (lm)[1];
	  MORE_CACHE_WERR ("evict: Size %db > %db - evicting %O / %O.\n",
			   size, max_size, cache_name, entry);
	  low_remove_entry (cache_name, entry);
	}
	else
	  m_delete (lookup, cache_name);
      }
    }
  }
}

protected CM_Random cm_random = CM_Random();
#endif

class CM_GreedyDual
//! Base class for cache managers that works with some variant of the
//! GreedyDual algorithm (see e.g. Cao and Irani, "Cost-Aware WWW
//! Proxy Caching Algorithms" in "Proceedings of the 1997 USENIX
//! Symposium on Internet Technology and Systems"):
//!
//! A priority queue is maintained, which contains all entries ordered
//! according to a priority value. The entry with the lowest priority
//! is always chosen for eviction. When a new entry p is added, and
//! each time it is hit afterwards, the priority is set to v(p) + L,
//! where v(p) is p's value according to some algorithm-specific
//! definition, and L is the lowest priority value in the cache. This
//! means that the priority values constantly increases, so that old
//! entries without hits eventually gets evicted regardless of their
//! initial v(p).
{
  inherit CacheManager;

  //! Allow cache to grow 10% above @[size_limit] before evicting
  //! entries synchronously in @[add_entry].
  constant max_overshoot_factor = 1.1;

  //! Mutex protecting @[priority_queue].
  Thread.Mutex priority_mux = Thread.Mutex();

  //! A heap of all [CacheEntry]s in priority order sorted by @[CacheEntry.`<].
  ADT.Heap priority_queue = ADT.Heap();

  //! Queue to hold entries that need a size update (asynchronous
  //! count_memory).
  Thread.Queue update_size_queue = Thread.Queue();

  mapping(CacheEntry:int(1..1)) pending_pval_updates = ([]);

  //! Wrapper so that we can get back to @[CacheEntry] from
  //! @[ADT.Heap.Element] easily.
  protected class HeapElement
  {
    inherit ADT.Heap.Element;

    //! Return the @[CacheEntry] that contains this @[HeapElement].
    object(CacheEntry) cache_entry() { return [object(CacheEntry)](mixed)this; }
  }

  class CacheEntry
  //!
  {
    private local inherit HeapElement;

    inherit global::CacheEntry;

    int|float value;
    //! The value of the entry, i.e. v(p) in the class description.

    //! @decl int|float pval;
    //! The priority value for the entry, effecting its position in
    //! @[priority_queue].
    //!
    //! If the element is a member of @[priority_queue] it will
    //! automatically adjust its position when this value is changed.

    int|float `pval()
    {
      return HeapElement::value;
    }
    void `pval=(int|float val)
    {
      Element::value = val;
      if (HeapElement::pos != -1) {
	//  NB: We may get called in a context where the mutex
	//      already has been taken.
	Thread.MutexKey key = priority_mux->lock(2);
	priority_queue->adjust(HeapElement::this);
      }
    }

    //! Return the @[HeapElement] corresponding to this @[CacheEntry].
    HeapElement element() { return HeapElement::this; }

    string cache_name;
    //! Need the cache name to find the entry, since @[priority_queue]
    //! is global.

    protected string _sprintf (int flag)
    {
      return flag == 'O' &&
	sprintf ("CM_GreedyDual.CacheEntry(%O: %s, %db, %O)",
		 pval, format_key(), size, value);
    }
  }

  protected int max_used_pval;
  // Used to detect when the entry pval's get too big to warrant a
  // reset.
  //
  // For integers, this is the maximum used pval and we reset at the
  // next gc when it gets over Int.NATIVE_MAX/2 (to have some spare
  // room for the gc delay).
  //
  // For floats, we reset whenever L is so big that less than 8
  // significant bits remains when v(p) is added to it. In that case
  // max_used_pval only works as a flag, and we set it to
  // Int.NATIVE_MAX when that state is reached.

  // call_out handle used by schedule_update_weights.
  protected mixed update_weights_handle;

  protected void schedule_update_weights()
  {
    if (!update_weights_handle) {
      // Weird indexing: the roxen constant is not registered when
      // this file is compiled...
      update_weights_handle =
        all_constants()->roxen->background_run (0.001, update_weights);
    }
  }

  protected void update_weights()
  {
    update_weights_handle = 0;

    // Try to limit run time to 50 ms at a time in order to avoid
    // impacting requests too much. If we're interrupted due to
    // timeout we'll reschedule ourselves as a background job. In a
    // heavily loaded server this might delay size/pval updates for a
    // while, but the main focus should be handling requests rather
    // than fiddling with size estimations and heap rebalancing. We'll
    // assume updates won't be deferred for so long that eviction
    // selection will be severely impacted.
    constant max_run_time = 50000;
    int start = gethrtime();
    int reschedule;

    // Protect against race when rebalancing on setting entry->pval.
    Thread.MutexKey key = priority_mux->lock();

    foreach (pending_pval_updates; CacheEntry entry;) {
      // NB: The priority queue is automatically adjusted on
      //     change of pval.
      entry->pval = calc_pval (entry);

      m_delete (pending_pval_updates, entry);

      if (gethrtime() - start > max_run_time / 2) {
        // Save some time for the loop below.
        reschedule = 1;
        break;
      }
    }

    while (CacheEntry entry = update_size_queue->try_read()) {
      string cache_name = entry->cache_name;
      // Check if entry has been evicted already.
      if (mapping(string:CacheEntry) lm = lookup[cache_name]) {
        if (lm[entry->key] == entry) {
          int size_diff = entry->update_size();
          size += size_diff;

          if (CacheStats cs = stats[cache_name]) {
            cs->size += size_diff;
            recent_added_bytes += size_diff;
            byte_add_count += size_diff;
          }
        }

        // NB: The priority queue is automatically adjusted on
        //     change of pval.
        entry->pval = calc_pval (entry);
      }

      if (gethrtime() - start > max_run_time) {
        reschedule = 1;
        break;
      }
    }

    key = 0;

    if (size > size_limit) {
      evict (size_limit);
    }

    if (reschedule) {
      schedule_update_weights();
    }
  }

#ifdef CACHE_DEBUG
  protected void debug_check_priority_queue()
  // Assumes no concurrent access - run inside _disable_threads.
  {
    werror ("Checking priority_queue with %d entries.\n",
	    sizeof(priority_queue));
    if (priority_queue->verify_heap) {
      Thread.MutexKey key = priority_mux->lock();
      priority_queue->verify_heap();
    }
  }
#endif

  int|float calc_value (string cache_name, CacheEntry entry,
			int old_entry, mapping cache_context);
  //! Called to calculate the value for @[entry], which gets assigned
  //! to the @expr{value@} variable. Arguments are the same as to
  //! @[add_entry].

  void got_miss (string cache_name, mixed key, mapping cache_context)
  {
    account_miss (cache_name);
  }

  local protected int|float calc_pval (CacheEntry entry)
  {
    int|float pval;
    if (HeapElement lowest = priority_queue->low_peek()) {
      int|float l = lowest->value, v = entry->value;
      pval = l + v;

      if (floatp (v)) {
	if (v != 0.0 && v < l * (Float.EPSILON * 0x10)) {
#ifdef DEBUG
	  if (max_used_pval != Int.NATIVE_MAX)
	    werror ("%O: Ran out of significant digits for cache entry %O - "
		    "got min priority %O and entry value %O.\n",
		    this, entry, l, v);
#endif
	  // Force a reset of the pvals in the next gc.
	  max_used_pval = Int.NATIVE_MAX;
	}
      }
      else if (pval > max_used_pval)
	max_used_pval = pval;
    }
    else
      // Assume entry->value isn't greater than Int.NATIVE_MAX/2 right away.
      pval = entry->value;
    return pval;
  }

  void got_hit (string cache_name, CacheEntry entry, mapping cache_context)
  {
    account_hit (cache_name, entry);
    // Even though heap rebalancing is relatively cheap (at least
    // compared to the old multiset strategy), we'll defer updates to
    // a background job (because of how frequent cache hits are). This
    // also helps consolidation.
    pending_pval_updates[entry] = 1;
    schedule_update_weights();
  }

  int add_entry (string cache_name, CacheEntry entry,
		 int old_entry, mapping cache_context)
  {
    int need_size_update;
    entry->cache_name = cache_name;
    // count_memory may account for significant amounts of CPU time on
    // frequent cache misses. To avoid impacting requests too much
    // we'll assign a mean value here and defer actual memory counting
    // to a background job. During load spikes that should help
    // amortize the cost of count_memory over a longer period of time.
    if (CacheStats cs = stats[cache_name]) {
      if (cs->count) {
        entry->size = cs->size / cs->count;
        need_size_update = 1;
      } else {
        // No entry present from before -- update synchronously.
        entry->update_size();
      }
    }

    entry->cache_name = cache_name;
    int|float v = entry->value =
      calc_value (cache_name, entry, old_entry, cache_context);

    if (!low_add_entry (cache_name, entry)) return 0;

    Thread.MutexKey key = priority_mux->lock();
    entry->pval = calc_pval (entry);
    priority_queue->push(entry->element());
    key = 0;

    if (need_size_update) {
      update_size_queue->write (entry);
      schedule_update_weights();
    }

    // Evictions will normally take place in the background job as
    // well, but we'll make sure we don't overshoot the size limit by
    // too much.
    int hard_size_limit = (int)(size_limit * max_overshoot_factor);
    if (size > hard_size_limit)
      evict (hard_size_limit);

    return 1;
  }

  int remove_entry (string cache_name, CacheEntry entry)
  {
    Thread.MutexKey key = priority_mux->lock();
    priority_queue->remove(entry->element());
    key = 0;
    return low_remove_entry (cache_name, entry);
  }

  void evict (int max_size)
  {
    Thread.MutexKey key = priority_mux->lock();
    while ((size > max_size) && sizeof(priority_queue)) {
      // NB: Use low_peek() + remove() since low_pop() doesn't exist.
      HeapElement element = priority_queue->low_peek();
      if (!element) break;
      priority_queue->remove(element);

      CacheEntry entry = element->cache_entry();

      MORE_CACHE_WERR ("evict: Size %db > %db - evicting %O / %O.\n",
		       size, max_size, entry->cache_name, entry);

      low_remove_entry (entry->cache_name, entry);
    }
  }

  int manager_size_overhead()
  {
    return Pike.count_memory (-1, priority_queue) + ::manager_size_overhead();
  }

  void after_gc()
  {
    if (max_used_pval > Int.NATIVE_MAX / 2) {
      int|float pval_base;
      if (HeapElement lowest = priority_queue->low_peek())
	pval_base = lowest->value;
      else
	return;

      // To cope with concurrent updates, we replace the lookup
      // mapping and start adding back the entries from the old one.
      // Need _disable_threads to make the resets of the CacheStats
      // fields atomic.
      Thread.MutexKey key = priority_mux->lock();
      object threads_disabled = _disable_threads();
      mapping(string:mapping(mixed:CacheEntry)) old_lookup = lookup;
      lookup = ([]);
      foreach (old_lookup; string cache_name;) {
	lookup[cache_name] = ([]);
	if (CacheStats cs = stats[cache_name]) {
	  cs->count = 0;
	  cs->size = 0;
	}
      }
      priority_queue = ADT.Heap();
      size = 0;
      max_used_pval = 0;
      threads_disabled = 0;

      int|float max_pval;

      foreach (old_lookup; string cache_name; mapping(mixed:CacheEntry) old_lm)
	if (CacheStats cs = stats[cache_name])
	  if (mapping(mixed:CacheEntry) new_lm = lookup[cache_name])
	    foreach (old_lm; mixed key; CacheEntry entry) {
	      entry->element()->pos = -1;
	      int|float pval = entry->pval -= pval_base;
	      if (!new_lm[key]) {
		// Relying on the interpreter lock here.
		new_lm[key] = entry;

		priority_queue->push(entry->element());
		if (pval > max_pval) max_pval = pval;

		cs->count++;
		cs->size += entry->size;
		size += entry->size;
	      }
	    }

      key = 0;

#ifdef CACHE_DEBUG
      debug_check_priority_queue();
#endif

      if (intp (max_pval))
	max_used_pval = max_pval;

      CACHE_WERR ("%O: Rebased priority values - "
		  "old base was %O, new range is 0..%O.\n",
		  this, pval_base, max_pval);

      if (Configuration admin_config = roxenp()->get_admin_configuration())
	// Log an event, in case we suspect this starts to happen a lot.
	admin_config->log_event ("roxen", "ram-cache-rebase", this->name, ([
				   "old-pval-base": pval_base,
				   "new-max-pval": max_pval,
				 ]));
    }
  }
}

class CM_GDS_1
{
  inherit CM_GreedyDual;

  constant name = "GDS(1)";
  constant doc = #"\
This cache manager implements <a
href='http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.30.7285'>GreedyDual-Size</a>
with the cost of each entry fixed at 1, which makes it optimize the
cache hit ratio.";

  float calc_value (string cache_name, CacheEntry entry,
		    int old_entry, mapping cache_context)
  {
    ASSERT_IF_DEBUG (entry->size /*%O*/ > 10, entry->size);
    return 1.0 / entry->size;
  }
}

protected CM_GDS_1 cm_gds_1 = CM_GDS_1();

class CM_GDS_Time
//! Like @[CM_GDS_1] but adds support for calculating entry cost based
//! on passed time.
{
  inherit CM_GreedyDual;

  constant has_cost = 1;

  class CacheEntry
  {
    inherit CM_GreedyDual::CacheEntry;
    int|float cost;

    protected string _sprintf (int flag)
    {
      return flag == 'O' &&
	sprintf ("CM_GDS_Time.CacheEntry(%O: %s, %db, %O, %O)",
		 pval, format_key(), size, value, cost);
    }
  }

  protected Thread.Local cache_contexts = Thread.Local();
  // A thread local mapping to store the timestamp from got_miss so it
  // can be read from the (presumably) following add_entry.
  //
  // In an entry with index 0 in the mapping, the time spent creating
  // cache entries is accumulated. It is used to deduct the time for
  // creating entries in subcaches.

  void clear_cache_context()
  {
    cache_contexts->set (([]));
  }

  protected int gettime_func();
  //! Returns the current time for cost calculation. (@[format_cost]
  //! assumes this is in microseconds.)

  protected void save_start_hrtime (string cache_name, mixed key,
				    mapping cache_context)
  {
    if (mapping all_ctx = cache_context || cache_contexts->get()) {
      int start = gettime_func() - all_ctx[0];

      if (mapping(mixed:int) ctx = all_ctx[cache_name]) {
#if 0
	if (!zero_type (ctx[key]))
	  // This warning is useful since strictly speaking we don't
	  // know which cache_lookup calls to use as start for the
	  // time measurement, so the time cost might be bogus. If it
	  // isn't the last one then you should probably replace some
	  // calls with cache_peek.
	  werror ("Warning: Detected repeated missed lookup calls.\n%s\n",
		  describe_backtrace (backtrace()));
#endif
	ctx[key] = start;
      }
      else
	all_ctx[cache_name] = ([key: start]);
    }

    else {
#ifdef DEBUG
      werror ("Warning: Got call from %O without cache context mapping.\n%s\n",
	      Thread.this_thread(), describe_backtrace (backtrace()));
#endif
    }
  }

  void got_miss (string cache_name, mixed key, mapping cache_context)
  {
    ::got_miss (cache_name, key, cache_context);
    save_start_hrtime (cache_name, key, cache_context);
  }

  void got_hit (string cache_name, CacheEntry entry, mapping cache_context)
  {
    ::got_hit(cache_name, entry, cache_context);
    if (CacheManagerPrefs prefs = prefs[cache_name]) {
      if (prefs->extend_entries) {
        // Save start time for caches that may want to extend existing
        // entries.
        save_start_hrtime (cache_name, entry->key, cache_context);
      }
    }
  }

  protected int entry_create_hrtime (string cache_name, mixed key,
				     mapping cache_context)
  {
    if (mapping all_ctx = cache_context || cache_contexts->get())
      if (mapping(mixed:int) ctx = all_ctx[cache_name]) {
	int start = m_delete (ctx, key);
	if (!zero_type (start)) {
	  int duration = (gettime_func() - all_ctx[0]) - start;
#if 0
	  // This assertion is disabled for now, since it doesn't work
	  // correctly when entry creations are interleaved instead of
	  // properly nested.
	  //
	  // However, handling that would mean more overhead. Just to
	  // detect interleaving we need to store the real timestamp
	  // in save_start_hrtime, in addition to the one with
	  // all_ctx[0] subtracted. And to evenly distribute the
	  // overlapping time between the interleaved entries, we'd
	  // have to track them and update their creation costs
	  // afterwards. If all that work is concentrated to this
	  // function (to keep save_start_hrtime as lean as possible
	  // since it's called much more often), it'd be an O(n^2)
	  // process.
	  //
	  // Also note that this assertion might trig if gettime_func
	  // isn't monotonic (c.f. FIXME in CM_GDS_RealTime.gettime_func).
	  ASSERT_IF_DEBUG (duration /*%O*/ >= 0 /* start: %O, all_ctx: %O */,
			   duration, start, all_ctx);
#endif
	  if (duration < 0)
	    // Can get negative duration when entry creation is
	    // interleaved. Consider this case (t_acc is all_ctx[0]):
	    //
	    //                  0                            t5
	    // Create entry A:  |----------------------------|
	    //                      t1               t3
	    // Create entry B:      |----------------|
	    //           t_acc == 0 ^         t2         t4
	    // Create entry C:                |----------|
	    //                     t_acc == 0 ^          ^ t_acc == t3
	    //
	    // When we get here for entry C, the accumulated time is
	    // t3, which could be larger than t4 - t2, thereby causing
	    // negative duration. Setting the duration to 0 here not
	    // only affects this entry; it also gives too much time
	    // (t4 - t3) to the entry A which encompasses both
	    // interleaved entries. The error stops there, though.
	    duration = 0;
	  all_ctx[0] += duration;
	  return duration;
	}
      }
#ifdef DEBUG
    // Note that this also happens if the caller calls cache_set()
    // several times to add the same entry. That should be avoided
    // (see the docs for cache_set).
    werror ("Warning: No preceding lookup for this key - "
	    "cannot determine entry creation time.\n%s\n",
	    describe_backtrace (backtrace()));
#endif
    return 0;
  }

  protected mapping(string:array(float|int)) mean_costs = ([]);
  // Stores the mean cost for all entries in each cache. The values
  // are on the form ({mean, count}), where count is the number of
  // samples that have contributed to the mean. These are not real
  // mean values since we (normally) don't keep track of the cost of
  // each entry. Instead it's a decaying average, where count is
  // capped at 1000.
  //
  // FIXME: Nowadays we actually do keep track of the cost for each
  // entry.

  float calc_value (string cache_name, CacheEntry entry,
		    int old_entry, mapping cache_context)
  {
    if (int hrtime = !old_entry &&
	entry_create_hrtime (cache_name, entry->key, cache_context)) {
      float cost = entry->cost = (float) hrtime;

      if (array(float|int) mean_entry = mean_costs[cache_name]) {
	[float mean_cost, int mean_count] = mean_entry;
	mean_entry[0] = (mean_count * mean_cost + cost) / (mean_count + 1);
	if (mean_count < 1000) mean_entry[1] = mean_count + 1;
      }
      else
	mean_costs[cache_name] = ({cost, 1});

      return cost / entry->size;
    }

    // Awkward situation: We don't have any cost for this entry. Just
    // use the mean cost of all entries in the cache, so it at least
    // isn't way off in either direction.
    if (array(float|int) mean_entry = mean_costs[cache_name])
      return mean_entry[0] / entry->size;
    else
      return 0.0;		// Here goes nothing.. :P
  }

  void evict (int max_size)
  {
    ::evict (max_size);
    if (!max_size) mean_costs = ([]);
  }

  string format_cost (float cost)
  {
    return Roxen.format_hrtime ((int) cost);
  }
}

class CM_GDS_CPUTime
{
  inherit CM_GDS_Time;

  constant name = "GDS(cpu time)";
  string doc = #"\
This cache manager implements <a
href='http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.30.7285'>GreedyDual-Size</a>
with the cost of each entry determined by the CPU time it took to
create it. The CPU time implementation is " +
    Roxen.html_encode_string (System.CPU_TIME_IMPLEMENTATION) +
    " which is " +
    (System.CPU_TIME_IS_THREAD_LOCAL ? "thread local" : "not thread local") +
    " and has a resolution of " +
    (System.CPU_TIME_RESOLUTION / 1e6) + " ms.";

  protected int gettime_func()
  {
    return gethrvtime();
  }
}

protected CM_GDS_CPUTime cm_gds_cputime = CM_GDS_CPUTime();

class CM_GDS_RealTime
{
  inherit CM_GDS_Time;

  constant name = "GDS(real time)";
  string doc = #"\
This cache manager implements <a
href='http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.30.7285'>GreedyDual-Size</a>
with the cost of each entry determined by the real (wall) time it took
to create it. The real time implementation is " +
    Roxen.html_encode_string (System.REAL_TIME_IMPLEMENTATION) +
    " which is " +
    (System.REAL_TIME_IS_MONOTONIC ? "monotonic" : "not monotonic") +
    " and has a resolution of " +
    (System.REAL_TIME_RESOLUTION / 1e6) + " ms.";

  protected int gettime_func()
  {
    // The real time includes a lot of noise that isn't appropriate
    // for cache entry cost measurement. Let's compensate for the time
    // spent in the pike gc, at least.
    //
    // FIXME: This function isn't monotonic if it's used inside gc
    // runs. That should be rare though, so we ignore it for now.
    return gethrtime() - Pike.implicit_gc_real_time();
  }
}

protected CM_GDS_RealTime cm_gds_realtime = CM_GDS_RealTime();

//! The preferred managers according to various caching requirements.
//! When several apply for a cache, choose the first one in this list.
//!
//! @dl
//! @item "default"
//!   The default manager for caches that do not specify any
//!   requirements.
//!
//! @item "no_cpu_timings"
//!   The manager to use for caches where a cache entry is created
//!   synchronously by one thread, but that thread spends most of its
//!   time waiting for a result from an external party, meaning that
//!   consumed cpu time is not an accurate measurement of the cost.
//!
//! @item "no_thread_timings"
//!   The manager to use for caches where a cache entry isn't created
//!   synchronously by one thread in the span between the
//!   @[cache_lookup] miss and the following @[cache_set].
//!
//! @item "no_timings"
//!   The manager to use for caches that do not have a usage pattern
//!   where it is meaningful to calculate the creation cost from the
//!   time between a @[cache_lookup] miss to the following
//!   @[cache_set].
//! @enddl
mapping(string:CacheManager) cache_manager_prefs = ([
#if 0
  // Workaround: The following uses GDS(cpu time) for most caches,
  // which should be more accurate. But since several caches cannot
  // use it, we get a balancing problem between it and GDS(real time).
  // Because update_cache_size_balance still isn't good enough at
  // responding to workload changes quickly, we stick to GDS(real
  // time) for now to make this problem less significant (there might
  // also be a few caches in GDS(1), but it's not large enough to
  // really matter).
  "default": (System.CPU_TIME_IS_THREAD_LOCAL != "yes" ||
	      System.CPU_TIME_RESOLUTION > 10000 ?
	      // Don't use cpu time if it's too bad. Buglet: We just
	      // assume the real time is better.
	      cm_gds_realtime :
	      cm_gds_cputime),
#else
  "default": cm_gds_realtime,
#endif
  "no_cpu_timings": cm_gds_realtime,
  "no_thread_timings": cm_gds_realtime,
  "no_timings": cm_gds_1,
]);

//! All available cache managers.
array(CacheManager) cache_managers =
  Array.uniq (({cache_manager_prefs->default,
		cache_manager_prefs->no_cpu_timings,
		cache_manager_prefs->no_thread_timings,
		cache_manager_prefs->no_timings,
	      }));

protected array(int) string_to_oid(string s)
{
  return ({ sizeof(s) }) + (array(int))s;
}

class CacheStatsMIB
{
  inherit SNMP.SimpleMIB;

  CacheStats stats;

  int get_count() { return stats->count; }
  int get_size() { return stats->size; }
  int get_hits() { return stats->hits; }
  int get_misses() { return stats->misses; }
  int get_cost_hits() { return (int)stats->cost_hits; }
  int get_cost_misses() { return (int)stats->cost_misses; }
#ifdef CACHE_HYTE_HR_STATS
  int get_byte_hits() { return stats->byte_hits; }
  int get_byte_misses() { return stats->byte_misses; }
#endif
  protected void create(CacheManager manager, string name, CacheStats stats)
  {
    this::stats = stats;
    array(int) oid = mib->path + string_to_oid(manager->name) + ({ 3 }) +
      string_to_oid(name);
    string label = "cache-"+name+"-";
    ::create(oid, ({}),
	     ({
	       UNDEFINED,
	       SNMP.String(name,     label+"name"),
	       SNMP.Gauge(get_count, label+"numEntries"),
	       SNMP.Gauge(get_size,  label+"numBytes"),
	       ({
		 SNMP.Counter(get_hits, label+"numHits"),
		 SNMP.Integer(get_cost_hits, label+"costHits"),
#ifdef CACHE_BYTE_HR_STATS
		 SNMP.Counter(get_byte_hits, label+"byteHits"),
#else
		 UNDEFINED,	/* Reserved */
#endif
	       }),
	       ({
		 SNMP.Counter(get_misses, label+"numMisses"),
		 SNMP.Integer(get_cost_misses, label+"costMisses"),
#ifdef CACHE_BYTE_HR_STATS
		 SNMP.Counter(get_byte_misses, label+"byteMisses"),
#else
		 UNDEFINED,	/* Reserved */
#endif
	       }),
	     }));
  }
}

class CacheManagerMIB
{
  inherit SNMP.SimpleMIB;

  CacheManager manager;
  int get_entries() { return Array.sum(values(manager->stats)->count); }
  int get_size() { return manager->size; }
  int get_entry_add_count() { return manager->entry_add_count; }
  int max_byte_add_count;
  int get_byte_add_count() {
    // SNMP.Counter should never decrease
    return max_byte_add_count = max(max_byte_add_count, manager->byte_add_count);
  }

  protected void create(CacheManager manager)
  {
    this::manager = manager;
    array(int) oid = mib->path + string_to_oid(manager->name);
    string label = "cacheManager-"+manager->name+"-";
    ::create(oid, ({}),
	     ({
	       UNDEFINED,
	       SNMP.String(manager->name, label+"name"),
	       ({
		 SNMP.Integer(get_entries,         label+"numEntries"),
		 SNMP.Integer(get_size,            label+"numBytes"),
		 SNMP.Counter(get_entry_add_count, label+"addedEntries"),
		 SNMP.Counter(get_byte_add_count,  label+"addedBytes"),
	       }),
	       UNDEFINED,	// Reserved for CacheStatsMIB.
	     }));
  }
}

protected Thread.Mutex cache_mgmt_mutex = Thread.Mutex();
// Locks operations that manipulate named caches, i.e. changes in the
// caches, CacheManager.stats and CacheManager.lookup mappings.

protected int cache_start_time = time() - 1;
protected int last_cache_size_balance = time() - 1;
// Subtract 1 from the initial values to avoid division by zero in
// update_decaying_stats if update_cache_size_balance gets called
// really soon after startup.

protected void update_cache_size_balance()
//! Updates the balance between the fractions of the total size
//! allocated to each cache manager.
{
  Thread.MutexKey lock = cache_mgmt_mutex->lock();

  int now = time();
  mapping(CacheManager:int) mgr_used = ([]);
  int used_size;

  // Update the decaying sums in the CacheStats objects.
  foreach (cache_managers, CacheManager mgr)
    mgr->update_decaying_stats (cache_start_time, last_cache_size_balance, now);

  if (!total_size_limit) {
    // Caches are effectively disabled. Ignore rebalance_min_size in this case.
    foreach (cache_managers, CacheManager mgr) {
      mgr->total_size_limit = 0;
      mgr->update_size_limit();
    }
  }

  else {
    foreach (cache_managers, CacheManager mgr)
      used_size += mgr_used[mgr] =
	mgr->size + (mgr->total_size_limit - mgr->size_limit);

    if (used_size < (int) (0.9 * total_size_limit)) {
      // The caches are underpopulated. Set the limits so that they all can
      // grow freely until the total limit is reached. The way this is done
      // might cause the combined size overshoot the limit, but we assume
      // update_cache_size_balance runs often enough to not let it get
      // seriously out of hand.
      int extra = total_size_limit - used_size;
      CACHE_WERR ("Rebalance: %db under the limit - free growth "
		  "(overshoot %db).\n", extra,
		  extra * sizeof (cache_managers) + used_size -
		  total_size_limit);

      foreach (cache_managers, CacheManager mgr) {
	mgr->total_size_limit = max (rebalance_min_size, mgr_used[mgr] + extra);
	mgr->update_size_limit();
      }
    }

    else {
      int reserved_size;
#ifdef CACHE_DEBUG
      int overshoot_size;
#endif
      mapping(CacheManager:int) mgr_reserved_size = ([]);
      mapping(CacheManager:float) mgr_weights = ([]);
      float total_weight = 0.0;

      foreach (cache_managers, CacheManager mgr) {
	int reserved = (int) (rebalance_keep_factor * mgr_used[mgr]);
	if (reserved < rebalance_min_size) {
	  // Don't reserve more than the used size - the rest is up for grabs
	  // by whichever cache fills it first. If that's under
	  // rebalance_min_size it means we get some "overshoot" room here
	  // too, like above.
	  reserved = mgr_used[mgr];
#ifdef CACHE_DEBUG
	  overshoot_size += rebalance_min_size - reserved;
#endif
	}
	reserved_size += mgr_reserved_size[mgr] = reserved;

	float hits;
	float misses;
	if (mgr->has_cost) {
	  hits = mgr->cost_hits;
	  misses = mgr->cost_misses;
	} else {
	  hits = mgr->hits;
	  misses = mgr->misses;
	}

	float lookups = hits + misses;
	float hit_rate_per_byte = lookups != 0.0 && mgr_used[mgr] ?
	  hits / lookups / mgr_used[mgr] : 0.0;

	// add_rate is a measurement on how many new bytes a cache could put
	// into use, and hit_rate_per_byte weighs in a projection on how
	// successful it would be caching those bytes.
	float weight = max (mgr->add_rate * hit_rate_per_byte, 0.0);
	mgr_weights[mgr] = weight;
	total_weight += weight;

	CACHE_WERR ("Rebalance weight %s: Reserved %db, "
		    "add rate %g, hr %g, hr/b %g, weight %g.\n",
		    mgr->name, reserved, mgr->add_rate,
		    lookups != 0.0 ? mgr->hits / lookups : 0.0,
		    hit_rate_per_byte, weight);
      }

      if (total_weight > 0.0) {
	// Don't change anything if there's no weight on any cache
	// manager. That means there's no activity.

	if (reserved_size > total_size_limit) {
	  // The caches are over the limit so much there's no room for
	  // weighted redistribution. Either total_size_limit has shrunk or
	  // they have overshot it as a result of the free growth policy.
	  // Shrink each cache manager relative to its current size.

	  // Ensure no manager gets below rebalance_min_size. Note that if a
	  // cache uses less than rebalance_min_size then the remaining space
	  // is available to the other caches, which means that sum of the
	  // limits might get larger than total_size_limit. That's intentional
	  // - it's a variant of the "overshoot" policy above.
	  int total_above_min = total_size_limit;
	  foreach (cache_managers, CacheManager mgr) {
	    int reserved = min (mgr_used[mgr], rebalance_min_size);
	    used_size -= reserved;
	    mgr_used[mgr] -= reserved;
	    total_above_min -= reserved;
	  }

	  if (used_size > 0) {
	    CACHE_WERR ("Rebalance: %db over the limit - shrinking linearly "
			"(overshoot %db).\n", used_size - total_above_min,
			rebalance_min_size * sizeof (cache_managers) +
			total_above_min - total_size_limit);

	    foreach (cache_managers, CacheManager mgr) {
	      int new_size = rebalance_min_size +
		(int) (((float) mgr_used[mgr] / used_size) * total_above_min);
	      CACHE_WERR ("Rebalance shrink %s: From %db to %db - diff %db.\n",
			  mgr->name, mgr->total_size_limit, new_size,
			  new_size - mgr->total_size_limit);
	      mgr->total_size_limit = new_size;
	      mgr->update_size_limit();
	    }
	  }
	}

	else {
	  int size_for_rebalance = total_size_limit - reserved_size;
	  CACHE_WERR ("Rebalance: %db for rebalance (reserved %db, "
		      "overshoot %db)\n", size_for_rebalance, reserved_size,
		      overshoot_size);

	  foreach (cache_managers, CacheManager mgr) {
	    int new_size = max (mgr_reserved_size[mgr] +
				(int) ((mgr_weights[mgr] / total_weight) *
				       size_for_rebalance),
				rebalance_min_size);
	    CACHE_WERR ("Rebalance on weight %s: From %db to %db - diff %db.\n",
			mgr->name, mgr->total_size_limit, new_size,
			new_size - mgr->total_size_limit);
	    mgr->total_size_limit = new_size;
	    mgr->update_size_limit();
	  }
	}
      }
    }
  }

#ifdef DEBUG
  foreach (cache_managers, CacheManager mgr)
    ASSERT_IF_DEBUG (mgr/*%O*/->total_size_limit /*%O*/ == 0 ||
		     mgr->total_size_limit >= rebalance_min_size,
		     mgr, mgr->total_size_limit);
#endif

  last_cache_size_balance = now;
}

protected void periodic_update_cache_size_balance()
{
  update_cache_size_balance();
  roxenp()->background_run (rebalance_interval, 
			    periodic_update_cache_size_balance);
}

#ifdef DEBUG_CACHE_SIZES
protected int cmp_sizeof_cache_entry (string cache_name, CacheEntry entry)
{
  int res;
  mixed data = entry->data;
  mapping opts = (["block_strings": 1,
#if DEBUG_CACHE_SIZES > 1
		   "collect_internals": 1,
#endif
		 ]);
  if (function(int|mapping:int) cm_cb =
      objectp (data) && data->cache_count_memory)
    res = cm_cb (opts) + Pike.count_memory (-1, entry, entry->key);
  else
    res = Pike.count_memory (opts, entry, entry->key, data);
#if DEBUG_CACHE_SIZES > 1
  werror ("Internals counted for %O / %O: ({\n%{%s,\n%}})\n",
	  cache_name, entry,
	  sort (map (opts->collect_internals,
		     lambda (mixed m) {return sprintf ("%O", m);})));
#endif
  return res;
}
#endif

protected mapping(string:CacheManager) caches = ([]);
// Maps the named caches to the cache managers that handle them.

mapping(string:CacheManager) cache_list()
//! Returns a list of all currently registered caches and their
//! managers.
{
  return caches + ([]);
}

CacheManager cache_register (string cache_name,
			     void|string|CacheManager manager,
                             void|CacheManagerPrefs prefs)
//! Registers a new cache. Returns its @[CacheManager] instance.
//!
//! @[manager] can be a specific @[CacheManager] instance to use, a
//! string that specifies a type of manager (see
//! @[cache_manager_prefs]), or zero to select the default manager.
//!
//! If @[prefs] is given it should point to an instance of
//! @[CacheManagerPrefs] that defines various cache behavior.
//!
//! If the cache already exists, its current manager is simply
//! returned, and @[manager] has no effect. It is however possible to
//! update @[prefs] for existing caches.
//!
//! Registering a cache is not mandatory before it is used - one will
//! be created automatically with the default manager otherwise.
//! Still, it's a good idea so that the cache list in the admin
//! interface gets populated timely.

{
  Thread.MutexKey lock =
    cache_mgmt_mutex->lock (2); // Called from cache_change_manager too.

  if (CacheManager mgr = caches[cache_name]) {
    if (prefs)
      mgr->prefs[cache_name] = prefs;
    return mgr;
  }

  if (!manager) manager = cache_manager_prefs->default;
  else if (stringp (manager)) {
    string cache_type = manager;
    manager = cache_manager_prefs[cache_type];
    if (!manager) error ("Unknown cache manager type %O requested.\n",
			 cache_type);
  }

  CacheStats stats = CacheStats();
  mib->merge(CacheStatsMIB(manager, cache_name, stats));
  caches[cache_name] = manager;
  manager->stats[cache_name] = stats;
  manager->lookup[cache_name] = ([]);
  if (prefs)
    manager->prefs[cache_name] = prefs;
  return manager;
}

void cache_unregister (string cache_name)
//! Unregisters the specified cache. This empties the cache and also
//! removes it from the cache overview in the admin interface.
{
  Thread.MutexKey lock = cache_mgmt_mutex->lock();

  // vvv Relying on the interpreter lock from here.
  if (CacheManager mgr = m_delete (caches, cache_name)) {
    mapping(mixed:CacheEntry) lm = m_delete (mgr->lookup, cache_name);
    CacheStats cs = m_delete (mgr->stats, cache_name);
    // ^^^ Relying on the interpreter lock to here.
    mgr->size -= cs->size;

    destruct (lock);
    foreach (lm;; CacheEntry entry)
      mgr->remove_entry (cache_name, entry);
  }
}

CacheManager cache_get_manager (string cache_name)
//! Returns the cache manager for the given cache, or zero if the
//! cache isn't registered.
{
  return caches[cache_name];
}

void cache_change_manager (string cache_name, CacheManager manager)
//! Changes the manager for a cache. All the cache entries are moved
//! to the new manager, but it might not have adequate information to
//! give them an accurate cost (typically applies to cost derived from
//! the creation time).
{
  Thread.MutexKey lock = cache_mgmt_mutex->lock();

  // vvv Relying on the interpreter lock from here.
  CacheManager old_mgr = m_delete (caches, cache_name);
  if (old_mgr == manager)
    caches[cache_name] = manager;
    // ^^^ Relying on the interpreter lock to here.

  else {
    mapping(mixed:CacheEntry) old_lm = m_delete (old_mgr->lookup, cache_name);
    CacheStats old_cs = m_delete (old_mgr->stats, cache_name);
    // ^^^ Relying on the interpreter lock to here.
    old_mgr->size -= old_cs->size;
    cache_register (cache_name, manager);

    // Move over the entries.
    destruct (lock);
    int entry_size_diff = (Pike.count_memory (0, manager->CacheEntry (0, 0)) -
			   Pike.count_memory (0, old_mgr->CacheEntry (0, 0)));
    foreach (old_lm; mixed key; CacheEntry old_ent) {
      old_mgr->remove_entry (cache_name, old_ent);
      CacheEntry new_ent = manager->CacheEntry (key, old_ent->data);
      new_ent->size = old_ent->size + entry_size_diff;
      manager->add_entry (cache_name, new_ent, 1, 0);
    }
    manager->update_size_limit(); // Evicts superfluous entries if necessary.
  }
}

void cache_expire (void|string cache_name)
//! Expires (i.e. removes) all entries in a named cache, or in all
//! caches if @[cache_name] is left out.
{
  // Currently not very efficiently implemented, but this function
  // doesn't have to be quick.
  foreach (cache_name ? ({cache_name}) : indices (caches), string cn) {
    CACHE_WERR ("Emptying cache %O.\n", cn);
    if (CacheManager mgr = caches[cn])
      if (mapping(mixed:CacheEntry) lm = mgr->lookup[cn]) {
	if (sizeof (mgr->lookup) == 1 || !cache_name) {
	  // Only one cache in this manager, or zapping all caches.
	  mgr->evict (0);
	  mgr->update_size_limit();
	}
	else
	  foreach (lm;; CacheEntry entry) {
	    MORE_CACHE_WERR ("cache_expire: Removing %O\n", entry);
	    mgr->remove_entry (cn, entry);
	  }
      }
  }
}

void cache_expire_by_prefix(string cache_name_prefix)
{
  map(filter(indices(caches), has_prefix, cache_name_prefix), cache_expire);
}

void flush_memory_cache (void|string cache_name) {cache_expire (cache_name);}

void cache_clear_deltas()
{
  cache_managers->clear_cache_context();
}

mixed cache_lookup (string cache_name, mixed key, void|mapping cache_context)
//! Looks up an entry in a cache. Returns @[UNDEFINED] if not found, or
//! if the stored value was zero and the cache garb evicted the entry.
//!
//! @[cache_context] is an optional mapping used to pass info between
//! @[cache_lookup] and @[cache_set], which some cache managers need
//! to determine the cost of the created entry (the work done between
//! a failed @[cache_lookup] and the following @[cache_set] with the
//! same key is assumed to be the creation of the cache entry).
//!
//! If @[cache_context] is not specified, a thread local mapping is
//! used. @[cache_context] is necessary when @[cache_lookup] and
//! @[cache_set] are called from different threads, or in different
//! callbacks from a backend. It should not be specified otherwise.
//!
//! If you need to use @[cache_context], create an empty mapping and
//! give it to @[cache_lookup]. Then give the same mapping to the
//! corresponding @[cache_set] when the entry has been created.
{
  CacheManager mgr = caches[cache_name] || cache_register (cache_name);

  if (mapping(mixed:CacheEntry) lm = mgr->lookup[cache_name])
    if (CacheEntry entry = lm[key]) {

      if (entry->timeout && entry->timeout <= time (1) || !entry->data) {
	mgr->remove_entry (cache_name, entry);
	mgr->got_miss (cache_name, key, cache_context);
	MORE_CACHE_WERR ("cache_lookup (%O, %s): %s\n",
			 cache_name, RXML.utils.format_short (key),
			 entry->data ? "Timed out" : "Destructed");
	return UNDEFINED;
      }

      mgr->got_hit (cache_name, entry, cache_context);
      MORE_CACHE_WERR ("cache_lookup (%O, %s): Hit\n",
		       cache_name, RXML.utils.format_short (key));
      return entry->data;
    }

  mgr->got_miss (cache_name, key, cache_context);
  MORE_CACHE_WERR ("cache_lookup (%O, %s): Miss\n",
		   cache_name, RXML.utils.format_short (key));
  return UNDEFINED;
}

mixed cache_peek (string cache_name, mixed key)
//! Checks if the cache contains an entry. Same as @[cache_lookup]
//! except that it doesn't affect the hit/miss statistics or the time
//! accounting used to estimate entry creation cost.
{
  if (CacheManager mgr = caches[cache_name])
    if (mapping(mixed:CacheEntry) lm = mgr->lookup[cache_name])
      if (CacheEntry entry = lm[key]) {

	if (entry->timeout && entry->timeout <= time (1)) {
	  mgr->remove_entry (cache_name, entry);
	  MORE_CACHE_WERR ("cache_peek (%O, %s): Timed out\n",
			   cache_name, RXML.utils.format_short (key));
	  return UNDEFINED;
	}

	MORE_CACHE_WERR ("cache_peek (%O, %s): Entry found\n",
			 cache_name, RXML.utils.format_short (key));
	return entry->data;
      }

  MORE_CACHE_WERR ("cache_peek (%O, %s): Entry not found\n",
		   cache_name, RXML.utils.format_short (key));
  return UNDEFINED;
}

mixed cache_set (string cache_name, mixed key, mixed data, void|int timeout,
		 void|mapping|int(1..1) cache_context)
//! Adds an entry to a cache.
//!
//! @param cache_name
//! The name of the cache. The cache has preferably been created with
//! @[cache_register], but otherwise it is created on-demand using the
//! default cache manager.
//!
//! @param key
//! The key for the cache entry. Normally a string, but can be
//! anything that works as an index in a mapping.
//!
//! @param data
//! The payload data. Note that if it is zero, the cache garb will
//! consider it a destructed object and evict it from the cache so
//! future lookups may return UNDEFINED instead.
//!
//! @param timeout
//! If nonzero, sets the maximum time in seconds that the entry is
//! valid.
//!
//! @param cache_context
//! The cache context mapping given to the earlier @[cache_lookup]
//! which failed to find the entry that this call adds to the cache.
//! See @[cache_lookup] for more details.
//!
//! @[cache_context] can also be the integer 1, which is a flag that
//! this entry got created without any prior lookup, so cache managers
//! tracking cost has to fall back to some default then.
//!
//! @returns
//! Returns @[data].
//!
//! @note
//! Cache managers commonly uses the time from the closest preceding
//! @[cache_lookup] call to calculate a weight for the entry. That
//! means the caller should avoid repeated calls to @[cache_set] for
//! the same entry.
{
  CacheManager mgr = caches[cache_name] || cache_register (cache_name);
  CacheEntry new_entry = mgr->CacheEntry (key, data);

  // We always create a new entry, even if the given key already
  // exists in the cache with the same data. That's to ensure we get
  // an up-to-date cost for the entry. (It's also a bit tricky to
  // atomically check for an existing entry here before creating a new
  // one.)

  if (timeout)
    new_entry->timeout = time (1) + timeout;

  mgr->add_entry (cache_name, new_entry,
		  intp (cache_context) && cache_context,
		  mappingp (cache_context) && cache_context);

  MORE_CACHE_WERR ("cache_set (%O, %s, %s, %O): %O\n",
		   cache_name, RXML.utils.format_short (key),
		   sprintf (objectp (data) ? "%O" : "%t", data), timeout,
		   new_entry);

  return data;
}

void cache_remove (string cache_name, mixed key)
//! Removes an entry from the cache.
//!
//! @note
//! If @[key] was zero, this function used to remove the whole cache.
//! Use @[cache_expire] for that instead.
{
  MORE_CACHE_WERR ("cache_remove (%O, %O)\n", cache_name, key);
  if (CacheManager mgr = caches[cache_name])
    if (mapping(mixed:CacheEntry) lm = mgr->lookup[cache_name])
      if (CacheEntry entry = lm[key])
	mgr->remove_entry (cache_name, entry);
}

mapping(mixed:CacheEntry) cache_entries (string cache_name)
//! Returns the lookup mapping for the given named cache. Don't be
//! destructive on the returned mapping or anything inside it.
{
  if (CacheManager mgr = caches[cache_name])
    if (mapping(mixed:CacheEntry) lm = mgr->lookup[cache_name])
      return lm;
  return ([]);
}

array cache_indices(string|void cache_name)
// Deprecated compat function.
{
  if (!cache_name)
    return indices (caches);
  else
    return indices (cache_entries (cache_name));
}

mapping(CacheManager:mapping(string:CacheStats)) cache_stats()
//! Returns the complete cache statistics. For each cache manager, a
//! mapping with the named caches it handles is returned, with their
//! respective @[CacheStat] objects. Don't be destructive on any part
//! of the returned value.
{
  mapping(CacheManager:mapping(string:CacheStats)) res = ([]);
  foreach (cache_managers, CacheManager mgr)
    res[mgr] = mgr->stats;
  return res;
}

// GC statistics. These are decaying sums/averages over the last
// gc_stats_period seconds.
constant gc_stats_period = 60 * 60;
float sum_gc_runs = 0.0, sum_gc_time = 0.0;
float sum_destruct_garbage_size = 0.0;
float sum_timeout_garbage_size = 0.0;
float avg_destruct_garbage_ratio = 0.0;
float avg_timeout_garbage_ratio = 0.0;

int last_gc_run;

protected void cache_clean()
// Periodic gc, to clean up timed out and destructed entries.
{
  int now = time (1);
  int vt = gethrvtime(), t = gethrtime();
  int total_size, destr_garb_size, timeout_garb_size;

  CACHE_WERR ("Starting RAM cache cleanup.\n");

  // Note: Might be necessary to always recheck the sizes here, since
  // entries can change in size for a number of reasons. Most of the
  // time it doesn't matter much, but the risk is that the size limit
  // gets unacceptably off after a while.

#ifdef DEBUG_CACHE_SIZES
  mapping(CacheManager:int) cache_sizes = ([]);
#endif

  foreach (caches; string cache_name; CacheManager mgr) {
#ifdef DEBUG_CACHE_SIZES
    int cache_count, cache_size;
#endif
    if (mapping(mixed:CacheEntry) lm = mgr->lookup[cache_name]) {
      foreach (lm;; CacheEntry entry) {

	if (!entry->data) {
	  MORE_CACHE_WERR ("%s: Removing destructed entry %O\n",
			   cache_name, entry);
	  destr_garb_size += entry->size;
	  mgr->remove_entry (cache_name, entry);
	}

	else if (entry->timeout && entry->timeout <= now) {
	  MORE_CACHE_WERR ("%s: Removing timed out entry %O\n",
			   cache_name, entry);
	  timeout_garb_size += entry->size;
	  mgr->remove_entry (cache_name, entry);
	}

	else {
#ifdef DEBUG_CACHE_SIZES
	  cache_count++;
	  cache_size += entry->size;
	  int size = cmp_sizeof_cache_entry (cache_name, entry);
	  if (size != entry->cmp_size) {
	    // Note that there are a lot of sources for false alarms here.
	    // E.g. RXML trees can increase in size due to new <if>/<else>
	    // branches getting visited, the entry might just happen to be in
	    // use during the count_memory call here, and there are often
	    // minor differences for whatever reason..
	    werror ("Size diff in %O: Is %d, was %d in cache_set() - "
		    "diff %d: %O\n",
		    cache_name, size, entry->cmp_size,
		    size - entry->cmp_size, entry);
	    // Update to avoid repeated messages.
	    entry->cmp_size = size;
	  }
#endif
	}
      }
    }

#ifdef DEBUG_CACHE_SIZES
    mapping(string:int)|CacheStats st = mgr->stats[cache_name] || ([]);
    // These might show false alarms due to races.
    if (cache_count != st->count)
      werror ("Entry count difference for %O: "
	      "Have %d, expected %d - diff %d.\n",
	      cache_name, cache_count, st->count, cache_count - st->count);
    if (cache_size != st->size)
      werror ("Entry size difference for %O: "
	      "Have %d, expected %d - diff %d.\n",
	      cache_name, cache_size, st->size, cache_size - st->size);
    cache_sizes[mgr] += st->size;
#endif
  }

  foreach (cache_managers, CacheManager mgr) {
    mgr->after_gc();
    total_size += mgr->size;

#ifdef DEBUG_CACHE_SIZES
    // This might show false alarms due to races.
    if (cache_sizes[mgr] != mgr->size)
      werror ("Cache size difference for %O: "
	      "Have %d, expected %d - diff %d.\n",
	      mgr, cache_sizes[mgr], mgr->size, cache_sizes[mgr] - mgr->size);
#endif
  }

  vt = gethrvtime() - vt;	// -1 - -1 if cpu time isn't working.
  t = gethrtime() - t;
  CACHE_WERR ("Finished RAM cache cleanup: "
	      "%db stale, %db timed out, took %s.\n",
	      destr_garb_size, timeout_garb_size,
	      Roxen.format_hrtime (vt || t));

  int stat_last_period = now - last_gc_run;
  int stat_tot_period = now - cache_start_time;
  int startup = stat_tot_period < gc_stats_period;
  if (!startup) stat_tot_period = gc_stats_period;

  if (stat_last_period > stat_tot_period) {
    // GC intervals are larger than the statistics interval, so just
    // set the values. Note that stat_last_period is very large on the
    // first call since last_gc_run is zero, so we always get here then.
    sum_gc_time = (float) (vt || t);
    sum_gc_runs = 1.0;
    sum_destruct_garbage_size = (float) destr_garb_size;
    sum_timeout_garbage_size = (float) timeout_garb_size;
    if (total_size) {
      avg_destruct_garbage_ratio = (float) destr_garb_size / total_size;
      avg_timeout_garbage_ratio = (float) timeout_garb_size / total_size;
    }
  }

  else {
    float our_weight = (float) stat_last_period / stat_tot_period;
    float old_weight = 1.0 - our_weight;

    if (startup) {
      sum_gc_runs += 1.0;
      sum_gc_time += (float) (vt || t);
      sum_destruct_garbage_size += (float) destr_garb_size;
      sum_timeout_garbage_size += (float) timeout_garb_size;
    }

    else {
      sum_gc_runs = old_weight * sum_gc_runs + 1.0;
      sum_gc_time = old_weight * sum_gc_time + (float) (vt || t);
      sum_destruct_garbage_size = (old_weight * sum_destruct_garbage_size +
				   (float) destr_garb_size);
      sum_timeout_garbage_size = (old_weight * sum_timeout_garbage_size +
				  (float) timeout_garb_size);
    }

    if (total_size) {
      avg_destruct_garbage_ratio = (old_weight * avg_destruct_garbage_ratio +
				    our_weight * destr_garb_size / total_size);
      avg_timeout_garbage_ratio = (old_weight * avg_timeout_garbage_ratio +
				   our_weight * timeout_garb_size / total_size);
    }
  }

  last_gc_run = now;

  if (Configuration admin_config = roxenp()->get_admin_configuration())
    admin_config->log_event ("roxen", "ram-cache-gc", 0, ([
			       "handle-cputime": vt,
			       "handle-time": t,
			       "stale-size": destr_garb_size,
			       "timed-out-size": timeout_garb_size,
			     ]));

  // Fall back to 60 secs just in case the config is messed up somehow.
  roxenp()->background_run (roxenp()->query ("mem_cache_gc_2") || 60,
			    cache_clean);
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

  foreach(nongc_cache; string cache; mapping(string:mixed) cachemap) {
    int size = Pike.count_memory (0, cachemap);
    res[cache] = ({ sizeof(cachemap), size});
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
private void store_session(string db_name, string id, mixed data, int t) {
  data = encode_value(data);
  db(db_name)->query("REPLACE INTO session_cache VALUES (%s,%d,%s)",
		     id, t, data);
}

// GC that, depending on the sessions session_persistence either
// throw the session away or store it in a database.
private void session_cache_handler() {
  int t=time(1);
  if(max_persistence>t) {

  clean:
    foreach(session_buckets[-1]; string id; mixed data) {
      if(session_persistence[id]<t) {
	m_delete(session_buckets[-1], id);
	m_delete(session_persistence, id);
	continue;
      }
      for(int i; i<SESSION_BUCKETS-2; i++)
	if(session_buckets[i][id]) {
	  continue clean;
	}
      if(objectp(data)) {
	m_delete(session_buckets[-1], id);
	m_delete(session_persistence, id);
	continue;
      }
      store_session("local", id, data, session_persistence[id]);
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
      foreach(session_bucket; string id; mixed data)
	if(session_persistence[id]>t) {
	  store_session("local", id, data, session_persistence[id]);
	  m_delete(session_persistence, id);
	}
  }
  report_notice("Session cache synchronized\n");
}

//! Removes the session data associated with @[id] from the session
//! cache and session database.
//!
//! @[db_name] may be given to use another database than the default
//! "local". That implictly disables the RAM based bucket cache.
//!
//! @seealso
//!   set_session_data
void clear_session(string id, void|string db_name) {
  if (!db_name) {
    m_delete(session_persistence, id);
    foreach(session_buckets, mapping bucket)
      m_delete(bucket, id);
  }
  db(db_name || "local")->query("DELETE FROM session_cache WHERE id=%s", id);
}

//! Returns the data associated with the session @[id].
//! Returns a zero type upon failure.
//!
//! @[db_name] may be given to use another database than the default
//! "local". That implictly disables the RAM based bucket cache.
//!
//! @seealso
//!   set_session_data
mixed get_session_data(string id, void|string db_name) {
  mixed data;
  if (!db_name)
    foreach(session_buckets, mapping bucket)
      if(data=bucket[id]) {
	session_buckets[0][id] = data;
	return data;
      }
  data = db(db_name || "local")->
    query("SELECT data FROM session_cache WHERE id=%s", id);
  if(sizeof([array]data) &&
     !catch(data=decode_value( ([array(mapping(string:string))]data)[0]->data )))
    return data;
  return ([])[0];
}

//! Associates the session @[id] to the @[data]. If no @[id] is provided
//! a unique id will be generated. The session id is returned from the
//! function. The minimum guaranteed storage time may be set with the
//! @[persistence] argument. Note that this is a time stamp, not a time out.
//!
//! If @[store] is set, the @[data] will be stored in a database
//! directly, and not when the garbage collect tries to delete the
//! data. This will ensure that the data is kept safe in case the
//! server restarts before the next GC. @[store] may also be the name
//! of another database where the "session_cache" table resides. In
//! that case the @[data] is always stored directly.
//!
//! @note
//!   The @[data] must not contain any object, programs or functions, or the
//!   storage in database will throw an error.
//!
//! @seealso
//!   get_session_data, clear_session
string set_session_data(mixed data, void|string id, void|int persistence,
			void|int(0..1)|string store) {
  if(!id) id = ([function(void:string)]roxenp()->create_unique_id)();
  if (intp (store)) {
    session_persistence[id] = persistence;
    session_buckets[0][id] = data;
    max_persistence = max(max_persistence, persistence);
  }
  if(store && persistence)
    store_session(stringp (store) ? store : "local", id, data, persistence);
  return id;
}

int setup_session_table (string db_name)
//! Creates a table "session_cache" with the proper definition in the
//! given database.
{
  Sql.Sql conn = db (db_name);
  if (!conn) return 0;
  conn->query("CREATE TABLE IF NOT EXISTS session_cache ("
	      "id CHAR(32) NOT NULL PRIMARY KEY, "
	      "persistence INT UNSIGNED NOT NULL DEFAULT 0, "
	      "data BLOB NOT NULL)");
  return 1;
}

// Sets up the session database tables.
private void setup_tables() {
  setup_session_table ("local");
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
  roxenp()->background_run (0, periodic_update_cache_size_balance);
  roxenp()->background_run(SESSION_SHIFT_TIME, session_cache_handler);

  CACHE_WERR("Cache garb call outs installed.\n");
}

void create()
{
  add_constant( "cache", this_object() );

  nongc_cache = ([ ]);

  session_buckets = ({ ([]) }) * SESSION_BUCKETS;
  session_persistence = ([]);

  CACHE_WERR("Now online.\n");
}

void destroy() {
  session_cache_destruct();
  return;
}
