#include <module.h>
#include <roxen.h>

inherit "module";
inherit "roxenlib";
inherit "modules/filesystems/filesystem.pike" : filesystem;

constant cvs_version="$Id: autositefs.pike,v 1.1 1998/07/15 22:57:53 js Exp $";

mapping host_to_id;

array register_module()
{
  return ({ MODULE_LOCATION|MODULE_PARSER,
	    "AutoSite filesystem",
	    "" });
}

string get_host(object id)
{
  return "www.gazonk.se";
  if(id->misc->host)
    return (id->misc->host / ":")[0];
  else
    return 0;
}
  
void update_host_cache(object id)
{
  object db=id->conf->call_provider("sql","sql_object",id);
  array a=db->query("select * from dns where rr_type='CNAME'");
  mapping new_host_to_id=([]);
  if(!catch {
    Array.map(a,lambda(mapping entry, mapping m)
		{
		  m[entry->rr_value]=entry->id;
		},new_host_to_id);
  })
    host_to_id=new_host_to_id;
}

string dir_from_host(object id)
{
  string prefix,dir;
  if(prefix=host_to_id[get_host(id)])
    dir = "/" + prefix + "/";
  else
    return 0; // No such host
  dir = replace(dir, "//", "/");
  return dir;
}

mixed find_file(string f, object id)
{
  if(!host_to_id)
    update_host_cache(id);
  string dir=dir_from_host(id);
  if(!dir)
  {
    string s="";
    s+=
      "<h1>Foobar Gazonk AB</h1>"
      "You seem to be using a browser that doesn't send host header. "
      "Please upgrade your browser, or access the site you want to from the "
      "list below:<p><ul>";
    foreach(indices(host_to_id), string host)
      s+="<li><a href='/"+host+"/'>"+host+"</a>";
    return http_string_answer(parse_rxml(s,id),"text/html");
  }
  else
    f=dir+f;
  
  mixed res = filesystem::find_file(f, id);
  if(objectp(res))
  {
    if(roxen->type_from_filename( f, 0 ) == "text/html")
    {
      string d = res->read( );
      d="<template><content>"+d+"</content></template>";
      res=http_string_answer(parse_rxml(d,id),"text/html");
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
  string dir=dir_from_host(id);
  if(!dir)
    return 0; // FIXME, return a helpful page
  else
    f=dir+f;
  array(int) fs;

  // Use the inherited stat_file
  fs = filesystem::stat_file( f,id );

  if (fs && ((fs[1] >= 0) || (fs[1] == -2)))
    return f;
  return 0;
}

array find_dir(string f, object id)
{
  if(!host_to_id)
    update_host_cache(id);
  string dir=dir_from_host(id);
  if(!dir)
    return 0; // FIXME, return got->conf->userlist(id);
  else
  {
    f=dir+f;
    return filesystem::find_dir(f, id);
  }
}

mixed stat_file(mixed f, mixed id)
{
  if(!host_to_id)
    update_host_cache(id);
  string dir=dir_from_host(id);
  if(!dir)
    return 0; // FIXME, return a helpful page
  else
  {
    f=dir+f;
    return filesystem::stat_file( f,id );
  }
}
