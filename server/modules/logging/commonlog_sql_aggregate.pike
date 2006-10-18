// Common Log SQL Aggregate module
// $Id: commonlog_sql_aggregate.pike,v 1.5 2006/10/18 07:34:07 noring Exp $

#include <module.h>

inherit "module";
inherit "roxenlib";

#define LOCALE(X,Y)	_STR_LOCALE("sql_log_aggregate",X,Y)
#define DLOCALE(X,Y)    _DEF_LOCALE("sql_log_aggregate",X,Y)

constant thread_safe = 1;
constant module_unique = 0;
constant module_type = MODULE_PROVIDER;
constant cvs_version = "$Id: commonlog_sql_aggregate.pike,v 1.5 2006/10/18 07:34:07 noring Exp $";

LocaleString module_group_name = DLOCALE(0,"SQL Log:");
LocaleString module_generic_name = DLOCALE(0, "Aggregate module");
LocaleString module_name = module_group_name + " " + module_generic_name;

LocaleString module_doc = DLOCALE(0,#"
<p>This is the SQL Log Aggregate module.</p>");

string query_name()
{
  return module_group_name + " " + module_generic_name;
}

void create(Configuration conf)
{
  defvar("db_name",
	 Variable.DatabaseChoice("log",
				 VAR_INITIAL,
				 DLOCALE(0, "Log database"),
				 DLOCALE(0, "The database where all "
					 "log data is stored."))
	 ->set_configuration_pointer(my_configuration));

  // FIXME: Update after Common Log SQL: Import module: Yes/No.

  defvar("minute_granularity", 5, "Minute granularity", TYPE_MULTIPLE_INT,
	 "Granularity of aggregated statistics in minutes.",
	 ({ 1, 2, 3, 5, 6, 10, 12, 15, 20, 30, 60 }));
}

string status()
{
  string msg = "";
  Sql.sql sql = get_log_db();
  
  if(!sql)
    return msg +
           "<p style='color: red;'>No database. "
           "Create a log database in the Import Log module. Alternatively, "
           "make a remote database connection through the DB Manager.</p>";

  if(!has_log_tables(sql))
    return msg +
           "<p style='color: red;'>No access log table. "
           "Create an access log table in the Import Log module.";
  
  return msg;
}

Configuration conf;
string db_name;

Sql.Sql get_log_db()
{
  return DBManager.get(db_name, conf);
}

int has_log_tables(Sql.sql sql)
{
  if(!sql)
    return 0;
  if(has_value(sql->list_tables(), "access_log"))
    return 1;
  return 0;
}

void start(int when, Configuration _conf)
{
  conf = _conf;
  db_name = query("db_name");
}

void stop()
{
  aggregate_stop();
}

void ready_to_receive_requests(Configuration conf)
{
}

mapping(string:function) query_action_buttons()
{
  mapping buttons = ([]);

  Sql.sql sql = get_log_db();
  if(sql)
  {
    if(is_aggregate_running())
      buttons["Aggregate STOP!"] = aggregate_stop;
    else
      buttons["Aggregate now!"] = aggregate_start;
  }
  
  return buttons;
}

Thread.Thread aggregate_thread;

int is_aggregate_running()
{
  return aggregate_thread && !aggregate_thread->status();
}

string aggregate_status()
{
  if(is_aggregate_running())
    return "Aggregate is running";
  return "Waiting";
}

void aggregate_stop()
{
  aggregate_thread = 0;
}

void aggregate_start()
{
  Sql.sql sql = get_log_db();
  if(!sql)
  {
    report_error("Cannot aggregate. No log database present: %O\n", db_name);
    return;
  }
  
  if(is_aggregate_running())
    return;

  aggregate_thread = Thread.thread_create(run_aggregate, sql);
}

void run_aggregate(Sql.sql sql)
{
  werror("%s: Starting\n", query_name());
  foreach(({ AggregateHits(sql),
	     AggregatePerformance(sql),
	     AggregateCache(sql),
	     AggregateHosts(sql),
	     AggregateResources(sql),
	     AggregateResourceDirs(sql) }),
	  Aggregate aggregate)
  {
    if(!is_aggregate_running())
      // Check if the import thread is supposed to run.
      break;
    aggregate->create_table_if_not_exist(sql);
    aggregate->update(sql);
  }
  werror("%s: Finished\n", query_name());
}

mapping(string:int) last_access_log_row_id_per_date(Sql.sql sql)
{
  mapping res = ([]);
  foreach(sql->query("SELECT MAX(log_row_id) AS last_log_row_id,\n"
		     "       date\n"
		     "  FROM access_log\n"
		     " GROUP BY date\n"), mapping r)
    if(r->date)
      res[r->date] = (int)r->last_log_row_id;
  return res;
}

mapping(string:int) last_aggregate_log_row_id_per_date(Sql.sql sql, string tbl)
{
  mapping res = ([]);
  foreach(sql->query("SELECT MAX(last_log_row_id) AS last_log_row_id,\n"
		     "       date\n"
		     "  FROM "+tbl+"\n"
		     " GROUP BY date\n"), mapping r)
    if(r->date)
      res[r->date] = (int)r->last_log_row_id;
  return res;
}

array(string) updated_dates(Sql.sql sql, string table)
{
  mapping last_access_row_id = last_access_log_row_id_per_date(sql);
  foreach(last_aggregate_log_row_id_per_date(sql, table);
	  string date; int last_row_id)
    if(last_access_row_id[date] == last_row_id)
      m_delete(last_access_row_id, date);
  return indices(last_access_row_id);
}

class Aggregate
{
  string table_name;
  
  array(array(string)) computed_fields = ({});
  array(array(string)) required_fields = ({});
  array(array(string)) optional_fields = ({});
        array(string)  where_fields    = ({});
        array(string)  group_by_fields = ({});
  
  multiset(string) available_fields;

  void alter_table_if_not_exist(Sql.sql sql)
  {
    // Placeholder function.
  }
  
  void create_table_if_not_exist(Sql.sql sql)
  {
    string table_def = "CREATE TABLE IF NOT EXISTS "+table_name+"\n"
		       "(aggregate_id INTEGER NOT NULL AUTO_INCREMENT,\n"
		       " last_log_row_id BIGINT NOT NULL,\n"
		       " server_name VARCHAR(32),\n"
		       " date DATE,\n"
		       " time DATETIME,\n";
    foreach(computed_fields +
	    required_fields +
	    optional_fields, array(string) field)
      if(field[1] && available_fields[field[0]])
	table_def += field[0] + " " + field[1] + ",\n";
    table_def += "PRIMARY KEY (aggregate_id),\n"
		 "INDEX (date),\n"
		 "INDEX (server_name),\n"
		 "INDEX (server_name, date))\n";
    
    sql->query(table_def);
    
    alter_table_if_not_exist(sql);
  }

  int is_available()
  {
    return !sizeof(required_fields - (array)available_fields);
  }

  void post_update_date(Sql.sql sql, string date)
  {
    // Placeholder function.
  }
  
  void update_date(Sql.sql sql, string date)
  {
    sql->query("DELETE FROM "+table_name+" WHERE date = %s", date);
    
    string minute_granularity = query( "minute_granularity" );
    string query_def = "INSERT INTO "+table_name+"\n"
		       "           (last_log_row_id,\n"
		       "            server_name,\n"
		       "            date,\n"
		       "            time";
    foreach(computed_fields +
	    required_fields +
	    optional_fields, array(string) field)
      if(field[2] && available_fields[field[0]])
	query_def += ",\n            " + field[0];
    query_def += ")\n"
		 "     SELECT MAX(log_row_id),\n"
		 "            server_name,\n"
		 "            date,\n"
		 "            CONCAT(DATE_FORMAT(time, '%Y-%m-%d %H:'),\n"
		 "                   FLOOR(MINUTE(time)/"+minute_granularity+")*"+minute_granularity+") AS time_granularity";
    foreach(computed_fields +
	    required_fields +
	    optional_fields, array(string) field)
      if(field[2] && available_fields[field[0]])
	query_def += ",\n            " + field[2];
    query_def += "\n"
		 "       FROM access_log,\n"
		 "            log_files\n"
		 "      WHERE access_log.date = '"+sql->quote(date)+"'\n"
		 "        AND access_log.log_file_id =\n"
		 "              log_files.log_file_id\n";
    foreach(where_fields, string field)
      query_def += "        AND " + field + "\n";
    query_def += "   GROUP BY server_name, time_granularity";
    foreach(group_by_fields, string field)
      if(available_fields[field])
	query_def += ",\n            " + field;
    
    sql->query(query_def + "\n");
    
    post_update_date(sql, date);
  }

  void update(Sql.sql sql)
  {
    werror("%s: %s starting\n", query_name(), table_name);
    foreach(sort(updated_dates(sql, table_name)), string date)
    {
      if(!is_aggregate_running())
	// Check if the import thread is supposed to run.
	break;
      werror("%s: %s %s\n", query_name(), table_name, date);
      update_date(sql, date);
    }
    werror("%s: %s finished\n", query_name(), table_name);
  }
  
  static void create(Sql.sql sql)
  {
    available_fields = (multiset)sql->list_fields("access_log")->name |
		       // computed_fields is an array(array(string))
		       (multiset)computed_fields[*][0];
  }
}

class AggregateHits
{
  inherit Aggregate;

  string table_name = "aggregate_hits";

  array(array(string)) computed_fields = ({
    ({ "hits",            "INTEGER UNSIGNED", "COUNT(*) AS hits"     })
  });
    
  array(array(string)) optional_fields = ({
    ({ "length",          "BIGINT UNSIGNED",  "SUM(length)"          }),
    ({ "server_uptime",   "INTEGER UNSIGNED", "MAX(server_uptime)"   }),
    ({ "server_cputime",  "INTEGER UNSIGNED", "MAX(server_cputime)"  }),
    ({ "server_usertime", "INTEGER UNSIGNED", "MAX(server_usertime)" }),
    ({ "server_systime",  "INTEGER UNSIGNED", "MAX(server_systime)"  })
  });
  
  array(string) where_fields = ({
    "ip_number IS NOT NULL"
  });
}

class AggregatePerformance
{
  inherit Aggregate;

  string table_name = "aggregate_performance";

  array(array(string)) computed_fields = ({
    ({ "hits",                 "INTEGER UNSIGNED", "COUNT(*) AS hits" }),
    ({ "server_uptime_diff",   "INTEGER UNSIGNED", "NULL"             }),
    ({ "server_cputime_diff",  "INTEGER UNSIGNED", "NULL"             }),
    ({ "server_usertime_diff", "INTEGER UNSIGNED", "NULL"             }),
    ({ "server_systime_diff",  "INTEGER UNSIGNED", "NULL"             })
  });
    
  array(array(string)) optional_fields = ({
    ({ "length",          "BIGINT UNSIGNED",  "SUM(length)"           }),
  });
  
  array(array(string)) required_fields = ({
    ({ "eval_status",     0,                  0                       }),
    ({ "cache_status",    0,                  0                       }),
    ({ "server_uptime",   "INTEGER UNSIGNED", "MAX(server_uptime)"    }),
    ({ "server_cputime",  "INTEGER UNSIGNED", "MAX(server_cputime)"   }),
    ({ "server_usertime", "INTEGER UNSIGNED", "MAX(server_usertime)"  }),
    ({ "server_systime",  "INTEGER UNSIGNED", "MAX(server_systime)"   })
  });
  
  array(string) where_fields = ({
    "ip_number IS NOT NULL"
  });

  void post_update_date(Sql.sql sql, string date)
  {
    array(string) fields =
      sql->list_fields(table_name)->name & ({ "server_uptime",
					      "server_cputime",
					      "server_usertime",
					      "server_systime"  });
    if(!sizeof(fields))
      return;
    
    // Compute server_{up,cpu,user,sys}time differences. We prefer
    // NULL for the corner cases (beginning of the day), because
    // calculating that will complicate the code too much. Server
    // restarts are also not considered accurately.
    Sql.sql_result sql_result =
      sql->big_query("SELECT server_name, aggregate_id, " + (fields * ", ") +
		     "  FROM " + table_name +
		     " WHERE " + (map(fields, `+, " IS NOT NULL") * " AND ") +
		     " ORDER BY server_name, aggregate_id");
    mapping(string:array(string)) prev_row = ([]);
    array(string) row;
    while(row = sql_result->fetch_row())
    {
      string server_name = row[0];
      string aggregate_id = row[1];
      
      if(prev_row[server_name])
      {
	array(string) diff_row = ({});
	for(int i = 2; i < sizeof(row); i++)
	  diff_row += ({ (int)row[i] - (int)prev_row[server_name][i] });

	if(diff_row[0] >= 0)
	{
	  string query_def = "UPDATE " + table_name + " SET ";
	  foreach(fields; int i; string field)
	    query_def += (i ? ", " : "") + field + "_diff = " + diff_row[i];
	  query_def += " WHERE aggregate_id = " + aggregate_id;
	  sql->query(query_def);
	}
      }
      
      prev_row[server_name] = row;
    }
  }
}

class AggregateCache
{
  inherit Aggregate;

  string table_name = "aggregate_cache";

  array(array(string)) computed_fields = ({
    ({ "hits",                 "INTEGER UNSIGNED", "COUNT(*) AS hits" }),
    // eval_status
    ({ "eval_xslt",            "INTEGER UNSIGNED",
       "SUM(IF(LOCATE('xslt', eval_status), 1, 0))"                   }),
    ({ "eval_rxmlpcode",       "INTEGER UNSIGNED",
       "SUM(IF(LOCATE('rxmlpcode', eval_status), 1, 0))"              }),
    ({ "eval_rxmlsrc",         "INTEGER UNSIGNED",
       "SUM(IF(LOCATE('rxmlpsrc', eval_status), 1, 0))"               }),
    // cache_status
    ({ "cache_nocache",        "INTEGER UNSIGNED",
       "SUM(IF(LOCATE('nocache', cache_status), 1, 0))"               }),
    ({ "cache_protstore",      "INTEGER UNSIGNED",
       "SUM(IF(LOCATE('protstore', cache_status), 1, 0))"             }),
    ({ "cache_xsltcache",      "INTEGER UNSIGNED",
       "SUM(IF(LOCATE('xsltcache', cache_status), 1, 0))"             }),
    ({ "cache_pcoderam",       "INTEGER UNSIGNED",
       "SUM(IF(LOCATE('pcoderam', cache_status), 1, 0))"              }),
    ({ "cache_pcodedisk",       "INTEGER UNSIGNED",
       "SUM(IF(LOCATE('pcodedisk', cache_status), 1, 0))"             }),
    ({ "cache_cachetag",       "INTEGER UNSIGNED",
       "SUM(IF(LOCATE('pcodedisk', cache_status), 1, 0))"             }),
    ({ "cache_crawlondemand",       "INTEGER UNSIGNED",
       "SUM(IF(LOCATE('crawlondemand', cache_status), 1, 0))"         }),
    ({ "cache_crawlondemandbyotherthread",       "INTEGER UNSIGNED",
       "SUM(IF(LOCATE('crawlondemandbyotherthread', cache_status), 1, 0))"}),
    ({ "cache_protcache",      "INTEGER UNSIGNED",
       "SUM(IF(LOCATE('protcache', cache_status), 1, 0))"             }),
  });
  
  array(array(string)) optional_fields = ({
    ({ "length",          "BIGINT UNSIGNED",  "SUM(length)"           }),
    ({ "content_type",    "VARCHAR(32)",      "content_type"          })
  });
  
  array(array(string)) required_fields = ({
    ({ "eval_status",     0,                  0                       }),
    ({ "cache_status",    0,                  0                       }),
    ({ "response",        "INTEGER UNSIGNED", "response"              })
  });
  
  array(string) where_fields = ({
    "ip_number IS NOT NULL"
  });
    
  array(string) group_by_fields = ({
    "response",
    "content_type"
  });
}

class AggregateHosts
{
  inherit Aggregate;

  string table_name = "aggregate_hosts";

  array(array(string)) computed_fields = ({
    ({ "hits",            "INTEGER UNSIGNED", "COUNT(*) AS hits"     })
  });
  
  array(array(string)) required_fields = ({
    ({ "host",            "VARCHAR(64)",      "host"                 }),
    ({ "response",        "INTEGER UNSIGNED", "response"             })
  });
    
  array(array(string)) optional_fields = ({
    ({ "length",          "BIGINT UNSIGNED",  "SUM(length)"          }),
    ({ "cache_status",    "VARCHAR(64)",      "cache_status"         }),
    ({ "eval_status",     "VARCHAR(64)",      "eval_status"          }),
    ({ "content_type",    "VARCHAR(32)",      "content_type"         })
  });
    
  array(string) group_by_fields = ({
    "host",
    "response",
    "cache_status",
    "eval_status",
    "content_type"
  });
}

class AggregateResources
{
  inherit Aggregate;

  string table_name = "aggregate_resources";

  array(array(string)) computed_fields = ({
    ({ "hits",            "INTEGER UNSIGNED", "COUNT(*) AS hits"     }),
    ({ "resource_path",   "VARCHAR(255)",
       "            SUBSTRING_INDEX(resource, '?', 1) as resource_path"               }),
    ({ "resource_query",  "VARCHAR(255)",
       "            SUBSTRING(resource,\n"
       "                      1+LENGTH(SUBSTRING_INDEX(resource, '?', 1))) as resource_query" })
  });
  
  array(array(string)) required_fields = ({
    ({ "resource",        0,                  0                      }),
    ({ "response",        "INTEGER UNSIGNED", "response"             })
  });
    
  array(array(string)) optional_fields = ({
    ({ "length",          "BIGINT UNSIGNED",  "SUM(length)"          }),
    ({ "cache_status",    "VARCHAR(64)",      "cache_status"         }),
    ({ "eval_status",     "VARCHAR(64)",      "eval_status"          }),
    ({ "content_type",    "VARCHAR(32)",      "content_type"         })
  });
    
  array(string) group_by_fields = ({
    "resource_path",
    "resource_query",
    "response",
    "cache_status",
    "eval_status",
    "content_type"
  });
}

class AggregateResourceDirs
{
  inherit Aggregate;

  string table_name = "aggregate_resource_dirs";
  
  array(array(string)) computed_fields = ({
    ({ "hits",            "INTEGER UNSIGNED", "COUNT(*) AS hits"     }),
    ({ "resource_dir",    "VARCHAR(255)",
       "            REVERSE(SUBSTRING(REVERSE(resource),\n"
       "                              LOCATE('/',\n"
       "                                     REVERSE(resource)))) AS resource_dir"   })
  });
  
  array(array(string)) required_fields = ({
    ({ "resource",        0,                  0                      }),
    ({ "response",        "INTEGER UNSIGNED", "response"             })
  });
    
  array(array(string)) optional_fields = ({
    ({ "length",          "BIGINT UNSIGNED",  "SUM(length)"          }),
    ({ "cache_status",    "VARCHAR(64)",      "cache_status"         }),
    ({ "eval_status",     "VARCHAR(64)",      "eval_status"          }),
    ({ "content_type",    "VARCHAR(32)",      "content_type"         })
  });
    
  array(string) group_by_fields = ({
    "resource_dir",
    "response",
    "cache_status",
    "eval_status",
    "content_type"
  });
}
