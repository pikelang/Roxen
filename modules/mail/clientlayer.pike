/*
 * $Id: clientlayer.pike,v 1.9 1998/09/09 10:03:25 per Exp $
 *
 * A module for Roxen AutoMail, which provides functions for
 * clients.
 *
 * Johan Schön, August 1998
 */

#include <module.h>
inherit "module" : module;

constant cvs_version="$Id: clientlayer.pike,v 1.9 1998/09/09 10:03:25 per Exp $";
constant thread_safe=1;

mapping sql_objs=([]);

/* Roxen module functions ----------------------------------- */

array register_module()
{
  return( ({ MODULE_PROVIDER,
	     "AutoMail Client Layer module",
	     "A module for Roxen AutoMail, which provides functions for "
             "client modules.",
	     0,
	     1 }) );
}

void create()
{
  defvar("maildir", "/home/js/AutoSite/mails/", "Mail storage directory", 
	 TYPE_DIR,
	 "This is the physical location of the root directory for all"
         " mail.");

  defvar("db_location", "mysql://auto:site@kopparorm/autosite",
	 "Database URL" ,TYPE_STRING,"");
}

string query_provides()
{
  return "automail_clientlayer";
}



/* Utility functions   ---------------------------------------- */

#if constant(thread_local)
object sql = thread_local();
Thread.Mutex lock = Thread.Mutex();
static Sql.sql get_sql()
{
  if(sql->get())
    return sql->get();
  sql->set(Sql.sql(query("db_location")));
  return sql->get();
}
#else
object sql;
object lock = class {
  void lock()
  {
    /* NO-OP */
  }
  function unlock = lock;
}();

static Sql.sql get_sql()
{
  if(sql)
    return sql;
  sql = Sql.sql(query("db_location"));
  return sql;
}
#endif

array(mapping(string:string)) squery(string fmt, mixed ... args)
{
  return sql_query(sprintf(fmt, @args));
}

array(mapping(string:string)) sql_query(string query_string, int|void nolock)
{
  object key;
  if(!nolock)
    key = lock->lock();
  array(mapping(string:string)) result = get_sql()->query( query_string );
  if(key)
    destruct(key);
  return result;
}

string sql_insert_mapping(mapping m)
{
  string pre="",post="";
  foreach(indices(m), string q)
  {
    pre += "'"+quote(q)+"',";
    post += "'"+quote(m[q])+"',";
  }
  return sprintf("( %s ) VALUES ( %s )", 
		 pre[..strlen(pre)-2], post[..strlen(post)-2]);
}


string quote(string what)
{
  return get_sql()->quote(what);
} 

function sql_quote = quote;

string hash_body_id(string body_id)
{
  body_id="0000"+body_id;
  int p=sizeof(body_id)-5;
  return body_id[p..p+1]+"/"+body_id[p+2..p+3];
}

Stdio.File load_body_get_obj(string body_id)
{
  Stdio.File o = Stdio.File();
  if(o->open( query("maildir")+"/"+body_id,"r" ))
    return o;
  return 0;
}

string get_unique_body_id()
{
  string id;
  object key = lock->lock(); // Do this transaction locked.
  sql_query("update message_body_id set last=last+1", 1);
  id=sql_query("select last from message_body_id where 1=1", 1)[0]->last;
  destruct(key);
  return id;
}

Stdio.File get_fileobject(string body_id)
{
  string where=hash_body_id(body_id);
  mkdirhier(query("maildir")+"/"+where);
  return Stdio.File(query("maildir")+"/"+where+"/"+body_id,"wc");
}

void delete_body(string body_id)
{
  rm(query("maildir")+"/"+hash_body_id(body_id)+"/"+body_id);
}

Stdio.File new_body( string body_id )
{
  string f = query("maildir")+"/"+hash_body_id(body_id)+"/"+body_id;
  mkdirhier(f);
  return Stdio.File(f, "rwct");
}

/* Client Layer Abstraction ---------------------------------------- */

static mapping (program:mapping(int:object)) object_cache = ([]);

object get_cache_obj( program type, string|int id )
{
  if(!object_cache[ type ])
    return 0;
  if(object_cache[ type ][ id ])
    return object_cache[ type ][ id ];
}

object get_any_obj(string|int id, program type, mixed ... moreargs)
{
  if(!object_cache[ type ])
    object_cache[ type ] = ([]);
  if(object_cache[ type ][ id ])
  {
    object_cache[ type ][ id ]->create(id, @moreargs);
    return object_cache[ type ][ id ];
  }
  return object_cache[ type ][ id ] = type(id,@moreargs);
}

class Common
{
  int serial;
  int get_serial()
  {
    return serial;
  }

