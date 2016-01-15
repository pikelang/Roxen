/*
 * $Id$
 */
#include <stat.h>
#include <roxen.h>
//<locale-token project="admin_tasks">LOCALE</locale-token>
#define LOCALE(X,Y)	_DEF_LOCALE("admin_tasks",X,Y)

constant action = "debug_info";

LocaleString name= LOCALE(1,"Pike memory usage information");
LocaleString doc = LOCALE(2,
		    "Show some information about how Pike is using the "
		    "memory it has allocated. Mostly useful for developers.");

int creation_date = time();

int no_reload()
{
  return creation_date > file_stat( __FILE__ )[ST_MTIME];
}

string render_table(mapping last_usage, mapping mem_usage)
{
  string res = "";
  string first="";
  mem_usage->total_usage = 0;
  mem_usage->num_total = 0;
  array ind = sort(indices(mem_usage));
  string f;
  int row=0;

  array table = ({});

  foreach(ind, f)
    if(!search(f, "num_"))
    {
      int factor = 1;
      if (has_prefix(f, "num_free_")) {
	factor = -1;
      }
      if(f!="num_total")
	mem_usage->num_total += mem_usage[f];

      string bn = f[4..sizeof(f)-2]+"_bytes";
      mem_usage->total_bytes += factor*mem_usage[ bn ];

      string col ="&usr.warncolor;";

      int diff = (mem_usage[bn]-last_usage[bn])*factor;
      int cmp = factor*mem_usage[bn]/60;

      if (!diff) {
	// Look at the count diff instead.
	diff = mem_usage[f]-last_usage[f];
	cmp = mem_usage[f]/60;
      }

      if(diff < cmp)
	col="&usr.warncolor;";
      if(diff == 0)
	col="&usr.fgcolor;";
      if(diff < 0)
	col="&usr.fade4;";

      if( bn == "tota_bytes" )
        bn = "total_bytes";
      table += ({ ({
	col, f[4..], mem_usage[f], mem_usage[f]-last_usage[f],
        sprintf( "%.1f",mem_usage[bn]/1024.0),
        sprintf( "%.1f",(mem_usage[bn]-last_usage[bn])/1024.0 ),
      }) });
    }
  roxen->set_var("__memory_usage", mem_usage);

#define HCELL(thargs, color, text)					\
  ("<th " + thargs + ">"						\
   "&nbsp;<font color='" + color + "'><b>" + text + "</b></font>&nbsp;"	\
   "</th>")
#define TCELL(tdargs, color, text)					\
  ("<td " + tdargs + ">"						\
   "&nbsp;<font color='" + color + "'>" + text + "</font>&nbsp;"	\
   "</td>")

  res += "<p><table border='0' cellpadding='0'>\n<tr>\n" +
    HCELL ("align='left' ", "&usr.fgcolor;", (string)LOCALE(3,"Type")) +
    HCELL ("align='right'", "&usr.fgcolor;", (string)LOCALE(4,"Number")) +
    HCELL ("align='right'", "&usr.fgcolor;", (string)LOCALE(5,"Change")) +
    HCELL ("align='right'", "&usr.fgcolor;", "Kb") +
    HCELL ("align='right'", "&usr.fgcolor;", (string)LOCALE(5,"Change")) +
    "</tr>\n";
  foreach (table, array entry)
    res += "<tr>" +
      TCELL ("align='left' ", entry[0], entry[1]) +
      TCELL ("align='right'", entry[0], entry[2]) +
      TCELL ("align='right'", entry[0], entry[3]) +
      TCELL ("align='right'", entry[0], entry[4]) +
      TCELL ("align='right'", entry[0], entry[5]) + "</tr>\n";
  res += "</table></p>\n";

  return res;
}

