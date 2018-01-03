//
// "Globals"/"Filesystem GC".
//
// 2013-09-20 Henrik Grubbström
//

#include <config.h>
#include <roxen.h>
//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

// Linear histogram
string lin_histogram(string|object title, int num_buckets,
		 array(int) value_set, int max)
{
  int num_files = sizeof(value_set);
  if (!num_files) return "";
  max++;
  array(int) buckets = allocate(num_buckets);
  foreach(value_set, int v) {
    int b = (v * num_buckets)/max;
    if (b < 0) b = 0;
    if (b >= num_buckets) b = num_buckets - 1; 
    buckets[b]++;
  }
  
  int max_height = 150;
  int max_width = 0;
  int x_pos = 0;
  int y_pos = 0;  
  string res;
  
  foreach(buckets; int bno; int count) {
    int percent = (count*max_height)/num_files;
    int prev = (bno * max) / num_buckets;
    int sz = ((bno + 1) * max) / num_buckets - 1;
    
    // x_pos = horizontal pos of bar, starting point: 0
    // y_pos = vertical pos of bar, origin at upper left corner
    //
    y_pos = max_height - percent;
    res += sprintf(LOCALE(0, "<rect x='%d' y='%d'"
			     " width='10' height='%d'"
			     " style='fill:#808080;'>\n"
			     "  <title>%s: %d - %d\ncount: %d</title>\n"
			     "</rect>\n"
			     "<rect x='%d' y='0'"
			     " width='10' height='%d'"
			     " style='fill:f2f1eb;'/>\n"),
		   x_pos, y_pos,
		   percent, Roxen.html_encode_string(title),
		   prev, sz, count,
		   x_pos, y_pos);
    
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
  int bucket_max = 1024;
  mapping(int:int) buckets = ([]);
  foreach(value_set, int val) {
    while (val > bucket_max) {
      bucket_max *= 2;
      buckets[bucket_max] = 0;
    }
    buckets[bucket_max]++;
  }

  int max_height = 150;
  int max_width = 0;
  int prev = 0;
  int x_pos = 0;
  int y_pos = 0;
  string res;
  
  foreach(sort(indices(buckets)), int sz) {
    int count = buckets[sz];
    int percent = (count*150)/sizeof(value_set);
    // x_pos = horizontal pos of bar, starting point: 0
    // y_pos = vertical pos of bar, origin at upper left corner
    y_pos = max_height - percent;
    res += sprintf(LOCALE(0, "<rect x='%d' y='%d'"
			     " width='10' height='%d'"
			     " style='fill:#808080;'>\n"
			     "  <title>%s: %d - %d\ncount: %d</title>\n"
			     "</rect>\n"
			     "<rect x='%d' y='0'"
			     " width='10' height='%d'"
			     " style='fill:f2f1eb;'/>\n"),
		   x_pos, y_pos,
		   percent, Roxen.html_encode_string(title),
		   prev, sz, count,
		   x_pos, y_pos);
    
    prev = sz;
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
  array(object/*(roxen.FSGarb)*/) garbs = values(roxen->fsgarbs);
  if (!sizeof(garbs)) {
    return LOCALE(0, "No filesystem garbage collectors active.");
  }

  string res = "";
  sort(garbs->root, garbs);  
  foreach(garbs, object/*(roxen.FSGarb)*/ g) {
    if (sizeof(res)) res += "<tr><td>&nbsp;</td></tr>";
    
    array(Stdio.Stat) stats = g->get_stats();
    int local_max_size = 0;
    int local_min_mtime = 0x7fffffff;
    foreach(stats, Stdio.Stat st) {
      if (st->size > local_max_size) local_max_size = st->size;
      if (st->mtime < local_min_mtime) local_min_mtime = st->mtime;
    }
    string sizes = exp_histogram(LOCALE(0, "Size"),
				 10, stats->size, local_max_size);
    string ages = lin_histogram(LOCALE(0, "Age"),
				10, map(stats->mtime, `-, local_min_mtime),
				time(1) - local_min_mtime);
    
    res +=
      sprintf(LOCALE(0, "<tr><th align='left'>Mount point: %s</th></tr>\n"
		        "<tr><th><br/></th></tr>\n"
		        "<tr>\n"
		        "  <td>\n"
		        "    <table>\n"
		        "      <tr>\n"
		        "        <th align='left'>Registered by <br/>%s</th>\n"
		        "        <th align='left'>File size distribution</th>\n"
		        "        <th align='left'>File age distribution</th>\n"
		        "      </tr>\n"
		        "      <tr id='tbl'>\n"
		        "        <td>\n"
		        "            %d files (max: %d)<br/>\n"
		        "            %d bytes (max: %d)<br/>\n"
		        "            Age limit: %d seconds\n"
                        "        </td>\n"
		        "        <td>\n%s</td>\n"
		        "        <td>\n%s</td>\n"
		        "      </tr>\n"
		        "    </table>\n"
		        "  </td>\n"
		        "</tr>\n"),
	      Roxen.html_encode_string(g->root),
	      Roxen.html_encode_string(g->modid),
	      g->num_files, g->max_files,
	      g->total_size, g->max_size,
	      g->max_age,
	      sizes,
	      ages);
  }
  
  return "<table width='100%'>\n" + res + "</table>\n";
  
#else
  return LOCALE(0, "Not available in this installation of Roxen.");
#endif
}
