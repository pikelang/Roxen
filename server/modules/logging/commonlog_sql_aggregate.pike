// Common Log SQL Aggregate module
// $Id: commonlog_sql_aggregate.pike,v 1.2 2006/10/17 12:07:30 simon Exp $

#include <module.h>

inherit "module";
inherit "roxenlib";

#define LOCALE(X,Y)	_STR_LOCALE("sql_log_aggregate",X,Y)
#define DLOCALE(X,Y)    _DEF_LOCALE("sql_log_aggregate",X,Y)

constant thread_safe = 1;
constant module_unique = 0;
constant module_type = MODULE_PROVIDER;
constant cvs_version = "$Id: commonlog_sql_aggregate.pike,v 1.2 2006/10/17 12:07:30 simon Exp $";

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

  
  Aggregate aggregate_hits_and_cpu_time = AggregateHitsAndCpuTime( sql );
  //aggregate_hits_and_cpu_time->create_table_if_not_exist( sql );
  //aggregate_hits_and_cpu_time->update_date( sql, "2006-10-10" );
  
  Aggregate aggregate_distinct_hits = AggregateDistinctHits( sql );
  //aggregate_distinct_hits->create_table_if_not_exist( sql );
  //aggregate_distinct_hits->update_date( sql, "2006-10-10" );

  
  Aggregate aggregate_cached_hits = AggregateCachedHits( sql );
  //  aggregate_cached_hits->create_table_if_not_exist( sql );
  //aggregate_cached_hits->update_date( sql, "2006-10-10" );

  //  Aggregate aggregate_eval_hits = AggregateEvalHits( sql );
  //  aggregate_eval_hits->create_table_if_not_exist( sql );
  //aggregate_eval_hits->update_date( sql, "2006-10-10" );

  Aggregate aggregate_resources = AggregateResources( sql );
  //  aggregate_resources->create_table_if_not_exist( sql );
  //aggregate_resources->update_date( sql, "2006-10-10" );

  Aggregate aggregate_cache_type = AggregateCacheType( sql );
  aggregate_cache_type->create_table_if_not_exist( sql );
  aggregate_cache_type->update_date( sql, "2006-10-10" );
}

void aggregate_start() 
{
  int purge_days = query("acces_log_purge_days");
  int log_time_cutoff;
  if(purge_days)
    log_time_cutoff = time() - purge_days*24*60*60;

  string log_format = query("alt_LogFormat");
  if(!sizeof(log_format))
    log_format = conf->query("LogFormat");

  aggregate_thread = Thread.thread_create( );
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

class Aggregate
{
  string table_name;
  
  array(array(string)) computed_fields = ({});
  array(array(string)) required_fields = ({});
  array(array(string)) optional_fields = ({});
        array(string)  group_by_fields = ({});
  
  multiset(string) available_fields;

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
			optional_fields, array(string) field) {
      if(field[1] && available_fields[field[0]]) {
		table_def += field[0] + " " + field[1] + ",\n";
	  }
	}
    table_def += "PRIMARY KEY (aggregate_id),\n"
		 "INDEX (date),\n"
		 "INDEX (server_name),\n"
		 "INDEX (server_name, date))\n";
	
	write( "#####################\n" );
	write( table_def + "\n" );
	write( "#####################\n" );
	sql->query(table_def);
  }

  int is_available()
  {
    return !sizeof(required_fields - (array)available_fields);
  }

  void update_date(Sql.sql sql, string date )
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
		 "        AND access_log.log_file_id = log_files.log_file_id\n"
		 "   GROUP BY server_name, time_granularity";
    foreach(group_by_fields, string field) {
      if(available_fields[field]) {
		query_def += ",\n            " + field;
	  }
    }
	
	write( "#####################\n" );
	write( query_def + "\n" );
	write( "#####################\n" );
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
	  (multiset)computed_fields[*][0]; // computed_fields is an array(array(string))
  }
}

// FIXME: Add time with minute granularity.
class AggregateDistinctHits
{

  /**
select hour, minute, (max_server_cputime-min_server_cputime) as cpu_time from aggregate_summary order by hour asc, minute asc;
   */
  inherit Aggregate;

  string table_name = "aggregate_distinct_hits";

  // distinct_hits may want to be tuned to include params as well
  array(array(string)) computed_fields = ({
	({ "unique_file_resources",       "INTEGER UNSIGNED", "COUNT( DISTINCT replace(resource, substring(resource, locate('?', resource), length(resource)), '' ) )" }),
	({ "unique_resources",       "INTEGER UNSIGNED", "COUNT( DISTINCT resource )" }),
    ({ "max_server_cputime",  "INTEGER UNSIGNED", "MAX(server_cputime) as max_server_cputime"  }),
    ({ "min_server_cputime",  "INTEGER UNSIGNED", "MIN(server_cputime) as min_server_cputime"  })
  });
    
  //  array(string) group_by_fields = ({
  //  "resource"
  //});
}

class AggregateHitsAndCpuTime
{

  /**
select time_granularity, (max_server_cputime-min_server_cputime)/5 as cpu_time from aggregate_summary_minute order by hour asc, minute asc;
   */
  inherit Aggregate;

  string table_name = "aggregate_hits_and_cpu_time";

