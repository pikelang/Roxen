// $Id$

#include <config_interface.h>
#include <roxen.h>
//<locale-token project="roxen_config"> LOCALE </locale-token>
#define LOCALE(X,Y)  _STR_LOCALE("roxen_config",X,Y)

mapping parse(RequestID id)
{
  string res="";

  RequestID nid = id;

  while (nid->misc->orig && !nid->my_fd) {
    nid = nid->misc->orig;
  }

  if (!nid->misc->config_user->auth("Edit Users")) {
    return Roxen.http_string_answer(LOCALE(226, "Permission denied"),
                                    "text/html");
  }

  foreach (sort(roxen.list_admin_users()), string uid) {
    object u  = roxen.find_admin_user(uid);
    res += "<h3 class='section'>" + uid + "</h3>";
    res += u->form(nid);
  }

  do {
    id->variables = nid->variables;
    id = id->misc->orig;
  } while (id);

  return Roxen.http_string_answer(res, "text/html");
}
