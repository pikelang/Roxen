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
    if(strlen(sending))
      sending = sending[client->write(sending)..];
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
//    werror(sprintf("Handle cmd %s(%s)\n", indices(cmd)[0],
//		   (string)values(cmd)[0]));
    if(cmd->add_refs) refs[cmd->add_refs]++;
    if(cmd->subtract_refs)
    {
      int r = --refs[cmd->subtract_refs];
      if(r<=0)
      {
	object q;
	string r = cmd->subtract_refs;
//	werror("refs==0 for "+r+"\n");
	q = (classes[r] || search(my_identifiers, r));
	m_delete(classes, r);
	m_delete(refs, r);
	m_delete(my_identifiers, q);
	master->remove_identifier(r,q);
      }
    }
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

  void create(object c, object m)
  {
    master = m;
    refs = master->refs;
    client = c;
    c->set_nonblocking(got_data, write_data, done_data);
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
 
object port = files.port();

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

#define error(X) throw(({X, backtrace()}));

mixed do_call(object con, string in, string fun, mixed args)
{
  mixed me;

  if(fun=="create") error("Create is not a valid identifier.\n");

  if(!(me = identifiers[in]))  error("Identifier "+in+" not valid.\n");

  if(!fun) return me( @args );

  if(programp(me))
  {
    me = con->object_for(me, in);
    if(!me) error("Identifier "+in+" not valid\n");
  }
  if(!functionp(me[fun])) error(fun+" is not a function in "+in+"\n");
  return me[fun]( @args );
}

function ip_security, security;

void set_ip_security(function f) { ip_security = f; }
void set_security(function f)    {  security = f;   }

void low_got_connection(object c)
{
  if(c
     && (!ip_security || ip_security(c->query_address()))
     && (!security || security(c)))
    connections += ({ Connection( c, this_object() ) });
  else {
    catch(destruct(c));
  }
}

int num_connections()
{
  return sizeof(connections);
}

void got_connection(object on)
{
  object c = on->accept();
  low_got_connection(c);
  c->write("!");
}

string query_address()
{
  return port->query_address();
}

void create(string|object host, int|void p )
{
  if(objectp(host))
  {
    low_got_connection(host);
  } else if(host) {
    if(!port->bind(p, got_connection, host))
      error("Failed to bind to port\n");
  } else if(!port->bind(p, got_connection))
    error("Failed to bind to port\n");
}
