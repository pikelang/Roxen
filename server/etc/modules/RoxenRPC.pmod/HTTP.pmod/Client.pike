//
// $Id$
//
// Roxen HTTP RPC
//
// Copyright © 1996 - 2009, Roxen IS
//

private int port;
private string host, path;

private object rpc;

private void disconnect()
{
  rpc = 0;
}

private void establish()
{
  int rpc_port;
  object o = Stdio.File();
  signal(signum("SIGALRM"), lambda() { error("timeout"); });
  alarm(5);
  o->connect(host, port);
  o->write(sprintf("GET %s\r\n", "/"+combine_path(path, "rpc/")));
  sscanf(o->read(), "port %d", rpc_port);
  rpc = RoxenRPC.Client(host, rpc_port, "Q");
  signal(signum("SIGALRM"), lambda() {});
  alarm(time());
}

mixed `->(string var)
{
  if(!rpc) establish();
  remove_call_out(disconnect);
  call_out(disconnect, 60);
  mixed v;
  if(catch(v = predef::`->(rpc,var))) {
    establish();
    v = predef::`->(rpc,var);
  }
  return v;
}

void create(string url)
{
  if(url[-1] == '/')
    url = url[0..(sizeof(url)-2)];
  
  Standards.URI uri = Standards.URI(url);
  host = uri->host;
  port = uri->port || 80;
  path = uri->path || "";
}
