// Associates a name with an SQL-database. Copyright © 1997 - 2000, Roxen IS.

#include <module.h>


//<locale-token project="mod_sqldb">LOCALE</locale-token>
//<locale-token project="mod_sqldb">SLOCALE</locale-token>
#define SLOCALE(X,Y)	_STR_LOCALE("mod_sqldb",X,Y)
#define LOCALE(X,Y)	_DEF_LOCALE("mod_sqldb",X,Y)
// end locale stuff

inherit "module";

constant cvs_version = "$Id: sqldb.pike,v 1.2 2001/01/10 08:57:27 per Exp $";
constant module_type = MODULE_ZERO;
LocaleString module_name_locale = LOCALE(1,"DEPRECATED: SQL databases");
LocaleString module_doc_locale  = 
LOCALE(2,
"Use the DBs tab in the configuration interface instead. This module is"
" only kept for compatibility with old configurations.");

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
      Sql.Sql o;

      mixed err = catch {
	o = Sql.Sql(sql_urls[s]);
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
