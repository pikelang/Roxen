// This is a roxen module which provides explicit data caching.
// Copyright (c) 2004-2005, Stephen R. van den Berg, The Netherlands.
//                     <srb@cuci.nl>
//
// This module is open source software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
// by the Free Software Foundation; either version 2, or (at your option) any
// later version.
//

constant cvs_version =
 "$Id: datacache.pike,v 1.1 2004/06/07 02:04:14 _cvs_stephen Exp $";
constant thread_safe = 1;

#include <module.h>

inherit "module";

// ---------------- Module registration stuff ----------------

constant module_type = MODULE_TAG;
LocaleString module_name = "Tags: Datacache";
LocaleString module_doc  = 
 "This module provides the datacache RXML tag.<br />"
 "<p>Copyright &copy; 2004-2005, by "
 "<a href='mailto:srb@cuci.nl'>Stephen R. van den Berg</a>, "
 "The Netherlands.</p>"
 "<p>This module is open source software; you can redistribute it and/or "
 "modify it under the terms of the GNU General Public License as published "
 "by the Free Software Foundation; either version 2, or (at your option) any "
 "later version.</p>";

void create() {
  set_module_creator("Stephen R. van den Berg <srb@cuci.nl>");
  defvar("maxsize", 64*1024, "Maximum size of cached element",
   TYPE_INT,
   "Elements larger than this, will not be stored in the cache.");
  defvar("maxmem", 512*1024, "Maximum cache size in bytes",
   TYPE_INT,
   "When the cache size rises above this level in one cachestore, "
   "the oldest entries will be expired.");
  defvar("maxcount", 0, "Maximum number of cache entries",
   TYPE_INT,
   "When the number of cache entries in one cachestore rises above this "
   "level, the oldest entries will be expired.");
  defvar("maxage", 0, "Limit on the age of the oldest entry",
   TYPE_INT,
   "Entries older than this many seconds, will be expired.");
}

class MemCache {
  static int smaxmem;
  int usedmem;
  static int smaxage;
  static int smaxcount;
  int entrycount;
  static int smaxsize;
  static int(0..1) spurge;
  static array(mixed) root=({0,0});
  static enum storetype {inext, iprev, iexpires, iautorefresh, isize, ivalue};
  static mapping(string|int:array(mixed)) thestore=([0:root]);
  private Thread.Mutex listorder=Thread.Mutex();

  void setparameters(int maxmem,void|int maxage, void|int maxcount,
   void|int maxsize, void|int(0..1) purge) {
    if(entrycount)
      expire(maxmem, maxage, maxcount, maxsize, purge);
    smaxmem=maxmem; smaxcount=maxcount; smaxage=maxage;
    smaxsize=maxsize; spurge=purge;
  }

  static void create(int maxmem, void|int maxage, void|int maxcount,
   void|int maxsize, void|int(0..1) purge) {
    setparameters(maxmem, maxage, maxcount, maxsize, purge);
  }

  static void doexpire(int t, void|int purge) {
    while(entrycount
     && (smaxmem && usedmem>smaxmem || smaxcount && entrycount>smaxcount
      || smaxage && smaxage<=t-thestore[root[inext]][iexpires]))
      drop(root[inext], purge);
  }

  void expire(int maxmem, void|int maxage, void|int maxcount, void|int maxsize,
   void|int purge) {
    if(maxsize && (!smaxsize || maxsize<smaxsize)) {
      array match;
      for(mixed key=root[inext];match=thestore[key];) {
        string nextkey=match[inext];
        if(match[isize]>maxsize)
          drop(key,purge);
        key=nextkey;
      }
    }
    if(maxmem && (!smaxmem || maxmem<smaxmem)
     || maxage && (!smaxage || maxage<smaxage)
     || maxcount && (!smaxcount || maxcount<smaxcount))
      doexpire(time(1), purge);
  }

  static void hit(string|int key, array match) {
    thestore[match[inext]][iprev]=match[iprev];
    thestore[match[iprev]][inext]=match[inext];
    match[inext]=0;
    root[iprev]=thestore[match[iprev]=root[iprev]][inext]=key;
  }

