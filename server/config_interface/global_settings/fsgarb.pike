//
// "Globals"/"Filesystem GC".
//
// 2013-09-20 Henrik Grubbström
//

#include <config.h>
#include <roxen.h>
//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)	_STR_LOCALE("roxen_config",X,Y)

string fill_color = "#a6baf3";
string bg_color = "#e9eefc";

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
    int height = (count*max_height)/num_files;
    int min_val = (bno * max) / num_buckets;
    int max_val = ((bno + 1) * max) / num_buckets - 1;
    float percent = ((float)count/(float)num_files)*100;

    // x_pos = horizontal pos of bar, starting point: 0
    // y_pos = vertical pos of bar, origin at upper left corner
    // fill-color: #808080 | #f2f1eb
    y_pos = max_height - height;
    res += sprintf(LOCALE(1068, "<rect x='%d' y='%d'"
			     " width='10' height='%d'"
			     " style='fill:%s;'>\n"
			     "  <title>%s: %d - %d s\n%f&#37; (%d)</title>\n"
			     "</rect>\n"
			     "<rect x='%d' y='0'"
			     " width='10' height='%d'"
			     " style='fill:%s;'>\n"
			     "  <title>%s: %d - %d s\n%f&#37; (%d)</title>\n"
			     "</rect>\n"),
		   x_pos, y_pos, height, fill_color,
		   Roxen.html_encode_string(title), min_val, max_val, percent, count,
		   x_pos, y_pos, bg_color,
		   Roxen.html_encode_string(title), min_val, max_val, percent, count);

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

  foreach(value_set, int val) {
    while (val > bucket_max) {
      bucket_max *= 2;
      buckets[bucket_max] = 0;
    }
    buckets[bucket_max]++;
  }

  int max_height = 150;
  int max_width = 0;
  int min = 0;
  int x_pos = 0;
  int y_pos = 0;
  string res;

  foreach(sort(indices(buckets)), int sz) {
    int count = buckets[sz];
    int max = sz / chunk_sz; // part in KB
    int height = (count*max_height)/sizeof(value_set);
    float percent = ((float)count/(float)sizeof(value_set))*100;

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
  array(object/*(roxen.FSGarb)*/) garbs = values(roxen->fsgarbs);
  if (!sizeof(garbs)) {
    return LOCALE(1069, "No filesystem garbage collectors active.");
  }

  int time_unit = 60;
  int size_unit = 1024;
  string res = "";
  sort(garbs->root, garbs);
  foreach(garbs, object/*(roxen.FSGarb)*/ g) {

    // werror("FSGARG DEBUG object g: %O\n", g);

    if (sizeof(res)) res += "<tr><td>&nbsp;</td></tr>";

    array(Stdio.Stat) stats = g->get_stats();
    int local_max_size = 0;
    int local_min_mtime = 0x7fffffff;
    string age;
    if ((g->max_age/time_unit) > 1)
      age = g->max_age/time_unit + " minutes";
    else
      age = g->max_age + " seconds";

    foreach(stats, Stdio.Stat st) {
      if (st->size > local_max_size) local_max_size = st->size;
      if (st->mtime < local_min_mtime) local_min_mtime = st->mtime;
    }
    string sizes = exp_histogram(LOCALE(377, "Size"),
				 10, stats->size, local_max_size);
    // divide time in minutes.
    string ages = lin_histogram(LOCALE(1070, "Age"),
				10, map(stats->mtime, `-, local_min_mtime),
				time(1) - local_min_mtime);

    res +=
      sprintf(LOCALE(1071, "<tr><td><h3>Registered by %s</h3></td></tr>\n"
		        "<tr>\n"
		        "  <td>\n"
		        "    <table width='100&#37;'>\n"
		        "      <tr>\n"
		        "        <th align='left' valign='top'>%s</th>\n"
		        "        <th align='left' valign='top'>File size distribution</th>\n"
		        "        <th align='left' valign='top'>File age distribution</th>\n"
		        "      </tr>\n"
	        "      <tr id='tbl'>\n"
		        "        <td valign='top'>\n"
		        "            %d files (max: %d)<br/>\n"
		        "            %d KiB (max: %d)<br/>\n"
		        "            Age limit: %s\n"
                        "        </td>\n"
		        "        <td valign='top'>\n%s</td>\n"
		        "        <td valign='top'>\n%s</td>\n"
		        "      </tr>\n"
		        "    </table>\n"
		        "  </td>\n"
		        "</tr>\n"),
	      Roxen.html_encode_string(g->modid), // module
	      Roxen.html_encode_string(g->root), // Mount point
	      g->num_files, g->max_files, // files
	      (g->total_size/size_unit), (g->max_size/size_unit), // size (KiB)
	      age, // age (seconds or minutes)
	      sizes, // size distribution histogram
	      ages); // age distribution histogram
  }

  return "<table width='100%'>\n" + res + "</table>\n";

#else
  return LOCALE(1072, "Not available in this installation of Roxen.");
#endif
}
