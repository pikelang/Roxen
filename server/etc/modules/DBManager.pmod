// Symbolic DB handling. 
//
// $Id$

//! Manages database aliases and permissions

#include <roxen.h>
#include <config.h>


// FIXME: There should be mutexes here!


#define CN(X) string_to_utf8( X )
#define NC(X) utf8_to_string( X )


constant NONE  = 0;
//! No permissions. Used in @[set_permission] and @[get_permission_map]

constant READ  = 1;
//! Read permission. Used in @[set_permission] and @[get_permission_map]

constant WRITE = 2;
//! Write permission. Used in @[set_permission] and @[get_permission_map]


private
{
  string normalized_server_version;

  mixed query( mixed ... args )
  {
    return connect_to_my_mysql( 0, "roxen" )->query( @args );
  }

  Sql.sql_result big_query( mixed ... args )
  {
    return connect_to_my_mysql( 0, "roxen" )->big_query( @args );
  }

  string short( string n )
  {
    return lower_case(sprintf("%s%4x", CN(n)[..6],(hash( n )&65535) ));
  }

  void clear_sql_caches()
  {
#ifdef DBMANAGER_DEBUG
    werror("DBManager: clear_sql_caches():\n"
	   "  dead_sql_cache: %O\n"
	   "  sql_cache: %O\n"
	   "  connection_cache: %O\n",
	   dead_sql_cache,
	   sql_cache,
	   connection_cache);
#endif /* DMBMANAGER_DEBUG */
    /* Rotate the sql_caches.
     *
     * Perform the rotation first, to avoid thread-races.
     */
    sql_url_cache = ([]);
    user_db_permissions = ([]);
    connection_user_cache = ([]);
    restricted_user_cache = ([]);
    clear_connect_to_my_mysql_cache();
  }
  
  array changed_callbacks = ({});
  void changed()
  {
    changed_callbacks-=({0});
    clear_sql_caches();

    foreach( changed_callbacks, function cb )
      if (mixed err = catch( cb() ))
	report_error ("Error from dblist changed callback %O: %s",
		      cb, describe_backtrace (err));
  }

  int check_db_user (string user, string host)
  {
    return connect_to_my_mysql (0, "mysql")->
      big_query ("SELECT 1 FROM user WHERE Host=%s AND User=%s LIMIT 1",
		 host, user)->
      num_rows();
  }

  protected void low_ensure_has_users( Sql.Sql db, string short_name,
				       string host, string|void password )
  {
    if( password )
    {
      // According to the documentation MySQL 4.1 or newer is required
      // for OLD_PASSWORD(). There does however seem to exist versions of
      // at least 4.0 that know of OLD_PASSWORD().
      if (normalized_server_version >= "004.001") {
	db->query( "REPLACE INTO user (Host,User,Password) "
		   "VALUES (%s, %s, OLD_PASSWORD(%s)), "
		   "       (%s, %s, OLD_PASSWORD(%s))",
		   host, short_name + "_rw", password,
		   host, short_name + "_ro", password);
      } else {
	db->query( "REPLACE INTO user (Host,User,Password) "
		   "VALUES (%s, %s, PASSWORD(%s)), "
		   "       (%s, %s, PASSWORD(%s))",
		   host, short_name + "_rw", password,
		   host, short_name + "_ro", password);
      }
    }
    else
    {
      db->query( "REPLACE INTO user (Host,User,Password) "
		 "VALUES (%s, %s, ''), (%s, %s, '')",
		 host, short_name + "_rw",
		 host, short_name + "_ro" );
    }
  }

  void set_perms_in_user_table(Sql.Sql db, string host, string user, int level)
  {
    multiset(string) privs = (<>);

    switch (level) {
      case NONE:
	db->big_query ("DELETE FROM user "
		       " WHERE Host = %s AND User = %s", host, user);
	return;

      case READ:
	privs = (<
	  "Select_priv", "Show_db_priv", "Create_tmp_table_priv",
	  "Lock_tables_priv", "Execute_priv", "Show_view_priv",
	>);
	break;

      case WRITE:
	// Current as of MySQL 5.0.70.
	privs = (<
	  "Select_priv", "Insert_priv", "Update_priv", "Delete_priv",
	  "Create_priv", "Drop_priv", "Reload_priv", "Shutdown_priv",
	  "Process_priv", "File_priv", "Grant_priv", "References_priv",
	  "Index_priv", "Alter_priv", "Show_db_priv", "Super_priv",
	  "Create_tmp_table_priv", "Lock_tables_priv", "Execute_priv",
	  "Repl_slave_priv", "Repl_client_priv", "Create_view_priv",
	  "Show_view_priv",  "Create_routine_priv", "Alter_routine_priv",
	  "Create_user_priv",
	>);
	break;

      case -1:
	// Special case to create a record for a user that got no access.
	break;

      default:
	error ("Invalid level %d.\n", level);
    }
    if (!sizeof(db->query("SELECT User FROM user "
			  " WHERE Host = %s AND User = %s",
			  host, user))) {
      // Ensure that the user exists.
      db->big_query("REPLACE INTO user (Host, User) VALUES (%s, %s)",
		    host, user);
    }
#ifdef DBMANAGER_DEBUG
    werror("DBManager: Updating privs for %s@%s to %O.\n",
	   user, host, privs);
#endif /* DMBMANAGER_DEBUG */
    // Current as of MySQL 5.0.70.
    foreach(({ "Select_priv", "Insert_priv", "Update_priv", "Delete_priv",
	       "Create_priv", "Drop_priv", "Reload_priv", "Shutdown_priv",
	       "Process_priv", "File_priv", "Grant_priv", "References_priv",
	       "Index_priv", "Alter_priv", "Show_db_priv", "Super_priv",
	       "Create_tmp_table_priv", "Lock_tables_priv", "Execute_priv",
	       "Repl_slave_priv", "Repl_client_priv", "Create_view_priv",
	       "Show_view_priv",  "Create_routine_priv", "Alter_routine_priv",
	       "Create_user_priv",
	    }), string field) {
      db->big_query("UPDATE user SET " + field + " = %s "
		    " WHERE Host = %s AND User = %s AND " + field + " != %s",
		    privs[field]?"Y":"N",
		    host, user, privs[field]?"Y":"N");
    }
  }

  void set_perms_in_db_table (Sql.Sql db, string host, array(string) dbs,
			      string user, int level)
  {
    function(string:string) q = db->quote;

    switch (level) {
      case NONE:
	db->big_query ("DELETE FROM db WHERE"
		       " Host='" + q (host) + "'"
		       " AND Db IN ('" + (map (dbs, q) * "','") + "')"
		       " AND User='" + q (user) + "'");
	break;

      case READ:
	db->big_query ("REPLACE INTO db (Host, Db, User, Select_priv, "
		       "Create_tmp_table_priv, Lock_tables_priv, "
		       "Show_view_priv, Execute_priv) "
		       "VALUES " +
		       map (dbs, lambda (string db_name) {
				   return "("
				     "'" + q (host) + "',"
				     "'" + q (db_name) + "',"
				     "'" + q (user) + "',"
				     "'Y','Y','Y','Y','Y')";
				 }) * ",");
	break;

      case WRITE:
	// Current as of MySQL 5.0.70.
	db->big_query ("REPLACE INTO db (Host, Db, User,"
		       " Select_priv, Insert_priv, Update_priv, Delete_priv,"
		       " Create_priv, Drop_priv, Grant_priv, References_priv,"
		       " Index_priv, Alter_priv, Create_tmp_table_priv,"
		       " Lock_tables_priv, Create_view_priv, Show_view_priv,"
		       " Create_routine_priv, Alter_routine_priv,"
		       " Execute_priv) "
		       "VALUES " +
		       map (dbs, lambda (string db_name) {
				   return "("
				     "'" + q (host) + "',"
				     "'" + q (db_name) + "',"
				     "'" + q (user) + "',"
				     "'Y','Y','Y','Y',"
				     "'Y','Y','N','Y',"
				     "'Y','Y','Y',"
				     "'Y','Y','Y',"
				     "'Y','Y',"
				     "'Y')";
				 }) * ",");
	break;

      case -1:
	// Special case to create a record for a user that got no access.
	db->big_query ("REPLACE INTO db (Host, Db, User) "
		       "VALUES " +
		       map (dbs, lambda (string db_name) {
				   return "("
				     "'" + q (host) + "',"
				     "'" + q (db_name) + "',"
				     "'" + q (user) + "')";
				 }) * ",");
	break;

      default:
	error ("Invalid level %d.\n", level);
    }
  }

  //! Split on semi-colon, but not inside strings or comments...
  protected array(string) split_sql_script(string script)
  {
    array(string) res = ({});
    int start = 0;
    int i;
    for (i = 0; i < sizeof(script); i++) {
      int c = script[i];
      int cc;
      switch(c) {
      case ';':
	res += ({ script[start..i-1] });
	start = i+1;
	break;

	// Quote characters...
      case '\"': case '\'': case '\`': case '\´':
	while (i < sizeof(script) - 1) {
	  i++;
	  if ((cc = script[i]) == c) {
	    if ((i < sizeof(script) - 1) && (script[i+1] == c)) {
	      i++;
	      continue;
	    }
	    break;
	  }
	  if (cc == '\\') i++;
	}
	break;

	// Comments...
      case '/':
	i++;
	if ((i < sizeof(script)) &&
	    ((cc = script[i]) == '*')) {
	  // C-style comment.
	  int p = search(script, "*/", i+1);
	  if (p > i) i = p+1;
	  else i = sizeof(script)-1;
	}
	break;
      case '-':
	i++;
	if ((i < sizeof(script) - 1) &&
	    ((script[i] == '-') &&
	     ((script[i+1] == ' ') || (script[i+1] == '\t')))) {
	  // "-- "-style comment.
	  int p = search(script, "\n", i+2);
	  int p2 = search(script, "\r", i+2);
	  if ((p < p2) && (p > i)) i = p;
	  else if (p2 > i) i = p2;
	  else if (p > i) i = p;
	  else i = sizeof(script)-1;
	}
	break;
      case '#':
	{
	  // #-style comment.
	  int p = search(script, "\n", i+1);
	  int p2 = search(script, "\r", i+1);
	  if ((p < p2) && (p > i)) i = p;
	  else if (p2 > i) i = p2;
	  else if (p > i) i = p;
	  else i = sizeof(script)-1;
	}
	break;
      }
    }
    res += ({ script[start..i-1] });
    return res;
  }

  protected class SqlFileSplitIterator
  {
    inherit String.SplitIterator;

    protected void create(Stdio.File script_file)
    {
      ::create("", ';', 0, script_file->read_function(8192));
      next();
    }

    protected int _sizeof()
    {
      return -1;
    }

    protected string current = "";

    int next()
    {
      if (!current) return 0;
      current = 0;
      if (::value()) {
	string buf = "";
	while (1) {
	  buf += ::value() + ";";
	  if (!::next()) break;	// Skip the trailer.

	  array(string) a = split_sql_script(buf);
	  if (sizeof(a) > 1) {
	    current = a[0];
	    // NB: a[1] should always be "" here.
	    return 1;
	  }
	}
      }
      return 0;
    }

    int index()
    {
      return current?-1:UNDEFINED;
    }

    string value()
    {
      return current || UNDEFINED;
    }
  }

  protected void execute_sql_script(Sql.Sql db, string script,
				    int|void quiet)
  {
    array(string) queries = split_sql_script(script);
    foreach(queries[..sizeof(queries)-2], string q) {
      mixed err = catch {db->query(q);};
      if (err && !quiet) {
	// Complain about failures only if they're not expected.
	master()->handle_error(err);
      }
    }
  }

  protected void execute_sql_script_file(Sql.Sql db, Stdio.File script_file,
					 int|void quiet)
  {
    foreach(SqlFileSplitIterator(script_file);; string q) {
      mixed err = catch {db->query(q);};
      if (err && !quiet) {
	// Complain about failures only if they're not expected.
	master()->handle_error(err);
      }
    }
  }

  protected void check_upgrade_mysql()
  {
    Sql.Sql db = connect_to_my_mysql(0, "mysql");

    mapping(string:string) mysql_location = roxenloader->parse_mysql_location();
    string update_mysql;

    string mysql_version = db->server_info();
    // Typically a string like "mysql/5.5.30-log" or "mysql/5.5.39-MariaDB-log".
    if (has_value(mysql_version, "/")) mysql_version = (mysql_version/"/")[1];

    string db_version;
    // Catch in case mysql_upgrade_info is a directory (unlikely, but...).
    catch {
      db_version =
	Stdio.read_bytes(combine_path(roxenloader.query_mysql_data_dir(),
				      "mysql_upgrade_info"));
      // Typically a string like "5.5.30" or "5.5.39-MariaDB".
    };
    db_version = db_version && (db_version - "\n");

    if (db_version &&
	has_suffix(mysql_version, "-log") &&
	!has_suffix(db_version, "-log")) {
      db_version += "-log";
    }

    if (db_version == mysql_version) {
      // Already up-to-date.
    } else {
      werror("Upgrading database from %s to %s...\n",
	     db_version || "UNKNOWN", mysql_version);

      if (mysql_location->mysql_upgrade) {
	// Upgrade method in MySQL 5.0.19 and later (UNIX),
	// MySQL 5.0.25 and later (NT).
	Process.Process(({ mysql_location->mysql_upgrade,
#ifdef __NT__
			   "--pipe",
#endif
			   "-S", roxenloader.query_mysql_socket(),
			   "--user=rw",
			   // "--verbose",
			}))->wait();
      } else if ((mysql_location->basedir) &&
		 (update_mysql =
		  (Stdio.read_bytes(combine_path(mysql_location->basedir,
						 "share/mysql",
						 "mysql_fix_privilege_tables.sql")) ||
		   Stdio.read_bytes(combine_path(mysql_location->basedir,
						 "share",
						 "mysql_fix_privilege_tables.sql"))))) {
	// Don't complain about failures, they're expected...
	execute_sql_script(db, update_mysql, 1);
      } else {
	report_warning("Couldn't find MySQL upgrading script.\n");
      }

      // These table definitions come from [bug 7264], which in turn got them
      // from http://dba.stackexchange.com/questions/54608/innodb-error-table-mysql-innodb-table-stats-not-found-after-upgrade-to-mys
      foreach(({ #"CREATE TABLE IF NOT EXISTS `innodb_index_stats` (
  `database_name` varchar(64) COLLATE utf8_bin NOT NULL,
  `table_name` varchar(64) COLLATE utf8_bin NOT NULL,
  `index_name` varchar(64) COLLATE utf8_bin NOT NULL,
  `last_update` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `stat_name` varchar(64) COLLATE utf8_bin NOT NULL,
  `stat_value` bigint(20) unsigned NOT NULL,
  `sample_size` bigint(20) unsigned DEFAULT NULL,
  `stat_description` varchar(1024) COLLATE utf8_bin NOT NULL,
  PRIMARY KEY (`database_name`,`table_name`,`index_name`,`stat_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin STATS_PERSISTENT=0",
		 #"CREATE TABLE IF NOT EXISTS `innodb_table_stats` (
  `database_name` varchar(64) COLLATE utf8_bin NOT NULL,
  `table_name` varchar(64) COLLATE utf8_bin NOT NULL,
  `last_update` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `n_rows` bigint(20) unsigned NOT NULL,
  `clustered_index_size` bigint(20) unsigned NOT NULL,
  `sum_of_other_index_sizes` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`database_name`,`table_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin STATS_PERSISTENT=0",
		 #"CREATE TABLE IF NOT EXISTS `slave_master_info` (
  `Number_of_lines` int(10) unsigned NOT NULL COMMENT 'Number of lines in the file.',
  `Master_log_name` text CHARACTER SET utf8 COLLATE utf8_bin NOT NULL COMMENT 'The name of the master binary log currently being read from the master.',
  `Master_log_pos` bigint(20) unsigned NOT NULL COMMENT 'The master log position of the last read event.',
  `Host` char(64) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '' COMMENT 'The host name of the master.',
  `User_name` text CHARACTER SET utf8 COLLATE utf8_bin COMMENT 'The user name used to connect to the master.',
  `User_password` text CHARACTER SET utf8 COLLATE utf8_bin COMMENT 'The password used to connect to the master.',
  `Port` int(10) unsigned NOT NULL COMMENT 'The network port used to connect to the master.',
  `Connect_retry` int(10) unsigned NOT NULL COMMENT 'The period (in seconds) that the slave will wait before trying to reconnect to the master.',
  `Enabled_ssl` tinyint(1) NOT NULL COMMENT 'Indicates whether the server supports SSL connections.',
  `Ssl_ca` text CHARACTER SET utf8 COLLATE utf8_bin COMMENT 'The file used for the Certificate Authority (CA) certificate.',
  `Ssl_capath` text CHARACTER SET utf8 COLLATE utf8_bin COMMENT 'The path to the Certificate Authority (CA) certificates.',
  `Ssl_cert` text CHARACTER SET utf8 COLLATE utf8_bin COMMENT 'The name of the SSL certificate file.',
  `Ssl_cipher` text CHARACTER SET utf8 COLLATE utf8_bin COMMENT 'The name of the cipher in use for the SSL connection.',
  `Ssl_key` text CHARACTER SET utf8 COLLATE utf8_bin COMMENT 'The name of the SSL key file.',
  `Ssl_verify_server_cert` tinyint(1) NOT NULL COMMENT 'Whether to verify the server certificate.',
  `Heartbeat` float NOT NULL,
  `Bind` text CHARACTER SET utf8 COLLATE utf8_bin COMMENT 'Displays which interface is employed when connecting to the MySQL server',
  `Ignored_server_ids` text CHARACTER SET utf8 COLLATE utf8_bin COMMENT 'The number of server IDs to be ignored, followed by the actual server IDs',
  `Uuid` text CHARACTER SET utf8 COLLATE utf8_bin COMMENT 'The master server uuid.',
  `Retry_count` bigint(20) unsigned NOT NULL COMMENT 'Number of reconnect attempts, to the master, before giving up.',
  `Ssl_crl` text CHARACTER SET utf8 COLLATE utf8_bin COMMENT 'The file used for the Certificate Revocation List (CRL)',
  `Ssl_crlpath` text CHARACTER SET utf8 COLLATE utf8_bin COMMENT 'The path used for Certificate Revocation List (CRL) files',
  `Enabled_auto_position` tinyint(1) NOT NULL COMMENT 'Indicates whether GTIDs will be used to retrieve events from the master.',
  PRIMARY KEY (`Host`,`Port`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 STATS_PERSISTENT=0 COMMENT='Master Information'",
		 #"CREATE TABLE IF NOT EXISTS `slave_relay_log_info` (
  `Number_of_lines` int(10) unsigned NOT NULL COMMENT 'Number of lines in the file or rows in the table. Used to version table definitions.',
  `Relay_log_name` text CHARACTER SET utf8 COLLATE utf8_bin NOT NULL COMMENT 'The name of the current relay log file.',
  `Relay_log_pos` bigint(20) unsigned NOT NULL COMMENT 'The relay log position of the last executed event.',
  `Master_log_name` text CHARACTER SET utf8 COLLATE utf8_bin NOT NULL COMMENT 'The name of the master binary log file from which the events in the relay log file were read.',
  `Master_log_pos` bigint(20) unsigned NOT NULL COMMENT 'The master log position of the last executed event.',
  `Sql_delay` int(11) NOT NULL COMMENT 'The number of seconds that the slave must lag behind the master.',
  `Number_of_workers` int(10) unsigned NOT NULL,
  `Id` int(10) unsigned NOT NULL COMMENT 'Internal Id that uniquely identifies this record.',
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 STATS_PERSISTENT=0 COMMENT='Relay Log Information'",
		 #"CREATE TABLE IF NOT EXISTS `slave_worker_info` (
  `Id` int(10) unsigned NOT NULL,
  `Relay_log_name` text CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `Relay_log_pos` bigint(20) unsigned NOT NULL,
  `Master_log_name` text CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `Master_log_pos` bigint(20) unsigned NOT NULL,
  `Checkpoint_relay_log_name` text CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `Checkpoint_relay_log_pos` bigint(20) unsigned NOT NULL,
  `Checkpoint_master_log_name` text CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `Checkpoint_master_log_pos` bigint(20) unsigned NOT NULL,
  `Checkpoint_seqno` int(10) unsigned NOT NULL,
  `Checkpoint_group_size` int(10) unsigned NOT NULL,
  `Checkpoint_group_bitmap` blob NOT NULL,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 STATS_PERSISTENT=0 COMMENT='Worker Information'",
	      }), string table_def) {
	mixed err = catch {
	    db->query(table_def);
	  };
	if (err) {
	  string table_name = (table_def/"`")[1];
	  werror("DBManager: Failed to add table mysql.%s: %s\n",
		 table_name, describe_error(err));
	}
      }
    }

    multiset(string) missing_privs = (<
      // Current as of MySQL 5.0.70.
      "Select", "Insert", "Update", "Delete", "Create", "Drop", "Grant",
      "References", "Index", "Alter", "Create_tmp_table", "Lock_tables",
      "Create_view", "Show_view", "Create_routine", "Alter_routine",
      "Execute",
    >);
    foreach(db->query("DESCRIBE db"), mapping(string:string) row) {
      string field = row->Field || row->field;
      if (!field) {
	werror("DBManager: Failed to analyse privileges table mysql.db.\n"
	       "row: %O\n", row);
	return;
      }
      if (has_suffix(field, "_priv")) {
	// Note the extra space below.
	missing_privs[field[..sizeof(field)-sizeof(" _priv")]] = 0;
      }
    }
    if (sizeof(missing_privs)) {
      werror("DBManager: Updating priviliges table mysql.db with the fields\n"
	     "           %s...", indices(missing_privs)*", ");
      foreach(indices(missing_privs), string priv) {
	db->query("ALTER TABLE db "
		  "  ADD COLUMN " + priv+ "_priv "
		  "      ENUM('N','Y') DEFAULT 'N' NOT NULL");
      }
    }

    if (db_version != mysql_version) {
      // Make sure no table is broken after the upgrade.
      foreach(db->list_dbs(), string dbname) {
	if (lower_case(dbname) == "information_schema") {
	  // This is a virtual read-only db containing metadata
	  // about the other tables, etc. Attempting to repair
	  // any tables in it will cause errors to be thrown.
	  continue;
	}
	if (lower_case(dbname) == "performance_schema") {
	  // This is a virtual read-only db containing metadata
	  // about the other tables, etc. Attempting to repair
	  // any tables in it will cause errors to be thrown.
	  continue;
	}
	werror("DBManager: Repairing tables in the local db %O...\n", dbname);
	Sql.Sql sql = connect_to_my_mysql(0, dbname);
	foreach(sql->list_tables(), string table) {
	  // NB: Any errors from the repair other than access
	  //     permission errors are in the return value.
	  //
	  // We ignore them for now.
	  sql->query("REPAIR TABLE `" + table + "`");
	}
      }
      werror("DBManager: MySQL upgrade done.\n");
    }
  }

  void synch_mysql_perms()
  {
    Sql.Sql db = connect_to_my_mysql (0, "mysql");

    // Force proper privs for the low-level users.
    set_perms_in_user_table(db, "localhost", "rw", WRITE);
    set_perms_in_user_table(db, "localhost", "ro", READ);

    mapping(string:int(1..1)) old_perms = ([]);

    Sql.sql_result sqlres =
      db->big_query ("SELECT Db, User FROM db WHERE Host='localhost'");
    while (array(string) ent = sqlres->fetch_row())
      if (has_suffix (ent[1], "_rw") || has_suffix (ent[1], "_ro"))
	old_perms[ent[0] + "\0" + ent[1]] = 1;

    mapping(string:int(1..1)) checked_users = ([]);

    sqlres = big_query ("SELECT db, config, permission FROM db_permissions ");
    while (array(string) ent = sqlres->fetch_row()) {
      [string db_name, string config, string perm] = ent;
      string short_name = short (NC (config));

      if (!checked_users[short_name]) {
	low_ensure_has_users (db, short_name, "localhost");
	checked_users[short_name] = 1;
      }

      switch (perm) {
	case "read":
	  set_perms_in_db_table (db, "localhost", ({db_name}),
				 short_name + "_ro", READ);
	  set_perms_in_db_table (db, "localhost", ({db_name}),
				 short_name + "_rw", READ);
	  m_delete (old_perms, db_name + "\0" + short_name + "_ro");
	  m_delete (old_perms, db_name + "\0" + short_name + "_rw");
	  break;

	case "write":
	  set_perms_in_db_table (db, "localhost", ({db_name}),
				 short_name + "_ro", READ);
	  set_perms_in_db_table (db, "localhost", ({db_name}),
				 short_name + "_rw", WRITE);
	  m_delete (old_perms, db_name + "\0" + short_name + "_ro");
	  m_delete (old_perms, db_name + "\0" + short_name + "_rw");
	  break;
      }
    }

    foreach (old_perms; string key;) {
      sscanf (key, "%s\0%s", string db_name, string user);
      set_perms_in_db_table (db, "localhost", ({db_name}), user, NONE);
    }

    db->big_query ("FLUSH PRIVILEGES");
  }

  string make_autouser_name (int level, multiset(string) want_dbs,
			     Configuration conf)
  // Returns the name for a user which wants the given access to the
  // given databases, subject to the permission settings of the given
  // configuration (optional). The name begins with "?" if level is
  // READ or "!" if level is WRITE, then follows a 15 char hash
  // (without whitespace) based on want_dbs and conf->name. Only the
  // name is generated; fix_autouser must be called to ensure the user
  // exists.
  {
    if (level < READ) return 0;
    string s = encode_value_canonic (({want_dbs, conf->name}));
    s = MIME.encode_base64 (Crypto.SHA1()->update (s)->digest());
    return (level == READ ? "?" : "!") + s[..14];
  }

  void fix_autouser (string autouser, multiset(string) write_dbs,
		     multiset(string) read_dbs, multiset(string) none_dbs)
  // If the given autouser doesn't exist, it's created with access to
  // the stated databases. none_dbs is used for databases that the
  // user wants access to but isn't allowed. It's to make
  // invalidate_autousers properly detect this user if access is
  // granted on one of those dbs later.
  {
    Sql.Sql db = connect_to_my_mysql (0, "mysql");

    // If the user exists at all we assume it got the right perms.
    if (check_db_user (autouser, "localhost")) return;

    if (sizeof (write_dbs))
      set_perms_in_db_table (db, "localhost",
			     indices (write_dbs), autouser, WRITE);
    if (sizeof (read_dbs))
      set_perms_in_db_table (db, "localhost",
			     indices (read_dbs), autouser, READ);
    if (sizeof (none_dbs))
      set_perms_in_db_table (db, "localhost",
			     indices (none_dbs), autouser, -1);

    db->big_query ("REPLACE INTO user (Host, User, Password) "
		   "VALUES ('localhost', %s, '')", autouser);
    db->big_query ("FLUSH PRIVILEGES");
  }

  void invalidate_autousers (string db_name)
  // Invalidates the autousers that have any access on the given
  // database. Invalidates all autousers if db_name is zero.
  {
    Sql.Sql db = connect_to_my_mysql (0, "mysql");

    if (db_name) {
      array(string) users = ({});
      Sql.sql_result sqlres =
	db->big_query ("SELECT User FROM db "
		       "WHERE Host='localhost' AND Db=%s AND "
		       "(User LIKE '!_______________' OR"
		       " User LIKE '?_______________')", db_name);
      while (array(string) ent = sqlres->fetch_row())
	users += ({ent[0]});

      // We have to delete all affected autousers completely from the
      // db table to make get_autouser regenerate them.
      if (sizeof (users)) {
	string user_list = "('" + map (users, db->quote) * "','" + "')";
	db->big_query ("DELETE FROM db WHERE User IN " + user_list);
	db->big_query ("DELETE FROM user WHERE User IN " + user_list);
      }
    }
    else {
      db->big_query ("DELETE FROM db "
		     "WHERE Host='localhost' AND "
		       "(User LIKE '!_______________' OR"
		       " User LIKE '?_______________')");
      db->big_query ("DELETE FROM user "
		     "WHERE Host='localhost' AND "
		       "(User LIKE '!_______________' OR"
		       " User LIKE '?_______________')");
    }

    restricted_user_cache = ([]);
  }

  void low_set_user_permissions( Sql.Sql db, Configuration c,
				 string db_name, int level,
				 string host, string|void password )
  {
    string short_name = short (c->name);
    low_ensure_has_users( db, short_name, host, password );
    set_perms_in_db_table (db, host, ({db_name}),
			   short_name + "_ro", min (level, READ));
    set_perms_in_db_table (db, host, ({db_name}),
			   short_name + "_rw", level);
  }
  
  void set_user_permissions( Configuration c, string db_name, int level )
  {
    Sql.Sql db = connect_to_my_mysql( 0, "mysql" );
    low_set_user_permissions( db, c, db_name, level, "localhost" );
    invalidate_autousers (db_name);
    db->query( "FLUSH PRIVILEGES" );
  }
  
  void set_external_user_permissions( Configuration c, string db_name, int level,
				      string password )
  {
    Sql.Sql db = connect_to_my_mysql( 0, "mysql" );
    low_set_user_permissions( db, c, db_name, level, "127.0.0.1", password );
    db->query( "FLUSH PRIVILEGES" );
  }


  class ROWrapper( protected Sql.Sql sql )
  {
    protected int pe;
    protected array(mapping(string:mixed)) query( string query, mixed ... args )
    {
      // Get rid of any initial whitespace.
      query = String.trim_all_whites(query);
      if( has_prefix( lower_case(query), "select" ) ||
          has_prefix( lower_case(query), "show" ) ||
          has_prefix( lower_case(query), "describe" ))
        return sql->query( query, @args );
      pe = 1;
      throw( ({ "Permission denied\n", backtrace()}) );
    }
    protected Sql.sql_result big_query( string query, mixed ... args )
    {
      // Get rid of any initial whitespace.
      query = String.trim_all_whites(query);
      if( has_prefix( lower_case(query), "select" ) ||
          has_prefix( lower_case(query), "show" ) ||
          has_prefix( lower_case(query), "describe" ))
        return sql->big_query( query, @args );
      pe = 1;
      throw( ({ "Permission denied\n", backtrace()}) );
    }
    protected string error()
    {
      if( pe )
      {
        pe = 0;
        return "Permission denied";
      }
      return sql->error();
    }

    protected string host_info()
    {
      return sql->host_info()+" (read only)";
    }

    protected mixed `[]( string i )
    {
      switch( i )
      {
       case "query": return query;
       case "big_query": return big_query;
       case "host_info": return host_info;
       case "error": return error;
       default:
         return sql[i];
      }
    }
    protected mixed `->( string i )
    {
      return `[](i);
    }
  }

  mapping(string:mapping(string:string)) sql_url_cache = ([]);
};

mapping(string:mixed) get_db_url_info(string db)
{
  mapping(string:mixed) d = sql_url_cache[ db ];
  if( !d )
  {
    array(mapping(string:string)) res =
      query("SELECT path, local, default_charset "
	    "  FROM dbs WHERE name=%s", db );
    if( !sizeof( res ) )
      return 0;
    sql_url_cache[db] = d = res[0];
  }
  return d;
}

#ifdef MODULE_DEBUG
private class SqlSqlStaleChecker (protected Sql.Sql sql)
{
  // Wrapper to check that connections aren't held on to by modules
  // for too long, in MODULE_DEBUG mode. Modules should fetch
  // connections via the DBManager to make sure timeouts are handled
  // correctly.

  int _our_last_ping = time (1);
  constant _our_timeout = 10;

  protected void _check_ping()
  {
    if (time(1)-_our_last_ping > _our_timeout)
      werror ("Query attempted on connection with latest activity more than %d"
	      " seconds ago. Something is probably holding on to Sql.Sql "
	      "connections longer than it should. Backtrace: \n%s\n",
	      _our_timeout,
	      describe_backtrace(backtrace()));
    _our_last_ping = time (1); // Reset timestamp when running queries.
  }

  protected mixed `[]( string i )
  {
    switch (i) {
    case "ping":
      _our_last_ping = time (1);
      break;
    case "query":
    case "typed_query":
    case "big_query":
    case "big_typed_query":
    case "streaming_query":
      _check_ping();
      break;
    }
    return sql[i];
  }
  protected mixed `->( string i )
  {
    return `[](i);
  }
}
#endif

Sql.Sql low_get( string user, string db, void|int reuse_in_thread,
		 void|string charset)
{
  if( !user )
    return 0;

#ifdef MODULE_DEBUG
  if (!reuse_in_thread)
    if (mapping(string:TableLockInfo) dbs = table_locks->get())
      if (TableLockInfo lock_info = dbs[db])
	werror ("Warning: Another connection was requested to %O "
		"in a thread that has locked tables %s.\n"
		"It's likely that this will result in a deadlock - "
		"consider using the reuse_in_thread flag.\n",
		db,
		String.implode_nicely (indices (lock_info->locked_for_read &
						lock_info->locked_for_write)));
#endif

  mapping(string:mixed) d = get_db_url_info(db);
  if( !d ) return 0;

  Sql.Sql res;

  if( (int)d->local ) {
    res = connect_to_my_mysql( user, db, reuse_in_thread,
			       charset || d->default_charset );
  }
  // Otherwise it's a tad more complex...
  else if( has_suffix (user, "_ro") ) {
    // The ROWrapper object really has all member functions Sql.Sql
    // has, but they are hidden behind an overloaded index operator.
    // Thus, we have to fool the typechecker.
    res = [object(Sql.Sql)](object)
      ROWrapper( sql_cache_get( d->path, reuse_in_thread,
				charset || d->default_charset) );
  } else {
    res = sql_cache_get( d->path, reuse_in_thread,
			 charset || d->default_charset);
  }

#ifdef MODULE_DEBUG
  return [object(Sql.Sql)](object)SqlSqlStaleChecker (res);
#else
  return res;
#endif
}

Sql.Sql get_sql_handler(string db_url)
{
#ifdef USE_EXTSQL_ORACLE
  if(has_prefix(db_url, "oracle:"))
    return ExtSQL.sql(db_url);
#endif
  return Sql.Sql(db_url, ([ "reconnect":0 ]));
}

Sql.Sql sql_cache_get(string what, void|int reuse_in_thread,
		      void|string charset)
{
  Thread.MutexKey key = roxenloader.sq_cache_lock();
  string i = replace(what,":",";")+":-";
  Sql.Sql res = roxenloader.sq_cache_get(i, reuse_in_thread);
  if (res) {
    destruct(key);
    return roxenloader.fix_connection_charset (res, charset);
  }
  // Release the lock during the call to get_sql_handler(),
  // since it may take quite a bit of time...
  destruct(key);
  if (res = get_sql_handler(what)) {
    // Now we need the lock again...
    key = roxenloader.sq_cache_lock();
    res = roxenloader.sq_cache_set(i, res, reuse_in_thread, charset);
    // Fool the optimizer so that key is not released prematurely
    if( res )
      return res; 
  }
}

void add_dblist_changed_callback( function(void:void) callback )
//! Add a function to be called when the database list has been
//! changed. This function will be called after all @[create_db] and
//! @[drop_db] calls.
{
  changed_callbacks |= ({ callback });
}

int remove_dblist_changed_callback( function(void:void) callback )
//! Remove a function previously added with @[add_dblist_changed_callback].
//! Returns non-zero if the function was in the callback list.
{
  int s = sizeof( changed_callbacks );
  changed_callbacks -= ({ callback });
  return s-sizeof( changed_callbacks );
}

array(string) list( void|Configuration c )
//! List all database aliases.
//!
//! If @[c] is specified, only databases that the given configuration can
//! access will be visible.
{
  if( c )
    return  query( "SELECT "
                   " dbs.name AS name "
                   "FROM "
                   " dbs,db_permissions "
                   "WHERE"
                   " dbs.name=db_permissions.db"
                   " AND db_permissions.config=%s"
                   " AND db_permissions.permission!='none'",
                   CN(c->name))->name
#ifndef YES_I_KNOW_WHAT_I_AM_DOING
      -({"roxen","mysql"})
#endif
      ;
  return query( "SELECT name FROM dbs" )->name
#ifndef YES_I_KNOW_WHAT_I_AM_DOING
      -({"roxen","mysql"})
#endif
    ;
}

mapping(string:mapping(string:int)) get_permission_map( )
//! Get a list of all permissions for all databases.
//!
//! @returns
//!   Return format:
//!   	@mapping
//!   	  @member mapping(string:int) dbname
//!   	    @mapping
//!   	      @member int configname
//!   		Access level same as for @[set_permission()] et al.
//!   	    @endmapping
//!   	@endmapping
{
  mapping(string:mapping(string:int)) res = ([]);

  foreach( list(), string n )
  {
    mixed m = query( "SELECT * FROM db_permissions WHERE db=%s", n );
    if( sizeof( m ) )
      foreach( m, m )
      {
        if( !res[m->db] )res[m->db] = ([]);
        switch( m->permission )
        {
         case "none":    res[m->db][NC(m->config)] = NONE; break;
         case "read":    res[m->db][NC(m->config)] = READ; break;
         case "write":   res[m->db][NC(m->config)] = WRITE; break;
        }
      }
    else
      res[n] = ([]);
  }
  foreach( indices(res), string q )
    foreach( roxenp()->configurations, Configuration c )
      if( zero_type( res[q][c->name] ) )
        res[q][c->name] = 0;
  return res;
}

string db_driver( string db )
//! Returns the name of the protocol used to connect to the database 'db'.
//! This is the part before :// in the database URL.  
{
  if( !(db = db_url( db )) ) return "mysql";
  sscanf( db, "%[^:]:", db );
  return db;
}

int is_mysql( string db )
//! Returns true if the specified database is a MySQL database.
{
  return !(db = db_url( db )) || has_prefix( db, "mysql://" );
}

protected mapping(string:mixed) convert_obj_to_mapping(object|mapping o)
{
  if (mappingp(o)) return o;
  return mkmapping(indices(o), values(o));
}

array(mapping(string:mixed)) db_table_fields( string name, string table )
//! Returns a mapping of fields in the database, if it's supported by
//! the protocol handler. Otherwise returns 0.
{
  Sql.Sql db = cached_get( name );
  object q;
  if (catch (
	q = db->big_query ("SELECT * FROM `" + table + "` LIMIT 0"))) {
    // Syntax error for query. Fall back to using the generic stuff.
    catch {
      // fetch_fields provides more info (if it exists...).
      if (db->master_sql->list_fields)
	return db->list_fields( table );
    };
    // list_fields() failed as well.
    // Try the original query, without the MySQL-specific syntax.
    // This is very generic.
    if (mixed err = catch (q = db->big_query ("SELECT * FROM " + table +
					      " WHERE 1 = 0"))) {
      report_debug ("Error listing fields in %O: %s",
		    table, describe_error (err));
      return 0;
    }
  }
  return map(q->fetch_fields(), convert_obj_to_mapping);
}

array(string) db_tables( string name )
//! Attempt to list all tables in the specified DB, and then return
//! the list.
{
  object db = get(name);
  if (!db) return ({});
  array(string) res;
  if( db->list_tables )
  {
    catch {
      if( res =  db->list_tables() )
	return res;
    };
  }

  // Well, let's try some specific solutions then. The main problem if
  // we reach this stage is probably that we are using a ODBC driver
  // which does not support the table enumeration interface, this
  // causing list_tables to throw an error.

  switch( db_driver( name ) )
  {
    case "mysql":
      return ({});

    case "odbc":
      // Oracle.
      catch {
	res = db->query( "select TNAME from tab")->TNAME;
	return res;
      };
      // fallthrough.

      // Microsoft SQL (7.0 or newer)
      catch {
	res = ({});
	foreach( db->query("SELECT * FROM information_schema.tables"),
		 mapping row )
	  if( has_prefix( lower_case(row->TABLE_TYPE), "base" ) )
	    res += ({ row->TABLE_NAME });
	return res;
      };

      
    case "postgres":
      // Postgres
      catch {
	res = db->query("SELECT a.relname AS name FROM pg_class a, "
			"pg_user b WHERE ( relkind = 'r') and "
			"relname !~ '^pg_' "
			"AND relname !~ '^xin[vx][0-9]+' AND "
			"b.usesysid = a.relowner AND "
			"NOT (EXISTS (SELECT viewname FROM pg_views "
			"WHERE viewname=a.relname)) ")->name;
	return res;
      };
  }

  return ({});
}

mapping db_table_information( string db, string table )
//! Return a mapping with at least the indices rows, data_length
//! and index_length, if possible. Otherwise returns 0.
{
  switch( db_driver( db ) )
  {
    case "mysql":
    {
      foreach( get(db)->query( "SHOW TABLE STATUS" ), mapping r )
      {
	if( r->Name == table )
	  return ([ "rows":(int)r->Rows,
		    "data_length":(int)r->Data_length,
		    "index_length":(int)r->Index_length ]);
      }
    }
    default:
    {
      object gdb=get(db);
      if (gdb->list_fields) {
	mixed err = catch {
	    array a = gdb->list_fields(table);
	    mapping res = sizeof(a) && a[0];
	    if (res) {
	      res->data_length = res->data_length || res->datasize;
	      res->rows = res->rows || res->rowcount;
	      res->index_legth = res->index_length || res->indexsize;
	    }
	    return res;
	  };
      }
    }
  }
  return 0;
}


mapping(string:int) db_stats( string name )
//! Return statistics for the specified database (such as the number
//! of tables and their total size). If the database is not an
//! internal database, or the database does not exist, 0 is returned
{
  mapping(string:int) res = (["size": 0, "tables": 0, "rows": 0]);
  Sql.Sql db = cached_get( name );
  array d;

  switch( db_driver( name ) )
  {
    case "mysql":
      if( !catch( d = db->query( "SHOW TABLE STATUS" ) ) )
      {
	foreach( d, mapping r )
	{
	  res->size += (int)r->Data_length+(int)r->Index_length;
	  res->tables++;
	  res->rows += (int)r->Rows;
	}
	return res;
      }

      // fallthrough to generic interface.
    default:
      catch
      {
	foreach( db_tables( name ), string n )
	{
	  mapping i  = db_table_information( name, n );
	  res->tables++;
	  if( i )
	  {
	    res->rows += i->rows;
	    res->size += i->data_length+i->index_length;
	  }
	}
	return res;
      };
  }
  return 0;
}


int is_internal( string name )
//! Return true if the DB @[name] is an internal database
{
  array(mapping(string:mixed)) d =
    query("SELECT local FROM dbs WHERE name=%s", name );
  if( !sizeof( d ) ) return 0;
  return (int)d[0]["local"];
}

string db_url( string name,
	       int|void force )
//! Returns the URL of the db, or 0 if the DB @[name] is an internal
//! database and @[force] is not specified. If @[force] is specified,
//! a URL is always returned unless the database does not exist.
{
  array(mapping(string:mixed)) d =
    query("SELECT path,local FROM dbs WHERE name=%s", name );

  if( !sizeof( d ) )
    return 0;

  if( (int)d[0]["local"] )
  {
    if( force )
      return replace( roxenloader->my_mysql_path,
		      ([
			"%user%":"rw",
			"%db%":name
		      ]) );
    return 0;
  }
  return d[0]->path;
}

protected mapping(string:multiset(string)) user_db_permissions = ([]);

multiset(string) config_db_access (Configuration conf, int read_only)
//! Returns the set of databases that the given configuration has
//! access to. If @[read_only] is set then the set includes both read
//! and write permissions, otherwise only databases with write access
//! are returned. Don't be destructive on the returned multisets.
{
  string key = conf->name + "|" + read_only;
  if (multiset(string) res = user_db_permissions[key])
    return res;

  string q;
  if (read_only)
    q = "SELECT db FROM db_permissions "
      "WHERE config=%s AND (permission='read' OR permission='write')";
  else
    q = "SELECT db FROM db_permissions "
      "WHERE config=%s AND permission='write'";

  multiset(string) res = (<>);
  Sql.sql_result sqlres = big_query (q, CN (conf->name));
  while (array(string) ent = sqlres->fetch_row())
    res[ent[0]] = 1;

  return user_db_permissions[key] = res;
}

protected mapping connection_user_cache  = ([]);

string get_db_user( string db_name, Configuration conf, int read_only )
//! Returns the name of a MySQL user which has the requested access.
//! This user is suitable to pass to @[low_get].
//!
//! If @[conf] is zero then a user with global read or read/write
//! access (according to @[read_only]) is returned.
//!
//! Otherwise, if @[db_name] is zero then a user is returned that has
//! read or read/write access (depending on @[read_only]) to the
//! databases for @[conf] according to its permission settings.
//!
//! Otherwise, a check is done that @[conf] has the requested access
//! on @[db_name], and if it does then a user is returned that can
//! access all databases for @[conf] according to its permission
//! settings.
{
  if (!conf) return read_only ? "ro" : "rw";

  string key = db_name+"|"+(conf&&conf->name)+"|"+read_only;
  if( !zero_type( connection_user_cache[ key ] ) )
    return connection_user_cache[ key ];

  if (!db_name)
    return connection_user_cache[key] =
      short (conf->name) + (read_only ? "_ro" : "_rw");

  array(mapping(string:mixed)) res =
    query( "SELECT permission FROM db_permissions "
	   "WHERE db=%s AND config=%s",  db_name, CN(conf->name));
  if( sizeof( res ) && res[0]->permission != "none" )
    return connection_user_cache[ key ]=short(conf->name) +
      ((read_only || res[0]->permission!="write")?"_ro":"_rw");

  return connection_user_cache[ key ] = 0;
}

protected mapping restricted_user_cache = ([]);

string get_restricted_db_user (multiset(string) dbs, Configuration conf,
			       int read_only)
//! Returns the name of a MySQL user which has read or read/write
//! access (depending on @[read_only]) to the databases listed in
//! @[dbs]. This user is suitable to pass to @[low_get].
//!
//! If @[conf] is given then the access is restricted according to the
//! permission settings for that configuration. Zero is returned if
//! @[conf] doesn't have any access on any of the specified databases.
//!
//! @note
//! Returned users can get zapped if db permissions change. Validity
//! should always be checked with @[is_valid_db_user] before use.
{
  multiset(string) conf_ro_dbs = conf && config_db_access (conf, 1);
  multiset(string) allowed_ro_dbs = conf_ro_dbs ? dbs & conf_ro_dbs : dbs;
  if (!sizeof (allowed_ro_dbs)) return 0;

  string key = make_autouser_name (read_only ? READ : WRITE, dbs, conf);
  {
    string val = restricted_user_cache[key];
    if (!zero_type (val)) return val;
  }

  if (equal (dbs, conf_ro_dbs)) {
    string nonautouser = short (conf->name) + (read_only ? "_ro" : "_rw");
    return restricted_user_cache[key] =
      restricted_user_cache[nonautouser] = nonautouser;
  }

  multiset(string) denied_dbs = dbs - allowed_ro_dbs;
  multiset(string) allowed_rw_dbs;
  if (read_only)
    allowed_rw_dbs = (<>);
  else {
    if (conf) {
      allowed_rw_dbs = dbs & config_db_access (conf, 0);
      allowed_ro_dbs -= allowed_rw_dbs;
    }
    else {
      allowed_rw_dbs = dbs;
      allowed_ro_dbs = (<>);
    }
  }

  fix_autouser (key, allowed_rw_dbs, allowed_ro_dbs, denied_dbs);
  return restricted_user_cache[key] = key;
}

int is_valid_db_user (string user)
//! Returns true if @[user] is a valid local access MySQL user.
{
  if (restricted_user_cache[user]) return 1;
  return check_db_user (user, "localhost");
}

Sql.Sql get( string name, void|Configuration conf,
	     int|void read_only, void|int reuse_in_thread,
	     void|string charset)
//! Returns an SQL connection object for a database named under the
//! "DB" tab in the administration interface.
//!
//! @param name
//!   The name of the database.
//!
//! @param conf
//!   If this isn't zero, only return the database if this
//!   configuration has at least read access.
//!
//! @param read_only
//!   Return a read-only connection if this is set. A read-only
//!   connection is also returned if @[conf] is specified and only has
//!   read access (regardless of @[read_only]).
//!
//! @param reuse_in_thread
//!   If this is nonzero then the SQL connection is reused within the
//!   current thread. I.e. other calls to this function from this
//!   thread with the same @[name] and @[read_only] and a nonzero
//!   @[reuse_in_thread] will return the same object. However, the
//!   connection won't be reused while a result object from
//!   @[Sql.Sql.big_query] or similar exists.
//!
//!   Using this flag is a good way to cut down on the amount of
//!   simultaneous connections, and to avoid deadlocks when
//!   transactions or locked tables are used (other problems can occur
//!   instead though, if transactions or table locking is done
//!   recursively). However, the caller has to ensure that the
//!   connection never becomes in use by another thread. The safest
//!   way to ensure that is to always keep it on the stack, i.e. only
//!   assign it to variables declared inside functions or pass it in
//!   arguments to functions.
//!
//! @param charset
//!   If this is nonzero then the returned connection is configured to
//!   use the specified charset for queries and returned text strings.
//!
//!   The valid values and their meanings depend on the type of
//!   database connection. However, the special value
//!   @expr{"unicode"@} configures the connection to accept and return
//!   unencoded (possibly wide) unicode strings (provided the
//!   connection supports this).
//!
//!   An error is thrown if the database connection doesn't support
//!   the given charset, but the argument is ignored if the database
//!   doesn't have any charset support at all, i.e. no @[set_charset]
//!   function.
//!
//!   See @[Sql.Sql.set_charset] for more information.
//!
//! @note
//! A charset being set through the @[charset] argument or
//! @[Sql.Sql.set_charset] is tracked and reset properly when a
//! connection is reused. If the charset (or any other context info,
//! for that matter) is changed some other way then it must be
//! restored before the connection is released.
{
  return low_get( get_db_user( name, conf, read_only), name, reuse_in_thread,
		  charset);
}

Sql.Sql cached_get( string name, void|Configuration c, void|int read_only,
		    void|string charset)
{
  return get (name, c, read_only, 0, charset);
}

protected Thread.Local table_locks = Thread.Local();
protected class TableLockInfo (
  Sql.Sql db,
  int count,
  multiset(string) locked_for_read,
  multiset(string) locked_for_write,
) {}

class MySQLTablesLock
//! This class is a helper to do MySQL style LOCK TABLES in a safer
//! way:
//!
//! o  It avoids nested LOCK TABLES which would implicitly release the
//!    previous lock. Instead it checks that the outermost lock
//!    encompasses all tables.
//! o  It ensures UNLOCK TABLES always gets executed on exit through
//!    the refcount garb strategy (i.e. put it in a local variable
//!    just like a @[Thread.MutexKey]).
//! o  It checks that the @[reuse_in_thread] flag was used to
//!    @[DBManager.get] to ensure that a thread doesn't outlock itself
//!    by using different connections.
//!
//! Note that atomic queries and updates don't require
//! @[MySQLTablesLock] stuff even when it's used in other places at
//! the same time. They should however use a connection retrieved with
//! @[reuse_in_thread] set to avoid deadlocks.
{
  protected TableLockInfo lock_info;

  protected void create (Sql.Sql db,
			 array(string) read_tables,
			 array(string) write_tables)
  //! @[read_tables] and @[write_tables] contain the tables to lock
  //! for reading and writing, respectively. A table string may be
  //! written as @expr{"foo AS bar"@} to specify an alias.
  {
    if (!db->db_name)
      error ("db was not retrieved with DBManager.get().\n");
    if (!db->reuse_in_thread)
      error ("db was not retrieved with DBManager.get(x,y,z,1).\n");

    multiset(string) read_tbl = (<>);
    foreach (read_tables || ({}), string tbl) {
      sscanf (tbl, "%[^ \t]", tbl);
      read_tbl[tbl] = 1;
    }

    multiset(string) write_tbl = (<>);
    foreach (write_tables || ({}), string tbl) {
      sscanf (tbl, "%[^ \t]", tbl);
      write_tbl[tbl] = 1;
    }

    mapping(string:TableLockInfo) dbs = table_locks->get();
    if (!dbs) table_locks->set (dbs = ([]));

    if ((lock_info = dbs[db->db_name])) {
      if (lock_info->db != db)
	error ("Tables %s are already locked by this thread through "
	       "a different connection.\nResult objects from "
	       "db->big_query or similar might be floating around, "
	       "or normal and read-only access might be mixed.\n",
	       indices (lock_info->locked_for_read &
			lock_info->locked_for_write) * ", ");
      if (sizeof (read_tbl - lock_info->locked_for_read -
		  lock_info->locked_for_write))
	error ("Cannot read lock more tables %s "
	       "due to already held locks on %s.\n",
	       indices (read_tbl - lock_info->locked_for_read -
			lock_info->locked_for_write) * ", ",
	       indices (lock_info->locked_for_read &
			lock_info->locked_for_write) * ", ");
      if (sizeof (write_tbl - lock_info->locked_for_write))
	error ("Cannot write lock more tables %s "
	       "due to already held locks on %s.\n",
	       indices (write_tbl - lock_info->locked_for_write) * ", ",
	       indices (lock_info->locked_for_read &
			lock_info->locked_for_write) * ", ");
#ifdef TABLE_LOCK_DEBUG
      werror ("[%O, %O] MySQLTablesLock.create(): Tables already locked: "
	      "read: [%{%O, %}], write: [%{%O, %}]\n",
	      this_thread(), db,
	      indices (lock_info->locked_for_read),
	      indices (lock_info->locked_for_write));
#endif
      lock_info->count++;
    }

    else {
      string query = "LOCK TABLES " +
	({
	  sizeof (read_tbl) && (read_tables * " READ, " + " READ"),
	  sizeof (write_tbl) && (write_tables * " WRITE, " + " WRITE")
	}) * ", ";
#ifdef TABLE_LOCK_DEBUG
      werror ("[%O, %O] MySQLTablesLock.create(): %s\n",
	      this_thread(), db, query);
#endif
      db->query (query);
      dbs[db->db_name] = lock_info =
	TableLockInfo (db, 1, read_tbl, write_tbl);
    }
  }

  int topmost_lock()
  {
    return lock_info->count == 1;
  }

  Sql.Sql get_db()
  {
    return lock_info->db;
  }

  protected void destroy()
  {
    if (!--lock_info->count) {
#ifdef TABLE_LOCK_DEBUG
      werror ("[%O, %O] MySQLTablesLock.destroy(): UNLOCK TABLES\n",
	      this_thread(), lock_info->db);
#endif
      lock_info->db->query ("UNLOCK TABLES");
      m_delete (table_locks->get(), lock_info->db->db_name);
    }
#ifdef TABLE_LOCK_DEBUG
    else
      werror ("[%O, %O] MySQLTablesLock.destroy(): %d locks left\n",
	      this_thread(), lock_info->db, lock_info->count);
#endif
  }
}

void drop_db( string name )
//! Drop the database @[name]. If the database is internal, the actual
//! tables will be deleted as well.
{
  if( (< "local", "mysql", "roxen"  >)[ name ] )
    error( "Cannot drop the '%s' database\n", name );

  array q = query( "SELECT name,local FROM dbs WHERE name=%s", name );
  if(!sizeof( q ) )
    error( "The database "+name+" does not exist\n" );
  if( sizeof( q ) && (int)q[0]["local"] ) {
    invalidate_autousers (name);
    query( "DROP DATABASE `"+name+"`" );
    Sql.Sql db = connect_to_my_mysql (0, "mysql");
    db->big_query ("DELETE FROM db WHERE Db=%s", name);
    db->big_query ("FLUSH PRIVILEGES");
  }
  query( "DELETE FROM dbs WHERE name=%s", name );
  query( "DELETE FROM db_groups WHERE db=%s", name );
  query( "DELETE FROM db_permissions WHERE db=%s", name );
  changed();
}

void set_url( string db, string url, int is_internal )
//! Set the URL for the specified database.
//! No data is copied.
//! This function call only works for external databases. 
{
  query( "UPDATE dbs SET path=%s, local=%d WHERE name=%s",
	 url, is_internal, db );
  changed();
}

void set_db_default_charset( string db, string default_charset )
//! Set the default character set for the specified database.
//! No data is recoded.
{
  if (default_charset && (default_charset != "")) {
    query( "UPDATE dbs SET default_charset=%s WHERE name=%s",
	   default_charset, db );
  } else {
    query( "UPDATE dbs SET default_charset=NULL WHERE name=%s", db );
  }
  changed();
}

string get_db_default_charset( string db)
//! Get the default character set for the specified database.
//! Returns @tt{0@} (zero) if no default has been set.
{
  array(mapping(string:string)) res =
    query( "SELECT default_charset FROM dbs WHERE name=%s",
	   db );
  if (sizeof(res)) return res[0]->default_charset;
  return 0;
}

void copy_db_md( string oname, string nname )
//! Copy the metadata from oname to nname. Both databases must exist
//! prior to this call.
{
  mapping m = get_permission_map( )[oname];
  foreach( indices( m ), string s )
    if( Configuration c = roxenp()->find_configuration( s ) )
      set_permission( nname, c, m[s] );
  changed();
}

array(mapping) backups( string dbname )
{
  if( dbname )
    return query( "SELECT * FROM db_backups WHERE db=%s", dbname );
  return query("SELECT * FROM db_backups"); 
}

array(mapping) restore( string dbname, string directory, string|void todb,
			array|void tables )
//! Restore the contents of the database dbname from the backup
//! directory. New tables will not be deleted.
//!
//! This function supports restoring both backups generated with @[backup()]
//! and with @[dump()].
//!
//! The format of the result is as for the second element in the
//! return array from @[backup]. If todb is specified, the backup will
//! be restored in todb, not in dbname.
//!
//! @note
//!   When restoring backups generated with @[dump()] the @[tables]
//!   parameter is ignored.
{
  Sql.Sql db = cached_get( todb || dbname );

  if( !directory )
    error("Illegal directory\n");

  if( !db )
    error("Illegal database\n");

  directory = combine_path( getcwd(), directory );

  string fname;

  if (Stdio.is_file(fname = directory + "/dump.sql") ||
      Stdio.is_file(fname = directory + "/dump.sql.bz2") ||
      Stdio.is_file(fname = directory + "/dump.sql.gz")) {
    // mysqldump-style backup.

    Stdio.File raw = Stdio.File(fname, "r");
    Stdio.File cooked = raw;
    if (has_suffix(fname, ".bz2")) {
      cooked = Stdio.File();
      Process.Process(({ "bzip2", "-cd" }),
		      ([ "stdout":cooked->pipe(Stdio.PROP_IPC),
			 "stdin":raw,
		      ]));
      raw->close();
    } else if (has_suffix(fname, ".gz")) {
      cooked = Stdio.File();
      Process.Process(({ "gzip", "-cd" }),
		      ([ "stdout":cooked->pipe(Stdio.PROP_IPC),
			 "stdin":raw,
		      ]));
      raw->close();
    }
    report_notice("Restoring backup file %s to database %s...\n",
		  fname, todb || dbname);
    execute_sql_script_file(db, cooked);
    report_notice("Backup file %s restored to database %s.\n",
		  fname, todb || dbname);
    // FIXME: Return a proper result.
    return ({});
  }

  // Old-style BACKUP format.
  array q =
    tables ||
    query( "SELECT tbl FROM db_backups WHERE db=%s AND directory=%s",
	   dbname, directory )->tbl;

  string db_dir =
    roxenp()->query_configuration_dir() + "/_mysql/" + dbname;

  int(0..1) use_restore = (normalized_server_version <= "005.005");
  if (!use_restore) {
    report_warning("Restoring an old-style backup by hand...\n");

    if (!Stdio.is_dir(db_dir + "/.")) {
      error("Failed to find database directory for db %O.\n"
	    "Tried: %O\n",
	    dbname, db_dir);
    }
  }

  array res = ({});
  foreach( q, string table )
  {
    db->query( "DROP TABLE IF EXISTS "+table);
    if (use_restore) {
      directory = combine_path( getcwd(), directory );
      res += db->query( "RESTORE TABLE "+table+" FROM %s", directory );
    } else {
      // Copy the files.
      foreach(({ ".frm", ".MYD", ".MYI" }), string ext) {
	if (Stdio.is_file(directory + "/" + table + ext)) {
	  if (!Stdio.cp(directory + "/" + table + ext,
			db_dir + "/" + table + ext)) {
	    error("Failed to copy %O to %O.\n",
		  directory + "/" + table + ext,
		  db_dir + "/" + table + ext);
	  }
	} else if (ext != ".MYI") {
	  error("Backup file %O is missing!\n",
		directory + "/" + table + ext);
	}
      }
      res += db->query("REPAIR TABLE "+table+" USE_FRM");
    }
  }
  return res;
}

void delete_backup( string dbname, string directory )
//! Delete a backup previously done with @[backup()] or @[dump()].
{
  // 1: Delete all backup files.
  array(string) tables =
    query( "SELECT tbl FROM db_backups WHERE db=%s AND directory=%s",
	   dbname, directory )->tbl;
  if (!sizeof(tables)) {
    // Backward compat...
    directory = combine_path( getcwd(), directory );
    tables =
      query( "SELECT tbl FROM db_backups WHERE db=%s AND directory=%s",
	     dbname, directory )->tbl;
  }
  foreach( tables, string table )
  {
    rm( directory+"/"+table+".frm" );
    rm( directory+"/"+table+".MYD" );
  }
  rm( directory+"/dump.sql" );
  rm( directory+"/dump.sql.bz2" );
  rm( directory+"/dump.sql.gz" );
  rm( directory );

  // 2: Delete the information about this backup.
  query( "DELETE FROM db_backups WHERE db=%s AND directory=%s",
	 dbname, directory );
}

array(string|array(mapping)) dump(string dbname, string|void directory,
				  string|void tag)
//! Make a backup using @tt{mysqldump@} of all data in the specified database.
//! If a directory is not specified, one will be created in $VARDIR.
//!
//! @param dbname
//!   Database to backup.
//! @param directory
//!   Directory to store the backup in.
//!   Defaults to a directory under @tt{$VARDIR@}/backup.
//! @param tag
//!   Flag indicating the subsystem that requested the backup
//!   (eg @[timed_backup()] sets it to @expr{"timed_backup"@}.
//!   This flag is used to let the backup generation cleanup
//!   differentiate between its backups and others.
//!
//! This function is similar to @[backup()], but uses a different
//! storage format, and supports backing up external (MySQL) databases.
//!
//! @returns
//!   Returns an array with the following structure:
//!   @array
//!   	@elem string directory
//!   	  Name of the directory.
//!   	@elem array(mapping(string:string)) db_info
//!   	@array
//!   	  @elem mapping(string:string) table_info
//!   	    @mapping
//!   	      @member string "Table"
//!   		Table name.
//!   	      @member string "Msg_type"
//!   		one of:
//!   		@string
//!   		  @value "status"
//!   		  @value "error"
//!   		  @value "info"
//!   		  @value "warning"
//!   		@endstring
//!   	      @member string "Msg_text"
//!   		The message.
//!   	    @endmapping
//!   	@endarray
//!   @endarray
//!
//! @note
//!   This function currently only works for MySQL databases.
//!
//! @seealso
//!   @[backup()]
{
  mapping(string:mixed) db_url_info = get_db_url_info(dbname);
  if (!db_url_info)
    error("Illegal database.\n");

  if (!sizeof(db_tables( dbname ))) {
    // Nothing to backup.
    return 0;
  }

  string mysqldump = roxenloader->parse_mysql_location()->mysqldump;
  if (!mysqldump) {
    error("Mysqldump backup method not supported "
	  "without a mysqldump binary.\n"
	  "%O\n", roxenloader->parse_mysql_location());
  }

  if( !directory )
    directory = roxen_path( "$VARDIR/backup/"+dbname+"-"+isodate(time(1)) );
  directory = combine_path( getcwd(), directory );

  string db_url = db_url_info->path;

  if ((int)db_url_info->local) {
    db_url = replace(roxenloader->my_mysql_path, ({ "%user%", "%db%" }),
		     ({ "ro", dbname || "mysql" }));
  }
  if (!has_prefix(db_url, "mysql://"))
    error("Currently only supports MySQL databases.\n");
  string host = (db_url/"://")[1..]*"://";
  string port;
  string user;
  string password;
  string db;
  array(string) arr = host/"@";
  if (sizeof(arr) > 1) {
    // User and/or password specified
    host = arr[-1];
    arr = (arr[..<1]*"@")/":";
    if (!user && sizeof(arr[0])) {
      user = arr[0];
    }
    if (!password && (sizeof(arr) > 1)) {
      password = arr[1..]*":";
      if (password == "") {
	password = 0;
      }
    }
  }
  arr = host/"/";
  if (sizeof(arr) > 1) {
    host = arr[..<1]*"/";
    db = arr[-1];
  } else {
    error("No database specified in DB-URL for DB alias %s.\n", dbname);
  }
  arr = host/":";
  if (sizeof(arr) > 1) {
    port = arr[1..]*":";
    host = arr[0];
  }

  // Time to build the command line...
  array(string) cmd = ({ mysqldump, "--add-drop-table", "--create-options",
			 "--complete-insert", "--compress",
			 "--extended-insert", "--hex-blob",
			 "--quick", "--quote-names" });
  if ((host == "") || (host == "localhost")) {
    // Socket.
    if (port) {
      cmd += ({ "--socket=" + port });
    }
  } else {
    // Hostname.
    cmd += ({ "--host=" + host });
    if (port) {
      cmd += ({ "--port=" + port });
    }
  }
  if (user) {
    cmd += ({ "--user=" + user });
  }
  if (password) {
    cmd += ({ "--password=" + password });
  }

  mkdirhier( directory+"/" );

  cmd += ({
    "--result-file=" + directory + "/dump.sql",
    db,
  });

  werror("Backing up database %s to %s/dump.sql...\n", dbname, directory);
  // werror("Starting mysqldump command: %O...\n", cmd);

  if (Process.Process(cmd)->wait()) {
    error("Mysql dump command failed for DB %s.\n", dbname);
  }

  foreach( db_tables( dbname ), string table )
  {
    query( "DELETE FROM db_backups WHERE "
	   "db=%s AND directory=%s AND tbl=%s",
	   dbname, directory, table );
    query( "INSERT INTO db_backups (db,tbl,directory,whn,tag) "
	   "VALUES (%s,%s,%s,%d,%s)",
	   dbname, table, directory, time(), tag );
  }

  if (Process.Process(({ "bzip2", "-f9", directory + "/dump.sql" }))->
      wait() &&
      Process.Process(({ "gzip", "-f9", directory + "/dump.sql" }))->
      wait()) {
    werror("Failed to compress the database dump.\n");
  }

  // FIXME: Fix the returned table_info!
  return ({ directory,
	    map(db_tables(dbname),
		lambda(string table) {
		  return ([ "Table":table,
			    "Msg_type":"status",
			    "Msg_text":"Backup ok",
		  ]);
		}),
  });
}

array(string|array(mapping)) backup( string dbname, string|void directory,
				     string|void tag)
//! Make a backup of all data in the specified database.
//! If a directory is not specified, one will be created in $VARDIR.
//!
//! @param dbname
//!   (Internal) database to backup.
//! @param directory
//!   Directory to store the backup in.
//!   Defaults to a directory under @tt{$VARDIR@}/backup.
//! @param tag
//!   Flag indicating the subsystem that requested the backup
//!   (eg @[timed_backup()] sets it to @expr{"timed_backup"@}.
//!   This flag is used to let the backup generation cleanup
//!   differentiate between its backups and others.
//!
//! @returns
//!   Returns an array with the following structure:
//!   @array
//!   	@elem string directory
//!   	  Name of the directory.
//!   	@array
//!   	  @elem mapping(string:string) table_info
//!   	    @mapping
//!   	      @member string "Table"
//!   		Table name.
//!   	      @member string "Msg_type"
//!   		one of:
//!   		@string
//!   		  @value "status"
//!   		  @value "error"
//!   		  @value "info"
//!   		  @value "warning"
//!   		@endstring
//!   	      @member string "Msg_text"
//!   		The message.
//!   	    @endmapping
//!   	@endarray
//!   @endarray
//!
//! @note
//!   Currently this function only works for internal databases.
//!
//! @note
//!   This method is not supported in MySQL 5.5 and later.
//!
//! @seealso
//!   @[dump()]
{
  Sql.Sql db = cached_get( dbname );

  if( !db )
    error("Illegal database\n");

  if( !directory )
    directory = roxen_path( "$VARDIR/backup/"+dbname+"-"+isodate(time(1)) );
  directory = combine_path( getcwd(), directory );

  if( is_internal( dbname ) )
  {
    if (normalized_server_version >= "005.005") {
      error("Old-style MySQL BACKUP files are no longer supported!\n");
    }
    mkdirhier( directory+"/" );
    array tables = db_tables( dbname );
    array res = ({});
    foreach( tables, string table )
    {
      res += db->query( "BACKUP TABLE "+table+" TO %s",directory);
      query( "DELETE FROM db_backups WHERE "
	     "db=%s AND directory=%s AND tbl=%s",
	     dbname, directory, table );
      query( "INSERT INTO db_backups (db,tbl,directory,whn,tag) "
	     "VALUES (%s,%s,%s,%d,%s)",
	     dbname, table, directory, time(), tag );
    }

    return ({ directory,res });
  }
  else
  {
    error("Currently only handles internal databases\n");
    // Harder. :-)
  }
}

//! Call-out id's for backup schedules.
protected mapping(int:mixed) backup_cos = ([]);

//! Perform a scheduled database backup.
//!
//! @param schedule_id
//!   Database to backup.
//!
//! This function is called by the database backup scheduler
//! to perform the scheduled backup.
//!
//! @seealso
//!   @[set_backup_timer()]
void timed_backup(int schedule_id)
{
  mixed co = m_delete(backup_cos, schedule_id);
  if (co) remove_call_out(co);

  array(mapping(string:string))
    backup_info = query("SELECT schedule, period, offset, dir, "
			"       generations, method "
			"  FROM db_schedules "
			" WHERE id = %d "
			"   AND period > 0 ",
			schedule_id);
  if (!sizeof(backup_info)) return;	// Timed backups disabled.
  string base_dir = backup_info[0]->dir || "";
  if (!has_prefix(base_dir, "/")) {
    base_dir = "$VARDIR/backup/" + base_dir;
  }

  report_notice("Performing database backup according to schedule %s...\n",
		backup_info[0]->schedule);

  foreach(query("SELECT name "
		"  FROM dbs "
		" WHERE schedule_id = %d",
		schedule_id)->name, string db) {
    mixed err = catch {
	mapping lt = localtime(time(1));
	string dir = roxen_path(base_dir + "/" + db + "-" + isodate(time(1)) +
				sprintf("T%02d-%02d", lt->hour, lt->min));

	switch(backup_info[0]->method) {
	case "backup":
	  // This method is not supported in MySQL 5.5 and later.
	  if (normalized_server_version < "005.005") {
	    backup(db, dir, "timed_backup");
	    break;
	  }
	  // FALL_THROUGH
	default:
	  report_error("Unsupported database backup method: %O for DB %O\n"
		       "Falling back to the default \"mysqldump\" method.\n",
		       backup_info[0]->method, db);
	  // FALL_THROUGH
	case "mysqldump":
	  dump(db, dir, "timed_backup");
	  break;
	}
	int generations = (int)backup_info[0]->generations;
	if (generations) {
	  foreach(query("SELECT directory FROM db_backups "
			" WHERE db = %s "
			"   AND tag = %s "
			" GROUP BY directory "
			" ORDER BY whn DESC "
			" LIMIT %d, 65536",
			db, "timed_backup", generations)->directory,
		  string dir) {
	    report_notice("Removing old backup %O of DB %O...\n",
			  dir, db);
	    delete_backup(db, dir);
	  }
	}
      };
    if (err) {
      master()->handle_error(err);
      err = catch {
	  if (has_prefix(err[0], "Unsupported ")) {
	    report_error("Disabling timed backup of database %s.\n", db);
	    query("UPDATE dbs "
		  "   SET schedule_id = NULL "
		  " WHERE name = %s ",
		  db);
	  }
	};
      if (err) {
	master()->handle_error(err);
      }
    }
  }

  report_notice("Database backup according to schedule %s completed.\n",
		backup_info[0]->schedule);

  start_backup_timer(schedule_id, (int)backup_info[0]->period,
		     (int)backup_info[0]->offset);
}

//! Set (and restart) a backup schedule.
//!
//! @param schedule_id
//!   Backup schedule to configure.
//! @param period
//!   Backup interval. @expr{0@} (zero) to disable automatic backups.
//! @param offset
//!   Backup interval offset.
//!
//! See @[start_backup_timer()] for details about @[period] and @[offset].
//!
//! @seealso
//!   @[start_backup_timer()]
void low_set_backup_timer(int schedule_id, int period, int offset)
{
  query("UPDATE db_schedules "
	"   SET period = %d, "
	"       offset = %d "
	" WHERE id = %d",
	period, offset, schedule_id);

  start_backup_timer(schedule_id, period, offset);
}

//! Set (and restart) a backup schedule.
//!
//! @param schedule_id
//!   Backup schedule to configure.
//! @param period
//!   Backup interval in seconds.
//!   Typically @expr{604800@} (weekly) or @expr{86400@} (dayly),
//!   or @expr{0@} (zero - disabled).
//! @param weekday
//!   Day of week to perform backups on (if weekly backups).
//!   @expr{0@} (zero) or @expr{7@} for Sunday.
//! @param tod
//!   Time of day in seconds to perform the backup.
//!
//! @seealso
//!   @[low_set_backup_timer()]
void set_backup_timer(int schedule_id, int period, int weekday, int tod)
{
  low_set_backup_timer(schedule_id, period, tod + ((weekday + 3)%7)*86400);
}

//! (Re-)start the timer for a backup schedule.
//!
//! @param schedule_id
//!   Backup schedule to (re-)start.
//! @param period
//!   Backup interval in seconds (example: @expr{604800@} for weekly).
//!   Specifying a period of @expr{0@} (zero) disables the backup timer
//!   for the database temporarily (until the next call or server restart).
//! @param offset
//!   Offset in seconds from Thursday 1970-01-01 00:00:00 local time
//!   for the backup period (example: @expr{266400@} (@expr{3*86400 + 2*3600@})
//!   for Sundays at 02:00).
//!
//! @seealso
//!   @[timed_backup()], @[start_backup_timers()]
void start_backup_timer(int schedule_id, int period, int offset)
{
  mixed co = m_delete(backup_cos, schedule_id);
  if (co) remove_call_out(co);

  if (!period) return;

  int t = -time(1);
  mapping(string:int) lt = localtime(-t);
  t += offset + lt->timezone;
  t %= period;

  if (!t) t += period;

  backup_cos[schedule_id] =
    roxenp()->background_run(t, timed_backup, schedule_id);
}

//! (Re-)start backup timers for all databases.
//!
//! This function calls @[start_backup_timer()] for
//! all configured databases.
//!
//! @seealso
//!   @[start_backup_timer()]
void start_backup_timers()
{
  foreach(query("SELECT id, schedule, period, offset "
		"  FROM db_schedules "
		" WHERE period > 0 "
		" ORDER BY id ASC"),
	  mapping(string:string) backup_info) {
    report_notice("Starting the backup timer for the %s backup schedule.\n",
		  backup_info->schedule);
    start_backup_timer((int)backup_info->id, (int)backup_info->period,
		       (int)backup_info->offset);
  }
}

void rename_db( string oname, string nname )
//! Rename a database. Please note that the actual data (in the case of
//! internal database) is not copied. The old database is deleted,
//! however. For external databases, only the metadata is modified, no
//! attempt is made to alter the external database.
{
  query( "UPDATE dbs SET name=%s WHERE name=%s", oname, nname );
  query( "UPDATE db_permissions SET db=%s WHERE db=%s", oname, nname );
  if( is_internal( oname ) )
  {
    Sql.Sql db = connect_to_my_mysql( 0, "mysql" );
    db->query("CREATE DATABASE IF NOT EXISTS %s",nname);
    db->query("UPDATE db SET Db=%s WHERE Db=%s",oname, nname );
    db->query("DROP DATABASE IF EXISTS %s",oname);
    query( "FLUSH PRIVILEGES" );
  }
  changed();
}

mapping get_group( string name )
{
  array r= query( "SELECT * FROM groups WHERE name=%s", name );
  if( sizeof( r ) )
    return r[0];
}

array(string) list_groups()
{
  return query( "SELECT name FROM groups" )->name;
}

int create_group( string name,    string lname,
		     string comment, string pattern )
{
  if( get_group( name ) )
  {
    query( "UPDATE groups SET comment=%s, pattern=%s, lname=%s "
	   "WHERE name=%s",  comment, pattern, lname, name );
  }
  else
  {
    query("INSERT INTO groups (comment,pattern,lname,name) "
	  "VALUES (%s,%s,%s,%s)", comment, pattern, lname, name );
  }
}

int delete_group( string name )
{
  if( !get_group( name ) )
    return 0;
  if( sizeof(group_dbs( name )) )
    return 0;
  query( "DELETE FROM groups WHERE name=%s", name );
  return 1;
}

array(string) group_dbs( string group )
{
  return query( "SELECT db FROM db_groups WHERE groupn=%s", group )
    ->db
#ifndef YES_I_KNOW_WHAT_I_AM_DOING
      -({"roxen","mysql"})
#endif
    ;
}

string db_group( string db )
{
  array q =query( "SELECT groupn FROM db_groups WHERE db=%s", db );
  if( sizeof( q )  )
    return q[0]->groupn;
  return "internal";
}

string db_schedule( string db )
{
  array q = query("SELECT schedule FROM dbs, db_schedules "
		  " WHERE schedule_id = db_schedules.id "
		  "   AND name = %s", db);
  if (!sizeof(q)) return UNDEFINED;
  return q[0]->schedule;
}

string get_group_path( string db, string group )
{
  mapping m = get_group( group );
  if( !m )
    error("The group %O does not exist.", group );
  if( strlen( m->pattern ) )
  {
    catch
    {
      Sql.Sql sq = Sql.Sql( m->pattern+"mysql" );
      sq->query( "CREATE DATABASE "+db );
    };
    return m->pattern+db;
  }
  return 0;
}

void set_db_group( string db, string group )
{
  query("DELETE FROM db_groups WHERE db=%s", db);
  query("INSERT INTO db_groups (db,groupn) VALUES (%s,%s)",
	db, group );
}

void create_db( string name, string path, int is_internal,
		string|void group, string|void default_charset )
//! Create a new symbolic database alias.
//!
//! If @[is_internal] is specified, the database will be automatically
//! created if it does not exist, and the @[path] argument is ignored.
//!
//! If the database @[name] already exists, an error will be thrown
//!
//! If group is specified, the @[path] will be generated
//! automatically using the groups defined by @[create_group]
{
  if( get( name ) )
    error("The database "+name+" already exists\n");
  if( sizeof((array)name & ({ '@', ' ', '-', '&', '%', '\t',
			      '\n', '\r', '\\', '/', '\'', '"',
			      '(', ')', '*', '+', }) ) )
    error("Please do not use any of the characters @, -, &, /, \\ "
	  "or %% in database names.\nAlso avoid whitespace characters\n");
  if( has_value( name, "-" ) )
    name = replace( name, "-", "_" );
  if( group )
  {
    set_db_group( name, group );
    if( is_internal )
    {
      path = get_group_path( name, group );
      if( path )
	is_internal = 0;
    }
  }
  else
    query("INSERT INTO db_groups (db,groupn) VALUES (%s,%s)",
	  name, "internal" );

  if (default_charset) {
    query( "INSERT INTO dbs (name, path, local, default_charset) "
	   "VALUES (%s, %s, %s, %s)", name,
	   (is_internal?name:path), (is_internal?"1":"0"), default_charset );
  } else {
    query( "INSERT INTO dbs (name, path, local) "
	   "VALUES (%s, %s, %s)",
	   name, (is_internal?name:path), (is_internal?"1":"0") );
  }
  if (!is_internal) {
    // Don't attempt to backup external databases automatically.
    query("UPDATE dbs SET schedule_id = NULL WHERE name = %s", name);
  } else {
    catch(query( "CREATE DATABASE `"+name+"`"));
  }
  changed();
}

int set_external_permission( string name, Configuration c, int level,
			     string password )
//! Set the permission for the configuration @[c] on the database
//! @[name] to @[level] for an external tcp connection from 127.0.0.1
//! authenticated via password @[password].
//!
//! Levels:
//!  @int
//!    @value DBManager.NONE
//!      No access
//!    @value DBManager.READ
//!      Read access
//!    @value DBManager.WRITE
//!      Write access
//!  @endint
//!
//! @returns
//!  This function returns 0 if it fails. The only reason for it to
//!  fail is if there is no database with the specified @[name].
//!
//! @note
//!  This function is only valid for local databases.
//!
//! @seealso
//!  @[set_permission()], @[get_db_user()]
{
  array(mapping(string:mixed)) d =
           query("SELECT path,local FROM dbs WHERE name=%s", name );

  if( !sizeof( d ) )
      return 0;

  if( (int)d[0]["local"] )
    set_external_user_permissions( c, name, level, password );
  
  return 1;
}

int set_permission( string name, Configuration c, int level )
//! Set the permission for the configuration @[c] on the database
//! @[name] to @[level].
//!
//! Levels:
//!  @int
//!    @value DBManager.NONE
//!      No access
//!    @value DBManager.READ
//!      Read access
//!    @value DBManager.WRITE
//!      Write access
//!  @endint
//!
//!  Please note that for non-local databases, it's not really
//!  possible to differentiate between read and write permissions,
//!  roxen does try to do that anyway by checking the requests and
//!  disallowing anything but 'select' and 'show' from read only
//!  databases. Please note that this is not really all that secure.
//!
//!  From local (in the mysql used by Roxen) databases, the
//!  permissions are enforced by using different users, and should be
//!  secure as long as the permission system in mysql is not modified
//!  directly by the administrator.
//!
//! @returns
//!  This function returns 0 if it fails. The only reason for it to
//!  fail is if there is no database with the specified @[name].
{
  array(mapping(string:mixed)) d =
           query("SELECT path,local FROM dbs WHERE name=%s", name );

  if( !sizeof( d ) )
      return 0;

  query( "DELETE FROM db_permissions WHERE db=%s AND config=%s",
         name,CN(c->name) );

  query( "INSERT INTO db_permissions (db,config,permission) "
	 "VALUES (%s,%s,%s)", name,CN(c->name),
	 (level?level==2?"write":"read":"none") );
  
  if( (int)d[0]["local"] )
    set_user_permissions( c, name, level );

  clear_sql_caches();

  return 1;
}

mapping(string:string) module_table_info( string db, string table )
{
  array(mapping(string:string)) td;
  mapping(string:string) res1;
  if( sizeof(td=query("SELECT * FROM module_tables WHERE db=%s AND tbl=%s",
		      db, table ) ) ) {
    res1 = td[0];
    foreach (td, mapping(string:mixed) row) {
      if (table != "" ||
	  (row->conf && sizeof (row->conf) &&
	   row->module && sizeof (row->module)))
	return row;
    }
  }
  else
    res1 = ([]);

  // Many modules don't set the conf and module on the database but
  // only on the individual tables, so do some more effort to find a
  // common conf and module if table == "".

  if (table == "" &&
      sizeof (td = query ("SELECT DISTINCT conf, module, db FROM module_tables "
			  "WHERE db=%s AND tbl!=\"\"", db))) {
    if (sizeof (td) == 1 &&
	(td[0]->conf && sizeof (td[0]->conf) &&
	 td[0]->module && sizeof (td[0]->module)))
      return res1 + td[0];
    res1->module_varies = "yes";

    string conf;
    foreach (td, mapping(string:string) ent)
      if (ent->conf) {
	if (!conf) conf = ent->conf;
	else if (conf != ent->conf) {
	  conf = 0;
	  break;
	}
      }
    if (conf) res1->conf = conf;
    else res1->conf_varies = "yes";

    return res1;
  }

  return res1;
}

string insert_statement( string db, string table, mapping row )
//! Convenience function.
{
  function q = cached_get( db )->quote;
  string res = "INSERT INTO "+table+" ";
  array(string) vi = ({});
  array(string) vv = ({});
  foreach( indices( row ), string r )
    if( !has_value( r, "." ) )
    {
      vi += ({r});
      vv += ({"'"+q(row[r])+"'"});
    }
  return res + "("+vi*","+") VALUES ("+vv*","+")";
}

void is_module_table( RoxenModule module, string db, string table,
		   string|void comment )
//! Tell the system that the table 'table' in the database 'db'
//! belongs to the module 'module'. The comment is optional, and will
//! be shown in the configuration interface if present.
{
  string mn = module ? module->sname(): "";
  string cn = module ? module->my_configuration()->name : "";
  catch(query("DELETE FROM module_tables WHERE "
	      "module=%s AND conf=%s AND tbl=%s AND db=%s",
	      mn,cn,table,db ));

  query("INSERT INTO module_tables (conf,module,db,tbl,comment) VALUES "
	"(%s,%s,%s,%s,%s)",
	cn,mn,db,table,comment||"" );
}

void is_module_db( RoxenModule module, string db, string|void comment )
//! Tell the system that the databse 'db' belongs to the module 'module'.
//! The comment is optional, and will be shown in the configuration
//! interface if present.
{
  is_module_table( module, db, "", comment );
}

protected void create()
{
  Sql.Sql db = connect_to_my_mysql(0, "mysql");
  // Typically a string like "mysql/5.5.30-log" or "mysql/5.5.39-MariaDB-log".
  normalized_server_version = map(((db->server_info()/"/")[1]/"-")[0]/".",
				  lambda(string d) {
				    return ("000" + d)[<2..];
				  }) * ".";

  mixed err = 
  catch {
    query("CREATE TABLE IF NOT EXISTS db_backups ("
	  " db varchar(80) not null, "
	  " tbl varchar(80) not null, "
	  " directory varchar(255) not null, "
	  " whn int unsigned not null, "
	  " tag varchar(20) null, "
	  " INDEX place (db,directory))");

    if (catch { query("SELECT tag FROM db_backups LIMIT 1"); }) {
      // The tag field is missing.
      // Upgraded Roxen?
      query("ALTER TABLE db_backups "
	    "  ADD tag varchar(20) null");
    }
       
  query("CREATE TABLE IF NOT EXISTS db_groups ("
	" db varchar(80) not null, "
	" groupn varchar(80) not null)");

  query("CREATE TABLE IF NOT EXISTS groups ( "
	"  name varchar(80) not null primary key, "
	"  lname varchar(80) not null, "
	"  comment blob not null, "
	"  pattern varchar(255) not null default '')");

  catch(query("INSERT INTO groups (name,lname,comment,pattern) VALUES "
      " ('internal','Uncategorized','Databases without any group','')"));

  query("CREATE TABLE IF NOT EXISTS module_tables ("
	"  conf varchar(80) not null, "
	"  module varchar(80) not null, "
	"  db   varchar(80) not null, "
	"  tbl varchar(80) not null, "
	"  comment blob not null, "
	"  INDEX place (db,tbl), "
	"  INDEX own (conf,module) "
	")");

  query("CREATE TABLE IF NOT EXISTS db_schedules ("
	"id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, "
	"schedule VARCHAR(255) NOT NULL, "
	"dir VARCHAR(255) NULL, "
	"period INT UNSIGNED NOT NULL DEFAULT 604800, "
	"offset INT UNSIGNED NOT NULL DEFAULT 266400, "
	"generations INT UNSIGNED NOT NULL DEFAULT 1, "
	"method VARCHAR(20) NOT NULL DEFAULT 'mysqldump')");

  if (!sizeof(query("SELECT schedule "
		    "  FROM db_schedules "
		    " WHERE id = 1"))) {
    // Add the Default schedule with a disabled backup for minimal intrusion.
    query("INSERT INTO db_schedules "
	  "       (id, schedule, period) "
	  "VALUES (1, 'Default', 0)");
  }
    
  multiset q = (multiset)query( "SHOW TABLES" )->Tables_in_roxen;
  if( !q->dbs )
  {
    query( #"
CREATE TABLE dbs (
 name VARCHAR(64) NOT NULL PRIMARY KEY,
 path VARCHAR(100) NOT NULL, 
 local INT UNSIGNED NOT NULL,
 default_charset VARCHAR(64),
 schedule_id INT DEFAULT 1,
 INDEX schedule_id (schedule_id)
)" );
  } else {
    if (catch { query("SELECT default_charset FROM dbs LIMIT 1"); }) {
      // The default_charset field is missing.
      // Upgraded Roxen?
      query("ALTER TABLE dbs "
	    "  ADD default_charset VARCHAR(64)");
    }
    if (catch { query("SELECT schedule_id FROM dbs LIMIT 1"); }) {
      // The schedule_id field is missing.
      // Upgraded Roxen?
      query("ALTER TABLE dbs "
	    "  ADD schedule_id INT DEFAULT 1, "
	    "  ADD INDEX schedule_id (schedule_id)");
      // Don't attempt to backup non-mysql databases.
      query("UPDATE dbs "
	    "   SET schedule_id = NULL "
	    " WHERE local = 0 "
	    "   AND path NOT LIKE 'mysql://%'");
    }
  }

  if (!get ("local")) {
    create_db( "local",  0, 1 );
    is_module_db( 0, "local",
		  "The local database contains data that "
		  "should not be shared between multiple-frontend servers" );
  }

  if (!get ("roxen")) {
    create_db( "roxen",  0, 1 );
    is_module_db( 0, "roxen",
		  "The roxen database contains data about the other databases "
		  "in the server." );
  }
  if (!get ("mysql")) {
    create_db( "mysql",  0, 1 );
    is_module_db( 0, "mysql",
		  "The mysql database contains data about access "
		  "rights for the internal MySQL database." );
  }

  if( !q->db_permissions )
  {
    query(#"
CREATE TABLE db_permissions (
 db VARCHAR(64) NOT NULL, 
 config VARCHAR(80) NOT NULL, 
 permission ENUM ('none','read','write') NOT NULL,
 INDEX db_conf (db,config))
" );
    // Must be done from a call_out -- the configurations do not
    // exist yet (this code is called before 'main' is called in
    // roxen)
    call_out(
      lambda(){
	foreach( roxenp()->configurations, object c )
	{
	  set_permission( "local", c, WRITE );
	}
      }, 0 );
  }

  check_upgrade_mysql();

  synch_mysql_perms();

  if( file_stat( "etc/docs.frm" ) )
  {
    if( !sizeof(query( "SELECT tbl FROM db_backups WHERE "
		       "db=%s AND directory=%s",
		       "docs", getcwd()+"/etc" ) ) )
      query("INSERT INTO db_backups (db,tbl,directory,whn) "
	    "VALUES ('docs','docs','"+getcwd()+"/etc','"+time()+"')");
  }

  // Start the backup timers when we have finished booting.
  call_out(start_backup_timers, 0);
  
  return;
  };

  werror( describe_backtrace( err ) );
}
