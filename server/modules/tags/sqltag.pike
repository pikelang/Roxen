/* 
 * $Id: sqltag.pike,v 1.31 1998/09/30 23:11:29 js Exp $
 *
 * A module for Roxen Challenger, which gives the tags
 * <SQLQUERY> and <SQLOUTPUT>.
 *
 * Henrik Grubbström 1997-01-12
 */

constant cvs_version="$Id: sqltag.pike,v 1.31 1998/09/30 23:11:29 js Exp $";
constant thread_safe=1;
#include <module.h>

/* Compatibility with old versions of the sqltag module. */
// #define SQL_TAG_COMPAT

inherit "module";
inherit "roxenlib";

import Array;
import Sql;

object conf;


/*
 * Module interface functions
 */

array register_module()
{
  return( ({ MODULE_PARSER|MODULE_PROVIDER,
	     "SQL-module",
	     "This module gives the three tags &lt;SQLQUERY&gt;, "
	     "&lt;SQLOUTPUT&gt;, and &lt;SQLTABLE&gt;.<br>\n"
	     "Usage:<ul>\n"
	     "<table border=0>\n"
	     "<tr><td valign=top><b>&lt;sqloutput&gt;</b></td>"
	     "<td>Executes an SQL-query, and "
	     "replaces #-quoted fieldnames with the results. # is "
	     "quoted as ##. The content inbetween &lt;sqloutput&gt; and "
	     "&lt;/sqloutput&gt; is repeated once for every row in the "
	     "result.</td></tr>\n"
	     "<tr><td valign=top><b>&lt;sqlquery&gt;</b></td>\n"
	     "<td>Executes an SQL-query, but "
	     "doesn't do anything with the result. This is useful if "
	     "you do queries like INSERT and CREATE.</td></tr>\n"
	     "<tr><td valign=top><b>&lt;sqltable&gt;</td>"
	     "<td>Executes an SQL-query, and makes "
	     "an HTML-table from the result.</td></tr>\n"
	     "</table></ul>\n"
	     "The following attributes are used by the above tags:<ul>\n"
	     "<table border=0>\n"
	     "<tr><td valign=top><b>query</b></td>"
	     "<td>The actual SQL-query. (<b>REQUIERED</b>)</td></tr>\n"
	     "<tr><td valign=top><b>host<b></td>"
	     "<td>The hostname of the machine the SQL-server runs on.<br>\n"
	     "This argument can also be used to specify which SQL-server "
	     "to use by specifying an \"SQL-URL\":<br><ul>\n"
	     "<pre>[<i>sqlserver</i>://][[<i>user</i>][:<i>password</i>]@]"
	     "[<i>host</i>[:<i>port</i>]]/<i>database</i></pre><br>\n"
	     "</ul>Valid values for \"sqlserver\" depend on which "
	     "sql-servers your pike has support for, but the following "
	     "might exist: msql, mysql, odbc, oracle, postgres.</td></tr>\n"
	     "<tr><td valign=top><b>database</b></td>"
	     "<td>The name of the database to use.</td></tr>\n"
	     "<tr><td valign=top><b>user</b></td>"
	     "<td>The name of the user to access the database with.</td></tr>\n"
	     "<tr><td valign=top><b>password</b></td>"
	     "<td>The password to access the database.</td></tr>\n"
	     "<tr><td valign=top><b>parse</b></td>"
	     "<td>If specified, the query will be parsed by the "
	     "RXML-parser</td></tr>\n"
	     "<tr><td valign=top><b>quiet</b></td>"
	     "<td>If specified, SQL-errors will be kept quiet.</td></tr>\n"
	     "</table></ul><p>\n"
	     "The &lt;sqltable&gt; tag has an additional attribute "
	     "<b>ascii</b>, which generates a tab-separated table (usefull "
	     "with eg the &lt;diagram&gt; tag).<p>\n"
	     "\n"
	     "<b>NOTE</b>: Specifying passwords in the documents may prove "
	     "to be a security hole if the module is not loaded for some "
	     "reason.<br>\n"
	     "<b>SEE ALSO</b>: The &lt;FORMOUTPUT&gt; tag can be "
	     "usefull to generate the queries.<br>\n",
	     0,
	     1 }) );
}

