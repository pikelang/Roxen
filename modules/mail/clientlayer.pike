/*
 * $Id: clientlayer.pike,v 1.14 1998/09/12 20:44:21 per Exp $
 *
 * A module for Roxen AutoMail, which provides functions for
 * clients.
 *
 * Johan Schön, August 1998
 */

#include <module.h>
inherit "module" : module;

constant cvs_version="$Id: clientlayer.pike,v 1.14 1998/09/12 20:44:21 per Exp $";
constant thread_safe=1;





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




/* Global variables -------------------------------------------------- */

object sql = thread_local();
Thread.Mutex lock = Thread.Mutex();
mapping (program:mapping(int:object)) object_cache = ([]);






/* (local) Utility functions   ---------------------------------------- */

string encode_binary( mixed what )
{
  return sql_quote( MIME.encode_base64( encode_value( what ), 1 ) );
}

mixed decode_binary( string what )
{
  return decode_value( MIME.decode_base64( what ) );
}

mapping filter_headers( mapping from ) 
{
  mapping res = ([]);
  if(from->subject) res->subject = from->subject;
  if(from->from) res->from = from->from;
  if(from->to) res->to = from->to;
  if(from->date) res->date = from->date;
//   werror("Filtered headers are %O\n", res);
  return res;
}

string encode_headers( mapping from )
{
  string res="";
  foreach(indices(from), string f)
    res += f+": "+from[f]+"\n";
  return res;
}

string read_headers_from_fd( Stdio.File fd )
{
  fd->seek( 0 );
  string q = "", w;
  int pos;
  do {
    w = fd->read(1024);
    q+=w;
  } while(strlen(w)
	  && ((pos=search(q, "\r\n\r\n"))==-1)
	  && ((pos=search(q, "\n\n"))==-1));

  return q[..pos-1];
}

Sql.sql get_sql()
{
  return sql->get() || sql->set(Sql.sql(query("db_location")));
}

array(mapping(string:string)) squery(string fmt, mixed ... args)
{
  return get_sql()->query( sprintf(fmt, @args) );
}

