/* imap.pike
 *
 * imap protocol
 */

constant cvs_version = "$Id: imap.pike,v 1.4 1998/09/24 19:31:47 nisse Exp $";
constant thread_safe = 1;

#include <module.h>

inherit "module";

import Protocols.IMAP;
import types;

#define IMAP_DEBUG

/* Names of imap related attributes */

/* Mailbox attributes */
#define UID_VALIDITY "IMAP:uid_validity"
#define NEXT_UID "IMAP:next_uid"
#define DEFINED_FLAGS "IMAP:defined_flags"

/* Mail attributes */
#define UID "IMAP:uid"

/* User attributes */
#define IMAP_SUBSCRIBED "IMAP:subscribed"

/* In IMAP, it is crucial that the client and server are in synch at
 * all times. The servers view of a mailbox may not change unless it
 * has an opportunity to tell the client about it. Therefore, most
 * information about mailboxes has to be retrieved from the database
 * early, and the cache is only updated in response to a command from
 * the client. */

class imap_mail
{  
  object mail;     // Clientlayer object
  int serial;      // To poll for changes */

  // FIXME: Recent status should be recorded in the database. Idea:
  // Associate each live selection of a mailbox with a number (for
  // instance the time of the select command). For each mail, store a
  // timestamp corresponding to the selection for which the mail is
  // recent. In this way, we don't have to set and clear flags in the
  // database.

  int is_recent;
  multiset flags;

  int uid;
  
  int index;  /* Index in the mailbox */
  
  void create(object m, int r, int i)
    {
      mail = m;
      is_recent = r;
      index = i;
      flags = get_flags();
      uid = mail->get(UID);
    }
  
  multiset get_flags()
    {
      multiset res = (< >);

      res["\\Recent"] = is_recent;

      foreach(indices(mail->get_flags), string flag)
      {
	string imap_flag =
	([ "read" : "\\Seen",
	   "answered" : "\\Answered",
	   "deleted" : "\\Deleted",
	   "draft" : "\\Draft" ]) [flag];
	if (imap_flag)
	  res[imap_flag] = 1;
	else
	{
	  if ((strlen(flag) > 5) && (flag[..4] == "IMAP:"))
	    res[flag[5..]] = 1;
	}
      }
      return res;
    }

  array update()
    {
      int current = mail->get_serial();
      if (serial < current)
      {
	serial = current;
	return ({ "FETCH", imap_number(index),
		  imap_list( ({ "FLAGS",
				imap_list(indices(get_flags())) }) ) });
      }
      return 0;
    }

  object make_bodystructure(MIME.Message msg)
    {
    }

  object|string string_to_imap(string s)
    {
      return s ? imap_string(s) : "nil";
    }

  object|string address_to_imap(string s)
    {
    }
  object|string address_list_to_imap(string s)
    {
      
    }
  object make_envelope(mapping(string:string) h)
    {
      object|string from = address_list_to_imap(h->from);
      object|string sender = (h->sender
			      ? address_list_to_imap(h->sender)
			      : from);
      object|string reply_to = (h["reply-to"]
				? address_list_to_imap(h["reply-to"])
				: from);
      
      imap_list( ({ string_to_imap(h->date),
		    string_to_imap(h->subject),
		    from, sender, reply_to,
		    address_list_to_imap(h->to),
		    address_list_to_imap(h->cc),
		    address_list_to_imap(h->bcc),
		    string_to_imap(h["in-reply-to"]),
		    string_to_imap(h["message-id"]) }) )
    }
  
  // array collect(mixed ...args) { return args; }
  
  array fetch(array attrs)
    {
      return ({ "FETCH",
		imap_list(Array.transpose
			  ( ({ fetch_attrs->raw,
			       Array.map(fetch_attrs, fetch_attr) }) )
			  * ({})) });
    }

  string format_headers(mapping headers)
    {
      return Array.map(indices(headers),
		       lambda(string name, mapping h)
			 {
			   string|array(string) value = h[name];
			   if (stringp(value))
			     return name + ":" + h[name] + "\r\n";
			      return
				Array.map(value,
					  lambda(string v, string n)
					    { return n + ":" + v + "\r\n"; },
					  name) * "";
			 },
		       headers) * "" + "\r\n";
    }
      
