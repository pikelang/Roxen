// AutoSite Mail API
// $Id: AutoMailAPI.pike,v 1.5 1998/07/22 13:53:40 leif Exp $
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
  return s;
}        

array register_module()
{ return ({ 0, "AutoMail Database API Module", "", 0, 1 });
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
  return -1;
}

mixed add_receiver(int mail_id, int user_id, string folder)
{ if (!database) return "unable to access AutoMail database";

  database->big_query("INSERT INTO mailboxes (user_id,message_id,folder) "
            "VALUES (:user_id,:mail_id,:folder)",
                      ([ "user_id": user_id,
                         "mail_id": mail_id,
                         "folder": folder
                      ])
                 );

  return 0;
}

int start()
{ if (!database)
  { database = Sql.sql(query(DBURL));
    if (!database) db_status = "not connected";
              else db_status = "connected (" + database->host_info() + ")";
  }
}
