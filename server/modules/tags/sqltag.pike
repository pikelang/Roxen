/* 
 * $Id: sqltag.pike,v 1.39 1999/11/05 08:46:55 nilsson Exp $
 *
 * A module for Roxen Challenger, which gives the tags
 * <sqltable>, <sqlquery> and <sqloutput>.
 *
 * Henrik Grubbström 1997-01-12
 */

constant cvs_version="$Id: sqltag.pike,v 1.39 1999/11/05 08:46:55 nilsson Exp $";
constant thread_safe=1;
#include <module.h>
#define old_rxml_compat 1

// Compatibility with old versions of the sqltag module.
// #define SQL_TAG_COMPAT

inherit "module";
inherit "roxenlib";

import Sql;

object conf;


// Module interface functions

array register_module()
{
  return( ({ MODULE_PARSER|MODULE_PROVIDER,
	     "SQL module",
	     "This module gives the three tags &lt;SQLQUERY&gt;, "
	     "&lt;SQLOUTPUT&gt;, and &lt;SQLTABLE&gt;.<br>\n"
	     "Usage:<ul>\n"
	     "<table border=0>\n"
	     "<tr><td valign=top><b>&lt;sqloutput&gt;</b></td>"
	     "<td>Executes an SQL query, and "
	     "replaces #-quoted fieldnames with the results. # is "
	     "quoted as ##. The content between &lt;sqloutput&gt; and "
	     "&lt;/sqloutput&gt; is repeated once for every row in the "
	     "result.</td></tr>\n"
	     "<tr><td valign=top><b>&lt;sqlquery&gt;</b></td>\n"
	     "<td>Executes an SQL query, but "
	     "doesn't do anything with the result. This is useful if "
	     "you do queries like INSERT and CREATE.</td></tr>\n"
	     "<tr><td valign=top><b>&lt;sqltable&gt;</td>"
	     "<td>Executes an SQL query, and makes "
	     "an HTML table from the result.</td></tr>\n"
	     "</table></ul>\n"
	     "The following attributes are used by the above tags:<ul>\n"
	     "<table border=0>\n"
	     "<tr><td valign=top><b>query</b></td>"
	     "<td>The actual SQL query. (<b>REQUIRED</b>)</td></tr>\n"
	     "<tr><td valign=top><b>host<b></td>"
	     "<td>The hostname of the machine the SQL server runs on.<br>\n"
	     "This argument can also be used to specify which SQL server "
	     "to use by specifying an \"SQL URL\":<br><ul>\n"
	     "<pre>[<i>sqlserver</i>://][[<i>user</i>][:<i>password</i>]@]"
	     "[<i>host</i>[:<i>port</i>]]/<i>database</i></pre><br>\n"
	     "</ul>Valid values for \"sqlserver\" depend on which "
	     "SQL servers your pike has support for, but the following "
	     "might exist: msql, mysql, odbc, oracle, postgres.</td></tr>\n"
	     "<tr><td valign=top><b>database</b></td>"
	     "<td>The name of the database to use.</td></tr>\n"
	     "<tr><td valign=top><b>user</b></td>"
	     "<td>The name of the user to access the database with.</td></tr>\n"
	     "<tr><td valign=top><b>password</b></td>"
	     "<td>The password to access the database.</td></tr>\n"
	     "<tr><td valign=top><b>parse</b></td>"
	     "<td>If specified, the query will be parsed by the "
	     "RXML parser</td></tr>\n"
	     "<tr><td valign=top><b>quiet</b></td>"
	     "<td>If specified, SQL errors will be kept quiet.</td></tr>\n"
	     "</table></ul><p>\n"
	     "The &lt;sqltable&gt; tag has an additional attribute "
	     "<b>ascii</b>, which generates a tab separated table (usefull "
	     "with eg the &lt;diagram&gt; tag).<p>\n"
	     "\n"
	     "<b>NOTE</b>: Specifying passwords in the documents may prove "
	     "to be a security hole if the module is not loaded for some "
	     "reason.<br>\n"
	     "<b>SEE ALSO</b>: The &lt;FORMOUTPUT&gt; tag can be "
	     "useful to generate the queries.<br>\n",
	     0,
	     1 }) );
}

array|string|object do_sql_query(string tag, mapping args, RequestID id)
{
  if (!args->query)
    return rxml_error(tag, "No query.", id);

  if (args->parse)
    args->query = parse_rxml(args->query, id);

  string host = query("hostname");
  object(sql) con;
  array(mapping(string:mixed)) result;
  function sql_connect = id->conf->sql_connect;
  mixed error;

#ifdef SQL_TAG_COMPAT
  string database = query("database");
  string user = query("user");
  string password = query("password");

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

  if (sql_connect)
    error = catch(con = sql_connect(host));
  else {
    host = (lower_case(host) == "localhost")?"":host;
    error = catch(con = sql(host, database, user, password));
  }
#else
  if (args->host)
    host=args->host;

  if(sql_connect)
    error = catch(con = sql_connect(host));
  else
    error = catch(con = sql(lower_case(host)=="localhost"?"":host));
#endif

  if (error) {
    if (!args->quiet) {
      if (args->log_error && QUERY(log_error)) {
        report_error(sprintf("SQLTAG: Couldn't connect to SQL server:\n"
       		       "%s\n", describe_backtrace(error)));
      }
      return "<h3>Couldn't connect to SQL server</h3><br>\n" +
              html_encode_string(error[0]) + "<false>";
    }
    return rxml_error(tag, "Couldn't connect to SQL server. "+html_encode_string(error[0]), id);
  }

  if (error = catch(result = tag=="sqltable"?con->big_query(args->query):con->query(args->query))) {
    error = html_encode_string(sprintf("Query %O failed. %s", args->query, con->error()));
    if (!args->quiet) {
      if (args->log_error && QUERY(log_error)) {
        report_error(sprintf("SQLTAG: Query %O failed:\n"
	       "%s\n",
	       args->query, describe_backtrace(error)));
      }
      return "<h3>"+error+"</h3>\n<false>";
    }
    return rxml_error(tag, error, id);
  }

  if(tag=="sqlquery") args["dbobj"]=con;
  return result;
}


