#define error(X) throw( ({ X, backtrace() }) )

class RemoteFunctionCall
{
  object server;
  function lock;
  string cl, me, pc;
  object master;

  mixed call(mixed ... args)
  {
    int len; object key = lock(); mixed data;
    data= encode_value(({ cl, me, args }));
    server->write(sprintf("%4c%s", strlen(data), data));
    data="";
    while(strlen(data) < 8) {
      data += server->read(4000,1);
      if(!strlen(data))
	error("Remote RPC server closed connection.\n");
    }
    sscanf(data, "%4c%s", len,data);
    if(strlen(data) < len) data += server->read(len-strlen(data));
    data = decode_value(data);

    /* The server returned a pointer to an object. */
    /* Build a new RPC object and return it... */
    if(data[0]==2)
      return object_program(master)( server, 0, data[1], !master->nolock, 0,1);
    /* The server returned a pointer to a program or function. */
    /* Build a new RPC function call object and return it... */
    else if(data[0]==3)
      return object_program(this_object())( 0, data[1], server, lock, master )
	->call;

    if(data[0]) return data[1];
    error("Remote error: "+data[1]);
  }

  void destroy()
  {
    string v = encode_value(([ "subtract_refs":cl ]));
    server->write(sprintf("%4c%s", strlen(v), v));
    if(server->read(1) != "!")
      error("server->subtract_refs("+cl+") failed\n");
  }

  void create(string m, string c, object s, function l, object mast)
  {
    me = m; cl = c; server = s; lock = l;
    master = mast;
    string v = encode_value(([ "add_refs":cl ]));
    server->write(sprintf("%4c%s", strlen(v), v));
    if(server->read(1) != "!")
      error("server->subtract_refs("+cl+") failed\n");
  }
}


string myclass;
object server = files.file();

int nolock = 0;
object lock = Thread.Mutex();

mixed `->(string id)
{
  return RemoteFunctionCall(id, myclass, server, lock->lock, this_object())->call;
}

void create(string|object ip, int port, string cl,
	    int|string|void lck, void|string key, int|void not_again)
{
  if(stringp(lck))
  {
    key = lck;
    lck = 0;
  }

  if(objectp(ip))
  {
    /* Server in ip... */
    server = ip;
  } else {
    if(!server->connect(ip, port)) error("Failed to connect to RPC server\n");
  }

  while(!not_again)
  {
    switch(server->read(1))
    {
     case "=":
      not_again=1;
     case "!":
      break;
     case "?":
      server->write("%4c%s", strlen(key||""), key||"");
      continue;
     default:
      error("Server there, but refused connection.\n");
    }
  }

  myclass = cl;

  if(!lck) { nolock=1; lock = class{ void lock(){}}(); }

  string v = encode_value(([ "add_refs":myclass ]));

  server->write(sprintf("%4c%s", strlen(v), v));

  if(server->read(1) != "!")
    error("server->add_refs("+myclass+") failed\n");
}

void destroy()
{
  catch
  {
    string v = encode_value(([ "subtract_refs":myclass ]));
    server->write(sprintf("%4c%s", strlen(v), v));
    if(server->read(1) != "!")
      error("server->subtract_refs("+myclass+") failed\n");
  };
}
