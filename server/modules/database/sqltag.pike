// This is a roxen module. Copyright © 1997-2000, Roxen IS.
//
// A module for Roxen, which gives the tags
// <sqltable>, <sqlquery> and <sqloutput>.
//
// Henrik Grubbström 1997-01-12

constant cvs_version="$Id: sqltag.pike,v 1.68 2002/02/15 18:18:03 mast Exp $";
constant thread_safe=1;
#include <module.h>
#include <config.h>

inherit "module";

Configuration conf;


// Module interface functions

constant module_type=MODULE_TAG|MODULE_PROVIDER;
constant module_name="SQL tags";
constant module_doc =
#"The SQL tags module provides the tags <tt>&lt;sqlquery&gt;</tt> and
<tt>&lt;sqltable&gt;</tt> as well as being a source to the 
<tt>&lt;emit&gt;</tt> tag (<tt>&lt;emit source=\"sql\" ... &gt;</tt>).
All tags send queries to SQL databases.";

TAGDOCUMENTATION
#ifdef manual
constant tagdoc=([
"sqltable":#"
<desc tag='tag'><p><short>
 Creates an HTML or ASCII table from the results of an SQL query.
</short></p>
</desc>

<attr name='ascii'><p>
 Create an ASCII table rather than a HTML table. Useful for
 interacting with <xref href='../graphics/diagram.tag' /> and <xref
 href='../text/tablify.tag' />.</p>
</attr>

<attr name='host' value='database'><p>
 Which database to connect to, usually a symbolic name set in the <xref
 href='../../administrator/installing/databases.xml'><module>SQL
 Databases</module></xref> module. If omitted the default database will
 be used.</p>
</attr>

<attr name='query' value='SQL statement'><p>
 The actual SQL-statement.</p>
</attr>

<attr name='parse'><p>
 If specified, the query will be parsed by the RXML parser.
 Useful if you wish to dynamically build the query.</p>
</attr>",

"sqlquery":#"
<desc tag='tag'><p><short>
 Executes an SQL query, but doesn't do anything with the
 result.</short> This is mostly used for SQL queries that change the
 contents of the database, for example INSERT or UPDATE.</p>
</desc>

<attr name='host' value='database'><p>
 Which database to connect to, usually a symbolic name set in the <xref
 href='../../administrator/installing/databases.xml'><module>SQL
 Databases</module></xref> module. If omitted the default
 database will be used.</p>
</attr>

<attr name='query' value='SQL statement'><p>
 The actual SQL-statement.</p>
</attr>

<attr name='parse'><p>
 If specified, the query will be parsed by the RXML parser. Useful if
 you wish to dynamically build the query.</p>
</attr>

<attr name='mysql-insert-id' value='form-variable'><p>
 Set form-variable to the insert id used by Mysql for
 auto-incrementing columns. Note: This is only available with Mysql.</p>
</attr>",

"emit#sql":#"<desc plugin='plugin'><p><short>

 Use this source to connect to and query SQL databases for
 information.</short> The result will be available in variables named
 as the SQL columns.</p>
</desc>

<attr name='host' value='database'><p>
 Which database to connect to, usually a symbolic name set in the <xref
 href='../../administrator/installing/databases.xml'><module>SQL
 Databases</module></xref> module. If omitted the default
 database will be used.</p>
</attr>

<attr name='query' value='SQL statement'><p>
 The actual SQL-statement.</p>
</attr>
"
]);
#endif

array|object do_sql_query(mapping args, RequestID id, void|int big_query)
{
  string host = query("hostname");
  if (args->host) {
    host=args->host;
    args->host="CENSORED";
  }

  if (!args->query)
    RXML.parse_error("No query.\n");

  if (args->parse)
    args->query = Roxen.parse_rxml(args->query, id);

  Sql.sql con;
  array(mapping(string:mixed))|object result;
  function sql_connect = id->conf->sql_connect;
  mixed error;

  if(sql_connect)
    error = catch(con = sql_connect(host));
  else
    error = catch(con = Sql.sql(lower_case(host)=="localhost"?"":host));

  if (error)
    RXML.run_error("Couldn't connect to SQL server: "+error[0]+"\n");

  // Got a connection now. Any errors below this point ought to be
  // syntax errors and should be reported with parse_error.

  if (error = catch(result = (big_query?con->big_query(args->query):con->query(args->query)))) {
    error = con->error();
    if (error) error = ": " + error;
    error = sprintf("Query failed%s\n", error||".");
    RXML.parse_error(error);
  }

  args["dbobj"]=con;
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
class TagSQLOutput {
  inherit RXML.Tag;
  constant name = "sqloutput";
  RXML.Type content_type = RXML.t_same;
  array(RXML.Type) result_types = ({ RXML.t_any(RXML.PXml) });

  class Frame {
    inherit RXML.Frame;
    inherit "roxenlib";

    array do_return(RequestID id) {
      NOCACHE();

      array res=do_sql_query(args, id);

      if (res && sizeof(res)) {
	result = do_output_tag(args, res, content, id);
	id->misc->defines[" _ok"] = 1; // The effect of <true>, since res isn't parsed.

	return 0;
      }

      if (args["do-once"]) {
	result = do_output_tag( args, ({([])}), content, id );
	id->misc->defines[" _ok"] = 1;
	return 0;
      }

      id->misc->defines[" _ok"] = 0;
      return 0;
    }
  }
}
#endif

#ifdef SQL_EMIT_FOR_DATABASES_WITHOUT_NULL_ENTRIES
class TagSqlplugin {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "sql";

  array get_dataset(mapping m, RequestID id) {
    return do_sql_query(m, id);
  }
}
#else
class TagSqlplugin {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "sql";

  array get_dataset(mapping m, RequestID id) {
    NOCACHE();
    array(mapping(string:string|int)) res=do_sql_query(m, id);

    foreach(res, mapping(string:string|int) row)
      foreach(indices(row), string col)
	if(!row[col]) row[col]=RXML.Void;

    return res;
  }
}
#endif

class TagSQLQuery {
  inherit RXML.Tag;
  constant name = "sqlquery";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      NOCACHE();

      array res=do_sql_query(args, id);

      if(args["mysql-insert-id"])
	if(args->dbobj && args->dbobj->master_sql)
	  RXML.user_set_var(args["mysql-insert-id"], args->dbobj->master_sql->insert_id());
	else
	  RXML.parse_error("No insert_id present.\n");

      id->misc->defines[" _ok"] = 1;
      return 0;
    }
  }
}

