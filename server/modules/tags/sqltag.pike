/*
 * $Id: sqltag.pike,v 1.6 1997/09/05 16:57:07 grubba Exp $
 *
 * A module for Roxen Challenger, which gives the tags
 * <SQLQUERY> and <SQLOUTPUT>.
 *
 * Henrik Grubbström 1997-01-12
 */

constant cvs_version="$Id: sqltag.pike,v 1.6 1997/09/05 16:57:07 grubba Exp $";
constant thread_safe=1;
#include <module.h>

inherit "module";
inherit "roxenlib";

import Array;
import Sql;

/*
 * Module interface functions
 */

array register_module()
{
  return( ({ MODULE_PARSER,
	       "SQL-module",
	       "This module gives the three tags &lt;SQLQUERY&gt;, "
	       "&lt;SQLOUTPUT&gt; and &lt;SQLTABLE&gt;.<br>\n"
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
	       "doesn't do anything with the result. This is usefull if "
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
	       "</table></ul><p>\n"
	       "\n"
	       "<b>NOTE</b>: Specifying passwords in the documents may prove "
	       "to be a security hole if the module is not loaded for some "
	       "reason.<br>\n",
	       0,
	       1 }) );
}

/*
 * Tag handlers
 */

string sqloutput_tag(string tag_name, mapping args, string contents,
		     object request_id, mapping defines)
{
  if (args->query) {
    string host = query("hostname");
    string database = query("database");
    string user = query("user");
    string password = query("password");
    object(sql) con;
    array(mapping(string:mixed)) result;
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
    }
    if (args->user) {
      user = args->user;
    }
    if (args->password) {
      password = args->password;
    }
    host = lower_case(host);
    host = (host == "localhost")?"":host;
    
    if (error = catch(con = sql(host, database, user, password))) {
      contents = "<h1>Couldn't connect to SQL-server</h1><br>\n" +
	((master()->describe_backtrace(error)/"\n")*"<br>\n") +
	contents;
    } else if (error = catch(result = con->query(args->query))) {
      contents = "<h1>Query \"" + args->query + "\" failed: " +
	con->error() + "</h1>\n" +
	((master()->describe_backtrace(error)/"\n")*"<br>\n") +
	contents;
    } else if (result) {
      string nullvalue="";
      array(string) content_array = contents/"#";
      array(string) res_array=allocate(sizeof(content_array)*sizeof(result));
      int j = 0;

      if (args->nullvalue) {
	nullvalue = (string)args->nullvalue;
      }

      foreach(result, mapping(string:mixed) row) {
	int i;

	for (i=0; i < sizeof(content_array); i++, j++) {
	  if (i & 1) {
	    if (row[content_array[i]] || !zero_type(row[content_array[i]])) {
	      string value = (string)row[content_array[i]];
	      res_array[j] = ((value=="")?nullvalue:value);
	    } else if (content_array[i] == "") {
	      /* Dual #'s to get one */
	      res_array[j] = "#";
	    } else {
	      res_array[j] = "<!-- Missing field " + content_array[i] + " -->";
	    }
	  } else {
	    res_array[j] = content_array[i];
	  }
	}
      }
      contents = res_array * "";
    }
  } else {
    contents = "<!-- No query! -->" + contents;
  }
  return(contents);
}

string sqlquery_tag(string tag_name, mapping args,
		    object request_id, mapping defines)
{
  if (args->query) {
    string host = query("hostname");
    string database = query("database");
    string user = query("user");
    string password = query("password");
    object(sql) con;
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
    }
    if (args->user) {
      user = args->user;
    }
    if (args->password) {
      password = args->password;
    }
    host = lower_case(host);
    host = (host == "localhost")?"":host;
    
    if (error = catch(con = sql(host, database, user, password))) {
      return("<h1>Couldn't connect to SQL-server</h1><br>\n" +
	     ((master()->describe_backtrace(error)/"\n")*"<br>\n"));
    } else if (error = catch(con->query(args->query))) {
      return("<h1>Query \"" + args->query + "\" failed: " +
	     con->error() + "</h1>\n" +
	     ((master()->describe_backtrace(error)/"\n")*"<br>\n"));
    }
  } else {
    return("<!-- No query! -->");
  }
  return("");
}

string sqltable_tag(string tag_name, mapping args,
		    object request_id, mapping defines)
{
  if (args->query) {
    string host = query("hostname");
    string database = query("database");
    string user = query("user");
    string password = query("password");
    object(sql) con;
    mixed error;
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
    }
    if (args->user) {
      user = args->user;
    }
    if (args->password) {
      password = args->password;
    }
    host = lower_case(host);
    host = (host == "localhost")?"":host;
    
    if (error = catch(con = sql(host, database, user, password))) {
      return("<h1>Couldn't connect to SQL-server</h1><br>\n" +
	     ((master()->describe_backtrace(error)/"\n")*"<br>\n"));
    } else if (error = catch(result = con->big_query(args->query))) {
      return("<h1>Query \"" + args->query + "\" failed: " +
	     con->error() + "</h1>\n" +
	     ((master()->describe_backtrace(error)/"\n")*"<br>\n"));
    }

    if (result) {
      string nullvalue="";
      array(mixed) row;

      if (args->nullvalue) {
	nullvalue=(string)args->nullvalue;
      }

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
      while (row = result->fetch_row()) {
	res += "<tr>";
	foreach(row, mixed value) {
	  value = (string)value;
	  res += "<td>"+(value==""?nullvalue:value)+"</td>";
	}
	res += "</tr>\n";
      }
      res += "</table>";

      return(res);
    } else {
      return("<!-- No result from query -->");
    }
  } else {
    return("<!-- No query! -->");
  }
}

string dumpid_tag(string tag_name, mapping args,
		  object request_id, mapping defines)
{
  return(sprintf("<pre>ID:%O\n</pre>\n",
		 mkmapping(indices(request_id), values(request_id))));
}

/*
 * Hook in the tags
 */

mapping query_tag_callers()
{
  return( ([ "sql":sqlquery_tag, "sqlquery":sqlquery_tag,
	     "sqltable":sqltable_tag, "dumpid":dumpid_tag ]) );
}

mapping query_container_callers()
{
  return( ([ "sqloutput":sqloutput_tag ]) );
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
	 "</ul>Valid values for \"sqlserver\" depend on which "
	 "sql-servers your pike has support for, but the following "
	 "might exist: msql, mysql, odbc, oracle, postgres.\n");
  defvar("database", "", "Default SQL-database",
	 TYPE_STRING, "Specifies the name of the default SQL-database.\n");
  defvar("user", "", "Default username",
	 TYPE_STRING, "Specifies the default username to use for access.\n");
  defvar("password", "", "Default password",
	 TYPE_STRING, "Specifies the default password to use for access.\n");
}

/*
 * More interface functions
 */

void start()
{
}

void stop()
{
}

string status()
{
  if (catch {
    object o = Sql.sql(QUERY(hostname), QUERY(database),
		       QUERY(user), QUERY(password));
    return(sprintf("Connected to %s-server on %s<br>\n",
		   o->server_info(), o->host_info()));
  }) {
    return("<font color=red>Not connected.</font><br>\n");
  }
}

