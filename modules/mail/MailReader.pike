// AutoSite Mail Reader (Test)
// $Id: MailReader.pike,v 1.1 1998/08/07 02:32:23 leif Exp $
// Leif Stensson, July/August 1998.

#include <module.h>
inherit "module";
inherit "roxenlib";

#define MOUNTP     "Mail Reader Mountpoint"
#define ADMIN_USER "Administrator User Name"
#define ADMIN_PASS "Administrator Password"

#define ADMINHEAD  "<HTML>\n<HEAD>\n<TITLE>AutoMail Administration"
#define ADMINTAIL  "</TITLE>\n</HEAD>\n"
#define BODYTAG    "<BODY BGCOLOR=#ffffff TEXT=#000000>\n"
#define ENDTAGS    "\n</BODY>\n</HTML>\n"

#define SINGLE_CUSTOMER  1

static mapping user_cache = ([ ]);

static object AutoMailAPI;

void create()
{ defvar(MOUNTP, "/mail/",
         MOUNTP, TYPE_STRING,
         "Where to mount the AutoMail Reader entry pages.");

  defvar(ADMIN_USER, "mailadm",
         ADMIN_USER, TYPE_STRING,
         "The login name of the AutoMail administrator.");

  defvar(ADMIN_PASS, "mailpass",
         ADMIN_PASS, TYPE_PASSWORD,
         "The login password of the AutoMail administrator.");
}

array register_module()
{ return ({ MODULE_LOCATION, "AutoMailTest Module", "", 0, 1 });
}

string query_location()
{ return query(MOUNTP);
}

string status()
{ if (!AutoMailAPI) return "<B>Error</B>: MailAPI module not found.";
  return "OK.";
}

static int get_user_id(string name)
{ int user_id = user_cache[name];
  if (user_id) return user_id;
  if (!AutoMailAPI) return 0;
  user_id = AutoMailAPI->find_user(name);
  if (user_id < 1) return 0;
  return user_id;
}

static string mountpoint()
{ string m = query(MOUNTP);
  if (m[sizeof(m)-1..] != "/") m += "/";
  return m;
}


mixed find_file(string fname, object id)
{ if (id->realauth == 0)
     return http_auth_required("AutoMail");

  string auth = id->realauth;
  string user = (auth / ":")[0];
  string pass = "";
  if (sizeof(auth / ":") > 1)
         pass = (auth/":")[1];

  if (fname[0..0] == "/") fname = fname[1..];

  int user_id = get_user_id(user);

  if (!user_id)
  { if (AutoMailAPI)
      return http_auth_required("AutoMail");
    else
      return http_low_answer(200, "<H2>Service unavailable</H2>");
  }

  array component = fname / "/";

  string page = "<HTML><HEAD><TITLE>AutoMail User: " + user +
                    "</TITLE>\n</HEAD>\n" BODYTAG;

  page += "<B>AutoMail</B><BR>";
  if (component[0] != "mailbox" && component[0] != "")
      page += "<A HREF=" + query(MOUNTP) + "mailbox>Mailbox</A> ";
  if (component[0] != "archive")
      page += "<A HREF=" + query(MOUNTP) + "archive>Mail Archive</A> ";

  if (component[0] == "mail")
  { if (sizeof(component) == 2 || sizeof(component) == 3)
    { int mail_id; string flag = 0;
      if (sizeof(component) == 3 && component[2] != 0 && component[2] != "")
              flag = component[2];
      if (sscanf(component[1], "%d", mail_id))
      { if (AutoMailAPI->has_receiver(mail_id, user_id))
        { string h = AutoMailAPI->get_mail_header(mail_id);
          string c = AutoMailAPI->get_mail_contents(mail_id);
          if (!flag) page += " <A HREF=" + mountpoint() + "mail/" + mail_id +
                                "/full-headers>Show Full Headers</A>\n";
               else page += " <A HREF=" + mountpoint() + "mail/" + mail_id +
                                "/>Show Brief Headers</A>\n";
          page += "<HR><H2>Message " + mail_id + "</H2>\n";
          if (flag == "full-headers")
               page += "<BLOCKQUOTE>\n<PRE>\n" + h + "\n</PRE>\n</BLOCKQUOTE>\n";
          else
          { array lines = h / "\n";
            string subj, from, date, l;
            foreach (lines, l)
            { if      (l[0..7] == "Subject:") subj = l;
              else if (l[0..4] == "Date:") date = l;
              else if (l[0..3] == "From") from = l;
            }
            page += "<BLOCKQUOTE>\n";
            if (from) page += "<B>" + from + "</B><BR>\n";
            if (date) page += "<B>" + date + "</B><BR>\n";
            if (subj) page += "<B>" + subj + "</B><BR>\n";
            page += "</BLOCKQUOTE>\n";
          }
          page += "<PRE>\n" + c + "\n</PRE>\n";
          return http_string_answer(page);
        }
        else return http_auth_required("AutoMail");
      }
      else return http_string_answer("Hmm.<BR> C[0] = '" + component[0] +
                                     "'<BR>C[1] = '" + component[1] + "'.");
    }
    component = ({ "mailbox" });
  }

  if (component[0] == "" || component[0] == "mailbox" ||
      component[0] == "archive")
  { array mails = AutoMailAPI->get_new_mail(user_id);
    if (arrayp(mails))
    { mapping item;
      if (component[0] == "archive")
              page += "<HR><H2>Mail archive for '" + user + "'</H2>\n<UL>\n";
        else  page += "<HR><H2>New mail for '" + user + "'</H2>\n<UL>\n";
      foreach (mails, item)
      { page += "<LI><A HREF=" + mountpoint() +"mail/" + item->mail_id + "/>From " +
                    item->from + " " + item->date + " Subject: " +
                    item->subject + "</A>\n";
      }
      page += "</UL>\n";
    }
    else if (component[0] == "archive")
         page += "<HR><H2>No archived mail for '" + user + "'</H2>\n";
    else page += "<HR><H2>No new mail for '" + user + "'</H2>\n";

    return http_string_answer(page + "</BODY>\n</HTML>\n");
  }

  return http_low_answer(404, "There is no such document. "
                          "C0 = '" + component[0] + "'. "
                          "fn = '" + fname + "'. "
                        );
}


void start()
{ if (!AutoMailAPI)
  { AutoMailAPI = roxen->query_var("AutoMailAPI_hook");
  }
}
