// Copyright 2007 - 2009 Roxen Internet Software
// Contributed by:
// Digital Fractions 2007
// www.digitalfractions.net

// Note: The difference between this and the normal db_list/browse
// interfaces is that it also includes databases in the local mysql
// that aren't registered with DBManager. You need -DMORE_DB_OPTS to
// add a tab for this.

#include <config_interface.h>
#include <config.h>
#include <roxen.h>
//<locale-token project="roxen_config">_</locale-token>
#define _(X,Y)  _STR_LOCALE("roxen_config",X,Y)

#define CU_AUTH id->misc->config_user->auth

mixed query( mixed ... args ) {
  return connect_to_my_mysql( 0, "roxen" )->query( @args );
}

string|mapping parse( RequestID id )
{
  // Permissions check
  if ( !(CU_AUTH( "Edit Global Variables" )) ) return "Access denied";

  // Database table
  string res = #"
  <table class='nice db-list'>
    <thead>
      <tr>
        <th>Target</th>
        <th class='text-right'>Tables</th>
        <th class='text-right'>Rows</th>
        <th>Actions</th>
      </tr>
    </thead>
    <tbody>";

  string get_link(string action, string db, string name) {
    array(string) args = ({ });

    switch (action) {
      case "repair":
        args += ({ "repair=" + db });
        break;

      case "optimize":
        args += ({ "optimize=" + db });
        break;

      case "both":
        args += ({ "optimize=" + db, "repair=" + db });
        break;
    }

    args += ({ "&usr.set-wiz-id;" });

    return sprintf("<a href='&page.path;?%s#op'>%s</a>",
                   args*"&amp;", name);
  };

  // List databases
  mixed m = query("SHOW DATABASES");

  if (sizeof(m)) {
    foreach (m, m) {
      int table_count = 0;
      int table_rows = 0;

      mixed q = query("SHOW TABLE STATUS IN " + m->Database);

      if (sizeof(q)) {
        table_count = sizeof(q);
        table_rows  = Array.sum((array(int)) q->Rows);
      }

      res += sprintf(#"
        <tr>
          <td>
            <a href='browser.pike?db=%s&amp;&usr.set-wiz-id;'>%[0]s</a>
          </td>
          <td class='num'>%d</td>
          <td class='num'>%d</td>
          <td>%s | %s | %s</td>
        </tr>",
        m->Database,
        table_count,
        table_rows,
        get_link("repair",   m->Database, "Repair"),
        get_link("optimize", m->Database, "Optimize"),
        get_link("both",     m->Database, "Both"));
    }
  }

  res += "</tbody></table><br/>";
  res += "<link-gbutton href='db_repairall.html'>Repair all</link-gbutton> ";
  res += "<link-gbutton href='db_optimizeall.html'>Optimize all</link-gbutton>";

  // Draw result table
  if (id->variables->repair || id->variables->optimize) {
    res += #"
      <hr class='margin-top margin-bottom'>
      <table class='nice db-list' id='op'>
        <thead>
          <tr>
            <th>Target</th>
            <th>Operation</th>
            <th>Result</th>
            <th>Time</th>
          </tr>
        </thead>
        <tbody>";
  }

  // Repair and optimize
  float t3 = 0;
  mixed st;
  void do_operation(string op) {
    string db_name = id->variables->repair || id->variables->optimize;

    if (!st) {
      st = query("SHOW TABLE STATUS IN " + db_name);
    }

    if (sizeof(st)) {
      foreach (st, mapping tbl) {
        int t = time();
        float t1 = time(t);
        mixed q = query(upper_case(op) + " TABLE `" +
                        db_name + "`.`" + tbl->Name + "`");
        float t2 = (time(t)-t1);
        t3 += t2;

        string result = "";

        if (q->Msg_text = "OK") {
          result = "<span class='notify ok inline'>Ok</span>";
        }
        else {
          result = "<span class='notify error inline'>Error</span>";
        }

        res += sprintf(#"
          <tr>
            <td>
              <a href='browser.pike?db=%s&amp;%s'>%[0]s</a>.<a
               href='browser.pike?db=%[0]s&amp;table=%s&amp;%[1]s'>%[2]s</a>
            </td>
            <td>%s</td>
            <td>%s</td>
            <td>%.5f</td>
          </tr>",
          db_name,
          "&usr.set-wiz-id;",
          tbl->Name,
          op,
          result,
          t2);
      }
    }
  };

  if (id->variables->repair) {
    do_operation("Repair");
  }

  if (id->variables->optimize) {
    do_operation("Optimize");
  }

  if (id->variables->repair || id->variables->optimize) {
    res += sprintf(#"
      </tbody>
      <tfoot>
        <tr>
          <td colspan='3'>Total:</td>
          <td>%.5f</td>
        </tr>
      </tfoot>
    </table>",
    t3);
  }

  // Done
  return Roxen.http_string_answer(res);
}
