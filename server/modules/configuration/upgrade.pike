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

void create()
{
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

  string _sprintf() { return "RXML.Scope(upgrade)"; }
}

RXML.Scope upgade_scope=Scope_upgrade();

void set_entities(RXML.Context c)
{
  c->extend_scope("upgrade", upgrade_scope);
}

string tag_foo(string t, mapping m, RequestID id)
{
  
}

string container_bar(string t, mapping m, string c, RequestID id)
{
  
}

/*

Fetchers:

get_new_info_files


*/



class GetInfoFile
{
  inherit Protocols.HTTP.Query();

  void request_ok(object httpquery)
  {
    
  }

  void request_fail(object httpquery)
  {

  }

  void do_request()
  {
    
  }
  
  void create()
  {
    set_callbacks(request_ok, request_fail);
    async_request(QUERY(server),QUERY(port), query, headers);
  }
}

class UpdateInfoFiles
{
  inherit Protocols.HTTP.Query();

  void request_ok(object httpquery)
  {
    
  }

  void request_fail(object httpquery)
  {

  }

  void do_request()
  {
    async_request(string server,int port,string query,mapping headers,void|string data);
  }
  
  void create()
  {
    set_callbacks(request_ok, request_fail);
  }
}


/*
object db=Yabu.lookup(fname,"wS");
  db->pkginfo[17]["foobar"]="gazonk";

  indices(db->pkginfo);

*/
