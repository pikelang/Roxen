/*
 * $Id: sqltag.pike,v 1.1 1997/02/20 14:56:08 grubba Exp $
 *
 * A module for Roxen Challenger, which gives the tags
 * <SQLQUERY> and <SQLOUTPUT>.
 *
 * Henrik Grubbström 1997-01-12
 */

#include <module.h>
#include <sql.h>

inherit "module";
inherit "roxenlib";

/*
 * Module interface functions
 */

array register_module()
{
  return( ({ MODULE_PARSER,
	       "SQL-module",
	       "This module gives the two tags &lt;SQLQUERY&gt;, "
	       "&lt;SQLOUTPUT&gt; and &lt;SQLTABLE&gt;.",
	       0,
	       1 }) );
}

string cvs_version = "$Id: sqltag.pike,v 1.1 1997/02/20 14:56:08 grubba Exp $";

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
    object(Sql) sql;
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
    
    if (error = catch(sql = Sql(host, database, user, password))) {
      contents = "<h1>Couldn't connect to SQL-server</h1><br>\n" +
	((master()->describe_backtrace(error)/"\n")*"<br>\n") +
	contents;
    } else if (error = catch(result = sql->query(args->query))) {
      contents = "<h1>Query \"" + args->query + "\" failed: " +
	sql->error() + "</h1>\n" +
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
    object(Sql) sql;
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
    
    if (error = catch(sql = Sql(host, database, user, password))) {
      return("<h1>Couldn't connect to SQL-server</h1><br>\n" +
	     ((master()->describe_backtrace(error)/"\n")*"<br>\n"));
    } else if (error = catch(sql->query(args->query))) {
      return("<h1>Query \"" + args->query + "\" failed: " +
	     sql->error() + "</h1>\n" +
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
    object(Sql) sql;
    mixed error;
    object(Sql_result) sql_result;
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
    
    if (error = catch(sql = Sql(host, database, user, password))) {
      return("<h1>Couldn't connect to SQL-server</h1><br>\n" +
	     ((master()->describe_backtrace(error)/"\n")*"<br>\n"));
    } else if (error = catch(sql_result = sql->big_query(args->query))) {
      return("<h1>Query \"" + args->query + "\" failed: " +
	     sql->error() + "</h1>\n" +
	     ((master()->describe_backtrace(error)/"\n")*"<br>\n"));
    }

    if (sql_result) {
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
      foreach(map(sql_result->fetch_fields(), lambda (mapping m) {
	return(m->name);
      } ), string name) {
	res += "<th>"+name+"</th>";
      }
      res += "</tr>\n";
      while (row = sql_result->fetch_row()) {
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

string|void check_variable(string var, mixed new_value)
{
  switch(var) {
  case "hostname":
    if (catch(Sql(((lower_case(new_value)=="localhost")?"":new_value)))) {
      return("Couldn't connect to any SQL-server at "+new_value+"\n");
    }
    break;
  case "database":
    if (catch(Sql(((lower_case(query("hostname"))=="localhost")?"":query("hostname")),
		  new_value))) {
      return("Couldn't select database "+new_value+"\n");
    }
    break;
  case "user":
    break;
  case "password":
    if (catch(Sql(((lower_case(query("hostname"))=="localhost")?"":query("hostname")),
		  query("database"), query("user"), new_value))) {
      return("Couldn't connect to database. Wrong password?\n");
    }
    break;
  default:
    return("Unknown variable "+var+"\n");
  }
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
  return("OK");
}