  /* Returns a pair ({ atom[options], value }) */
  mixed fetch_attr(mapping attr)
    {
      /* This variable is cleared if we recurse into a multipart the
       * message. It is used to decide if the headers in the database
       * are relevant. */
      int top_level = 1;
      
      switch(attr->wanted)
      {
      case "body":
      case "body.peek": {
	if (!(sizeof(attr->section) + sizeof(attr->part)))
	{
	  /* Entire message */
	  return m->body();
	}

	MIME.Message msg = MIME.Message(m->body());
	
	if (sizeof(attr->part))
	{
	  foreach(attr->part, int i)
	  {
	    if (!i)
	      throw("There's no part zero");

	    /* Recurse into parts of type message/rfc822 */
	    while (!msg->body_parts)
	    {
	      if ( (msg->type == "message")
		   && (msg->subtype == "rfc822"))
	      {
		msg = MIME.Message(msg->getdata());
		top_level = 0;
	      }
	      else
		break;
	    }
	    if (!msg->body_parts)
	    {
	      /* Every message has a part 1. This may be more liberal than rfc-2060,
	       * which seems to require this only at the top level. */
	      if (i == 1)
		continue;
	      else
		throw("No such part");
	    }
	    if (i > sizeof(msg->body_parts))
	      throw("No such part");
	    msg = msg->body_parts[i-1];
	    top_level = 0;
	  }
	}

	if (!sizeof(attr->section))
	  return top_level ? m->body() : (string) msg;
	
	switch(attr->section[0])
	{
	case "text":
	  if (sizeof(attr->section) != 1)
	    throw("Invalid section");
	  return msg->getdata();

	case "mime": 
	  if (sizeof(attr->section) != 1)
	    throw("Invalid section");

	  if (!sizeof(parts))
	    throw("MIME section requires numeric part specifier");

	  /* Filter headers */
	  return format_headers
	    ( ([ "mime-version" : 1,
		 "content-type" : 1,
		 "content-length" : 1,
		 "content-transfer-encoding" : 1 ])
	      & (top_level ? m->headers() : msg->headers) );
	  
	case "header": {
	  mapping headers = top_level ? m->headers() : msg->headers;
	  
	  if (sizeof(attr->section) == 1)
	    return format_headers(headers);

	  /* Section should be HEADER.FIELDS or HEADER.FIELDS.NOT.
	   * Options should be a list of atoms corresponding to header names. */
	  if (attr->section[1] != "fields")
	    throw("Invalid section");
	  
	  if (sizeof(attr->options) != 1)
	    throw("Invalid section");

	  array list = attr->options[0]->list;

	  if (!list
	      || sizeof(list->type - ({ "atom" }))
	      || sizeof(list->options -({ 0 })))
	    throw("Invalid header list");

	  list = Array.map(lower_case, list->atom);
	  mapping filter = mkmapping(list, list);

	  switch(sizeof(attr->section))
	  {
	  case 2:
	    return format_headers(filter & headers);
	  case 3:
	    if (attr->section[2] == "not")
	      return format_headers(headers - filter);
	    /* Fall through */
	  default:
	    throw("Invalid section");
	  }
	}
	default:
	  throw("Invalid section");
	}
	/* Should not happen */
	throw( ({ "Internal error", backtrace() }) );
      }
      case "bodystructure": 
	return make_bodystructure(MIME.Message(m->getdata()), attr->no_extention_data);

      case "envelope": 
	return make_envelope(top_level
			     ? m->decoded_headers()
			     : MIME.Message(m->getdata())->headers);
	
      case "flags":
	return imap_list(indices(get_flags()));

      case "internaldate":
	// FIXME: Where can a suitable date be found?
	throw("Not implemented");

      case "rfc822":
	if (sizeof(attr->section == 1))
	  return m->body();

	if (sizeof(attr->section != 2))
	  throw("Invalid fetch");

	switch(attr->section[1])
	{
	case "header":
	  return format_headers(m->headers());
	case "size":
	  // FIXME: How does rfc-822 define the size of the message?
	  throw("Not implemented");
	case "text":
	  return MIME.Message(m->body())->getdata();
	default:
	  throw("Invalid fetch");
	}
	break;
      case "uid":
	return imap_number(uid);
      default:
	throw( ({ "Internal error", backtrace() }) );
      }
    }
  
  void mark_as_read()
    {
      /* Don't update the flags variable: That is done by a later
       * update() call.*/
      m->set_flag("read");
    }
}
  
class imap_mailbox
{
  object mailbox;  // Clientlayer object 
  int serial;      // To poll for changes */

  int uid_validity;
  int next_uid;
  
