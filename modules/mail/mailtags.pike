/* This is -*- pike -*- code */
/* Standard roxen module header -------------------------------- */

#include <module.h>
inherit "module";
constant cvs_version = 
"$Id: mailtags.pike,v 1.3 1998/09/01 03:09:20 per Exp $";

constant thread_safe = 1;


/* Some defines to cheer up our day ---------------------------- */

#define UID id->misc->_automail_user

#ifdef DEBUG
# undef DEBUG
#endif

#ifdef MODULE_DEBUG
# define DEBUG(X) if(debug) werror X ;
#else
# define DEBUG(X) 
#endif

/* Prototypes ----------------------------------------------------- */

class  ClientLayer 
{
  int authentificate_user(string username, string passwordcleartext);

  int create_mailbox(int user, string mailbox);
  int delete_mailbox(int mailbox_id);
  int rename_mailbox(int mailbox_id, string newmailbox);
  string get_mailbox_name(int mailbox_id);
  mapping(string:int) list_mailboxes(int user);

  int add_mailbox_to_mail(int mail_id, int mailbox_id);

  mapping(string:mixed) get_mail(int mail_id);
  mapping(string:mixed) get_mail_headers(int message_id);
  int delete_mail(int mail_id);
  array(int) list_mail(int mailbox_id);

  void set_flag(int mail_id, string flag);
  void delete_flag(int mail_id, string flag);
  multiset get_flags(int mail_id);
}


/* Client layer wrapper layer ------------------------------------- */

static mapping (program:mapping(int:object)) object_cache = ([]);

object get_cache_obj( program type, int id )
{
  if(!object_cache[ type ])
    return 0;
  if(object_cache[ type ][ id ])
    return object_cache[ type ][ id ];
}

object get_any_obj(int id, program type, mixed ... moreargs)
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

class Mail
{
  int id;
  object user;
  array(object) _mboxes;
  string name;

  static mapping _headers;
  static multiset _flags;

  string body()
  {
    if(!_headers)headers();
    return clientlayer->load_body( (int)_headers->body_id );
  }

  mapping headers(int force)
  {
    mapping h = clientlayer->get_mail_headers( id );
    if(!_headers || force)
      return _headers = parse_headers(h[ HEAD_CID ]) | h;
    return _headers;
  }

  multiset flags(int force)
  {
    if(!_flags || force)
      return _flags = clientlayer->get_flags( id );
  }

  void set_flag(string name)
  {
    _flags = 0;
    clientlayer->set_flag( id, name );
  }

  void clear_flag(string name)
  {
    _flags = 0;
    clientlayer->delete_flag( id, name );
  }



  void create(int i, object m)
  {
    id = i;
    if(_mboxes)
      _mboxes |= ({ m });
    else
      _mboxes = ({ m });
    user = m->user;
  }
}

class Mailbox
{
  int id;
  object user;
  string name;

  int rename(string to)
  {
    name=0;
    clientlayer->rename_mailbox( id, to );
  }
  
  void delete()
  {
    clientlayer->delete_mailbox( id );
    destruct(this_object());
  }
  
  string query_name(int force)
  {
    if(force) name=0;
    return name||(name=clientlayer->get_mailbox_name( id ));
  }

  array(Mail) mails()
  {
    return Array.map(clientlayer->list_mail( id ), get_any_obj, 
		     Mail, this_object());
  }



  void create(int i, object u, string n)
  {
    id = i;
    user = u;
    name = n;
  }
}

class User
{
  int id;

  string cast(string to)
  {
    if(to != "int") 
      error("Cannot cast to "+to+"\n");
    return (string)id;
  }

  array(Mailbox) mailboxes()
  {
    mapping m = clientlayer->list_mailboxes(id);
    array a = values(m), b = indices(m);
    for(int i=0; i<sizeof(f); i++)
      a[i] = get_any_obj( a[i], Mailbox, this_object(), b[i] );
    return a;
  }

  Mailbox create_mailbox( string name )
  {
    return Mailbox( clientlayer->create_mailbox( id, name ), 
		    get_any_obj, Mailbox, this_object(), name );
  }



  void create(int _id)
  {
p    id = _id;
  }
}


/* Globals ---------------------------------------------------------*/

static ClientLayer clientlayer;
static MIME.Message mymesg = MIME.Message();
static roxen.Configuration conf;
static int debug, secure;

/* Roxen module glue ---------------------------------------------- */
/* These functions are arranged in calling order. ----------------- */