mixed page_0( object id )
{
  mapping last_usage;
  last_usage = roxen->query_var("__memory_usage");
  if(!last_usage)
  {
    last_usage = _memory_usage();
    roxen->set_var( "__memory_usage", last_usage );
  }

  mapping(string|program:array) allobj = ([]);
  mapping(string|program:int) numobjs = ([]);
  mapping(string:int) refs = ([]);
  mapping(string:int) mem = ([]);

  object threads_disabled = _disable_threads();

  int orig_enabled = Pike.gc_parameters()->enabled;
  Pike.gc_parameters ((["enabled": 0]));

  int gc_freed =
    (id->real_variables->gc || id->real_variables["gc.x"]) && gc();

  mapping(string:int) mem_usage = _memory_usage();
  int this_found = 0, walked_objects = 0, destructed_objs = 0;
  object obj = next_object();
  // next_object skips over destructed objects, so back up over them.
  while (zero_type (_prev (obj))) obj = _prev (obj);
  while (1) {
    object next_obj;
    // Objects can be very much like zeroes, so the only reliable way
    // to go through them all is to continue until _next balks.
    if (catch (next_obj = _next (obj))) break;
    string|program p = object_program (obj);
    if (p == this_program && obj == this_object()) this_found = 1;
    if (p) {
      p = functionp (p) && Function.defined (p) ||
	programp (p) && Program.defined (p) ||
	p;
      catch {
	// Paranoia catch.
	refs[p] += Debug.refs(obj) - 2; // obj and stack.
	mem[p] += Pike.count_memory (-1, obj);
      };
      if (++numobjs[p] <= 50) {
#if 0
	if (stringp (p) && has_suffix (p, "my-file.pike:4711"))
	  _locate_references (obj);
#endif
	allobj[p] += ({obj});
      }
    }
    else
      destructed_objs++;
    walked_objects++;
    obj = next_obj;
  }

  // We need to convert the objects to strings here already, in order
  // to release object references before threads_disabled is released
  // below. The extra references might otherwise cause problems with
  // e.g. Thread.MutexKey objects that are normally expected to only
  // have references from the stack of the owning thread.
  foreach (allobj; string|program prog; array objs)
    for (int i = 0; i < sizeof (objs); i++) {
      if (catch {
	  // The object might have become destructed since the walk above.
	  // Just ignore it in that case.
	  objs[i] = !zero_type (objs[i]) && sprintf ("%O", objs[i]);
	})
	objs[i] = 0;
    }

  mapping(string:int) mem_usage_afterwards = _memory_usage();
  int num_things_afterwards =
    mem_usage_afterwards->num_arrays +
    mem_usage_afterwards->num_mappings +
    mem_usage_afterwards->num_multisets +
    mem_usage_afterwards->num_objects +
    mem_usage_afterwards->num_programs;

  Pike.gc_parameters ((["enabled": orig_enabled]));
  mapping gc_status = _gc_status();
  threads_disabled = 0;

  string res = "<p>Current time: " + ctime (time()) + "</p>\n"
    "<p>";
  if (id->real_variables->gc || id->real_variables["gc.x"])
    res += sprintf (LOCALE(169, "The garbage collector freed %d of %d things (%d%%)."),
		    gc_freed, gc_freed + num_things_afterwards,
		    gc_freed * 100 / (gc_freed + num_things_afterwards));
  else
    res += sprintf (LOCALE(170, "%d seconds since last garbage collection, "
			   "%d%% of the interval is consumed."),
		    time() - gc_status->last_gc,
		    (gc_status->num_allocs + 1) * 100 /
		    (gc_status->alloc_threshold + 1));

  res += "</p>\n";

  if (!this_found)
    res += "<p><font color='&usr.warncolor;'>" + LOCALE(173, "Internal inconsistency") +
      ":</font> " + LOCALE(174, "Object(s) missing in object link list.") + "</p>\n";

  mapping last_low_usage =
    ([ "num_malloc_blocks":0, "malloc_block_bytes":0,
       "num_free_blocks":0, "free_block_bytes":0 ]) & last_usage;
  mapping low_usage =
    ([ "num_malloc_blocks":0, "malloc_block_bytes":0,
       "num_free_blocks":0, "free_block_bytes":0 ]) & mem_usage;

  if (sizeof(low_usage)) {
    res += render_table(last_low_usage, low_usage);
  }

  res += render_table(last_usage - last_low_usage, mem_usage - low_usage);

  if (walked_objects != mem_usage->num_objects) {
    res += "<p><font color='&usr.warncolor;'>" + LOCALE(175, "Warning") + ":</font> ";
    if (mem_usage_afterwards->num_objects != mem_usage->num_objects)
      res += LOCALE(176, "Number of objects changed during object walkthrough "
		    "(probably due to automatic gc call) - "
		    "the list below is not complete.");
    else
      res += sprintf (LOCALE(177, "The object walkthrough visited %d of %d objects - "
			     "the list below is not accurate."),
		      walked_objects, mem_usage->num_objects);
    res += "</p>\n";
  }

  mapping save_numobjs = roxen->query_var( "__num_clones" );
  int no_save_numobjs = !save_numobjs;
  if (no_save_numobjs) save_numobjs = ([]);

  if (destructed_objs) {
    allobj["    "] = ({"<destructed object>"});
    numobjs["    "] = destructed_objs;
  }

  array table = (array) allobj;

  string cwd = getcwd() + "/";
  constant inc_color  = "&usr.warncolor;";
  constant dec_color  = "&usr.fade4;";
  constant same_color = "&usr.fgcolor;";

  for (int i = 0; i < sizeof (table); i++) {
    [string|program prog, array(string) objs] = table[i];
    objs -= ({0});

    string objstr = String.common_prefix (objs)[..30];
    if (!(<"", "object">)[objstr]) {
      if (sizeof (objstr) < max (@map (objs, sizeof))) objstr += "...";
    }
    else objstr = "";

    int|string change;
    if (array ent = save_numobjs[prog]) {
      change = numobjs[prog] - ent[0];
      ent[0] = numobjs[prog];
    }
    else
      save_numobjs[prog] = ({change = numobjs[prog], objstr});

    if (sizeof (objs) > 2 || abs (change) > 2) {
      string progstr;
      if (stringp (prog)) {
	if (has_prefix (prog, cwd))
	  progstr = prog[sizeof (cwd)..];
	else if (has_prefix (prog, roxenloader.server_dir + "/"))
	  progstr = prog[sizeof (roxenloader.server_dir + "/")..];
	else
	  progstr = prog;
      }
      else progstr = "?";

      string color;
      if (no_save_numobjs) {
	change = "N/A";
	color = same_color;
      }
      else {
	if (change > 0) color = inc_color, change = "+" + change;
	else if (change < 0) color = dec_color;
	else color = same_color;
      }

      table[i] = ({ color, progstr, objstr,
		    numobjs[prog], change, refs[prog], mem[prog] });
    }
    else table[i] = 0;
  }

  // Add decrement entries for the objects that have disappeared completely.
  foreach (save_numobjs - allobj; string|program prog; array entry) {
    if (entry[0] > 2) {
      string progstr;
      if (stringp (prog)) {
	if (has_prefix (prog, cwd))
	  progstr = prog[sizeof (cwd)..];
	else
	  progstr = prog;
      }
      else progstr = "";
      table += ({({dec_color, progstr, entry[1], 0, -entry[0], 0, 0})});
    }
    entry[0] = 0;
  }

  table = Array.sort_array (table - ({0}),
			    lambda (array a, array b) {
			      return a[3] < b[3] || a[3] == b[3] && (
				a[2] < b[2] || a[2] == b[2] && (
				  a[1] < b[1]));
			    });

  roxen->set_var("__num_clones", save_numobjs);

  res += "<p><table style='font-size: 9px' border='0' cellpadding='0'>\n<tr>\n" +
    HCELL ("align='left' ", "&usr.fgcolor;", (string)LOCALE(141,"Source")) +
    HCELL ("align='left' ", "&usr.fgcolor;", (string)LOCALE(142,"Program")) +
    HCELL ("align='right'", "&usr.fgcolor;", (string)LOCALE(403,"References")) +
    HCELL ("align='right'", "&usr.fgcolor;", (string)LOCALE(143,"Clones")) +
    HCELL ("align='right'", "&usr.fgcolor;", (string)LOCALE(5,"Change")) +
    HCELL ("align='right'", "&usr.fgcolor;", (string)LOCALE(0,"Bytes")) +
    "</tr>\n";
  string trim_path( string what )
  {
    sscanf( what, "%*s/lib/modules/%s", what );
    return what;
  };

  foreach (table, array entry)
    res += "<tr>" +
      TCELL ("align='left' ", entry[0],
	     replace (Roxen.html_encode_string (trim_path(entry[1])), " ", "\0240")) +
      TCELL ("align='left' ", entry[0],
	     replace (Roxen.html_encode_string (entry[2]), " ", "\0240")) +
      TCELL ("align='right'", entry[0], entry[5]) +
      TCELL ("align='right'", entry[0], entry[3]) +
      TCELL ("align='right'", entry[0], entry[4]) +
      TCELL ("align='right'", entry[0], entry[6]) + "</tr>\n";
  res += "</table></p>\n";

  if (gc_status->non_gc_time)
    gc_status->gc_time_ratio =
      (float) gc_status->gc_time / gc_status->non_gc_time;

  res += "<p><b>" + LOCALE(172,"Garbage collector status") + "</b><br />\n"
    "<table border='0' cellpadding='0'>\n";
  foreach (sort (indices (gc_status)), string field)
    res += "<tr>" +
      TCELL ("align='left'", "&usr.fgcolor;",
	     Roxen.html_encode_string (field)) +
      TCELL ("align='left'", "&usr.fgcolor;",
	     Roxen.html_encode_string (gc_status[field])) +
      "</tr>\n";
  res += "</table></p>\n"
    "<p><font size='-1'>" + LOCALE(401, #"\
Note that the garbage collector referred to here is not the same as
the one for the <a
href='/actions/?action=cachestatus.pike&amp;class=status&amp;&usr.set-wiz-id;'>Roxen memory
cache</a>. This is the low-level garbage collector used internally by
the Pike interpreter.") + "</font></p>\n";
    ;

  return res;
}

mixed parse( RequestID id )
{
  return
    "<font size='+1'><b>"+
    LOCALE(1,"Pike memory usage information")+
    "</b></font>"
    "<p />"
    "<input type='hidden' name='action' value='debug_info.pike' />\n"
    "<p><submit-gbutton2 name='refresh' img-align='middle'> "
    "<translate id='520'>Refresh</translate> "// <cf-refresh> doesn't submit.
    "</submit-gbutton2>\n"
    "<submit-gbutton2 name='gc' img-align='middle'> "
    "<translate id='0'>Run garbage collector</translate> "
    "</submit-gbutton2>\n"
    "<cf-cancel href='?class=&form.class;&amp;&usr.set-wiz-id;'/>\n" +
    page_0( id );
}