  array contents;

  /* Flags (except system flags) defined for this mailbox */
  multiset flags;
  
  int alloc_uid()
    {
      int res = next_uid++;
      mailbox->set(NEXT_UID, next_uid);
      return res;
    }
  
  void create(object m)
    {
      mailbox = m;
      uid_validity = mailbox->get(UID_VALIDITY);

      if (!uid_validity)
      {
	/* Initialize imap attributes */
	uid_validity = time();
	mailbox->set(UID_VALIDITY, uid_validity);
	next_uid = 1;
	mailbox->set(NEXT_UID, next_uid);
	contents = get_contents(1);
      } else {
	next_uid = mailbox->get(NEXT_UID);
	contents = get_contents(0);
      }
      flags = m->get("DEFINED_FLAGS") || (< >);
    }

  array get_contents(int make_new_uids)
    {
      array a = mailbox->mail();
      int n = sizeof(a);

      sort(a->get(UID), a);

      /* Are there any mails with out uids? */
      int i;
      
      for (i=0; i<sizeof(a); i++)
	if (a[i]->get(UID))
	  break;

      /* Extract the new mails */
      array new = a[..i-1];
      array old = a[i..];
      
      if (make_new_uids)
      {
	/* Assign new uids to all mails */
	foreach(old, object mail)
	  mail->set(UID, alloc_uid());
      } 
      /* Assign uids to new mails */
      foreach(new, object mail)
	mail->set(UID, alloc_uid());

      /* Create imap_mail objects */
      int index = 1;

      for(i = 0; i<sizeof(old); i++)
	old[i] = imap_mail(old[i], 0, index++);

      for(i = 0; i<sizeof(new); i++)
	new[i] = imap_mail(new[i], 0, index++);

      return old + new;
    }
  
  array update()
    {
      int current = mailbox->get_serial();
      if (serial < current)
      {
	serial = current;

	/* Something happened */
	array new_contents = get_contents(0);

	array res = ({ });

	int i, j;
	int expunged = 0;
	
	for (i=j=0; (i<sizeof(contents)) && (j<sizeof(new_contents)); )
	{
	  if (contents[i]->uid = new_contents[j]->uid)
	  {
	    i++; j++;
	    continue;
	  }
	  else if (contents[i]->uid < new_contents[j]->uid)
	  {
	    /* A mail has den deleted */
	    res += ({ ({ imap_number(i-expunged), "EXISTS" }) });
	    expunged++;
	  }
	  else
	    throw( ({ "imap.pike: Internal error\n", backtrace() }) );
	}

	contents = new_contents;

	res += ({ get_exists() });

	/* Updated flags */
	res += contents->update() - ({ 0 });

	res += ({ get_recent() });

	return res;
      }
      else
	return 0;
    }

  array get_uidvalidity()
    {
      return ({ "OK", imap_prefix( ({ "UIDVALIDITY",
				      imap_number(uid_validity) }) ) });
    }

  array get_exists()
    {
      return ({ imap_number(sizeof(contents)), "EXISTS" });
    }

  array get_recent()
    {
      return ({ imap_number(sizeof(contents->is_recent - ({ 0 }) )),
		"RECENT" });
    }

  array get_unseen()
    {
      int unseen = sizeof(contents->flags["\\Seen"] - ({ 1 }) );
      return ({ "OK", imap_prefix( ({ "UNSEEN", imap_number(unseen) }) ) });
    }

  array get_flags()
    {
      return ({ "FLAGS", imap_list(
	({ "\\Answered", "\\Deleted", "\\Draft",
	   "\\Flagged", "\\Recent", "\\Seen",
	   @indices(flags)
	}) ) });
    }

  array get_permanent_flags()
    {
      /* All flags except \Recent are permanent */
      return ({ "OK", imap_prefix(
	({ "PERMANENTFLAGS",
	   imap_list(
	     ({ "\\Answered", "\\Deleted", "\\Draft",
		"\\Flagged", "\\Seen",
		@indices(flags)
	     })) }) ) });
    }

