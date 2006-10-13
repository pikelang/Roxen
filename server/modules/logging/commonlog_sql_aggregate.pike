// Common Log SQL Aggregate module
// $Id: commonlog_sql_aggregate.pike,v 1.1 2006/10/13 12:40:04 noring Exp $

#include <module.h>

inherit "module";
inherit "roxenlib";

#define LOCALE(X,Y)	_STR_LOCALE("sql_log_aggregate",X,Y)
#define DLOCALE(X,Y)    _DEF_LOCALE("sql_log_aggregate",X,Y)

constant thread_safe = 1;
constant module_unique = 0;
constant module_type = MODULE_PROVIDER;
constant cvs_version = "$Id: commonlog_sql_aggregate.pike,v 1.1 2006/10/13 12:40:04 noring Exp $";

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
  
  aggregate_summary(sql, query("minute_granularity"));
  aggregate_hosts(sql);
  aggregate_resources(sql);
  aggregate_resources_dir(sql);
  // FIXME: aggregate_thread = Thread.thread_create();
}

mapping(string:int) last_access_log_row_id_per_date(Sql.sql sql)
{
  mapping res = ([]);
  foreach(sql->query("SELECT MAX(log_row_id) AS last_log_row_id,\n"
		     "       date\n"
		     "  FROM access_log\n"
		     " GROUP BY date\n"), mapping r)
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

void aggregate_summary(Sql.sql sql, int minute_granularity)
{
  constant table_name = "aggregate_summary";

  werror("%s: %s starting\n", query_name(), table_name);
    
  constant optional_fields = ({
    ({ "length",          "BIGINT UNSIGNED",  "SUM(length)"          }),
    ({ "server_uptime",   "INTEGER UNSIGNED", "MAX(server_uptime)"   }),
    ({ "server_cputime",  "INTEGER UNSIGNED", "MAX(server_cputime)"  }),
    ({ "server_usertime", "INTEGER UNSIGNED", "MAX(server_usertime)" }),
    ({ "server_systime",  "INTEGER UNSIGNED", "MAX(server_systime)"  })
  });

  multiset(string) available_fields =
    (multiset)sql->list_fields("access_log")->name;

  string table_def = "CREATE TABLE IF NOT EXISTS "+table_name+"\n"
		     "(aggregate_id INTEGER NOT NULL AUTO_INCREMENT,\n"
		     " last_log_row_id BIGINT NOT NULL,\n"
		     " server_name VARCHAR(32),\n"
		     " date DATE,\n"
		     " time DATETIME,\n"
		     " hits INTEGER UNSIGNED,\n";
  foreach(optional_fields, array(string) field)
    if(available_fields[field[0]])
      table_def += field[0] + " " + field[1] + ",\n";
  table_def += "PRIMARY KEY (aggregate_id),\n"
	       "INDEX (date),\n"
	       "INDEX (server_name),\n"
	       "INDEX (server_name, date))\n";
  sql->query(table_def);

  foreach(sort(updated_dates(sql, table_name)), string date)
  {
    werror("%s: %s %s\n", query_name(), table_name, date);

    sql->query("DELETE FROM "+table_name+" WHERE date = %s", date);
    
    string query_def = "INSERT INTO "+table_name+"\n"
		       "           (last_log_row_id,\n"
		       "            server_name,\n"
		       "            date,\n"
		       "            time,\n"
		       "            hits";
    foreach(optional_fields, array(string) field)
      if(available_fields[field[0]])
	query_def += ",\n            " + field[0];
    query_def += ")\n"
		 "     SELECT MAX(log_row_id),\n"
		 "            server_name,\n"
		 "            date,\n"
		 "            CONCAT(DATE_FORMAT(time, '%Y-%m-%d %H:'),\n"
		 "                   FLOOR(MINUTE(time)/"+minute_granularity+")*"+minute_granularity+") AS time_granularity,\n"
	       "            COUNT(*)";
    foreach(optional_fields, array(string) field)
      if(available_fields[field[0]])
	query_def += ",\n            " + field[2];
    query_def += "\n"
		 "       FROM access_log,\n"
		 "            log_files\n"
		 "      WHERE access_log.date = '"+sql->quote(date)+"'\n"
		 "        AND access_log.log_file_id = log_files.log_file_id\n"
		 "   GROUP BY server_name,\n"
		 "            time_granularity";
    
    sql->query(query_def + "\n");
  }
  
  werror("%s: %s finished\n", query_name(), table_name);
}

void aggregate_hosts(Sql.sql sql)
{
  constant table_name = "aggregate_hosts";
  
  werror("%s: %s starting\n", query_name(), table_name);
    
  constant optional_fields = ({
    ({ "length",          "BIGINT UNSIGNED",  "SUM(length)"          }),
    ({ "response",        "INTEGER UNSIGNED", "response"             })
  });

  multiset(string) available_fields =
    (multiset)sql->list_fields("access_log")->name;

  // "host" is a required field.
  if(!available_fields["host"])
    return;
  
  string table_def = "CREATE TABLE IF NOT EXISTS "+table_name+"\n"
		     "(aggregate_id INTEGER NOT NULL AUTO_INCREMENT,\n"
		     " last_log_row_id BIGINT NOT NULL,\n"
		     " server_name VARCHAR(32),\n"
		     " date DATE,\n"
		     " host VARCHAR(64),\n"
		     " hits INTEGER UNSIGNED,\n";
  foreach(optional_fields, array(string) field)
    if(available_fields[field[0]])
      table_def += field[0] + " " + field[1] + ",\n";
  table_def += "PRIMARY KEY (aggregate_id),\n"
	       "INDEX (date),\n"
	       "INDEX (server_name),\n"
	       "INDEX (server_name, date))\n";
  sql->query(table_def);

  foreach(sort(updated_dates(sql, table_name)), string date)
  {
    werror("%s: %s %s\n", query_name(), table_name, date);

    sql->query("DELETE FROM "+table_name+" WHERE date = %s", date);
    
    string query_def = "INSERT INTO "+table_name+"\n"
		       "           (last_log_row_id,\n"
		       "            server_name,\n"
		       "            date,\n"
		       "            host,\n"
		       "            hits";
    foreach(optional_fields, array(string) field)
      if(available_fields[field[0]])
	query_def += ",\n            " + field[0];
    query_def += ")\n"
		 "     SELECT MAX(log_row_id),\n"
		 "            server_name,\n"
		 "            date,\n"
		 "            host,\n"
		 "            COUNT(*) AS hits";
    foreach(optional_fields, array(string) field)
      if(available_fields[field[0]])
	query_def += ",\n            " + field[2];
    query_def += "\n"
		 "       FROM access_log,\n"
		 "            log_files\n"
		 "      WHERE access_log.date = '"+sql->quote(date)+"'\n"
		 "        AND access_log.log_file_id = log_files.log_file_id\n"
		 "   GROUP BY server_name,\n"
		 "            host";
    foreach(optional_fields, array(string) field)
      if(available_fields[field[0]] && field[0] == field[2])
	query_def += ",\n            " + field[0];
    
    sql->query(query_def + "\n");
  }
  
  werror("%s: %s finished\n", query_name(), table_name);
}

class Aggregate
{
  string table_name;
  
  array(array(string)) computed_fields = ({});
  array(array(string)) requried_fields = ({});
  array(array(string)) optional_fields = ({});
        array(string)  group_by_fields = ({});
  
  multiset(string) available_fields;

  void create_table_if_not_exist(Sql.sql sql)
  {
    string table_def = "CREATE TABLE IF NOT EXISTS "+table_name+"\n"
		       "(aggregate_id INTEGER NOT NULL AUTO_INCREMENT,\n"
		       " last_log_row_id BIGINT NOT NULL,\n"
		       " server_name VARCHAR(32),\n"
		       " date DATE,\n";
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
  }

  int is_available()
  {
    return !sizeof(required_fields - (array)available_fields);
  }

  void update_date(Sql.sql sql, string date)
  {
    sql->query("DELETE FROM "+table_name+" WHERE date = %s", date);
    
    string query_def = "INSERT INTO "+table_name+"\n"
		       "           (last_log_row_id,\n"
		       "            server_name,\n"
		       "            date";
    foreach(computed_fields +
	    required_fields +
	    optional_fields, array(string) field)
      if(field[2] && available_fields[field[0]])
	query_def += ",\n            " + field[0];
    query_def += ")\n"
		 "     SELECT MAX(log_row_id),\n"
		 "            server_name,\n"
		 "            date";
    foreach(computed_fields +
	    required_fields +
	    optional_fields, array(string) field)
      if(field[2] && available_fields[field[0]])
	query_def += ",\n            " + field[2];
    query_def += "\n"
		 "       FROM access_log,\n"
		 "            log_files\n"
		 "      WHERE access_log.date = '"+sql->quote(date)+"'\n"
		 "        AND access_log.log_file_id = log_files.log_file_id\n"
		 "   GROUP BY server_name";
    foreach(group_by_fields, array(string) field)
      if(available_fields[field[0]])
	query_def += ",\n            " + field[0];
    
    sql->query(query_def + "\n");
  }

  void update(Sql.sql sql)
  {
    werror("%s: %s starting\n", query_name(), table_name);
    foreach(sort(updated_dates(sql, table_name)), string date)
    {
      werror("%s: %s aggregating %s\n", query_name(), table_name, date);
      update_date(sql, date);
    }
    werror("%s: %s finished\n", query_name(), table_name);
  }
  
  static void create(Sql.sql sql)
  {
    available_fields = (multiset)sql->list_fields("access_log")->name |
		       (multiset)computed_fields;
  }
}

// FIXME: Add time with minute granularity.
class AggregateSummary
{
  inherit Aggregate;

  string table_name = "aggregate_summary";

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
}

// FIXME: Add time with hour granularity.
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

// FIXME: Add time with hour granularity.
class AggregateResources
{
  inherit Aggregate;

  string table_name = "aggregate_resources";

  array(array(string)) computed_fields = ({
    ({ "hits",            "INTEGER UNSIGNED", "COUNT(*) AS hits"     }),
    ({ "resource_path",   "VARCHAR(255)",
       "            SUBSTRING_INDEX(resource, '?', 1)"               }),
    ({ "resource_query",  "VARCHAR(255)",
       "            SUBSTRING(resource,\n"
       "                      1+LENGTH(SUBSTRING_INDEX(resource, '?', 1)))" })
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

// FIXME: Add time with hour granularity.
class AggregateResourceDirs
{
  inherit Aggregate;

  string table_name = "aggregate_resource_dirs";
  
  array(array(string)) computed_fields = ({
    ({ "hits",            "INTEGER UNSIGNED", "COUNT(*) AS hits"     }),
    ({ "resource_dir",    "VARCHAR(255)",
       "            REVERSE(SUBSTRING(REVERSE(resource),\n"
       "                              LOCATE('/',\n"
       "                                     REVERSE(resource))))"   })
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
