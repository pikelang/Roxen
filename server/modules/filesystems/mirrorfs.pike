import RoxenRPC;
#include <module.h>
inherit "filesystem";

array register_module()
{
  return ({MODULE_LOCATION,"Mirror Filesystem", "Documentation here"});
}

void create()
{
  ::create();

  defvar("mserver", "www.roxen.com:2000", "Mirror Server", TYPE_STRING,
	 "The location to mirror from. This is <b>not</b> the http location, "
	 "it is the one entered in the 'mirror server' on the remote site.");

  defvar("mrefresh", 2, "Mirror Refresh", TYPE_INT,
	 "Check the pages this often (in hours). Please note that the "
	 "pages are not reloaded from the source server unless they actually "
	 "have changed, and that this is all a lot faster than with "
	 "FTP mirror. At most one file per second is checked. The updata might "
	 "therefore take quite a while.");
}

object _rpc;
object rpc(int|void force)
{
  array s = query("mserver")/":";
  if(force|| !_rpc || catch{_rpc->open();})
    _rpc = Client(s[0],(int)s[1],"mirror");
  return _rpc;
}

void start(int arg, object conf)
{
  ::start();
//  call_out(update, query("mrefresh"));
  if(conf) catch{rpc(1);};
}

void get_remote_dir(string dir)
{
  string l = combine_path(path,combine_path("/",dir+"/")[1..]);
  array d ;
  if(d=rpc()->get_dir(dir))
  {
    mkdirhier(l+".dirents");
    rm(l+".dirents");
    Stdio.write_file(l+".dirents", encode_value(d));
  }
}

void get_remote_file(string f)
{
  if(!strlen(f) || f[-1]=='/') f+="index.html";
  string l = combine_path(path,combine_path("/",f)[1..]);
  catch {
    string s = rpc()->get_file(f);
    if(s)
    {
      mkdirhier(l); rm(l);
      Stdio.write_file(l, s);
    }
  };
}

array find_dir(string s, object id)
{
  mixed res;
  perror("find dir "+s+"\n");
  if(objectp(res=::find_file(s+".dirents",id)))
    return decode_value(res->read(0x7ffffff));
  perror("get remote dir "+s+"\n");
//  if(s[-1]=='/' || !strlen(s))
  get_remote_dir(s);
  if(objectp(res=::find_file(s+".dirents",id)))
    return decode_value(res->read(0x7ffffff));
}

array stat_file(string s, object id)
{
  array res;
  if(res=::stat_file(s,id)) return res;
  perror("Remote Stat file "+s+"\n");
  return rpc()->stat_file(s);
}


mixed find_file(string s, object id)
{
  mixed res;
  if(res=::find_file(s,id))
    return res;
  perror("Get remote file "+s+"\n");
  get_remote_file(s);
  if(res=::find_file(s,id)) return res;
  perror("Get remote dir "+s+"?\n");
  if(stat_file(s,id)) return -1;
}
