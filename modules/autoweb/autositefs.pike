#include <module.h>
#include <roxen.h>

inherit "module";
inherit "roxenlib";
inherit "modules/filesystems/filesystem.pike" : filesystem;

constant cvs_version="$Id: autositefs.pike,v 1.21 1998/09/16 12:46:26 js Exp $";

mapping host_to_id;

array register_module()
{
  return ({ MODULE_LOCATION|MODULE_PARSER,
	    "AutoSite IP-less hosting Filesystem",
	    "" });
}

string get_host(object id)
{
  if(id->misc->host)
    return lower_case((id->misc->host / ":")[0]);
  else
    return 0;
}
  
void update_host_cache(object id)
{
  object db=id->conf->call_provider("sql","sql_object",id);
  array a=db->query("select rr_owner,customer_id,domain from dns where rr_type='A'");
  mapping new_host_to_id=([]);
  if(!catch {
    Array.map(a,lambda(mapping entry, mapping m)
		{
		  if(sizeof(entry->rr_owner))
		    m[entry->rr_owner+"."+entry->domain]=entry->customer_id;
		  else
		    m[entry->domain]=entry->customer_id;
		},new_host_to_id);
  })
    host_to_id=new_host_to_id;
}

string file_from_host(object id, string file)
{
  string prefix,dir;
  if(prefix=id->misc->customer_id)
    return "/"+prefix+"/"+file;
  string prefix=id->misc->customer_id=id->variables->customer_id=
    host_to_id[get_host(id)];
  if(prefix)
    dir = "/" + prefix + "/";
  else
  {
    string host,rest="";
    sscanf(file,"%s/%s",host,rest);
    if(prefix=host_to_id[host])
    {
      id->misc->customer_id=id->variables->customer_id=prefix;
      dir="/" + prefix + "/";
      if(rest)
	file=rest;
    }
    else
      return 0; // No such host
  }
  return dir+file;
}

mixed find_file(string f, object id)
{
  if(!host_to_id)
    update_host_cache(id);
  string file=file_from_host(id,f);
  //werror("customer_id: %O\n",id->misc->customer_id);
  id->misc->wa = this_object();
  if(!file&& (f=="" ||
	      host_to_id[(array_sscanf(f,"%s/")+({""}))[0]]))
  {
    string s="";
    s+=
      "<h1>Foobar Gazonk AB</h1>"
      "You seem to be using a browser that doesn't send host header. "
      "Please upgrade your browser, or access the site you want to from the "
      "list below:<p><ul>";
    foreach(indices(host_to_id), string host)
      if(host[0..3]=="www.")
	s+="<li><a href='/"+host+"/'>"+host+"</a>";
    return http_string_answer(parse_rxml(s,id),"text/html");
  }
  if(!file)
    return 0;
  mixed res = filesystem::find_file(file, id);
  if(objectp(res)) {
    mapping md = .AutoWeb.MetaData(id, f)->get();
   // werror("File: %O, md: %O", f, md);
    if(md->content_type=="text/html") {
      string d = res->read( );
      if((md->template)&&(md->template!="No"))
	d = "<template><content>"+d+"</content></template>";
      res = http_string_answer(parse_rxml(d, id), "text/html");
    }
  }
  return res;
}


string real_file(string f, mixed id)
{
  if(!sizeof(f) || f=="/")
    return 0;
  if(!host_to_id)
    update_host_cache(id);
  string file=file_from_host(id,f);
  if(!file)
    return 0; // FIXME, return a helpful page
  array(int) fs;

  // Use the inherited stat_file
  fs = filesystem::stat_file( file,id );

  if (fs && ((fs[1] >= 0) || (fs[1] == -2)))
    return f;
  return 0;
}

array find_dir(string f, object id)
{
  if(!host_to_id)
    update_host_cache(id);
  string file=file_from_host(id,f);
  if(!file)
    return 0; // FIXME, return got->conf->userlist(id);
  else
    return filesystem::find_dir(file, id);
}

mixed stat_file(mixed f, mixed id)
{
  if(!host_to_id)
    update_host_cache(id);
  string file=file_from_host(id,f);
  if(!file)
    return 0;
  else
    return filesystem::stat_file( file,id );
}

string tag_update(string tag_name, mapping args, object id)
{
  update_host_cache(id);
  return "Filesystem configuration reloaded.";
}

string tag_init_home_dir(string tag_name, mapping args, object id)
{
  if(!args->id)
    return "error";
  string dir=combine_path(query("searchpath"),(string)(int)args->id);
  // I don't know why, but this feels dangerous...
  Process.popen("rm -rf "+dir);
  mkdir(dir);
  mkdir(dir+"/templates/");
  Stdio.write_file(dir+"/index.html",
		   "<h1>Foobolaget</h1>"
		   "Enjoy...");
  Stdio.write_file(dir+"/templates/default.tmpl",
		   Stdio.read_bytes(combine_path(
		     query("searchpath"),"default.tmpl")));
}

mapping query_tag_callers()
{
  return ([ "autosite-fs-update" : tag_update,
	    "autosite-fs-init-home-dir" : tag_init_home_dir  ]);
}