/*
 * Tag handlers
 */

string sqloutput_tag(string tag_name, mapping args, string contents,
		     object request_id, object f,
		     mapping defines, object fd)
{
  if(args->help) return register_module()[2]; // FIXME

  request_id->misc->cacheable=0;

  if (args->query) {

    if (args->parse) {
      args->query = parse_rxml(args->query, request_id, f, defines);
    }

    string host = query("hostname");
#ifdef SQL_TAG_COMPAT
    string database = query("database");
    string user = query("user");
    string password = query("password");
#else /* SQL_TAG_COMPAT */
    string database, user, password;
#endif /* SQL_TAG_COMPAT */
    object(sql) con;
    array(mapping(string:mixed)) result;
    function sql_connect = request_id->conf->sql_connect;
    mixed error;

    if (args->host) {
      host = args->host;
      user = "";
      password = "";
    }
    if (args->database) {
      database = args->database;
      user = "";
      password = "";
      sql_connect = 0;
    }
    if (args->user) {
      user = args->user;
      sql_connect = 0;
    }
    if (args->password) {
      password = args->password;
      sql_connect = 0;
    }
    if (sql_connect) {
      error = catch(con = sql_connect(host));
    } else {
      host = (lower_case(host) == "localhost")?"":host;
      error = catch(con = sql(host, database, user, password));
    }
    if (error) {
      if (!args->quiet) {
	if (args->log_error && QUERY(log_error)) {
	  report_error(sprintf("SQLTAG: Couldn't connect to SQL-server:\n"
			       "%s\n", describe_backtrace(error)));
	}
	contents = ("<h3>Couldn't connect to SQL-server</h1><br>\n" +
		    html_encode_string(error[0]) + "<false>");
      } else {
	contents = "<false>";
      }
    } else if (error = catch(result = con->query(args->query))) {
      if (!args->quiet) {
	if (args->log_error && QUERY(log_error)) {
	  report_error(sprintf("SQLTAG: Query %O failed:\n"
			       "%s\n",
			       args->query, describe_backtrace(error)));
	}
	contents = ("<h3>Query \"" + html_encode_string(args->query)
		    + "\" failed: " + html_encode_string(con->error()) 
		    + "</h1>\n<false>");
      } else {
	contents = "<false>";
      }
    } else if (result && sizeof(result))
    {
      contents = do_output_tag( args, result, contents, request_id )
	+ "<true>";
    } else {
      contents = "<false>";
    }
  } else {
    contents = "<!-- No query! --><false>";
  }
  return(contents);
}

string sqlquery_tag(string tag_name, mapping args,
		    object request_id, object f,
		    mapping defines, object fd)
{
  if(args->help) return register_module()[2]; // FIXME

  request_id->misc->cacheable=0;

  if (args->query) {

    if (args->parse) {
      args->query = parse_rxml(args->query, request_id, f, defines);
    }

    string host = query("hostname");
#ifdef SQL_TAG_COMPAT
    string database = query("database");
    string user = query("user");
    string password = query("password");
#else /* SQL_TAG_COMPAT */
    string database, user, password;
#endif /* SQL_TAG_COMPAT */
    object(sql) con;
    mixed error;
    function sql_connect = request_id->conf->sql_connect;
    array(mapping(string:mixed)) res;

    if (args->host) {
      host = args->host;
      user = "";
      password = "";
    }
    if (args->database) {
      database = args->database;
      user = "";
      password = "";
      sql_connect = 0;
    }
    if (args->user) {
      user = args->user;
      sql_connect = 0;
    }
    if (args->password) {
      password = args->password;
      sql_connect = 0;
    }
    if (sql_connect) {
      error = catch(con = sql_connect(host));
    } else {
      host = (lower_case(host) == "localhost")?"":host;
      error = catch(con = sql(host, database, user, password));
    }
    if (error) {
      if (!args->quiet) {
	if (args->log_error && QUERY(log_error)) {
	  report_error(sprintf("SQLTAG: Couldn't connect to SQL-server:\n"
			       "%s\n", describe_backtrace(error)));
	}
	return("<h3>Couldn't connect to SQL-server</h1><br>\n" +
	       html_encode_string(error[0])+"<false>");
      } else {
	return("<false>");
      }
    } else if (error = catch(res = con->query(args->query))) {
      if (!args->quiet) {
	if (args->log_error && QUERY(log_error)) {
	  report_error(sprintf("SQLTAG: Query %O failed:\n"
			       "%s\n",
			       args->query, describe_backtrace(error)));
	}
	return("<h3>Query \"" + html_encode_string(args->query)+"\" failed: "
	       + html_encode_string(con->error()) + "</h1>\n<false>");
      } else {
	return("<false>");
      }
    }
    if(args["mysql-insert-id"])
      if(con->master_sql)
	request_id->variables[args["mysql-insert-id"]] =
	  con->master_sql->insert_id();
      else
	return "<!-- No insert_id present. --><false>";
    return(res?"<true>":"<false>");
  } else {
    return("<!-- No query! --><false>");
  }
}

