inherit "module";
inherit "html";
inherit "roxenlib";
#include <roxen.h>
#include <module.h>
#include <stat.h>
#include <config_interface.h>

constant module_type = MODULE_PARSER|MODULE_CONFIG;
constant module_name = "Upgrade handler for the config interface";


void start(int num, Configuration conf)
{
  conf->parse_html_compat=1;
}

void create() {
  query_tag_set()->prepare_context=set_entities;
}

class Scope_usr
{
  inherit RXML.Scope;

  mixed `[]  (string var, void|RXML.Context c, void|string scope)
  {
    object id = c->id;
    return "foo";
  }

  string _sprintf() { return "RXML.Scope(usr)"; }
}

RXML.Scope usr_scope=Scope_usr();

void set_entities(RXML.Context c) {
  c->extend_scope("usr", usr_scope);
}

string get_var_type( string s, object mod, object id )
{
}
string container_cf_perm( string t, mapping m, string c, RequestID id )
{
}