  void drop(string|int key, void|int(0..1) purge) {
    array match;
    { Thread.MutexKey k=listorder->lock();
      if(!key || !(match=thestore[key]))
        return;
      thestore[match[inext]][iprev]=match[iprev];
      thestore[match[iprev]][inext]=match[inext];
      m_delete(thestore,key);
      destruct(k);
    }
    mixed op=match[ivalue];
    usedmem-=match[isize];
    if((spurge||purge) && objectp(op))
      destruct(op);
    entrycount--;
  }

  mixed get(string|int key) {
    array match;
    if(key && (match=thestore[key])) {
      int t=time(1);
      int iar=match[iautorefresh];
      if(iar || match[iexpires]>t) {
        if(iar)
          match[iexpires]=t+iar;
        Thread.MutexKey k=listorder->lock();
        if(match=thestore[key])
          hit(key, match);
        destruct(k);
      }
      else
        drop(key), match=0;
    }
    return match && match[ivalue];
  }

  mixed store(string|int key, mixed value, void|int expires, void|int size,
   void|int autorefresh) {
    if(key) {
      int t=time(1);
      if(!size)
        size=sizeof(value);	 // This is far from ideal, FIXME
      if(smaxsize && size>smaxsize)
        return value;
      if(!expires) {
        expires=t+autorefresh;
        if(!autorefresh)
          if(smaxage)
            expires+=smaxage;
          else
            expires++, autorefresh=1;
      }
      array match;
      if(match=thestore[key]) {
        mixed op=match[ivalue];
        { Thread.MutexKey k=listorder->lock();
          if(match=thestore[key]) {
            match[ivalue]=value;
            match[iexpires]=expires; match[iautorefresh]=autorefresh;
	    usedmem+=size-match[isize];
            match[isize]=size;
            hit(key,match);
          }
          destruct(k);
        }
        if(spurge && objectp(op) && op!=value)
          destruct(op);
      }
      else {
        match=({0,0,expires,autorefresh,size,value});
        { Thread.MutexKey k=listorder->lock();
          if(!thestore[key]) {
            thestore[root[iprev]=thestore[match[iprev]=root[iprev]][inext]=key]
             = match;
	    entrycount++;usedmem+=size;
          }
          destruct(k);
        }
      }
      doexpire(t);
    }
#ifdef DEBUG
    else
      throw(0);	     // empty keys should not be stored in the cache
#endif
    return value;
  }

  mixed `[](string|int key) {
    return get(key);
  }

  mixed `[]= (string|int key, mixed value) {
    return store(key, value);
  }
}

static mapping(string:array(int)) hitcount=([]);

string status() {
  string s="<tr><td colspan=7 align=center>None yet</td></tr>";
  if(sizeof(hitcount))
   { s="";
     foreach(sort(indices(hitcount)),string store) {
       array cnt=hitcount[store];
       MemCache cache=caches[store];
       s+=sprintf("<tr><td>%s&nbsp;</td>"
        "<td align=right>%d</td><td align=right>%s</td>"
        "<td align=right>%d</td><td align=right>%s</td>"
        "<td align=right>%d</td><td align=right>%s</td></tr>"
        ,store,cache->entrycount,String.int2size(cache->usedmem),
        cnt[0],String.int2size(cnt[1]),cnt[2],String.int2size(cnt[3]));
     }
   }
  return "<table border=1><tr><th>Store</th>"
   "<th colspan=2>Stored/Traffic</th>"
   "<th colspan=2>Hits/Traffic</th>"
   "<th colspan=2>Misses/Traffic</th></tr>"+
   s+"</table>";
}

// ------------------- Containers ----------------

mapping(string:MemCache) caches=([]);

class TagDatacache
{
  inherit RXML.Tag;
  constant name = "datacache";
  constant flags = (RXML.FLAG_GET_RAW_CONTENT |
                    RXML.FLAG_GET_EVALED_CONTENT |
                    RXML.FLAG_DONT_CACHE_RESULT |
                    RXML.FLAG_CUSTOM_TRACE);
  array(RXML.Type) result_types = ({RXML.t_any});

