
#include <roxen.h>
//<locale-token project="admin_tasks">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("admin_tasks",X,Y)

constant action = "status";

string name= LOCALE(59, "Cache status");
string doc = LOCALE(60, 
		    "Show information about the main memory cache in Roxen");

string format_hit_rate (int|float hits, int|float misses)
{
  if ((hits == 0 || hits == 0.0) && (misses == 0 || misses == 0.0))
    return "-";
  return sprintf ("%.2f%%", hits * 100.0 / (hits + misses));
}

string parse( RequestID id )
{
  string res =
    "<p><font size='+1'><b>"+
    LOCALE(61, "WebServer Memory Cache")+
    "</b></font></p>\n"
    "<input type='hidden' name='action' value='cachestatus.pike' />"
    "<p><cf-refresh/> <cf-cancel href='?class=&form.class;'/></p>";

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
	"<table cellpadding=\"3\" cellspacing=\"0\""
	"       style='border-width: 1px; border-style: solid;'>\n"
	"<tr align='center' bgcolor=\"&usr.obox-titlebg;\""
	"    style='white-space: nowrap;'>"
	"<th align=\"left\">"+LOCALE(62, "Cache")+"</th>"
	"<th>"+LOCALE(295, "Entries")+"</th>"
	"<th>"+LOCALE(0, "Lookups")+"</th>"
	"<th>"+LOCALE(67, "Hit rate")+"</th>"
	"<th>"+LOCALE(64, "Size")+"</th>"
#ifdef RAMCACHE_STATS
	"<th>"+LOCALE(0, "Byte HR")+"</th>"
	"<th>"+LOCALE(0, "Create cost")+"</th>"
	"<th>"+LOCALE(0, "Cost HR")+"</th>"
#endif
	"</tr>\n";

      int got_caches;
      int tot_count, tot_size;
      int tot_hits, tot_misses;
#ifdef RAMCACHE_STATS
      int tot_byte_hits, tot_byte_misses;
      int|float tot_cost_hits, tot_cost_misses, tot_cost;
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

	got_caches = 1;

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
	  foreach (cache.cache_entries (cache_name);; cache.CacheEntry entry)
	    cost += entry->cost;
	  grp_cost += cost;
#endif
	}

	table +=
	  "<tr align=\"right\" bgcolor=\"" +
	  (row/3%2?"&usr.fade1;":"&usr.obox-bodybg;") + "\">"
	  "<td align=\"left\">" +
	  Roxen.html_encode_string (trans[group_name] || group_name) + "</td>"
	  "<td>" + grp_count + "</td>"
	  "<td>" + (grp_hits + grp_misses) + "</td>"
	  "<td>" + format_hit_rate (grp_hits, grp_misses) + "</td>"
	  "<td style='white-space: nowrap;'>" +
	  Roxen.sizetostring (grp_size) + "</td>"
#ifdef RAMCACHE_STATS
	  "<td>" + format_hit_rate (grp_byte_hits, grp_byte_misses) + "</td>"
	  "<td>" + mgr->format_cost (grp_cost) + "</td>"
	  "<td>" + format_hit_rate (grp_cost_hits, grp_cost_misses) + "</td>"
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

      if (got_caches)
	res += table +
	  "<tr align=\"right\" bgcolor=\"&usr.fade2;\">"
	  "<td align=\"left\"><b>"+LOCALE(178, "Total")+"</b></td>"
	  "<td>" + tot_count + "</td>"
	  "<td>" + (tot_hits + tot_misses) + "</td>"
	  "<td>" + format_hit_rate (tot_hits, tot_misses) + "</td>"
	  "<td style='white-space: nowrap;'>" +
	  Roxen.sizetostring (tot_size) + "</td>"
#ifdef RAMCACHE_STATS
	  "<td>" + format_hit_rate (tot_byte_hits, tot_byte_misses) + "</td>"
	  "<td>" + mgr->format_cost (tot_cost) + "</td>"
	  "<td>" + format_hit_rate (tot_cost_hits, tot_cost_misses) + "</td>"
#endif
	  "</tr>\n"
	  "</table>\n";
    }

