inherit "module";
inherit "html";
inherit "roxenlib";
#include <roxen.h>
#include <module.h>
#include <stat.h>
#include <config_interface.h>

constant module_type = MODULE_PARSER|MODULE_CONFIG;
constant module_name = "Upgrade handler for the config interface";

object db;

void start(int num, Configuration conf)
{
  conf->parse_html_compat=1;
  db=Yabu.db(QUERY("yabuname","wS"));
  UpdateInfoFiles();
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

string encode_ranges(array(int) a)
{
  a=sort(a);
  string s="";
  int last;
  if(!sizeof(a))
    return "";
  for(int i=0;i<sizeof(a);i++)
  {
    if(i==0)
    {
      s+=(string)a[i];
      last=a[i];
      continue;
    }
    
    if(a[i]==last+1)
    {
      last=a[i];
      if(s[-1]!='-')
	s+="-";
      continue;
    }
    
    if(s[-1]=='-')
      s+=(string)last;

    s+=", "+(string)a[i];
    last=a[i];
  }
  if(s[-1]=='-')
    s+=(string)last;
  return s;
}

array(int) decode_ranges(string s)
{
  array a=({ });
  int start,stop;
  foreach( ((s-" ")/",")-({""}), string r)
    if(sscanf(r,"%d-%d",start,stop)==2 && stop>start && (stop-start)< 1<<16 )
      for(int i=start; i<=stop; i++)
	a+=({ i });
    else
      a+=({ (int)r });
  return sort(a);
}

mapping get_headers()
{
  return ([ "host":QUERY(server)+":"+QUERY(port),
	    "user-agent": "Roxen·WebServer/1.4.143", // FIXME
	    "authorization": "Basic "+MIME.encode_base64("foo:bar"), // FIXME
  ]);
}



class GetInfoFile
{
  inherit Protocols.HTTP.Query();

  string get_containers(string t, mapping m, string c, mapping res)
  {
    if(sizeof(t) && t[0]!='/')
      res[t]=c;
  }
  
  void request_ok(object httpquery, int num)
  {
    spider;
    mapping res=([]);;
    parse_html_lines(httpquery->data(),
		     ([])
		     (["":get_containers]),
		     res);
    res->size=httpquery->headers->size;
    db->pkginfo[(string)num]=res;
    db->pkginfo->sync();
    report_notice("Added information about package number "+num+".");
  }

  void request_fail(object httpquery, int num)
  {
    report_error("Failed to connect to upgrade server to fetch "
		 "information about package number "+num+".");
  }

  void create(int pkgnum)
  {
    set_callbacks(request_ok, request_fail, pkgnum);
    async_request(QUERY(server),QUERY(port),
		  "GET /upgradeserver/packages/"+pkgnum+".info HTTP/1.0",
		  get_headers());
  }
}


class UpdateInfoFiles
{
  inherit Protocols.HTTP.Query();

  void request_ok(object httpquery)
  {
    string s=httpquery->data();

    array lines=s/"\n";
    array(int) new_packages=decode_ranges(lines[1]);
    array(int) delete_packages=decode_ranges(lines[2]);

    if(sizeof(new_packages))
      report_notice("Found new packages: "+ ((array(string))new_packages)*", ");
    else
      report_notice("No new packages found");

    if(sizeof(delete_packages))
      report_notice("Deleting packages: "+ ((array(string))delete_packages)*", ");
    else
      report_notice("No packages to delete found");

    foreach(new_packages, int i)
      GetInfoFile(i);

    foreach(delete_packages, int i)
      db->pkginfo->delete((string)i);
      
  }

  void request_fail(object httpquery)
  {
    report_error("Failed to connect to upgrade server to fetch "
		 "information about new packages.");
  }

  void do_request()
  {
    async_request(QUERY(server),QUERY(PORT),
		  "POST /upgradeserver/get-packages HTTP/1.0",
		  get_headers() |
		  (["Content-type":"application/x-www-form-urlencoded"]),
		  "have_packages="+encode_ranges((array(int))indices(db->pkginfo)));
    call_out(do_request, 12*3600);
  }
  
  void create()
  {
    set_callbacks(request_ok, request_fail);
    call_out(do_request,60);
  }
}
