
#include <roxen.h>
//<locale-token project="admin_tasks">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("admin_tasks",X,Y)

constant action = "status";

string name= LOCALE(59, "Cache status");
string doc = LOCALE(60, 
		    "Show information about the main memory cache in Roxen");

string format_hit_rate (int|float hits, int|float misses)
{
  float res = 0.0;
  catch (res = hits * 100.0 / (hits + misses));
  return sprintf ("%.2f%%", res);
}

// Should use external css instead. I'm lazy..
#define TABLE_ATTRS							\
  "style='border-collapse: collapse; white-space: nowrap;'"
#define HDR_TR_ATTRS							\
  "style='text-align: center; border-bottom: 1px solid #666;'"
#define BODY_TR_ATTRS(ROW)						\
  "style='text-align: right; " +					\
    (ROW ? "border-top: 2px solid transparent;" : "") + "'"
#define FTR_TR_ATTRS							\
  "style='text-align: right; border-top: 1px solid #666;'"
#define FIRST_CELL							\
  "style='text-align: left; padding: 0;'"
#define REST_CELLS							\
  "style='white-space: nowrap; padding: 0 0 0 1ex;'"

#define DESCR_ROW(ROW, DESCR, VALUE)					\
  "<tr " BODY_TR_ATTRS (ROW) ">"					\
    "<td " FIRST_CELL ">" + (DESCR) + "</td>"				\
    "<td " REST_CELLS ">" + (VALUE) + "</td>"				\
    "</tr>"

