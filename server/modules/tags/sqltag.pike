// This is a roxen module. Copyright © 1997-2000, Roxen IS.
//
// A module for Roxen, which gives the tags
// <sqltable>, <sqlquery> and <sqloutput>.
//
// Henrik Grubbström 1997-01-12

constant cvs_version="$Id: sqltag.pike,v 1.49 2000/03/09 09:05:18 mast Exp $";
constant thread_safe=1;
#include <module.h>

// Compatibility with old versions of the sqltag module.
// #define SQL_TAG_COMPAT

inherit "module";
inherit "roxenlib";

Configuration conf;


// Module interface functions

constant module_type=MODULE_PARSER|MODULE_PROVIDER;
constant module_name="SQL tag module";
constant module_doc ="This module gives the three tags &lt;SQLQUERY&gt;, "
  "&lt;SQLOUTPUT&gt;, and &lt;SQLTABLE&gt;.<br>\n";

TAGDOCUMENTATION
#ifdef manual
constant tagdoc=([
"sqltable":#"
<desc tag><short>
 Creates an HTML or ASCII table from the results of an SQL query.
</short>
</desc>

<attr name=ascii>
 Create an ASCII table rather than a HTML table. Useful for
 interacting with the <ref type=tag>diagram</ref> and <ref
 type=tag>tablify</ref> tags.
</attr>

<attr name=host type=database>
 Which database to connect to, usually a symbolic name set in the
 <module>SQL Databases</module> module. If omitted the default
 database will be used.
</attr>

<attr name=SQL statement>
 The actual SQL-statement.
</attr>

<attribute name=parse>
 If specified, the query will be parsed by the RXML parser.
 Useful if you wish to dynamically build the query.
</attribute>",

"sqlquery":#"
<desc tag><short>
 Executes an SQL query, but doesn't do anything with the
 result.</short> This is mostly used for SQL queries that change the
 contents of the database, for example INSERT or UPDATE.
</desc>

<attr name=host type=database>
 Which database to connect to, usually a symbolic name set in the
 <module>SQL Databases</module> module. If omitted the default
 database will be used.
</attr>

<attr name=query type=SQL statement>
 The actual SQL-statement.
</attr>

<attr name=parse>
 If specified, the query will be parsed by the RXML parser. Useful if
 you wish to dynamically build the query.
</attr>

<attr name=mysql-insert-id type=form-variable>
 Set form-variable to the insert id used by Mysql for
 auto-incrementing columns. Note: This is only available with Mysql.
</attr>
"]);
#endif

array|object do_sql_query(string tag, mapping args, RequestID id)
{
  if (!args->query)
    RXML.parse_error("No query.");

  if (args->parse)
    args->query = parse_rxml(args->query, id);

  string host = query("hostname");
  Sql.sql con;
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
    error = catch(con = Sql.sql(host, database, user, password));
  }
#else
  if (args->host)
    host=args->host;

  if(sql_connect)
    error = catch(con = sql_connect(host));
  else
    error = catch(con = Sql.sql(lower_case(host)=="localhost"?"":host));
#endif

  if (error)
    RXML.run_error("Couldn't connect to SQL server. "+html_encode_string(error[0]));

  if (error = catch(result = tag=="sqltable"?con->big_query(args->query):con->query(args->query))) {
    error = html_encode_string(sprintf("Query %O failed. %s", args->query,
				       con->error()||""));
    RXML.run_error(error);
  }

  if(tag=="sqlquery") args["dbobj"]=con;
  return result;
}


// -------------------------------- Tag handlers ------------------------------------

array|string container_sqloutput(string tag, mapping args, string contents,
		    RequestID id)
{
  NOCACHE();

  array res=do_sql_query(tag, args, id);

  if (res && sizeof(res)) {
    array ret = ({ do_output_tag(args, res, contents, id) });
    id->misc->defines[" _ok"] = 1; // The effect of <true>, since res isn't parsed.

    if( args["rowinfo"] )
           id->variables[args->rowinfo]=sizeof(res);

    return ret;
  }

  if (args["do-once"])
    return do_output_tag( args, ({([])}), contents, id )+ "<true>";

  RXML.run_error("No SQL return values.");
}

class TagSqlplugin {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "sql";

  array get_dataset(mapping m, RequestID id) {
    array|string res=do_sql_query("sqloutput", m, id);
    if(m->rowinfo) id->variables[m->rowinfo] = sizeof(res);
    return res;
  }
}

string tag_sqlquery(string tag, mapping args, RequestID id)
{
  NOCACHE();

  array res=do_sql_query(tag, args, id);

  if(args["mysql-insert-id"])
    if(args->dbobj && args->dbobj->master_sql)
      id->variables[args["mysql-insert-id"]] = args->dbobj->master_sql->insert_id();
    else
      RXML.parse_error("No insert_id present.");

  return "<true />";
}

string tag_sqltable(string tag, mapping args, RequestID id)
{
  NOCACHE();

  object res=do_sql_query(tag, args, id);

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

  RXML.run_error("No SQL return values.");
}


// ------------------- Callback functions -------------------------

Sql.sql sql_object(void|string host)
{
  string host = stringp(host)?host:query("hostname");
  Sql.sql con;
  function sql_connect = conf->sql_connect;
  mixed error;
  /* Is this really a good idea? /mast
  error = catch(con = sql_connect(host));
  if(error)
    return 0;
  return con;
  */
  return sql_connect(host);
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

#ifdef SQL_TAG_COMPAT
  defvar("database", "", "Default SQL database (deprecated)",
	 TYPE_STRING,
	 "Specifies the name of the default SQL database.\n");
  defvar("user", "", "Default username (deprecated)",
	 TYPE_STRING,
	 "Specifies the default username to use for access.\n");
  defvar("password", "", "Default password (deprecated)",
	 TYPE_STRING,
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
  if (mixed err = catch {
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
    return
      "<font color=red>Not connected:</font> " +
      replace (html_encode_string (describe_error(err)), "\n", "<br>\n") +
      "<br>\n";
}

