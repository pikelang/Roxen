/*
 * $Id: mailadmin.pike,v 1.1 1998/09/02 17:16:11 js Exp $
 *
 * A general administration module for Roxen AutoMail
 * Johan Schön, September 1998
 */

#include <module.h>
inherit "module";

constant cvs_version="$Id: mailadmin.pike,v 1.1 1998/09/02 17:16:11 js Exp $";
constant thread_safe=1;

mapping sql_objs=([]);

// Roxen module functions

array register_module()
{
  return( ({ MODULE_PROVIDER|MODULE_LOCATION,
	     "AutoMail Administration module",
	     "A general administration module for Roxen AutoMail.",
	     0,1 }) );
}

string query_provides()
{
  return "automail_admin";
}

void create()
{
  defvar("db_location", "mysql://auto:site@kopparorm/autosite",
	 "Database URL" ,TYPE_STRING,
 	 "");
}

object get_sql()
{
  if(sql_objs[this_thread])
    return sql_objs[this_thread];
  else
    return sql_objs[this_thread]=Sql.sql(query("db_location"));
}


string|mapping find_file(string f, object id)
{
  return "foo";
}
