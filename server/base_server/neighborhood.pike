#define DELAY 20
#define NEIGH_DEBUG
mapping neighborhood = ([ ]);
object udp_broad=spider.dumUDP();

class TCPNeigh {
  object me, master;
  static void read(mixed foo, string d)
  {
    return master->low_got_info(d, this_object());
  }

  void send(string s)
  {
    return me->write(s);
  }

  void done()
  {
    me->set_blocking();
    destruct(me);
    master->remove_neighbour(this_object());
    destruct(this_object());
  }
  
  void create(object|string f, int port, object m)
  {
    if(objectp(f)) me=f;
    else me = files.file();
    if(port)
    {
#ifdef NEIGH_DEBUG
      werror("Neighbourhood: Connecting to "+(f||"127.0.0.1")+"\n");
#endif
      if(!me->connect(f||"127.0.0.1",port))
      {
#ifdef NEIGH_DEBUG
	werror("Connection failed.\n");
#endif
	call_out(m->remove_neighbour,0, this_object());
	call_out(destruct,1, this_object());
	return;
      }
    }
    master=m;
    me->set_nonblocking(read,0,done);
  }
};

object udp_sock;

class UDPNeigh
{
  object master;
  int port;
  string net;
  int nobr=1;

  static void read()
  {
#ifdef NEIGH_DEBUG
    werror("Neighbourhood: Got UDP\n");
#endif
    return master->low_got_info(master->udp_sock->read()->data, this_object());
  }

  void send(string s)
  {
    if(!nobr)
    {
#ifdef NEIGH_DEBUG
      werror("Neighbourhood: Send to "+net+":"+port+"\n");
#endif
      return master->udp_sock->send(net,port,s);
    }
  }

  void create(string f, int p, object m)
  {
    master = m;
    if(!f)
    {
      if(!master->udp_sock)
	master->udp_sock = spider.dumUDP();
#ifdef NEIGH_DEBUG
      werror("Neighbourhood: Listening to UDP\n");
#endif
      if(!master->udp_sock->bind( 0, p ))
	werror("Bind failed.\n");
      master->udp_sock->set_read_callback(read);
    } else
      nobr=0;
    port = p; net = f;
  }
}

mapping neighbours = ([ ]);


string network_numbers()
{
  return roxen->query("neigh_ips");
}

string tcp_numbers()
{
  return roxen->query("neigh_tcp_ips");
}

int seq;

int lr=time();

mapping low_neighbours = ([]);

void add_neighbour(object neigh)
{
  low_neighbours[neigh] = time();
}

object master;

void send_to_all(string f, object from)
{
  foreach(indices(low_neighbours), object o)
    if(o!=from) o->send(f);
}

array config_info(object c)
{
  return ({
    strlen(c->query("name"))?c->query("name"):c->name,
    c->query("MyWorldLocation"),
  });
}

mapping neigh_data()
{
  mapping m = (["last_reboot":lr]);
  m->configurl=roxen->config_url();
  m->seq=seq++;
  switch(seq & 3)
  {
   case 0:
    m->comment=roxen->query("neigh_com");
    break;
   case 1:
    m->server_urls=Array.map(roxen->configurations, config_info);
    break;
   case 2:
    m->host=gethostname();
    m->version=roxen->real_version;
    m->pid=getpid();
    m->uid=getuid();
    m->ppid=getppid();
  }
  return m;
}  

void broadcast()
{
#ifdef NEIGH_DEBUG
//    werror("Neighbourhood: Sending broadcast to "+
//	   sizeof(low_neighbours)+" neighbour connections\n");
#endif
  remove_call_out(broadcast);
  if(seq) call_out(broadcast,DELAY); else call_out(broadcast,1);
  send_to_all(encode_value(neigh_data()),0);
}

void low_got_info(string data, object from)
{
  int cs;
  mapping ns, m;
  m = decode_value(data);
  if(m->sequence) m->seq = m->sequence;
  ns = neighborhood[m->configurl]||([]);
  if(!ns->seq || (m->seq != ns->seq))
  {
#ifdef NEIGH_DEBUG
    werror("Neighbourhood: Got info for "+m->configurl+"\n");
#endif
    m->rec_time = time();
    if(m->last_reboot > ns->last_reboot) {
      m->last_last_reboot = m->last_reboot;
      m->seq_reboots=ns->seq_reboots+1;
    } else {
      m->seq_reboots=0;
    }
    neighborhood[m->configurl] = ns | m;
    send_to_all(data, from);
  }
}

void got_connection(object port)
{
  object o = port->accept();
  if(o) {
#ifdef NEIGH_DEBUG
    werror("Neighbourhood: Got TCP connection from "+o->query_address()+"\n");
#endif
    add_neighbour(TCPNeigh(o, 0, this_object()));
  }
}

void remove_neighbour(object neigh)
{
  if(!master)
  {
    master = files.port();
    master->set_id(master);
    if(!master->bind(51521,got_connection))
      master = 0;
  }
  m_delete(low_neighbours,neigh);
}

void reinit()
{
  foreach(indices(low_neighbours), object o)
  {
    destruct(o->me);
    destruct(o);
  }
  low_neighbours = ([ ]);
  if(!master) add_neighbour(TCPNeigh(0,51521,this_object()));
  foreach(network_numbers(), string s)
    add_neighbour(UDPNeigh(s,51521,this_object()));
  foreach(tcp_numbers(), string s)
    add_neighbour(TCPNeigh(s,51521,this_object()));
}

void create()
{
  if(!master)
  {
    master = files.port();
    master->set_id(master);
    if(!master->bind(51521,got_connection))
    {
      master=0;
      add_neighbour(TCPNeigh(0,51521,this_object()));
    }
#ifdef NEIGH_DEBUG
    else
      werror("Neighbourhood: Bound to ALL:51521\n");
#endif
    add_neighbour(UDPNeigh(0,51521,this_object()));
    
    foreach(tcp_numbers(), string s)
      add_neighbour(TCPNeigh(s,51521,this_object()));
    foreach(network_numbers(), string s)
      add_neighbour(UDPNeigh(s,51521,this_object()));
    if(roxen->query("neighborhood")) broadcast();
    add_constant("neighborhood", neighborhood);
  }
}
