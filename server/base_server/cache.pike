// This file is part of Roxen WebServer.
// Copyright © 1996 - 2009, Roxen IS.
// $Id: cache.pike,v 1.95 2009/11/12 14:43:59 mast Exp $

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

// FIXME: Statistics from the gc for invalid cache entry ratio.

constant default_cache_size = 50 * 1024 * 1024;
// FIXME: Better way to deduce the default size.

class CacheEntry (mixed key, mixed data)
//! Base class for cache entries.
{
  // FIXME: Consider unifying this with CacheKey. But in that case we
  // need to ensure "interpreter lock" atomicity below.

  int size;
  //! The size of this cache entry, as measured by @[Pike.count_memory].

  int timeout;
  //! Unix time when the entry times out, or zero if there's no
  //! timeout.

  //! @decl int|float cost;
  //!
  //! The creation cost for the entry, according to the metric used by
  //! the cache manager (provided it implements cost).

  protected string _sprintf (int flag)
  {
    return flag == 'O' &&
      sprintf ("CacheEntry(%s, %db)",
	       (stringp (key) ? key[..20] :
		sprintf (objectp (key) ? "%O" : "%t", key)),
	       size);
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
  //! Plain counts of cache hits and misses.

#ifdef RAMCACHE_STATS
  int byte_hits, byte_misses;
  //! Byte hit and miss count. Note that @[byte_misses] is determined
  //! when a new entry is added - it will not include when no new
  //! entry was created after a cache miss.

  int|float cost_hits, cost_misses;
  //! Hit and miss count according to the cache manager cost metric.
  //! Note that @[cost_misses] is determined when a new entry is added
  //! - it will not include when no new entry was created after a
  //! cache miss.
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

  int total_size_limit;
  //! Maximum allowed size including the cache manager overhead.

  int size;
  //! The sum of @[CacheStats.size] for all named caches.

  int size_limit;
  //! Maximum allowed size for cache entries - @[size] should never
  //! greater than this. This is a cached value calculated from
  //! @[total_size_limit] on regular intervals.

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

  //! @decl program CacheEntry;
  //!
  //! The manager-specific class to use to create @[CacheEntry] objects.

  void got_miss (string cache_name, mixed key, mapping cache_context);
  //! Called when @[cache_lookup] records a cache miss.

  protected void account_miss (string cache_name)
  {
    if (CacheStats cs = stats[cache_name])
      cs->misses++;
  }

  void got_hit (string cache_name, CacheEntry entry);
  //! Called when @[cache_lookup] records a cache hit.

  protected void account_hit (string cache_name, CacheEntry entry)
  {
    if (CacheStats cs = stats[cache_name]) {
      cs->hits++;
#ifdef RAMCACHE_STATS
      cs->byte_hits += entry->size;
      cs->cost_hits += entry->cost;
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

  protected int low_add_entry (string cache_name, CacheEntry entry)
  {
    ASSERT_IF_DEBUG (entry->size /*%O*/, entry->size);

    if (CacheStats cs = stats[cache_name]) {
#ifdef RAMCACHE_STATS
      // Assume that the addition of the new entry came about due to a
      // cache miss.
      cs->byte_misses += entry->size;
      cs->cost_misses += entry->cost;
#endif

      if (mapping(mixed:CacheEntry) lm = lookup[cache_name]) {
	// vvv Relying on the interpreter lock from here.
	CacheEntry old_entry = lm[entry->key];
	lm[entry->key] = entry;
	// ^^^ Relying on the interpreter lock to here.

	if (old_entry)
	  remove_entry (cache_name, old_entry);

	cs->count++;
	cs->size += entry->size;
	size += entry->size;

	if (!(cs->misses & 0x3fff)) // = 16383
	  // Approximate the number of misses as the number of new entries
	  // added to the cache. That should be a suitable unit to use for the
	  // update interval since the manager overhead should be linear to
	  // the number of cached entries.
	  update_size_limit();
      }

      return 1;
    }

    return 0;
  }

  int remove_entry (string cache_name, CacheEntry entry);
  //! Called to delete an entry from the cache. Returns 1 if the entry
  //! got removed from the cache. Returns 0 if the entry wasn't found
  //! in the cache or if the cache has disappeared.

  protected int low_remove_entry (string cache_name, CacheEntry entry)
  {
    if (mapping(mixed:CacheEntry) lm = lookup[cache_name])
      if (m_delete (lm, entry->key)) {
	if (CacheStats cs = stats[cache_name]) {
	  cs->count--;
	  cs->size -= entry->size;
	  ASSERT_IF_DEBUG (cs->size /*%O*/ >= 0, cs->size);
	  ASSERT_IF_DEBUG (cs->count /*%O*/ >= 0, cs->count);
	}
	size -= entry->size;
	ASSERT_IF_DEBUG (size /*%O*/ >= 0, size);

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
    return (Pike.count_memory (-1, this) +
	    Pike.count_memory (0, stats) +
	    Pike.count_memory ((["block_objects": 1]), lookup));
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

  string format_cost (int|float cost) {return "-";}
  //! Function to format a cost measurement for display in the status
  //! page.

  protected void create (int total_size_limit)
  {
    this_program::total_size_limit = total_size_limit;
    update_size_limit();
  }

  protected string _sprintf (int flag)
  {
    return flag == 'O' &&
      sprintf ("CacheManager(%s: %dk/%dk)",
	       this->name || "-", size / 1024, size_limit / 1024);
  }
}

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

  void got_hit (string cache_name, CacheEntry entry)
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
	  MORE_CACHE_WERR ("%s: Size is %d - evicting %O.\n",
			   cache_name, size, entry);
	  low_remove_entry (cache_name, entry);
	}
	else
	  m_delete (lookup, cache_name);
      }
    }
  }
}

