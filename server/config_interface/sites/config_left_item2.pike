#include <config_interface.h>
#include <roxen.h>

//<locale-token project="roxen_config">LOCALE</locale-token>
#define LOCALE(X,Y)     _STR_LOCALE("roxen_config",X,Y)

private string stache_tmpl;

string noendslash(string what)
{
  while (strlen(what) && what[-1] == '/') {
    what = what[..strlen(what)-2];
  }

  return what;
}

mapping group(array(string) w)
{
  mapping groups = ([]);

  foreach (w, string n) {
    string g, s;
    ModuleInfo i = roxen.find_module(n);

    if (sscanf((string)i->get_name(), "%s:%s", g, s) == 2) {
      groups[g] += ({ n });
    }
    else {
      groups[ "zz_misc" ] += ({ n });
    }
  }

  return groups;
}

string selected_item(string q, Configuration c, RequestID id,
                     string module_group,string module)
{
  while (id->misc->orig) {
    id = id->misc->orig;
  }

  int do_js = config_setting("modulelistmode") == "js";
  int unfolded = config_setting("modulelistmode") == "uf";

  mapping m_state = ([
    "buttons_first" : ({
      ([ "name" : LOCALE(213, "Sites"),
         "href" : "/sites/" ]),

      ([ "name"       : c->query_name(),
         "class_name" : "site-name",
         "href"       : module && sizeof(module) &&
                        id->not_query + "/" + replace(c->name, " ", "%20") ])
    }),
    "module_groups" : ({}),
    "buttons_last"  : ({}),
    "list"          : false,
    "js"            : do_js
  ]);

  string url = id->not_query + id->misc->path_info;
  string pre_site_url="";
  string quoted_url = Roxen.http_encode_invalids(url);

  if (has_value(quoted_url, "!")) {
    quoted_url += "../"*(sizeof(quoted_url/"!")-1);
  }

  sscanf(id->not_query, "%ssite.html", pre_site_url);

  if (!config_perm("Site:"+c->name)) {
    return "<div class='notify error'>Permission denied</div>";
  }

  mapping gr = group(indices(c->modules));
  array module_groups = ({});

  foreach (indices(gr), string gn) {
    array gg = ({});

    foreach (gr[gn], string q) {
      ModuleInfo mi = roxen->find_module(q);

      foreach (sort(indices(c->modules[q]->copies)), int i) {
        string name, doc;
        mixed err;

        if (err=catch(name=mi->get_name()+(i?" # "+i:""))) {
          name = q + (i?" # "+i:"") + " (Generated an error)";
          report_error("Error reading module name from %s#%d\n%s\n",
                       q, i, describe_backtrace(err));
        }

        if (c->modules[q]->copies[i]->query_name) {
          if (err = catch(name=c->modules[q]->copies[i]->query_name())) {
            report_error("Cannot get module name for %s#%d\n%s\n",
                         q, i, describe_backtrace(err));
          }
        }

        if (sscanf(name, "%*s:%s", name) == 2) {
          name = String.trim_whites(name);
        }

        gg += ({ ([ "sname"      : q+"!"+i,
                    "name"       : name,
                    "deprecated" : mi->deprecated,
                    "locked"     : mi->config_locked[c] ]) });
      }
    }

    sort(map(gg->name, lower_case), gg);
    module_groups += ({ ({ gn, gg }) });
  }

  module_groups = Array.sort_array(module_groups,
                                   lambda(array a, array b) {
                                     return a[0] > b[0];
                                   });

  // TRACE("module_groups: %O\n", module_groups);

  int list = (RXML.get_var("module-list-style", "usr") == "list");

  m_state->list = list;

  if (!sizeof(module_groups)) {
    m_state->modules = UNDEFINED;
  }

  if (!has_suffix(quoted_url, "/")) {
    quoted_url += "/";
  }

  foreach (module_groups, array gd) {
    bool fold = !(unfolded || RXML.get_var("unfolded", "usr"));
    string name = gd[0];
    string r_module_group = module_group;
    bool selected = name == module_group;

    // foreach (gd[1], mapping data) {
    //   if (data->sname == module) {
    //     r_module_group = name;
    //     selected = true;
    //     break;
    //   }
    // }

    if (module_group == name) {
      fold = false;
    }

    mapping mod_section = ([
      "name"      : name == "zz_misc" ? LOCALE(525, "Other") : name,
      "real_name" : name,
      "modules"   : gd[1],
      "fold"      : fold,
      // "selected"  : !selected,
      "nmodules"  : sizeof(gd[1]),
      "url"       : (quoted_url + Roxen.http_encode_invalids(name) + "!0/" +
                     ((module && strlen(module)) ? module + "/" : ""))
    ]);

    foreach (gd[1], mapping mod) {
      if (mod->sname == module) {
        mod->selected = true;
        mod_section->fold = false;
        mod_section->selected = true;
      }
      else {
        mod->selected = false;
      }

      mod->url = quoted_url + Roxen.http_encode_invalids(name) + "!0/" +
                 mod->sname + "/";
    }

    m_state->module_groups += ({ mod_section });
  }


  // Do not allow easy addition and removal of modules to and
  // from the configuration interface server. Most of the time
  // it's a really bad idea.  Basically, protect the user. :-)
  if (
#ifndef YES_I_KNOW_WHAT_I_AM_DOING
    (c != id->conf) &&
#endif
    config_perm("Add Module"))
  {
    m_state->buttons_last +=
      ({
        ([ "name" : LOCALE(251, "Add Module"),
           "href" : sprintf("%sadd_module.pike?config=%s&amp;&usr.set-wiz-id;",
                            pre_site_url, Roxen.http_encode_url(c->name)),
           "class_name" : "add-module" ]),
        ([ "name" : LOCALE(252, "Drop Module"),
           "href" : sprintf("%sdrop_module.pike?config=%s&amp;&usr.set-wiz-id;",
                            pre_site_url, Roxen.http_encode_url(c->name)),
           "class_name" : "drop-module" ])
      });
  }

  if (!stache_tmpl) {
    stache_tmpl = Stdio.read_file(combine_path(__DIR__, "site_modules.mu"));
  }

  string res = Roxen.render_mustache(stache_tmpl, m_state);

  return "<eval>" + res + "</eval>";
}

mapping|string parse(RequestID id)
{
  string site;

  if (!id->misc->path_info) {
    id->misc->path_info = "";
  }

  sscanf(id->misc->path_info, "/%[^/]/", site);
  array(string) path = ((id->misc->path_info||"")/"/")-({""});

  return Roxen.http_string_answer(
    selected_item(site, roxen.find_configuration(site), id,
                   (((sizeof(path)>=2)?path[1]:"")/"!")[0],
                   ((sizeof(path)>=3)?path[2]:"")));
}