string sqltable_tag(string tag_name, mapping args,
		    object request_id, object f,
		    mapping defines, object fd)
{
  int ascii;

  if(args->help) return register_module()[2]; // FIXME

  request_id->misc->cacheable=0;


  if (args->ascii) {
    // ASCII-mode
    ascii = 1;
  }

  if (args->query) {

    if (args->parse) {
      args->query = parse_rxml(args->query, request_id, f, defines);
    }

    string host = query("hostname");
#ifdef SQL_TAG_COMPAT
    string database = query("database");
    string user = query("user");
    string password = query("password");
#else /* SQL_TAG_COMPAT */
    string database, user, password;
#endif /* SQL_TAG_COMPAT */
    object(sql) con;
    mixed error;
    function sql_connect = request_id->conf->sql_connect;
    object(sql_result) result;
    string res;

    if (args->host) {
      host = args->host;
      user = "";
      password = "";
    }
    if (args->database) {
      database = args->database;
      user = "";
      password = "";
      sql_connect = 0;
    }
    if (args->user) {
      user = args->user;
      sql_connect = 0;
    }
    if (args->password) {
      password = args->password;
      sql_connect = 0;
    }
    if (sql_connect) {
      error = catch(con = sql_connect(host));
    } else {
      host = (lower_case(host) == "localhost")?"":host;
      error = catch(con = sql(host, database, user, password));
    }
    if (error) {
      if (!args->quiet) {
	if (args->log_error && QUERY(log_error)) {
	  report_error(sprintf("SQLTAG: Couldn't connect to SQL-server:\n"
			       "%s\n", describe_backtrace(error)));
	}
	return("<h3>Couldn't connect to SQL-server</h1><br>\n" +
	       html_encode_string(error[0])+"<false>");
      } else {
	return("<false>");
      }
    } else if (error = catch(result = con->big_query(args->query))) {
      if (!args->quiet) {
	if (args->log_error && QUERY(log_error)) {
	  report_error(sprintf("SQLTAG: Query %O failed:\n"
			       "%s\n",
			       args->query, describe_backtrace(error)));
	}
	return ("<h3>Query \"" + html_encode_string(args->query) +
	        "\" failed: " + html_encode_string(con->error()) + "</h1>\n" +
	        "<false>");
      } else {
	return("<false>");
      }
    }

    if (result) {
      string nullvalue="";
      array(mixed) row;

      if (args->nullvalue) {
	nullvalue=(string)args->nullvalue;
      }

      if (ascii) {
	res = "";
      } else {
	res = "<table";
	foreach(indices(args) - ({ "host", "database", "user", "password",
				 "query", "nullvalue" }),
		string attr) {
	  string val = args[attr];
	  if (val != attr) {
	    res += " "+attr+"=\""+val+"\"";
	  } else {
	    res += " "+attr;
	  }
	}
	res += "><tr>";
	foreach(map(result->fetch_fields(), lambda (mapping m) {
					      return(m->name);
					    } ), string name) {
	  res += "<th>"+name+"</th>";
	}
	res += "</tr>\n";
      }

      while (row = result->fetch_row()) {
	if (ascii) {
	  res += (Array.map(row, lambda(mixed value) {
				   return((string)value);
				 }) * "\t") + "\n";
	} else {
	  res += "<tr>";
	  foreach(row, mixed value) {
	    value = (string)value;
	    res += "<td>"+(value==""?nullvalue:value)+"</td>";
	  }
	  res += "</tr>\n";
	}
      }
      if (ascii) {
	res += "<true>";
      } else {
	res += "</table><true>";
      }

      return(res);
    } else {
      if (ascii) {
	return("<false>");
      }
      return("<!-- No result from query --><false>");
    }
  } else {
    if (ascii) {
      return("<false>");
    }
    return("<!-- No query! --><false>");
  }
}