protected CM_Random cm_random = CM_Random (default_cache_size);

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
      return flag == 'O' && sprintf ("CacheEntry(%O, %db, %O)",
				     key, size, value);
    }
  }

  multiset(CacheEntry) priority_list = (<>);
  //! A list of all entries in priority order, by using the multiset
  //! builtin sorting through @[CacheEntry.`<].

  int|float pval_limit = Int.NATIVE_MAX / 2;
  //! Approximate limit for priority values. When they get over this,
  //! the base will be reset to zero on the next gc.
  // Should be a constant, but we currently can't create an int|float
  // type on a constant.

  protected int|float max_used_pval;
  // Save the max used pval since the multiset iterator currently
  // can't access the last element efficiently.

  int|float calc_value (string cache_name, CacheEntry entry,
			int old_entry, mapping cache_context);
  //! Called to calculate the value for @[entry], which gets assigned
  //! to the @expr{value@} variable. Arguments are the same as to
  //! @[add_entry].

  void got_miss (string cache_name, mixed key, mapping cache_context)
  {
    account_miss (cache_name);
  }

  void got_hit (string cache_name, CacheEntry entry)
  {
    account_hit (cache_name, entry);

    int|float pv;
    if (CacheEntry lowest = get_iterator (priority_list)->index()) {
      pv = entry->value + lowest->pval;

      if (floatp (pv) && pv == lowest->pval &&
	  entry->value != 0.0 && lowest->pval != 0.0) {
#ifdef DEBUG
	werror ("Cache %s: Ran out of significant digits for cache entry %O - "
		"got min priority %O and entry value %O.\n",
		cache_name, entry, lowest->pval, entry->value);
#endif
	// Force a reset of the pvals in the next gc.
	max_used_pval = pval_limit * 2;
      }
    }
    else
      pv = entry->value;

    if (pv > max_used_pval) max_used_pval = pv;

    // vvv Relying on the interpreter lock from here.
    priority_list[entry] = 0;
    entry->pval = pv;
    priority_list[entry] = 1;
    // ^^^ Relying on the interpreter lock to here.
  }

  int add_entry (string cache_name, CacheEntry entry,
		 int old_entry, mapping cache_context)
  {
    entry->cache_name = cache_name;
    int|float v = entry->value =
      calc_value (cache_name, entry, old_entry, cache_context);

    if (!low_add_entry (cache_name, entry)) return 0;

    int|float pv;
    if (CacheEntry lowest = get_iterator (priority_list)->index()) {
      pv = entry->pval = v + lowest->pval;

      if (floatp (pv) && pv == lowest->pval &&
	  v != 0.0 && lowest->pval != 0.0) {
#ifdef DEBUG
	werror ("Cache %s: Ran out of significant digits for cache entry %O - "
		"got min priority %O and entry value %O.\n",
		cache_name, entry, lowest->pval, v);
#endif
	// Force a reset of the pvals in the next gc.
	max_used_pval = pval_limit * 2;
      }
    }
    else
      pv = entry->pval = v;

    if (pv > max_used_pval) max_used_pval = pv;

    priority_list[entry] = 1;

    if (size > size_limit) evict (size_limit);
    return 1;
  }

  int remove_entry (string cache_name, CacheEntry entry)
  {
    if (!low_remove_entry (cache_name, entry)) return 0;
    priority_list[entry] = 0;
    return 1;
  }

  void evict (int max_size)
  {
    while (size > max_size) {
      CacheEntry entry = get_iterator (priority_list)->index();
      if (!entry) break;
      MORE_CACHE_WERR ("%s: Size is %d - evicting %O.\n",
		       entry->cache_name, size, entry);
      priority_list[entry] = 0;
      low_remove_entry (entry->cache_name, entry);
    }
  }

  void after_gc()
  {
    if (max_used_pval > pval_limit) {
      // The neat thing to do here is to lower all priority values,
      // but it has to be done atomically. Since this presumably
      // happens so seldom we take the easy way and just empty the
      // caches instead.
      CACHE_WERR ("%O: Max priority value %O over limit %O - resetting.\n",
		  this, max_used_pval, pval_limit);

      if (Configuration admin_config = roxenp()->get_admin_configuration())
	// Log an event, in case it doesn't happen that seldom afterall.
	admin_config->log_event ("roxen", "reset-ram-cache", this->name);

      while (sizeof (priority_list))
	evict (0);
      max_used_pval = intp (pval_limit) ? 0 : 0.0;
    }
  }

  protected void create (int total_size_limit)
  {
    ::create (total_size_limit);
    max_used_pval = intp (pval_limit) ? 0 : 0.0;
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

  float pval_limit = 1e-6 / Float.EPSILON;
  // Put the limit before we start to lose too much precision. Since
  // calc_value returns 1.0/(size in bytes), the issue becomes to
  // avoid L + c(p) == L for reasonably sized entries. Assuming most
  // entries are in the range 1-10 kb we get c(p) in the range 1e-3 to
  // 1e-4. We also need some significant digits afterwards, say at
  // least two. So put our epsilon at approx 1e-6.
  //
  // FIXME: For 32 bit architectures with a standard pike, that puts
  // the limit close to 1.0, so the risk of too frequent resets is
  // real.

  float calc_value (string cache_name, CacheEntry entry,
		    int old_entry, mapping cache_context)
  {
    ASSERT_IF_DEBUG (entry->size /*%O*/ > 10, entry->size);
    return 1.0 / entry->size;
  }
}

