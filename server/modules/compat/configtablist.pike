// Config tablist look-a-like module. Copyright © 1999, Idonex AB.
//

constant cvs_version="$Id: configtablist.pike,v 1.7 1999/12/27 22:34:59 nilsson Exp $";

#include <module.h>
inherit "module";
inherit "roxenlib";

array register_module() {
  return ({ MODULE_PARSER, "Old tab list module", "Use the <i>Tab list</i> module instead", 0, 1});
}

void start(int num, Configuration conf) {
  module_dependencies (conf, ({ "tablist" }));
  werror("\n ***** Config tab list outdated. Adding Tab list instead.\n");
}

RoxenModule rxml_warning_cache;
void old_rxml_warning(RequestID id, string no, string yes) {
  if(!rxml_warning_cache) rxml_warning_cache=my_configuration()->get_provider("oldRXMLwarning");
  if(!rxml_warning_cache) return;
  rxml_warning_cache->old_rxml_warning(id, no, yes);
}

string tag_ctablist(string t, mapping a, string c, object id) {
  old_rxml_warning(id, "config_tablist tag","tablist");
  return make_container("tablist",a,c);
}

mapping query_container_callers() {
  return ([ "config_tablist":tag_ctablist ]);
}