  array(array(string)) computed_fields = ({
    ({ "hits",                "INTEGER UNSIGNED", "COUNT(*) AS hits"     }),
    ({ "max_server_cputime",  "INTEGER UNSIGNED", "MAX(server_cputime) as max_server_cputime"  }),
    ({ "min_server_cputime",  "INTEGER UNSIGNED", "MIN(server_cputime) as min_server_cputime"  })
  });
    
  array(array(string)) optional_fields = ({
    ({ "length",          "BIGINT UNSIGNED",  "SUM(length)"          }),
    ({ "server_uptime",   "INTEGER UNSIGNED", "MAX(server_uptime)"   }),
    ({ "server_usertime", "INTEGER UNSIGNED", "MAX(server_usertime)" }),
    ({ "server_systime",  "INTEGER UNSIGNED", "MAX(server_systime)"  })
  });
}

// FIXME: Add time with minute granularity.
class AggregateCachedHits
{

  /**
select hour, minute, (max_server_cputime-min_server_cputime) as cpu_time from aggregate_summary order by hour asc, minute asc;
   */
  inherit Aggregate;

  string table_name = "aggregate_cached_hits";

  // distinct_hits may want to be tuned to include params as well
  array(array(string)) computed_fields = ({
	({ "cached_hits",         "INTEGER UNSIGNED", "COUNT(*) as cached_hits" }),
    ({ "max_server_cputime",  "INTEGER UNSIGNED", "MAX(server_cputime) as max_server_cputime"  }),
    ({ "min_server_cputime",  "INTEGER UNSIGNED", "MIN(server_cputime) as min_server_cputime"  })
  });
    

  array(array(string)) required_fields = ({
    ({ "cache_status",    "VARCHAR(64)",      "IF( LOCATE( 'rxml', cache_status ), CONCAT( 'rxml', IF( LOCATE( 'xslt', cache_status ), '_xslt', '') ), IF( LOCATE( 'xslt' ), 'xslt', '' ), 'other' ) AS cache_status"                 })
  });

  array(string) group_by_fields = ({
    "cache_status"
  });
}

class AggregateEvalType
{
  inherit Aggregate;

  string table_name = "aggregate_eval_type";

  // distinct_hits may want to be tuned to include params as well
  array(array(string)) computed_fields = ({
	({ "eval_hits",            "INTEGER UNSIGNED", "COUNT(*) as eval_hits" }),
    ({ "eval_class_rxmlpcode", "INTEGER UNSIGNED", "IF( LOCATE( 'rxmlpcode', eval_status ), 1, 0 ) as eval_class_rxmlpcode" }),
    ({ "eval_class_rxmlsrc",   "INTEGER UNSIGNED", "IF( LOCATE( 'rxmlsrc', eval_status ), 1, 0 ) as eval_class_rxmlsrc" }),
    ({ "eval_class_xslt",      "INTEGER UNSIGNED", "IF( LOCATE( 'xslt', eval_status ), 1, 0 ) as eval_class_xslt" })
  });
    
  array(array(string)) required_fields = ({
	({ "eval_status",          "VARCHAR(64)",      "eval_status" }),
  });

  array(string) group_by_fields = ({
	"eval_class_rxml",
	"eval_class_xslt",
	"eval_status"
  });
}

class AggregateCacheType
{
  inherit Aggregate;

  string table_name = "aggregate_cache_type";

  // distinct_hits may want to be tuned to include params as well
  array(array(string)) computed_fields = ({
	({ "cache_hits",                            "INTEGER UNSIGNED", "COUNT(*) as eval_hits" }),
    ({ "cache_class_pcodedisk",                  "INTEGER UNSIGNED", "IF( LOCATE( 'pcodedisk', cache_status ), 1, 0 ) as cache_class_pcodedisk" }),
    ({ "cache_class_nocache",                    "INTEGER UNSIGNED", "IF( LOCATE( 'nocache', cache_status ), 1, 0 ) as cache_class_nocache" }),
    ({ "cache_class_protcache",                  "INTEGER UNSIGNED", "IF( LOCATE( 'protcache', cache_status ), 1, 0 ) as cache_class_protcache" }),
    ({ "cache_class_cachetag",                   "INTEGER UNSIGNED", "IF( LOCATE( 'cachetag', cache_status ), 1, 0 ) as cache_class_cachetag" }),
    ({ "cache_class_crawlondemand",              "INTEGER UNSIGNED", "IF( LOCATE( 'crawlondemand', cache_status ), 1, 0 ) as cache_class_crawlondemand" }),
    ({ "cache_class_crawlondemandbyotherthread", "INTEGER UNSIGNED", "IF( LOCATE( 'crawlondemandbyotherthread', cache_status ), 1, 0 ) as cache_class_crawlondemandbyotherthread" })
  });
    
  array(array(string)) required_fields = ({
	({ "cache_status",          "VARCHAR(64)",      "cache_status" }),
  });

  array(string) group_by_fields = ({
	"cache_class_pcodedisk",
	"cache_class_nocache",
	"cache_class_protcache",
	"cache_class_cachetag",
	"cache_class_crawlondemand",
	"cache_class_crawlondemandbyotherthread",
	"cache_status"
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