// -------------------------------- Tag handlers ------------------------------------

array|string container_sqloutput(string tag, mapping args, string contents,
		    RequestID id)
{
  if(args->help) return register_module()[2]; // FIXME
  NOCACHE();

  string|array res=do_sql_query(tag, args, id);
  if(stringp(res)) return res;

  if (res && sizeof(res)) {
    array ret = ({ do_output_tag(args, res, contents, id) });
    id->misc->defines[" _ok"] = 1; // The effect of <true>, since res isn't parsed.

    if( args["rowinfo"] )
           id->variables[args->rowinfo]=sizeof(res);

    return ret;
  }

  if (args["do-once"])
    return do_output_tag( args, ({([])}), contents, id )+ "<true>";

  return rxml_error(tag, "No SQL return values.", id);
}

string tag_sqlquery(string tag, mapping args, RequestID id)
{
  if(args->help) return register_module()[2]; // FIXME
  NOCACHE();

  string|array res=do_sql_query(tag, args, id);
  if(stringp(res)) return res;

  if(args["mysql-insert-id"])
    if(args->dbobj && args->dbobj->master_sql)
      id->variables[args["mysql-insert-id"]] = args->dbobj->master_sql->insert_id();
    else
      return rxml_error(tag, "No insert_id present.", id);

  return "<true>";
}

string tag_sqltable(string tag, mapping args, RequestID id)
{
  if(args->help) return register_module()[2]; // FIXME
  NOCACHE();

  string|object res=do_sql_query(tag, args, id);
  if(stringp(res)) return res;

  int ascii=!!args->ascii;
  string ret="";

  if (res) {
    string nullvalue=args->nullvalue||"";
    array(mixed) row;

    if (!ascii) {
      ret="<tr>";
      foreach(map(res->fetch_fields(), lambda (mapping m) {
					      return m->name;
					    } ), string name)
        ret += "<th>"+name+"</th>";
      ret += "</tr>\n";
    }

    if( args["rowinfo"] )
        id->variables[args->rowinfo]=res->num_rows();

    while(arrayp(row=res->fetch_row())) {
      if (ascii)
        ret += row * "\t" + "\n";
      else {
        ret += "<tr>";
        foreach(row, mixed value)
          ret += "<td>"+(value==""?nullvalue:value)+"</td>";
        ret += "</tr>\n";
      }
    }

    if (!ascii)
      ret=make_container("table", args-(["host":"", "database":"", "user":"", "password":"",
					 "query":"", "nullvalue":""]), ret);

    return ret+"<true>";
  }

  return rxml_error(tag, "No SQL return values.", id);
}


// ------------------- Callback functions -------------------------

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


// ------------------------ Setting the defaults -------------------------

void create()
{
  defvar("hostname", "localhost", "Default SQL database host",
	 TYPE_STRING, "Specifies the default host to use for SQL queries.\n"
	 "This argument can also be used to specify which SQL server to "
	 "use by specifying an \"SQL URL\":<ul>\n"
	 "<pre>[<i>sqlserver</i>://][[<i>user</i>][:<i>password</i>]@]"
	 "[<i>host</i>[:<i>port</i>]]/<i>database</i></pre></ul><br>\n"
	 "Valid values for \"sqlserver\" depend on which "
	 "SQL servers your pike has support for, but the following "
	 "might exist: msql, mysql, odbc, oracle, postgres.\n");

  defvar("log_error", 0, "Enable the log_error attribute",
	 TYPE_FLAG|VAR_MORE, "Enables the attribute \"log_error\" "
	 "which causes errors to be logged to the event log.\n");

#ifdef SQL_TAG_COMPAT
  defvar("database", "", "Default SQL database (deprecated)",
	 TYPE_STRING|VAR_MORE,
	 "Specifies the name of the default SQL database.\n");
  defvar("user", "", "Default username (deprecated)",
	 TYPE_STRING|VAR_MORE,
	 "Specifies the default username to use for access.\n");
  defvar("password", "", "Default password (deprecated)",
	 TYPE_STRING|VAR_MORE,
	 "Specifies the default password to use for access.\n");
#endif // SQL_TAG_COMPAT
}


// --------------------- More interface functions --------------------------

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
    if (conf->sql_connect)
      o = conf->sql_connect(QUERY(hostname));
    else
      o = Sql.sql(QUERY(hostname)
#ifdef SQL_TAG_COMPAT
		  , QUERY(database), QUERY(user), QUERY(password)
#endif // SQL_TAG_COMPAT
		  );
    return(sprintf("Connected to %s server on %s<br>\n",
		   o->server_info(), o->host_info()));
  })
  return "<font color=red>Not connected.</font><br>\n";
}

