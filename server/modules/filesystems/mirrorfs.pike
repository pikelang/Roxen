constant cvs_version="$Id: mirrorfs.pike,v 1.10 1998/03/11 19:42:35 neotron Exp $";
constant thread_safe=1;

import RoxenRPC;
#include <roxen.h>
#include <module.h>
#include <stat.h>
inherit "filesystem";

array register_module()
{
  return ({MODULE_LOCATION,"Mirror Filesystem",
	     "This is a mirror filesystem, it mirrors the virtual file-tree "
	     "of another Roxen server.\n<p>The filesystem connects to a "
	     "Mirror Server using Roxen RPC.<p>\n"
	     "The searchpath of the Mirror Filesystem is used as a "
	     "cache.  It is not a good idea to use the same cache-directory "
	     "in multiple mirror filesystems, and never store other files in it"
	     ". There is a mirror for www.roxen.com at skuld.idonex.se:2000, "
	     "if you want to test this module.<p><b>Do not under any "
	     "circumstances let this module connect to a mirror server in the "
	     "same Roxen server. It will not work. At all.</b>"});
}

void create()
{
  ::create();

  defvar("mserver", "www.roxen.com:2000", "Mirror Server", TYPE_STRING,
	 "The location to mirror from. This is <b>not</b> the http location, "
	 "it is the one entered in the 'mirror server' on the remote site.");

  defvar("mrefresh", 24, "Mirror Refresh", TYPE_INT,
	 "Check the pages this often (in hours). Please note that the "
	 "pages are not reloaded from the source server unless they actually "
	 "have changed, and that this is all a lot faster than with "
	 "FTP mirror. At most one file per second is checked. The update might "
	 "therefore take quite a while anyway.");
}

object _rpc;
object rpc(int|void force)
{
  if(force|| !_rpc || catch{_rpc->open();}) {
    array s = query("mserver")/":";
    if (sizeof(s) < 2) {
      s = ({ s[0], "80" });
    }
    if (catch {
      _rpc = Client(s[0],(int)s[1],"mirror",1);
    }) {
      _rpc = 0;
      perror("mirrorfs:Failed to connect to server %s:%s\n",
	     s[0], s[1]);
    }
  }
  return _rpc;
}

array update_queue = ({});

void get_remote_dir(string dir);

void update_file(string path, string rpath)
{
  if(sscanf(rpath, "%s.dirents", rpath))
  {
    get_remote_dir(rpath);
    return;
  }
  object _rpc = rpc();
  if (!_rpc) {
    return;
  }
  array s1=_rpc->stat_file(rpath), s2=file_stat(path);
  if(!s1)
    rm(path);
  else if(s1[ST_MTIME] > s2[ST_MTIME])
    rm(path);
}

void update_one(string fs_path, string rpath)
{
  array s1;
  mixed res;
  if(fs_path[-1]=='/') foreach(get_dir(fs_path)||({}), string file)
    if(((s1=file_stat(fs_path+file))[ST_SIZE] < 0))
    {
      if((res=open(path+file+"/"+".dirents","r")) &&
	 (res=decode_value(res->read(0x7ffffff))) && (res[0]==path))
	update_queue += ({ ({ fs_path+file+"/", rpath+file+"/" }) });
    }
    else
      update_queue += ({ ({ fs_path+file, rpath+file }) });
  else
    update_file(fs_path,rpath);
}

void update();

#ifdef THREADS
object lock = Thread.Mutex();
#endif /* THREADS */
void handle_update_queue()
{
#ifdef THREADS;
  mixed key;
  catch { key = lock->lock(); };
#endif /* THREADS */
  remove_call_out(handle_update_queue);
  if(sizeof(update_queue))
  {
    update_one(@update_queue[0]);
    update_queue=update_queue[1..];
    call_out(handle_update_queue, 1);
  } else
    call_out(update, query("mrefresh")*3600);
}


void update()
{
#ifdef THREADS;
  mixed key;
  catch { key = lock->lock(); };
#endif /* THREADS */
  update_queue = ({ ({path,""}) });
  handle_update_queue();
}

void start(int arg, object conf)
{
#ifdef THREADS;
  mixed key;
  catch { key = lock->lock(); };
#endif /* THREADS */
  ::start();
  call_out(update, query("mrefresh")*3600);
  if(conf) catch{rpc(1);};
}