void create()
{
  defvar("debug", 0, "Debug", TYPE_FLAG, 
	 "If this flag is set, debugging output might be added for some tags. "
	 "Also, more sanity checks will be done");

  defvar("security_level", "high", "Security level", TYPE_STRING_LIST|VAR_MORE,
	 "The level of security verification to do.<p>"
	 "high:  All checks. It should be impossible to read mails"
	 " that is not yours, same goes for list of mails etc.<p>"
	 "mails: Only the ownership of mails will be checked.<p>"
	 "low: Only checks that will not generate extra CVS queries"
	 " will be done. This saves CPU, but the cost is high. A smart and"
	 " resourcefull user could read all mails.",
	 ({ "high", "mails", "low"}));
}

array register_module()
{
  return ({ MODULE_PARSER|MODULE_PROVIDER, "Automail HTML client",
	    "This module adds quite a few new tags for Automail email "
	    "handling. This module talks to the AutoMail client layer module",
	    0,1 });
}

void query_tag_callers()
{
  return common_callers(  "tag_" );
}

void query_container_callers()
{
  return common_callers(  "container_" );
}

string query_provides()
{
  return "automail_htmlmail";
}


void start(int q, roxen.Configuration c)
{
  array err;
  if(!c)
    return;

  if( err = catch {
    module_dependencies( c, ({ "clientlayer" }) );
    clientlayer = conf->get_providers( "automail_clientlayer" )[ 0 ];
  })
    report_error("AutoMail HTML Client init failed!\n" + 
		 describe_backtrace( err ) );
  debug = query("debug");
  
  if(debug)
    report_notice("AutoMail HTML Client added to the '"+c->query_name()+
		  "' configuration.\n");
  if(query("security_level") == "high")
    secure=2;
  else if(query("security_level") == "mails")
    secure=1;
  else
    secure=0;
}

/* Utility functions ---------------------------------------------- */

static mapping common_callers( string prefix )
{
  mapping tags = ([]);
  foreach(glob(prefix+"*",indices(this_object())), string s)
    tags[replace(s[strlen(prefix)..], "_", "-")] = this_object()[s];

  DEBUG(( "Tags for %s is %s\n",+prefix,implode_nicely(sort(indices(tags)))));
  return tags;
}

static string verify_ownership( Mail mailid, object id )
{
  // FIXME!
  if(!secure) return 0;
}

static int num_unread(array(Mail) from)
{
  int res;
  foreach(from, Mail m)
    if(!m->flags()->read)
      res++;
  return res;
}

static mapping parse_headers( string foo )
{
  return mymesg->parse_headers( foo )[0];
}

static mapping make_flagmapping(multiset from)
{
  return mkmapping( Array.map(indices(from), lambda(string s) {
					       return "flag_"+s;
					     }),
		    ({"set"})*sizeof(from));
}


string login(object id)
{
  int id;
  string force = ("<return code=304>"
		  "<header name=WWW-Authenticate "
                  "        value='realm=e-mail'>");

  if(!UID)
  {
    if(!id->realauth) return force;
    id = clientlayer->authenticate_user( @(id->realauth/":") );
    if(!id) return force;
    UID = User( id );
  }
}


/* Tag functions --------------------------------------------------- */

// <delete-mail mail=id>
// Please note that this function only removes a reference from the
// mail, if it is referenced by e.g. other clients, or is present in
// more than one mailbox, the mail will not be deleted.

string tag_delete_mail(string tag, mapping args, object id)
{
  string res;
  Mail mid = get_cache_obj( Mail, (int)args->mail );
  if(res = login(id))
    return res;
  if(mail && mail->user == UID )
    mid->delete();
}

// <mail-body mail=id>
string tag_mail_body(string tag, mapping args, object id)
{
  string res;
  if(res = login(id))
    return res;

  Mail mail = get_cache_obj( Mail, (int)args->mail );
  if(res = login(id))
    return res;
  if(mail && mail->user == UID )
    return mail->body( );
}

// <list-mailboxes>
//  #name# #id# #unread# #read# #mail#
// </list-mailboxes>
string container_list_mailboxes(string tag, mapping args, string contents, 
				object id)
{
  string res;
  if(res = login(id))
    return res;

  
  array(mapping) vars = ({});
  foreach(UID->mailboxes(), Mailbox m)
    vars += ({ ([
      "_mb":m,
      "name":m->name,
      "id":m->id,
    ]) });

  if(!args->quick)
  {
    foreach(vars, mapping v)
    {
      v->mails = sizeof(v->_mb->mails());
      v->unread = num_unread( v->_mb->mails() );
      v->read = v->mails - v->unread;
    }
  }
  return do_output_tag( args, vars, contents, id );
}

// <list-mails mailbox=id>
//  #subject# #from# etc.
// </list-mails>
string container_list_mails( string tag, mapping args, string contents, 
			     object id )
{
  string res;
  Mailbox mbox;
  if(res = login(id))
    return res;

