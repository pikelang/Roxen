/*
 * $Id: update.pike,v 1.9 2000/03/24 20:01:07 js Exp $
 *
 * The Roxen Update Client
 * Copyright © 2000, Roxen IS.
 *
 * Author: Johan Schön
 * January-March 2000
 */

#ifdef UPDATE_DEBUG
# define UPDATE_MSG(X) werror("Update client: "+X+"\n")
# define UPDATE_MSGS(X, Y) werror("Update client: "+X+"\n", @Y)
#else
# define UPDATE_MSG(X)
# define UPDATE_MSGS(X, Y)
#endif

#ifdef UPDATE_NOISY_DEBUG
# define UPDATE_NOISE(X) werror("Update client noise: "+X+"\n")
# define UPDATE_NOISES(X, Y) werror("Update client noise: "+X+"\n", @Y)
#else
# define UPDATE_NOISE(X)
# define UPDATE_NOISES(X, Y)
#endif

inherit "module";
inherit "html";
inherit "roxenlib";
#include <roxen.h>
#include <module.h>
#include <stat.h>
#include <config_interface.h>

constant module_type = MODULE_PARSER|MODULE_CONFIG;
constant module_name = "Update client";
constant module_doc = "This is the update client. "
                      "If you have a Roxen user identity at the Roxen Community "
                      "website, feel free to enter your username and password in "
                      "the settings tab.";

object db;

object updater;
Yabu.Table pkginfo, misc, installed;

mapping(int:GetPackage) package_downloads = ([ ]);

int inited;
void post_start()
{
#ifdef UPDATE_DEBUG
  if(mixed error =
#endif
  catch(db=Yabu.db(roxen_path(QUERY(yabudir)),"wcSQ"))
#ifdef UPDATE_DEBUG
    )
    UPDATE_MSGS("post_start() failed to create yabu database: %O", ({ error }));
#else
  ;
#endif
  pkginfo=db["pkginfo"];
  misc=db["misc"];
  installed=db["installed"];
  mkdirhier(roxen_path(QUERY(pkgdir)+"/foo"));
  if(QUERY(do_external_updates))
    updater=UpdateInfoFiles();
  UPDATE_NOISES("db == %O", ({ db }));
}

void start(int num, Configuration conf)
{
  if(conf && !inited)
  {
    inited++;
    UPDATE_NOISE("Initializing...");
#if !constant(thread_create)
    call_out( post_start, 1 );
#else
    thread_create( post_start );
#endif
  }
}

void stop()
{
  UPDATE_NOISE("Shutting down...");
  catch(db->close());
  catch(destruct(updater));
  UPDATE_NOISE("Shutdown complete.");
}

