// $Id$

#include <roxen.h>
//<locale-token project="admin_tasks">LOCALE</locale-token>
#define LOCALE(X,Y)     _STR_LOCALE("admin_tasks",X,Y)

constant action = "status";

string name= LOCALE(59, "Cache status");
string doc = LOCALE(60,
                    "Show information about the main memory cache in Roxen");

#define VALUE_NA "<span class='dimtext'>n/a</span>"

string format_hit_rate (int|float hits, int|float misses)
{
  catch {
    float res = hits * 100.0 / (hits + misses);
    return sprintf ("%.1f%%", res);
  };
  return VALUE_NA;
}

// Should use external css instead. I'm lazy..
#define TABLE_ATTRS                                                     \
  "class='nice narrow'"
#define THEAD_ATTRS                                                     \
  "class='sticky'"
#define HDR_TR_ATTRS                                                    \
  ""
#define BODY_TR_ATTRS(ROW)                                              \
  ""
#define FTR_TR_ATTRS                                                    \
  "class='text-right'"
#define FIRST_CELL                                                      \
  "class='text-left'"
#define REST_CELLS                                                      \
  "class='nowrap text-right'"

#define DESCR_ROW(ROW, DESCR, VALUE)                                    \
  "<tr " BODY_TR_ATTRS (ROW) ">"                                        \
    "<td " FIRST_CELL ">" + (DESCR) + "</td>"                           \
    "<td " REST_CELLS ">" + (VALUE) + "</td>"                           \
    "</tr>"