void get_remote_dir(string dir)
{
#ifdef MODULE_DEBUG
  roxen_perror("get_remote_dir(\""+dir+"\")\n");
#endif /* MODULE_DEBOG */
  string l = combine_path(path,combine_path("/",dir+"/")[1..]);
  array d ;
  if(rpc() && (d=rpc()->get_dir(dir)))
  {
    mkdirhier(l+".dirents");
    rm(l+".dirents");
    Stdio.write_file(l+".dirents", encode_value(({ path, d })));
  }
}

void get_remote_file(string f)
{
#ifdef MODULE_DEBUG
  roxen_perror("get_remote_file(\""+f+"\")\n");
#endif /* MODULE_DEBOG */
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

class RemoteFile {
  object outbuffer, remote_file;
  function read_cb, close_cb;
  int query_fd(){ return -1;}

  int done;
  string data = "";
  mixed id;

  void set_id(mixed t){ id=t; };
  
  void set_nonblocking(function rc, function wc, function cc)
  {
    read_cb = rc;
    close_cb = cc;
    if(strlen(data)) rc(id,data);
    if(done) cc(id);
  }

  void set_blocking(function rc, function wc, function cc)
  {
    read_cb = close_cb = 0;
  }

  string read(int len)
  {
    if(strlen(data))
    {
      string q = data[..len-1];
      data = data[len .. ];
      return data;
    }
    return "";
  }
  
  void close()
  {
    /* NOOP */
  }

  void get_data()
  {
    string q = remote_file->read(1024);
    if(strlen(q) != 1024)
    {
      destruct(remote_file);
      done=1;
    }
    data += q;
    outbuffer->write( q );
    if(!done) call_out(get_data, 0);
    if(read_cb)
    {
      read_cb(id, data);
      data = "";
    }
    if(done)
    {
      outbuffer->close();
      if(close_cb) close_cb( id );
      outbuffer=remote_file=0;
    }
  }
  
  void create(object in, object out)
  {
    trace(1);
    remote_file = in;
    outbuffer = out;
    call_out(get_data, 0);
  }
  
};


object(RemoteFile) open_remote_file(string f)
{
#ifdef MODULE_DEBUG
  roxen_perror("open_remote_file(\""+f+"\")\n");
#endif /* MODULE_DEBOG */
  if(!strlen(f) || f[-1]=='/') f+="index.html";
  string l = combine_path(path,combine_path("/",f)[1..]);
  object o = rpc()->open_file( f );
  if(o)
  {
    mkdirhier(l); rm(l);
    object out = open(l, "wct");
    return RemoteFile( o, out );
  }
}

mixed find_local_file(string f, object id)
{
  string old_method = id->method;
  id->method="GET";
  mixed res = ::find_file(f, id);
  id->method=old_method;
  return res;
}

array find_dir(string s, object id)
{
  mixed res;
  if(objectp(res=find_local_file(s+".dirents",id)))
    if(res = decode_value(res->read(0x7ffffff)))
      if(res[0]==path) return res[1];
  get_remote_dir(s);
  if(objectp(res=find_local_file(s+".dirents",id)))
    return decode_value(res->read(0x7ffffff))[1];
}

array stat_file(string s, object id)
{
  array res;
  if(res=::stat_file(s,id)) return res;
#ifdef MODULE_DEBUG
  roxen_perror("remote_stat_file(\""+s+"\")\n");
#endif /* MODULE_DEBOG */
  return rpc() && rpc()->stat_file(s);
}


mixed find_file(string s, object id)
{
  mixed res;
#ifdef MODULE_DEBUG
  roxen_perror("find_file(\""+s+"\")\n");
#endif /* MODULE_DEBOG */
  if(res=::find_file(s,id)) return res;
  if((res=stat_file(s,id)) && res[ST_SIZE]<-1) return -1;
  if(!res) return 0;
//catch{
//  return open_remote_file(s);
//};
  get_remote_file(s);
  return ::find_file(s,id);
}

string status()
{
  if (rpc()) {
    return ("Connected OK<br>\n");
  }
  return("<font color=red>Failed to connect to server</font><br>\n");
}
