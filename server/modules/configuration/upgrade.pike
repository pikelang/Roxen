/*
 * $Id: upgrade.pike,v 1.13 2000/02/21 14:44:25 js Exp $
 *
 * The Roxen Upgrade Client
 *
 * Johan Schön, Peter Bortas
 * January-February 2000
 */

inherit "module";
inherit "html";
inherit "roxenlib";
#include <roxen.h>
#include <module.h>
#include <stat.h>
#include <config_interface.h>

constant module_type = MODULE_PARSER|MODULE_CONFIG;
constant module_name = "Upgrade client";

object db;

object updater;


mapping(int:GetPackage) package_downloads = ([ ]);

void start(int num, Configuration conf)
{
  if(!num)
  {
    catch(db=Yabu.db(QUERY(yabudir),"wcSQ"));
    updater=UpdateInfoFiles();
  }
}

void stop()
{
  catch(db->close());
  catch(destruct(updater));
}

void create()
{
  query_tag_set()->prepare_context=set_entities;
  defvar("yabudir", "../upgrade_data/", "Database directory",
	 TYPE_DIR, ""); /* Keep this in server and regenerate on upgrade */
  defvar("pkgdir", "../packages/", "Database directory",
	 TYPE_DIR, "");
  defvar("server", "community.roxen.com", "Server host",
	 TYPE_STRING, "");
  defvar("port", 80, "Server port",
	 TYPE_INT, "");
}

static string describe_time_period( int amnt )
{
  if(amnt < 0) return "some time";
  amnt/=60;
  if(amnt < 120) return amnt+" minutes";
  amnt/=60;
  if(amnt < 48) return amnt+" hours";
  amnt/=24;
  if(amnt < 60) return amnt+" days";
  amnt/=(365/12);
  if(amnt < 30) return amnt+" months";
  amnt/=12;
  return amnt+" years";
}

class Scope_upgrade
{
  inherit RXML.Scope;

