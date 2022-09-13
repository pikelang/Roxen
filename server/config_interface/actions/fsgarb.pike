//
// "Globals"/"Filesystem GC".
//
// 2013-09-20 Henrik Grubbstr�m
//

#include <config.h>
#include <roxen.h>
//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

constant action="status";

string name = LOCALE(1093, "Filesystem garbage collector status");
string doc  =
  LOCALE(1094, "Show the status for the filesystem garbage collectors.");

string fill_color = "#a6baf3";
string bg_color = "#e9eefc";

string format_time(int t)
{
  string res;
  foreach(({ ({ 604800, LOCALE(1095, "1 week"), LOCALE(1096, "%d weeks") }),
	     ({ 86400, LOCALE(1097, "1 day"), LOCALE(1098, "%d days") }),
	     ({ 3600, LOCALE(1099, "1 hour"), LOCALE(1100, "%d hours") }),
	     ({ 60, LOCALE(1101, "1 minute"), LOCALE(1102, "%d minutes") }),
	  }), [ int unit, string singular, string plural ]) {
    if (t < unit) continue;
    int c = t/unit;
    string frag;
    if (c == 1) frag = singular;
    else frag = sprintf(plural, c);
    if (res) res += " " + frag;
    else res = frag;
    t -= c * unit;
  }
  if (!res) return LOCALE(1103, "none");
  return res;
}

// Linear histogram
string lin_histogram(string|object title, int num_buckets,
		     array(int) value_set, int max)
{
  int num_files = sizeof(value_set) || 1;
  max++;

  // Adjust to a reasonably even bucket size.
  int bsize = max / num_buckets;
  if (max > bsize * num_buckets) bsize++;
  int threshold_found;
  foreach(({ 604800, 86400, 3600, 60, 1 }), int quanta) {
    if (bsize <= quanta) continue;
    if (!threshold_found) {
      threshold_found = 1;
      continue;
    }
    int rest = bsize % quanta;
    if (rest) bsize += quanta - rest;
    break;
  }
  max = bsize * num_buckets;

  array(int) buckets = allocate(num_buckets);
  foreach(value_set, int v) {
    int b = (v * num_buckets)/max;
    if (b < 0) b = 0;
    if (b >= num_buckets) b = num_buckets - 1;
    buckets[b]++;
  }

  int max_height = 60;
  int max_width = 0;
  int x_pos = 0;
  int y_pos = 0;
  string res;

  foreach(buckets; int bno; int count) {
    int height = (count*max_height)/num_files;
    int min_val = (bno * max) / num_buckets;
    int max_val = ((bno + 1) * max) / num_buckets - 1;
    float percent = ((float)count/(float)num_files)*100;

    // x_pos = horizontal pos of bar, starting point: 0
    // y_pos = vertical pos of bar, origin at upper left corner
    // fill-color: #808080 | #f2f1eb
    y_pos = max_height - height;
    res += sprintf(LOCALE(1104, "<rect x='%d' y='%d'"
			     " width='10' height='%d'"
			     " style='fill:%s;'>\n"
			     "  <title>%s: %s - %s\n%f&#37; (%d)</title>\n"
			     "</rect>\n"
			     "<rect x='%d' y='0'"
			     " width='10' height='%d'"
			     " style='fill:%s;'>\n"
			     "  <title>%s: %s - %s\n%f&#37; (%d)</title>\n"
			     "</rect>\n"),
		   x_pos, y_pos, height, fill_color,
		   Roxen.html_encode_string(title),
		   format_time(min_val), format_time(max_val+1), percent, count,
		   x_pos, y_pos, bg_color,
		   Roxen.html_encode_string(title),
		   format_time(min_val), format_time(max_val+1), percent, count);

    x_pos = x_pos + 12;
    max_width = max_width + 12;
  }

  // Using svg
  return sprintf("<svg width='%d' height='%d'"
		 "     viewPort='0 0 %d %d' version='1.1'"
		 "     xmlns='http://www.w3.org/2000/svg'>",
		 max_width, max_height,
		 max_width, max_height) + res + "</svg>";
}

