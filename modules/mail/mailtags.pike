/* Standard roxen module header -------------------------------- */
#include <module.h>
inherit "module";
constant cvs_version = "$Id: mailtags.pike,v 1.2 1998/09/01 01:23:32 per Exp $";
constant thread_sage = 1;


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
  int delete_mailbox(int mailbox_id);n
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



/* Globals ---------------------------------------------------------*/

static ClientLayer clientlayer;
static MIME.Message mymesg = MIME.Message();
static roxen.Configuration conf;
static int debug;

/* Roxen module glue ---------------------------------------------- */
/* These functions are arranged in calling order. ----------------- */

void create()
{
  defvar("debug", 0, "Debug", TYPE_FLAG, 
	 "If this flag is set, debugging output might be added for some tags. "
	 "Also, more sanity checks will be done");
}

array register_module()
{
  return ({ MODULE_PARSER, "Automail HTML client",
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

void start(int q, roxen.Configuration c)
{
  array err;
  if(c)
  {
    if( err = catch {
      require_module( "clientlayer" );
      conf = c;
      clientlayer = conf->get_providers( "automail_clientlayer" );
    })
      report_error("AutoMail HTML Client init failed!\n" + 
		   describe_backtrace( err ) );
    debug = query("debug");
    
    if(debug)
      report_notice("AutoMail HTML Client added to the '"+c->query_name()+
		    "' configuration.\n");
  }
}

/* Utility functions ---------------------------------------------- */

static string verify_ownership( int mailid, object id )
{
  // FIXME
  /*
    if()
    return "Not really, no";
   */
}

static mapping common_callers( string prefix )
{
  mapping tags = ([]);
  foreach(glob(prefix+"*",indices(this_object())), string s)
    tags[replace(s[strlen(prefix)..], "_", "-")] = this_object()[s];

  DEBUG(( "Tags for %s is %s\n",+prefix,implode_nicely(sort(indices(tags)))));
  return tags;
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

static string login(object id)
{
  int id;
  string force = ("<return code=304>"
		  "<header name=WWW-Authenticate "
                  "        value='realm=automail'>");

  if(zero_type(UID))
  {
    if(!id->realauth) return force;
    id = clientlayer->authenticate_user( @(id->realauth/":") );
    if(!id) return force;
    UID = id;
  }
}

static int num_unread(array from)
{
  int res;
  foreach(from, int f)
    if(!clientlayer->get_flags( f )->read)
      res++;
  return res;
}

static int verify_mailbox( int mbox, object id )
{
  return zero_type(search( clientlayer->list_mailboxes( UID ), mbox ));
}


/* Tag functions --------------------------------------------------- */

// <delete-mail mail=id [force]>
//   Force is rather dangerous, since it might leave dangling references 
//   to the mail.

string tag_delete_mail(string tag, mapping args, object id)
{
  string res;
  if(res = login(id))
    return res;

  if(res = verify_ownership( (int)args->mail, id ))
    return res;

  clientlayer->delete_mail( (int)args->mail );
  return "";
}

// <mail-body mail=id>
string tag_mail_body(string tag, mapping args, object id)
{
  string res;
  if(res = login(id))
    return res;

  if(res = verify_ownership( (int)args->mail, id ))
    return res;

  return clientlayer->load_body( args->mail );
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
  
  mapping mboxes = clientlayer->list_mailboxes( UID );
  array(mapping) vars = ({});
  foreach(sort(indices(mboxes)), string s)
  {
    vars += ({ ([
      "name":s,
      "id":mboxes[id],
    ]) });
  }
  if(!args->quick)
  {
    foreach(vars, mapping v)
    {
      array (int) mails = clientlayer->list_mails( v->id );
      v->mails = sizeof(mails);
      v->unread = num_unread( mails );
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
  if(res = login(id))
    return res;

  if(verify_mailbox( (int)args->mailbox, id )) 
    return "Invalid mailbox id";
  
  array (int) mails = clientlayer->list_mails( (int)args->mailbox );

  array variables = ({ });
  foreach(mails, int m)
    variables += 
    ({ 
      parse_headers( clientlayer->get_mail_headers( m ) )
      | make_flagmapping( clientlayer->get_flags( m ) )
    });
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

/* <get-mail mail=id>
 *  #subject# #from# #body# etc.
 * </get-mail>
 * NOTE: Body contains the headers. See <mail-body-parts>
 */
string container_get_mail( string tag, mapping args, string contents, 
			   object id )
{
  string res;
  if(res = login(id))
    return res;
  
  if(res = verify_ownership( (int)args->mail, id ))
    return res;

  mapping vars = 
    (parse_headers(clientlayer->get_mail_headers((int)args->mail))|
     make_flagmapping(clientlayer->get_flags( m ))|
     ([ "body":tag_mail_body( tag, args, id ) ]));

  return do_output_tag( args, ({vars}), contents, id );
}
