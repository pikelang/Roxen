// Roxen AutoMail POP3 Server
// $Id: pop3.pike,v 1.2 1998/09/22 18:09:24 leif Exp $
// Leif Stensson, September 1998.

#include <module.h>
#include <roxen.h>
#include <stdio.h>

inherit "module";
inherit "socket";
inherit "roxenlib";

#define LISTENPORT "POP3 Server Port"
#define TIMEOUT    "POP3 Client Timeout"

int    ListenPortNo;
object (Stdio.Port)  ListenPort;

object conf;
object clientlayer;

array  CurrentSessions = ({ });

int    serial;

void create ()
{ defvar(LISTENPORT, 110,
         LISTENPORT, TYPE_INT,
         "The TCP port on which the POP3 server should expect "
         "client connections. (Standard port: 110.)");

  defvar(TIMEOUT, "15 minutes",
         TIMEOUT, TYPE_MULTIPLE_STRING,
         "How long should a client session be allowed to remain inactive "
         "before terminating the connection?",
           ({ "3 minutes", "5 minutes", "10 minutes", "15 minutes",
              "20 minutes", "30 minutes", "45 minutes", "60 minutes"
           })
        );

  serial = random(9999);
}

array register_module()
{ return ({ 0, "POP3 Server Module", "", 0, 1 });
}

string status()
{ string s = "<H2>Roxen AutoMail POP3 Server Status</H2>\n";

  if (!clientlayer)
     s += "AutoMail Client Layer not found.<BR>\n";

  if (ListenPort && ListenPortNo == query(LISTENPORT))
     s += "Listening on port " + query(LISTENPORT) + ".<BR>\n";
  else 
     s += "Unable to bind port " + query(LISTENPORT) + ".<BR>\n";

  return s;
}

void client_close_callback(mapping id)
{ int i;
  for(i = 0; i < sizeof(CurrentSessions); ++i)
    if (CurrentSessions[i] == id)
       CurrentSessions[i] = 0;

  destruct(id->clientport);
}

void init_transaction_state(mapping id)
{ id->state = "TRANSACTION";
  id->maildrop = ({ 0 });

//  id->clientport->write("*Mail for user #" + id->user_id + "\r\n");
//  id->clientport->write("*User: " + clientlayer->get_user_realname(id->user_id) + "\n");

  mapping mailboxes = clientlayer->list_mailboxes(id->user_id);
  array m = indices(mailboxes);

//  id->clientport->write("*# of mailboxes: " + sizeof(mailboxes) + "\r\n");
//  foreach(m, string x) id->clientport->write("*Mailbox: " + x + "\r\n");

  if (id->mailbox_id = mailboxes["incoming"])
  {
//    id->clientport->write("*Inbox ID: " + id->mailbox_id + "\r\n");
    mapping maildrop0 = clientlayer->list_mail(id->mailbox_id);
//    id->clientport->write("*Maildrop items: " + sizeof(maildrop0) + "\r\n");
    foreach (indices(maildrop0), mixed refno)
    {
//      id->clientport->write("*Mail: " + refno + "\n");
//      id->clientport->write("*  Message-ID: " + maildrop0[refno] + "\r\n");

      mixed mail = clientlayer->get_mail(maildrop0[refno]);

//      id->clientport->write("*  Did get_mail()\r\n");

//      foreach (indices(mail), string item)
//      id->clientport->write("*  Item '" + item + "': " + mail[item] + "\n");

      if (mail->body_id)
      {
        Stdio.File f = clientlayer->load_body_get_obj(mail->body_id);
        int size = 0;
        if (f)
        { string sz;
          while ((sz = f->read(1000)) && sz != "")
          { size += sizeof(sz);
//            id->clientport->write(sz);
          }
          destruct(f); 
        }
//        id->clientport->write(" Size: " + size + "\r\n");
        id->maildrop +=
            ({ ([ "size":     size,
                  "deleted":  0,
                  "refno":    refno,
                  "body_id":  mail->body_id,
                  "headers":  mail->headers,
                  "sender":   mail->sender,
                  "subject":  mail->subject,
                  "in-date":  mail->incoming_date,
               ])
            });
      }
    }
  }
//  id->clientport->write("*Maildropsize: " + sizeof(id->maildrop)-1 + "\n");
}

