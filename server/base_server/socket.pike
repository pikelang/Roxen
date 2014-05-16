// This file is part of Roxen WebServer.
// Copyright © 1996 - 2009, Roxen IS.
// $Id$

#define roxen roxenp()

#ifdef SOCKET_DEBUG
# define SOCKET_WERR(X) report_debug("SOCKETS: "+X+"\n");
#else
# define SOCKET_WERR(X)
#endif

private void connected(array args)
{
  if (!args) {
    SOCKET_WERR("async_connect: No arguments to connected");
    return;
  }
#ifdef SOCKET_DEBUG
  if (!args[0]) {
    SOCKET_WERR("async_connect: No arguments[0] to connected");
    return;
  }
  if (!args[1]) {
    SOCKET_WERR("async_connect: No arguments[1] to connected");
    return;
  }
  if (!args[2]) {
    SOCKET_WERR("async_connect: No arguments[2] to connected");
    return;
  }
  SOCKET_WERR("async_connect ok.");
#endif
  args[2]->set_id(0);
  args[0](args[2], @args[1]);
}

private void failed(array args)
{
  SOCKET_WERR("async_connect failed");
  args[2]->set_id(0);
  destruct(args[2]);
  args[0](0, @args[1]);
}

private void got_host_name(string host, string oh, int port,
			   function callback, mixed ... args)
{
  if(!host)
  {
    SOCKET_WERR("got_hostname - no host ("+oh+")");
    callback(0, @args);
    return;
  }
  Stdio.File f = Stdio.File();
  SOCKET_WERR("async_connect "+oh+" == "+host);
  if(!f->open_socket())
  {
    SOCKET_WERR("socket() failed. Out of sockets?");
    callback(0, @args);
    destruct(f);
    return;
  }
  f->set_id( ({ callback, args, f }) );
  f->set_nonblocking(0, connected, failed);
  // f->set_nonblocking(0,0,0);
#ifdef FD_DEBUG
  mark_fd(f->query_fd(), "async socket communication: -> "+host+":"+port);
#endif
  int res=0;
  array err;
  if((err=catch(res=f->connect(host, port)))||!res) // Illegal format...
  {
    report_debug("SOCKETS: Illegal internet address (" + host + ":" +port + ")"
		 " in connect in async comm.\n");
    if(err&&arrayp(err)&&err[1])
      report_debug("SOCKETS: " + err[0] - "\n" + " (" + host + ":" + port + ")"
		   " in connect in async comm.\n");
    f->set_nonblocking(0,0,0);
    callback(0, @args);
    destruct(f);
    return;
  }
  // f->set_nonblocking(0, connected, failed);
}

void async_connect(string host, int port, function|void callback,
		   mixed ... args)
{
  SOCKET_WERR("async_connect requested to "+host+":"+port);
  roxen->host_to_ip(host, got_host_name, host, port, callback, @args);
}


void my_pipe_done(Pipe.pipe which)
{
  if(objectp(which))
  {
    if(which->done_callback)
      which->done_callback(which);
    else
      destruct(which);
  }
}

void async_pipe(Stdio.File to, Stdio.File from,
                function|void callback,
		mixed|void id, mixed|void cl, mixed|void file)
{
  object pipe=Pipe.pipe();
  object cache;

  SOCKET_WERR("async_pipe(): ");
  if(callback)
    pipe->set_done_callback(callback, id);
  else if(cl) {
    cache = roxen->cache_file(cl, file);
    if(cache)
    {
      SOCKET_WERR("Using normal pipe with done callback.");
      pipe->input(cache->file);
      pipe->set_done_callback(my_pipe_done, cache);
      pipe->output(to);
      destruct(from);
      pipe->start();
      return;
    }
    if(cache = roxen->create_cache_file(cl, file))
    {
      SOCKET_WERR("Using normal pipe with cache.");
      pipe->output(cache->file);
      pipe->set_done_callback(my_pipe_done, cache);
      pipe->input(from);
      pipe->output(to);
      return;
    }
  }
  SOCKET_WERR("Using normal pipe.");
  pipe->input(from);
  pipe->output(to);
}

void async_cache_connect(string host, int port, string cl,
			 string entry, function|void callback,
			 mixed ... args)
{
  object cache;
  SOCKET_WERR("async_cache_connect requested to "+host+":"+port);
  cache = roxen->cache_file(cl, entry);
  if(cache)
  {
    object f;
    f=cache->file;
//    report_debug("Cache file is %O\n", f);
    cache->file = 0; // do _not_ close the actual file when returning...
    destruct(cache);
    return callback(f, @args);
  }
  roxen->host_to_ip(host, got_host_name, host, port, callback, @args);
}
