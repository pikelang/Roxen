/*
 * $Id: intraseek_helper.pike,v 1.7 1998/10/12 09:43:52 js Exp $
 *
 * AutoSeek, Intraseek helper module
 *
 * Johan Schön 1998-09-08
 */

constant cvs_version = "$Id: intraseek_helper.pike,v 1.7 1998/10/12 09:43:52 js Exp $";

#include <module.h>
#include <roxen.h>

inherit "module";
inherit "roxenlib";


array register_module()
{
  return ({ MODULE_PARSER, "AutoSite Intraseek helper module",
	    "",0,1 });
}

void create(object conf)
{
  defvar("workdir", "/usr/local/AutoSite/intraseek_databases/",
	 "Intraseek database directory", TYPE_DIR,
	 "");
}


string tag_create(string tag_name, mapping args, object id)
{
  // arguments:   id    Id number
  //              host  Host name, i.e. www.ultraviking.se
  //              name  Profile name
  object o=id->conf->get_provider("intraseek");
  if(!o)
    return "Intraseek not present.";

  array data = allocate(29);
  string storage_dir;

  data[0]=args->name;
  mkdir(storage_dir = combine_path(query("workdir"),args->id));
  data[1]=storage_dir+"/";
  data[3]=({ "http://"+args->host+"/*" });
  data[5]=({ "http://"+args->host+"/" });
  data[20]="2";
  data[21]="1";
  data[22]="0";
  data[23]="1";

  o->engine_reset(1);

  o->profile_handler->create_profile(args->id, data);
  o->profile_handler->save_profiles(o->query("profilespath"));
  o->build_active_databases_list();

  return "Intraseek profile created.";
}

string tag_delete(string tag_name, mapping args, object id)
{
  // arguments:   id    id number
  object o=id->conf->get_provider("intraseek");
  if(!o)
    return "Intraseek not present.";
  o->profile_handler->remove_profile(args->id);
  o->profile_handler->save_profiles(o->query("profilespath"));
  o->build_active_databases_list();
  return "Intraseek profile deleted.";
}

string tag_launch(string tag_name, mapping args, object id)
{
  // arguments:   id    id number
  object o=id->conf->get_provider("intraseek");
  if(!o)
    return "Intraseek not present.";
  catch {
    o->do_launch(args->id, 0, 0);
  };
  return "Intraseek profile launched.";
}

string tag_search(string tag_name, mapping args, object id)
{
  werror("id: %O\n",id->misc->customer_id);
  if(!sizeof(id->conf->get_provider("sql")->sql_object(id)->
	     query("select feature from features where customer_id="+
		   id->variables->customer_id+" and feature='Intraseek'")))
    return "Intraseek not enabled for this host. ("+id->variables->customer_id+")";
  else 
    return 
      "<intraseek_form lang="+(args->lang?args->lang:"en")+" ids="+id->misc->customer_id+" default_id="+
      id->misc->customer_id+"><intraseek_results lang="+(args->lang?args->lang:"en")+">";
}

mapping query_tag_callers()
{
  return ([ "autosite-intraseek-create" : tag_create,
	    "autosite-intraseek-delete" : tag_delete,
	    "autosite-intraseek-launch" : tag_launch,
	    "search": tag_search
  ]);
}
