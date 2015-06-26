// This is a roxen module. Copyright © 2011, Roxen IS.

// TODO
//
//   * Move index creation to Roxen Core

#include <module.h>
inherit "module";

constant cvs_version = "$Id$";
constant thread_safe = 1;

constant module_type = MODULE_ZERO;
constant module_name = "ArgCache GC";
constant module_doc  = 
  "<p>This module deletes old entries from the argument cache based on "
  "the access time column.</p>"
  "<p><b>Note:</b> Only one module instance per Roxen server is needed.</p>"
  "<p><b>Note:</b> Potentionally dangerous to use if the site keeps persistent "
  "cache objects longer then the remote purge time. This can lead to "
  "broken images.</p>";

string site_name;

void create(Configuration conf) 
{
  defvar("garb_schedule",
	 Variable.Schedule( ({ 2, 1, 1, 0, 5 }), 0,
			    "Schedule",
			    "When to automaticaly perform the GC") );

  defvar("purge_limit", 100000, "Purge limit",
	 TYPE_INT,
	 "Maximum number of entries to delete in each run.");

  defvar("local_purge_days", 183, "Local purge days",
	 TYPE_INT,
	 "Purge local argcache entries that has not been accessed in the specified number "
	 "of days.");

  defvar("remote_purge_days", 365, "Remote purge days",
	 TYPE_INT,
	 "Purge remote argcache entries that has not been accessed in the specified number "
	 "of days.");

  if(conf)
    site_name = conf->query_name();
}

mapping(string:function|array(function|string)) query_action_buttons()
{
  return ([ "Purge": argcache_garb ]);
}

string status()
{
  string res = "";

  Sql.Sql local_db = DBManager.cached_get("local");

  array(mapping) local_entries = 
    local_db->query("SELECT count(*) as count "
		    "FROM arguments2");

  array(mapping) local_old = 
    local_db->query("SELECT id, ctime, atime "
		    "FROM arguments2 "
		    "ORDER BY atime ASC "
		    "LIMIT 1");

  res += 
    sprintf("<tr><td>Local entries:</td> <td>%s</td></tr>\n"
	    "<tr><td>Local oldest entry:</td> <td>%s</td></tr>\n",
	    local_entries[0]->count,
	    local_old[0]->atime);

  Sql.Sql remote_db = DBManager.cached_get("replicate");
  if(remote_db)
  {
    array(mapping) remote_entries = 
      remote_db->query("SELECT count(*) as count "
		       "FROM arguments2");
    
    array(mapping) remote_old = 
      remote_db->query("SELECT id, ctime, atime "
		       "FROM arguments2 "
		       "ORDER BY atime ASC "
		       "LIMIT 1");
    res += 
      sprintf("<tr><td>Remote entries:</td> <td>%s</td></tr>\n"
	      "<tr><td>Remote oldest entry:</td> <td>%s</td></tr>\n",
	      remote_entries[0]->count,
	      remote_old[0]->atime);
  }
  else
    res += "<tr><td>No replicate database found.</td></tr>";
  
  return "<table>" + res + "</table><br/>";
}


protected roxen.BackgroundProcess garb_argcache_process;
void start() 
{
  if (garb_argcache_process) 
    garb_argcache_process->stop();
  garb_argcache_process = roxen.BackgroundProcess(60, check_schedule);
}

void stop()
{
  if (garb_argcache_process) 
    garb_argcache_process->stop();
}

protected string get_state_path()
{
  return combine_path (getcwd(),
                       getenv ("VARDIR") || "../var",
                       "argcache_garb_state", Roxen.short_name(site_name)+".state");
}

protected void save_state(int value)
{
  string path = get_state_path();
  Stdio.mkdirhier (dirname (path));
  Stdio.write_file(path, sprintf("last_garb: %d\n", value));
}

protected int get_state()
{
  string path = get_state_path();
  string s = Stdio.read_file(path) || "";
  if(sscanf(s, "last_garb: %d\n", int value) >= 1)
    return value;
}

void purge_db(Sql.Sql db, int days, string name)
{
  create_index(db, name);

  int start_time = gethrtime();

  db->big_query("DELETE FROM arguments2 "
		"WHERE atime < SUBDATE(NOW(), %d) "
		"ORDER BY atime ASC "
		"LIMIT %d",
		days, query("purge_limit"));

  werror("ArgCache Garb: Purged %d %s entries. [%f s]\n", 
	 db->master_sql->affected_rows(), name,
	 (gethrtime() - start_time)/1000000.0);
}

void argcache_garb()
{

  werror("ArgCache Garb: Starting...\n");
  purge_db(DBManager.cached_get("local"), (int)query("local_purge_days"), "local");

  Sql.Sql remote_db = DBManager.cached_get("replicate");
  if(remote_db) 
    purge_db(remote_db, (int)query("remote_purge_days"), "remote");
}


void create_index(Sql.Sql db, string name)
{
  array(mapping(string:mixed)) res = 
    db->query("SHOW INDEX FROM arguments2");

  if(search(res->Key_name, "atime") < 0) {
    werror("ArgCache Garb: Adding index atime on %s arguments2...\n", name);
    int start_time = gethrtime();
    db->query("CREATE INDEX atime ON arguments2 (atime)");
    werror("ArgCache Garb: Add index complete. [%f s]\n", 
	   (gethrtime() - start_time)/1000000.0);
  }
}


void check_schedule()
{
  int next = getvar("garb_schedule")->get_next( get_state() );
#ifdef ACGC_SCHEDULE_DEBUG
  werror("Last     : %s", ctime(get_state()));
  werror("Next dump: %s", ctime(next));
#endif
  if (next >= 0) {
    if (next <= time(1)) {
      save_state( time(1) );
      argcache_garb();
    }
    else if (garb_argcache_process) {
      garb_argcache_process->set_period (next - time(1));
#ifdef ACGC_SCHEDULE_DEBUG
      werror("wait %d\n", next - time(1));
#endif
    }
  }
}