  int modify()
  {
    serial++;
  }
}

class Mail
{
  inherit Common;
  inherit MIME.Message;
  string message_id;
  string id;
  object user;
  object mailbox;
  // array(object) _mboxes; 
  // Nope. This is now actually a mail, not a message. Thus, it is
  // only present in _one_ mailbox.


  local static string encode_binary( mixed what )
  {
    return sql_quote( MIME.encode_base64( encode_value( what ), 1 ) );
  }

  local static mixed decode_binary( string what )
  {
    return decode_value( MIME.decode_base64( what ) );
  }

  mixed get(string var)
  {
    array(mapping) a;
    a=squery("select data from mail_misc where id=%s and variable='%s'",
	     id,var);
    if(sizeof(a))
      return decode_binary( a[0]->data );
  }

  mixed set(string name, mixed to)
  {
    modify();
    name = sql_quote( name );
    string enc = encode_binary( to );
    squery("delete from mail_misc where id=%s and variable='%s'", id, name);
    squery("insert into mail_misc values (%s,'%s','%s')", id, name, enc);
    return to;
  }

  string name;

  static mapping _headers;
  static multiset _flags;

  Stdio.File body_fd()
  {
    return load_body_get_obj( headers()->body_id );
  }

  string body()
  {
    return body_fd()->read();
  }

  mapping headers(int|void force)
  {
    mapping h = get_mail_headers( message_id );
    if(!_headers || force)
      return _headers = parse_headers( h[ "headers" ] )[0] | h;
    return _headers;
  }

  multiset flags(int|void force)
  {
    if(!_flags || force)
      return _flags = get_mail_flags( id );
  }

  void set_flag(string name)
  {
    modify();
    _flags = 0;
    set_mail_flag( id, name );
  }

  void clear_flag(string name)
  {
    _flags = 0;
    delete_mail_flag( id, name );
  }

  void create(string i, string m, object mb)
  {
    id = i;
    message_id = m;
    user = mb->user;
    mailbox = mb;
  }
}

class Mailbox
{
  inherit MIME.Message;
  inherit Common;
  static array _mails = ({ });

  int id;
  object user;
  string name;

  static mapping filter_headers( mapping from ) 
  {
    mapping res = ([]);
    if(from->subject) res->subject = from->subject;
    if(from->from) res->from = from->from;
    if(from->to) res->to = from->to;
    if(from->date) res->date = from->date;
    return res;
  }

  static string encode_headers( mapping from )
  {
    string res="";
    foreach(indices(from), string f)
      res += f+": "+from[f]+"\n";
    return res;
  }

			
  static string read_headers_from_fd( Stdio.File fd )
  {
    string q = "", w;
    do {
      w = fd->read(1024);
      q+=w;
    } while(strlen(w) && (search(q, "\r\n\r\n")==-1)
	    && (search(q, "\n\n")==-1));
    return q[..search(q, "\n\n")];
  }

  void remove_mail(Mail mail)
  {
    if(search(mails()->message_id, mail->message_id) != -1)
    {
      _mails = 0; // No optimization, for safety...
      destruct( mail );
      modify( );
      remove_mailbox_from_mail( mail->message_id, id );
    }
  }

  Mail add_mail(Mail mail, int|void nocopy)
  {
    if(search(mails()->message_id, mail->message_id) == -1)
    {
      _mails = 0;
      modify();
      add_mailbox_to_mail( mail->message_id, id );
      foreach(mails(), Mail m)
	if(m->message_id == mail->message_id)
	{
	  if(!nocopy)
	    foreach(indices(mail->flags), string f)
	      m->set_flag( f );
	  return m;
	}
      error("Added message could not be found in list of messages.\n");
    }
    return mail;
  }

  int rename(string to)
  {
    name=0;
    rename_mailbox( id, to );
  }
    
  void delete()
  {
    foreach(mails, object m)
    {
      m->_mboxes -= ({ this_object() });
      m->modify();
      user->_mailboxes = 0;
      user->modify();
    }
    delete_mailbox( id );
    destruct(this_object());
  }
  
  string query_name(int|void force)
  {
    if(force) name=0;
    return name||(name=get_mailbox_name( id ));
  }

  array(Mail) mails(int|void force)
  {
    if(!force && _mails) 
      return _mails;
    mapping q = list_mail( id );
    _mails = ({ });
    foreach(sort(indices(q)), string w)
      _mails += ({ get_any_obj( w, Mail, q[w], this_object()) });
    return _mails;
  }


