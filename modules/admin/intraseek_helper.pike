/*
 * $Id: intraseek_helper.pike,v 1.3 1998/09/15 12:50:53 js Exp $
 *
 * AutoSeek, Intraseek helper module
 *
 * Johan Schön 1998-07-08
 */

constant cvs_version = "$Id: intraseek_helper.pike,v 1.3 1998/09/15 12:50:53 js Exp $";

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

  return "Intraseek profile created.";
}

string tag_delete(string tag_name, mapping args, object id)
{
  // arguments:   id    id number
  object o=id->conf->get_provider("intraseek");
  if(!o)
    return "Intraseek not present.";
  o->remove_profile(args->id);
  o->profile_handler->save_profiles(o->query("profilespath"));
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

mapping query_tag_callers()
{
  return ([ "autosite-intraseek-create" : tag_create,
	    "autosite-intraseek-delete" : tag_delete,
	    "autosite-intraseek-launch" : tag_launch ]);
}
