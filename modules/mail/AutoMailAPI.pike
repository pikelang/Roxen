// AutoSite Mail API
// $Id: AutoMailAPI.pike,v 1.9 1998/07/25 21:53:59 leif Exp $
// Leif Stensson, July 1998.

#include <module.h>
inherit "module";
inherit "roxenlib";

#define DBURL    "Database URL"

object database;
string db_status = "not connected yet";
int    last_insert_id = 0;

void create()
{ defvar(DBURL, "mysql://auto:site@kopparorm.idonex.se/autosite",
         DBURL, TYPE_STRING,
         "The URL of the database holding the tables 'users', "
         "'mailboxes' and 'messages'."
        );

  roxen->set_var("AutoMailAPI_hook", this_object());
}

string status()
{ string s = "<B>Module version</B>:" +
                  (("$Revision: 1.9 $"/":")[1]/"$")[0] +
                  (("$Date: 1998/07/25 21:53:59 $"/"e:")[1]/"$")[0] +
                  (("$Author: leif $"/"or:")[1]/"$")[0] + "<BR>\n";
  s += "<B>Database</B>: " + db_status;
  if (last_insert_id)
  { s += "<BR>\n<B>ID of most recent insert</B>: " + last_insert_id;
  }
#ifdef DEBUG
  int user_id = this_object()->find_user("test");
  s += "<BR>\n<B>ID of user 'test'</B>: " + user_id;
  s += "<BR>\n<B>Header of msg 1</B>: " + this_object()->get_mail_header(1) + "\n";
  s += "<BR>\n<B>Contents of msg 1</B>: " + this_object()->get_mail_contents(1) + "\n";

  if (get_mail_header(2) == 0)
  { new_mail("test@test", "Subject: New test.", "New test contents.");
    s += "<BR>\nTest message added.\n";
    add_receiver(2, 1);
  }

  array news = get_new_mail(1);
  s += "<BR>\n<B>New mail(s) for user 1</B>:" + sizeof(news);
  if (sizeof(news))
  { s += "<BR>\n---First new mail id: " + news[0]["mail_id"] + "\n";
  }
#endif

  return s;
}        

array register_module()
{ return ({ 0, "AutoMail Database API Module", "", 0, 1 });
}

mixed get_mail_contents(int mail_id)
{ if (!database) return -1;
  object result = database->big_query(
        "SELECT contents FROM messages WHERE id="+mail_id);
  array row = result->fetch_row();
  if (!row) return 0;
  return row[0];
}

mixed get_mail_header(int mail_id)
{ if (!database) return -1;
  object result = database->big_query(
        "SELECT header FROM messages WHERE id="+mail_id);
  array row = result->fetch_row();
  if (!row) return 0;
  return row[0];
}

string mysql_quote_string(string s)
{ string result = "", tmp = "", c; int i;

  // This is potentially slow and might cause a lot of
  // work for the garbage collector, but it will do for
  // now.

  for(i = 0; i < sizeof(s); ++i)
  { c = s[i..i];
    if      (c ==  "'") c = "\\'";
    else if (c == "\"") c = "\\\"";
    else if (c == "\\") c = "\\\\";
    else if (c == "\0") c = "\\0";
    tmp += c;
    if (i % 100 == 99)
    { result += tmp;
      tmp = "";
    }
  }
  return result + tmp;
}


int new_mail(string from, string header, string contents)
{ if (!database) return -1;

  array header_lines = (header) / "\n";
  string subject = "";
  int i;
  for(i = 0; i < sizeof(header_lines); ++i)
     if (header_lines[i][0..7] == "Subject:")
        subject = header_lines[i][9..99];

  while (subject[0..0] == " ") subject = subject[1..99];

  database->big_query("INSERT INTO messages (from_addr,header,contents,date,subject) "
                    + "VALUES ('" + mysql_quote_string(from) + "',"
                              "'" + mysql_quote_string(header) + "',"
                              "'" + mysql_quote_string(contents) + "',"
                              "NOW(),"
                              "'" + mysql_quote_string(subject) + "')"
                     );

  // Extract the mail ID number.
  
  return last_insert_id = database->master_sql->insert_id();
}

