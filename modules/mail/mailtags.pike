#define LOGIN "<return code=304><header name=WWW-Authenticate value='realm=automail'>"
#define UID id->misc->_automail_user

object clientlayer;

/* Utility functions ---------------------------------------------- */

static MIME.Message mymesg = MIME.Message();

static mapping parse_headers( string foo )
{
  return mymesg->parse_headers( foo )[0];
}

static mapping make_flagmapping(multiset from)
{
  return mkmapping( Array.map(indices(from),lambda(string s){return "flag_"+s;}),
		    ({"set"})*sizeof(from))
}

static string login(object id)
{
  int id;
  if(zero_type(UID))
  {
    if(!id->realauth) return LOGIN;
    id = clientlayer->authenticate_user( @(id->realauth/":") );
    if(!id) return LOGIN;
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

/*
 * <delete-mail mail=id [force]>
 *   Force is rather dangerous, since it might leave dangling references 
 *   to the mail.
 */

string tag_delete_mail(string tag, mapping args, object id)
{
  string res;
  if(res = login(id))
    return res;

  /* FIXME: Verify that this mail is actually owned by the current
   * user!
   */

  if(args->force)
    clientlayer->update_message_refcount( (int)args->mail, -1000000 );
  else
    clientlayer->delete_mail( (int)args->mail );
  return "";
}

/*
 * <mail-body mail=id>
 *
 */
string tag_mail_body(string tag, mapping args, object id)
{
  string res;
  if(res = login(id))
    return res;
  return clientlayer->load_body( args->mail );
}

/*
 * <list-mailboxes>
 *  #name# #id# #unread# #read# #mail#
 * </list-mailboxes>
 */
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

/*
 * <list-mails mailbox=id>
 *  #subject# #from# etc.
 * </list-mails>
 */
string container_list_mails( string tag, mapping args, string contents, 
			     object id )
{
  string res;
  if(res = login(id))
    return res;

  if(verify_mailbox( (int)args->mailbox, id )) 
    return "Invalid mailbox id";
  
  array (int) mails = clientlayer->list_mails( (int)args->mailbox );

  /* And now for something completely different... */
  array variables = ({ });
  foreach(mails, int m)
    variables += 
    ({ 
      parse_headers( clientlayer->get_mail_headers( m ) )
      | make_flagmapping( clientlayer->get_flags( m ) )
    });
  return do_output_tag( args, variables, contents, id );
}


/* <body-part mail=id part=num>
 *
 * Part 0 is the non-multipart part of the mail.
 *
 */

/*
 * <body-parts mail=id
 *             binary-part-url=URL
 *	            (default not_query?mail=#mail#&part=#part#)
 *             image-part-format='...#url#...'
 *                  (default <a href='#url#'><img src='#url#'>
 *                           <br>#name# (#type#)<br></a>)
 *             binary-part-format='...#url#...'
 *                  (default <a href='#url#'>Binary data #name# (#type#)</a>)
 *             html-part-format='...#data#...'
 *                  (default <table><tr><td>#data#</td></tr></table>)
 *             text-part-format='...#data#...'>
 *                  (default <pre>#data#</pre>)
 *    full mime-data
 * </body-parts>
 *
 */
string container_body_parts( string tag, mapping args, string contents, 
			     object id)
{
  MIME.Message msg = MIME.Message( contents );

  string html_part_format = (args["html-part-format"] || 
			     "<table><tr><td>#data#</td></tr></table>");
  string text_part_format = (args["text-part-format"] || 
			     "<pre>#data#</pre>");
  string binary_part_format = (args["binary-part-format"] || 
			     "<a href='#url#'>Binary data #name# (#type#)</a>");
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
		       "#name#":html_encode_string(msg->get_filename())||i+".a",
		       "#type#":html_encode_string( msg->type+"/"+msg->subtype ),
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

/*
 * <get-mail mail=id>
 *  #subject# #from# #body# etc.
 * </get-mail>
 */
string container_get_mail( string tag, mapping args, string contents, 
			   object id )
{
  string res;
  if(res = login(id))
    return res;
  
  /* FIXME: Verify that the mail actually belongs to the current user. */

  mapping vars = 
    (parse_headers(clientlayer->get_mail_headers((int)args->mail))|
     make_flagmapping(clientlayer->get_flags( m ))|
     ([ "body":tag_body( tag, args, id ) ]));

  return do_output_tag( args, ({vars}), contents, id );
}