  Mail low_create_mail( string bodyid, mapping headers )
  {
    /* This could be easier.. :-) */
    // 1> Generate the db row for the 'messages' table.
    mapping row = ([
      "sender":headers->from,
      "subject":headers->subject,
      "body_id":headers->bodyid,
      "headers":encode_headers(filter_headers(headers)),
    ]);

    // 2> Insert the row in the database, and get a new message id.
    string mid = create_message( row );
    
    // 3> Insert the message in this mailbox using the 'mail' table.
    add_mailbox_to_mail( mid, id );
    
    // 4> Zap the cache.
    _mails = 0;
    modify();

    // 5> Find this new message in the mails() array.
    foreach(mails(), Mail m)
      if(m->message_id == mid)
	return m;

    // Oups. This should not happend. :-)
    error("Failed to find newly created message in message array!\n");
  }

  Mail create_mail_from_fd( Stdio.File fd )
  {
    string foo = read_headers_from_fd( fd );
    mapping headers = parse_headers( foo )[0];
    string bodyid = get_unique_body_id();
    fd->seek( 0 );
    Stdio.File f = new_body( bodyid );
    do 
    {
      foo = fd->read( 8192 );
      if( f->write( foo ) != 8192 )
	error("Failed to write body.\n");
    } while(strlen(foo) == 8192);
    f->close();
    return low_create_mail( bodyid, headers );
  }

  Mail create_mail_from_data( string data )
  {
    return create_mail( MIME.Message( data ) );
  }

  Mail create_mail( MIME.Message m )
  {
    string bodyid = get_unique_body_id();
    object f = new_body( bodyid );
    string data = (string)m;
    if(f->write(data) != strlen(data))
      error("Failed to write body.\n");
    return low_create_mail( bodyid, m->headers );
  }

  void create(int i, object u, string n)
  {
    id = i;
    if(user != u)
      modify();
    user = u;
    if(name != n)
      modify();
    name = n;
  }
}

class User
{
  inherit Common;
  array _mboxes;
  int id;

  local static Mailbox create_mailbox( string name )
  {
    _mboxes = 0;
    modify();
    return Mailbox( create_user_mailbox( id, name ), this_object(), name );
  }

  // We need a way to store metadata about the user, preferences
  // etc. This should probably be added to this object, since it would 
  // have to be added for each and every protocol module
  // otherwise. That might be somewhat unessesary. The problem is the
  // API. Do we keep the data from different clients separated, or
  // should we rely on them using unique keys? 
  
  // My suggestion:
  local static string encode_binary( mixed what )
  {
    return sql_quote( MIME.encode_base64( encode_value( what ), 1 ) );
  }

  local static mixed decode_binary( string what )
  {
    return decode_value( MIME.decode_base64( what ) );
  }

  mixed get(string var)
  {
    array a=squery("select data from user_misc where "
		     "uid=%d and variable='%s'", id, var);
    if(sizeof(a))
      return decode_binary( a[0]->data );
  }

  mixed set(string name, mixed to)
  {
    modify();

    name = sql_quote( name );
    string enc= encode_binary( to );
    squery("delete from user_misc where uid=%d and  variable='%s'", id, name);
    squery("insert into user_misc values (%d,'%s','%s')",id,name,enc);
    return to;
  }

  array(Mailbox) mailboxes(int|void force)
  {
    if(!force && _mboxes)
      return _mboxes;
    
    mapping m = list_mailboxes(id);
    array a = values(m), b = indices(m);
    for(int i=0; i<sizeof(a); i++)
      a[i] = get_any_obj( a[i], Mailbox, this_object(), b[i] );
    return _mboxes = a;
  }

  Mailbox get_incoming()
  {
    return get_or_create_mailbox( "incoming" );
  }

  Mailbox get_drafts()
  {
    return get_or_create_mailbox( "drafts" );
  }

  Mailbox get_or_create_mailbox( string name )
  {
    foreach(mailboxes(), Mailbox m )
      if( lower_case(m->query_name()) == lower_case(name) ) 
	return m;
    return create_mailbox( name );
  }

  void create(int _id)
  {
    id = _id;
  }
}

User get_user( string username, string password )
{
  int id;
  id = authenticate_user( username, password );
  if(!id) return 0;
  return get_any_obj( id, User );
}

/* Low level client layer functions ---------------------------------- */

int authenticate_user(string username, string passwordcleartext)
{
  array a=squery("select password,id from users where username='%s'",username);
  if(!sizeof(a))
    return 0;
  return (int)(crypt(passwordcleartext,a[0]->password)?a[0]->id:0);
}

mapping(string:int) list_mailboxes(int user)
{
  array a=squery("select id,name from mailboxes where user_id='%d'",user);
  return mkmapping( column( a, "name" ), (array(int))column(a, "id" ) );
//   mapping mailboxes=([]);
//   foreach(a, mapping row)
//     mailboxes[row->name]=(int)row->id;
//   return mailboxes;
}