// Exponential histogram
string exp_histogram(string|object title, int num_buckets,
		     array(int) value_set, int max)
{
  sort(value_set);
  int chunk_sz = 1024;
  int bucket_max = 1024;
  mapping(int:int) buckets = ([]);

  buckets[bucket_max] = 0;
  while (sizeof(buckets) < num_buckets) {
    bucket_max *= 2;
    buckets[bucket_max] = 0;
  }

  int bm = 1024;
  foreach(value_set, int val) {
    while (val > bm) {
      bm *= 2;
    }
    if (bm > bucket_max) {
      buckets[bucket_max]++;
    } else {
      buckets[bm]++;
    }
  }

  int max_height = 60;
  int max_width = 0;
  int min = 0;
  int x_pos = 0;
  int y_pos = 0;
  string res;

  foreach(sort(indices(buckets)), int sz) {
    int count = buckets[sz];
    if (sz == bucket_max && bm > bucket_max) sz = bm;
    int max = sz / chunk_sz; // part in KB
    int height = (count*max_height)/(sizeof(value_set) || 1);
    float percent = ((float)count/(float)(sizeof(value_set)||1))*100;


    // x_pos = horizontal pos of bar, starting point: 0
    // y_pos = vertical pos of bar, origin at upper left corner
    y_pos = max_height - height;
    res += sprintf(LOCALE(1068, "<rect x='%d' y='%d'"
			     " width='10' height='%d'"
			     " style='fill:%s;'>\n"
			     "  <title>%s: %d - %d KB\n%f&#37; (%d)</title>\n"
			     "</rect>\n"
			     "<rect x='%d' y='0'"
			     " width='10' height='%d'"
			     " style='fill:%s;'>\n"
			     "  <title>%s: %d - %d KB\n%f&#37; (%d)</title>\n"
			     "</rect>\n"),
		   x_pos, y_pos, height, fill_color,
		   Roxen.html_encode_string(title), min, max, percent, count,
		   x_pos, y_pos, bg_color,
		   Roxen.html_encode_string(title), min, max, percent, count);

    min = max; // sz
    x_pos = x_pos + 12;
    max_width = max_width + 12;
  }

  // Using svg
  return sprintf("<svg width='%d' height='%d'"
		 "     viewPort='0 0 %d %d' version='1.1'"
		 "     xmlns='http://www.w3.org/2000/svg'>",
		 max_width, max_height,
		 max_width, max_height) + res + "</svg>";
}

