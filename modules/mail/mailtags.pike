/* This is -*- pike -*- code */
/* Standard roxen module header -------------------------------- */
#include <module.h>
inherit "module";
inherit "roxenlib";
inherit Regexp : regexp;

constant cvs_version = 
"$Id: mailtags.pike,v 1.10 1998/09/12 20:44:53 per Exp $";

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
#define WANT_CLIENTINIT
#include "clientlayer.h"


/* Globals ---------------------------------------------------------*/

static MIME.Message mymesg = MIME.Message();
static roxen.Configuration conf;
static int debug, secure;

/* Roxen module glue ---------------------------------------------- */
/* These functions are arranged in calling order. ----------------- */

void create()
{
  defvar("debug", 0, "Debug", TYPE_FLAG, 
	 "If this flag is set, debugging output might be added for some"
	 " tags. Also, more sanity checks will be done");

  defvar("security_level", "high", "Security level", 
	 TYPE_STRING_LIST|VAR_MORE,
	 "The level of security verification to do.<p>"
	 "high:  All checks. It should be impossible to read mail"
	 " that is not yours, same goes for list of mail etc.<p>"
	 "mail: Only the ownership of mail will be checked.<p>"
	 "low: Only checks that will not generate extra CVS queries"
	 " will be done. This saves CPU, but the cost is high. A smart and"
	 " resourcefull user could read all mail.",
	 ({ "high", "mail", "low"}));

  regexp::create("^(.*)((http://|https://|ftp:/|news:|wais://|//|mailto:|telnet:)[^ \n\t\012\014\"<>|\\\\]*[^ \n\t\012\014\"<>|\\\\.,(){}?'`*])");

}

array register_module()
{
  return ({ MODULE_PARSER|MODULE_PROVIDER, "Automail HTML client",
	    "This module adds quite a few new tags for Automail email "
	    "handling. This module talks to the AutoMail client layer module",
	    0,1 });
}

mapping query_tag_callers()
{
  return common_callers(  "tag_" );
}

mapping query_container_callers()
{
  return common_callers(  "container_" );
}

string query_provides()
{
  return "automail_htmlmail";
}


void start(int q, roxen.Configuration c)
{
  if(!c)
  {
    report_debug("start called without configuration\n");
    return;
  }  
  conf = c;
  report_notice("AutoMail HTML Client added to the '"+c->query_name()+
		"' configuration.\n");

  if(!init_clientlayer( c ))
    report_error("AutoMail HTML Client init failed!\n");

  debug = query("debug");
  
  if(query("security_level") == "high")
    secure=2;
  else if(query("security_level") == "mail")
    secure=1;
  else
    secure=0;
}

/* Utility functions ---------------------------------------------- */

string fix_urls(string s)
{
  string *foo;
  if(foo=regexp::split(s))
  {
    string url;
    
    return fix_urls(foo[0])+
      "<a href=\""+foo[1]+"\">"+foo[1]+"</a>"+
      fix_urls(s[strlen(foo[0])+strlen(foo[1])..0x7fffffff]);
  }
  return s;
}


inline string qte(string what)
{
  return fix_urls(replace(what, ({ "<", ">", "&", }),
			  ({ "&lt;", "&gt;", "&amp;" })));
}

string describe_body(string bdy, mapping m)
{
  int br;
  array (string) res=({"<table><tr><td>"});
  if(!m->freeform) res += ({ "<pre>" });
  else br = 1;

  string line;
  int quote, lq;
  foreach(bdy/"\n", line)
  {
    quote = 0;
    if(strlen(line) && line[0]=='>')
      quote=1;
    else
      quote=0;

    if(!strlen(line))
    {
      if(br) res +=({"<br>"});
      res += ({ "\n" });
      continue;
    }
    if(lq < quote)
    {
      res += ({ "<dl><dt><font color=darkred size=-1><i>" });
    } else if(lq > quote) {
      res += ({ "</i></font></dl>" });
    }
    lq=quote;
    if(line=="-- ") res+= ({"<font color=darkgreen>"});
    res += ({ qte(line)+"\n" });
    if(br) res +=({"<br>"});
  }
  if(!br) res+=({"</pre>"});
  res += ({ "</td></tr></table>" });
  return res*"";
}

string highlight_mail(string from, object id)
{
  return describe_body( from, id->variables );
}

static mapping common_callers( string prefix )
{
  mapping tags = ([]);
  foreach(glob(prefix+"*",indices(this_object())), string s)
  {
    if(!debug && search( s, "debug") != -1)
      continue;
    tags[replace(s[strlen(prefix)..], "_", "-")] = this_object()[s];
  }

  DEBUG(( "Tags for %s is %s\n",prefix,
	  String.implode_nicely(sort(indices(tags)))));
  return tags;
}

static string verify_ownership( Mail mailid, object id )
{
  if(!secure) return 0;
  if(mailid->user != UID) 
  {
    id->realauth = 0;
    return login( id );
  }
}

