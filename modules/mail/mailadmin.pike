/*
 * $Id: mailadmin.pike,v 1.3 1998/09/08 21:30:35 js Exp $
 *
 * A general administration module for Roxen AutoMail
 * Johan Schön, September 1998
 */

#include <module.h>
inherit "module";

constant cvs_version="$Id: mailadmin.pike,v 1.3 1998/09/08 21:30:35 js Exp $";
constant thread_safe=1;

mapping sql_objs=([]);

// Roxen module functions

array register_module()
{
  return ({ MODULE_PROVIDER|MODULE_PARSER,
	    "AutoMail Administration module",
	    "A general administration module for Roxen AutoMail.",
	    0,1 }) ;
}

multiset query_provides()
{
  return (<"automail_admin">);
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

string set_variables(object id, string rcpt_name, int user_id, mapping rcpt_name_to_object)
{
  object db=get_sql();
  multiset vars=rcpt_name_to_object[rcpt_name]->query_automail_variables();
  string s="<h2><sqloutput query=\"select realname from users where id='"+
    user_id+"'\">#realname#</sqloutput></h2><form action='./' method=get>";
  foreach(indices(vars), string var)
  {
    s+=
      "<b>"+var[0]+":</b><br>"+
      "<input name='automail_admin_variable."+user_id+"."+rcpt_name+"."+var[1]+
      "' size=40><br><br>";
  }
  s+="<input type=submit name=apply value='Apply'></form>";
  return s;
}

string tag_admin(string tag_name, mapping args, object id)
{
  int customer=(int)args->customer;
  if(!customer)
    return "No customer id supplied.";
  object db=get_sql();
  array cols=Array.transpose(
    ({ id->conf->map_providers("automail_rcpt","query_automail_title"),
       id->conf->map_providers("automail_rcpt","query_automail_name") }));

  mapping rcpt_name_to_object=mkmapping(
    id->conf->map_providers("automail_rcpt","query_automail_name"),
    id->conf->get_providers("automail_rcpt"));

  // Check any variables that should be set  
  foreach(glob("automail_admin_variable.*",indices(id->variables)), string var)
  {
    int user_id;
    string name, rcpt_name;
    if(sscanf(var,"automail_admin_variable.%d.%s.%s",user_id,rcpt_name,name)==3)
      db->query("insert into admin_variables values('"+user_id+"','"+rcpt_name+
		"','"+name+"','"+db->quote(id->variables[var])+"')");
  }
  
  // Check any mouse clicks  
  foreach(glob("automail_admin_status.*.x",indices(id->variables)), string var)
  {
    int user_id;
    string name;
    if(sscanf(var,"automail_admin_status.%d.%s.x",user_id,name)==2)
    {
      array a=db->query("select status from admin_status where user_id='"+user_id+
			"' and rcpt_name='"+name+"'");
      int status=0;
      if(!sizeof(a))
	db->query("insert into admin_status values('"+user_id+"','"+name+ "','1')");
      else
      {
	status=(int)a[0]->status;
	db->query("update admin_status set status='"+(1-status)+"' where user_id='"+
		  user_id+"' and rcpt_name='"+name+"'");
      }
      if(!status && (sizeof(rcpt_name_to_object[name]->query_automail_variables()) !=
	 sizeof(db->query("select name from admin_variables where user_id='"+user_id+
			  "' and rcpt_name='"+name+"'"))))
	return set_variables(id,name,user_id,rcpt_name_to_object);
    }
  }

  // select the whole status matrix for html generating
  array users=db->query("select realname,username,id from users where customer_id='"+
			customer+"' order by realname");
  foreach(users, mapping user)
  {
    array a=db->query("select rcpt_name,status from admin_status where user_id='"+
		      user->id+"'");
    user->what=mkmapping(a->rcpt_name,a);
  }

  string s=
    "<form action='./' method=get><input type=hidden name=apply value=1>"
    "<table border=0 cellspacing=1 cellpadding=3><tr><td></td>";
  foreach(cols, array col)
    s+="<td bgcolor=#a8d4dc valign=bottom><gtext bg=#a8d4dc href=foo "
      "nfont=times 4 rotate=270>"+col[0]+"</gtext></td>";
  s+="</tr>";

  foreach(users, mapping user)
  {
    s+="<tr><td bgcolor=#a8d4dc>"+user->realname+"</td>";
    foreach(cols, array col)
      s+="<td align=center bgcolor=#b4b4f0>"
	"<input alt='' type=image name=\"automail_admin_status."+user->id+"."+
	col[1]+"\" src=/img/knapp_"+
	(( (int)user->what[col[1]]->status )?"on":"off")+
	".gif width=16 height=11 border=0></td>";
  }
  s+="</table></form>";

  return s;
}


mapping query_tag_callers()
{
  return ([ "automail-admin" : tag_admin]);
}