protected CM_GDS_1 cm_gds_1 = CM_GDS_1 (default_cache_size);

protected Thread.Local cache_contexts = Thread.Local();
// A thread local mapping to store the timestamp from got_miss so it
// can be read from the (presumably) following add_entry.
//
// In an entry with index 0 in the mapping, the time spent creating
// cache entries is accumulated. It is used to deduct the time for
// creating entries in subcaches.
//
// FIXME: Doesn't work with callbacks etc.

class CM_GD_TimeCost
//! Like @[CM_GreedyDual] but adds support for calculating cost based
//! on passed time as the basis for the entry creation cost.
{
  inherit CM_GreedyDual;

#ifdef RAMCACHE_STATS
  class CacheEntry
  {
    inherit CM_GreedyDual::CacheEntry;
    int|float cost;

    protected string _sprintf (int flag)
    {
      return flag == 'O' && sprintf ("CacheEntry(%O, %db, %O, %O)",
				     key, size, value, cost);
    }
  }
#endif

  protected int gettime_func();
  //! Returns the current time for cost calculation.

  void got_miss (string cache_name, mixed key, mapping cache_context)
  {
    //werror ("Miss.\n%s\n", describe_backtrace (backtrace()));

    account_miss (cache_name);

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

  int entry_create_hrtime (string cache_name, mixed key,
			   mapping cache_context)
  //! Returns the time spent since the @[got_miss] call for the given key.
  {
    if (mapping all_ctx = cache_context || cache_contexts->get())
      if (mapping(mixed:int) ctx = all_ctx[cache_name]) {
	int start = m_delete (ctx, key);
	if (!zero_type (start)) {
	  int duration = (gettime_func() - all_ctx[0]) - start;
	  ASSERT_IF_DEBUG (duration >= 0);
	  all_ctx[0] += duration;
	  return duration;
	}
      }
#ifdef DEBUG
    werror ("Warning: No preceding missed lookup for this key - "
	    "cannot determine entry creation time.\n%s\n",
	    describe_backtrace (backtrace()));
#endif
    return 0;
  }
}

class CM_GDS_RealTime
{
  inherit CM_GD_TimeCost;

  constant name = "GDS(real time)";
  constant doc = #"\
This cache manager implements <a
href='http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.30.7285'>GreedyDual-Size</a>
with the cost of each entry determined by the real (wall) time it took
to create it.";

  protected float mean_cost;
  protected int mean_count = 0;
  // This is not a real mean value since we (normally) don't keep
  // track of the cost of each entry. Instead it's a decaying average.

  float pval_limit = 1e-6 / Float.EPSILON;
  // FIXME: Tune.

  protected int gettime_func()
  {
    // The real time includes a lot of noise that isn't appropriate
    // for cache entry cost measurement. Let's compensate for the time
    // spent in the pike gc, at least.
    return gethrtime() - Pike.implicit_gc_real_time();
  }

  float calc_value (string cache_name, CacheEntry entry,
		    int old_entry, mapping cache_context)
  {
    if (int hrtime = !old_entry &&
	entry_create_hrtime (cache_name, entry->key, cache_context)) {
      float cost = (float) hrtime;
#ifdef RAMCACHE_STATS
      entry->cost = cost;
#endif

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

protected CM_GDS_RealTime cm_gds_realtime =
  CM_GDS_RealTime (default_cache_size);

class CM_GDS_CPUTime
{
  inherit CM_GDS_RealTime;

  constant name = "GDS(cpu time)";
  constant doc = #"\
This cache manager implements <a
href='http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.30.7285'>GreedyDual-Size</a>
with the cost of each entry determined by the CPU time it took to
create it.";

  protected int gettime_func()
  {
    return gethrvtime();
  }
}

protected CM_GDS_CPUTime cm_gds_cputime = CM_GDS_CPUTime (default_cache_size);

//! The preferred managers according to various caching requirements:
//!
//! @dl
//! @item "default"
//!   The default manager for caches that do not specify any
//!   requirements.
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
  "default": cm_gds_realtime,
  "no_thread_timings": cm_gds_realtime,
  "no_timings": cm_gds_1,
]);

//! All available cache managers.
array(CacheManager) cache_managers =
  Array.uniq (({cache_manager_prefs->default,
		cache_manager_prefs->no_thread_timings,
		cache_manager_prefs->no_timings,
		cm_random,
	      }) + values (cache_manager_prefs));

protected mapping(string:CacheManager) caches = ([]);
// Maps the named caches to the cache managers that handle them.

protected Thread.Mutex cache_mgmt_mutex = Thread.Mutex();
// Locks operations that manipulate named caches, i.e. changes in the
// caches, CacheManager.stats and CacheManager.lookup mappings.

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
  Thread.Mutex lock =
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
  Thread.Mutex lock = cache_mgmt_mutex->lock();

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

void cache_change_manager (string cache_name, CacheManager manager)
//! Changes the manager for a cache. All the cache entries are moved
//! to the new manager, but it might not have adequate information to
//! give them an accurate cost (typically applies to cost derived from
//! the creation time).
{
  Thread.Mutex lock = cache_mgmt_mutex->lock();

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
  foreach (cache_name ? ({cache_name}) : indices (caches); string cn;) {
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
  cache_contexts->set (([]));
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

      if (entry->timeout && entry->timeout <= time (1)) {
	mgr->remove_entry (cache_name, entry);
	mgr->got_miss (cache_name, key, cache_context);
	MORE_CACHE_WERR ("cache_lookup (%O, %s): Timed out\n",
			 cache_name, RXML.utils.format_short (key));
	return 0;
      }

      mgr->got_hit (cache_name, entry);
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
		 void|mapping cache_context)
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
      new_entry->size = Pike.count_memory (0, new_entry, key, data);
    };
  werror ("%O -> %s: la %d size %d time %g int %d cyc %d ext %d vis %d "
	  "revis %d rnd %d wqa %d\n",
	  key, sprintf (objectp (data) ? "%O" : "%t", data),
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
#else  // !DEBUG_COUNT_MEM
  new_entry->size = Pike.count_memory (0, new_entry, key, data);
#endif

  if (timeout)
    new_entry->timeout = time (1) + timeout;

  mgr->add_entry (cache_name, new_entry, 0, cache_context);

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
      if (CacheEntry entry = m_delete (lm, key))
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

protected void cache_clean()
// Periodic gc, to clean up timed out and destructed entries.
{
  int now = time (1);
  int vt = gethrvtime(), t = gethrtime();

  CACHE_WERR ("Starting RAM cache cleanup.\n");

  foreach (caches;; CacheManager mgr) {
    foreach (mgr->lookup; string cache_name; mapping(mixed:CacheEntry) lm)
      foreach (lm;; CacheEntry entry)
	if (!entry->data || entry->timeout && entry->timeout <= now) {
	  MORE_CACHE_WERR ("%s: Removing %s entry %O\n", cache_name,
			   entry->data ? "timed out" : "destructed", entry);
	  mgr->remove_entry (cache_name, entry);
	}
    mgr->after_gc();
  }

  vt = gethrvtime() - vt;	// -1 - -1 if cpu time isn't working.
  t = gethrtime() - t;
  CACHE_WERR ("Finished RAM cache cleanup - took %s.\n",
	      Roxen.format_hrtime (vt || t));

  if (Configuration admin_config = roxenp()->get_admin_configuration())
    admin_config->log_event ("roxen", "ram-gc", 0, ([
			       "handle-cputime": vt,
			       "handle-time": t,
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
mixed cache_set(string in, mixed what, mixed to, int|void tm,
		void|mapping ignored)
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
	if(entry[TIMESTAMP]+1 < now &&
	   entry[TIMESTAMP] + gc_time - entry[SIZE] / 100 < now)
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
