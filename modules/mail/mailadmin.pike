/*
 * $Id: mailadmin.pike,v 1.9 1998/10/01 05:23:35 js Exp $
 *
 * A general administration module for Roxen AutoMail
 * Johan Schön, September 1998
 */

#include <module.h>
inherit "module";
inherit "roxenlib";

constant cvs_version="$Id: mailadmin.pike,v 1.9 1998/10/01 05:23:35 js Exp $";
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


// object sql = thread_local();
// static Sql.sql get_sql()
// {
//   if(sql->get())
//     return sql->get();
//   sql->set(Sql.sql(query("db_location")));
//   return sql->get();
// }

object get_sql()
{
  if(sql_objs[this_thread()])
    return sql_objs[this_thread()];
  else
    return sql_objs[this_thread()]=Sql.sql(query("db_location"));
}

array(mapping(string:string)) squery(string fmt, mixed ... args)
{
  return sql_query(sprintf(fmt, @args));
}

array(mapping(string:string)) sql_query(string query_string, int|void nolock)
{
  array(mapping(string:string)) result = get_sql()->query( query_string );
  return result;
}

string sql_insert_mapping(mapping m)
{
  string pre="",post="";
  foreach(indices(m), string q)
  {
    pre += quote(q)+",";
    post += "'"+quote((string)m[q])+"',";
  }
  return sprintf("( %s ) VALUES ( %s )", 
		 pre[..strlen(pre)-2], post[..strlen(post)-2]);
}


string quote(string what)
{
  return get_sql()->quote(what);
} 

function sql_quote = quote;

string set_variables(object id, string rcpt_name, int user_id, mapping rcpt_name_to_object)
{
  object db=get_sql();
  string s="<h2><sqloutput query=\"select realname from users where id='"+
    user_id+"'\">#realname#</sqloutput></h2><form action='./' method=get>";
  foreach(rcpt_name_to_object[rcpt_name]->query_automail_variables(), array var)
  {
    s+=
      "<b>"+var[0]+":</b><br>"+
      "<input name='automail_admin_variable."+user_id+"."+rcpt_name+"."+var[1]+
      "' size=40><br><br>";
  }
  s+="<input type=submit name=apply value='Apply'></form>";
  return s;
}

string tag_matrix(string tag_name, mapping args, object id)
{
  int customer=(int)args->customer;
  if(!customer)
    return "No customer id supplied.";
  object db=get_sql();

  array titles=id->conf->map_providers("automail_rcpt","query_automail_title");
  array names= id->conf->map_providers("automail_rcpt","query_automail_name");
  sort(titles,names);

  array cols=Array.transpose(
    ({ titles, names }) );

  mapping rcpt_name_to_object=mkmapping(
    id->conf->map_providers("automail_rcpt","query_automail_name"),
    id->conf->get_providers("automail_rcpt"));

  // Check any variables that should be set  
  foreach(glob("automail_admin_variable.*",indices(id->variables)), string var)
  {
    int user_id;
    string name, rcpt_name;
    if(sscanf(var,"automail_admin_variable.%d.%s.%s",user_id,rcpt_name,name)==3)
      db->query("replace into admin_variables values('"+user_id+"','"+rcpt_name+
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
      if(status==0 &&
	 (sizeof(rcpt_name_to_object[name]->query_automail_variables()) !=
	  sizeof(db->query("select name from admin_variables where user_id='"+user_id+
			   "' and rcpt_name='"+name+"'"))))
	return set_variables(id,name,user_id,rcpt_name_to_object);
      else
      {
	id->misc->do_redirect=1;
	return "";
      }
    }
  }

  // select the whole status matrix for html generating later on
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
    s+="<td bgcolor=#a8d4dc valign=bottom><gtext bg=#a8d4dc "
      "nfont=times 4 rotate=270>"+col[0]+"</gtext></td>";
  s+="</tr>";

  foreach(users, mapping user)
  {
    s+="<tr><td bgcolor=#a8d4dc><a href=./?adduser=1&edit="+
      user->id+">"+user->realname+" (<i>"+user->username+"</i>)</a></td>";
    foreach(cols, array col)
      s+="<td align=center bgcolor=#b4b4f0>"
	"<input alt='' type=image name=\"automail_admin_status."+user->id+"."+
	col[1]+"\" src=/img/knapp_"+
	(( user->what[col[1]] && (int)user->what[col[1]]->status )?"on":"off")+
	".gif width=16 height=11 border=0></td>";
  }
  s+="</table><br><input type=submit name=adduser value='Add a user'></form>";
  s+="<br><br>Press the users name to edit it's parameters.";
  return s;
}


// Add or edit a user

