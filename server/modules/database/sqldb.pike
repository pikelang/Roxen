// Associates a name with an SQL-database. Copyright © 1997 - 2000, Roxen IS.

#include <module.h>

inherit "module";

constant cvs_version = "$Id: sqldb.pike,v 1.7 2000/06/11 14:53:21 mast Exp $";
constant module_type = MODULE_ZERO;
constant module_name = "SQL databases";
constant module_doc  = 
#"SQL databases provides symbolic names to any number of database URLs. The
symbolic names can later be used instead of the database URL. This makes
it unnecessary to store full database URLs in RXML pages, which enhances
security. It also becomes possible to change database without having to
change any RXML pages.";

void create()
{
  defvar("table", "", "Database URL table", TYPE_TEXT_FIELD|VAR_INITIAL,
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
      Sql.sql o;

      mixed err = catch {
	o = Sql.sql(sql_urls[s]);
      };

      if (o) {
	res += sprintf("<tr><td>Connection OK</td>"
		       "<td><tt>%s</tt></td><td><tt>%s</tt></td></tr>\n",
		       Roxen.html_encode_string (s),
		       Roxen.html_encode_string (sql_urls[s]));
      } else if (err) {
	res += sprintf("<tr><td><font color=red>Connection failed</font>: %s</td>"
		       "<td><tt>%s</tt></td><td><tt>%s</tt></td></tr>\n",
		       Roxen.html_encode_string (describe_error (err)),
		       Roxen.html_encode_string (s),
		       Roxen.html_encode_string (sql_urls[s]));
      }
      else
	res += sprintf("<tr><td><font color=red>Connection failed</font>: "
		       "Unknown reason</td>"
		       "<td><tt>%s</tt></td><td><tt>%s</tt></td></tr>\n",
		       Roxen.html_encode_string (s),
		       Roxen.html_encode_string (sql_urls[s]));
    }
    res += "</table>\n";
  } else {
    res += "No associations defined.<br>\n";
  }
  return(res);
}
