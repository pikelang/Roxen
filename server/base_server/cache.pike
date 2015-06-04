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

#ifdef NEW_RAM_CACHE

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

class CacheEntry (mixed key, mixed data)
//! Base class for cache entries.
{
  // FIXME: Consider unifying this with CacheKey. But in that case we
  // need to ensure "interpreter lock" atomicity below.

  int size;
  //! The size of this cache entry, as measured by @[Pike.count_memory].

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
    else if (objectp (key))
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

class CacheManager
//! A cache manager handles one or more caches, applying the same
//! eviction policy and the same size limit on all of them. I.e. it's
//! practically one cache, and the named caches inside only act as
//! separate name spaces.
{
  //! @decl constant string name;
  //!
  //! A unique name to identify the manager. It is also used as
  //! display name.

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
	// vvv Relying on the interpreter lock from here.
	CacheEntry old_entry = lm[entry->key];
	lm[entry->key] = entry;
	// ^^^ Relying on the interpreter lock to here.

	if (old_entry) {
	  account_remove_entry (cache_name, old_entry);
	  recent_added_bytes -= entry->size;
	  remove_entry (cache_name, old_entry);
	}

	cs->count++;
	cs->size += entry->size;
	size += entry->size;
	recent_added_bytes += entry->size;

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

    float our_weight = min (last_period / tot_period, 1.0);
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
	       this->name || "-", size / 1024, size_limit / 1024);
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

  class CacheEntry
  {
    inherit global::CacheEntry;

    int|float value;
    //! The value of the entry, i.e. v(p) in the class description.

    int|float pval;
    //! The priority value for the entry, defining its position in
    //! @[priority_list]. Must not change for an entry that is
    //! currently a member of @[priority_list].

    string cache_name;
    //! Need the cache name to find the entry, since @[priority_list]
    //! is global.

    protected int `< (CacheEntry other)
    {
      return pval < other->pval;
    }

    protected string _sprintf (int flag)
    {
      return flag == 'O' && sprintf ("CacheEntry(%s, %db, %O)",
				     format_key(), size, value);
    }
  }

  multiset(CacheEntry) priority_list = (<>);
  //! A list of all entries in priority order, by using the multiset
  //! builtin sorting through @[CacheEntry.`<].

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
    if (CacheEntry lowest = get_iterator (priority_list)->index()) {
      int|float l = lowest->pval, v = entry->value;
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
    int|float pval = calc_pval (entry);

    // Note: Won't have the interpreter lock during the operation below. The
    // tricky situation occur if the same entry is processed by another
    // got_hit, where we might get it inserted in more than one place and one
    // of them will be inconsistent with the pval value. evict() has a
    // consistency check that should detect and correct this eventually. The
    // worst thing that happens is that the eviction order is more or less
    // wrong until then.
    priority_list[entry] = 0;
    entry->pval = pval;
    priority_list[entry] = 1;
  }

  int add_entry (string cache_name, CacheEntry entry,
		 int old_entry, mapping cache_context)
  {
    entry->cache_name = cache_name;
    int|float v = entry->value =
      calc_value (cache_name, entry, old_entry, cache_context);

    if (!low_add_entry (cache_name, entry)) return 0;

    entry->pval = calc_pval (entry);
    priority_list[entry] = 1;

    if (size > size_limit) evict (size_limit);
    return 1;
  }

  int remove_entry (string cache_name, CacheEntry entry)
  {
    priority_list[entry] = 0;
    return low_remove_entry (cache_name, entry);
  }

  void evict (int max_size)
  {
    object threads_disabled;

    while (size > max_size) {
      CacheEntry entry = get_iterator (priority_list)->index();
      if (!entry) break;

      if (!priority_list[entry]) {
	// The order in the list has become inconsistent with the pval values.
	// It might happen due to the race in got_hit(), or it might just be
	// interference from a concurrent evict() call.
	if (!threads_disabled)
	  // Take a hefty lock and retry, to rule out the second case.
	  threads_disabled = _disable_threads();
	else {
	  // Got the lock so it can't be a race, i.e. the priority_list order
	  // is funky. Have to rebuild it without interventions.
	  report_warning ("Warning: Recovering from race inconsistency "
			  "in %O->priority_list.\n", this);
	  priority_list = (<>);
	  foreach (lookup; string cache_name; mapping(mixed:CacheEntry) lm)
	    foreach (lm;; CacheEntry entry)
	      priority_list[entry] = 1;
	}
	continue;
      }

      priority_list[entry] = 0;

      MORE_CACHE_WERR ("evict: Size %db > %db - evicting %O / %O.\n",
		       size, max_size, entry->cache_name, entry);

      low_remove_entry (entry->cache_name, entry);
    }

    threads_disabled = 0;
  }

  int manager_size_overhead()
  {
    return Pike.count_memory (-1, priority_list) + ::manager_size_overhead();
  }

  void after_gc()
  {
    if (max_used_pval > Int.NATIVE_MAX / 2) {
      int|float pval_base;
      if (CacheEntry lowest = get_iterator (priority_list)->index())
	pval_base = lowest->pval;
      else
	return;

      // To cope with concurrent updates, we replace the lookup
      // mapping and start adding back the entries from the old one.
      // Need _disable_threads to make the resets of the CacheStats
      // fields atomic.
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
      priority_list = (<>);
      size = 0;
      max_used_pval = 0;
      threads_disabled = 0;

      int|float max_pval;

      foreach (old_lookup; string cache_name; mapping(mixed:CacheEntry) old_lm)
	if (CacheStats cs = stats[cache_name])
	  if (mapping(mixed:CacheEntry) new_lm = lookup[cache_name])
	    foreach (old_lm; mixed key; CacheEntry entry) {
	      int|float pval = entry->pval -= pval_base;
	      if (!new_lm[key]) {
		// Relying on the interpreter lock here.
		new_lm[key] = entry;

		priority_list[entry] = 1;
		if (pval > max_pval) max_pval = pval;

		cs->count++;
		cs->size += entry->size;
		size += entry->size;
	      }
	    }

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
      return flag == 'O' && sprintf ("CacheEntry(%s, %db, %O, %O)",
				     format_key(), size, value, cost);
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
    //werror ("Miss.\n%s\n", describe_backtrace (backtrace()));
    account_miss (cache_name);
    save_start_hrtime (cache_name, key, cache_context);
  }

  void got_hit (string cache_name, CacheEntry entry, mapping cache_context)
  {
    account_hit (cache_name, entry);
    // It shouldn't be necessary to record the start time for cache
    // hits, but do it anyway for now since there are caches that on
    // cache hits extend the entries with more data.
    save_start_hrtime (cache_name, entry->key, cache_context);
  }

  protected int entry_create_hrtime (string cache_name, mixed key,
				     mapping cache_context)
  {
    if (mapping all_ctx = cache_context || cache_contexts->get())
      if (mapping(mixed:int) ctx = all_ctx[cache_name]) {
	int start = m_delete (ctx, key);
	if (!zero_type (start)) {
	  int duration = (gettime_func() - all_ctx[0]) - start;
	  ASSERT_IF_DEBUG (duration /*%O*/ >= 0 /* start: %O, all_ctx: %O */,
			   duration, start, all_ctx);
	  if (duration < 0)
	    // Limit the breakage somewhat when the assertion isn't active.
	    duration = 0;
	  all_ctx[0] += duration;
	  return duration;
	}
      }
#ifdef DEBUG
    werror ("Warning: No preceding lookup for this key - "
	    "cannot determine entry creation time.\n%s\n",
	    describe_backtrace (backtrace()));
#endif
    return 0;
  }

  protected float mean_cost;
  protected int mean_count = 0;
  // This is not a real mean value since we (normally) don't keep
  // track of the cost of each entry. Instead it's a decaying average.

  float calc_value (string cache_name, CacheEntry entry,
		    int old_entry, mapping cache_context)
  {
    if (int hrtime = !old_entry &&
	entry_create_hrtime (cache_name, entry->key, cache_context)) {
      float cost = entry->cost = (float) hrtime;

      if (!mean_count) {
	mean_cost = cost;
	mean_count = 1;
      }
      else {
	mean_cost = (mean_count * mean_cost + cost) / (mean_count + 1);
	if (mean_count < 1000) mean_count++;
      }

      return cost / entry->size;
    }

    // Awkward situation: We don't have any cost for this entry. Just
    // use the mean cost of all entries in the cache, so it at least
    // isn't way off in either direction.
    return mean_cost / entry->size;
  }

  void evict (int max_size)
  {
    ::evict (max_size);
    if (!max_size) mean_count = 0;
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

	float lookups = mgr->has_cost ?
	  mgr->cost_hits + mgr->cost_misses : mgr->hits + mgr->misses;
	float hit_rate_per_byte = lookups != 0.0 && mgr_used[mgr] ?
	  mgr->hits / lookups / mgr_used[mgr] : 0.0;

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
			     void|string|CacheManager manager)
//! Registers a new cache. Returns its @[CacheManager] instance.
//!
//! @[manager] can be a specific @[CacheManager] instance to use, a
//! string that specifies a type of manager (see
//! @[cache_manager_prefs]), or zero to select the default manager.
//!
//! If the cache already exists, its current manager is simply
//! returned, and @[manager] has no effect.
//!
//! Registering a cache is not mandatory before it is used - one will
//! be created automatically with the default manager otherwise.
//! Still, it's a good idea so that the cache list in the admin
//! interface gets populated timely.

{
  Thread.MutexKey lock =
    cache_mgmt_mutex->lock (2); // Called from cache_change_manager too.

  if (CacheManager mgr = caches[cache_name])
    return mgr;

  if (!manager) manager = cache_manager_prefs->default;
  else if (stringp (manager)) {
    string cache_type = manager;
    manager = cache_manager_prefs[cache_type];
    if (!manager) error ("Unknown cache manager type %O requested.\n",
			 cache_type);
  }

  caches[cache_name] = manager;
  manager->stats[cache_name] = CacheStats();
  manager->lookup[cache_name] = ([]);
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
    if (CacheManager mgr = caches[cn]) {
      mgr->evict (0);
      mgr->update_size_limit();
    }
  }
}

void flush_memory_cache (void|string cache_name) {cache_expire (cache_name);}

void cache_clear_deltas()
{
  cache_managers->clear_cache_context();
}

mixed cache_lookup (string cache_name, mixed key, void|mapping cache_context)
//! Looks up an entry in a cache. Returns @[UNDEFINED] if not found.
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
	return 0;
      }

      mgr->got_hit (cache_name, entry, cache_context);
      MORE_CACHE_WERR ("cache_lookup (%O, %s): Hit\n",
		       cache_name, RXML.utils.format_short (key));
      return entry->data;
    }

  mgr->got_miss (cache_name, key, cache_context);
  MORE_CACHE_WERR ("cache_lookup (%O, %s): Miss\n",
		   cache_name, RXML.utils.format_short (key));
  return 0;
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
	  return 0;
	}

	MORE_CACHE_WERR ("cache_peek (%O, %s): Entry found\n",
			 cache_name, RXML.utils.format_short (key));
	return entry->data;
      }

  MORE_CACHE_WERR ("cache_peek (%O, %s): Entry not found\n",
		   cache_name, RXML.utils.format_short (key));
  return 0;
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
//! The payload data. This cannot be a zero, since the cache garb will
//! consider that a destructed object and evict it from the cache.
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
{
  ASSERT_IF_DEBUG (data);

  CacheManager mgr = caches[cache_name] || cache_register (cache_name);
  CacheEntry new_entry = mgr->CacheEntry (key, data);

#ifdef DEBUG_COUNT_MEM
  mapping opts = (["lookahead": DEBUG_COUNT_MEM - 1,
		   "collect_stats": 1,
		   "collect_direct_externals": 1,
		 ]);
  float t = gauge {
#else
#define opts 0
#endif

      if (function(int|mapping:int) cm_cb =
	  objectp (data) && data->cache_count_memory)
	new_entry->size = cm_cb (opts) + Pike.count_memory (-1, new_entry, key);
      else
	new_entry->size = Pike.count_memory (opts, new_entry, key, data);

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

  if (timeout)
    new_entry->timeout = time (1) + timeout;

  mgr->add_entry (cache_name, new_entry, intp (cache_context),
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

#else  // !NEW_RAM_CACHE

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

protected int sizeof_cache_entry (array entry)
{
  int res;

#ifdef DEBUG_COUNT_MEM
  mapping opts = (["lookahead": DEBUG_COUNT_MEM - 1,
		   "collect_stats": 1,
		   "collect_direct_externals": 1,
		 ]);
  float t = gauge {
#else
#define opts 0
#endif

      if (function(int|mapping:int) cm_cb =
	  objectp (entry[DATA]) && entry[DATA]->cache_count_memory)
	res = cm_cb (opts) + Pike.count_memory (-1, entry);
      else
	res = Pike.count_memory (opts, entry);

#ifdef DEBUG_COUNT_MEM
    };
  werror ("%s: la %d size %d time %g int %d cyc %d ext %d vis %d revis %d "
	  "rnd %d wqa %d\n",
	  (objectp (entry[DATA]) ?
	   sprintf ("%O", entry[DATA]) : sprintf ("%t", entry[DATA])),
	  opts->lookahead, opts->size, t, opts->internal, opts->cyclic,
	  opts->external, opts->visits, opts->revisits, opts->rounds,
	  opts->work_queue_alloc);

#if 0
  if (opts->external) {
    opts->collect_direct_externals = 1;
    // Raise the lookahead to 1 to recurse the closest externals.
    if (opts->lookahead < 1) opts->lookahead = 1;

    if (function(int|mapping:int) cm_cb =
	objectp (entry[DATA]) && entry[DATA]->cache_count_memory)
      res = cm_cb (opts) + Pike.count_memory (-1, entry);
    else
      res = Pike.count_memory (opts, entry);

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

  return res;
}

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

object cache_register (string cache_name, void|string|object manager)
// Forward compat dummy.
{
  return 0;
}

// Expire a whole cache
void cache_expire(string in)
{
  CACHE_WERR("cache_expire(%O)\n", in);
  m_delete(cache, in);
}

// Lookup an entry in a cache
mixed cache_lookup(string in, mixed what, void|mapping ignored)
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

mixed cache_peek (string cache_name, mixed key)
// Forward compat alias.
{
  return cache_lookup (cache_name, key);
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
  foreach (cache; string name; mapping(string:array) cache_class) {
#ifdef DEBUG_COUNT_MEM
    werror ("\nCache: %s\n", name);
#endif
    //  We only show names up to the first ":" if present. This lets us
    //  group entries together in the status table.
    string show_name = (name / ":")[0];
    int size = 0;
    foreach (cache_class; string idx; array entry) {
      if (!entry[SIZE])
	entry[SIZE] = Pike.count_memory (0, idx) + sizeof_cache_entry (entry);
      size += entry[SIZE];
    }
    array(int) entry = ({ sizeof(cache[name]),
			  hits[name],
			  all[name],
			  size });
    if (!zero_type(ret[show_name]))
      for (int idx = 0; idx <= 3; idx++)
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
mixed cache_set(string in, mixed what, mixed to, int|void tm,
		void|mapping|int(1..1) ignored)
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
#ifdef DEBUG_COUNT_MEM
    werror ("\nCache: %s\n", cache_class_name);
#endif

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
	  }
#endif /* TIME_BASED_CACHE */

	if(!entry[SIZE])
	  entry[SIZE] = Pike.count_memory (0, idx) + sizeof_cache_entry (entry);
	if(
#ifdef OLD_RAM_CACHE_FIXED_GC
	  entry[TIMEOUT]+1 < now
#else
	  entry[TIMESTAMP]+1 < now
#endif
	  && entry[TIMESTAMP] + gc_time - entry[SIZE] / 100 < now)
	{
	  m_delete(cache_class, idx);
	  MORE_CACHE_WERR("    %O with size %d bytes: Deleted\n",
			  idx, [int] entry[SIZE]);
	}
	else
	  MORE_CACHE_WERR("    %O with size %d bytes: Ok\n",
			  idx, [int] entry[SIZE]);
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

#endif	// !NEW_RAM_CACHE


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
#ifdef NEW_RAM_CACHE
  roxenp()->background_run (0, periodic_update_cache_size_balance);
#endif
  roxenp()->background_run(SESSION_SHIFT_TIME, session_cache_handler);

  CACHE_WERR("Cache garb call outs installed.\n");
}

void create()
{
  add_constant( "cache", this_object() );
#ifndef NEW_RAM_CACHE
  cache = ([ ]);
#endif

  nongc_cache = ([ ]);

  session_buckets = ({ ([]) }) * SESSION_BUCKETS;
  session_persistence = ([]);

  CACHE_WERR("Now online.\n");
}

void destroy() {
  session_cache_destruct();
  return;
}