string sqlelse_tag(string tag_name, mapping args, string contents,
		   object request_id, mapping defines)
{
  return(make_container("else", args, contents));
}

#if 0

string dumpid_tag(string tag_name, mapping args,
		  object request_id, mapping defines)
{
  return(sprintf("<pre>ID:%O\n</pre>\n",
		 mkmapping(indices(request_id), values(request_id))));
}

#endif /* 0 */


/*
 * Hook in the tags
 */

mapping query_tag_callers()
{
  return( ([ "sql":sqlquery_tag, "sqlquery":sqlquery_tag,
	     "sqltable":sqltable_tag,
#if 0
	     "dumpid":dumpid_tag
#endif /* 0 */
  ]) );
}

mapping query_container_callers()
{
  return( ([ "sqloutput":sqloutput_tag, "sqlelse":sqlelse_tag ]) );
}

/*
 *  Callback functions
 */


object(sql) sql_object(void|string host)
{
  string host = stringp(host)?host:query("hostname");
  object(sql) con;
  function sql_connect = conf->sql_connect;
  mixed error;
  error = catch(con = sql_connect(host));
  if(error)
    return 0;
  return con;
}

string query_provides()
{
  return "sql";
}

/*
 * Setting the defaults
 */

void create()
{
  defvar("hostname", "localhost", "Default SQL-database host", 
	 TYPE_STRING, "Specifies the default host to use for SQL-queries.\n"
	 "This argument can also be used to specify which SQL-server to "
	 "use by specifying an \"SQL-URL\":<ul>\n"
	 "<pre>[<i>sqlserver</i>://][[<i>user</i>][:<i>password</i>]@]"
	 "[<i>host</i>[:<i>port</i>]]/<i>database</i></pre></ul><br>\n"
	 "Valid values for \"sqlserver\" depend on which "
	 "sql-servers your pike has support for, but the following "
	 "might exist: msql, mysql, odbc, oracle, postgres.\n");

  defvar("log_error", 0, "Enable the log_error attribute",
	 TYPE_FLAG|VAR_MORE, "Enables the attribute \"log_error\" "
	 "which causes errors to be logged to the event-log.\n");

#ifdef SQL_TAG_COMPAT
  defvar("database", "", "Default SQL-database (deprecated)",
	 TYPE_STRING|VAR_MORE,
	 "Specifies the name of the default SQL-database.\n");
  defvar("user", "", "Default username (deprecated)",
	 TYPE_STRING|VAR_MORE,
	 "Specifies the default username to use for access.\n");
  defvar("password", "", "Default password (deprecated)",
	 TYPE_STRING|VAR_MORE,
	 "Specifies the default password to use for access.\n");
#endif /* SQL_TAG_COMPAT */
}

/*
 * More interface functions
 */


void start(int level, object _conf)
{
  if (_conf) {
    conf = _conf;
  }
//add_api_function("sql_query", api_sql_query, ({ "string", 0,"int" }));
}

void stop()
{
}

string status()
{
  if (catch {
    object o;
    if (conf->sql_connect) {
      o = conf->sql_connect(QUERY(hostname));
    } else {
      o = Sql.sql(QUERY(hostname)
#ifdef SQL_TAG_COMPAT
		  , QUERY(database), QUERY(user), QUERY(password)
#endif /* SQL_TAG_COMPAT */
		  );
    }
    return(sprintf("Connected to %s-server on %s<br>\n",
		   o->server_info(), o->host_info()));
  }) {
    return("<font color=red>Not connected.</font><br>\n");
  }
}

