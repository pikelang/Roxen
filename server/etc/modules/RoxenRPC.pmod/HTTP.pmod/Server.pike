//
// $Id$
//
// Roxen HTTP RPC
//
// Copyright © 1996 - 2009, Roxen IS
//

private int port;
private string host;

private object rpc;
private function security;

mapping http(string path)
{
  if(path == "rpc/")
    return ([ "raw":1, "data":"port "+port ]);
}

private int ip_security(string ip)
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
