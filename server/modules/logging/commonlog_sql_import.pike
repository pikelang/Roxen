// Common Log SQL Import module
// $Id: commonlog_sql_import.pike,v 1.2 2006/10/17 11:31:36 simon Exp $

#include <module.h>

inherit "module";
inherit "roxenlib";

#define LOCALE(X,Y)	_STR_LOCALE("commonlog_sql_log_import",X,Y)
#define DLOCALE(X,Y)    _DEF_LOCALE("commonlog_sql_log_import",X,Y)

constant thread_safe = 1;
constant module_unique = 0;
constant module_type = MODULE_PROVIDER;
constant cvs_version = "$Id: commonlog_sql_import.pike,v 1.2 2006/10/17 11:31:36 simon Exp $";

LocaleString module_group_name = DLOCALE(0,"SQL Log:");
LocaleString module_generic_name = DLOCALE(0, "Common Log Import module");
LocaleString module_name = module_group_name + " " + module_generic_name;

LocaleString module_doc = DLOCALE(0,#"
<p>This is the Common Log to SQL Log Import module.</p>");

void create(Configuration conf)
{
  defvar("db_name",
	 Variable.DatabaseChoice("log",
				 VAR_INITIAL,
				 DLOCALE(0, "Log database"),
				 DLOCALE(0, "The database where all "
					 "log data is stored."))
	 ->set_configuration_pointer(my_configuration));

  defvar("update_hour", "05", "Import hour", TYPE_MULTIPLE_STRING,
	 "Hour during the day when to start importing logs, "
	 "'Every hour' or 'Never'.",
	 ({ "Never" }) + ({ "Every hour" }) +
	 Array.map(indices(allocate(24)),
		   lambda(int h) { return sprintf("%02d", h); }));
  
  defvar("alt_server_name", "",
	 DLOCALE(0, "Alternate server name"),
	 TYPE_STRING,
	 DLOCALE(0, "If filled in, imports are done under this alternate "
		 "server name instead of the default name of this server."));

  defvar("alt_import_glob_paths", ({}),
	 DLOCALE(0, "Alternate import glob paths"),
         TYPE_STRING_LIST,
	 DLOCALE(0, "If filled in, imports are made from log files matching "
		 "these glob paths instead of using the default log files "
		 "for this server."));

  defvar("alt_LogFormat", "",
	 DLOCALE(0, "Alternate log format"),
	 TYPE_TEXT_FIELD|VAR_MORE,
	 DLOCALE(0, "If filled in, this log format is used instead of the "
		 "default Logging Format under the Logging tab for this "
		 "server. The syntax is the same as for the Logging Format. "
		 "Example:"
		 "<pre>404: $host $referer - [$cern_date] \"$method $resource $protocol\" 404 -\n"
		 "500: $host $referer ERROR [$cern_date] \"$method $resource $protocol\" 500 -\n"
		 "*: $host - - [$cern_date] \"$method $resource $protocol\" $response $length</pre>"));
  
  defvar("alt_sql_LogFormat", "",
	 DLOCALE(0, "Alternate database fields"),
	 TYPE_TEXT_FIELD|VAR_MORE,
	 DLOCALE(0, "If filled in, the database will use these fields, "
		 "instead of the default fields, when created. "
		 "The syntax is the same as for the Logging Format. Example:"
		 "<pre>404: $host $referer - [$cern_date] \"$method $resource $protocol\" 404 -\n"
		 "500: $host $referer ERROR [$cern_date] \"$method $resource $protocol\" 500 -\n"
		 "*: $host - - [$cern_date] \"$method $resource $protocol\" $response $length</pre>"));

  defvar("acces_log_purge_days", 0,
	 DLOCALE(0, "Purge old log entries"),
	 TYPE_INT,
	 DLOCALE(0, "If zero, imported log entries are never purged "
		 "from the database by this module. If larger than zero, "
		 "imported log entries older than this number of days are "
		 "purged from the database."));

  defvar("decompressor_programs",
	 ({ ".bz2:/usr/bin/bzcat", ".gz:/usr/bin/gzcat" }),
	 DLOCALE(0, "Log file decompress programs"),
         TYPE_STRING_LIST,
	 DLOCALE(0, "List of compression file extensions and paths to programs "
		 "for decompression. The programs must accept one compressed "
		 "file argument and decompress on standard output. "
		 "Example: <tt>.bz2:/usr/bin/bzcat</tt>"));
}

string query_name()
{
  return module_group_name + " "+
         DLOCALE(0, "Import") +" \"" + get_server_name() + "\"";
}

string get_server_name()
{
  string alt_server_name = query("alt_server_name");
  if(sizeof(alt_server_name))
    return alt_server_name;
  return conf->query_name();
}

string status()
{
  string msg = "";
  Sql.sql sql = get_log_db();
  
  if(!sql)
    return msg +
           "<p style='color: red;'>No database. Click on the "
           "'<b>Create local log database</b>' button to "
           "create a local log database. Alternatively, make a remote "
           "database connection through the DB Manager.</p>";

  if(!has_log_tables(sql))
    return msg +
           "<p style='color: red;'>No access log table. Click on the "
           "'<b>Create access log table</b>' button to "
           "create this table with the following fields as currently defined "
           "by the <b>Logging Format</b> setting:</p>"
           "<pre>"+
           log_import->
             access_log_fields_from_format(conf->query("LogFormat")/"\n")*"\n"+
           "</pre>";

  msg += "<p><b>Import status:</b> "+import_status()+"<br/>"
	 "<b>Last imported data:</b> "+
	 (last_import_time() || "No imports have been done yet")+"<br/>"
	 "<b>Importing with server name:</b> "+get_server_name()+"</p>"
	 "<p><i>Note! The server name must be unique for all "
	 "servers (frontends etc.) importing to the same log database.</i></p>";

  msg += "<p><b>Fields in the \"access_log\" table for the "
	 "database \""+db_name+"\":</b></p>"
	 "<pre>"+log_import->access_log_fields_from_db(sql)*"\n"+"</pre>";

  array(mapping) log_file_db_status =
    log_import->log_file_status(sql, get_server_name());
  mapping log_file_status =
    mkmapping(log_file_db_status->log_file_path, log_file_db_status);
  foreach(log_file_list(), string log_file_path)
    if(!log_file_status[log_file_path])
      log_file_status[log_file_path] = ([]);
  msg += "<table border='1px' width='100%'>"
	 "<tr><td><b>Log files for \""+get_server_name()+"\"</b></td>"
	 "<td align='right'><b>Last row</b></td></tr>";
  foreach(reverse(sort(indices(log_file_status))), string log_file_path)
    msg += "<tr><td><tt>"+log_file_path+"</tt></td>"
	   "<td align='right'>"
	   +(log_file_status[log_file_path]->max_log_row || "-")+
	   "</td></tr>";
  msg += "</table>";
  
  return msg;
}

LogImport log_import = LogImport();
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

void create_access_log_table()
{
  Sql.sql sql = get_log_db();
  if(!sql)
  {
    report_error("Cannot create access log table: "
		 "No log database present: %O\n", db_name);
    return;
  }
  log_import->create_log_files_table(sql);

  string log_format = query("alt_sql_LogFormat");
  if(!sizeof(log_format))
    log_format = conf->query("LogFormat");
  log_import->create_access_log_table(sql, log_format/"\n");
}

void create_log_db()
{
  if(get_log_db())
    return;

  mapping perms = DBManager.get_permission_map()[db_name];
  if(perms && perms[conf->name] == DBManager.NONE)
  {
    report_error("No permission to read log database: %s\n", db_name);
    return;
  }
    
  report_notice("No log database present. Creating %O.\n", db_name);
  DBManager.create_db(db_name, 0, 1);
  DBManager.set_permission(db_name, conf, DBManager.WRITE);
  perms = DBManager.get_permission_map()[db_name];
  DBManager.is_module_db(0, db_name, "Used by the Common Log SQL Import module "
			 "to store its data.");
  if(!get_log_db())
    report_error("Unable to create log database.\n");
}

void start(int when, Configuration _conf)
{
  conf = _conf;
  db_name = query("db_name");
  
  schedule_import();
}

void stop_import_schedule()
{
  while(!zero_type(remove_call_out(run_scheduled_import)))
    ;
}

void schedule_import()
{
  stop_import_schedule();
  
  string hour = query("update_hour");
  switch(hour)
  {
    case "Never":
      return;

    case "Every hour":
      call_out(run_scheduled_import, 3600 - time(1)%3600);
      break;

    default:
      int time_offset;
      
      mapping t = localtime(time());
      time_offset = (((24 + (int)hour - t->hour) % 24)*60 - t->min)*60 - t->sec;
      if(time_offset <= 0)
	time_offset += 24*60*60;

      call_out(run_scheduled_import, time_offset);
  }
}

void run_scheduled_import()
{
  schedule_import();
  import_start();
}

void stop()
{
  stop_import_schedule();
  import_stop();
}

void ready_to_receive_requests(Configuration conf)
{
}

mapping(string:function) query_action_buttons()
{
  mapping buttons = ([]);

  Sql.sql sql = get_log_db();
  if(!sql)
    buttons["Create local log database"] = create_log_db;
  else if(!has_log_tables(sql))
    buttons["Create access log table"] = create_access_log_table;
  else if(sql)
  {
    if(is_import_running())
      buttons["Import STOP!"] = import_stop;
    else
      buttons["Import now!"] = import_start;
    buttons["Remove unused log files"] = cleanup_log_file_table;
  }
  
  return buttons;
}

void cleanup_log_file_table()
{
  Sql.sql sql = get_log_db();
  if(!sql)
  {
    report_error("Cannot import. No log database present: %O\n", db_name);
    return;
  }
  log_import->cleanup_log_file_table(sql, get_server_name());
}

Thread.Thread import_thread;

int is_import_running()
{
  return import_thread && !import_thread->status();
}

string import_status()
{
  if(is_import_running())
    return "Import is running";
  return "Waiting";
}

void import_stop()
{
  import_thread = 0;
}

void import_start()
{
  Sql.sql sql = get_log_db();
  if(!sql)
  {
    report_error("Cannot import. No log database present: %O\n", db_name);
    return;
  }
  
  int purge_days = query("acces_log_purge_days");
  int log_time_cutoff;
  if(purge_days)
    log_time_cutoff = time() - purge_days*24*60*60;
  string log_format = query("alt_LogFormat");
  if(!sizeof(log_format))
    log_format = conf->query("LogFormat");

  if(is_import_running())
    return;
  import_thread = Thread.thread_create(log_import->import_log_files,
				       sql, get_server_name(), log_file_list(),
				       log_time_cutoff, log_format/"\n",
				       query("decompressor_programs"));
}

string last_import_time()
{
  Sql.sql sql = get_log_db();
  if(!sql)
    return 0;
  array(mapping) res = sql->query("SELECT MAX(last_import_time) "
				  "         AS last_import_time "
				  "  FROM log_files "
				  " WHERE server_name = %s",
				  get_server_name());
  if(res && sizeof(res) == 1)
    return res[0]->last_import_time;
  return 0;
}

array(string) default_log_file_list()
{
  string default_log_file = roxen_path(conf->query("LogFile"));
  array(string) log_files = ({});
  string dir = dirname(default_log_file);

  array(string) log_file_extensions = ({});
  if(sizeof(conf->query("LogFileCompressor") || ""))
    foreach(query("decompressor_programs"), string compressor)
      if(sscanf(compressor, "%s:", string extension))
	log_file_extensions += ({ extension });
  
  foreach(get_dir(dir) || ({}), string filename_candidate)
  {
    if(Regexp("^"+replace(basename(default_log_file),
			  ({ ".", "%y", "%m", "%d", "%h", "%H" }),
			  ({ "\\.", "[0-9][0-9][0-9][0-9]", "[0-9][0-9]",
			     "[0-9][0-9]", "[0-9][0-9]", "(.+)" }))+
	      "("+(map(log_file_extensions, replace, ".", "\\.")*"|")+")"+
	      "$")->match(filename_candidate))
    {
      string log_file = combine_path(dir, filename_candidate);
      log_files += ({ log_file });
    }
  }
  return log_files;
}

array(string) alt_log_file_list(array(string) glob_paths)
{
  array(string) log_files = ({});
  foreach(glob_paths, string glob_path)
  {
    string dir = dirname(glob_path);
    foreach(get_dir(dir) || ({}), string filename_candidate)
      if(glob(basename(glob_path), filename_candidate))
	log_files += ({ combine_path(dir, filename_candidate) });
  }
  return log_files;
}

array(string) log_file_list()
{
  if(sizeof(query("alt_import_glob_paths")))
    return alt_log_file_list(query("alt_import_glob_paths"));
  return default_log_file_list();
}

class LogField(string clf_field,
	       string sscanf_field,
	       string sql_field,
	       string sql_definition,
	       function|void format_conversion_f)
{
}

class LogImport
{
  string bin_ip_number_to_ascii(int bin_ip_number)
  {
    return sprintf("%d.%d.%d.%d",
		   (bin_ip_number >> 24) % 256,
		   (bin_ip_number >> 16) % 256,
		   (bin_ip_number >>  8) % 256,
		   (bin_ip_number >>  0) % 256);
  }
  
  int cern_date_to_unix(array(array(int)) cern_date)
  {
    constant month_names = ([ "Jan":1,
			      "Feb":2,
			      "Mar":3,
			      "Apr":4,
			      "May":5,
			      "Jun":6,
			      "Jul":7,
			      "Aug":8,
			      "Sep":9,
			      "Oct":10,
			      "Nov":11,
			      "Dec":12 ]);

    [int mday, string mon_name, int year,
     int hour, int min, int sec, int timezone] = cern_date[0];
    
    if(!month_names[mon_name])
      error("Bad month %O\n", mon_name);
    return mktime(([ "sec"      : sec,
		     "min"      : min,
		     "hour"     : hour,
		     "mday"     : mday,
		     "mon"      : month_names[mon_name] - 1,
		     "year"     : year - 1900,
		     "timezone" : -((timezone%100) + ((timezone/100)*3600)) ]));
  }
  
  array(LogField) clf_format = ({
    LogField("$host",            "%s",  "host",            "VARCHAR(64)"),
    LogField("$vhost",           "%s",  "vhost",           "VARCHAR(64)"),
    LogField("$ip_number",       "%s",  "ip_number",       "VARCHAR(32)"),
	//    LogField("$bin-ip_number",   "%4c", "ip_number",       "VARCHAR(32)",
	//     bin_ip_number_to_ascii),
    LogField("$cern_date",       "%{%d/%s/%d:%d:%d:%d %d%}",
	                                "time",            "DATETIME",
	     cern_date_to_unix),
    LogField("$bin-date",        "%4c", "time",            "DATETIME"),
    LogField("$method",          "%s",  "method",          "VARCHAR(8)"),
    LogField("$resource",        "%s",  "resource",        "VARCHAR(255)"),
    LogField("$full_resource",   "%s",  "resource",        "VARCHAR(255)"),
    LogField("$protocol",        "%s",  "protocol",        "VARCHAR(32)"),
    LogField("$response",        "%d",  "response",        "INTEGER UNSIGNED"),
    LogField("$bin-response",    "%2c", "response",        "INTEGER UNSIGNED"),
    LogField("$length",          "%d",  "length",          "BIGINT UNSIGNED"),
    LogField("$bin-length",      "%4c", "length",          "BIGINT UNSIGNED"),
    LogField("$request-time",    "%d",  "request_time",    "INTEGER UNSIGNED"),
    LogField("$referer",         "%s",  "referrer",        "VARCHAR(255)"),
    LogField("$user_agent",      "%s",  "user_agent",      "VARCHAR(255)"),
    LogField("$user_agent_raw",  "%s",  "user_agent",      "VARCHAR(255)"),
    LogField("$user",            "%s",  "user",            "VARCHAR(255)"),
    LogField("$user_id",         "%s",  "user_id",         "VARCHAR(32)"),
    LogField("$cache-status",    "%s",  "cache_status",    "VARCHAR(64)"),
    LogField("$eval-status",     "%s",  "eval_status",     "VARCHAR(64)"),
    LogField("$content-type",    "%s",  "conent_type",     "VARCHAR(32)"),
    LogField("$protcache-cost",  "%d",  "protcache_cost",  "INTEGER UNSIGNED"),
    LogField("$server-uptime",   "%d",  "server_uptime",   "INTEGER UNSIGNED"),
    LogField("$server-cputime",  "%d",  "server_cputime",  "INTEGER UNSIGNED"),
    LogField("$server-usertime", "%d",  "server_usertime", "INTEGER UNSIGNED"),
    LogField("$server-systime",  "%d",  "server_systime",  "INTEGER UNSIGNED"),
    LogField("$cookies",         "%s",  "cookies",         "VARCHAR(255)"),
    LogField("$ac-userid",       "%d",  "ac_userid",       "INTEGER"),
    LogField("$workarea",        "%s",  "workarea",        "VARCHAR(255)"),
    LogField("$commit-type",     "%s",  "commit_type",     "VARCHAR(32)"),
    LogField("$action",          "%s",  "action",          "VARCHAR(32)"), 
    LogField("$facility",        "%s",  "facility",        "VARCHAR(255)") 
  });

  // Quick lookup from "sql_field" to "format_conversion_f" in clf_format.
  mapping(string:function) clf_format_conversions = ([]);
  
  array(string) access_log_fields_from_format(array(string) format)
  {
    multiset(string) fields = (<>);
    foreach(format, string format_line)
      if(sscanf(format_line, "%s:%s", string code, string def))
      {
	while(has_value(def, "$"))
	{
	  sscanf(def, "%*s$%[a-z_-]%s", string column, def);
	  if(!sizeof(column))
	    error("Unknown format %O.\n", column);
	  fields["$"+column] = 1;
	}
      }
    return clf_format->clf_field & (array)fields;
  }

  array(string) access_log_fields_from_db(Sql.sql sql)
  {
    return clf_format->sql_field & sql->list_fields("access_log")->name;
  }

  void create_log_files_table(Sql.sql sql)
  {
    sql->query("CREATE TABLE IF NOT EXISTS log_files\n"
	       "(log_file_id INTEGER NOT NULL AUTO_INCREMENT,\n"
	       "server_name VARCHAR(32) NOT NULL,\n"
	       "log_file_path VARCHAR(255) NOT NULL,\n"
	       "log_file_alias VARCHAR(255) NOT NULL,\n"
	       "log_file_mtime DATETIME NOT NULL,\n"
	       "last_import_time DATETIME NOT NULL,\n"
	       "PRIMARY KEY (log_file_id),\n"
	       "UNIQUE (server_name, log_file_alias),\n"
	       "UNIQUE (server_name, log_file_path))");
  }
  
  void create_access_log_table(Sql.sql sql, array(string) format)
  {
    array(string) fields = access_log_fields_from_format(format);
    
    string table_def = "CREATE TABLE IF NOT EXISTS access_log\n"
		       "(log_row_id BIGINT NOT NULL AUTO_INCREMENT,\n"
		       "log_file_id INTEGER NOT NULL,\n"
		       "log_row INTEGER NOT NULL,\n"
		       "date DATE,\n";
    foreach(clf_format, LogField log_field)
      if(has_value(fields, log_field->clf_field))
	table_def += log_field->sql_field + " " +
		     log_field->sql_definition + ",\n";
    table_def += "PRIMARY KEY (log_row_id),\n"
		 "INDEX (log_file_id),\n"
		 "UNIQUE INDEX (log_file_id, log_row),\n"
		 "INDEX (date),\n"
		 "INDEX (date, log_row_id))\n";
    
    sql->query(table_def);
  }

  string file_alias(string filename, array(string) decompressor_programs)
  {
    foreach(decompressor_programs, string compressor)
      if(sscanf(compressor, "%s:", string extension))
	if(has_suffix(filename, extension))
	  return filename[..sizeof(filename)-sizeof(extension)-1];
    return filename;
  }

  array(int) update_log_file_table(Sql.sql sql, string server_name,
				   string log_file_path,
				   array(string) decompressor_programs)
  {
    int already_imported_log_rows = 0;

    // Use log file aliases to treat compressed and uncompressed log
    // files as equivalent files.
    string log_file_alias = file_alias(log_file_path, decompressor_programs);

    int log_file_id;
    Stdio.Stat stat = file_stat(log_file_path);
    array(mapping) log_file_res =
      sql->query("SELECT log_file_id, "
		 "       UNIX_TIMESTAMP(log_file_mtime) AS log_file_mtime "
		 "  FROM log_files "
		 " WHERE server_name = %s "
		 "   AND log_file_alias = %s",
		 server_name, log_file_alias);
    if(sizeof(log_file_res))
    {
      log_file_id = (int)log_file_res[0]->log_file_id;
      int log_file_mtime = (int)log_file_res[0]->log_file_mtime;
      if(log_file_mtime == stat->mtime)
	// Log file remains unchanged since last import, skip.
	return 0;
      already_imported_log_rows = (int)sql->query("SELECT MAX(log_row) "
						  "         AS max_log_row"
						  "  FROM access_log "
						  " WHERE log_file_id = %d",
						  log_file_id)[0]->max_log_row;
    }
    else
    {
      sql->query("INSERT INTO log_files "
		 "        SET server_name = %s, "
		 "            log_file_path = %s, "
		 "            log_file_alias = %s, "
		 "            log_file_mtime = FROM_UNIXTIME(%d), "
		 "            last_import_time = NOW()",
		 server_name, log_file_path, log_file_alias,
		 stat->mtime-1 /* Delay real mtime until import finishes. */);
      log_file_id = (int)sql->master_sql->insert_id();
    }
    
    return ({ log_file_id, stat->mtime, already_imported_log_rows });
  }

  Stdio.File open_file(string filepath, array(string) decompressor_programs)
  {
    string decompressor;
    foreach(decompressor_programs, string compressor)
      if(sscanf(compressor, "%s:%s", string extension, string prog))
	if(has_suffix(filepath, extension))
	  decompressor = prog;

    Stdio.File fd;
    if(decompressor)
    {
      fd = Stdio.File();
      Stdio.File pipe = fd->pipe(Stdio.PROP_IPC);
      Process.Process(({ decompressor, filepath }), ([ "stdout":pipe ]));
      pipe->close();
    } else
      fd = Stdio.File(filepath);
    return fd;
  }

  array clf_sscanf_parser(array(string) format)
  {
    array(string) sscanf_parser = ({});
    foreach(format, string format_line)
      if(sscanf(format_line, "%s:%*[ ]%s", string code, string def))
      {
	array(string) sql_fields = ({});
	string rest_def = def;
	while(has_value(rest_def, "$"))
	{
	  sscanf(rest_def, "%*s$%[a-z_-]%s", string field, rest_def);
	  if(!field || !sizeof(field))
	    error("Unknown format field %O.\n", field);
	  string sql_field;
	  foreach(clf_format, LogField log_field)
	    if("$"+field == log_field->clf_field)
	      sql_field = log_field->sql_field;
	  if(!sql_field)
	    error("Unknown format field %O.\n", field);
	  sql_fields += ({ sql_field });
	}
	
	string format = def;
	foreach(clf_format, LogField log_field)
	  format = replace(format, log_field->clf_field,
			   log_field->sscanf_field);
	
	sscanf_parser += ({ ({ code, format, sql_fields }) });
      }
    
    return sscanf_parser;
  }

  mapping clf_sscanf_parse_line(array(array(string)) sscanf_parser, string line)
  {
    mapping val = ([]);
    foreach(sscanf_parser, array parser)
    {
      [string response, string format, array(string) fields] = parser;
      
      array res = array_sscanf(line, format);
      mapping new_val = mkmapping(fields[..sizeof(res)-1], res);
      if(!sizeof(new_val))
	continue;
      if(!new_val->response && (int)response)
	new_val->response = (int)response;
      if(sizeof(val) < sizeof(new_val))
	val = new_val;
    }

    foreach(val; string field; string res)
      if(res == "-")
	// Remove fields with blank values
	m_delete(val, field);
      else if(clf_format_conversions[field])
	val[field] = clf_format_conversions[field](res);
    
    return val;
  }

  void insert_line(Sql.sql sql, int log_file_id, int log_row,
		   int log_time_cutoff,
		   multiset(string) sql_fields, mapping line)
  {
    if(!sizeof(line))
      return;
    array(string) flds =
      ({ "log_file_id = "+log_file_id, "log_row = "+log_row });
    foreach(line; string field; mixed value)
      if(sql_fields[field])
	switch(field)
	{
	  case "time":
	    if(log_time_cutoff && value < log_time_cutoff)
	      return;
	    flds += ({ field + " = "
		       "FROM_UNIXTIME('" + sql->quote((string)value) + "')" });
	    flds += ({ "date = "
		       "FROM_UNIXTIME('" + sql->quote((string)value) + "')" });
	    break;
	    
	  default:
	    flds += ({ field + " = '" + sql->quote((string)value) + "'" });
	}
    sql->query("INSERT INTO access_log SET\n" + flds*",\n" + "\n");
  }

  void import_log_file(Sql.sql sql, int log_file_id, Stdio.File log_fd,
		       multiset(string) sql_fields, array sscanf_parser,
		       int log_time_cutoff, int already_imported_log_rows)
  {
    string buffer = "";
    int log_row = 0;
    
    for(;;)
    {
      string data = log_fd->read(32768);
      if(!data)
	data = "";

      buffer += data;
      array(string) lines = buffer / "\n";
      if(sizeof(data))
      {
	buffer = lines[-1];
	lines = lines[..sizeof(lines)-2];
      }
      
      foreach(lines, string line)
      {
	log_row++;
	if(log_row <= already_imported_log_rows)
	  continue;
	if(!is_import_running())
	  // Check if the import thread is supposed to run.
	  return;
	insert_line(sql, log_file_id, log_row, log_time_cutoff, sql_fields,
		    clf_sscanf_parse_line(sscanf_parser, line));
      }

      if(!sizeof(data))
	break;
    }
  }

  void purge_deprecated_log_entries(Sql.sql sql, string server_name,
				    int log_time_cutoff)
  {
    foreach(sql->query("SELECT log_file_id "
		       "  FROM log_files "
		       " WHERE server_name = %s",
		       server_name)->log_file_id, string log_file_id)
      sql->query("DELETE FROM access_log "
		 " WHERE log_file_id = %s "
		 "   AND time < FROM_UNIXTIME(%d)",
		 log_file_id, log_time_cutoff);
  }

  void cleanup_log_file_table(Sql.sql sql, string server_name)
  {
    foreach(sql->query("SELECT log_file_id "
		       "  FROM log_files "
		       " WHERE server_name = %s",
		       server_name)->log_file_id, string log_file_id)
      if(!(int)sql->query("SELECT MAX(log_row) AS max_log_row "
			  "  FROM access_log "
			  " WHERE log_file_id = %s",
			  log_file_id)[0]->max_log_row)
	sql->query("DELETE FROM log_files "
		   " WHERE log_file_id = %s",
		   log_file_id);
  }
  
  void import_log_files(Sql.sql sql, string server_name,
			array(string) log_files, int log_time_cutoff,
			array(string) format,
			array(string) decompressor_programs)
  {
    multiset(string) sql_fields = (multiset)access_log_fields_from_db(sql);
    array sscanf_parser = clf_sscanf_parser(format);
    
    werror("%s: Import starting\n", query_name());
    
    if(log_time_cutoff)
      purge_deprecated_log_entries(sql, server_name, log_time_cutoff);
    
    foreach(sort(log_files), string log_file_path)
    {
      // Check if the import thread is supposed to run.
      if(!is_import_running())
      {
	werror("%s: Import aborted\n", query_name());
	return;
      }

      array update_res =
      	update_log_file_table(sql, server_name, log_file_path,
			      decompressor_programs);
      if(!update_res)
	// Nothing to update...
	continue;
      [int log_file_id, int log_file_mtime,
       int already_imported_log_rows] = update_res;
      
      werror("%s: %s\n", query_name(), log_file_path);

      Stdio.File log_fd = open_file(log_file_path, decompressor_programs);
      import_log_file(sql, log_file_id, log_fd, sql_fields, sscanf_parser,
		      log_time_cutoff, already_imported_log_rows);
      log_fd->close();

      sql->query("UPDATE log_files "
		 "   SET log_file_mtime = FROM_UNIXTIME(%d), "
		 "       last_import_time = NOW() "
		 " WHERE log_file_id = %d",
		 log_file_mtime, log_file_id);
    }

    werror("%s: Import finished\n", query_name());
  }

  array(mapping) log_file_status(Sql.sql sql, string server_name)
  {
    array(mapping) res = ({});
    foreach(sql->query("SELECT log_file_id, "
		       "       log_file_path, "
		       "       log_file_mtime, "
		       "       last_import_time "
		       "  FROM log_files "
		       " WHERE server_name = %s",
		       server_name), mapping log_file_res)
    {
      int log_file_id = (int)log_file_res->log_file_id;
      log_file_res->max_log_row =
	sql->query("SELECT MAX(log_row) AS max_log_row "
		   "  FROM access_log "
		   " WHERE log_file_id = %d",
		   log_file_id)[0]->max_log_row;
      res += ({ log_file_res });
    }
    return res;
  }
  
  static void create()
  {
    foreach(clf_format, LogField log_field)
      if(log_field->format_conversion_f)
	clf_format_conversions[log_field->sql_field] =
	  log_field->format_conversion_f;
  }
}
