// This file is part of Roxen Webserver.
// Copyright © 1996 - 2000, Roxen IS.
// $Id: cache.pike,v 1.46 2000/03/13 18:27:42 nilsson Exp $

#pragma strict_types

#include <roxen.h>
#include <config.h>

#define TIMESTAMP 0
#define DATA 1
#define TIMEOUT 2
#define SIZE 3

#define ENTRY_SIZE 4

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

mapping(string:mapping(string:array)) cache;
mapping(string:int) hits=([]), all=([]);

constant svalsize = 4*4; // if pointers are 4 bytes..
int get_size(mixed x, void|int iter)
{
  if(iter++>50) {
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

#ifdef THREADS
Thread.Mutex cleaning_lock = Thread.Mutex();
#endif /* THREADS */

void cache_expire(string in)
{
  m_delete(cache, in);
}

mixed cache_lookup(string in, string what)
{
  CACHE_WERR(sprintf("cache_lookup(\"%s\",\"%s\")  ->  ", in, what));
  all[in]++;
  if(array entry = cache[in] && cache[in][what])
    if (entry[TIMEOUT] && entry[TIMEOUT] < time(1)) {
      CACHE_WERR("Timed out");
      m_delete (cache[in], what);
    }
    else {
      CACHE_WERR("Hit");
      hits[in]++;
      cache[in][what][TIMESTAMP]=time(1);
      return entry[DATA];
    }
  else CACHE_WERR("Miss");
  return ([])[0];
}

string status()
{
  string res, a;
  res = "<table cellpadding=\"3\" cellspacing=\"0\" border=\"0\">"
      #"<tr bgcolor=\"&usr.fade3;\">
<td>&locale.class_;</td>
<td align=\"right\">&locale.entries;</td>
<td align=\"right\">&locale.size;</td>
<td align=\"right\">&locale.hits;</td>
<td align=\"right\">&locale.misses;</td>
<td align=\"right\">&locale.hitpct;</td>
";

  mapping(string:int) ca=([]), cb=([]), ch=([]), ct=([]);
  array(string) b=indices(cache);
  array(int) c=Array.map(values(cache), get_size);
  int i;

  for(i=0; i<sizeof(b); i++)
  {
    int s = sizeof(cache[b[i]]);
    int h = hits[b[i]];
    int t = all[b[i]];
    sscanf(b[i], "%s:", b[i]);
    b[i] = ([function(void:object(RoxenLocale.standard))]roxenp()->locale->get)()
      ->config_interface
      ->translate_cache_class( b[i] );
    ca[b[i]]+=c[i]; cb[b[i]]+=s; ch[b[i]]+=h; ct[b[i]]+=t;
  }
  b=indices(ca);
  c=values(ca);
  sort(c,b);
  int n, totale, totalm, totalh, mem, totalr;
  i=0;
  c=reverse(c);
  foreach(reverse(b), a)
  {
    if(ct[a])
    {
      res += ("<tr align=\"right\" bgcolor=\""+(n/3%2?"&usr.bgcolor;":"&usr.fade1;")+
	      "\"><td align=\"left\">"+a+"</td><td>"+cb[a]+"</td><td>" +
	      sprintf("%.1f", ((mem=c[i])/1024.0)) + "</td>");
      res += "<td>"+ch[a]+"</td><td>"+(ct[a]-ch[a])+"</td>";
      if(ct[a])
	res += "<td>"+(ch[a]*100)/ct[a]+"%</td>";
      else
	res += "<td>0%</td>";
      res += "</tr>";
      totale += cb[a];
      totalm += mem;
      totalh += ch[a];
      totalr += ct[a];
    }
    i++;
  }
  res += "<tr align=\"right\" bgcolor=\"&usr.fade3;\"><td align=\"left\">&nbsp;</td><td>"+
    totale+"</td><td>" + sprintf("%.1f", (totalm/1024.0)) + "</td>";
  res += "<td>"+totalh+"</td><td>"+(totalr-totalh)+"</td>";
  if(totalr)
    res += "<td>"+(totalh*100)/totalr+"%</td>";
  else
    res += "<td>0%</td>";
  res += "</tr>";
  return res + "</table>";
}

void cache_remove(string in, string what)
{
  CACHE_WERR(sprintf("cache_remove(\"%s\",\"%O\")", in, what));
  if(!what)
    m_delete(cache, in);
  else
    if(cache[in])
      m_delete(cache[in], what);
}

mixed cache_set(string in, string what, mixed to, int|void tm)
{
#if DEBUG_LEVEL > 40
  CACHE_WERR(sprintf("cache_set(\"%s\", \"%s\", %O)\n",
		     in, what, to));
#else
  CACHE_WERR(sprintf("cache_set(\"%s\", \"%s\", %t)\n",
		     in, what, to));
#endif
  if(!cache[in])
    cache[in]=([ ]);
  cache[in][what] = allocate(ENTRY_SIZE);
  cache[in][what][DATA] = to;
  if(tm) cache[in][what][TIMEOUT] = time(1) + tm;
  cache[in][what][TIMESTAMP] = time(1);
  return to;
}

void cache_clear(string in)
{
  CACHE_WERR(sprintf("cache_clear(\"%s\")", in));
  if(cache[in])
    m_delete(cache,in);
}

void cache_clean()
{
  remove_call_out(cache_clean);
  int gc_time=[int]roxenp()->query("mem_cache_gc");
  string a, b;
  array c;
  int t=[int]time(1);
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
	  c[SIZE]=(get_size(c[DATA])+5*svalsize+4)/100;
	  // (Entry size + cache overhead) / arbitrary factor
          CACHE40_WERR("     Cache entry size percieved as "+([int]c[SIZE]*100)+" bytes\n");
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
