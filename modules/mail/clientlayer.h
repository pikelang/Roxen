// -*- pike -*-

class Common
{
  int get_serial();
}

class Mail
{
  inherit Common;
  object mailbox;
  object user;
  string body();
  Stdio.File body_fd();
  mapping decoded_headers(int force);
  mapping headers(int force);
  multiset flags(int force);
  void set_flag(string name);
  void clear_flag(string name);
  mixed set(string name, mixed to);
  mixed get(string name);
}

class Mailbox
{
  inherit Common;
  object user;
  int rename(string to);
  void delete();
  string query_name(int force);

  int num_unread();

  array(Mail) mail();
  Mail add_mail(Mail m, int|void do_not_copy_the_flags);
  void remove_mail(Mail m);

  Mail low_create_mail( string bodyid, mapping headers );
  Mail create_mail_from_fd( Stdio.File from );
  Mail create_mail_from_data( string from );
  Mail create_mail( MIME.Message from );
}

class User
{
  inherit Common;
  array(Mailbox) mailboxes();
  mixed set( string name, mixed to );
  mixed get( string name );
  Mailbox get_or_create_mailbox( string name );
  Mailbox get_incoming();
  Mailbox get_drafts();
}

class ClientLayer
{
  User get_user( string username, string password );
  User get_user_from_address( string adress );

  object get_cache_obj( program type, int id );

  /* low level functions */
  int authenticate_user(string username, string passwordcleartext);
  int find_user( string username_at_host );
  mapping(string:int)    list_mailboxes(int user);
  mapping(string:string) list_mail(int mailbox_id);
  mapping(string:mixed)  get_mail_headers(string message_id);
  int    update_message_refcount(string message_id, int deltacount);
  int    delete_mail(string mail_id);
  int    create_user_mailbox(int user, string mailbox);
  string create_message(mapping mess);
  string get_mailbox_name(int mailbox_id);
  int    delete_mailbox(int mailbox_id);
  int    rename_mailbox(int mailbox_id, string newname);
  int    remove_mailbox_from_mail(string message_id, int mailbox_id);
  int    add_mailbox_to_mail(string message_id, int mailbox_id);
  void   set_mail_flag(string mail_id, string flag);
  void   delete_mail_flag(string mail_id, string flag);
  multiset get_mail_flags(string mail_id);
}

#ifdef WANT_CLIENTINIT
  static local ClientLayer clientlayer;

  int init_clientlayer( roxen.Configuration c )
  {
    array err;
    if( err = catch {
      module_dependencies( c, ({ "clientlayer" }) );
      clientlayer = c->get_providers( "automail_clientlayer" )[ 0 ];
    })
    {
      report_error("While getting clientlayer: "+ 
		   describe_backtrace(err));
      return 0;
    }
    if(clientlayer) 
      return 1;
  }
#endif