string tag_adduser(string tag_name, mapping args, object id)
{
  if(id->variables->edit)
    args->edit=id->variables->edit;
  string error="";
  int not_ok;

  // Edit, not create, a user. Fetch default values from database.
  if(args->edit)
  {
    array a=squery("select * from users where id='%d'",(int)args->edit);
    if(!sizeof(a))
      return "No such user.";
    id->variables->realname=id->variables->realname||a[0]->realname;
    id->variables->username=id->variables->username||a[0]->username;
    id->variables->crypted_password=a[0]->password;
    foreach(squery("select * from admin_variables where user_id='%d'",(int)args->edit),
	    mapping var)
    {
      string var_name="automail_adduser_variable."+var->rcpt_name+"."+var->name;
      id->variables[var_name]=id->variables[var_name]||var->value;
    }
  }
  
  if(id->variables->entered)
  {
    if(id->variables->password!=id->variables->password_again)
    {
      error="Passwords don't match.";
      id->variables->password_again="";
      not_ok=1;
    }
    if(!id->variables->edit && (!sizeof(id->variables->realname) ||
		 !sizeof(id->variables->username) ||
		 !sizeof(id->variables->password)))
    {
      error="Enter all fields.";
      not_ok=1;
    }
    if(!id->variables->edit &&
       sizeof(squery("select id from users where username='%s' and customer_id='%d'",
		     id->variables->username,(int)args->customer)))
    {
      error="That username already exists.";
      not_ok=1;
    }
    if(!not_ok)
    {
      mapping m=(["realname":id->variables->realname,
		  "username":id->variables->username,
		  "password":crypt(id->variables->password),
		  "customer_id":args->customer]);
      if(args->edit && (!id->variables->password || !sizeof(id->variables->password)))
	m->password=id->variables->crypted_password;
      if(args->edit)
	m->id=(int)args->edit;
      squery("replace into users "+
	     sql_insert_mapping(m));
      int user_id=get_sql()->master_sql->insert_id()||(int)id->variables->edit;
      foreach(glob("automail_adduser_variable.*",indices(id->variables)), string var)
      {
	string name, rcpt_name;
	if(sscanf(var,"automail_adduser_variable.%s.%s",rcpt_name,name)==2)
	  squery("replace into admin_variables"+
		 sql_insert_mapping((["user_id": user_id,
				      "rcpt_name": rcpt_name,
				      "name": name,
				      "value": id->variables[var] ])));
      }
      id->misc->do_redirect=1;
      return "";
    }
  }
  string s=
    "<h1>User details</h1><form method=get action='./'>";
  if(args->edit)
    s+="<input type=hidden name=edit value='"+args->edit+"'>";
  s+=
    "<input type=hidden name=entered value=1><table><tr>"+
    "<td><b>Real name:</b></td><td><input name=realname value='"+
    (id->variables->realname||"")+"' size=40></td></tr><tr>"+
    "<td><b>Username:</b></td><td><input name=username value='"+
    (id->variables->username||"")+"' size=20></td></tr><tr>"+
    "<td><b>Password:</b></td><td><input name=password type=password value='"+
    (id->variables->password||"")+"' size=20></td></tr><tr>"+
    "<td><b>Password (again):</b></td><td><input name=password_again type=password value='"+
    (id->variables->password_again||"")+"' size=20></td></tr></table>";

  s+="<h1>Module variables</h1>";
  array rcpts=id->conf->get_providers("automail_rcpt");
  array tmp=rcpts->query_automail_title();
  sort(tmp,rcpts);
  foreach(rcpts, object rcpt)
  {
    array vars=rcpt->query_automail_variables();
    if(sizeof(vars))
      s+="<h3>"+rcpt->query_automail_title()+"</h3><table>";
    foreach(vars, array var)
    {
      string var_name="automail_adduser_variable."+rcpt->query_automail_name()+"."+var[1];
      s+="<tr><td><b>"+var[0]+":</b></td><td><input size=40 name='"+var_name+"' value='"+
	(id->variables[var_name]||"")+
	"'></td></tr>";
    }
    if(sizeof(vars))
      s+="</table>";
  }
  s+="<b><font color=darkred>"+error+"</font></b><br>";
  s+="<input type=submit name=adduser value='Save'>";
  if(args->edit)
    s+=" <input type=submit name=delete_user value='Delete user'>";
  s+="</form>";
  return s;
}

string tag_delete_user(string tag_name, mapping args, object id)
{
  if(id->variables->really_delete)
  {
    squery("delete from admin_status where user_id='%d'",(int)id->variables->edit);
    squery("delete from admin_variables where user_id='%d'",(int)id->variables->edit);
    squery("delete from users where id='%d'",(int)id->variables->edit);
    id->misc->do_redirect=1;
    return "";
  }
  else
  {
    array a=squery("select realname,username from users where id='%d'",
		   (int)id->variables->edit);
    string s="";
    s+=
      "<h2>Really delete user '"+a[0]->realname+" (<i>"+a[0]->username+"</i>)'?</h2>"
      "<form method=get action='./'>"
      "<input type=hidden name=edit value='"+(int)id->variables->edit+"'>"
      "<input type=hidden name=delete_user value=1>"
      "<input type=submit name=really_delete value='Yes, delete this user'>"
      "</form><form method=get action='./'>"
      " <input type=submit name=nope value='No, do not delete this user'>"
      "</form>";
    return s;
  }
}

// roxen module callback

mapping query_tag_callers()
{
  return ([ "automail-admin-matrix" : tag_matrix,
	    "automail-admin-adduser": tag_adduser,
	    "automail-admin-delete-user": tag_delete_user
  ]);
}


// callbacks

int query_status(int user_id, string rcpt_name)
{
  array a=squery("select status from admin_status where user_id='%d' and rcpt_name='%s'",
		 user_id,quote(rcpt_name));
  if(!sizeof(a))
    return 0;
  else
    return (int)a[0]->status;
}

string query_variable(int user_id, string rcpt_name, string variable)
{
  array a=squery("select value from admin_variables where user_id='%d' and "
		 "rcpt_name='%s' and name='%s'",
		 user_id,quote(rcpt_name),quote(variable));;
  if(!sizeof(a))
    return 0;
  else
    return a[0]->value;
}


