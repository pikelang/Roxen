#include <roxen.h>

constant box = "large";
constant box_initial = 1;

string box_name = "Server schedule";
string box_doc = "Upcoming server events";


constant css = #"
  tr.sched {
    cursor: default;
    color: #000;
  }
  tr.sched td {
    font-size: 12px;
  }
  tr.sched.first td {
    padding: 8px 12px 2px;
    white-space: nowrap;
  }
  tr.sched td.next {
    color: #073;
    padding-right: 0;
  }
  tr.sched td.next .disabled {
    color: #000;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    opacity: 0.4;
  }
  tr.sched.off td.mod,
  tr.sched.off td.desc div {
    opacity: 0.4;
  }
  tr.sched td.mod .varname {
    font-weight: bold;
  }
  tr.sched:not(.off) td.mod .modname {
    display: inline-block;
    outline: 2px solid #ffffbf;
    background-color: #ffffbf;
  }
  tr.sched.second td {
    padding: 0 12px 8px;
    white-space: nowrap;
  }
  tr.sched.second:not(:last-child) td {
    border-bottom: 1px solid #ddd;
  }
  tr.sched td.next-rel {
    font-size: 11px;
    color: #9b9;
  }
  tr.sched td.desc div {
    font-size: 11px;
    opacity: 0.7;
  }
  tr.sched td.desc p {
    margin: 0;
    padding: 0;
  }";


int(-1..1) list_schedule_var(Variable.Variable vv,
                             mapping(string:Variable.Variable) all_vars)
{
  if (object_program(vv) != Variable.Schedule)
    return 0;

  //  Check if variable has been linked to another variable which in turn
  //  is disabled. This is typical when a separate on/off setting is used.
  if (string|function link_enabled = vv->get_link_enabled()) {
    if (functionp(link_enabled)) {
      return link_enabled();
    } else if (Variable.Variable link_enabled_var = all_vars[link_enabled])
      if (!link_enabled_var->query()) {
        //  Include but list as disabled
        return -1;
      }
  }
  return 1;
}

int get_next_run(Variable.Variable vv,
                 mapping(string:Variable.Variable) all_vars)
{
  if (object_program(vv) != Variable.Schedule)
    return -1;

  int last_run_ts = 0;
  if (string|function link_last_run = vv->get_link_last_run()) {
    if (functionp(link_last_run)) {
      last_run_ts = link_last_run();
    } else if (Variable.Variable link_last_run_var = all_vars[link_last_run]) {
      last_run_ts = link_last_run_var->query();
    }
  }
  return vv->get_next(last_run_ts);
}

string get_next_rel(int ts)
{
  int now = time();
  if (ts < 0)
    return "&nbsp;";
  if (ts < now)
    return "&nbsp;";
  array(string) parts = ({ });
  int delta = ts - now;
  if (delta >= 86400) {
    int days = delta / 86400;
    parts += ({ sprintf("%dd ", days) });
    delta -= days * 86400;
  }
  if (delta >= 3600) {
    int hours = delta / 3600;
    parts += ({ sprintf("%dh", hours) });
    delta -= hours * 3600;
  }
  if (delta >= 60) {
    int minutes = delta / 60;
    parts += ({ sprintf("%dm", minutes) });
    delta -= minutes * 60;
  }
  if (!sizeof(parts))
    return "(imminent)";
  return "(in " + (parts * " ") + ")";
}

string get_next_msg(int next_ts)
{
  string msg =
    (next_ts < 0) ? "<span class='disabled'>Disabled</span>" :
    Roxen.strftime("%a, %b %e, at %H:%M", next_ts);
  if ((next_ts >= 0) && (next_ts <= time()))
    msg = "Running...";
  return msg;
}

string get_sort_key(int next_ts, string conf_name, string var_name)
{
  return
    sprintf("%020d:%s:%s",
            next_ts < 0 ? Int.NATIVE_MAX : next_ts,
            conf_name || "",
            lower_case(var_name || ""));
}

