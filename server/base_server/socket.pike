// This code has to work both in 'roxen.pike' and all modules
// string _cvs_version = "$Id: socket.pike,v 1.13 1999/03/05 01:59:53 grubba Exp $";

#if !efun(roxen)
#define roxen roxenp()
#endif

#if DEBUG_LEVEL > 19
#ifndef SOCKET_DEBUG
# define SOCKET_DEBUG
#endif
#endif

private void connected(array args)
{
  if (!args) {
#ifdef SOCKET_DEBUG
    perror("SOCKETS: async_connect: No arguments to connected\n");
#endif /* SOCKET_DEBUG */
    return;
  }
#ifdef SOCKET_DEBUG
  if (!args[0]) {
    perror("SOCKETS: async_connect: No arguments[0] to connected\n");
    return;
  }
  if (!args[1]) {
    perror("SOCKETS: async_connect: No arguments[1] to connected\n");
    return;
  }
  if (!args[2]) {
    perror("SOCKETS: async_connect: No arguments[2] to connected\n");
    return;
  }
  perror("SOCKETS: async_connect ok.\n");
#endif
  args[2]->set_id(0);
  args[0](args[2], @args[1]);
}

private void failed(array args)
{
#ifdef SOCKET_DEBUG
  perror("SOCKETS: async_connect failed\n");
#endif
  args[2]->set_id(0);
  destruct(args[2]);
  args[0](0, @args[1]);
}

private void got_host_name(string host, string oh, int port,
			   function callback, mixed ... args)
{
  if(!host)
  {
#ifdef SOCKET_DEBUG
    perror("SOCKETS: got_hostname - no host ("+oh+")\n");
#endif
    callback(0, @args);
    return;
  }
  object f;
  f=Stdio.File();
#ifdef SOCKET_DEBUG
  perror("SOCKETS: async_connect "+oh+" == "+host+"\n");
#endif
  if(!f->open_socket())
  {
#ifdef SOCKET_DEBUG
    perror("SOCKETS: socket() failed. Out of sockets?\n");
#endif
    callback(0, @args);
    destruct(f);
    return;
  }
  f->set_id( ({ callback, args, f }) );
  // f->set_nonblocking(0, connected, failed);
  f->set_nonblocking(0,0,0);
#ifdef FD_DEBUG
  mark_fd(f->query_fd(), "async socket communication: -> "+host+":"+port);
#endif
  int res=0;
  array err;
  if(err=catch(res=f->connect(host, port))||!res) // Illegal format...
  {
//#ifdef SOCKET_DEBUG
    perror("SOCKETS: Illegal internet address (" + host + ":" +port + ")"
	   " in connect in async comm.\n");
    if(err&&err[1])
      perror("SOCKETS: " + err[0] - "\n" + " (" + host + ":" + port + ")"
	     " in connect in async comm.\n");
//#endif
    //f->set_nonblocking(0,0,0);
    callback(0, @args);
    destruct(f);
    return;
  }
  f->set_nonblocking(0, connected, failed);
}

void async_connect(string host, int port, function|void callback,
		   mixed ... args)
{
#ifdef SOCKET_DEBUG
  perror("SOCKETS: async_connect requested to "+host+":"+port+"\n");
#endif
  roxen->host_to_ip(host, got_host_name, host, port, callback, @args);
}


private void my_pipe_done(object which)
{
  if(objectp(which))
  {
    if(which->done_callback)
      which->done_callback(which);
    else
      destruct(which);
  }
}

void async_pipe(object to, object from, function|void callback, 
		mixed|void id, mixed|void cl, mixed|void file)
{
  object pipe=Pipe.pipe();
  object cache;

#ifdef SOCKET_DEBUG
  perror("async_pipe(): ");
#endif
  if(callback) 
    pipe->set_done_callback(callback, id);
  else if(cl) {
    cache = roxen->cache_file(cl, file);
    if(cache)
    {
#ifdef SOCKET_DEBUG
      perror("Using normal pipe with done callback.\n");
#endif
      pipe->input(cache->file);
      pipe->set_done_callback(my_pipe_done, cache);
      pipe->output(to);
      destruct(from);
      pipe->start();
      return;
    }
    if(cache = roxen->create_cache_file(cl, file))
    {
#ifdef SOCKET_DEBUG
      perror("Using normal pipe with cache.\n");
#endif
      pipe->output(cache->file);
      pipe->set_done_callback(my_pipe_done, cache);
      pipe->input(from);
      pipe->output(to);
      return;
    }
  }
#ifdef SOCKET_DEBUG
  perror("Using normal pipe.\n");
#endif
  pipe->input(from);
  pipe->output(to);
}

void async_cache_connect(string host, int port, string cl, 
			 string entry, function|void callback,
			 mixed ... args)
{
  object cache;
#ifdef SOCKET_DEBUG
  perror("SOCKETS: async_cache_connect requested to "+host+":"+port+"\n");
#endif
  cache = roxen->cache_file(cl, entry);
  if(cache)
  {
    object f;
    f=cache->file;
//    perror("Cache file is %O\n", f);
    cache->file = 0; // do _not_ close the actual file when returning...
    destruct(cache);
    return callback(f, @args);
  }
  roxen->host_to_ip(host, got_host_name, host, port, callback, @args);
}
