// Locale stuff.
// <locale-token project="roxen_config"> _ </locale-token>

#include <roxen.h>
#include <config_interface.h>
#define _(X,Y)  _DEF_LOCALE("roxen_config",X,Y)

constant box = "large";
constant box_initial = 1;

LocaleString box_name = _(0,"Deprecated Modules");
LocaleString box_doc  = _(0,"Warn when sites contains deprecated modules");


string get_module_group(ModuleInfo m)
{
  string name = (string)m->get_name();

  if (sscanf(name, "%s:%*s", string g) == 2) {
    return Roxen.http_encode_invalids(g);
  }

  return "zz_misc";
}


string parse(RequestID id)
{
  mapping(string:ModuleInfo) mod_cache = ([]);
  mapping(string:array(mapping)) deprecated_info = ([]);

  map(roxen->configurations,
    lambda (Configuration c) {
      string cname = c->query_name();
      mapping(string:int(1..1)) mods;

      if (!c->inited) {
        mods = roxen.retrieve("EnabledModules", c);
      }
      else {
        mods = c->enabled_modules;
      }

      foreach (indices(mods), string mname) {
        array(string) pts = mname/"#";
        mname = pts[0];

        if (!mod_cache[mname]) {
          ModuleInfo info = roxen->find_module(mname);

          if (info) {
            mod_cache[mname] = info;
          }
        }

        ModuleInfo mi = mod_cache[mname];

        if (mi && mi->deprecated) {
          if (!deprecated_info[cname]) {
            deprecated_info[cname] = ({});
          }

          string curl = "/sites/site.html/" +
                        replace(lower_case(c->name), ([ " " : "-" ])) + "/" +
                        get_module_group(mi) + "!0/" +
                        mi->sname + "!" + pts[1] + "/";

          mapping m = ([
            "name" : mi->get_name(),
            "url"  : curl
          ]);

          deprecated_info[cname] += ({ m });
        }
      }
    });

  if (sizeof(deprecated_info)) {
    mapping ctx = ([
      "box_type" : box,
      "box_name" : box_name,
      "sites"    : ({})
    ]);

    string tmpl = #"
      <cbox type='{{box_type}}' title='{{box_name}}'>
        <p class='no-margin-top'>The following modules are deprecated and will
          not receive any bug fixes or any other updates. Consider removing
          them if possible.</p>

        {{#sites}}
          <dl>
            <dt>{{name}}</dt>
            {{#modules}}
              <dd><a href='{{url}}'>{{name}}</a></dd>
            {{/modules}}
          </dl>
        {{/sites}}
      </cbox>";

    foreach (sort(indices(deprecated_info)), string cname) {
      array(mapping) mi = deprecated_info[cname];
      sort(mi->name, mi);

      ctx->sites += ({
        ([ "name"    : cname,
           "modules" : mi ])
      });
    }

    mod_cache = 0;
    deprecated_info = 0;

    return Roxen.render_mustache(tmpl, ctx);
  }

  return "";
}