string beautify_group_name(string group_name)
{
  return
    Roxen.html_encode_string(map(group_name / ":",
                                 String.trim_all_whites) * " \u203a ");
}

string trim_desc(string desc)
{
  desc = (string) desc;
  if (sizeof(desc) < 50)
    return desc;
  if (has_value(desc, "</p>"))
    return (desc / "</p>")[0];
  if (has_value(desc, ". "))
    return (desc / ". ")[0] + ".";
  return desc;
}

string parse(RequestID id)
{
  mapping(string:Variable.Variable) vars = ([ ]);
  mapping(Variable.Variable:int) next_run = ([ ]);
  mapping(string:RoxenModule) mod_lookup = ([ ]);

  //  Find eligible Variable.Schedule instances
  foreach (roxen->variables; string key; Variable.Variable gv) {
    if (int status = list_schedule_var(gv, roxen->variables)) {
      vars["_global:" + key] = gv;
      next_run[gv] = (status > 0) ? get_next_run(gv, roxen->variables) : -1;
    }
  }
  foreach (roxen->configurations, Configuration c) {
    foreach (c->variables; string key; Variable.Variable cv) {
      if (int status = list_schedule_var(cv, c->variables)) {
        vars[c->name + ":" + key] = cv;
        next_run[cv] = (status > 0) ? get_next_run(cv, c->variables) : -1;
      }
    }
    foreach (c->modules; string modname; object modcopies) {
      foreach (values(modcopies), RoxenModule mod) {
        foreach (mod->variables; string key; Variable.Variable mv) {
          if (int status = list_schedule_var(mv, mod->variables)) {
            string mod_id = mod->module_identifier();
            mod_lookup[mod_id] = mod;
            vars[mod_id + ":" + key] = mv;
            next_run[mv] = (status > 0) ? get_next_run(mv, mod->variables) : -1;
          }
        }
      }
    }
  }

  //  Collect rows to display based on global, configuration and module
  //  variables.
  int now = time();
  array(mapping) rows = ({ });
  foreach (vars; string key; Variable.Schedule sv) {
    string mod_id = (key / ":")[0];
    RoxenModule m = mod_lookup[mod_id];
    string mod_name =
      (mod_id == "_global") ? 0 : beautify_group_name(m->module_name);
    string conf_name =
      m ? Roxen.html_encode_string(m->my_configuration()->name) :
      "Global Settings";
    string curl =
      (m && conf_name) ?
      ("/sites/site.html/" + replace(conf_name, " ", "%20") + "/") :
      "/global_settings/?section=Auto%20Maintenance&amp;&usr.set-wiz-id;";
    string mname = m && Roxen.get_modfullname(m);
    string mgroup = "zz_misc";
    if (mname) {
      if (sscanf(mname, "%s:%*s", mgroup) != 2)
        mgroup = "zz_misc";
      if (mgroup == "zz_misc") mgroup = "Other";
    }
    string murl =
      m && (curl +
            Roxen.http_encode_invalids(mgroup) + "!0/" +
            replace(m->sname(), "#", "!") +
            "/?section=Status&amp;&usr.set-wiz-id;");
    string var_name = beautify_group_name(sv->name());
    int next_ts = next_run[sv];
    mapping row = ([
      "var_name":  var_name,
      "mod_name":  mod_name,
      "conf_name": conf_name,
      "mod_desc":  trim_desc(sv->doc() || ""),
      "disabled":  next_ts < 0,
      "next_ts":   next_ts,
      "next_msg":  get_next_msg(next_ts),
      "next_rel":  get_next_rel(next_ts),
      "curl":      curl,
      "murl":      murl,
      "sort_key":  get_sort_key(next_ts, conf_name, var_name) ]);
    rows += ({ row });
  }

  //  Add special entries for built-in DB backup
  array(mapping) db_backups = DBManager.get_pending_backups();
  if (!sizeof(db_backups))
    db_backups = ({ 0 });
  foreach (db_backups, void|mapping info) {
    int next_ts = info ? info->abs_start_ts : -1;
    string mod_desc =
      info ?
      ("Run backup schedule \u201c" + info->schedule + "\u201d.") :
      "No active schedule.";
    rows += ({
      ([ "var_name":  "Backup",
         "mod_name":  0,
         "conf_name": "Database Manager",
         "mod_desc":  Roxen.html_encode_string(mod_desc),
         "disabled":  !info,
         "next_ts":   next_ts,
         "next_msg":  get_next_msg(next_ts),
         "next_rel":  get_next_rel(next_ts),
         "curl":      "/dbs/schedules.html",
         "murl":      0,
         "sort_key":  get_sort_key(next_ts, "", "Backup") ])
    });
  }

  //  Add search engine schedules since they are wrapped inside profiles
#if constant(Search)
  foreach (roxen->configurations, Configuration c) {
    if (RoxenModule search_mod = c->get_provider("sb_plugin_search")) {
      mapping(string:int) db_profiles = search_mod->list_db_profiles();
      foreach (db_profiles; string name; int profile_id) {
        if (object db_prof = search_mod->get_profile(profile_id)) {
          foreach (db_prof->vars; string key; Variable.Variable vv) {
            if (list_schedule_var(vv, db_prof->vars)) {
              string var_name = beautify_group_name(vv->name());
              string mod_name =
                "<span class='modname'>" +
                Roxen.html_encode_string("Search profile \u201c" +
                                         db_prof->name + "\u201d") +
                "</span>";
              string conf_name = Roxen.html_encode_string(c->name);
              int next_ts = get_next_run(vv, db_prof->vars);
              string curl =
                "/sites/site.html/" + replace(conf_name, " ", "%20") + "/";
              rows += ({
                ([ "var_name":  var_name,
                   "mod_name":  mod_name,
                   "conf_name": conf_name,
                   "mod_desc":  trim_desc(vv->doc() || ""),
                   "disabled":  next_ts < 0,
                   "next_ts":   next_ts,
                   "next_msg":  get_next_msg(next_ts),
                   "next_rel":  get_next_rel(next_ts),
                   "curl":      curl,
                   "murl":      0,
                   "sort_key":  get_sort_key(next_ts, conf_name, var_name)
                ]) });
            }
          }
        }
      }
    }
  }
#endif

  //  Sort and generate HTML
  string res = "";
  sort(rows->sort_key, rows);
  foreach (rows, mapping row) {
    string disabled_cls = (row->disabled ? " off" : "");
    res +=
      "<tr class='sched first " + disabled_cls + "'>"
        "<td class='next'>" + row->next_msg + "</td>"
        "<td class='mod'>"
          "<span class='varname'>" + row->var_name + "</span>" +
      ((row->murl || row->mod_name) ?
          (" in " +
           (row->murl ?
            ("<a class='modname' href='" + row->murl + "'>" +
             row->mod_name + "</a>") :
            ("<span class='Xmodname'>" + row->mod_name + "</span>"))) : "") +
      ((sizeof(row->conf_name) && row->curl) ?
          (" in "
           "<a class='confname' href='" + row->curl + "'>" +
           row->conf_name + "</a>") : "") +
          "."
        "</td>"
      "</tr>"
      "<tr class='sched second " + disabled_cls + "'>"
        "<td class='next-rel'>" + row->next_rel + "</td>"
        "<td class='desc'><div>" + row->mod_desc + "</div></td>"
      "</tr>";
  }

  return
    "<box type='" + box + "' title='" + box_name + "'>"
    "<style type='text/css'>" + css + "</style>"
    "<table cellpadding='0' cellspacing='0' border='0'>" + res + "</table>"
    "</box>";
}