  foreach( UID->mailboxes(), Mailbox m )
    if(m->id == (int)args->mailbox )
    {
      mbox = m;
      break;
    }

  if(!mbox)
    return "Invalid mailbox id";
  
  array variables = ({ });
  foreach(mbox->mails(), Mail m)
    variables += ({ m->headers() | make_flagmapping( m->flags() ) });
  return do_output_tag( args, variables, contents, id );
}


// <mail-body-part mail=id part=num>
//
// Part 0 is the non-multipart part of the mail.
// If part > the available number of parts, part 0 is returned.
string tag_mail_body_part( string tag, mapping args, object id )
{
  MIME.Message m = MIME.Message( tag_mail_body( tag, args, id ) );
  int part = (int)args->part;
  if(!part) return msg->getdata();
  if( msg->body_parts && sizeof(msg->body_parts) > part )
    return msg->body_parts[ part ]->getdata();
  return msg->getdata();
}

// <mail-body-parts mail=id
//             binary-part-url=URL
//	            (default not_query?mail=#mail#&part=#part#)
//             image-part-format='...#url#...'
//                  (default <a href='#url#'><img src='#url#'>
//                           <br>#name# (#type#)<br></a>)
//             binary-part-format='...#url#...'
//                  (default <a href='#url#'>Binary data #name# (#type#)</a>)
//             html-part-format='...#data#...'
//                  (default <table><tr><td>#data#</td></tr></table>)
//             text-part-format='...#data#...'>
//                  (default <pre>#data#</pre>)
//    full mime-data
// </mail-body-parts>
string container_mail_body_parts( string tag, mapping args, string contents, 
			     object id)
{
  MIME.Message msg = MIME.Message( contents );

  string html_part_format = (args["html-part-format"] || 
			     "<table><tr><td>#data#</td></tr></table>");

  string text_part_format = (args["text-part-format"] || 
			     "<pre>#data#</pre>");

  string binary_part_format = (args["binary-part-format"] || 
			     "<a href='#url#'>Binary data #name# (#type#)"
			       "</a>");

  string image_part_format = (args["image-part-format"] || 
			     "<a href='#url#'><img border=0 src='#url#'>"
			      "<br>#name# (#type#)<br></a>");

  string binary_part_url = (fix_relative(args["binary-part-url"],id) ||
			    id->not_query+"?mail=#mail#&part=#part#");

  string res="";

  if(msg->body_parts)
  {
    int i;
    foreach(msg->body_parts, object msg)
    {
      if(msg->type == "text")
      {
	if(msg->subtype == "html")
	  res += replace( html_part_format, "#data#", msg->getdata() );
	else
	  res += replace( text_part_format, "#data#", 
			  html_encode_string(msg->getdata()) );
      } else {
	string format;
	if(msg->type == "image") 
	  format = image_part_format;
	else
	  format = binary_part_format;

	mapping q = ([ "#url#":replace(binary_part_url,
				     ({"#mail#", "#part#" }),
				     ({ args->mail, (string)i })),
		       "#name#":html_encode_string(msg->get_filename())||i,
		       "#type#":html_encode_string(msg->type+"/"+msg->subtype),
	]);
	res += replace( format, indices(q), values(q) );
      }
      i++;
    }
  } else
    if(msg->type == "text")
    {
      if(msg->subtype == "html")
	res += replace( html_part_format, "#data#", msg->getdata() );
      else
	res += replace( text_part_format, "#data#", 
			html_encode_string(msg->getdata()) );
    } else {
      string format;
      if(msg->type == "image") 
	format = image_part_format;
      else
	nformat = binary_part_format;
      
      mapping q = ([ "#url#":replace(binary_part_url,
				     ({"#mail#", "#part#" }),
				     ({ args->mail, "0" })),
		     "#name#":html_encode_string(msg->get_filename())||"0.a",
		     "#type#":html_encode_string( msg->type+"/"+msg->subtype ),
      ]);
      res += replace( format, indices(q), values(q) );
    }

  return res;
}

// <get-mail mail=id>
//   #subject# #from# #body# etc.
// </get-mail>
// NOTE: Body contains the headers. See <mail-body-parts>
string container_get_mail( string tag, mapping args, 
			   string contents, object id )
{
  string res;
  Mail mid = get_cache_obj( Mail, (int)args->mail );

  if(res = login(id))
    return res;

  if(mid && mid->user == UID)
    return do_output_tag( args,({(mid->headers()
				  |make_flagmapping(mid->flags())
				  |([ "body":mid->body() ])
				  |args)}),
			  contents, id );
  return "Permission denied.";
}
