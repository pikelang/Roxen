/*
 * $Id$
 *
 * The Roxen Update Client
 * Copyright © 2000 - 2009, Roxen IS.
 *
 * Author: Johan Schön
 * January-March 2000, June 2001
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
#include <roxen.h>
#include <module.h>
#include <stat.h>
#include <config_interface.h>

// --- Locale defines ---
//<locale-token project="roxen_start">   LOC_S </locale-token>
//<locale-token project="update_client"> LOC_U </locale-token>
//<locale-token project="update_client"> LOC_UD</locale-token>
#define LOC_S(X,Y)	_STR_LOCALE("roxen_start",X,Y)
#define LOC_U(X,Y)	_STR_LOCALE("update_client",X,Y)
#define LOC_UD(X,Y)     _DEF_LOCALE("update_client",X,Y)


constant module_type = MODULE_TAG|MODULE_CONFIG;
constant module_name = "Update client";
constant module_doc = "This is the update client. "
                      "If you have a Roxen user identity at the Roxen Community "
                      "website, feel free to enter your username and password in "
                      "the settings tab.";

function(void:Sql.Sql) db;
object updater;
SqlMapping pkginfo, misc, installed;

mapping(int:GetPackage) package_downloads = ([ ]);

int inited;

class SqlMapping
{
  string table;
  function(void:Sql.Sql) db;
  void create(function(void:Sql.Sql) _db, string _table)
  {
    db=_db;
    table=_table;
    DBManager.is_module_table( this_module(), "local", table,
			       "Information used by the update "
			       "client system.");
    catch(db()->query("create table "+table+
		    " ( name varchar(255) primary key ,"
		    "  value mediumblob)"));
  }

  mixed get(string handle)
  {
    array a=db()->query("select value from "+table+" where name=%s",handle);
    if(!sizeof(a))
      return 0;
    else
      return decode_value(a[0]->value);
  }

  mixed set(string handle, mixed x)
  {
    db()->query("replace into "+table+" (name,value) values (%s,%s)",
	      handle,encode_value(x));
  }

  void delete(string handle)
  {
    db()->query("delete from "+table+" where name=%s",handle);
  }
  
  array list_keys()
  {
    return db()->query("select name from "+table)->name;
  }
  
  mixed `[]=(string handle, mixed x){ return set(handle, x); }
  mixed `[](string handle)          { return get(handle); }
  array _indices()                  { return list_keys(); }
  array _values()                   { return map(_indices(), `[]); }
  void sync()  { }
}

void post_start()
{
  db=lambda(){ return DBManager.cached_get( "local" ); };

  pkginfo=SqlMapping(db,"update_pkginfo");
  misc=SqlMapping(db,"update_misc");
  installed=SqlMapping(db, "update_installed")
    ;
  mkdirhier(roxen_path(query("pkgdir")+"/foo"));
#ifndef OFFLINE
  if(query("do_external_updates"))
    updater=UpdateInfoFiles();
#endif
  UPDATE_NOISES("db == %O", ({ db }));
}

void start(int num, Configuration conf)
{
  if (my_configuration()->query ("compat_level") != roxen.roxen_ver)
    // Don't do anything - config_filesystem will reload us.
    return;

#ifndef ENABLE_UPDATE_CLIENT
  // This update system isn't in use, so drop this module.
  roxen.background_run (0, lambda (Configuration conf) {
			     conf->disable_module (module_local_id());
			     conf->save();
			     conf->save_me();
			   }, conf);
  return;
#endif

  if(conf && !inited)
  {
    inited++;
    UPDATE_NOISE("Initializing...");
#ifndef THREADS
    call_out( post_start, 1 );
#else
    thread_create( post_start );
#endif
  }
}

void stop()
{
  UPDATE_NOISE("Shutting down...");
  catch(destruct(updater));
  UPDATE_NOISE("Shutdown complete.");
}

void create()
{
  defvar("pkgdir", "$LOCALDIR/packages/", "Package directory",
	 TYPE_DIR, "");
  defvar("proxyserver", "", "Proxy host",
	 TYPE_STRING, "Leave empty to disable the use of a proxy server");
  defvar("proxyport", 80, "Proxy port",
	 TYPE_INT, "");
  defvar("userpassword", "", "Username and password",
	 TYPE_STRING,
	 "Format: username@host:password. "
	 "Will not use auth if left empty.");
  defvar("do_external_updates",0,"Connect to update.roxen.com for updates",
	 TYPE_FLAG,
         "Turn this off if you're inside a firewall and/or don't want to "
	 "reveal anything to the outside world.");
  Locale.register_project("update_client", "translations/%L/update_client.xml");
}

protected string describe_time_period( int amnt )
{
  if(amnt < 0) return LOC_U(18,"some time");
  amnt/=60;
  if(amnt < 120) return sprintf(LOC_U(32,"%d minutes"), amnt);
  amnt/=60;
  if(amnt < 48) return sprintf(LOC_U(33,"%d hours"), amnt);
  amnt/=24;
  if(amnt < 60) return sprintf(LOC_U(34,"%d days"), amnt);
  amnt/=(365/12);
  if(amnt < 30) return sprintf(LOC_U(35,"%d months"), amnt);
  amnt/=12;
  return sprintf(LOC_U(36,"%d years"), amnt);
}

class TagUpdateShowBacktrace {
  inherit RXML.Tag;
  constant name = "update-show-backtrace";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {

      int t;
      if(catch(t=misc["last_updated"]) || t==0)
	RXML.set_var("last_updated", LOC_U(37,"infinitely long"), "var");
      else
	RXML.set_var("last_updated", describe_time_period(time(1)-t), "var");

      return 0;
    }
  }
}

array(array) products = ({
  ({ LOC_UD(9, "Products"), "products" }),
  ({ LOC_UD(45, "Security"), "security" }),
  ({ LOC_UD(46, "Bugfixes"), "bugfixes" }),
  ({ LOC_UD(47, "Third party"), "3rdpart" }),
});

class TagEmitUpdateProducts {
  inherit RXML.Tag;
  constant name = "emit";
  constant plugin_name = "update-products";

  array(mapping(string:string)) get_dataset(mapping m, RequestID id) {
    return map( ({})+products, lambda(array x) {
				 return ([ "name":x[0], "cat":x[1] ]);
			       });
  }
}

class TagUpdateUninstallPackage {
  inherit RXML.Tag;
  constant name = "update-uninstall-package";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if(args->package)
	catch(installed->delete(args->package));
      return 0;
    }
  }
}

// <update-package>...</>
// Show information about one or several packages.
// Arguments: package, reverse, type, limit
class TagUpdatePackage {
  inherit RXML.Tag;
  constant name = "update-package";

  class Frame {
    inherit RXML.Frame;
    mapping vars=([]);
    array res=({ });
    string scope_name;
    int counter;

    array do_enter(RequestID id) {

      scope_name=args->scope;

      UPDATE_NOISES("<%s>: args = %O, contents = %O", ({ "update-package",
							 args, content }));
      int i=0;

      if(!args->package)
      {
	UPDATE_MSGS("pkginfo = %O", ({ pkginfo }));
	array(string) packages = indices(pkginfo);
	packages = sort(packages);
	if(args->reverse)
	  packages=reverse(packages);

	foreach(packages, string pkg)
	{
	  mapping p=pkginfo[pkg];
	  if( !args->installed && !installed[pkg] &&
	      ((args->type && p["package-type"]==args->type) || !args->type))
	    res+=({ p });
	  if(args->installed && installed[pkg])
	    res+=({ p });
	  i++;
	  if(args->limit && i>=(int)args->limit)
	    break;
	}
      }
      else {
	mapping p=pkginfo[args->package];
	if(p) {
	  mapping t=localtime((int)p["issued-date"]);
	  p->date=sprintf("%04d-%02d-%02d",1900+t->year,t->mon+1, t->mday);;
	  res=({ p });
	}
      }
    }

    int do_iterate(RequestID id) {
      if(!sizeof(res) || counter>=sizeof(res)) return 0;
      vars=res[counter++];
      return 1;
    }
  }
}

class TagUpdateStartDownload {
  inherit RXML.Tag;
  constant name = "update-start-download";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      mixed err=catch(start_package_download((int)args->package));
      if(err) report_error("Upgrade: %s",err);
      return 0;
    }
  }
}

class TagUpdatePackageIsDownloaded {
  inherit RXML.Tag;
  constant name = "update-package-is-downloaded";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
//   mapping(string:RXML.Type) req_arg_types = ([ "package" : RXML.t_text ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if(completely_downloaded(((int)args->package)))
	id->variables[args->variable]="1";
      if(installed[args->package])
	id->variables[args->installed_variable]="1";
      return 0;
    }
  }
}

class TagDownloadProgress {
  inherit RXML.Tag;
  constant name = "update-download-progress";

  class Frame {
    inherit RXML.Frame;

    mapping vars=([]);
    array(int) packages;
    int counter;

    array do_enter(RequestID id) {
      packages=sort(indices(package_downloads));
      return 0;
    }

    int do_iterate(RequestID id) {
      if(!sizeof(packages) || counter>=sizeof(packages)) return 0;
      int package=packages[counter++];
      vars=pkginfo[(string)package];
      vars->size=Roxen.sizetostring(vars->size);
      vars->progress=sprintf("%3.1f",100.0*package_downloads[package]->percent_done());
    }
  }
}

mapping get_package_info(string dir, int package)
{
  object fs=Filesystem.Tar(dir+package+".tar");
  Stdio.File fd=fs->open("info/"+package+".info", "r");
  if(!fd)
    return 0;
  string s=fd->read();
  fd->close();
  Stat stat=file_stat(roxen_path(query("pkgdir"))+"/"+package+".tar");
  return parse_info_file(s) | ([ "size":stat[1] ]);    
}

// Find any new packages in the package dir that's not in the database,
// and index them there.
class TagUpdateScanLocalPackages {
  inherit RXML.Tag;
  constant name = "update-scan-local-packages";

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      array(int) packages=sort((array(int))glob("*.tar",
	r_get_dir(query("pkgdir")+"/") ));
      foreach(packages, int package) {
	mapping pkg=pkginfo[(string)package];
	if(!pkg) {
	  mapping tmp=get_package_info(roxen_path(query("pkgdir"))+"/",package);
	  if(tmp && tmp->id) {
	    pkginfo[tmp->id]=tmp;
	    pkginfo->sync();
	    report_notice("Update: Added information about package number "
			  +tmp->id+".\n");
	  }
	}
      }
      return 0;
    }
  }
}

class TagUpdateDownloadedPackages {
  inherit RXML.Tag;
  constant name = "update-downloaded-packages";

  class Frame {
    inherit RXML.Frame;

    mapping(string:string) vars=([]);
    array res=({ });
    int counter;

    array do_enter(RequestID id) {
      array(int) packages=sort((array(int))glob("*.tar",
						r_get_dir(query("pkgdir")+"/")||
						({}) ));
      foreach(packages, int package) {
	mapping pkg=pkginfo[(string)package];
	if(pkg && !installed[(string)package]) {
	  pkg->size=Roxen.sizetostring((int)pkg->size);
	  res+=({ pkg });
	}
      }
      return 0;
    }

    int do_iterate(RequestID id) {
      if(!sizeof(res) || counter>=sizeof(res)) return 0;
      vars=res[counter++];
      return 1;
    }
  }
}

// Safely unpack a file
string|void unpack_file(Stdio.File from, string to)
{
  string prefix="../";
  if(sscanf(to,"/server/%s", to))
    prefix="";
  
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
  return "Wrote "+replace(prefix+to,"//","/")+".";
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
    throw(res*"<br />");
  return res*"<br />";
}


// Really unpack/install a package.
class TagUpdateInstallPackage {
  inherit RXML.Tag;
  constant name = "update-install-package";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;
//   mapping(string:RXML.Type) req_arg_types = ([ "package" : RXML.t_text ]);

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if(!completely_downloaded((int)args->package))
	return ({ "<b>"+ LOC_U(48, "Package not completely downloaded.") +"</b>" });

      mixed err;
      string res;
      if(err=catch(res=unpack_tarfile(roxen_path(query("pkgdir"))+"/"+(int)args->package+".tar")))
	return ({ err+"<br /><br /><b>"+
		  LOC_U(49, "Could not install package. Fix the problems above and try again.")
		  +"</b>" });

      id->variables[args->variable]="1";
      installed[args->package]=1;
      installed->sync();

      catch(Stdio.recursive_rm(roxen_path("$VVARDIR/precompiled/")));

      result = res+"<br /><br /><b>"+LOC_U(50, "Package installed completely.")+"</b>";
      return 0;
    }
  }
}

array(mapping) tarfile_contents(string|object tarfile, void|string dir)
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
    object stat=tarfile->stat(entry);
    if(stat->isdir())
      res += tarfile_contents(tarfile,entry);
    else
      res += ({ (["size":(string)stat->size, "path": stat->fullpath]) });
  }
  return res;
}

class TagUpdatePackageContents {
  inherit RXML.Tag;
  constant name = "update-package-contents";

  class Frame {
    inherit RXML.Frame;
    mapping vars=([]);
    array res=({});
    int counter;

    array do_enter(RequestID id) {
      if(!args->package)
	return ({ LOC_U(51, "No package argument.") });
      res=tarfile_contents(roxen_path(query("pkgdir"))+"/"+args->package+".tar");
      return 0;
    }

    int do_iterate(RequestID id) {
      if(!sizeof(res) || counter>=sizeof(res)) return 0;
      vars=res[counter++];
      return 1;
    }
  }
}

class TagUpdateUpdateList {
  inherit RXML.Tag;
  constant name = "update-update-list";
  constant flags = RXML.FLAG_EMPTY_ELEMENT;

  class Frame {
    inherit RXML.Frame;

    array do_return(RequestID id) {
      if(query("do_external_updates"))
	{
	  if(!updater)
	    updater=UpdateInfoFiles();
	  else
	    {
	      remove_call_out(updater->do_request);
	      updater->do_request();
	    }
	}
    }
  }
}

// ------------------------------------------------

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
  mapping m = ([ "host":"update.roxen.com:80",
		 "user-agent": roxen->real_version ]);

  if(sizeof(query("userpassword")))
    m->authorization="Basic "+MIME.encode_base64(query("userpassword"));
  return m;
}


int completely_downloaded(int num)
{
  Stat stat=r_file_stat(roxen_path(query("pkgdir"))+"/"+num+".tar");
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
  if(sizeof(query("proxyserver")))
    return "http://update.roxen.com";
  else
    return "";
}

string get_server()
{
  if(sizeof(query("proxyserver")))
    return query("proxyserver");
  return "update.roxen.com";
}

int get_port()
{
  if(sizeof(query("proxyserver")))
    return query("proxyport");
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

  void got_data()
  {
    // FIXME: rewrite this to use a file object and stream to disk?
    Stdio.File f;

    if(catch(f=Stdio.File(roxen_path(query("pkgdir"))+"/"+num+".tar","wc")))
    {
      report_error("Update: Failed to open file for writing: "+
		   roxen_path(query("pkgdir"))+num+".tar\n");
      catch(m_delete(package_downloads, num));
      return;
    }
    if(catch(f->write(data())))
    {
      report_error("Update: Failed to write package to file: "+
		   roxen_path(query("pkgdir"))+num+".tar\n");
      catch(r_rm(query("pkgdir")+"/"+num+".tar"));
      catch(m_delete(package_downloads, num));
      return;
    }
    f->close();
    catch(m_delete(package_downloads, num));
  }

  void request_ok(object httpquery, int _num)
  {
    async_fetch(got_data);
  }

  void request_fail(object httpquery, int num)
  {
    report_error("Update: Failed to connect to update server to fetch "
		 "package number "+num+".\n");
    catch(m_delete(package_downloads, num));
  }

  void create(int pkgnum)
  {
#ifdef OFFLINE
    report_warning("Cannot update files, since Roxen is offline\n");
#else
    num=pkgnum;
    set_callbacks(request_ok, request_fail);
    async_request(get_server(), get_port(),
		  "GET "+proxyprefix()+"/updateserver/packages/"+
		  pkgnum+".tar HTTP/1.0",
		  get_headers());
#endif
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
  int num;
  
  void got_data()
  {
    spider;
    mapping res=([]);

    if(status!=200)
    {
      report_error("Update: Wrong answer from server for package %d. "
		   "HTTP status code: %d\n",num,status);
      return;
    }

    res=parse_info_file(data());
    res->size=(int)headers->pkgsize;
    pkginfo[(string)num]=res;
    pkginfo->sync();
    report_notice("Update: Added information about package number "
		  +num+".\n");
  }

  void request_ok(object httpquery)
  {
    async_fetch(got_data);
  }

  void request_fail(object httpquery)
  {
    report_error("Update: Failed to connect to update server to fetch "
		 "information about package number "+num+".\n");
  }

  void create(int pkgnum)
  {
#ifdef OFFLINE
    report_warning("Cannot update files, since Roxen is offline\n");
#else
    num=pkgnum;
    set_callbacks(request_ok, request_fail);
    async_request(get_server(), get_port(),
		  "GET "+proxyprefix()+"/updateserver/packages/"+pkgnum+
		  ".info HTTP/1.0",
		  get_headers());
#endif
  }
}


class UpdateInfoFiles
{
  inherit Protocols.HTTP.Query;

  void got_data()
  {
    string s=data();

    array lines=s/"\n";

    if(status==401)
    {
      report_error("Update: Authorization failed. Will not receive any "
		   "new update packages.\n");
      return;
    }
    
    if(status!=200 || lines[0]!="update" || sizeof(lines)<3)
    {
      report_error("Update: Wrong answer from server. "
		   "HTTP status code: %d\n",status);
      return;
    }

    array(int) new_packages=decode_ranges(lines[1]);
    array(int) delete_packages=decode_ranges(lines[2]);

    if(sizeof(new_packages))
      report_notice(LOC_S(5, "Update: Found new packages: %s")+"\n",
		    ((array(string))new_packages)*", ");
    else
      report_notice(LOC_S(6, "Update: No new packages found.")+"\n");

    if(sizeof(delete_packages))
      report_notice("Update: Deleting packages: "+
		    ((array(string))delete_packages)*", "+
		    "\n");

    foreach(new_packages, int i)
      GetInfoFile(i);

    foreach(delete_packages, int i)
      catch(pkginfo->delete((string)i));

    catch(misc["last_updated"]=time(1));
  }
  
  void request_ok(object httpquery)
  {
    async_fetch(got_data);
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
    buf="";
    headerbuf="";
    async_request(get_server(), get_port(),
		  "POST "+proxyprefix()+"/updateserver/get_packages HTTP/1.0",
		  get_headers() |
		  (["content-type":"application/x-www-form-urlencoded"]),
		  "roxen_version="+version_as_float()+"&"+
		  "sysname="+uname()->sysname+"&"+
		  "machine="+uname()->machine+"&"+
		  "release="+uname()->release+"&"+
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
#ifdef OFFLINE
    report_warning("Cannot update files, since Roxen is offline\n");
#else
    set_callbacks(request_ok, request_fail);
    call_out(do_request,1);
#endif
  }
}
