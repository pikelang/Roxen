import RoxenRPC;
#include <module.h>
inherit "module";
object rpc;

class MirrorServer {
  import Stdio;
  string base;
  object fid;

  int open(){ return 1; }

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
    perror("Mirror server ok..\n");
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
  return ({0,"Mirror Server", "Documentation here"});
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
      server = Server(a[0]!="any"?a[0]:0,(int)a[1]);
      server->provide("mirror", MirrorServer(FakeID(conf),query("base")));
    };
}