void retrieve_mail(mixed id, int msgno, int lines)
{ mapping mail = id->maildrop[msgno];
  mixed   refno= mail->refno;
//  id->clientport->write("*RefNo: " + refno + "\n"); 
  if (refno)
  { Stdio.File f0 = clientlayer->load_body_get_obj(mail->body_id);
    if (f0)
    { Stdio.FILE f = Stdio.FILE(); f->assign(f0);
      mixed s;
      id->clientport->write("+OK Mail data follows.\r\n");
      while ((s = f->gets()) != 0)
      { if (stringp(s) && sizeof(s) > 0 && s[0] == ".")
               id->clientport->write(".");
        id->clientport->write(s);
        if (sizeof(s) < 2 || s[sizeof(s)-2..] != "\r\n")
            id->clientport->write("\r\n");
        if (s == "\n" || s == "\r\n" || s == "") break;
      }
      while ((s = f->gets()) != 0 && (--lines != -1))
      { if (stringp(s) && sizeof(s) > 0 && s[0] == ".")
               id->clientport->write(".");
        id->clientport->write(s);
        if (sizeof(s) < 2 || s[sizeof(s)-2..] != "\r\n")
            id->clientport->write("\r\n");
      }
      id->clientport->write(".\r\n");
      return;
    }
  }

  /* else */

  id->clientport->write("-ERR No such message.\r\n");
}

void pop3_delete_mail(mapping id, mapping mail)
{ /* Delete a mail in the INBOX. Might want to move it to
   * a separate "POP3DELETED" folder instead, so that IMAP
   * and other ways of accessing the mail database can still
   * find it.
   */
//  clientlayer->delete_mail(mail->refno);
}

void client_read_callback(mixed id, string data)
{ if (id->data) data = id->data + data;

  array a = data / "\r\n";

  int i, m;

  id->lastactiontime = time();

  for(i = 0; i < sizeof(a); ++i)
  { string cmd = a[i];

    cmd = (cmd / "\n")[0];

    if (i == sizeof(a)-1 && cmd != "")
    { /* incomplete command */
      id->data = cmd;
      return;
    }

    if (sizeof(cmd) > 512)
    { id->clientport->write("-ERR Command line too long.\r\n");
      continue;
    }

    switch (upper_case(cmd[0..3]))
    {
      case "USER":
        if (id->state != "AUTHORIZATION")
        { id->clientport->write("-ERR Not allowed.\r\n");
          break;
        }

   /*** INSERT CHECK FOR WHICH AUTH. MECHANISM IS ALLOWED FOR THIS USER ***/

        id->username = cmd[5..];
        id->clientport->write("+OK User '" + cmd[5..] + "'.\r\n");
        break;

      case "PASS":
        if (id->state == "AUTHORIZATION" && id->username)
        { if (id->username == "test" && cmd[5..99] == "auto")
          { id->clientport->write("+OK Logged in as '" + id->username +
                                         "'.\r\n");
            id->user_id = 4;
            init_transaction_state(id);
            break;
          }
          else if (id->user_id =
              clientlayer->authenticate_user(id->username, cmd[5..]))
          { id->clientport->write("+OK Logged in as '" + id->username +
                                  "'.\r\n");
            init_transaction_state(id);
            break;
          }
        }
        id->clientport->write("-ERR Not allowed.\r\n");
        id->username = 0;
        id->user_id  = 0;
        break;

      case "APOP":
        array apop = cmd / " ";
        if (id->state == "AUTHORIZATION" && sizeof(apop) == 3)
        {
          /* INSERT PROPER DIGEST CHECKING HERE */
          if (apop[1] == "test")
          { id->clientport->write("+OK Logged in as '" + id->username +
                                         "'.\r\n");
            id->user_id = 4;
            init_transaction_state(id);
            break;
          }
        }
        id->clientport->write("-ERR Failed.\r\n");
        break;

      case "STAT":
        if (id->state != "TRANSACTION")
        { id->clientport->write("-ERR Not allowed.\r\n");
          break;
        }

        int message_count = 0;
        int message_bytes = 0;

        if (sizeof(id->maildrop) > 1)
        { int n;
          for(n = 1; n < sizeof(id->maildrop); ++n)
          { mapping mail = id->maildrop[n];
            if (!mail->deleted)
            { message_count += 1;
              message_bytes += mail->size;
            }
          }
        }

        id->clientport->write("+OK " + message_count + " " +
                                       message_bytes + "\r\n");
        break;

      case "LIST":
        if (id->state == "TRANSACTION")
        { int msgno;
          if (sscanf(cmd[5..], "%d", msgno) > 0)
          { if (msgno > 0 && msgno < sizeof(id->maildrop) &&
                ! id->maildrop[msgno]->deleted)
            { id->clientport->write("+OK " + msgno + " " +
                    id->maildrop[msgno]->size + "\r\n");
              break;
            }
          }
          else
          { int msgno;
            id->clientport->write(
                   sizeof(id->maildrop) < 2
                     ? "+OK Scan listing follows (but is empty).\r\n"
                     : "+OK Scan listing follows.\r\n");
            for(msgno = 1; msgno < sizeof(id->maildrop); ++msgno)
               if (!id->maildrop[msgno]->deleted)
                   id->clientport->write(msgno + " " +
                       id->maildrop[msgno]->size + "\r\n");
            id->clientport->write(".\r\n");
            break;
          }
        }
        id->clientport->write("-ERR Failed.\r\n");
        break;

      case "RETR":
        if (id->state == "TRANSACTION")
        { int msgno;
          if (sscanf(cmd[5..], "%d", msgno) == 1)
          { if (msgno > 0 && msgno < sizeof(id->maildrop))
            { if (!id->maildrop[msgno]->deleted)
              { retrieve_mail(id, msgno, -1);
                break;
              }
            }
          }
        }
        id->clientport->write("-ERR Failed.\r\n");
        break;

      case "TOP ":
        if (id->state == "TRANSACTION")
        { int msgno, lines;
          if (sscanf(cmd[4..], "%d %d", msgno, lines) == 2)
          { if (msgno > 0 && msgno < sizeof(id->maildrop))
            { if (!id->maildrop[msgno]->deleted)
              { retrieve_mail(id, msgno, lines);
                break;
              }
            }
          }
        }
        id->clientport->write("-ERR Failed.\r\n");
        break;

      case "DELE":
        if (id->state == "TRANSACTION")
        { int msgno;
          if (sscanf(cmd[5..], "%d", msgno) == 1)
          { if (msgno > 0 && msgno < sizeof(id->maildrop))
            { if (!id->maildrop[msgno]->deleted)
              { id->maildrop[msgno]->deleted = 1;
                id->clientport->write("+OK Message " + msgno +
                         " marked for deletion.\n");
                break;
              }
            }
          }
        }
        id->clientport->write("-ERR Failed.\r\n");
        break;

      case "NOOP":
        id->clientport->write("+OK\r\n");
        break;

      case "RSET":
        if (id->state == "TRANSACTION")
        { foreach (id->maildrop, mapping mail)
            if (mail)
              mail->deleted = 0;
          id->clientport->write("+OK\r\n");
          break;
        }
        id->clientport->write("-ERR Only allowed in transaction state.\r\n");
        break;

      case "QUIT":
        id->clientport->write("+OK Closing connection.\r\n");
        id->clientport->close();
        if (id->state == "TRANSACTION")
        { foreach (id->maildrop, mapping mail)
          { if (mail->deleted)
            { /* The mail was marked for deletion, so delete it. */
              pop3_delete_mail(id, mail);
            }
          } 
        }
        client_close_callback(id);
        return;

          
      case "":
        break;

      default:
        id->clientport->write("-ERR Unknown command.\r\n");
        break;
    }
  }
  id->data = "";
}

