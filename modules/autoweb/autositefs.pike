#include <module.h>
#include <roxen.h>

inherit "module";
inherit "roxenlib";
inherit "modules/filesystems/filesystem.pike" : filesystem;

#define DB_ALIAS "autosite"
constant cvs_version="$Id: autositefs.pike,v 1.27 1998/09/30 23:00:34 js Exp $";

mapping host_to_id;
multiset(int) hidden_sites;
array register_module()
{
  return ({ MODULE_LOCATION|MODULE_PARSER,
	    "AutoSite IP-less hosting Filesystem",
	    "" });
}

string create(object configuration)
{
  filesystem::create();
  defvar("defaulttext",
	 "<HTML>\n"
	 "\n"
	 "<!-- There are no secret messages in the"
	 " source code to this web page. -->\n"
	 "<!-- There are no tyops in this web page. -->\n"
	 "<TITLE>Not yet the $$COMPANY$$ home page</TITLE>\n"
	 "<BODY>\n"
	 "This web page is not here yet.\n"
	 "</BODY>\n"
	 "</HTML>",
	 "Default text for /index.html",
	 TYPE_TEXT_FIELD,
	 "");
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
  object db=id->conf->sql_connect(DB_ALIAS);
  array a=
    db->query("select rr_owner,customer_id,domain from dns where rr_type='A'");
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

void update_hidden_sites(object id)
{
  object db=id->conf->sql_connect(DB_ALIAS);
  array a=db->query("select customer_id from features where feature='Hidden Site'");
  hidden_sites=(< @a->customer_id >);
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

int hiddenp(object id)
{
  return hidden_sites[id->misc->customer_id];
}

int validate_user(object id)
{
  array a=id->conf->sql_connect(DB_ALIAS)->
    query("select user_id,password from customers where id='"+
	  id->misc->customer_id+"'");
  if(!sizeof(a))
    return 0;
  else
    return equal( ({ a[0]->user_id, a[0]->password }),
		  ((id->realauth||"*:*")/":") );
}

mixed find_file(string f, object id)
{
  if(!host_to_id)   update_host_cache(id);
  if(!hidden_sites) update_hidden_sites(id);
  string file=file_from_host(id,f);
  //werror("customer_id: %O\n",id->misc->customer_id);
  id->misc->wa = this_object();
  if(!file&& (f=="" ||
	      host_to_id[(array_sscanf(f,"%s/")+({""}))[0]]))
  {
    string s="";
    s+=
      "<h1>Error!</h1>"
      "You seem to be using a browser that doesn't send host header. "
      "Please upgrade your browser.<br><br>"
      "The following sites are hosted here:<p><ul>";
    foreach(indices(host_to_id), string host)
      if(host[0..3]=="www.")
	s+="<li><a href='http://"+host+"/'>"+host+"</a>";
    return http_string_answer(parse_rxml(s,id),"text/html");
  }
  if(!file)
    return 0;
  if(hiddenp(id) && !validate_user(id))
    return http_auth_required(get_host(id));
	     
  mixed res = filesystem::find_file(file, id);
  if(objectp(res)) {
    mapping md = .AutoWeb.MetaData(id, "/"+f)->get();
    id->misc->md = md;
    if(md->content_type=="text/html") {
      string d = res->read( );
      if((md->template)&&(md->template!="No"))
	d = "<template><content>"+d+"</content></template>";
      int t=gethrtime();
      res = http_string_answer(parse_rxml(d, id), "text/html");
      werror("parse_rxml: %f (f: %O)\n",(gethrtime()-t)/1000.0,f);
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
  update_hidden_sites(id);
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
		   replace(query("defaulttext"),"$$COMPANY$$",args->company));
  Stdio.write_file(dir+"/index.html.md",
		   "<md variable=\"content_type\">text/html</md>\n"
		   "<md variable=\"description\"></md>\n"
		   "<md variable=\"keywords\"></md>\n"
		   "<md variable=\"template\">Yes</md>"
		   "<md variable=\"title\">Welcome</md>");
  
  Stdio.write_file(dir+"/templates/default.tmpl","<tmplinsertall>");
}

mapping query_tag_callers()
{
  return ([ "autosite-fs-update" : tag_update,
	    "autosite-fs-init-home-dir" : tag_init_home_dir  ]);
}
