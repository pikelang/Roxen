// Associates a name with an SQL-database. Copyright © 1997 - 2000, Roxen IS.

#include <module.h>


//<locale-token project="mod_sqldb">LOCALE</locale-token>
//<locale-token project="mod_sqldb">SLOCALE</locale-token>
#define SLOCALE(X,Y)	_STR_LOCALE("mod_sqldb",X,Y)
#define LOCALE(X,Y)	_DEF_LOCALE("mod_sqldb",X,Y)
// end locale stuff

inherit "module";

constant cvs_version = "$Id: sqldb.pike,v 1.12 2000/11/26 15:58:57 nilsson Exp $";
constant module_type = MODULE_ZERO;
LocaleString module_name_locale = LOCALE(1,"SQL databases");
LocaleString module_doc_locale  = 
LOCALE(2,
"SQL databases provides symbolic names to any number of database URLs. The\n"
"symbolic names can later be used instead of the database URL. This makes\n"
"it unnecessary to store full database URLs in RXML pages, which enhances\n"
"security. It also becomes possible to change database without having to\n"
"change any RXML pages.");

void create()
{
  defvar("table", "", LOCALE(3,"Database URL table"),
	 TYPE_TEXT_FIELD|VAR_INITIAL,
	 LOCALE(4,"The table with database URLs in the format:"
		"<pre>name\tURL</pre>"
		"The database URL is specified as "
		"<tt>driver://user name:password@host:port/database</tt>.\n"));
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
	res += sprintf("<tr><td>"+LOCALE(5,"Connection OK")+"</td>"
		       "<td><tt>%s</tt></td>"
		       "<td>"+LOCALE(6,"%[2]s server on %[3]s")+
		       "</td></tr>\n",
		       Roxen.html_encode_string (s),
		       Roxen.html_encode_string (o->server_info()),
		       Roxen.html_encode_string (o->host_info()));
      } else if (err) {
	res += sprintf("<tr><td><font color='&usr.warncolor;'>"+
		       LOCALE(7,"Connection failed")+"</font>: %s</td>"
		       "<td><tt>%s</tt></td><td>&nbsp;</td></tr>\n",
		       Roxen.html_encode_string (describe_error (err)),
		       Roxen.html_encode_string (s));
      }
      else
	res += sprintf("<tr><td><font color='&usr.warncolor;'>"+
		       LOCALE(7,"Connection failed")+"</font>: "+
		       LOCALE(8,"Unknown reason")+"</td>"
		       "<td><tt>%s</tt></td><td>&nbsp;</td></tr>\n",
		       Roxen.html_encode_string (s));
    }
    res += "</table>\n";
  } else {
    res += LOCALE(9,"No associations defined.")+"<br>\n";
  }
  return(res);
}
