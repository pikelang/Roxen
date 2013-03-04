// Associates a name with an SQL-database. Copyright © 1997 - 2009, Roxen IS.

#include <module.h>
inherit "module";

constant cvs_version = "$Id$";
constant module_type = MODULE_ZERO;
constant module_name = "DEPRECATED: SQL databases";
constant module_doc  =
"Use the DBs tab in the configuration interface instead. This module is"
" only kept for compatibility with old configurations.";

void create()
{
  defvar("table", "", "Database URL table",
	 TYPE_TEXT_FIELD|VAR_INITIAL,
	 "The table with database URLs in the format:"
	 "<pre>name\tURL</pre>"
	 "The database URL is specified as "
	 "<tt>driver://user name:password@host:port/database</tt>.\n");
}

mapping(string:string) parse_table(string tab)
{
  mapping(string:string) res = ([]);

  tab = replace(tab||"", "\r", "\n");

  foreach(tab/"\n", string line) {
    string line2 = replace(line, "\t", " ");
    array(string) arr = (line2/" ") - ({ "" });
    if ((sizeof(arr) >= 2) && (arr[0][0] != '#')) {
      string name = arr[0];
      string infix = arr[1];
      string suffix = ((line/name)[1..])*name;
      suffix = infix + ((suffix/infix)[1..])*infix;
      res[name] = suffix;
    }
  }
  return(res);
}

void start(int level, Configuration conf)
{
  conf->sql_urls = parse_table(QUERY(table));
}

string status()
{
  mapping sql_urls = parse_table(QUERY(table));

  string res = "";

  if (sizeof(sql_urls)) {
    res += "<table border=\"0\">\n";
    foreach(sort(indices(sql_urls)), string s) {
      Sql.Sql o;

      mixed err = catch {
	o = Sql.Sql(sql_urls[s]);
      };

      if (o) {
	res += sprintf("<tr><td>Connection OK</td>"
		       "<td><tt>%s</tt></td>"
		       "<td>%s server on %s"
		       "</td></tr>\n",
		       Roxen.html_encode_string (s),
		       Roxen.html_encode_string (o->server_info()),
		       Roxen.html_encode_string (o->host_info()));
      } else if (err) {
	res += sprintf("<tr><td><font color='&usr.warncolor;'>"
		       "Connection failed</font>: %s</td>"
		       "<td><tt>%s</tt></td><td>&nbsp;</td></tr>\n",
		       Roxen.html_encode_string (describe_error (err)),
		       Roxen.html_encode_string (s));
      }
      else
	res += sprintf("<tr><td><font color='&usr.warncolor;'>"
		       "Connection failed</font>: "
		       "Unknown reason</td>"
		       "<td><tt>%s</tt></td><td>&nbsp;</td></tr>\n",
		       Roxen.html_encode_string (s));
    }
    res += "</table>\n";
  } else {
    res += "No associations defined.<br />\n";
  }
  return(res);
}
