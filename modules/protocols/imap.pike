/* imap.pike
 *
 * imap protocol
 */

constant cvs_version = "$Id: imap.pike,v 1.1 1998/09/16 02:59:22 nisse Exp $";
constant thread_safe = 1;

#include <module.h>

inherit "module";

import "/home/nisse/hack/AutoSite/pike-modules";

#define IMAP_DEBUG

/* Names of imap related attributes */
#define UID_VALIDITY "IMAP:uid_validity"
#define UID "IMAP:uid"
#define NEXT_UID "IMAP:next_uid"

/* In IMAP, it is crucial that the client and server are in synch at
 * all times. The servers view of a mailbox may not change unless it
 * has an opportunity to tell the client about it. Therefore, most
 * information about mailboxes has to be retrieved from the database
 * early, and the cache is only updated in response to a command from
 * the client. */

class mail
{
  object mail;     // Clientlayer object
  int serial;      // To poll for changes */

  int is_recent;
  multiset flags;

  int uid;
  
  void create(object m, int r)
    {
      mail = m;
      is_recent = r;
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
	  if ((strlen(flag) > 5) && (flag[..4] = "IMAP:"))
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
	return ({ imap_number(uid), imap_list( ({ "FLAGS", imap_list(flags) }) ) });
      }
      return 0;
    }
}
  
class mailbox
{
  object mailbox;  // Clientlayer object 
  int serial;      // To poll for changes */

  int uid_validity;
  int next_uid;
  
  array contents;

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
    }

  array get_contents(int make_new_uids)
    {
      array a = mailbox->mail();

      sort(a->get(UID), a);

      /* Are there any mails with out uids? */
      int i;
      
      for (i=0; i<sizeof(a); i++)
	if (a[i]->get(UID))
	  break;

      /* Extract the new mails */
      array new = a[..i-1];
      a = a[i..];
      
      if (make_new_uids)
      {
	/* Assign new uids to all mails */
	foreach(a + new, mail)
	  mail->set(UID, alloc_uid());
      } else {
	/* Assign uids to new mails */
	foreach(new, object mail)
	  mail->set(UID, alloc_uid());
      }
      return Array.map(mail, a, 0) + Array.map(mail, new, 1);
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

	res += ({ ({ imap_number(sizeof(contents)), "EXISTS" }) });

	/* Updated flags */
	res += contents->update() - ({ 0 });

	res += ({ ({ imap_number(sizeof(contents->is_recent - ({ 0 }) )),
		     "RECENT" }) });

	return res;
      }
      else
	return 0;
    }
}

// The IMAP protocol uses this object to operate on the mailboxes */
class backend
{
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

  array list(object|mapping session, string reference, string glob)
    {
      if ( (reference != "") )
	return ({ });

      array res = ({ });
      
      /* IMAP's glob patterns uses % and * as wild cards (equivalent
       * as long as there are no hierachical names. Pike's glob
       * patterns uses * and ?, which can not be escaped. To be able
       * to match questionmarks properly, we use scanf instead. */

      glob = replace(glob, ({ "*", "%", }), ({ "%*s", "%*s" }) );

      foreach(session->user->mailboxes->query_name(), string name)
      {
	/* FIXME: Could add support for \Marked and \Unmarked. */
	if (sscanf(name, glob))
	  res += ({ ({ imap_list( ({}) ), "nil", name }) });
      }
      return res;
    }

  array lsub(object|mapping session, string reference, string glob)
    {
      
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
  defvar("port", Protocols.Ports.tcp.imap2, "SMTP port number", TYPE_INT,
	 "Portnumber to listen to. "
	 "Usually " + Protocols.Ports.tcp.imap2 + ".\n");
}

void start(int i, object c)
{
  mixed e = catch {
    imap_server(Stdio.Port, QUERY(port), backend(conf), 1);
  };

  if (e)
    report_error(sprintf("SMTP: Failed to initialize the server:\n"
			 "%s\n", describe_backtrace(err)));
}

void stop() {}

  