#ifdef RAMCACHE_STATS
  res += "<font size='-1'>" + LOCALE(0, #"\
<p><i>Byte HR</i> is the byte hit rate, i.e. every hit and miss is
weighted with the size of the entry. <i>Cost HR</i> weights each entry
with its cost according to the cost metric of the cache manager. Note
that both use the approximation that every cache miss is followed by
the addition of a new cache entry.</p>\n") + "</font>";
#endif

#else  // !NEW_RAM_CACHE

  res +=
    "<table cellpadding=\"3\" cellspacing=\"0\""
    "       style='border-width: 1px; border-style: solid;'>\n"
    "<tr bgcolor=\"&usr.obox-titlebg;\">"
    "<th align=\"left\">"+LOCALE(62, "Class")+"</th>"
    "<th align=\"right\">"+LOCALE(295, "Entries")+"</th>"
    "<th align=\"right\">"+LOCALE(64, "Size")+"</th>"
    "<th align=\"right\">"+LOCALE(293, "Hits")+"</th>"
    "<th align=\"right\">"+LOCALE(294, "Misses")+"</th>"
    "<th align=\"right\">"+LOCALE(67, "Hit rate")+"</th></tr>\n";

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

  int i, totale, totalm, totalh, totalt;
  foreach(sort(indices(c)), string n)
  {
    array ent=c[n];
    res += ("<tr align=\"right\" bgcolor=\"" + (i/3%2?"&usr.fade1;":"&usr.obox-bodybg;") +
	    "\"><td align=\"left\">"+ n +"</td><td>"+ ent[0] + "</td><td>" + Roxen.sizetostring(ent[3])
	    + "</td><td>" + ent[1] + "</td><td>" + (ent[2]-ent[1]) + "</td>");
    if(ent[2])
      res += "<td>" + (ent[1]*100)/ent[2] + "%</td>";
    else
      res += "<td>0%</td>";
    res += "</tr>";
    totale += ent[0];
    totalm += ent[3];
    totalh += ent[1];
    totalt += ent[2];
    i++;
  }
  res += "<tr align=\"right\" bgcolor=\"&usr.fade2;\">"
    "<td align=\"left\"><b>"+LOCALE(178, "Total")+"</b></td><td>" +
    totale + "</td><td>" + Roxen.sizetostring(totalm) + "</td>" +
    "<td>" + totalh + "</td><td>" + (totalt-totalh) + "</td>";
  if(totalt)
    res += "<td>"+(totalh*100)/totalt+"%</td>";
  else
    res += "<td>0%</td>";

  res += "</tr></table>\n";

#endif	// !NEW_RAM_CACHE

  res += (roxen->query("cache")? "<br />" + roxen->get_garb_info():"");


  // ---

  mapping ngc = cache->ngc_status();

  if(sizeof(ngc)) {
    res += "<p><font size='+1'><b>"+
      LOCALE(87, "Non-garbing Memory Cache")+"</b></font></p>\n"
      "<table cellpadding=\"3\" cellspacing=\"0\""
      "       style='border-width: 1px; border-style: solid;'>\n"
      "<tr bgcolor=\"&usr.obox-titlebg;\">"
      "<th align=\"left\">"+LOCALE(62, "Class")+"</th>"
      "<th align=\"right\">"+LOCALE(295, "Entries")+"</th>"
      "<th align=\"right\">"+LOCALE(64, "Size")+"</th></tr>";

    int i, totale, totalm;
    foreach(sort(indices(ngc)), string name) {
      array ent = ngc[name];
      res += ("<tr align=\"right\" bgcolor=\"" +
	      (i/3%2?"&usr.fade1;":"&usr.obox-bgcolor;") +
	      "\"><td align=\"left\">"+ name +"</td><td>"+ ent[0] +
	      "</td><td>" +
	      Roxen.sizetostring(ent[1]) + "</td></tr>");
      totale += ent[0];
      totalm += ent[1];
      i++;
    }

    res += "<tr align=\"right\" bgcolor=\"&usr.fade2;\">"
      "<td align=\"left\"><b>"+LOCALE(178, "Total")+"</b></td><td>" +
      totale + "</td><td>" + Roxen.sizetostring(totalm) + "</td></tr>\n"
      "</table>\n";
  }

  // ---

  mapping l=Locale.cache_status();
  res += "<p><font size='+1'><b>"+LOCALE(71, "Locale Cache")+"</b></font></p>"
    "<table cellpadding=\"3\" cellspacing=\"0\""
    "       style='border-width: 1px; border-style: solid;'>\n"
    "<tr>\n"
    "<td>"+LOCALE(72, "Used languages:")+"</td><td>"+l->languages+"</td></tr>\n"
    "<tr><td>"+LOCALE(73, "Registered projects:")+"</td><td>"+l->reg_proj+"</td></tr>\n"
    "<tr><td>"+LOCALE(74, "Loaded project files:")+"</td><td>"+l->load_proj+"</td></tr>\n"
    "<tr><td>"+LOCALE(75, "Current cache size:")+"</td><td>"+Roxen.sizetostring(l->bytes)+"</td></tr>\n"
    "</table>\n";

  return res;
}
