import RoxenRPC;
#include <module.h>
inherit "module";
object rpc;

class MirrorServer {
  import Stdio;
  string base;
  object fid;

  int open(){ return 1; }


  static class MyFile {
    object q;

    string read(int len)
    {
      return q->read(len);
    }
    
    void create(string fn)
    {
      q = open(fn,"r");
    }
  };


  static class MyStringFile {
    string b;

    string read(int len)
    {
      string q = b[..len-1];
      b = b[len..];
      return q;
    }
    
    void create(string fn)
    {
      b=fn;
    }
  };

  
  object open_file(string url)
  {
    url = replace(base+url,"//","/");
    string foo = roxen->real_file(url, fid);
    if(foo) return MyFile(foo);
    return MyStringFile(fid->conf->try_get_file(url, fid));
  }
  
  string get_file(string url)
  {
    url = replace(base+url,"//","/");
    string foo = roxen->real_file(url, fid);
    if(foo) return read_bytes(foo);
    return fid->conf->try_get_file(url, fid);
  }

  string get_dir(string url)
  {
    url = replace(base+url,"//","/");
    return fid->conf->find_dir(url,fid);
  }

  string stat_file(string url)
  {
    return fid->conf->stat_file(base+url,fid);
  }

  void create(object fi, string ba)
  {
    roxen_perror("Mirror server ok..\n");
    fid = fi;
    base=ba;
  }
}

class FakeID
{
  inherit "protocols/http";

  void create(object c)
  {
    conf = c;
  }
};

array register_module()
{
  return ({0,"Mirror Server",
	     "This is the server end of the Roxen Mirror system.<br>\n"
	     "Add this module to any server you want to mirror <b>on another "
	     "server</b>. You can not mirror to the same Roxen server, since that "
	     "would cause a deadlock (the mirror filesystem does a blocking "
	     "request to the mirror server, which cannot serve it, since the "
	     " mirror filesystem is blocking the Roxen server)\n" });
}

void create()
{
  defvar("port", "any:2000", "Mirror Server port", TYPE_STRING);
  defvar("base", "/", "Base URL", TYPE_STRING);
}

object server;
void start(int arg, object conf)
{
  if(conf)
    catch
    {
      array a = lower_case(query("port"))/":";
      object privs = ((program)"privs")("Opening Mirror Server Port: \"" +
					query("port") + "\"\n");
      server = Server(a[0]!="any"?a[0]:0,(int)a[1]);
      privs = 0;
      server->provide("mirror", MirrorServer(FakeID(conf),query("base")));
    };
}
