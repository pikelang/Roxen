//
// "Globals"/"Filesystem GC".
//
// 2013-09-20 Henrik Grubbström
//

#include <config.h>
#include <roxen.h>
//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

string histogram(string|object title, int num_buckets,
		 array(int) value_set, int max)
{
  if (!sizeof(value_set)) return "";
  max++;
  array(int) buckets = allocate(num_buckets);
  foreach(value_set, int v) {
    int b = (v * num_buckets)/max;
    if (b < 0) b = 0;
    if (b >= num_buckets) b = num_buckets - 1;
    buckets[b]++;
  }
  string res = sprintf("<tr><td><h5>%s</h5></td></tr>\n",
		       Roxen.html_encode_string(title));
  foreach(buckets; int bno; int count) {
    res += sprintf("<tr><td>%d - %d</td><td>%d</td></tr>\n",
		   (bno * max) / num_buckets,
		   ((bno + 1) * max) / num_buckets - 1,
		   count);
  }
  res += sprintf("<tr><td>&nbsp;</td></tr>\n");

  return res;
}

string parse(RequestID id)
{
#if constant(roxen.register_fsgarb)
  array(object/*(roxen.FSGarb)*/) garbs = values(roxen->fsgarbs);
  if (!sizeof(garbs)) {
    return LOCALE(0, "No filesystem garbage collectors active.");
  }

  string res = "";
  sort(garbs->root, garbs);  
  foreach(garbs, object/*(roxen.FSGarb)*/ g) {
    if (sizeof(res)) res += "<tr><td>&nbsp;</td></tr>";
    res +=
      sprintf(LOCALE(0, "<tr><th>%s</th></tr>\n"
		     "<tr><td>Registered by <b>%s</b></td></tr>"
		     "<tr><td>%d files (max: %d)</td></tr>\n"
		     "<tr><td>%d bytes (max: %d)</td></tr>\n"
		     "<tr><td>Age limit: %d seconds</td></tr>\n"),
	      Roxen.html_encode_string(g->root),
	      Roxen.html_encode_string(g->modid),
	      g->num_files, g->max_files,
	      g->total_size, g->max_size,
	      g->max_age);
    array(Stdio.Stat) stats = g->get_stats();
    int local_max_size = 0;
    int local_min_mtime = 0x7fffffff;
    foreach(stats, Stdio.Stat st) {
      if (st->size > local_max_size) local_max_size = st->size;
      if (st->mtime < local_min_mtime) local_min_mtime = st->mtime;
    }
    res += histogram(LOCALE(0, "File size distribution"),
		     10, stats->size, local_max_size);
    res += histogram(LOCALE(0, "File age distribution"),
		     10, map(stats->mtime, `-, local_min_mtime),
		     time(1) - local_min_mtime);
  }
  return "<table>\n" + res + "</table>\n";
#else
  return LOCALE(0, "Not available in this installation of Roxen.");
#endif
}