#include <module.h>
inherit "module";
inherit "roxen";

#define DBSERV   "AutoMail Database Server Machine"
#define DBNAME   "AutoMail Database Name"

object database;

void create()
{ defvar(DBSERV, "automail.idonex.se",
         DBSERV, TYPE_TEXT_FIELD,
         "The address of the machine running the MySQL database server.");

  defvar(DBNAME, "AutoMailDB",
         DBNAME, TYPE_TEXT_FIELD,
         "The name for the AutoMail database in the MySQL database server.");
}

array register_module()
{ return ({ 0, "AutoMail DBAPI Module", "", 0, 1 });
}

int new_mail(string from, string header, string contents)
{ if (!database) return -1;

  // Note: this is not nice if maildata contains bad characters,
  // or is very large. A better way of doing this is desirable.
  database->big_query("INSERT sender,header,contents INTO messages "
                    + "VALUES (:from,:header,:contents)",
                      ([ "from": from,
                         "header": header,
                         "contents": contents
                       ])
                 );
  // Extract the mail ID number.

  return database->master_sql->insert_id();
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
         return i;
      if (row[2] == user_name)
         aliasmatch = i;
    }
    if (aliasmatch != -1) return aliasmatch;
  }
  // Match in other ways?

  // Fail.
  return -1;
}

mixed add_receiver(mail_id, user_id, folder)
{ if (!database) return "unable to access AutoMail database";

  database->big_query("INSERT user_id,message_id,folder INTO mailboxes "
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
  { database = MySQL.mysql(query(DBSERV), query(DBNAME));
    if (!database) dbstat = "no connection to database";
  }
}