string parse( RequestID id )
{
  string res =
    "<input type='hidden' name='action' value='cachestatus.pike' />"
    "<p><cf-refresh/> <cf-cancel href='?class=&form.class;'/></p>\n"
    "<h3>"+
    LOCALE(61, "WebServer Memory Cache")+
    "</h3>\n"
    "<p><a href='/global_settings/?section=Cache'>" +
    LOCALE(0, "Configure cache settings") + "</a></p>\n";

#ifdef NEW_RAM_CACHE

  mapping(cache.CacheManager:mapping(string:cache.CacheStats)) stats =
    cache.cache_stats();

  mapping trans = ([
    "supports":LOCALE(68,"Supports database"),
    "fonts":LOCALE(69,"Fonts"),
    "hosts":LOCALE(70,"DNS"),
  ]);

  foreach (cache.cache_managers, cache.CacheManager mgr)
    if (mapping(string:cache.CacheStats) caches = stats[mgr]) {
      res +=
	"<p><b>" + (LOCALE(0, "Cache manager: ") +
		    Roxen.html_encode_string (mgr->name)) + "</b></p>\n"
	"<p>" + mgr->doc + "</p>\n";

      string table =
	"<table " TABLE_ATTRS ">\n"
	"<tr " HDR_TR_ATTRS ">"
	"<th " FIRST_CELL ">"+LOCALE(62, "Cache")+"</th>"
	"<th " REST_CELLS ">"+LOCALE(295, "Entries")+"</th>"
	"<th " REST_CELLS ">"+LOCALE(0, "Lookups")+"</th>"
	"<th " REST_CELLS ">"+LOCALE(67, "Hit rate")+"</th>"
	"<th " REST_CELLS ">"+LOCALE(64, "Size")+"</th>"
	"<th " REST_CELLS ">"+LOCALE(0, "Size/entry")+"</th>"
#ifdef RAMCACHE_STATS
	"<th " REST_CELLS ">"+LOCALE(0, "Byte HR")+"</th>"
	"<th " REST_CELLS ">"+LOCALE(0, "Create cost")+"</th>"
	"<th " REST_CELLS ">"+LOCALE(0, "Cost/entry")+"</th>"
	"<th " REST_CELLS ">"+LOCALE(0, "Cost HR")+"</th>"
#endif
	"</tr>\n";

      int num_caches;
      int tot_count, tot_size;
      int tot_hits, tot_misses;
#ifdef RAMCACHE_STATS
      int tot_byte_hits, tot_byte_misses;
      int|float tot_cost_hits, tot_cost_misses, tot_cost;
#ifdef DEBUG_CACHE_MANAGER
      int min_size = Int.NATIVE_MAX, max_size;
      int|float min_cost = Float.MAX, max_cost;
      int|float min_value = Float.MAX, max_value;
      int|float min_pval = Float.MAX, max_pval;
#endif
#endif

      mapping(string:array(string)) cache_groups = ([]);
      foreach (caches; string cache_name;) {
	sscanf (cache_name, "%[^:]", string group_name);
	cache_groups[group_name] += ({cache_name});
      }

      mapping(string:string) name_trans =
	mkmapping (indices (cache_groups), indices (cache_groups));
      foreach (trans; string name; string trans)
	if (m_delete (name_trans, name))
	  name_trans[trans] = name;

      foreach (sort (indices (name_trans)); int row; string trans_name) {
	string group_name = name_trans[trans_name];

	num_caches++;

	int grp_count, grp_size;
	int grp_hits, grp_misses;
#ifdef RAMCACHE_STATS
	int grp_byte_hits, grp_byte_misses;
	int|float grp_cost_hits, grp_cost_misses, grp_cost;
#endif

	foreach (cache_groups[group_name], string cache_name) {
	  cache.CacheStats st = caches[cache_name];

	  grp_count += st->count;
	  grp_hits += st->hits;
	  grp_misses += st->misses;
	  grp_size += st->size;
#ifdef RAMCACHE_STATS
	  grp_byte_hits += st->byte_hits;
	  grp_byte_misses += st->byte_misses;
	  grp_cost_hits += st->cost_hits;
	  grp_cost_misses += st->cost_misses;

	  int|float cost;
	  foreach (cache.cache_entries (cache_name);; cache.CacheEntry entry) {
	    int|float c = entry->cost;
	    cost += c;
#ifdef DEBUG_CACHE_MANAGER
	    if (c > max_cost) max_cost = c;
	    if (c < min_cost) min_cost = c;
	    int s = entry->size;
	    if (s > max_size) max_size = s;
	    if (s < min_size) min_size = s;
	    int|float v = entry->value;
	    if (v > max_value) max_value = v;
	    if (v < min_value) min_value = v;
	    v = entry->pval;
	    if (v > max_pval) max_pval = v;
	    if (v < min_pval) min_pval = v;
#endif
	  }
	  grp_cost += cost;
#endif
	}

	table +=
	  "<tr " BODY_TR_ATTRS (row) ">"
	  "<td " FIRST_CELL ">" +
	  Roxen.html_encode_string (trans[group_name] || group_name) + "</td>"
	  "<td " REST_CELLS ">" + grp_count + "</td>"
	  "<td " REST_CELLS ">" + (grp_hits + grp_misses) + "</td>"
	  "<td " REST_CELLS ">" +
	  format_hit_rate (grp_hits, grp_misses) + "</td>"
	  "<td " REST_CELLS ">" +
	  Roxen.sizetostring (grp_size) + "</td>"
	  "<td " REST_CELLS ">" +
	  Roxen.sizetostring (grp_count && grp_size / grp_count) +
	  "</td>"
#ifdef RAMCACHE_STATS
	  "<td " REST_CELLS ">" +
	  format_hit_rate (grp_byte_hits, grp_byte_misses) + "</td>"
	  "<td " REST_CELLS ">" +
	  mgr->format_cost (grp_cost) + "</td>"
	  "<td " REST_CELLS ">" +
	  mgr->format_cost (grp_count && grp_cost / grp_count) + "</td>"
	  "<td " REST_CELLS ">" +
	  format_hit_rate (grp_cost_hits, grp_cost_misses) + "</td>"
#endif
	  "</tr>\n";

	tot_count += grp_count;
	tot_hits += grp_hits;
	tot_misses += grp_misses;
	tot_size += grp_size;
#ifdef RAMCACHE_STATS
	tot_byte_hits += grp_byte_hits;
	tot_byte_misses += grp_byte_misses;
	tot_cost_hits += grp_cost_hits;
	tot_cost_misses += grp_cost_misses;
	tot_cost += grp_cost;
#endif
      }

#if defined (RAMCACHE_STATS) && defined (DEBUG_CACHE_MANAGER)
      if (tot_count) {
	res += "<p>"
	  "Entry size range: " + min_size + " .. " + max_size;
	if (tot_cost)
	  res += "<br />\n"
	    "Entry cost range: " + min_cost + " .. " + max_cost;
	res += "<br />\n"
	  "Entry value range: " + min_value + " .. " + max_value;
	if (min_pval < max_pval)
	  // CM_GreedyDual specific.
	  res += "<br />\n"
	    "Entry priority value range: " + min_pval + " .. " + max_pval +
	    "</p>\n";
      }
#endif

      if (num_caches) {
	res += table;
	if (num_caches > 1)
	  res +=
	    "<tr " FTR_TR_ATTRS ">"
	    "<td " FIRST_CELL "><b>"+LOCALE(178, "Total")+"</b></td>"
	    "<td " REST_CELLS ">" + tot_count + "</td>"
	    "<td " REST_CELLS ">" + (tot_hits + tot_misses) + "</td>"
	    "<td " REST_CELLS ">" +
	    format_hit_rate (tot_hits, tot_misses) + "</td>"
	    "<td " REST_CELLS ">" +
	    Roxen.sizetostring (tot_size) + "</td>"
	    "<td " REST_CELLS ">" +
	    Roxen.sizetostring (tot_count && tot_size / tot_count) +
	    "</td>"
#ifdef RAMCACHE_STATS
	    "<td " REST_CELLS ">" +
	    format_hit_rate (tot_byte_hits, tot_byte_misses) + "</td>"
	    "<td " REST_CELLS ">" +
	    mgr->format_cost (tot_cost) + "</td>"
	    "<td " REST_CELLS ">" +
	    mgr->format_cost (tot_count && tot_cost / tot_count) + "</td>"
	    "<td " REST_CELLS ">" +
	    format_hit_rate (tot_cost_hits, tot_cost_misses) + "</td>"
#endif
	    "</tr>\n";
	res += "</table>\n";
      }
    }

#ifdef RAMCACHE_STATS
  res += "<font size='-1'>" + LOCALE(0, #"\
<p><i>Byte HR</i> is the byte hit rate, i.e. every hit and miss is
weighted with the size of the entry. <i>Cost HR</i> weights each entry
with its cost according to the cost metric of the cache manager. Note
that both use the approximation that every cache miss is followed by
the addition of a new cache entry.</p>\n") + "</font>";
#endif

  res += "<p><b>" + LOCALE(0, "Garbage Collector") + "</b></p>\n";
  if (!cache->last_gc_run)
    res += "<p>" +
      LOCALE(0, "The garbage collector has not run yet.") + "</p>\n";
  else {
    res += "<p>" +
      sprintf (LOCALE(0, "%d seconds since the last garbage collection. "
		      "The following are totals over approximately "
		      "the last hour."),
	       time() - cache->last_gc_run) + "</p>\n"
      "<table " TABLE_ATTRS ">\n"
      DESCR_ROW (0, LOCALE(0, "Time spent in the garbage collector:"),
		 Roxen.format_hrtime ((int) cache->sum_gc_time))
      DESCR_ROW (1, LOCALE(0, "Size of garbage collected invalid entries:"),
		 Roxen.sizetostring ((int) cache->sum_destruct_garbage_size))
      DESCR_ROW (2, LOCALE(0, "Size of garbage collected timed out entries:"),
		 Roxen.sizetostring ((int) cache->sum_timeout_garbage_size))
      "</table>\n";
  }

#else  // !NEW_RAM_CACHE

  res +=
    "<table " TABLE_ATTRS ">\n"
    "<tr " HDR_TR_ATTRS ">"
    "<th " FIRST_CELL ">"+LOCALE(62, "Class")+"</th>"
    "<th " REST_CELLS ">"+LOCALE(295, "Entries")+"</th>"
    "<th " REST_CELLS ">"+LOCALE(64, "Size")+"</th>"
    "<th " REST_CELLS ">"+LOCALE(293, "Hits")+"</th>"
    "<th " REST_CELLS ">"+LOCALE(294, "Misses")+"</th>"
    "<th " REST_CELLS ">"+LOCALE(67, "Hit rate")+"</th></tr>\n";

  mapping c=cache->status();

  mapping trans = ([
    "supports":LOCALE(68,"supportdb"),
    "fonts":LOCALE(69,"Fonts"),
    "hosts":LOCALE(70,"DNS"),
  ]);

  foreach(indices(c), string n)
    if(trans[n]) {
      c[trans[n]]=c[n];
      m_delete(c, n);
    }

  int totale, totalm, totalh, totalt;
  foreach(sort(indices(c)); int row; string n)
  {
    array ent=c[n];
    res += "<tr " BODY_TR_ATTRS (row) ">"
      "<td " FIRST_CELL ">"+ Roxen.html_encode_string (n) +"</td>"
      "<td " REST_CELLS ">"+ ent[0] + "</td>"
      "<td " REST_CELLS ">" + Roxen.sizetostring(ent[3]) + "</td>"
      "<td " REST_CELLS ">" + ent[1] + "</td>"
      "<td " REST_CELLS ">" + (ent[2]-ent[1]) + "</td>";
    if(ent[2])
      res += "<td " REST_CELLS ">" + (ent[1]*100)/ent[2] + "%</td>";
    else
      res += "<td " REST_CELLS ">0%</td>";
    res += "</tr>";
    totale += ent[0];
    totalm += ent[3];
    totalh += ent[1];
    totalt += ent[2];
  }
  res += "<tr " FTR_TR_ATTRS ">"
    "<td " FIRST_CELL "><b>"+LOCALE(178, "Total")+"</b></td>"
    "<td " REST_CELLS ">" + totale + "</td>"
    "<td " REST_CELLS ">" + Roxen.sizetostring(totalm) + "</td>" +
    "<td " REST_CELLS ">" + totalh + "</td>"
    "<td " REST_CELLS ">" + (totalt-totalh) + "</td>";
  if(totalt)
    res += "<td " REST_CELLS ">"+(totalh*100)/totalt+"%</td>";
  else
    res += "<td " REST_CELLS ">0%</td>";

  res += "</tr></table>\n";

#endif	// !NEW_RAM_CACHE

  res += (roxen->query("cache")? "<br />" + roxen->get_garb_info():"");


  // ---

  mapping ngc = cache->ngc_status();

  if(sizeof(ngc)) {
    res += "<br/><h3>"+
      LOCALE(87, "Non-garbing Memory Cache")+"</h3>\n"
      "<table " TABLE_ATTRS ">\n"
      "<tr " HDR_TR_ATTRS ">"
      "<th " FIRST_CELL ">"+LOCALE(62, "Class")+"</th>"
      "<th " REST_CELLS ">"+LOCALE(295, "Entries")+"</th>"
      "<th " REST_CELLS ">"+LOCALE(64, "Size")+"</th></tr>";

    int row, totale, totalm;
    foreach(sort(indices(ngc)); row; string name) {
      array ent = ngc[name];
      res += "<tr " BODY_TR_ATTRS (row) ">"
	"<td " FIRST_CELL ">"+ name +"</td>"
	"<td " REST_CELLS ">"+ ent[0] + "</td>"
	"<td " REST_CELLS ">" + Roxen.sizetostring(ent[1]) + "</td></tr>";
      totale += ent[0];
      totalm += ent[1];
    }

    if (row >= 1)
      res += "<tr " FTR_TR_ATTRS ">"
	"<td " FIRST_CELL "><b>"+LOCALE(178, "Total")+"</b></td>"
	"<td " REST_CELLS ">" + totale + "</td>"
	"<td " REST_CELLS ">" + Roxen.sizetostring(totalm) + "</td></tr>\n";
    res += "</table>\n";
  }

  // ---

  mapping l=Locale.cache_status();
  res += "<br/><h3>"+LOCALE(71, "Locale Cache")+"</h3>"
    "<table " TABLE_ATTRS ">\n"
    DESCR_ROW (0, LOCALE(72, "Used languages:"), l->languages)
    DESCR_ROW (1, LOCALE(73, "Registered projects:"), l->reg_proj)
    DESCR_ROW (2, LOCALE(74, "Loaded project files:"), l->load_proj)
    DESCR_ROW (3, LOCALE(75, "Current cache size:"),
	       Roxen.sizetostring(l->bytes))
    "</table>\n";

  return res;
}