static int num_unread(array(Mail) from)
{
//   int res;
//   werror("%O\n", from->flags());
  return sizeof(from->flags()->read-({1}));
//   foreach(from, Mail m)
//     if(!m->flags()->read)
//       res++;
//   return res;
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

mapping _login = http_auth_required( "E-Mail" );

string login(object id)
{
  string force = ("Permission denied");

  if(!clientlayer) 
    init_clientlayer( conf );
  if(!clientlayer)
    return "Internal server error";

  if(!id->realauth) 
  {
    id->misc->defines[" _extra_heads"] = _login->extra_heads;
    id->misc->defines[" _error"] = _login->error;
    return force;
  }

  if(!UID)
  {
    UID = clientlayer->get_user(  @(id->realauth/":") );
    if(!UID) 
    {
      id->misc->defines[" _extra_heads"] = _login->extra_heads;
      id->misc->defines[" _error"] = _login->error;
      return force;
    }
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
  Mail mid = clientlayer->get_cache_obj( clientlayer->Mail, args->mail );
  if(res = login(id))
    return res;
  if(mid && mid->user == UID )
    mid->mailbox->remove_mail( mid );
}

// <mail-body mail=id>
string tag_mail_body(string tag, mapping args, object id)
{
  string res;
  if(res = login(id))
    return res;

  Mail mail = clientlayer->get_cache_obj( clientlayer->Mail, args->mail );
  if(res = login(id))
    return res;
  if(mail && mail->user == UID )
    return mail->body( );
}

// <mail-verify-login>
//  .. page ...
// </mail-verify-login>

string container_mail_verify_login(string tag, mapping args, 
				   string contents, object id)
{
  string q = login(id);
  if(q) return q;
  return contents;
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

  UID->get_incoming();
  UID->get_drafts();

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
      v->mail = (string)sizeof(v->_mb->mail());
      v->unread = (string)num_unread( v->_mb->mail() );
      v->read = (string)((int)v->mail - (int)v->unread);
    }
  }
  return do_output_tag( args, vars, contents, id );
}

// <list-mail mailbox=id>
//  #subject# #from# etc.
// </list-mail>
string container_list_mail( string tag, mapping args, string contents, 
			     object id )
{
  string res;
  Mailbox mbox;

  int start = (int)args->start;
  int num = (int)args->num;

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
  array m = mbox->mail();
  if(start < 0)
    start = sizeof(m)+start;
  foreach(m[start-1..start+num], Mail m)
    variables += ({ (["id":m->id]) |
		    m->decoded_headers()   | 
		    make_flagmapping( m->flags() ) });
  return do_output_tag( args, variables, contents, id );
}

string container_mail_a( string tag, mapping args, string c, object id )
{
  mapping q= copy_value(id->variables);
  q |= args;
  q->i = (string)time() + (string)gethrtime();
  m_delete(id->variables, "fg");   m_delete(id->variables, "bg");
  m_delete(id->variables, "font"); m_delete(id->variables, "link");
  string link="?";
  
  foreach(sort(indices(q)), string v)
    if(q[v] != "0")
      link += v+"="+http_encode_url( q[v] )+"&";
  q = ([ "href":fix_relative(link[ .. strlen(link)-2 ], id) ]);
  return make_container("a", q, c );
}

string tag_amail_user_variable( string tag, mapping args, object id )
{
  mixed res;
  if(res = login(id))
    return res;
  if( args->set )
    return UID->set( "amhc_"+args->variable, args->set );
  else
    return (string)(UID->get( "amhc_"+args->variable ) || args["default"]);
}

// <mail-body-part mail=id part=num>
//
// Part 0 is the non-multipart part of the mail.
// If part > the available number of parts, part 0 is returned.
string tag_mail_body_part( string tag, mapping args, object id )
{
  MIME.Message m = MIME.Message( tag_mail_body( tag, args, id ) );
  mixed res;
  if(res = login(id))
    return res;
  int part = (int)args->part;
  object p;
  if(!part) p=m;
  if( m->body_parts && sizeof(m->body_parts) > part )
    p=m->body_parts[ part ];
  else 
    p=m;
  
  id->misc->moreheads = ([ "Content-type":p->type+"/"+p->subtype ]);
  return p->getdata();
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
//                  (default #data#)
//    full mime-data
// </mail-body-parts>

string container_mail_body_parts( string tag, mapping args, string contents, 
			     object id)
{
  MIME.Message msg = MIME.Message( contents );

  string html_part_format = (args["html-part-format"] || 
			     "<table><tr><td>#data#</td></tr></table>");

  string text_part_format = (args["text-part-format"] || "#data#");

  string binary_part_format = (args["binary-part-format"] || 
			     "<a href='#url#'>Binary data #name# (#type#)"
			       "</a>");

  string image_part_format = (args["image-part-format"] || 
			     "<a href='#url#'><img border=0 src='#url#'>"
			      "<br>#name# (#type#)<br></a>");

  string binary_part_url = (fix_relative(args["binary-part-url"]
			 ||"display.html?mail=#mail#&part=#part#",id));

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
			  highlight_mail(msg->getdata(),id) );
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
			highlight_mail(msg->getdata(),id));
    } else {
      string format;
      if(msg->type == "image") 
	format = image_part_format;
      else
	format = binary_part_format;
      
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

// <debug-import-mail-from-dir dir=...>
//  Guess. :-)

string tag_debug_import_mail_from_dir( string tag, mapping args,
				       object id )
{
  if(!debug) return "Debug is not enabled!\n";

  if(mixed q = login( id )) 
    return q;
  Mailbox incoming = UID->get_incoming();

  string res = "Importing from "+args->dir+"<p>\n";
  foreach(get_dir( args->dir ), string file)
    if(file_stat( args->dir+"/"+file )[ 1 ] > 0)
    {
      incoming->create_mail_from_fd( Stdio.File( args->dir+"/"+file, "r" ) );
      res+="<br>"+file+"\n";
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
  Mail mid = clientlayer->get_cache_obj( clientlayer->Mail, args->mail );

  if(res = login(id))
    return res;

  mid->set_flag( "read" );

  if(mid && mid->user == UID)
    return do_output_tag( args,({(mid->decoded_headers()
				  |make_flagmapping(mid->flags())
				  |([ "body":mid->body() ])
				  |args)}),
			  contents, id );
  return "Permission denied.";
}
