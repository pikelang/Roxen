//
// $Id: Server.pike,v 1.3 1998/03/11 19:42:34 neotron Exp $
//
// Roxen HTTP RPC
//
// Copyright © 1996 - 1998, Idonex AB
//

static private int port;
static private string host;

static private object rpc;
static private function security;

mapping http(string path)
{
  if(path == "rpc/")
    return ([ "raw":1, "data":"port "+port ]);
}

static private int ip_security(string ip)
{
  ip = (ip/" ")[0];
  array a = gethostbyaddr(ip) || ({ ip });
  return search(Array.map(({ a[0] }) + a[1] + a[2], security),1)+1;
}

void create(object o, function|void security_in)
{
  rpc = RoxenRPC.Server(0, 0);
  if(security = security_in)
    rpc->set_ip_security(ip_security);
  rpc->provide("Q", o);
  
  string adr = rpc->query_address();
  host = (adr/" ")[0];
  port = (int) (adr/" ")[1];
}
