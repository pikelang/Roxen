// This is a roxen module. Copyright © 1997-2000, Roxen IS.
//
// A module for Roxen, which gives the tags
// <sqltable>, <sqlquery> and <sqloutput>.
//
// Henrik Grubbström 1997-01-12

constant cvs_version="$Id: sqltag.pike,v 1.56 2000/04/04 18:03:44 jhs Exp $";
constant thread_safe=1;
#include <module.h>
#include <config.h>

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

<attr name=host value=database>
 Which database to connect to, usually a symbolic name set in the
 <module>SQL Databases</module> module. If omitted the default
 database will be used.
</attr>

<attr name=query value='SQL statement'>
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

<attr name=host value=database>
 Which database to connect to, usually a symbolic name set in the
 <module>SQL Databases</module> module. If omitted the default
 database will be used.
</attr>

<attr name=query value='SQL statement'>
 The actual SQL-statement.
</attr>

<attr name=parse>
 If specified, the query will be parsed by the RXML parser. Useful if
 you wish to dynamically build the query.
</attr>

<attr name=mysql-insert-id value=form-variable>
 Set form-variable to the insert id used by Mysql for
 auto-incrementing columns. Note: This is only available with Mysql.
</attr>",

"emit#sql":#"<desc plugin>Use this source to connect to and
 query SQL databases for information. The result will be available in
 variables named as the SQL columns.</desc>

<attr name=host value=database>
 Which database to connect to, usually a symbolic name set in the
 <module>SQL Databases</module> module. If omitted the default
 database will be used.
</attr>

<attr name=query value='SQL statement'>
 The actual SQL-statement.
</attr>
"
]);
#endif

array|object do_sql_query(string tag, mapping args, RequestID id)
{
  string host = query("hostname");
  if (args->host) {
    host=args->host;
    args->host="CENSORED";
  }

  if (!args->query)
    RXML.parse_error("No query.");

  if (args->parse)
    args->query = parse_rxml(args->query, id);

  Sql.sql con;
  array(mapping(string:mixed))|object result;
  function sql_connect = id->conf->sql_connect;
  mixed error;

  if(sql_connect)
    error = catch(con = sql_connect(host));
  else
    error = catch(con = Sql.sql(lower_case(host)=="localhost"?"":host));

  if (error)
    RXML.run_error("Couldn't connect to SQL server. "+html_encode_string(error[0]));

  if (error = catch(result = (tag=="sqltable"?con->big_query(args->query):con->query(args->query)))) {
    error = html_encode_string(sprintf("Query %O failed. %s", args->query,
				       con->error()||""));
    RXML.run_error(error);
  }

  if(tag=="sqlquery") args["dbobj"]=con;
  if(result && args->rowinfo) {
    int rows;
    if(arrayp(result)) rows=sizeof(result);
    if(objectp(result)) rows=result->num_rows();
    RXML.user_set_var(args->rowinfo, rows);
  }

  return result;
}


// -------------------------------- Tag handlers ------------------------------------

#ifdef OLD_RXML_COMPAT
string simpletag_sqloutput(string tag, mapping args, string contents,
			   RequestID id)
{
  NOCACHE();

  array res=do_sql_query(tag, args, id);

  if (res && sizeof(res)) {
    string ret = do_output_tag(args, res, contents, id);
    id->misc->defines[" _ok"] = 1; // The effect of <true>, since res isn't parsed.

    return ret;
  }

  if (args["do-once"])
    return do_output_tag( args, ({([])}), contents, id )+ "<true>";

  id->misc->defines[" _ok"] = 0;
}
#endif

class TagSqlplugin {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "sql";

  array get_dataset(mapping m, RequestID id) {
    array|string res=do_sql_query("sqloutput", m, id);
    return res;
  }
}

string tag_sqlquery(string tag, mapping args, RequestID id)
{
  NOCACHE();

  array res=do_sql_query(tag, args, id);

  if(args["mysql-insert-id"])
    if(args->dbobj && args->dbobj->master_sql)
      RXML.user_set_var(args["mysql-insert-id"], args->dbobj->master_sql->insert_id());
    else
      RXML.parse_error("No insert_id present.");

  id->misc->defines[" _ok"] = 1;
  return "";
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

    id->misc->defines[" _ok"] = 1;
    return ret;
  }

  id->misc->defines[" _ok"] = 0;
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
	 TYPE_STRING | VAR_INITIAL,
	 "Specifies the default host to use for SQL queries.\n"
	 "This argument can also be used to specify which SQL server to "
	 "use by specifying an \"SQL URL\":<ul>\n"
	 "<pre>[<i>sqlserver</i>://][[<i>user</i>][:<i>password</i>]@]"
	 "[<i>host</i>[:<i>port</i>]]/<i>database</i></pre></ul><br>\n"
	 "Valid values for \"sqlserver\" depend on which "
	 "SQL servers your pike has support for, but the following "
	 "might exist: msql, mysql, odbc, oracle, postgres.\n");
}


// --------------------- More interface functions --------------------------

void start(int level, Configuration _conf)
{
  if (_conf)
    conf = _conf;
}

string status()
{
  if (mixed err = catch {
    object o;
    if (conf->sql_connect)
      o = conf->sql_connect(QUERY(hostname));
    else
      o = Sql.sql(QUERY(hostname));

    return(sprintf("Connected to %s server on %s<br />\n",
		   o->server_info(), o->host_info()));
  })
    return
      "<font color=\"red\">Not connected:</font> " +
      replace (html_encode_string (describe_error(err)), "\n", "<br />\n") +
      "<br />\n";
}