string parse(RequestID id)
{
#if constant(roxen.register_fsgarb)
  //  Sort according to config, module and path
  array(string) garb_sort_keys = ({ });
  array(object/*(roxen.FSGarb)*/) garbs = values(roxen->fsgarbs);
  foreach (garbs, object/*(roxen.FSGarb)*/ g) {
    RoxenModule mod = Roxen.get_module(g->modid);
    Configuration conf = mod && mod->my_configuration();
    garb_sort_keys += ({ (conf ? conf->name : "") + "|" +
                         (mod ? Roxen.get_modfullname(mod) : g->modid) + "|" +
                         g->root });
  }
  sort(garb_sort_keys, garbs);

  int size_unit = 1024;
  string res = "";

#ifdef DISABLE_FSGARB
  res = "<p><font color='&usr.warncolor;'><img src='&usr.err-2;' />&nbsp;<b>" +
    LOCALE(0, "The filesystem garbage collector is disabled.") +
    "</b></font></p>\n\n";
#endif

  string modid;
  foreach(garbs, object/*(roxen.FSGarb)*/ g) {

    // werror("FSGARG DEBUG object g: %O\n", g);

    if (g->modid != modid) {
      if (modid) {
	res +=
	  "    </table>\n"
	  "  </td>\n"
	  "</tr>\n";
      }
      modid = g->modid;
      RoxenModule mod = Roxen.get_module(modid);
      string name = Roxen.html_encode_string(modid);
      if (mod) {
	Configuration conf = mod->my_configuration();
	string curl = replace(conf->name, " ", "%20") + "/";
	string mname = Roxen.get_modfullname(mod);

	string mgroup = "zz_misc";
	if (sscanf(mname, "%s:%*s", mgroup) != 2)
	  mgroup = "zz_misc";
	if (mgroup == "zz_misc") mgroup = LOCALE(525, "Other");

	string murl = curl +
	  Roxen.http_encode_invalids(mgroup) + "!0/" +
	  replace(mod->sname(), "#", "!") + "/?section=Status";

	name = sprintf("<a href='/sites/site.html/%s&amp;&usr.set-wiz-id;'>%s</a>/"
		       "<a href='/sites/site.html/%s&amp;&usr.set-wiz-id;'>%s</a>",
		       Roxen.html_encode_string(curl),
		       replace(Roxen.html_encode_string(conf->query_name()),
			       " ", "&nbsp;"),
		       Roxen.html_encode_string(murl),
		       replace(Roxen.get_modfullname(mod),
			       " ", "&nbsp;"));
      }
      res +=
	"<tr><td><h3>" +
	sprintf(LOCALE(1105, "Registered by %s"), name) +
	"</h3></td></tr>\n"
	"<tr>\n"
	"  <td>\n"
	"    <table class='entry'>\n";
    }

    array(Stdio.Stat) stats = g->get_stats();
    int local_max_size = 0;
    int local_min_mtime = 0x7fffffff;
    string age = format_time(g->max_age);

    foreach(stats, Stdio.Stat st) {
      if (st->size > local_max_size) local_max_size = st->size;
      if (st->mtime < local_min_mtime) local_min_mtime = st->mtime;
    }
    string sizes = exp_histogram(LOCALE(377, "Size"),
				 20, stats->size, local_max_size);
    // divide time in minutes.
    string ages = lin_histogram(LOCALE(1070, "Age"),
				20, map(stats->mtime, `-, local_min_mtime),
				g->max_age || time(1) - local_min_mtime);

    res +=
      sprintf("      <tr>"
	      "        <th>&nbsp;</th>\n"
              "        <th class='path' colspan='3'><tt>%s</tt></th>"
              "      </tr>\n"
	      "      <tr>\n"
	      "        <th style='width: 0%%'>&nbsp;</th>\n"
	      "        <th>%s</th>\n"
	      "        <th>%s</th>\n"
	      "        <th>%s</th>\n"
	      "      </tr>\n"
	      "      <tr class='sub-table'>\n"
	      "        <td>&nbsp;</td>\n"
	      "        <td class='status'>\n"
	      "            " +
	      LOCALE(1071, "%d files <span class='dim'>(max: %d)</span>") +
              "<br/>\n"
	      "            " +
	      LOCALE(1106, "%d KiB <span class='dim'>(max: %d)</span>") +
              "<br/>\n"
	      "            Age limit: %s\n"
	      "        </td>\n"
	      "        <td>\n%s</td>\n"
	      "        <td>\n%s</td>\n"
	      "      </tr>\n",
	      Roxen.html_encode_string(g->root), // Mount point
	      LOCALE(228, "Status"),
	      LOCALE(1107, "File age distribution"),
	      LOCALE(1108, "File size distribution"),
	      g->num_files, g->max_files, // files
	      (g->total_size/size_unit), (g->max_size/size_unit), // size (KiB)
	      age, // age (seconds or minutes)
	      ages, // age distribution histogram
	      sizes); // size distribution histogram
  }
  if (modid) {
    res +=
      "    </table>\n"
      "  </td>\n"
      "</tr>\n";
  }

  if (!sizeof(res)) {
    res = "<tr><th>" +
      LOCALE(1069, "No filesystem garbage collectors active.") +
      "</th></tr>\n";
  }

  return
    "<style type='text/css'>\n"
    "#fsgc-table h3 { font-size: 14px; margin: 0; }\n"
    "#fsgc-table .entry { font-size: 12px; margin-bottom: 12px; }\n"
    "#fsgc-table .entry tt { font-size: 14px; }\n"
    "#fsgc-table .entry .dim { color: #888; }\n"
    "#fsgc-table th { text-align: left; vertical-align: top; }\n"
    "#fsgc-table th.path { color: #68a; padding: 8px 0; }\n"
    "#fsgc-table .sub-table td { vertical-align: top; padding-right: 20px; }\n"
    "#fsgc-table .sub-table td.status { width: 250px; }\n"
    "</style>\n"
    "<table id='fsgc-table' width='100%'>\n" + res + "</table>\n"
    "<input type='hidden' name='action' value='fsgarb.pike' />"
    "<br />\n"
    "<cf-ok-button href='./'/> <cf-refresh/>\n";

#else
  return LOCALE(1072, "Not available in this installation of Roxen.");
#endif
}