class TagSQLTable {
  inherit RXML.Tag;
  constant name = "sqltable";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      NOCACHE();

      object res=do_sql_query(args, id, 1);

      int ascii=!!args->ascii;
      string ret="";

      if (res) {
	string nullvalue=args->nullvalue||"";

	if (!ascii) {
	  ret="<tr>";
	  foreach(map(res->fetch_fields(), lambda (mapping m) {
					     return m->name;
					   } ), string name)
	    ret += "<th>"+name+"</th>";
	  ret += "</tr>\n";
	}

	array row;
	while(arrayp(row=res->fetch_row())) {
	  if (ascii)
	    ret += ((array(string))row) * "\t" + "\n";
	  else {
	    ret += "<tr>";
	    foreach(row, mixed value)
	      ret += "<td>"+(value==""?nullvalue:value)+"</td>";
	    ret += "</tr>\n";
	  }
	}

	if (!ascii)
	  ret=Roxen.make_container("table", args-(["host":"", "database":"", "user":"", "password":"",
						   "query":"", "nullvalue":"", "dbobj":""]), ret);

	id->misc->defines[" _ok"] = 1;
	result=ret;
	return 0;
      }

      id->misc->defines[" _ok"] = 0;
      return 0;
    }
  }
}


// ------------------- Callback functions -------------------------

Sql.sql sql_object(void|string host)
{
  string hostname = stringp(host)?host:query("hostname");
  Sql.sql con;
  function sql_connect = conf->sql_connect;
  mixed error;
  /* Is this really a good idea? /mast
  error = catch(con = sql_connect(hostname));
  if(error)
    return 0;
  return con;
  */
  return sql_connect(hostname);
}

string query_provides()
{
  return "sql";
}


// ------------------------ Setting the defaults -------------------------

void create()
{
  defvar("hostname", "localhost", "Default database",
	 TYPE_STRING | VAR_INITIAL,
	 "The default database that will be used if no <i>host</i> "
	 "attribute is given to the tags. Usually the <i>host</i> "
	 "attribute should be used with a symbolic database name definied "
	 "in the <i>SQL databases</i> module."
	 "<p>The default database is specified as a database URL in the "
	 "format "
	 "<tt>driver://user name:password@host:port/database</tt>.\n");
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
      replace (Roxen.html_encode_string (describe_error(err)), "\n", "<br />\n") +
      "<br />\n";
}
