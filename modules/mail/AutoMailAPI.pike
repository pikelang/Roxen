// AutoSite Mail API
// $Id: AutoMailAPI.pike,v 1.6 1998/07/23 11:28:49 leif Exp $
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
{ string s = "<B>Database</B>: " + db_status;
  if (last_insert_id)
  { s += "<BR>\n<B>ID of most recent insert</B>: " + last_insert_id;
  }
  int user_id = this_object()->find_user("test");
  s += "<BR>\n<B>ID of user 'test'</B>: " + user_id;
  
  return s;
}        

array register_module()
{ return ({ 0, "AutoMail Database API Module", "", 0, 1 });
}

mixed get_mail_contents(int mail_id)
{ if (!database) return -1;
  object result = database->big_query(
        "SELECT contents FROM mail WHERE mail_id="+mail_id);
  array row = result->fetch_row();
  if (!row) return 0;
  return row[0];
}

mixed get_mail_header(int mail_id)
{ if (!database) return -1;
  object result = database->big_query(
        "SELECT header FROM mail WHERE mail_id="+mail_id);
  array row = result->fetch_row();
  if (!row) return 0;
  return row[0];
}

int new_mail(string from, string header, string contents)
{ if (!database) return -1;

  // Note: this is not nice if maildata contains bad characters,
  // or is very large. A better way of doing this is desirable.

  database->big_query("INSERT INTO messages (sender,header,contents) "
                    + "VALUES (:from,:header,:contents)",
                      ([ "from": from,
                         "header": header,
                         "contents": contents
                       ])
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
  if (sizeof(a) == 2)
  { string user_name = a[0];
    string mail_addr = a[1];
    object result =
      database->big_query("SELECT id,username,aliasname FROM users "
                      "WHERE username=" + user_name +
                      "OR aliasname=" + user_name);
    array  row;
    int    aliasmatch = -1;
    while (row = result->fetch_row())
    { if (row[1] == user_name)
         return row[0];
      if (row[2] == user_name)
         aliasmatch = row[0];
    }
    if (aliasmatch != -1) return aliasmatch;
  }
  // Match in other ways?

  // Fail.
  return 0;
}

mixed add_receiver(int mail_id, int user_id, string folder)
{ if (!database) return -1;

  database->big_query("INSERT INTO mailboxes (user_id,message_id,folder) "
            "VALUES (:user_id,:mail_id,:folder)",
                      ([ "user_id": user_id,
                         "mail_id": mail_id,
                         "folder": folder
                      ])
                 );

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

  string request = "SELECT mail_id,from,subject,date FROM mailboxes WHERE ";
  object result;

  if (folder) request += "folder='" + folder + "' AND ";
  request += "user_id=" + user_id + " AND received IS NULL";

  return mailbox_entries(database->big_query(request));
}

mixed mark_as_received(int mail_id, int user_id)
{ if (!database) return -1;
  database->big_query("UPDATE mailboxes SET received=NOW() "
               "WHERE mail_id="+mail_id+" AND user_id="+user_id);
  return 1;
}

mixed delete_from_mailbox(int mail_id, int user_id)
{ if (!database) return -1;

  object result = database->big_query("SELECT * FROM mailboxes "
               "WHERE mail_id="+mail_id+" AND user_id="+user_id);

  if (!result->fetch_row())
                 return 0;

  database->big_query("DELETE FROM mailboxes "
               "WHERE mail_id="+mail_id+" AND user_id="+user_id);

  return 1;
}

mixed get_all_mail_in_folder(int user_id, void|string folder)
{ string where;
  object result;

  while (folder[0] == " ") folder = folder[1..40];

  if (folder && folder != "")
    return mailbox_entries(database->big_query(
      "SELECT mail_id,from,subject,date"
      " WHERE folder='" + folder + "' AND user_id=" + user_id));
  else  
    return mailbox_entries(database->big_query(
      "SELECT mail_id,from,subject,date"
      " WHERE user_id=" + user_id));
}

int start()
{ if (!database)
  { database = Sql.sql(query(DBURL));
    if (!database) db_status = "not connected";
              else db_status = "connected (" + database->host_info() + ")";
  }
}
