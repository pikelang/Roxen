/*
 * $Id: mailadmin.pike,v 1.2 1998/09/04 17:16:33 js Exp $
 *
 * A general administration module for Roxen AutoMail
 * Johan Schön, September 1998
 */

#include <module.h>
inherit "module";

constant cvs_version="$Id: mailadmin.pike,v 1.2 1998/09/04 17:16:33 js Exp $";
constant thread_safe=1;

mapping sql_objs=([]);

// Roxen module functions

array register_module()
{
  return( ({ MODULE_PROVIDER|PARSER,
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

mapping|string tag_admin(string tag_name, mapping args, object id)
{
  int customer=(int)args->customer;
  if(!customer)
    return "No customer id supplied.";
  object db=get_sql();
  array cols=id->conf->array_map_providers("automail_admin_data","get_data");
  array users=db->query("select realname,username,id from users where custumer_id='"+
			customer+"' order by realname");
  foreach(users, mapping user)
  {
    user->what=db->query("select name,value,status from mail_expn where user_id='"+
			 user->id+"'");
    if(id->variables->apply)
      if( ((int)user->what->status) != (1 && id->variables["a"+user->what->id]) )
	db->query("update mail_expn set status='"+
		  (user->what->status=id->variabls["a"+user->what->id]?"1":"0")
		  what+"'");
  }

  return "foo";
}


mapping query_tag_callers()
{
  return ([ "automail-admin" : tag_admin]);
}

