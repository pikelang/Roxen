// Roxen HTTP RPC
//
// Copyright (C) 1996, 1997 Informationsvävarna
//

static private int port;
static private string host, path;

static private object rpc;

static private void disconnect()
{
  rpc = 0;
}

static private void establish()
{
  int rpc_port;
  object o = files.file();
  o->connect(host, port);
  o->write(sprintf("GET %s\r\n", "/"+combine_path(path, "rpc/")));
  sscanf(o->read(), "port %d", rpc_port);
  rpc = RoxenRPC.Client(host, rpc_port, "Q");
}

mixed `->(string var)
{
  if(!rpc) establish();
  remove_call_out(disconnect);
  call_out(disconnect, 60);
  return predef::`->(rpc,var);
}

void create(string url)
{
  if(url[-1] == '/')
    url = url[0..(sizeof(url)-2)];
  
  sscanf(url-"http://", "%s:%d/%s", host, port, path);
  if(!port)
    port = 80;
  if(!path)
    path = "";
}
