/*
 * $Id: clientlayer.pike,v 1.5 1998/08/30 04:24:30 per Exp $
 *
 * A module for Roxen AutoMail, which provides functions for
 * clients.
 *
 * Johan Schön, August 1998
 */

#include <module.h>
inherit "module";

constant cvs_version="$Id: clientlayer.pike,v 1.5 1998/08/30 04:24:30 per Exp $";
constant thread_safe=1;

mapping sql_objs=([]);

// Roxen module functions

array register_module()
{
  return( ({ MODULE_PROVIDER,
	     "AutoMail Client Layer module",
	     "A module for Roxen AutoMail, which provides functions for "
             "client modules.",
	     0,
	     1 }) );
}

string query_provides()
{
  return "automail_clientlayer";
}

void create()
{
  defvar("maildir", "/home/js/AutoSite/mails/", "Mail storage directory", TYPE_DIR,
	 "This is the physical location of the root directory for all"
         " mail.");
  defvar("db_location", "mysql://auto:site@kopparorm/autosite",
	 "Database URL" ,TYPE_STRING,
 	 "");
}


string load_body(string body_id)
{
  // FIXME: hash body_id to subdirectories
  return Stdio.read_bytes(query("maildir")+"/"+body_id);
}

void delete_body(string body_id)
{
  rm(query("maildir")+"/"+body_id);
}

object get_sql()
{
  if(sql_objs[this_thread])
    return sql_objs[this_thread];
  else
    return sql_objs[this_thread]=Sql.sql(query("db_location"));
}

// Client Layer functions

int authentificate_user(string username, string passwordcleartext)
{
  array a=get_sql()->query("select password,id from users where username='"+username+"'");
  if(!sizeof(a))
    return 0;
  return (int)(crypt(passwordcleartext,a[0]->password)?a[0]->id:0);
}

mapping(string:int) list_mailboxes(int user)
{
  array a=get_sql()->query("select id,name from mailboxes where user_id='"+user+"'");
  mapping mailboxes=([]);
  foreach(a, mapping row)
    mailboxes[row->name]=(int)row->id;
  return mailboxes;
}

array(int) list_mail(int mailbox_id)
{
  array a=get_sql()->query("select id from mail where mailbox_id='"+mailbox_id+
		     "' order by id");
  array mail=({});
  foreach(a, mapping row)
    mail+=({ (int)row->id });
  return mail;
}

mapping(string:mixed) get_mail(int mail_id)
{
  array a=get_sql()->query("select message_id from mail where id='"+mail_id+"'");
  if(!sizeof(a))
    return 0;
  a=get_sql()->query("select * from messages where id='"+a[0]->message_id+"'");
  if(!sizeof(a))
    return 0;
  mapping mail=a[0];
  mail->body=load_body(mail->body_id);
  return mail;
}

mapping(string:mixed) get_mail_headers(int message_id)
{
  array a=get_sql()->query("select message_id from mail where id='"+message_id+"'");
  if(!sizeof(a))
    return 0;
  a=get_sql()->query("select * from messages where id='"+a[0]->message_id+"'");
  if(!sizeof(a))
    return 0;
  return a[0];
}

int update_message_refcount(int message_id, int deltacount)
{
  array a=get_sql()->query("select refcount from messages where id='"+message_id+"'");
  if(!a||!sizeof(a))
    return 0;
  int refcount=(int)a[0]->refcount + deltacount;
  if(refcount <= 0)
  {
    get_sql()->query("delete from messages where id='"+message_id+"'");
    delete_body(a[0]->body_id);
  }
  else
    get_sql()->query("update messages set refcount='"+refcount+"' where id='"+message_id+"'");
  
}

int delete_mail(int mail_id)
{
  array a=get_sql()->query("select message_id from mail where id='"+mail_id+"'");
  if(!sizeof(a))
    return 0;
  int message_id=a[0]->message_id;
  get_sql()->query("delete from mail where id='"+mail_id+"'");
  a=get_sql()->query("select refcount,body_id from messages where id='"+message_id+"'");
  werror("%O",a);
  if(!a||!sizeof(a))
    return 0;
  if(!update_message_refcount(message_id,-1))
    return 0;
  return 1;
}

int create_mailbox(int user, string mailbox)
{
  object sql=Sql.sql("mysql://auto:site@kopparorm/autosite");
  sql->query("insert into mailboxes values(NULL,'"+user+"','"+mailbox+"')");
  return sql->master_sql->insert_id();
}

string get_mailbox_name(int mailbox_id)
{
  array a=get_sql()->query("select name from mailboxes where id='"+mailbox_id+"'");
  if(!sizeof(a)) return 0;
  return a[0]->name;
}

int delete_mailbox(int mailbox_id)
{
  get_sql()->query("delete from mailboxes where id='"+mailbox_id+"'");
  foreach(list_mail(mailbox_id), int mail_id)
    delete_mail(mail_id);
  return 1;
}

int rename_mailbox(int mailbox_id, string newmailbox)
{
  get_sql()->query("update mailboxes set name='"+newmailbox+"' where id='"+mailbox_id+"'");
  return 1;
}

int add_mailbox_to_mail(int mail_id, int mailbox_id)
{
  array a=get_sql()->query("select message_id from mail where id='"+mail_id+"'");
  if(!sizeof(a))
    return 0;
  int message_id=a[0]->message_id;
  get_sql()->query("insert into mail values(NULL,'"+mailbox_id+"','"+message_id+"')");
  if(!update_message_refcount(message_id,1))
    return 0;
  return 1;
}

void set_flag(int mail_id, string flag)
{
  get_sql()->query("insert into flags values('"+mail_id+"','"+flag+"')");
}

void delete_flag(int mail_id, string flag)
{
  get_sql()->query("delete from flags where mail_id='"+mail_id+"' and name='"+flag+"'");
}
  
multiset get_flags(int mail_id)
{
  array a=get_sql()->query("select name from flags where mail_id='"+mail_id+"'");
  if(!a) return (<>);
  multiset flags=(<>);
  foreach(a, mapping row)
    flags[row->name]=1;
  return flags;
}