void new_session_callback()
{ object newclient = ListenPort->accept(); mixed id;
  if (newclient)
  { newclient->set_id(id = 
        ([ "clientport": newclient,
           "lastactiontime": time(),
           "timestamp" : "<" + serial + "." + time() +
                         "@" + gethostname() + ">",
           "state"     : "AUTHORIZATION",
        ])
      );
    serial = (serial + 1) % 10000;
    newclient->write("+OK POP3. Timestamp: " + id->timestamp + "\r\n");

    newclient->set_read_callback(client_read_callback);
    newclient->set_close_callback(client_close_callback);

    if (sizeof(CurrentSessions) > 10)
    { int i;
      for(i = 0; i < sizeof(CurrentSessions); ++i)
      { if (CurrentSessions[i] == 0)
        { CurrentSessions[i] = id;
          return;
        }
      }
    }
    CurrentSessions += ({ id });
  }
}

void periodic_callback()
{ int portno = query(LISTENPORT);

  if (!ListenPort || ListenPortNo != portno)
  { object newport = Stdio.Port();

    if (newport->bind(portno, new_session_callback))
    { ListenPort   = newport;
      ListenPortNo = portno;
    }
  }

  int timeout;
  if (sscanf(query(TIMEOUT), "%d", timeout) == 1)
       timeout *= 60;
    else
       timeout  = 600; // ten minutes is default

  call_out(periodic_callback, timeout < 900 ? timeout/3 : 300);

  int i;
  for(i = 0; i < sizeof(CurrentSessions); ++i)
  { mixed id = CurrentSessions[i];
    if (mappingp(id) && id->lastactiontime + timeout < time())
    { destruct(id->clientport);
      CurrentSessions[i] = 0;
    }
  }
}

void stop()
{ if (ListenPort) destruct(ListenPort);
  foreach(CurrentSessions, mixed id)
     if (mappingp(id) && id->clientport)
       destruct(id->clientport);
  CurrentSessions = ({ });
}

void start(int flag, object config)
{ conf = config;

  if (conf && !clientlayer)
        clientlayer = config->get_provider("automail_clientlayer");

  periodic_callback();
}
