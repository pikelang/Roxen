// Associates a name with an SQL-database. Copyright © 1997 - 2000, Roxen IS.

#include <module.h>

inherit "module";

constant cvs_version = "$Id: sqldb.pike,v 1.9 2000/10/18 21:28:04 mast Exp $";
constant module_type = MODULE_ZERO;
constant module_name = "SQL databases";
constant module_doc  = 
#"SQL databases provides symbolic names to any number of database URLs.
The symbolic names can later be used instead of the database URL. This
avoids storing full database URLs in RXML pages, which enhances
security. It also becomes possible to change database without having
to change any RXML pages.";

void create()
{
  defvar("table", "", "Database URL table", TYPE_TEXT_FIELD|VAR_INITIAL,
	 "The table with database URLs. Every line is on the form:\n"
	 "<p><blockquote><pre><i>name</i>\t<i>URL</i>\n"
	 "</pre></blockquote>\n"
	 "<p><i>URL</i> is a database URL and the <i>name</i> is the alias "
	 "given to it. Database URLs have the format:\n"
	 "<p><blockquote><pre>"
	 "<i>driver</i><b>://</b>"
	 "[<i>username</i>[<b>:</b><i>password</i>]<b>@</b>]"
	 "<i>host</i>[<b>:</b><i>port</i>]"
	 "[<b>/</b><i>database</i>]\n"
	 "</pre></blockquote>\n");
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
    res += "<p><table border=\"0\">\n"
      "<tr><th align='left'>Alias</th><td>&nbsp;&nbsp;</td>"
      "<th align='left'>Connection status</th></tr>\n";
    foreach(sort(indices(sql_urls)), string s) {
      res += "<tr><td>" + Roxen.html_encode_string (s) + "</td><td>&nbsp;</td>";

      Sql.sql o;

      mixed err = catch {
	o = Sql.sql(sql_urls[s]);
      };

      if (o) {
	res += sprintf("<td>Connected to %s server on %s</td>",
		       Roxen.html_encode_string (o->server_info()),
		       Roxen.html_encode_string (o->host_info()));
      } else if (err) {
	res += sprintf("<td><font color='red'>Connection failed</font>: %s</td>",
		       Roxen.html_encode_string (describe_error (err)));
      }
      else
	res += "<td><font color='red'>Connection failed</font>: Unknown reason</td>";

      res += "</tr>\n";
    }
    res += "</table>\n";
  } else {
    res += "<p>No associations defined.\n";
  }
  return(res);
}
