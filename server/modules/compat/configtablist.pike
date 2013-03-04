// Config tablist look-a-like module. Copyright © 1999 - 2009, Roxen IS.
//

constant cvs_version="$Id$";

inherit "module";
inherit "roxenlib";

constant module_type = MODULE_PARSER;
constant module_name = "Old tab list module";
constant module_doc  = "<h2>Deprecated</h2>Use the <i>Tab list</i> module instead";

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
