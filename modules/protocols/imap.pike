/* imap.pike
 *
 * imap protocol
 */

constant cvs_version = "$Id: imap.pike,v 1.52 1999/02/11 21:24:07 grubba Exp $";
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
  object mail;     // Clientlayer object(Mail)
  int serial;      // To poll for changes */

  // FIXME: Recent status should be recorded in the database. Idea:
  // Associate each live selection of a mailbox with a number (for
  // instance the time of the select command). For each mail, store a
  // timestamp corresponding to the selection for which the mail is
  // recent. In this way, we don't have to set and clear flags in the
  // database.

  int is_recent;
  multiset(string) flags;

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
  
  multiset(string) get_flags()
  {
    multiset(string) res = (< >);

    res["\\Recent"] = is_recent;

    foreach(indices(mail->flags()), string flag)
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

  array(string|object) update()
  {
    int current = mail->get_serial();
    if (serial < current)
    {
      serial = current;
      return ({ "FETCH", imap_number(index),
		imap_list( ({ "FLAGS",
			      imap_list(indices(get_flags())),
			      "UID", imap_number(uid),
		}) ) });
    }
    return 0;
  }

  object mapping_to_list(mapping m)
  {
    return imap_list( ((array) m) * ({ }));
  }

  object make_bodystructure(object(MIME.Message) msg, int extension_data)
  {
    array a;

#ifdef IMAP_DEBUG
    werror("imap_mail->make_bodystructure(%O, %O)\n",
	   mkmapping(indices(msg), values(msg)), extension_data);
#endif /* IMAP_DEBUG */

    if (msg->body_parts)
    {
      a = Array.map(msg->body_parts, make_bodystructure, extension_data)
	+ ({ msg->subtype });
      if (extension_data)
	a += ({ mapping_to_list(msg->params),
		// FIXME: Disposition header described in rfc 1806,
		// FIXME: Language tag (rfc 1766).
	});
    } else {
      string data = msg->getdata() || "";

      a = ({ msg->type, msg->subtype,
	     mapping_to_list(msg->params),
	     // FIXME: Content id (rfc 2045)
	     // FIXME: Body description
	       
	     // NOTE: The MIME module decodes any transfer encoding
	     "binary",  // msg->transfer_encoding, 
	     imap_number(strlen(data)) });
	
      // FIXME: Type specific fields, for text/* and message/rfc822 messages
      if (extension_data)
	a += ({ Crypto.md5()->update(data)->digest(),
		// Disposition,
		// Language
	});
    }
    return imap_list(a);
  }
				 
  object|string string_to_imap(string s)
  {
    return s ? imap_string(s) : "nil";
  }

  /* Extracts real name, mailbox name and domain name from an rfc-822 mail address.
   *
   * FIXME: Doesn't handle groups or source routes */
  mapping(string:string) parse_address(array(string|int) tokens)
  {
    int i = search(tokens, '<');
    if (i >= 0)
    {
      if ( (i + 4 < sizeof(tokens) )
	   && stringp(tokens[i+1])
	   && (tokens[i + 2] == '@')
	   && stringp(tokens[i + 3])
	   && (tokens[i+4] == '>') )
	return ([ "name" : (MIME.quote(tokens[..i-1])
			    + MIME.quote(tokens[i+5..])),
		  "mailbox" : tokens[i+1],
		  "domain" : tokens[i+3] ]);
      else
	/* Invalid address */
	return 0;
    }
    int i = search(tokens, '@', 1);
    if ( (i>0)
	 && (i+1 < sizeof(tokens))
	 && stringp(tokens[i-1])
	 && stringp(tokens[i+1]) )
      return ([ "mailbox" : tokens[i-1],
		"domain" : tokens[i+1] ]);
    else
      return 0;
  }

  object|string address_to_imap(string s)
    {
      mapping(string:string) address = parse_address(MIME.tokenize(s));

      return imap_list(s ?
		       ({ address->name, 0, address->mailbox, address->domain })
		       : /* Invalid address */
		       ({ s, 0, "invalid", "invalid" }) );
    }

  object|string address_list_to_imap(string s)
  {
    array(array(string|int)) tokens = MIME.tokenize(s) / ({ ',' });

    return imap_list(Array.map(tokens, parse_address));
  }

  string first_header(array|string v)
  {
    return arrayp(v) ? v[0] : (v || "");
  }
  
  // FIXME: Handle multiple headers... 
  object make_envelope(mapping(string:string|array(string)) h)
  {
    object|string from = address_list_to_imap(first_header(h->from));
    object|string sender = from;
    object|string reply_to = from;
    
    if (h->sender) {
      sender = address_list_to_imap(first_header(h->sender));
    }
    if (h["reply-to"]) {
      reply_to = address_list_to_imap(first_header(h["reply-to"]));
    }

#ifdef IMAP_DEBUG
    werror("make_envelope(%O)\n", h);
#endif /* IMAP_DEBUG */

    imap_list( ({ string_to_imap(first_header(h->date)),
		  string_to_imap(first_header(h->subject)),
		  from, sender, reply_to,
		  address_list_to_imap(first_header(h->to)),
		  address_list_to_imap(first_header(h->cc)),
		  address_list_to_imap(first_header(h->bcc)),
		  string_to_imap(first_header(h["in-reply-to"])),
		  string_to_imap(first_header(h["message-id"])) }) );
  }
  
  // array collect(mixed ...args) { return args; }
  
  array fetch(array(mapping(string:mixed)) attrs)
  {
    array data = Array.map(attrs, fetch_attr) * ({})
      /* + ({ "UID", imap_number(uid) }) */ ;
    
#ifdef IMAP_DEBUG
    werror("imap_mail->fetch(%O) => %O\n", attrs, data);
#endif /* IMAP_DEBUG */

    return ({ "FETCH", 
	      imap_list(data)
    });
  }

  string format_headers(mapping(string:string|array(string)) headers)
  {
    return Array.map(indices(headers),
		     lambda(string name, mapping h)
		     {
		       string|array(string) value = h[name];
		       if (stringp(value))
			 return name + ": " + h[name] + "\r\n";
		       return
			 Array.map(value,
				   lambda(string v, string n)
				   { return n + ": " + v + "\r\n"; },
				   name) * "";
		     },
		     headers) * "" + "\r\n";
  }

  object get_message(string|void s)
  {
    return MIME.Message(s || mail->body(), 0, 0, 1);
  }

  mapping(string:string|array(string)) get_headers(string|void s)
  {
    return MIME.parse_headers(s || mail->read_headers(), 1)[0];
  }

  /* Read a part of the body */
  string get_body_range(array(int) range, string|void s)
  {
    if (!range)
      return s || mail->body();

    if (s)
      return s[range[0]..range[0] + range[1] - 1];

    object f = mail->body_fd();
    if (f->seek(range[0]) < 0)
      throw( ({ "imap->get_body_range: seek failed!\n", backtrace() }) );

    return f->read(range[1]);
  }

  class fetch_response
  {
    object wanted;

    void create(string w)
    {
      wanted = imap_atom(upper_case(w));
    }

    array(object|mixed) `()(mixed response)
    {
      return ({ wanted, response });
    }
  }
    
  class fetch_body_response
  {
    object item;
    array(int) range;
    
    void create(string wanted, array raw, array(int) r)
    {
      range = r;
      item = imap_atom_options(wanted, raw, range);
    }

    array(object|string) `()(string|void s)
    {
      return ({ item, get_body_range(range, s) });
    }
  }

  /* Returns a pair ({ atom[options], value }) */
  /* FIXME: Don't do too much MIME-decoding. Use
   * MIME.Message->getencoded(), not MIME.Message->getdata(). */
  mixed fetch_attr(mapping(string:string|mixed) attr)
  {
#ifdef IMAP_DEBUG
    werror(sprintf("imap_mail->fetch_attr(%O)\n", attr));
#endif /* IMAP_DEBUG */

    /* This variable is cleared if we recurse into a multipart the
     * message. It is used to decide if the headers in the database
     * are relevant. */
    int top_level = 1;

    object response = fetch_response(attr->raw_wanted || attr->wanted);
      
    switch(attr->wanted)
    {
    case "body":
    case "body.peek": {
      object body_response = fetch_body_response(attr->wanted,
						 attr->raw_options,
						 attr->range);
      if (!(sizeof(attr->section) + sizeof(attr->part)))
      {
	/* Entire message */
	return body_response();
      }

      string raw_body = mail->body();

#ifdef IMAP_DEBUG
      werror("fetch_attr(): raw_body: %O\n", raw_body);
#endif /* IMAP_DEBUG */

      // Use multiple headers
      MIME.Message msg = get_message(raw_body);
      
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
	      msg = get_message(msg->getdata());
	      top_level = 0;
	    }
	    else
	      break;
	  }
	  if (!msg->body_parts)
	  {
	    /* Every message has a part 1. This may be more liberal
	     * than rfc-2060, which seems to require this only at
	     * the top level. */
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
	return body_response(top_level ? raw_body : (string) msg);
	
      switch(attr->section[0])
      {
      case "text":
	if (sizeof(attr->section) != 1)
	  throw("Invalid section");
	return body_response(msg->getdata());
	
      case "mime": 
	if (sizeof(attr->section) != 1)
	  throw("Invalid section");

	if (!sizeof(attr->parts))
	  throw("MIME section requires numeric part specifier");

	/* Filter headers */
	return body_response(format_headers
			     ( ([ "mime-version" : 1,
				  "content-type" : 1,
				  "content-length" : 1,
				  "content-transfer-encoding" : 1 ])
			       & msg->headers ));
	    
      case "header": {
	mapping(string:string|array(string)) headers = msg->headers;
	
	if (sizeof(attr->section) == 1)
	  return body_response(format_headers(headers));

	/* Section should be HEADER.FIELDS or HEADER.FIELDS.NOT.
	 * Options should be a list of atoms corresponding to header names. */
	if (attr->section[1] != "fields")
	  throw("Invalid section");
	  
	if (sizeof(attr->options) != 1)
	  throw("Invalid section");
	
	array(mapping(string:mixed)|string) list = attr->options[0]->list;

	if (!list
	    || sizeof(list->type - ({ "atom" }))
	    || sizeof(list->options -({ 0 })))
	  throw("Invalid header list");

	list = Array.map(lower_case, list->atom);
	mapping(string:string) filter = mkmapping(list, list);

	switch(sizeof(attr->section))
	{
	case 2:
	  return body_response(format_headers(filter & headers));
	case 3:
	  if (attr->section[2] == "not")
	    return body_response(format_headers(headers - filter));
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
      return response(make_bodystructure(MIME.Message(mail->body(), 0, 0, 1),
					 !attr->no_extention_data));

    case "envelope": 
      return response(make_envelope(get_headers()));
	
    case "flags":
      return response(imap_list(indices(get_flags())));

    case "internaldate":
      // FIXME: Where can a suitable date be found?
      // Use mail->headers()->incoming_date
      werror("mail->headers(): %O\n", mail->headers());
      // FIXME
      return response("internaldate_unimplemented");

    case "rfc822":
      switch(sizeof(attr->section))
      {
      default:
	throw("Invalid fetch");
      case 0:
	return response(mail->body());
      case 1:
	switch(attr->section[0])
	{
	case "header":
	  return response(mail->read_headers());
	case "size":
	  // FIXME: How does rfc-822 define the size of the message?
	  return response(imap_number(mail->get_size()));
	case "text":
	  return response(get_message()->getdata());
	default:
	  throw("Invalid fetch");
	}
      }
      break;
    case "uid":
      return response(imap_number(uid));
    default:
      throw( ({ sprintf("Internal error: Unknown attribute %O\n",
			attr->wanted),
		backtrace() }) );
    }
  }
  
  void mark_as_read()
  {
    /* Don't update the flags variable: That is done by a later
     * update() call.*/
    mail->set_flag("read");
  }
}
  
class imap_mailbox
{
  object mailbox;  // Clientlayer object 
  int serial;      // To poll for changes */

  int uid_validity;
  int next_uid;

  /* Array of imap_mail objects */
  array(object) contents;

  mapping(int:int) uid_lookup = ([]);

  /* Flags (except system flags) defined for this mailbox */
  multiset(string) flags;
  
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

    /* Initialize the UID to mail id lookup table */
    array(int) uids = contents->uid;

#ifdef IMAP_DEBUG
    werror("imap_mailbox(): uids:%O\n", uids);
#endif /* IMAP_DEBUG */

    uid_lookup = mkmapping(uids, indices(uids));

    flags = mailbox->get("DEFINED_FLAGS") || (< >);
  }

  array(object) get_contents(int make_new_uids)
  {
    array(object) a = mailbox->mail();
    int n = sizeof(a);

    sort(a->get(UID), a);

    /* Is there any mail without uid? */
    int i;
      
    for (i=0; i<sizeof(a); i++)
      if (a[i]->get(UID))
	break;

    /* NOTE: The new mail come before the old mail. */
    /* Extract the new mail */
    array(object) new = a[..i-1];
    array(object) old = a[i..];
      
    if (make_new_uids)
    {
      /* Assign new uids to all mail */
      foreach(old, object mail)
	mail->set(UID, alloc_uid());
    } 
    /* Assign uids to new mail */
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
      array(object) new_contents = get_contents(0);

      array(array(object|string)) res = ({ });

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

      /* Update the UID to mail id lookup table */
      array(int) uids = contents->uid;
      uid_lookup = mkmapping(uids, indices(uids));

      res += ({ get_exists() });

      /* Updated flags */
      res += contents->update() - ({ 0 });

      res += ({ get_recent() });

      return res;
    }
    else
      return 0;
  }

  array(string|object) get_uidvalidity()
  {
    return ({ "OK", imap_prefix( ({ "UIDVALIDITY",
				    imap_number(uid_validity) }) ) });
  }

  array(object) get_exists()
  {
    return ({ imap_number(sizeof(contents)), "EXISTS" });
  }

  array(object) get_recent()
  {
    return ({ imap_number(sizeof(contents->is_recent - ({ 0 }) )),
	      "RECENT" });
  }

  array(string|object) get_unseen()
  {
    // RFC 2060: 6.3.1:
    //   The server SHOULD also send an UNSEEN response code in an OK
    //   untagged response, indicating the message sequence number of
    //   the first unseen message in the mailbox.
    int unseen = search(contents->flags["\\Seen"], 0) + 1;
    if (unseen) {
      return({ "OK", imap_prefix( ({ "UNSEEN", imap_number(unseen) }) ) });
    }
    return 0;
  }

  array(string|object) get_flags()
  {
    return ({
      "FLAGS", imap_list( ({
	"\\Answered", "\\Deleted", "\\Draft",
	"\\Flagged", "\\Recent", "\\Seen",
	@indices(flags)
      }) )
    });
  }

  array(string|object) get_permanent_flags()
  {
    /* All flags except \Recent are permanent */
    return ({
      "OK",
      imap_prefix( ({
	"PERMANENTFLAGS",
	imap_list( ({
	  "\\Answered", "\\Deleted", "\\Draft",
	  "\\Flagged", "\\Seen",
	  @indices(flags)
	}) )
      }) )
    });
  }

  array(array(string|object)) fetch(object message_set, array(mapping) attrs)
  {
    array message_numbers =  message_set->expand(sizeof(contents));

#ifdef IMAP_DEBUG
    werror("imap_mailbox->fetch(%O, %O)\n", message_numbers, attrs);
#endif /* IMAP_DEBUG */

    array(array(string|object)) res
      = Array.map(message_numbers,
		  lambda(int i, array attrs)
		  {
		    return ({
		      "FETCH", imap_number(i),
		      imap_list( Array.map(attrs,
					   lambda(mixed attr, int i)
					   {
					     return contents[i-1]->
					       fetch_attr(attr);
					   },
					   i) * ({}) + ({
					     "UID",
					     imap_number(contents[i-1]->uid)
					   }) )
		    });
		  },
		  attrs);

#ifdef IMAP_DEBUG
    werror("=> res: %O\n", res);
#endif /* IMAP_DEBUG */
      
    /* Fetch was successful. Consider setting the \Read flag. */
    if (sizeof(attrs->mark_as_read - ({ 0 }) ))
    {
      foreach(message_numbers, int i)
	contents[i-1]->mark_as_read();
    }

    return res;
  }

  object uid_to_local(object uid_set)
  {
    /* FIXME: Some of this stuff should probably be in types.imap_set. */

#ifdef IMAP_DEBUG
    werror("uid_to_local(%O)\n", uid_set->items);
#endif /* IMAP_DEBUG */

    array all_uids = indices(uid_lookup);

    // Not terribly efficient, but...
    // Doesn't handle overlapping ranges.
    object local_set = imap_set(({}));

#ifdef IMAP_DEBUG
    werror("uid_to_local(): all_uids:%O\n", all_uids);
#endif /* IMAP_DEBUG */

    foreach(uid_set->items, string|array(int|string)|int item) {
#ifdef IMAP_DEBUG
      werror("uid_to_local(): item:%O\n", item);
#endif /* IMAP_DEBUG */
      if (intp(item)) {
	// Specific UID
	if (uid_lookup[item]) {
	  local_set->items += ({ uid_lookup[item] });
	}
      } else if (item == "*") {
	// Matches all UID's
	local_set->items = values(uid_lookup);

	break;
      } else if (arrayp(item)) {
	if (item[1] == "*") {
	  // No upper limit.
	  foreach(all_uids, int uid) {
	    if (uid >= item[0]) {
	      local_set->items += ({ uid_lookup[uid] });
	    }
	  }
	} else {
	  foreach(all_uids, int uid) {
	    if ((uid >= item[0]) && (uid <= item[1])) {
	      local_set->items += ({ uid_lookup[uid] });
	    }
	  }
	}
      }
    }

    sort(local_set->items);

    /* Make local id's */
    int i;
    for (i=0; i < sizeof(local_set->items); i++) {
      local_set->items[i]++;
    }

#ifdef IMAP_DEBUG
    werror("uid_to_local() => %O\n", local_set->items);
#endif /* IMAP_DEBUG */
    return(local_set);
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

  array(string) capabilities(object|mapping session)
  {
#ifdef IMAP_DEBUG
    werror("imap.pike: capabilities\n");
#endif
    return ({ "IMAP4rev1" });
  }

  int login(object|mapping(string:mixed) session, string name, string passwd)
  {
#ifdef IMAP_DEBUG
    werror("imap.pike: login: %O\n", name);
#endif
    return session->user = clientlayer->get_user(name, passwd);
  }
  
  array(string|object) update(object|mapping(string:mixed) session)
  {
#ifdef IMAP_DEBUG
    werror("imap.pike: update\n");
#endif
    return session->mailbox && session->mailbox->update();
  }

  array(string)|int imap_glob(string glob, string|array(string) name)
  {
    /* IMAP's glob patterns uses % and * as wild cards (equivalent
     * as long as there are no hierachical names. Pike's glob
     * patterns uses * and ?, which can not be escaped. To be able
     * to match questionmarks properly, we use scanf instead. */

    glob = replace(glob, ({ "*", "%", }), ({ "%*s", "%*s" }) );

    if (stringp(name))
      return sscanf(name, glob);

    array(string) res = ({ });

    foreach(name, string n)
      if (sscanf(n, glob))
	res += ({ n });

    return res;
  }
  
  array(array(object|string)) list(object|mapping(string:mixed) session,
				   string reference, string glob)
  {
    if ( (reference != "") )
      return ({ });
    
    return Array.map(imap_glob(glob,
			       Array.map(session->user->mailboxes()->
					 query_name(),
					 lambda(string n) {
					   // Remap incoming => INBOX.
					   return (n=="incoming")?"INBOX":n;
					 })),
		     lambda (string name)
		     { return ({ imap_list( ({}) ), "nil", name }); } );
  }

  array(array(object|string)) lsub(object|mapping(string:mixed) session,
				   string reference, string glob)
  {
    if ( (reference != "") )
      return ({ });

    return Array.map(imap_glob(glob,
			       indices(session->user->get(IMAP_SUBSCRIBED)
				       || (< >))),
		     lambda (string name)
		     { return ({ imap_list( ({}) ), "nil", name }); } );
  }

  array(array(object|string)) select(object|mapping(string:mixed) session,
				     string mailbox)
  {
    // Remap INBOX => incoming.
    mailbox = (mailbox == "INBOX")?"incoming":mailbox;
    object m = session->user->get_mailbox(mailbox);

    if (!m)
    {
      session->mailbox = 0;
      return 0;
    }
    m = imap_mailbox(m);
    session->mailbox = m;
    
    return ({ m->get_exists(),
	      m->get_recent(),
	      m->get_unseen(),
	      m->get_uidvalidity(),
	      m->get_flags(),
	      m->get_permanent_flags() });
      
  }

  array(array(string|object)) fetch(object|mapping(string:mixed) session,
				    object message_set,
				    array(mapping(string:mixed)) fetch_attrs)
  {
    return session->mailbox->fetch(message_set, fetch_attrs)
      + (session->mailbox->update() || ({}));
  }

  object uid_to_local(object|mapping(string:mixed) session, object uid_set)
  {
    return session->mailbox->uid_to_local(uid_set);
  }
}

array(mixed) register_module()
{
  return ({ 0,
	    "IMAP protocol",
	    "IMAP interface to the mail system." });
}

#if 0
/* This doesn't work, for some reason */
#define PORT Protocols.Ports.tcp.imap2
#else
#define PORT 143
#endif

void create()
{
  werror("imap->create\n");
  defvar("port", PORT, "IMAP port number", TYPE_INT,
	 "Portnumber to listen to. "
	 "Usually " + PORT + ".\n");
  defvar("timeout", 600, "Max idle time.", TYPE_INT,
	 "Clients who are inactive this long are logged out automatically.\n");
  defvar("debug", 0, "Debug", TYPE_FLAG, "Enable IMAP debug output.\n");
}

#undef PORT

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
					  QUERY(port), QUERY(timeout),
					  backend(conf), QUERY(debug));
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
  mapping(string:program) m = master()->programs;

  foreach(glob("*IMAP*", indices(m)), string name)
    m_delete(m, name);
}
	  
