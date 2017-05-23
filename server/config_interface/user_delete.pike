#include <roxen.h>
//<locale-token project="roxen_config"> LOCALE </locale-token>
#define LOCALE(X,Y)  _STR_LOCALE("roxen_config",X,Y)

string tmpl = #"
  <ul class='nolist button-list'>
    {{ #users }}
    <li>
      <button class='icon delete-user'
        {{ #disabled}}disabled=''{{/disabled}}
        {{ ^disabled }}data-href='user_delete.pike?delete_user={{ uid }}"
          #"&amp;page=delete_user&amp;&usr.set-wiz-id;'{{ /disabled }}
      >{{ realname }} ({{ uid }})</button>
    </li>
    {{ /users }}
  </ul>";

mixed parse( RequestID id )
{
  mixed v = id->variables;

  if (!id->misc->config_user->auth("Edit Users")) {
    return LOCALE(226, "Permission denied");
  }

  while (id->misc->orig) {
    id = id->misc->orig;
  }

  if (v->delete_user && v->delete_user != "") {
    roxen.delete_admin_user(v->delete_user);
    return Roxen.http_redirect("users.html", id);
  }

  mapping mctx = ([
    "users" : ({})
  ]);

  foreach (sort(roxen.list_admin_users()), string uid) {
    object u = roxen.find_admin_user(uid);

    mctx->users += ({ ([
      "uid"      : uid,
      "realname" : u->real_name,
      "disabled" : u == id->misc->config_user
    ]) });
  }

  Mustache stache = Mustache();
  string ret = stache->render(tmpl, mctx);
  destruct(stache);

  return Roxen.http_string_answer(ret);
}
