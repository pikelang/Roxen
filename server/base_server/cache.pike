// This file is part of Roxen Webserver.
// Copyright © 1996 - 2000, Roxen IS.
// $Id: cache.pike,v 1.56 2000/09/04 12:11:09 jonasw Exp $

#pragma strict_types

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
// The size of the entry, in byts.
#define SIZE 3

#if DEBUG_LEVEL > 8
# ifndef CACHE_DEBUG
#  define CACHE_DEBUG
# endif
#endif

#undef CACHE_WERR
#ifdef CACHE_DEBUG
# define CACHE_WERR(X) werror("CACHE: "+X+"\n");
#else
# define CACHE_WERR(X)
#endif

#undef CACHE40_WERR
#if DEBUG_LEVEL > 40
# define CACHE40_WERR(X) werror("CACHE: "+X+"\n");
#else
# define CACHE40_WERR(X)
#endif

// The actual cache along with some statistics mappings.
static mapping(string:mapping(string:array)) cache;
static mapping(string:int) hits=([]), all=([]);

void flush_memory_cache() {
  cache=([]);
  hits=([]);
  all=([]);
}

// Calculates the size of an entry, though it isn't very good at it.
constant svalsize = 4*4; // if pointers are 4 bytes..
int get_size(mixed x, void|int iter)
{
  if(iter++>20) {
    CACHE_WERR("Too deep recursion when examining entry size.\n");
    return 0;
  }
  if(mappingp(x))
    return svalsize + 64 + get_size(indices([mapping]x), iter) +
      get_size(values([mapping]x), iter);
  else if(stringp(x))
    return strlen([string]x)+svalsize;
  else if(arrayp(x))
  {
    int i;
    foreach([array]x, mixed f)
      i += get_size(f,iter);
    return svalsize + 4 + i;    // (base) + arraysize
  } else if(multisetp(x)) {
    int i;
    foreach(indices([multiset]x), mixed f)
      i += get_size(f,iter);
    return svalsize + i;    // (base) + arraysize
  } else if(objectp(x) || functionp(x)) {
    return svalsize + 128; // (base) + object struct + some extra.
    // _Should_ consider size of global variables / refcount
  }
  return svalsize; // base
}

// Expire a whole cache
void cache_expire(string in)
{
  CACHE_WERR(sprintf("cache_expire(\"%s\")", in));
  m_delete(cache, in);
}

// Lookup an entry in a cache
mixed cache_lookup(string in, string what)
{
  CACHE_WERR(sprintf("cache_lookup(\"%s\",\"%s\")  ->  ", in, what));
  all[in]++;
  int t=time(1);
  // Does the entry exist at all?
  if(array entry = (cache[in] && cache[in][what]) )
    // Is it time outed?
    if (entry[TIMEOUT] && entry[TIMEOUT] < t) {
      m_delete (cache[in], what);
      CACHE_WERR("Timed out");
    }
    else {
      // Update the timestamp and hits counter and return the value.
      cache[in][what][TIMESTAMP]=t;
      CACHE_WERR("Hit");
      hits[in]++;
      return entry[DATA];
    }
  else CACHE_WERR("Miss");
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
    array(int) entry = ({ sizeof(cache[name]),
			  hits[name],
			  all[name],
			  get_size(cache[name]) });
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
void cache_remove(string in, string what)
{
  CACHE_WERR(sprintf("cache_remove(\"%s\",\"%O\")", in, what));
  if(!what)
    m_delete(cache, in);
  else
    if(cache[in])
      m_delete(cache[in], what);
}

// Add an entry to a cache
mixed cache_set(string in, string what, mixed to, int|void tm)
{
#if DEBUG_LEVEL > 40
  CACHE_WERR(sprintf("cache_set(\"%s\", \"%s\", %O)\n",
		     in, what, to));
#else
  CACHE_WERR(sprintf("cache_set(\"%s\", \"%s\", %t)\n",
		     in, what, to));
#endif
  int t=time(1);
  if(!cache[in])
    cache[in]=([ ]);
  cache[in][what] = allocate(ENTRY_SIZE);
  cache[in][what][DATA] = to;
  if(tm) cache[in][what][TIMEOUT] = t + tm;
  cache[in][what][TIMESTAMP] = t;
  return to;
}

// Clean the cache.
void cache_clean()
{
  remove_call_out(cache_clean);
  int gc_time=[int]roxenp()->query("mem_cache_gc");
  string a, b;
  array c;
  int t=time(1);
  CACHE_WERR("cache_clean()");
  foreach(indices(cache), a)
  {
    CACHE40_WERR("  Class  " + a);
    foreach(indices(cache[a]), b)
    {
      CACHE40_WERR("     " + b + " ");
      c = cache[a][b];
#ifdef DEBUG
      if(!intp(c[TIMESTAMP]))
	error("     Illegal timestamp in cache ("+a+":"+b+")\n");
#endif
      if(c[TIMEOUT] && c[TIMEOUT] < t) {
	CACHE40_WERR("     DELETED (explicit timeout)");
	m_delete(cache[a], b);
      }
      else {
	if(!c[SIZE]) {
	  c[SIZE]=(get_size(b) + get_size(c[DATA]) + 5*svalsize + 4)/100;
	  // (Entry size + cache overhead) / arbitrary factor
          CACHE40_WERR("     Cache entry size percieved as " +
		       ([int]c[SIZE]*100) + " bytes\n");
	}
	if(c[TIMESTAMP]+1 < t && c[TIMESTAMP] + gc_time -
	   c[SIZE] < t)
	  {
	    CACHE40_WERR("     DELETED");
	    m_delete(cache[a], b);
	  }
#ifdef CACHE_DEBUG
#if DEBUG_LEVEL > 40
	else
	  CACHE_WERR("Ok");
#endif
#endif
      }
      if(!sizeof(cache[a]))
      {
	CACHE40_WERR("  Class DELETED.");
	m_delete(cache, a);
      }
    }
  }
  call_out(cache_clean, gc_time);
}

void create()
{
  cache=([ ]);
  add_constant( "cache", this_object() );
  call_out(cache_clean, 60);
  CACHE_WERR("Now online.");
}