  mixed `[]  (string var, void|RXML.Context c, void|string scope)
  {
    if(var=="last_updated")
    {
      int t;
      if(catch(t=db["misc"]["last_updated"]) || t==0)
	return "infinitely long";
      return describe_time_period(time()-t);
    }
  }

  string _sprintf() { return "RXML.Scope(upgrade)"; }
}

RXML.Scope upgrade_scope=Scope_upgrade();

void set_entities(RXML.Context c)
{
  c->extend_scope("upgrade", upgrade_scope);
}

array(array) menu = ({
  ({ "Main","" }),
  ({ "Products","products" }),
  ({ "Security","security" }),
  ({ "Bugfixes","bugfixes" }),
  ({ "Third party","3rdpart" }),
});

string tag_upgrade_sidemenu(string t, mapping m, RequestID id)
{
  string ret =
    "<gbutton width=150 bgcolor=&usr.fade1;>Update List</gbutton><br><br>";
  
  foreach(menu, array entry)
  {
    ret += "<gbutton width=150 ";
    if((id->variables->category||"")==entry[1])
    {
      ret += "bgcolor=&usr.left-selbuttonbg; "+
	" icon_src=&usr.selected-indicator; ";
    }
    else
      ret += "bgcolor=&usr.fade1; ";
    ret += "icon_align=left preparse href=\"upgrade.html?category="+
      entry[1]+"\">"+entry[0]+"</gbutton><br>";
  }
 
  return ret;
}

string container_upgrade_package_output(string t, mapping m, string c, RequestID id)
{
  array res=({ });
  int i=0;

  if(!m->package)
  {
    array(string) packages=indices(db["pkginfo"]);
    packages=sort(packages);
    if(m->reverse)
      packages=reverse(packages);
    
    foreach(packages, string pkg)
    {
      mapping p=db["pkginfo"][pkg];
      if( (m->type && p["package-type"]==m->type) || !m->type)
	res+=({ p });
      i++;
      if(m->limit && i>=(int)m->limit)
	break;
    }
  }
  else
  {
    mixed err=catch(start_package_download((int)m->package));
    if(err) report_error("Upgrade: %s",err);
    
    mapping p=db["pkginfo"][m->package];
    if(p)
      res=({ p });
  }
  return do_output_tag(m, res, c, id);
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
	    "authorization": "Basic "+MIME.encode_base64("js:klorgas"), // FIXME
  ]);
}


void start_package_download(int num)
{
  if(search(indices(package_downloads), num)!=-1)
    throw("Package download already in progress for package "+num+".\n");

  array stat=file_stat(QUERY(pkgdir)+num+".tar");

  if(stat && stat[1]==db["pkginfo"][(string)num]->size)
    throw("Package "+num+" already completely downloaded.\n");

  package_downloads[num]=GetPackage(num);
}


/*--- Custom HTTP fetchers ------------------------------------*/

class GetPackage
{
  int num;
  
  inherit Protocols.HTTP.Query;

  int|float percent_done()
  {
    int b=total_bytes();
    if(b==-1)
      return 0;
    return (float)downloaded_bytes() / (float)b;
  }
  
  void request_ok(object httpquery, int _num)
  {
    // FIXME: rewrite this to use a file object and stream to disk?
    Stdio.File f;
    num=_num;

    if(catch(f=Stdio.File(QUERY(pkgdir)+num+".tar","wc")))
    {
      report_error("Upgrade: Failed to open file for writing: "+
		   QUERY(pkgdir)+num+".tar\n");
      catch(m_delete(package_downloads, num));
      return;
    }
    if(catch(f->write(httpquery->data())))
    {
      report_error("Upgrade: Failed to write package to file: "+
		   QUERY(pkgdir)+num+".tar\n");
      catch(rm(QUERY(pkgdir)+num+".tar"));
      catch(m_delete(package_downloads, num));
      return;
    }
    f->close();
    catch(m_delete(package_downloads, num));
  }
  
  void request_fail(object httpquery, int num)
  {
    report_error("Upgrade: Failed to connect to upgrade server to fetch "
		 "package number "+num+".\n");
    catch(m_delete(package_downloads, num));
  }

  void create(int pkgnum)
  {
    set_callbacks(request_ok, request_fail, pkgnum);
    async_request(QUERY(server),QUERY(port),
		  "GET /upgradeserver/packages/"+pkgnum+".tar HTTP/1.0",
		  get_headers());
  }
}


class GetInfoFile
{
  inherit Protocols.HTTP.Query;

  string get_containers(string t, mapping m, string c, int line, mapping res)
  {
    if(sizeof(t) && t[0]!='/')
      res[t]=c;
  }
  
  void request_ok(object httpquery, int num)
  {
    spider;
    mapping res=([]);
    
    if(httpquery->status!=200)
    {
      report_error("Upgrade: Wrong answer from server for package %d.\n",num);
      return;
    }

    parse_html_lines(httpquery->data(),
		     ([]),
		     (["id" : get_containers, 
		       "title": get_containers, 
		       "description": get_containers, 
		       "organization": get_containers, 
		       "license": get_containers, 
		       "author-email": get_containers, 
		       "author-name": get_containers, 
		       "package-type": get_containers, 
		       "issued-date": get_containers, 
		       "roxen-low": get_containers, 
		       "roxen-high": get_containers, 
		       "crypto": get_containers ]),		     
		     res);
    res->size=(int)httpquery->headers->pkgsize;
    werror("%O\n",res);
    db["pkginfo"][(string)num]=res;
    db["pkginfo"]->sync();
    report_notice("Upgrade: Added information about package number "
		  +num+".\n");
  }

  void request_fail(object httpquery, int num)
  {
    report_error("Upgrade: Failed to connect to upgrade server to fetch "
		 "information about package number "+num+".\n");
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
  inherit Protocols.HTTP.Query;

  void request_ok(object httpquery)
  {
    string s=httpquery->data();
    
    array lines=s/"\n";
    if(httpquery->status!=200 || lines[0]!="upgrade" || sizeof(lines)<3)
    {
      report_error("Upgrade: Wrong answer from server.\n");
      return;
    }

    array(int) new_packages=decode_ranges(lines[1]);
    array(int) delete_packages=decode_ranges(lines[2]);

    if(sizeof(new_packages))
      report_notice("Upgrade: Found new packages: "+
		    ((array(string))new_packages)*", "+"\n");
    else
      report_notice("Upgrade: No new packages found.\n");

    if(sizeof(delete_packages))
      report_notice("Upgrade: Deleting packages: "+
		    ((array(string))delete_packages)*", "+
		    "\n");
    else
      report_notice("Upgrade: No packages to delete found.\n");

    foreach(new_packages, int i)
      GetInfoFile(i);

    foreach(delete_packages, int i)
      catch(db["pkginfo"]->delete((string)i));

    catch(db["misc"]["last_updated"]=time());
  }

  void request_fail(object httpquery)
  {
    report_error("Upgrade: Failed to connect to upgrade server to fetch "
		 "information about new packages.\n");
  }

  void do_request()
  {
//     werror("foo: %O\n",encode_ranges((array(int))indices(db["pkginfo"])));
    async_request(QUERY(server),QUERY(port),
		  "POST /upgradeserver/get_packages HTTP/1.0",
		  get_headers() |
		  (["content-type":"application/x-www-form-urlencoded"]),
		  "roxen_version=2.0001&"+
		  "have_packages="+
		  encode_ranges((array(int))indices(db["pkginfo"])));
    call_out(do_request, 12*3600);
  }

  void destroy()
  {
    remove_call_out(do_request);
  }
  
  void create()
  {
    set_callbacks(request_ok, request_fail);
    call_out(do_request,1);
  }
}
