/*
 * $Id: clientlayer.pike,v 1.1 1998/08/24 00:08:56 js Exp $
 *
 * A module for Roxen AutoMail, which provides functions for
 * clients.
 *
 * Johan Schön, August 1998
 */

#include <module.h>
inherit "module";

constant cvs_version="$Id: clientlayer.pike,v 1.1 1998/08/24 00:08:56 js Exp $";
constant thread_safe=1;

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
}


string load_body(string body_id)
{
  return "";
}

void delete_body(string body_id)
{
}


// Client Layer functions

int authentificate_user(string username, string passwordcleartext)
{
  array a=sql->query("select password from user,id where username='"+username+"'");
  if(!sizeof(a))
    return 0;
  return crypt(passwordcleartext,a[0]->password)?a[0]->id:0;
}

mapping(string:int) list_mailboxes(int user)
{
  array a=sql->query("select id,name from mailboxes where user='"+user+"'");
  mapping mailboxes=([]);
  foreach(a, mapping row)
    mailboxes[row->name]=(int)row->id;
  return mailboxes;
}

array(int) list_mail(int user, int mailbox_id)
{
  array a=sql->query("select id from mail where mailbox_id='"+mailbox_id+
		     "' order by id");
  array mail=({});
  foreach(a, mapping row)
    mail+=({ (int)row->id });
  return mail;
}

mapping(string:mixed) retrieve_mail(int mail_id)
{
  array a=sql->query("select message_id from mail where id='"+mail_id+"'");
  if(!sizeof(a))
    return 0;
  a=sql->query("select * from messages where id='"+a[0]->message_id+"'");
  if(!sizeof(a))
    return 0;
  mapping mail=a[0];
  mail->body=load_body(mail->body_id);
  return mail;
}

array(string) retrieve_mail_headers(int message_id)
{
  array a=sql->query("select message_id from mail where id='"+mail_id+"'");
  if(!sizeof(a))
    return 0;
  a=sql->query("select * from messages where id='"+a[0]->message_id+"'");
  if(!sizeof(a))
    return 0;
  return a[0];
}

int delete_mail(int mail_id)
{
  array a=sql->query("select message_id from mail where id='"+mail_id+"'");
  if(!sizeof(a))
    return 0;
  int message_id=a[0]->message_id;
  sql->query("delete from mail where mail_id='"+mail_id+"'");
  a=sql->query("select refcount,body_id from messages where id='"+message_id+"'");
  if(refcount==1)
  {
    sql->query("delete from messages where id='"+message_id+"'");
    delete_body(a[0]->body_id);
  }
  else
    sql->query("update messages set refcount=refcount-1");
  return 1;
}

int create_mailbox(int user, string mailbox)
{
  sql->query("insert into mailboxes values(NULL,'"+user+"','"+mailbox+"')");
  return sql->master_sql->insert_id();
}

string get_mailbox_name(int mailbox_id)
{
  array a=sql->query("select name from mailboxes where id='"+mailbox_id+"'");
  if(!sizeof(a)) return 0;
  return a[0]->name;
}

int delete_mailbox(int mailbox_id)
{
  sql->query("delete from mailboxes where id='"+mailbox_id+"'");
  return 1;
}

int rename_mailbox(int mailbox_id, string newmailbox)
{
  sql->query("update mailboxes set name='"+newmailbox+"' where id='"+mailbox_id+"'");
  return 1;
}

int add_mailbox_to_mail(int mail_id, int mailbox_id)
{
  array a=sql->query("select message_id from mail where id='"+mail_id+"'");
  if(!sizeof(a))
    return 0;
  int message_id=a[0]->message_id;
  sql->query("insert into mail values(NULL,'"+mailbox_id+"','"+message_id+"'");
  return sql->master_sql->insert_id();
}

void set_flag(int mail_id, string flag)
{
  sql->query("insert into flags values('"+mail_id+"','"+flag+"'");
}

void remove_flag(int mail_id, string flag)
{
  sql->query("delete from flags where mail_id='"+mail_id+"' and name='"+flag+"'");
}
  
multiset get_flags(int mail_id)
{
  array a=sql->query("select name from flags where mail_id='"+mail_id+"'");
  if(!a) return (<>);
  multiset flags=(<>);
  foreach(a, mapping row)
    flags[row->name]=1;
  return flags;
}
