#include <module.h>
inherit "module";
object proxy;
constant thread_safe = 1;
constant cvs_version = "$Id: upgrade_proxy.pike,v 1.6 1998/03/11 19:42:39 neotron Exp $";

array register_module()
{
  return ({0,"Upgrade Server Proxy",
	     ("<b>Proxies</b> the Upgrade Server Protocol. This is not an "
	      "actual upgrade server.") });
}

class Proxy
{
  object server, client;
  string ch, cp;

  void close_client()
  {
    if(client) destruct(client);
  }
  
  void `->(string ident)
  {
    remove_call_out(close_client);
    call_out(close_client, 20);
    if(!client) client = RoxenRPC.Client(ch,(int)cp,"upgrade");
    return predef::`->(client, ident);
  }
  
  void create(int port, string master)
  {
    server = RoxenRPC.Server(0, port);
    sscanf(master, "%s:%s", ch, cp);
    server->provide("upgrade", this_object());
  }
}

void start()
{
  if(proxy) proxy->close_client();
  proxy = Proxy(query("port"), query("master"));
}

void create()
{
  defvar("port", 55875, "Proxy Port", TYPE_INT,  "The port to bind to");
  defvar("master", "skuld.idonex.se:23", "Upgrade server master", TYPE_STRING,
	 "The server to connect to");
}
