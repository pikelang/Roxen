/*
 * $Id$
 */

#define CHECK_IO_ERROR(FD, OP) do {					\
    if (int err = (FD)->errno())					\
      error ("Error " OP " to %O: %s\n", (FD), strerror (err));		\
  } while (0)

class Connection
{
#define WAITING 0
#define MORE_TO_COME 1
  object master, client;
  int mode;
  int expected_len;
  string buffer="";
  string sending = "";

  void done_data()
  {
    destruct();
  }
  
  void write_data()
  {
    if(strlen(sending)) {
      int l = client->write(sending);
      CHECK_IO_ERROR (client, "writing");
      sending = sending[l..];
    }
  }

  mapping classes = ([]);
  object object_for(program p, string cl)
  {
    if(classes[cl]) return classes[cl];
    return classes[cl]=p(client, this_object());
  }

  mapping my_identifiers = ([]);
  string identifier_for(object o)
  {
    if(my_identifiers[o]) return my_identifiers[o];
    return my_identifiers[o] = master->get_identifier(o);
  }

  mapping refs;

  void handle_cmd(mapping cmd)
  {
#if 0
    if(cmd->add_refs) refs[cmd->add_refs]++;
    if(cmd->subtract_refs)
    {
      int r = --refs[cmd->subtract_refs];
      if(r<=0)
      {
	object q;
	string r = cmd->subtract_refs;

	q = (classes[r] || search(my_identifiers, r));
	m_delete(classes, r);
	m_delete(refs, r);
	m_delete(my_identifiers, q);
	master->remove_identifier(r,q);
      }
    }
#endif
  }
  
  void destroy()
  {
    foreach(values(my_identifiers), string v)
      master->remove_identifier( v, my_identifiers[v] );
    buffer=sending=0;
    expected_len=mode=0;
    master->connections -= ({ this_object() });
    client->set_blocking();
    client=master=0;
  }
  
  void return_res(array res)
  {
    if(objectp(res[1]))
      res = ({ 2, identifier_for(res[1]) });
    else if(programp(res[1]) || functionp(res[1]))
      res = ({ 3, identifier_for(res[1]) });
    string data = encode_value(res);
    sending += sprintf("%4c%s", strlen(data), data);
    write_data();
  }
  
  void got_data(object c, string d)
  {
//    werror("got "+strlen(d)+" bytes data.\n");
    buffer += d;
    if(mode) {
      if(strlen(buffer) >= expected_len)
      {
//	werror("got enough data.\n");
	d = buffer[..expected_len-1];
	buffer = buffer[expected_len..];
	array err, res;
	if(err = catch {
	  mixed val = decode_value(d);
	  if(arrayp(val))
	    res = ({ 1, master->do_call(this_object(),@val) });
	  else
	  {
	    handle_cmd( val ); // Do not return anything....
	    mode=WAITING;
	    expected_len=0;
	    sending+="!"; write_data();
	    got_data(c,"");
	    return;
	  }
	})
	  res = ({ 0, describe_backtrace(err) });
	return_res(res);
	mode=WAITING;
	expected_len = 0;
	got_data(c,"");
	return;
      }
      return;
    } else if((strlen(buffer)>=4) &&
	      (sscanf(buffer, "%4c%s", expected_len, buffer) == 2)) {
//      werror("waiting for "+expected_len+" bytes.\n");
      mode=MORE_TO_COME;
      got_data(0,"");
    }
  }

  void handler_thread()
  {
    string data="";
    int len;
    array err;
    array res;
    while(1)
    {
      while(strlen(data) < 8)
      {
	data += client->read(4000,1);
	CHECK_IO_ERROR (client, "reading");
	if(!strlen(data))
	{
	  destruct();
	  return;
	}
      }
      sscanf(data, "%4c%s", len,data);
      if(strlen(data) < len) {
	data += client->read(len-strlen(data));
	CHECK_IO_ERROR (client, "reading");
      }
      if(err = catch {
	mixed val = decode_value(data);
	if(arrayp(val))
	  res = ({ 1, master->do_call(this_object(),@val) });
	else
	{
	  handle_cmd( val );
	  sending+="!";
	  write_data();
	  continue;
	}
      })
	res = ({ 0, describe_backtrace(err) });
      return_res(res);
    }
  }

  
  object thread;
  void set_threaded(int to)
  {
    if(!to && thread)
      error("Cannot change from threaded operation to non-threaded.\n");
    if(to)
    {
      client->set_nonblocking();
      client->set_read_callback(0);
      client->set_write_callback(write_data);
      client->set_close_callback(0);
      thread=thread_create(handler_thread);
    }
    else
      client->set_nonblocking(got_data, write_data, done_data);

  }

  
  void create(object c, object m)
  {
    master = m;
    refs = master->refs;
    client = c;
  }
};