mapping(string:string) list_mail(int mailbox_id)
{
  // CHECKME: Is this correct?
  array a=squery("select m.id from mail as l, messages as m where "
		" l.mailbox_id='%d' and m.id=l.id order by m.id",
		 mailbox_id);
  return mkmapping(column( a, "l.id" ), column( a, "m.id" ));
//   array mail=({});
//   foreach(a, mapping row)
//     mail+=({ (int)row->id });
//   return mail;
}

mapping(string:mixed) get_mail(string message_id)
{
  array a;
//   array a=query("select message_id from mail where id='"+mail_id+"'");
//   if(!sizeof(a))
//     return 0;
  a=squery("select * from messages where id='%s'",message_id);
  if(!sizeof(a))
    return 0;
  return a[0];
//   mapping mail=a[0];
//   mail->body=load_body(mail->body_id);
//   return mail;
}

mapping(string:mixed) get_mail_headers(string message_id)
{
//   array a=query("select message_id from mail where id='"+message_id+"'");
//   if(!sizeof(a))
//     return 0;
  array a = squery("select * from messages where id='%s'",message_id);
  if(!sizeof(a))
    return 0;
  return a[0];
}

int update_message_refcount(string message_id, int deltacount)
{
  array a=squery("select refcount from messages where id='%s'",message_id);
  if(!a||!sizeof(a))
    return 0;
  int refcount=(int)a[0]->refcount + deltacount;
  if(refcount <= 0)
  {
    squery("delete from messages where id='%s'",message_id);
    delete_body(a[0]->body_id);
  }
  else
    squery("update messages set refcount='%d' where id=%s", 
	   refcount,message_id);
}

int delete_mail(string mail_id)
{
  array a=squery("select message_id from mail where id='%s'", mail_id);
  if(!sizeof(a))
    return 0;
  string message_id = a[0]->message_id;
  squery("delete from mail where id='%s'",mail_id);
  a=squery("select refcount,body_id from messages where id='%s'",message_id);
  werror("%O",a);
  if(!a||!sizeof(a))
    return 0;
  if(!update_message_refcount(message_id,-1))
    return 0;
  return 1;
}

int create_user_mailbox(int user, string mailbox)
{
  object key = lock->lock();
  sql_query("insert into mailboxes values(NULL,'"+user+"','"
	    + sql_quote(mailbox) + ")", 1);
  mixed id = get_sql()->master_sql->insert_id();
  destruct(key);
  return (int)id;
}

string create_message(mapping mess)
{
  object key = lock->lock();
  sql_query("insert into messages "+sql_insert_mapping( mess ));
  mixed id = get_sql()->master_sql->insert_id();
  destruct(key);
  return (string)id;
}

string get_mailbox_name(int mailbox_id)
{
  array a=squery("select name from mailboxes where id='%d'",mailbox_id);
  if(!sizeof(a)) return 0;
  return a[0]->name;
}

int delete_mailbox(int mailbox_id)
{
  squery("delete from mailboxes where id='%d'", mailbox_id);
  foreach(list_mail(mailbox_id), string mail_id)
    delete_mail(mail_id);
  return 1;
}

int rename_mailbox(int mailbox_id, string newname)
{
  squery("update mailboxes set name='%s' where id='%d'", newname, mailbox_id);
  return 1;
}

int remove_mailbox_from_mail(string message_id, int mailbox_id)
{
  squery("delete * from mail where mailbox_id='%d' and message_id='%s'",
	 mailbox_id, message_id);
  update_message_refcount( message_id, -1 );
}

int add_mailbox_to_mail(string message_id, int mailbox_id)
{
//   array a=query("select message_id from mail where id='"+mail_id+"'");
//   if(!sizeof(a))
//     return 0;
//   string message_id=a[0]->message_id;
  squery("insert into mail values(NULL,'%d','%s')",mailbox_id,message_id);
  if(!update_message_refcount(message_id,1))
    return 0;
  return 1;
}

void set_mail_flag(string mail_id, string flag)
{
  squery("insert into flags values('%s','%s')",mail_id,flag);
}

void delete_mail_flag(string mail_id, string flag)
{
  squery("delete from flags where mail_id='%s' and name='%s'",mail_id,flag);
}
  
multiset get_mail_flags(string mail_id)
{
  array a=squery("select name from flags where mail_id='%s'",mail_id);;
  if(!a) return (<>);
  multiset flags=(<>);
  foreach(a, mapping row)
    flags[row->name]=1;
  return flags;
}
