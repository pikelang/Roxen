// This code has to work both in 'roxen.pike' and all modules
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
#ifdef SOCKET_DEBUG
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
  object f;
  f=new(File);
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
  f->set_nonblocking(0, connected, failed);
  f->set_id( ({ callback, args, f }) );
//#ifdef DEBUG
  mark_fd(f->query_fd(), "async socket communication: -> "+host+":"+port);
//#endif
  if(catch(f->connect(host, port))) // Illegal format...
  {
#ifdef SOCKET_DEBUG
    perror("SOCKETS: Illegal internet address in connect in async comm.\n");
#endif
    callback(0, @args);
    destruct(f);
    return;
  }
}

varargs void async_connect(string host, int port, function callback,
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
  object pipe=new(Pipe);
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

varargs void async_cache_connect(string host, int port, string cl, 
				 string entry, function callback,
				 mixed ... args)
{
  object cache;
#ifdef SOCKET_DEBUG
  perror("SOCKETS: async_connect requested to "+host+":"+port+"\n");
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