class info
{
  int version()
  {
    return 1;
  }

  mixed echo(mixed what)
  {
    return what;
  }

  string ping()
  {
    return "pong";
  }
}

array connections = ({});


mapping identifiers = ([ 0:info() ]);
mapping refs = ([0:1]);
 
object port = Stdio.Port();

int c_ident;

string get_identifier(object i)
{
  string id;
  id = "_INTERNAL_"+c_ident++;
  identifiers[id]=i;
  return id;
}

void remove_identifier(string id, object i)
{
  m_delete(identifiers, id);
}


int provide(string what, object caller)
{
  refs[ what ]++;
  identifiers[ what ] = caller;
}

mixed do_call(object con, string in, string fun, mixed args)
{
  mixed me;

  if(fun=="create") error("\"create\" is not a valid identifier.\n");

  if(!(me = identifiers[in]))  error("Identifier "+in+" not valid.\n");

  if(!fun) return me( @args );

  if(programp(me))
  {
    me = con->object_for(me, in);
    if(!me) error("Identifier "+in+" not valid\n");
  }
  if(!functionp(`->(me,fun))) error(fun + " is not a function in "+in+"\n");
  return `->(me,fun)( @args );
}

function ip_security, security;

void set_ip_security(function f) { ip_security = f; }
void set_security(function f)    {  security = f;   }

string pass_key;
int threaded=0;
int low_got_connection(object c)
{
  object con;
  string tmp;
  if(c
     && (!ip_security || ip_security(c->query_address()))
     && (!security || security(c)))
    connections += ({ con = Connection( c, this_object() ) });
  else {
#ifdef RPC_DEBUG
    werror("RoxenRPC->low_got_connection(): Connection Refused:\n");
    if (c) {
      werror(sprintf("Connection from:%s\n", c->query_address()));
      if (ip_security) {
	werror(sprintf("IP-security enabled:%O\n",
		       ip_security(c->query_address())));
      }
      if (security) {
	werror(sprintf("Security enabled:%O\n",
		       security(c)));
      }
    } else {
      werror("No connection!\n");
    }
#endif /* RPC_DEBUG */
    catch(destruct(c));
    return 0;
  }
  if(pass_key)
  {
    int len;
    c->write("?");
    CHECK_IO_ERROR (c, "writing");
    string in = c->read(4);
    CHECK_IO_ERROR (c, "reading");
    sscanf(in, "%4c", len);
    
    werror("Expected "+pass_key+" got "+tmp+"\n");
    connections -= ({ con });
    catch {
      destruct(con);
      destruct(c);
    };
    return 0;
  }
  con->set_threaded(threaded);
  return 1;
}

void set_threaded(int i)
{
  if(threaded != i)
  {
    foreach(connections, object c)
      c->set_threaded(i);
    threaded=i;
  }
}

int num_connections()
{
  return sizeof(connections);
}


void got_connection(object on)
{
  if (!on) return;
  object c = on->accept();
  if (!c) {
    int err = on->errno();
    error ("Failed to accept connection on %s: %s\n",
	   on->query_address() || "unknown port", strerror (err));
  }

  if(low_got_connection(c)) {
    c->write("=");
    CHECK_IO_ERROR (c, "writing");
  }
  else
  {
    // werror("Got refused connection from "+addr+"\n");
  }
}

string query_address()
{
  return port->query_address();
}

void create(string|object host, int|string|void p, string|void key)
{
  if(stringp(p)) {
    key = p;
    p=0;
  }
  pass_key = key;
  if(objectp(host))
  {
    if(!low_got_connection(host))
      // werror?
      werror("Remote host failed authentication test.\n");
    else {
      host->write("=");
      CHECK_IO_ERROR (host, "writing");
    }
  } 
  else 
  {
    port->set_id(port);
    if(host) 
    {
       if(!port->bind(p, got_connection, host))
	 error("Failed to bind to port %s:%d: %s\n",
	       host, p, strerror (port->errno()));
    } 
    else if(!port->bind(p, got_connection))
      error("Failed to bind to port %d: %s\n",
	    p, strerror (port->errno()));
  }
}
