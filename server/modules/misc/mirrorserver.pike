#include <module.h>
inherit "module";

#ifndef MIRRORSERVER_DEBUG
#define MIRRORSERVER_DEBUG
#endif /* MIRRORSERVER_DEBUG */

constant cvs_version = "$Id: mirrorserver.pike,v 1.15 1999/04/22 09:10:43 per Exp $";

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
    string foo = fid->conf->real_file(url, fid);
    if(foo) return MyFile(foo);
    return MyStringFile(fid->conf->try_get_file(url, fid));
  }
  
  string get_file(string url)
  {
    url = replace(base+url,"//","/");
    string foo = fid->conf->real_file(url, fid);
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

// FIXME: Should probably be destructed on module reload.
object server;
void start(int arg, object conf)
{
  if(conf) {
    mixed err;
    if (err = catch {
      array(string) a = lower_case(query("port"))/":";
      object privs;
      if (((int)a[1]) < 1024)
	privs = Privs("Opening Mirror Server port below 1024 \"" +
		      query("port") + "\"\n");
      server = RoxenRPC.Server(a[0]!="any"?a[0]:0,(int)a[1]);
      privs = 0;
      server->provide("mirror", MirrorServer(FakeID(conf),query("base")));
    }) {
      if (!server) {
	report_error("Failed to initialize Mirror Server on port \"" +
		     query("port") + "\"\n");
      }
#ifdef MIRRORSERVER_DEBUG
      report_error("Error:"+strerror(errno())+"\n"+describe_backtrace(err));
#endif /* MIRRORSERVER_DEBUG */
    }
  }
}

string status()
{
  if (!server) {
    return("<font color=red>Failed to open port.</font>\n");
  } else {
    return("Server is up.\n");
  }
}
