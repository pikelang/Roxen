/* imap.pike
 *
 * imap protocol
 */

constant cvs_version = "$Id: imap.pike,v 1.3 1998/09/23 04:59:01 nisse Exp $";
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
	flags = get_flags();
	return ({ "FETCH", imap_number(index),
		  imap_list( ({ "FLAGS",
				imap_list(indices(flags)) }) ) });
      }
      return 0;
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
	  