string sql_insert_mapping(mapping m)
{
  string pre="",post="";
  foreach(indices(m), string q)
  {
    pre += q+",";
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

string hash_body_id(string body_id)
{
  body_id="0000"+body_id;
  int p=sizeof(body_id)-4;
  return body_id[p..p+1]+"/"+body_id[p+2..p+3];
}

Stdio.File load_body_get_obj(string body_id)
{
  Stdio.File o = Stdio.File();
  if(o->open( query("maildir")+"/"+hash_body_id(body_id)+"/"+body_id,"r" ))
    return o;
  return 0;
}

string get_unique_body_id()
{
  string id;
  object key = lock->lock(); /* Do this transaction locked. */
  squery("update message_body_id set last=last+1");
  id=squery("select last from message_body_id where 1=1")[0]->last;
  destruct(key);
  return id;
}

void delete_body(string body_id)
{
  rm(query("maildir")+"/"+hash_body_id(body_id)+"/"+body_id);
}

object(Stdio.File) new_body( string body_id )
{
  string f = query("maildir")+"/"+hash_body_id(body_id)+"/"+body_id;
  werror("Path: %s",f);
  mkdirhier(f);
  return Stdio.File(f, "rwct");
}





/* Client Layer Abstraction ---------------------------------------- */

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
  string|int id;
  static int serial;
  final int get_serial()
  {
    return serial;
  }

  int modify()
  {
    serial++;
  }

  static mapping cached_misc = ([]);
  final static mixed misc_get(string table, string var)
  {
    if(!zero_type(cached_misc[var])) return cached_misc[var];
    array(mapping) a;
    a=squery("select qwerty from %s where id=%s and variable='%s'", 
	     table, (string)id, var);
    if(sizeof(a))
      return cached_misc[var]=decode_binary( a[0]->data );
    return cached_misc[var]=0;
  }

  final static mixed misc_set(string table, string name, mixed to)
  {
    modify();
    name = sql_quote( name );
    string enc = encode_binary( to );
    squery("delete from %s where id=%s and variable='%s'", table, 
	   (string)id, name);
    squery("insert into %s values (%s,'%s','%s')", table, 
	   (string)id, name, enc);
    return cached_misc[name]=to;
  }
}

class Mail
{
  inherit Common;
  inherit MIME.Message;
  string message_id;
  object user;
  object mailbox;

  static mapping _headers;
  static multiset _flags;


  mixed get(string var)
  {
    return misc_get("mail_misc", var);
  }

  mixed set(string name, mixed to)
  {
    return misc_set("mail_misc", name, to);
  }

  Stdio.File body_fd()
  {
    return load_body_get_obj( headers()->body_id );
  }

  string body()
  {
    return body_fd()->read();
  }

  mapping decoded_headers(int|void force)
  {
    mapping heads = copy_value(headers(force));
    foreach(indices(heads), string w)
      heads[w] = column(Array.map( heads[w]/" ", MIME.decode_word ),0)*" ";
    return heads;
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
    return _flags;
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
    id = (string)i;
    message_id = (string)m;
    user = mb->user;
    mailbox = mb;
  }
}

class Mailbox
{
  inherit MIME.Message;
  inherit Common;
  static array _mail = 0;

  object user;
  string name;

  void remove_mail(Mail mail)
  {
    if(search(mail()->message_id, mail->message_id) != -1)
    {
      _mail = 0; // No optimization, for safety...
      destruct( mail );
      modify( );
      remove_mailbox_from_mail( mail->message_id, id );
    }
  }

  Mail add_mail(Mail mail, int|void nocopy)
  {
    if(search(mail()->message_id, mail->message_id) == -1)
    {
      _mail = 0;
      modify();
      add_mailbox_to_mail( mail->message_id, id );
      foreach(mail(), Mail m)
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
    foreach(mail, object m)
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

  array(Mail) mail(int|void force)
  {
    if(!force && _mail)
      return _mail;
    mapping q = list_mail( id );
    _mail = ({ });
//     werror("mail=%O\n", q);
    foreach(indices(q), string w)
      _mail += ({ get_any_obj( (string)w, Mail, 
			       (string)q[w], this_object()) });
    
    sort((array(int))_mail->message_id, _mail);

    return _mail;
  }


  Mail low_create_mail( string bodyid, mapping headers )
  {
    /* This could be easier.. :-) */
    // 1> Generate the db row for the 'messages' table.
    mapping row = ([
      "sender":headers->from,
      "subject":headers->subject,
      "body_id":bodyid,
      "headers":encode_headers(filter_headers(headers)),
    ]);

    // 2> Insert the row in the database, and get a new message id.
    string mid = create_message( row );
    
    // 3> Insert the message in this mailbox using the 'mail' table.
    add_mailbox_to_mail( mid, id );
    
    // 4> Zap the cache.
    _mail = 0;
    modify();

    // 5> Find this new message in the mail() array.
    foreach(mail(), Mail m)
      if((string)m->message_id == (string)mid)
	return m;

    // Oups. This should not happend. :-)
    error(sprintf("Failed to find newly created message (%s) in "
		  "array (%s) for mbox %s!\n", mid, 
		  String.implode_nicely((array(string))mail()->message_id),
		  (string)id));
  }

  Mail create_mail_from_fd( Stdio.File fd )
  {
    string foo = read_headers_from_fd( fd );
    mapping headers = parse_headers( foo )[0];
//     werror("Parsed headers are %O\n", headers);
    string bodyid = get_unique_body_id();
    fd->seek( 0 );
    Stdio.File f = new_body( bodyid );
    do 
    {
      foo = fd->read( 8192 );
      if( f->write( foo ) != strlen(foo) )
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

  static Mailbox create_mailbox( string name )
  {
    _mboxes = 0;
    modify();
    return Mailbox( create_user_mailbox( id, name ), this_object(), name );
  }

  mixed get(string var)
  {
    return misc_get("user_misc", var);
  }

  mixed set(string name, mixed to)
  {
    return misc_set("user_misc", name, to);
  }

  string query_name(int|void force)
  {
    return 0;
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

User get_user( string username_at_host, string password )
{
  int id;
  id = authenticate_user( username_at_host, password );
  if(!id) return 0;
  return get_any_obj( id, User );
}

User get_user_from_address( string username_at_host )
{
  int id;
  id = find_user( username_at_host );
  if(!id) return 0;
  return get_any_obj( id, User );
}






/* Low level client layer functions ---------------------------------- */


string get_addr(string addr)
{
  array a = MIME.tokenize(addr);

  int i;

  if ((i = search(a, '<')) != -1) {
    int j = search(a, '>', i);

    if (j != -1) {
      a = a[i+1..j-1];
    } else {
      // Mismatch, no '>'.
      a = a[i+1..];
    }
  }

  for(i = 0; i < sizeof(a); i++) {
    if (intp(a[i])) {
      if (a[i] == '@') {
	a[i] = "@";
      } else {
	a[i] = "";
      }
    }
  }
  return(a*"");
}

multiset(string) list_domains()
{
  return aggregate_multiset(@squery("select distinct domain from dns")->domain);
}

string get_user_realname(int user_id)
{
  array a = squery("select realname from users where user_id='%d'",
		   user_id);
  if(!sizeof(a))
    return 0;
  else
    return a[0]->realname;
}

int find_user( string username_at_host )
{
  catch {
    [string user, string domain]=get_addr(lower_case(username_at_host))/"@";
    int customer_id;
    array a = squery("select customer_id from dns where domain='%s' "
		     " group by customer_id", domain);
    if(!sizeof(a)) return 0;
    customer_id=(int)a[0]->customer_id;
    array a = squery("select id from users where username='%s' and"
		     " customer_id='%d'", user,customer_id);
    if(!sizeof(a)) return 0;
    if(sizeof(a)>1) error("Ambigious user list.\n");
    return (int)a[0]->id;
  };
}

int authenticate_user(string username_at_host, string passwordcleartext)
{
  int id = find_user( username_at_host );
  if(!id) return 0;
  array a=squery("select password from users where id='%d'", id);
//   if(!sizeof(a))
//     return 0;
//   return (passwordcleartext == a[0]->password) && id;
  return crypt(passwordcleartext, a[0]->password) && id;
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
  array a=squery("select m.id as m,l.id as l from mail as l, messages as m"
		 " where l.mailbox_id='%d' and m.id=l.message_id"
		 " order by m.id",
		 mailbox_id);
  return mkmapping(column( a, "l" ), column( a, "m" ));
}

mapping(string:mixed) get_mail(string message_id)
{
  return get_mail_headers( message_id );
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
  squery("insert into mailboxes values(NULL,'%d','%s')",
	 user,sql_quote(mailbox));
  return (int)get_sql()->master_sql->insert_id();
}

string create_message(mapping mess)
{
  werror(sql_insert_mapping( mess ));
  get_sql()->query("insert into messages "+sql_insert_mapping( mess ));
  return (string)get_sql()->master_sql->insert_id();
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