  array fetch(object message_set, mixed attr)
    {
      array message_numbers =  message_set->expand(sizeof(contents));
      array res
	= `+( ({ }),
	      @Array.map(message_numbers,
			 lambda(int i, array fetch_attrs)
			   {
			     return Array.map(fetch_attr,
					      lambda(mixed attr, int i)
						{
						  return contents[i-1]->fetch(attr);
						},
					      i);
			   },
			 fetch_attrs));
      
      /* Fetch was successful. Consider setting the \Read flag. */
      if (sizeof(fetch_attrs->mark_as_read - ({ 0 }) ))
      {
	foreach(message_numbers, int i)
	  contents[i-1]->mark_as_read();
      }

      return res;
    }
}

// The IMAP protocol uses this object to operate on the mailboxes */
class backend
{
  // import "/home/nisse/hack/AutoSite/pike-modules";
  // import IMAP.types;
  
  object clientlayer;

  void create(object conf)
    {
      clientlayer = conf->get_provider("automail_clientlayer");
      if (!clientlayer)
	throw( ({ "imap.pike: No clientlayer found\n", backtrace() }) );
    }

  array capabilities(object|mapping session)
    {
#ifdef IMAP_DEBUG
      werror("imap.pike: capabilities\n");
#endif
      return ({ "IMAP4rev1" });
    }

  int login(object|mapping session, string name, string passwd)
    {
#ifdef IMAP_DEBUG
      werror("imap.pike: login: %O\n", name);
#endif
      return session->user = clientlayer->get_user(name, passwd);
    }
  
  array update(object|mapping session)
    {
#ifdef IMAP_DEBUG
      werror("imap.pike: update\n");
#endif
      return session->mailbox && session->mailbox->update();
    }

  array imap_glob(string glob, string|array(string) name)
    {
      /* IMAP's glob patterns uses % and * as wild cards (equivalent
       * as long as there are no hierachical names. Pike's glob
       * patterns uses * and ?, which can not be escaped. To be able
       * to match questionmarks properly, we use scanf instead. */

      glob = replace(glob, ({ "*", "%", }), ({ "%*s", "%*s" }) );

      if (stringp(name))
	return sscanf(name, glob);

      array res = ({ });

      foreach(name, string n)
	if (sscanf(n, glob))
	  res += ({ n });

      return res;
    }
  
  array list(object|mapping session, string reference, string glob)
    {
      if ( (reference != "") )
	return ({ });

      return Array.map(imap_glob(glob, session->user->mailboxes()->query_name()),
		       lambda (string name)
			 { return ({ imap_list( ({}) ), "nil", name }); } );
    }

  array lsub(object|mapping session, string reference, string glob)
    {
      if ( (reference != "") )
	return ({ });

      return Array.map(imap_glob(glob,
				 indices(session->user->get(IMAP_SUBSCRIBED)
					 || (< >))),
		       lambda (string name)
			 { return ({ imap_list( ({}) ), "nil", name }); } );
    }

  array select(object|mapping session, string mailbox)
    {
      object m = session->user->get_mailbox(mailbox);

      if (!m)
      {
	session->mailbox = 0;
	return 0;
      }
      m = imap_mailbox(m);
      session->mailbox = m;

      return ({ m->get_uidvalidity(),
		m->get_exists(),
		m->get_recent(),
		m->get_unseen(),
		m->get_flags(),
		m->get_permanent_flags() });
      
    }

  array fetch(mapping|object session, object message_set, array fetch_attrs)
    {
      return session->mailbox->fetch(message_set, fetch_attrs)
	+ session->mailbox->update();
    }
}

array register_module()
{
  return ({ 0,
	    "IMAP protocol",
	    "IMAP interface to the mail system." });
}

void create()
{
  werror("imap->create\n");
  defvar("port", Protocols.Ports.tcp.imap2, "SMTP port number", TYPE_INT,
	 "Portnumber to listen to. "
	 "Usually " + Protocols.Ports.tcp.imap2 + ".\n");
  defvar("debug", 0, "Debug", TYPE_INT, "Enable IMAP debug output.\n");
}

object server;

void start(int i, object conf)
{
  werror("imap->start\n");
  if (server)
  {
    server->close();
    server = 0;
  }
  if (conf)
    {
      mixed e = catch {
	server = Protocols.IMAP.imap_server(Stdio.Port(),
					    QUERY(port), backend(conf), QUERY(debug));
      };
      
      if (e)
	report_error(sprintf("IMAP: Failed to initialize the server:\n"
			     "%s\n", describe_backtrace(e)));
    }
}

void stop()
{
  if (server)
  {
    server->close();
    server = 0;
  }
}

/* Remove needed pike modules, to make reloading easier. */
void destroy()
{
  mapping m = master()->programs;

  foreach(glob("IMAP*", indices(m)), string name)
    m_delete(m, name);
}
	  