string parse( RequestID id )
{
  string res =
    "<input type='hidden' name='action' value='cachestatus.pike' />"
    "<h2 class='no-margin-top'>"+
    LOCALE(61, "WebServer Memory Cache")+
    "</h2>\n"
    "<p><cf-refresh/> <cf-cancel href='?class=&form.class;&amp;&usr.set-wiz-id;'/></p>\n"
    "<hr class='section'>"
    "<p><a href='/global_settings/?section=Cache&amp;&usr.set-wiz-id;'>" +
    LOCALE(380, "Configure Cache Settings") + "</a></p>\n";

  mapping(cache.CacheManager:mapping(string:cache.CacheStats)) stats =
    cache.cache_stats();

  mapping trans = ([
    "supports":LOCALE(68,"Supports database"),
    "fonts":LOCALE(69,"Fonts"),
    "hosts":LOCALE(70,"DNS"),
  ]);

  string mgr_summary = "<p>" +
    sprintf (LOCALE(381, #"\
The configured maximum size %s is divided dynamically between the
cache managers based on the usage for the last half hour. If the
caches are not full then all free space is assigned to each one of
them. They will shrink to the configured maximum size as they fill up."),
             "<b>" + Roxen.sizetostring (cache->total_size_limit) + "</b>") +
    "</p>\n"
    "<table " TABLE_ATTRS ">\n"
    "<thead " THEAD_ATTRS ">"
    "<tr " HDR_TR_ATTRS ">"
    "<th " FIRST_CELL ">" + LOCALE(382, "Cache manager") + "</th>"
    "<th " REST_CELLS ">" + LOCALE(64, "Size") + "</th>"
    "<th " REST_CELLS ">" + LOCALE(383, "Size limit") + "</th>"
    "<th " REST_CELLS ">" + LOCALE(384, "Input rate") + "</th>"
    "<th " REST_CELLS ">" + LOCALE(67, "Hit rate") + "</th>"
    "<th " REST_CELLS ">" + LOCALE(385, "Cost HR") + "</th>"
#ifdef DEBUG_CACHE_MANAGER
    "<th " REST_CELLS " colspan='2'>Entry size</th>"
    "<th " REST_CELLS " colspan='2'>Entry cost</th>"
    "<th " REST_CELLS " colspan='2'>Entry value</th>"
    "<th " REST_CELLS " colspan='2'>Entry pri val</th>"
#endif
    "</thead>"
    "</tr>\n";

  string mgr_stats = "";

  foreach (cache.cache_managers; int mgr_idx; cache.CacheManager mgr)
    if (mapping(string:cache.CacheStats) caches = stats[mgr]) {
      mgr_stats +=
        "<h3 class='section'>" + (LOCALE(386, "Cache manager: ") +
                    Roxen.html_encode_string (mgr->name)) + "</h3>"
        "<p>" + mgr->doc + "</p>\n";

      string table =
        "<table " TABLE_ATTRS ">\n"
        "<thead " THEAD_ATTRS ">"
        "<tr " HDR_TR_ATTRS ">"
        "<th " FIRST_CELL ">"+LOCALE(402, "Cache")+"</th>"
        "<th " REST_CELLS ">"+LOCALE(295, "Entries")+"</th>"
        "<th " REST_CELLS ">"+LOCALE(387, "Lookups")+"</th>"
        "<th " REST_CELLS ">"+LOCALE(67, "Hit rate")+"</th>"
        "<th " REST_CELLS ">"+LOCALE(64, "Size")+"</th>"
        "<th " REST_CELLS ">"+LOCALE(388, "Size/entry")+"</th>"
#ifdef CACHE_BYTE_HR_STATS
        "<th " REST_CELLS ">"+LOCALE(389, "Byte HR")+"</th>"
#endif
        "<th " REST_CELLS ">"+LOCALE(390, "Create cost")+"</th>"
        "<th " REST_CELLS ">"+LOCALE(391, "Cost/entry")+"</th>"
        "<th " REST_CELLS ">"+LOCALE(385, "Cost HR")+"</th>"
        "</thead>"
        "</tr>\n";

      int num_caches;
      int tot_count, tot_size;
      int tot_hits, tot_misses;
#ifdef CACHE_BYTE_HR_STATS
      int tot_byte_hits, tot_byte_misses;
#endif
      int|float tot_cost_hits, tot_cost_misses, tot_cost;
#ifdef DEBUG_CACHE_MANAGER
      int min_size = Int.NATIVE_MAX, max_size;
      int|float min_cost = Float.MAX, max_cost;
      int|float min_value = Float.MAX, max_value;
      int|float min_pval = Float.MAX, max_pval;
#endif

      mapping(string:array(string)) cache_groups = ([]);
      // FIXME: The following should be redundant given the
      //        integrated grouping of CacheStats.
      foreach (caches; string cache_name;) {
        sscanf (cache_name, "%[^:]", string group_name);
        cache_groups[group_name] += ({cache_name});
      }

      // FIXME: The following looks broken.
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
#ifdef CACHE_BYTE_HR_STATS
        int grp_byte_hits, grp_byte_misses;
#endif
        int|float grp_cost_hits, grp_cost_misses, grp_cost;

        foreach (cache_groups[group_name], string cache_name) {
          cache.CacheStats st = caches[cache_name];

          grp_count += st->count;
          grp_hits += st->hits;
          grp_misses += st->misses;
          grp_size += st->size;
#ifdef CACHE_BYTE_HR_STATS
          grp_byte_hits += st->byte_hits;
          grp_byte_misses += st->byte_misses;
#endif
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
          Roxen.sizetostring (grp_count && (float) grp_size / grp_count) +
          "</td>"
#ifdef CACHE_BYTE_HR_STATS
          "<td " REST_CELLS ">" +
          format_hit_rate (grp_byte_hits, grp_byte_misses) + "</td>"
#endif
          "<td " REST_CELLS ">" +
          (mgr->has_cost ? mgr->format_cost (grp_cost) : VALUE_NA) + "</td>"
          "<td " REST_CELLS ">" +
          (mgr->has_cost ?
           mgr->format_cost (grp_count && grp_cost / grp_count) : VALUE_NA) +
          "</td>"
          "<td " REST_CELLS ">" +
          (mgr->has_cost ?
           format_hit_rate (grp_cost_hits, grp_cost_misses) : VALUE_NA) + "</td>"
          "</tr>\n";

        tot_count += grp_count;
        tot_hits += grp_hits;
        tot_misses += grp_misses;
        tot_size += grp_size;
#ifdef CACHE_BYTE_HR_STATS
        tot_byte_hits += grp_byte_hits;
        tot_byte_misses += grp_byte_misses;
#endif
        tot_cost_hits += grp_cost_hits;
        tot_cost_misses += grp_cost_misses;
        tot_cost += grp_cost;
      }

      mgr_summary += "<tr " BODY_TR_ATTRS (mgr_idx) ">"
        "<td " FIRST_CELL ">" + Roxen.html_encode_string (mgr->name) + "</td>"
        "<td " REST_CELLS ">" +
        Roxen.sizetostring (tot_size) + "</td>"
        "<td " REST_CELLS ">" +
        Roxen.sizetostring (mgr->total_size_limit) + "</td>"
        "<td " REST_CELLS ">" +
        Roxen.sizetostring (mgr->add_rate) + "/s</td>"
        "<td " REST_CELLS ">" +
        format_hit_rate (mgr->hits, mgr->misses) + "</td>"
        "<td " REST_CELLS ">" +
        (mgr->has_cost ?
         format_hit_rate (mgr->cost_hits, mgr->cost_misses) :
         format_hit_rate (mgr->hits, mgr->misses)) + "</td>"
#ifdef DEBUG_CACHE_MANAGER
        + (tot_count ?
           "<td " REST_CELLS ">" +
           Roxen.sizetostring (min_size) + " ..</td>"
           "<td " REST_CELLS " align='left'>" +
           Roxen.sizetostring (max_size) + "</td>" +
           (mgr->has_cost ?
            "<td " REST_CELLS ">" +
            (floatp (min_cost) ? sprintf ("%.3g", min_cost) : min_cost) +
            " ..</td>" +
            "<td " REST_CELLS " align='left'>" +
            (floatp (max_cost) ? sprintf ("%.3g", max_cost) : max_cost) +
            "</td>" :
            "<td " REST_CELLS " colspan='2' align='center'>" VALUE_NA "</td>") +
           "<td " REST_CELLS ">" +
           (floatp (min_value) ? sprintf ("%.3g", min_value) : min_value) +
           " ..</td>" +
           "<td " REST_CELLS " align='left'>" +
           (floatp (max_value) ? sprintf ("%.3g", max_value) : max_value) +
           "</td>"
           "<td " REST_CELLS ">" +
           (floatp (min_pval) ? sprintf ("%.3g", min_pval) : min_pval) +
           " ..</td>" +
           "<td " REST_CELLS " align='left'>" +
           (floatp (max_pval) ? sprintf ("%.3g", max_pval) : max_pval) +
           "</td>" :
           "<td " REST_CELLS " colspan='8'></td>") +
#endif
        "</tr>\n";

      if (num_caches) {
        mgr_stats += table;
        if (num_caches > 1)
          mgr_stats +=
            "<tfoot><tr " FTR_TR_ATTRS ">"
            "<td " FIRST_CELL "><b>"+LOCALE(178, "Total")+"</b></td>"
            "<td " REST_CELLS ">" + tot_count + "</td>"
            "<td " REST_CELLS ">" + (tot_hits + tot_misses) + "</td>"
            "<td " REST_CELLS ">" +
            format_hit_rate (tot_hits, tot_misses) + "</td>"
            "<td " REST_CELLS ">" +
            Roxen.sizetostring (tot_size) + "</td>"
            "<td " REST_CELLS ">" +
            Roxen.sizetostring (tot_count && (float) tot_size / tot_count) +
            "</td>"
#ifdef CACHE_BYTE_HR_STATS
            "<td " REST_CELLS ">" +
            format_hit_rate (tot_byte_hits, tot_byte_misses) + "</td>"
#endif
            "<td " REST_CELLS ">" +
            (mgr->has_cost ? mgr->format_cost (tot_cost) : VALUE_NA) + "</td>"
            "<td " REST_CELLS ">" +
            (mgr->has_cost ?
             mgr->format_cost (tot_count && tot_cost / tot_count) : VALUE_NA) +
            "</td>"
            "<td " REST_CELLS ">" +
            (mgr->has_cost ?
             format_hit_rate (tot_cost_hits, tot_cost_misses) : VALUE_NA) + "</td>"
            "</tr></tfoot>\n";
        mgr_stats += "</table>\n";
      }
    }

  mgr_stats += "<p class='small'>" +
    LOCALE(392, #"\
<i>Cost HR</i> is the cost hit rate, i.e. every hit and miss is
weighted with the cost for each entry according to the cost metric of
the cache manager. Note that it uses the approximation that every
cache miss is followed by the addition of a new cache entry.") +
    "</p>\n";

  mgr_summary += "</table>\n";

  res += mgr_summary + mgr_stats;

  res += "<h4>" + LOCALE(393, "Garbage Collector") + "</h4>\n";
  if (!cache->last_gc_run)
    res += "<p>" +
      LOCALE(394, "The garbage collector has not run yet.") + "</p>\n";
  else {
    res += "<p>" +
      sprintf (LOCALE(395, "%d seconds since the last garbage collection. "
                      "The following statistics are over approximately "
                      "the last hour."),
               time() - cache->last_gc_run) + "</p>\n"
      "<table class='nice narrow no-th'>\n"
      "<tr " BODY_TR_ATTRS (0) ">"
      "<td " FIRST_CELL ">" +
      LOCALE(396, "Time spent in the garbage collector:") + "</td>"
      "<td " REST_CELLS " colspan='3'>" +
      Roxen.format_hrtime ((int) cache->sum_gc_time) + "</td>"
      "</tr>"
      "<tr " BODY_TR_ATTRS (1) ">"
      "<td " FIRST_CELL ">" +
      LOCALE(397, "Size of garbage collected entries:") + "</td>"
      "<td " REST_CELLS ">" +
      Roxen.sizetostring (cache->sum_destruct_garbage_size) + " " +
      LOCALE(398, "stale") + " +</td>"
      "<td " REST_CELLS ">" +
      Roxen.sizetostring (cache->sum_timeout_garbage_size) + " " +
      LOCALE(399, "timed out") + " =</td>"
      "<td " REST_CELLS ">" +
      Roxen.sizetostring (cache->sum_destruct_garbage_size +
                          cache->sum_timeout_garbage_size) + "</td>"
      "</tr>"
      "<tr " BODY_TR_ATTRS (1) ">"
      "<td " FIRST_CELL ">" +
      LOCALE(400, "Garbage collection ratio:") + "</td>"
      "<td " REST_CELLS ">" +
      sprintf ("%.2f%%", cache->avg_destruct_garbage_ratio * 100.0) + " " +
      LOCALE(398, "stale") + " +</td>"
      "<td " REST_CELLS ">" +
      sprintf ("%.2f%%", cache->avg_timeout_garbage_ratio * 100.0) + " " +
      LOCALE(399, "timed out") + " =</td>"
      "<td " REST_CELLS ">" +
      sprintf ("%.2f%%", (cache->avg_destruct_garbage_ratio +
                          cache->avg_timeout_garbage_ratio) * 100.0) + "</td>"
      "</tr>"
      "</table>\n";
  }

  res += (roxen->query("cache")? "<br />" + roxen->get_garb_info():"");


  // ---

  mapping ngc = cache->ngc_status();

  if(sizeof(ngc)) {
    res += "<br><h3 class='section'>"+
      LOCALE(87, "Non-garbing Memory Cache")+"</h3>\n"
      "<table " TABLE_ATTRS ">\n"
      "<thead>"
      "<tr " HDR_TR_ATTRS ">"
      "<th " FIRST_CELL ">"+LOCALE(62, "Class")+"</th>"
      "<th " REST_CELLS ">"+LOCALE(295, "Entries")+"</th>"
      "<th " REST_CELLS ">"+LOCALE(64, "Size")+"</th></tr>"
      "</thead>";

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
      res +=
        "<tfoot>"
        "<tr " FTR_TR_ATTRS ">"
        "<td " FIRST_CELL "><b>"+LOCALE(178, "Total")+"</b></td>"
        "<td " REST_CELLS ">" + totale + "</td>"
        "<td " REST_CELLS ">" + Roxen.sizetostring(totalm) + "</td></tr>"
        "</tfoot>";
    res += "</table>\n";
  }

  // ---

  {
    int tot_entries = 0;
    int tot_hits = 0;
    int tot_misses = 0;
    int tot_current_size = 0;
    int tot_max_size = 0;

    string prot_cache_desc =
      "<p>" +
      LOCALE(422, "RAM-based cache per configuration that stores "
             "commonly requested files. Note that entries here don't "
             "count toward the aforementioned size limit for RAM caches in "
             "general, but instead is bound by a specific setting in each "
             "configuration.") +
      "</p>";

    res +=
      "<br/><h3 class='section'>" + LOCALE(423, "Protocol Cache") + "</h3>" +
      prot_cache_desc +
      "<table " TABLE_ATTRS ">\n"
      "<thead>"
      "<tr " HDR_TR_ATTRS ">"
      "<th " FIRST_CELL ">" + LOCALE(424, "Configuration") + "</th>"
      "<th " REST_CELLS ">" + LOCALE(295, "Entries") + "</th>"
      "<th " REST_CELLS ">" + LOCALE(387, "Lookups") + "</th>"
      "<th " REST_CELLS ">" + LOCALE(67, "Hit rate") + "</th>"
      "<th " REST_CELLS ">" + LOCALE(64, "Size") + "</th>"
      "<th " REST_CELLS ">" + LOCALE(388, "Size/entry") + "</th>"
      "<th " REST_CELLS ">" + LOCALE(425, "Max file size") + "</th>"
      "<th " REST_CELLS ">" + LOCALE(426, "Max size") + "</th>"
      "</tr>"
      "</thead>";

    array(Configuration) configs = roxen->configurations;
    string wiz_id =
      (id->real_variables->_roxen_wizard_id || ({ "" }) )[0];
    string wiz_quoted = Roxen.html_encode_string(wiz_id || "");
    sort(configs->name, configs);
    foreach (configs; int row; Configuration c) {
      string conf_link =
        "<a href='../sites/site.html/" +
        Roxen.http_encode_url(c->name) +
        "/?section=Cache&_roxen_wizard_id=" + wiz_quoted + "'>" +
        Roxen.html_encode_string(c->query_name()) +
        "</a>";
      mapping stats = c->datacache && c->datacache->get_cache_stats();
      if (!stats)
        continue;
      int lookups = stats->hits + stats->misses;
      string hit_rate = format_hit_rate(stats->hits, stats->misses);
      string entry_size =
        stats->entries ?
        Roxen.sizetostring(1.0 * stats->current_size / stats->entries) :
        VALUE_NA;
      res +=
        "<tr " BODY_TR_ATTRS (row) ">"
        "<td " FIRST_CELL ">" + conf_link + "</td>"
        "<td " REST_CELLS ">" + stats->entries + "</td>"
        "<td " REST_CELLS ">" + lookups + "</td>"
        "<td " REST_CELLS ">" + hit_rate + "</td>"
        "<td " REST_CELLS ">" + Roxen.sizetostring(stats->current_size) + "</td>"
        "<td " REST_CELLS ">" + entry_size + "</td>"
        "<td " REST_CELLS ">" + Roxen.sizetostring(stats->max_file_size) + "</td>"
        "<td " REST_CELLS ">" + Roxen.sizetostring(stats->max_size) + "</td>"
        "</tr>";

      //  Aggregate stats
      tot_entries += stats->entries;
      tot_hits += stats->hits;
      tot_misses += stats->misses;
      tot_current_size += stats->current_size;
      tot_max_size += stats->max_size;
    }

    res +=
      "<tr " FTR_TR_ATTRS ">"
      "<td " FIRST_CELL "><b>" + LOCALE(178, "Total") + "</b></td>"
      "<td " REST_CELLS ">" + tot_entries + "</td>"
      "<td " REST_CELLS ">" + (tot_hits + tot_misses) + "</td>"
      "<td " REST_CELLS ">" + format_hit_rate(tot_hits, tot_misses) + "</td>"
      "<td " REST_CELLS ">" + Roxen.sizetostring(tot_current_size) + "</td>"
      "<td " REST_CELLS ">" +
      (tot_entries ?
       Roxen.sizetostring((float) tot_current_size / tot_entries) : VALUE_NA) +
      "</td>"
      "<td " REST_CELLS ">" VALUE_NA "</td>"
      "<td " REST_CELLS ">" + Roxen.sizetostring(tot_max_size) + "</td>"
      "</tr>"
      "</table>";
  }

  // ---

  mapping l=Locale.cache_status();
  res += "<br/><h3 class='section'>"+LOCALE(71, "Locale Cache")+"</h3>"
    "<table class='nice narrow no-th'>\n"
    DESCR_ROW (0, LOCALE(72, "Used languages:"), l->languages)
    DESCR_ROW (1, LOCALE(73, "Registered projects:"), l->reg_proj)
    DESCR_ROW (2, LOCALE(74, "Loaded project files:"), l->load_proj)
    DESCR_ROW (3, LOCALE(75, "Current cache size:"),
               Roxen.sizetostring(l->bytes))
    "</table>\n";

  return res;
}