void create()
{
  query_tag_set()->prepare_context=set_entities;
  defvar("yabudir", "$VVARDIR/update_data/", "Database directory",
	 TYPE_DIR, ""); 
  defvar("pkgdir", "$LOCALDIR/packages/", "Database directory",
	 TYPE_DIR, "");
  defvar("proxyserver", "", "Proxy host",
	 TYPE_STRING, "Leave empty to disable the use of a proxy server");
  defvar("proxyport", 80, "Proxy port",
	 TYPE_INT, "");
  defvar("userpassword", "", "Username and password",
	 TYPE_STRING,
	 "Format: username@host:password. "
	 "Will not use auth if left empty.");
  defvar("do_external_updates",1,"Connect to community.roxen.com for updates",
	 TYPE_FLAG,
         "Turn this off if you're inside a firewall and/or don't want to "
	 "reveal anything to the outside world.");
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

class Scope_update
{
  inherit RXML.Scope;

  mixed `[]  (string var, void|RXML.Context c, void|string scope)
  {
    if(var=="last_updated")
    {
      int t;
      if(catch(t=misc["last_updated"]) || t==0)
	return "infinitely long";
      return describe_time_period(time()-t);
    }
  }

  string _sprintf() { return "RXML.Scope(update)"; }
}

RXML.Scope update_scope=Scope_update();

void set_entities(RXML.Context c)
{
  c->extend_scope("update", update_scope);
}

array(array) menu = ({
  ({ "Main","" }),
  ({ "Products","products" }),
  ({ "Security","security" }),
  ({ "Bugfixes","bugfixes" }),
  ({ "Third party","3rdpart" }),
});

string tag_update_sidemenu(string t, mapping m, RequestID id)
{
  string ret =
    "<gbutton href=\"update.html?update_list=1\" width=150 "
    "bgcolor=&usr.fade1;>Update List</gbutton><br><br>";

  foreach(menu, array entry)
  {
    ret += "<gbutton width=150 ";
    if((id->variables->category||(id->variables->uninstall||""))==entry[1])
    {
      ret += "bgcolor=&usr.left-selbuttonbg; "+
	" icon_src=&usr.selected-indicator; ";
    }
    else
      ret += "bgcolor=&usr.fade1; ";
    ret += "icon_align=left preparse href=\"update.html?category="+
      entry[1]+"\">"+entry[0]+"</gbutton><br>";
  }

  ret += "<br><gbutton href=\"update.html?uninstall=1\" width=150 ";
  if(id->variables->uninstall)
    ret += "bgcolor=&usr.left-selbuttonbg; "+
      " icon_src=&usr.selected-indicator; ";
  else
      ret += "bgcolor=&usr.fade1; ";
  
  ret+="icon_align=left>Uninstall packages</gbutton>";
  return ret;
}

string tag_update_uninstall_package(string t, mapping m, RequestID id)
{
  if(m->package)
    catch(installed->delete(m->package));
  return "";
}

// <update-package-output>...</>
// Show information about one or several packages.
// Arguments: package, reverse, type, limit
string container_update_package_output(string t, mapping m, string c, RequestID id)
{
  UPDATE_NOISES("<%s>: args = %O, contents = %O", ({ t, m, c }));
  array res=({ });
  int i=0;

  if(!m->package)
  {
    UPDATE_MSGS("pkginfo = %O", ({ pkginfo }));
    array(string) packages = indices(pkginfo);
    packages = sort(packages);
    if(m->reverse)
      packages=reverse(packages);

    foreach(packages, string pkg)
    {
      mapping p=pkginfo[pkg];
      if( !installed[pkg] && ((m->type && p["package-type"]==m->type) || !m->type))
	res+=({ p });
      if(m->installed && installed[pkg])
	res+=({ p });
      i++;
      if(m->limit && i>=(int)m->limit)
	break;
    }
  }
  else
  {
    mapping p=pkginfo[m->package];
    if(p)
    {
      mapping t=localtime((int)p["issued-date"]);
      p->date=sprintf("%04d-%02d-%02d",1900+t->year,t->mon+1, t->mday);;
      res=({ p });
    }
  }
  return do_output_tag(m, res, c, id);
}

string tag_update_start_download(string t, mapping m, RequestID id)
{
  mixed err=catch(start_package_download((int)m->package));
  if(err) report_error("Upgrade: %s",err);
  return "";
}


string tag_update_package_is_downloaded(string t, mapping m, RequestID id)
{
  if(!m->package)
    return "No package argument.";

  if(completely_downloaded(((int)m->package)))
    id->variables[m->variable]="1";
  if(installed[m->package])
    id->variables[m->installed_variable]="1";
  return "";
}

string container_update_download_progress_output(string t, mapping m,
					  string c, RequestID id)
{
  array(int) packages=sort(indices(package_downloads));
  array res=({ });

  foreach(packages, int package)
  {
    mapping pkg=pkginfo[(string)package];
    pkg->size=sprintf("%.1f",pkg->size/1024.0);
    pkg->progress=sprintf("%3.1f",package_downloads[package]->percent_done());
    res+=({ pkg });
  }

  return do_output_tag(m, res, c, id);
}

mapping get_package_info(string dir, int package)
{
  object fs=Filesystem.Tar(dir+package+".tar");
  Stdio.File fd=fs->open("info/"+package+".info", "r");
  if(!fd)
    return 0;
  string s=fd->read();
  fd->close();
  array stat=file_stat(roxen_path(QUERY(pkgdir))+package+".tar");
  return parse_info_file(s) | ([ "size":stat[1] ]);    
}

// Find any new packages in the package dir that's not in the database,
// and index them there.
string tag_update_scan_local_packages(string t, mapping m,
				      RequestID id)
{
  array(int) packages=sort((array(int))glob("*.tar",r_get_dir(QUERY(pkgdir))));
  foreach(packages, int package)
  {
    mapping pkg=pkginfo[(string)package];
    if(!pkg)
    {
      mapping tmp=get_package_info(roxen_path(QUERY(pkgdir)),package);
      if(tmp && tmp->id)
      {
	pkginfo[tmp->id]=tmp;
	pkginfo->sync();
	report_notice("Update: Added information about package number "
		      +tmp->id+".\n");
      }
    }
  }
  return "";
}

string container_update_downloaded_packages_output(string t, mapping m,
					    string c, RequestID id)
{
  array(int) packages=sort((array(int))glob("*.tar",r_get_dir(QUERY(pkgdir))));
  array res=({ });

  foreach(packages, int package)
  {
    mapping pkg=pkginfo[(string)package];
    if(pkg && !installed[(string)package])
    {
      pkg->size=sprintf("%3.1f",(float)pkg->size/1024.0);
      res+=({ pkg });
    }
  }

  return do_output_tag(m, res, c, id);
}

// Safely unpack a file
string|void unpack_file(Stdio.File from, string to)
{
  string prefix="../";
  if(r_file_stat(prefix+to))
  {
    if(!r_mv(prefix+to,prefix+to+"~"))
      throw(sprintf("Could not move %s to %s.\n",prefix+to,prefix+to+"~"));
  }
  else
    if(!mkdirhier(prefix+to))
      throw(sprintf("Could not make directory %s.\n",
		    combine_path(prefix+to,"../")));

  string block;
  Stdio.File f;

  mixed err=catch
  {
    if(!(f=open(prefix+to,"wc")))
      throw(sprintf("Could not open %s for writing.",
		    prefix+to));

    do {
      block = from->read(8192);
      if (!block)
	break;
      if(f->write(block)!=sizeof(block))
	throw(sprintf("Failed to write %s. Disk might be full.\n", prefix+to));
    } while (block != "");
  };

  if(err)
  {
    catch(f->close());
    r_rm(prefix+to);
    r_mv(prefix+to+"~", prefix+to);
    throw(err);
  }

  r_rm(prefix+to+"~");
  return "Wrote "+prefix+to+".";
}

array(string) low_unpack_tarfile(Filesystem.Tar fs, string dir, mapping errors)
{
  array(string) res=({ });
  foreach(sort(fs->get_dir(dir)), string entry)
    if(fs->stat(entry)->isdir())
      res += low_unpack_tarfile(fs, entry, errors);
    else
    {
      string tmp;
      mixed err;
      err=catch(tmp=unpack_file(fs->open(entry,"r"), entry));
      if(tmp)
	res+=({ tmp });
      if(err)
      {
	res+=({ "<b>Error:</b> "+err });
	errors->found=1;
      }
    }
  return res;
}

string unpack_tarfile(string tarfile)
{
  object fs;
  mixed err;
  if(err=catch(fs=Filesystem.Tar(tarfile)))
    throw("Could not open tar file "+tarfile+".\n");
  array res;
  mapping errors=([]);
  if(err=catch(res=low_unpack_tarfile(fs, "", errors)))
    throw(err);
  if(errors->found)
    throw(res*"<br>");
  return res*"<br>";
}


// Really unpack/install a package.
string tag_update_install_package(string t, mapping m, RequestID id)
{
  if(!m->package)
    return "No package argument";

  if(!completely_downloaded((int)m->package))
    return "<b>Package not completely downloaded.</b>";


  mixed err;
  string res;
  if(err=catch(res=unpack_tarfile(roxen_path(QUERY(pkgdir))+(int)m->package+".tar")))
    return err+"<br><br><b>Could not install package. Fix the problems above and try again.</b>";

  id->variables[m->variable]="1";
  installed[m->package]=1;
  installed->sync();

  Stdio.recursive_rm(roxen_path("$VVARDIR/precompiled/"));
  
  return res+"<br><br><b>Package installed completely.</b>";
}

array(string) tarfile_contents(string|object tarfile, void|string dir)
{
  if(dir=="/info/")
    return ({ });
  if(!dir)
    dir="";
  if(stringp(tarfile))
    tarfile=Filesystem.Tar(tarfile);

  array res = ({ });

  foreach(sort(tarfile->get_dir(dir)), string entry)
  {
    if(tarfile->stat(entry)->isdir())
      res += tarfile_contents(tarfile,entry);
    else
      res += ({ tarfile->stat(entry)->lsprint(1) });
  }
  return res;
}

string tag_update_package_contents(string t, mapping m, RequestID id)
{
  if(!m->package)
    return "No package argument.";

  return tarfile_contents(roxen_path(QUERY(pkgdir))+m->package+".tar")*"\n";
}

string tag_update_update_list(string t, mapping m, RequestID id)
{
  if(QUERY(do_external_updates))
  {
    if(!updater)
      updater=UpdateInfoFiles();
    else
    {
      remove_call_out(updater->do_request);
      updater->do_request();
    }
  }
  return "";
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
  mapping m = ([ "host":"community.roxen.com:80",
		 "user-agent": roxen->real_version ]);

  if(sizeof(QUERY(userpassword)))
    m->authorization="Basic "+MIME.encode_base64(QUERY(userpassword));
  return m;
}


int completely_downloaded(int num)
{
  array stat=r_file_stat(roxen_path(QUERY(pkgdir))+num+".tar");

  return (stat && (stat[1]==pkginfo[(string)num]->size));
}


void start_package_download(int num)
{
  if(search(indices(package_downloads), num)!=-1)
    throw("Package download already in progress for package "+num+".\n");

  if(completely_downloaded(num))
    throw("Package "+num+" already completely downloaded.\n");

  package_downloads[num]=GetPackage(num);
}


string proxyprefix()
{
  if(sizeof(QUERY(proxyserver)))
    return "http://community.roxen.com";
  else
    return "";
}

string get_server()
{
  if(sizeof(QUERY(proxyserver)))
    return QUERY(proxyserver);
  return "community.roxen.com";
}

int get_port()
{
  if(sizeof(QUERY(proxyserver)))
    return QUERY(proxyport);
  return 80;
}


/*--- Custom HTTP fetchers ------------------------------------*/

class GetPackage
{
  int num;

  inherit Protocols.HTTP.Query;

  float percent_done()
  {
    int b=total_bytes();
    if(b==-1)
      return 0.0;
    return (float)downloaded_bytes() / (float)b;
  }

  void request_ok(object httpquery, int _num)
  {
    // FIXME: rewrite this to use a file object and stream to disk?
    Stdio.File f;
    num=_num;

    if(catch(f=Stdio.File(roxen_path(QUERY(pkgdir))+num+".tar","wc")))
    {
      report_error("Update: Failed to open file for writing: "+
		   roxen_path(QUERY(pkgdir))+num+".tar\n");
      catch(m_delete(package_downloads, num));
      return;
    }
    if(catch(f->write(httpquery->data())))
    {
      report_error("Update: Failed to write package to file: "+
		   roxen_path(QUERY(pkgdir))+num+".tar\n");
      catch(r_rm(QUERY(pkgdir)+num+".tar"));
      catch(m_delete(package_downloads, num));
      return;
    }
    f->close();
    catch(m_delete(package_downloads, num));
  }

  void request_fail(object httpquery, int num)
  {
    report_error("Update: Failed to connect to update server to fetch "
		 "package number "+num+".\n");
    catch(m_delete(package_downloads, num));
  }

  void create(int pkgnum)
  {
    set_callbacks(request_ok, request_fail, pkgnum);
    async_request(get_server(), get_port(),
		  "GET "+proxyprefix()+"/updateserver/packages/"+
		  pkgnum+".tar HTTP/1.0",
		  get_headers());
  }
}


string get_containers(string t, mapping m, string c, int line, mapping res)
{
  if(sizeof(t) && t[0]!='/')
    res[t]=c;
}

mapping parse_info_file(string s)
{
  mapping res=([]);
  parse_html_lines(s,
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
  return res;
}

class GetInfoFile
{
  inherit Protocols.HTTP.Query;


  void request_ok(object httpquery, int num)
  {
    spider;
    mapping res=([]);

    if(httpquery->status!=200)
    {
      report_error("Update: Wrong answer from server for package %d. "
		   "HTTP status code: %d\n",num,httpquery->status);
      return;
    }

    res=parse_info_file(httpquery->data());
    res->size=(int)httpquery->headers->pkgsize;
    pkginfo[(string)num]=res;
    pkginfo->sync();
    report_notice("Update: Added information about package number "
		  +num+".\n");
  }

  void request_fail(object httpquery, int num)
  {
    report_error("Update: Failed to connect to update server to fetch "
		 "information about package number "+num+".\n");
  }

  void create(int pkgnum)
  {
    set_callbacks(request_ok, request_fail, pkgnum);
    async_request(get_server(), get_port(),
		  "GET "+proxyprefix()+"/updateserver/packages/"+pkgnum+
		  ".info HTTP/1.0",
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

    if(httpquery->status==401)
    {
      report_error("Update: Authorization failed. Will not receive any "
		   "new update packages.\n");
      return;
    }
    
    if(httpquery->status!=200 || lines[0]!="update" || sizeof(lines)<3)
    {
      report_error("Update: Wrong answer from server. "
		   "HTTP status code: %d\n",httpquery->status);
      return;
    }

    array(int) new_packages=decode_ranges(lines[1]);
    array(int) delete_packages=decode_ranges(lines[2]);

    if(sizeof(new_packages))
      report_notice("Update: Found new packages: "+
		    ((array(string))new_packages)*", "+"\n");
    else
      report_notice("Update: No new packages found.\n");

    if(sizeof(delete_packages))
      report_notice("Update: Deleting packages: "+
		    ((array(string))delete_packages)*", "+
		    "\n");

    foreach(new_packages, int i)
      GetInfoFile(i);

    foreach(delete_packages, int i)
      catch(pkginfo->delete((string)i));

    catch(misc["last_updated"]=time());
  }

  void request_fail(object httpquery)
  {
    report_error("Update: Failed to connect to update server to fetch "
		 "information about new packages.\n");
  }

  string version_as_float()
  {
    string s=roxen_version();
    string major, rest;
    sscanf(s,"%s.%s",major,rest);
    return (string)(float)sprintf("%s.%s",major,rest-".");
  }

  
  void do_request()
  {
    async_request(get_server(), get_port(),
		  "POST "+proxyprefix()+"/updateserver/get_packages HTTP/1.0",
		  get_headers() |
		  (["content-type":"application/x-www-form-urlencoded"]),
		  "roxen_version="+version_as_float()+"&"+
		  "have_packages="+
		  encode_ranges((array(int))indices(pkginfo)));
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
