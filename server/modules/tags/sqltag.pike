/*
 * $Id: sqltag.pike,v 1.3 1997/06/20 16:57:15 grubba Exp $
 *
 * A module for Roxen Challenger, which gives the tags
 * <SQLQUERY> and <SQLOUTPUT>.
 *
 * Henrik Grubbström 1997-01-12
 */

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
	       "&lt;SQLOUTPUT&gt; and &lt;SQLTABLE&gt;.",
	       0,
	       1 }) );
}

string cvs_version = "$Id: sqltag.pike,v 1.3 1997/06/20 16:57:15 grubba Exp $";

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
	 TYPE_STRING, "Specifies the default host to use for SQL-queries");
  defvar("database", "", "Default SQL-database",
	 TYPE_STRING, "Specifies the name of the default SQL-database");
  defvar("user", "", "Default username",
	 TYPE_STRING, "Specifies the default username to use for access");
  defvar("password", "", "Default password",
	 TYPE_STRING, "Specifies the default password to use for access");
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
    return(sprintf("Connected to %s-server on %s<br>\n"
		   o->server_info(), o->host_info()));
  }) {
    return("<font color=red>Not connected.</font><br>\n");
  }
}