  mapping(string:RXML.Type) req_arg_types = ([
   "key":RXML.t_text(RXML.PEnt),
  ]);
  mapping(string:RXML.Type) opt_arg_types = ([
   "store":RXML.t_text(RXML.PEnt),
   "maxsize":RXML.t_text(RXML.PEnt),
   "maxmem":RXML.t_text(RXML.PEnt),
   "maxcount":RXML.t_text(RXML.PEnt),
   "maxage":RXML.t_text(RXML.PEnt),
   "expires":RXML.t_text(RXML.PEnt),
   "autorefresh":RXML.t_text(RXML.PEnt),
   "nocache":RXML.t_text(RXML.PEnt),
  ]);

  class Frame
  {
    inherit RXML.Frame;

    int do_iterate;
    RXML.PCode evaled_content;

    int maxmem, maxage, maxcount, maxsize;
    string key;
    MemCache cache;
    array cnt;

    array do_enter(RequestID id) {
      do_iterate= 1;
      string store=args->store||"";
      if(args->maxcount=="0") {
        m_delete(caches,store);
        m_delete(hitcount,store);
      }
      if(args->nocache||args->maxage=="0"||args->maxcount=="0") {
	return 0;
      }
      key=args->key;
      maxmem=(int)args->maxmem;
      maxage=(int)args->maxage;
      maxcount=(int)args->maxcount;
      maxsize=(int)args->maxsize||query("maxsize");
      cache=caches[store];
      if(!cache) {
        caches[store]=cache=MemCache(maxmem||query("maxmem"),
         maxage||query("maxage"), maxcount||query("maxcount"),
         maxsize);
      }
      cnt=hitcount[store];
      if(!cnt)
         hitcount[store]=cnt=({0,0,0,0});
      if(evaled_content = cache[key]) {
        do_iterate= -1;
        return ({evaled_content});
      }
      return 0;
    }

    array do_return(RequestID id) {
      result += content||"";
      if(do_iterate>0
       && !args->nocache && args->maxage!="0" && args->maxcount!="0") {
        if(!maxsize || maxsize>=sizeof(result)) {
          if(maxmem||maxage||maxcount||(int)args->maxsize)
            cache->setparameters(maxmem, maxage, maxcount, maxsize);
          int expires=(int)args->expires;
          int autorefresh=(int)args->autorefresh;
          cnt[2]++; cnt[3]+=sizeof(result);
          cache->store(key, evaled_content, expires, sizeof(result),
	   autorefresh);
        }
      }
      else if(cnt)
        cnt[0]++, cnt[1]+=sizeof(result);
      return 0;
    }
  }
}

// --------------------- Documentation -----------------------

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=([
"datacache":#"<desc type='cont'><p><short hide='hide'>
 Controlled caching.</short>The &lt;datacache&gt;
 tag allows one store and retrieve data in a cache.</p>
</desc>

<attr name='key' value='string'><p>
 Key used to store and retrieve the cached data.</p>
</attr>

<attr name='store' value='string'><p>
 Name of the datastore, defaults to an empty store-name.  There can be
 as many stores as you like.</p>
</attr>

<attr name='expires' value='int'><p>
 Unix timestamp when this entry should expire.</p>
</attr>

<attr name='autorefresh' value='int'><p>
 Number of seconds this entry should remain valid after the last
 access.</p>
</attr>

<hr />

<h3>The following attributes adjust the defaults for the store referred to</h3>

<attr name='maxsize' value='int'><p>
 Elements larger than this, will not be stored in the cache.</p>
</attr>

<attr name='maxmem' value='int'><p>
 When the cache size rises above this level in one cachestore,
 the oldest entries will be expired.</p>
</attr>

<attr name='maxcount' value='int'><p>
 When the number of cache entries in one cachestore rises above this
 level, the oldest entries will be expired.  Setting this to zero,
 will purge the store.</p>
</attr>

<attr name='maxage' value='int'><p>
 Entries older than this many seconds, will be expired.
 Setting this to zero is identical to specifying the nocache attribute.
 </p>
</attr>

<attr name='nocache'><p>
 If set, no caching will take place, nor will existing cache entries be
 expired.</p>
 </p>
</attr>
",
    ]);
#endif