int find_user(string user_address)
// Find an internal user id number given a user's email
// address.
{ array a = user_address / "@";
  if (sizeof(a[0] / " ") != 1) return -1; // space not allowed in names
  if (!database) return -1;
  if (a[0] != "")
  { string user_name = a[0];
    string mail_addr = sizeof(a)>1 ? a[1] : "";
    object result =
      database->big_query("SELECT id,username,aliasname FROM users "
                      "WHERE username='" + user_name + "' "
                      "OR aliasname='" + user_name + "'");
    array  row;
    int    aliasmatch = -1;
    while (row = result->fetch_row())
    { int id;
      if (!sscanf(row[0], "%d", id)) continue; 
      if (row[1] == user_name)
         return id;
      if (row[2] == user_name)
         aliasmatch = id;
    }
    if (aliasmatch != -1) return aliasmatch;
  }
  // Match in other ways?

  // Fail.
  return 0;
}

mixed add_receiver(int mail_id, int user_id, void|string folder)
{ if (!database) return -1;

  object res = database->big_query("SELECT from_addr,date,subject "
                     "FROM messages WHERE id="+mail_id);

  object msg_data = res->fetch_row();

  if (!msg_data) return 0;

  string req;

  if (folder)
       req = "INSERT INTO mailboxes (user_id,message_id,from_addr,date,subject,folder) ";
  else req = "INSERT INTO mailboxes (user_id,message_id,from_addr,date,subject) ";

  req += "VALUES (" + user_id + "," + mail_id + ","
                      "'"+mysql_quote_string(msg_data[0])+"',"
                      "'"+mysql_quote_string(msg_data[1])+"',"
                      "'"+msg_data[2]+"'";

  if (folder) req += ",'"+mysql_quote_string(folder) + "'";

  database->big_query(req + ")");

  return 1;
}

int has_receiver(int mail_id, int user_id)
{ if (!database) return -1;
  object res = database->big_query("SELECT folder FROM mailboxes "
                   "WHERE message_id="+mail_id+" AND user_id="+user_id);
  array row = res->fetch_row();
  if (row)
  { if (row[0] == 0 || row[0] == "")
         return 1;
    return row[0];
  }
  return 0;
}


static mixed mailbox_entries(object query_result)
{ array row, news = 0;

  while (row = query_result->fetch_row())
  { if (news == 0) news = ({ });
    news += ({ ([ "mail_id": row[0],
                  "from"   : row[1],
                  "subject": row[2],
                  "date"   : row[3] ]) });
  }

  return news;
}

mixed get_new_mail(int user_id, void|string folder)
//
// Gets all unread (= not marked as received) mail. If
// the 'folder' argument is given, only mail from that
// folder will be listed.
//
// Returns an array of mappings with the fields
// "mail_id", "from", "subject" and "date".
//
{ if (!database) return -1;

  string request = "SELECT message_id,from_addr,subject,date FROM mailboxes WHERE ";
  object result;

  if (folder) request += "folder='" + folder + "' AND ";
  request += "user_id=" + user_id + " AND received IS NULL";

  return mailbox_entries(database->big_query(request));
}

mixed mark_as_received(int mail_id, int user_id)
{ if (!database) return -1;
  database->big_query("UPDATE mailboxes SET received=NOW() "
               "WHERE message_id="+mail_id+" AND user_id="+user_id);
  return 1;
}

mixed delete_from_mailbox(int mail_id, int user_id)
{ if (!database) return -1;

  object result = database->big_query("SELECT * FROM mailboxes "
               "WHERE message_id="+mail_id+" AND user_id="+user_id);

  if (!result->fetch_row())
                 return 0;

  database->big_query("DELETE FROM mailboxes "
               "WHERE message_id="+mail_id+" AND user_id="+user_id);

  return 1;
}

mixed get_all_mail_in_folder(int user_id, void|string folder)
{ string where;
  object result;

  while (folder[0] == " ") folder = folder[1..40];

  if (folder && folder != "")
    return mailbox_entries(database->big_query(
      "SELECT message_id,from_addr,subject,date"
      " WHERE folder='" + folder + "' AND user_id=" + user_id));
  else  
    return mailbox_entries(database->big_query(
      "SELECT message_id,from_addr,subject,date"
      " WHERE user_id=" + user_id));
}

int start()
{ if (!database)
  { database = Sql.sql(query(DBURL));
    if (!database) db_status = "not connected";
              else db_status = "connected (" + database->host_info() + ")";
  }
}
