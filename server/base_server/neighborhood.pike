#define DELAY 20
// #define NEIGH_DEBUG
mapping neighborhood = ([ ]);
object udp_broad=spider.dumUDP();

class TCPNeigh
{
  object me, master;
  static void read(mixed foo, string d)
  {
    return master->low_got_info(d, this_object());
  }

  void send(string s)
  {
    if(me)
    {
#ifdef NEIGH_DEBUG
      werror("Neighbourhood: TCP Send to "+me->query_address()+"\n");
#endif
      return me->write(s);
    }
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
    if(port && f && strlen(f))
    {
#ifdef NEIGH_DEBUG
      werror("Neighbourhood: Connecting to "+(f||"127.0.0.1")+"\n");
#endif
      if(!me->connect(f||"127.0.0.1",port))
      {
#ifdef NEIGH_DEBUG
	werror("Connection failed.\n");
#endif
	me=0;
	call_out(m->remove_neighbour, 0, this_object());
	return;
      }
    }
    master=m;
    catch(me->set_nonblocking(read,0,done));
  }
};

object udp_sock;
mapping seen_on_udp = ([]);
class UDPNeigh
{
  object master;
  int port;
  string net, last_from;
  int nobr=1;

  static void read()
  {
    mapping r;
    if(r = master->udp_sock->read()) {
      last_from = r->ip;
      master->seen_on_udp[last_from]++;
      return master->low_got_info(r->data, this_object());
    } else {
      // PATCH! Sometimes there is data that cannot be read on the socket.
#ifdef NEIGH_DEBUG
 werror("Ugly patch invoked. Waving a dead chicken in front of the socket\n");
#endif
      if(master->udp_sock->set_blocking)
	master->udp_sock->set_blocking();
      master->udp_sock->set_read_callback(0);
      destruct(master->udp_sock);
      master->udp_sock = spider.dumUDP();
      master->udp_sock->bind(port);
      if (master->udp_sock->enable_broadcast) {
	master->udp_sock->enable_broadcast();
      }
      master->udp_sock->set_nonblocking(read);
    }
  }

  void send(string s, string from)
  {
    if(net)
    {
      if(from)
      {
	string nnet;
	if(!sscanf(net, "%s.255", nnet)) sscanf(net, "%s.0", nnet);
	if(nnet && (!search(from,nnet)))
	{
	  if(master->seen_on_udp[from])
#ifdef NEIGH_DEBUG
	    werror("Not sending to "+net+", this is the origining network!\n");
#endif
	  return;
	}
      }

      if(!nobr)
      {
#ifdef NEIGH_DEBUG
	werror("Neighbourhood: UDP Send to "+net+":"+port+"\n");
#endif
	return master->udp_sock->send(net,port,s);
      }
    }
  }

  void create(string f, int p, object m)
  {
    master = m;
    if(!f)
    {
      if(!master->udp_sock) {
	master->udp_sock = spider.dumUDP();
      }
#ifdef NEIGH_DEBUG
      werror("Neighbourhood: Listening to UDP\n");
#endif
      if(!master->udp_sock->bind( p )) {
#ifdef NEIGH_DEBUG
	werror("Bind failed.\n");
#endif
	master->udp_sock = 0;
      } else {
	if (master->udp_sock->enable_broadcast) {
	  master->udp_sock->enable_broadcast();
	}
	master->udp_sock->set_nonblocking(read);
      }
    } else {
      nobr=0;
    }
    port = p; net = f;
  }
}

mapping neighbours = ([ ]);


string network_numbers()
{
  return roxen->query("neigh_ips")-({""});
}

string tcp_numbers()
{
  return roxen->query("neigh_tcp_ips")-({""});
}

int seq;

int lr=time();

mapping low_neighbours = ([]);

void add_neighbour(object neigh, int nosend)
{
  low_neighbours[neigh] = ({ time(), nosend });
}

object master;


void send_to_all(string f, object from)
{
  mapping sent_to = ([]);
  if(from)
  {
    string ip = from->me?(((from->me->query_address()||"")/" ")[0]):from->net;
    sent_to[ip]++;
  }
  foreach(indices(low_neighbours), object o)
  {
    if(objectp(o) && (o!=from))
    {
      if(!low_neighbours[o][1])
	catch
	{
	  string ip = o->me ? (((o->me->query_address()||"")/" ")[0]) : o->net;
	  if(ip=="") this_object()->remove_neighbour(o);
	  if(!sent_to[ip]++)
	    o->send(f,from?from->me?from->me->query_address():
		    from->last_from:0);
	};
    }
  }
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
  switch(seq & 1)
  {
   case 0:
    m->comment=roxen->query("neigh_com");
    m->host=gethostname();
    m->uid=getuid();
    break;
   case 1:
    m->server_urls=Array.map(roxen->configurations, config_info);
    m->pid=getpid();
    m->version=roxen->real_version;
    m->ppid=getppid();
  }
  return m;
}  

void low_got_info(string data, object from);

void broadcast()
{
  string data = encode_value(neigh_data());
#ifdef NEIGH_DEBUG
// werror("Neighbourhood: Sending broadcast to "+
//        sizeof(low_neighbours)+" neighbour connections\n");
#endif
  remove_call_out(broadcast);
  if(seq) call_out(broadcast,DELAY); else call_out(broadcast,1);
  low_got_info(data,0);
}

void low_got_info(string data, object from)
{
  int cs;
  mapping ns, m;
  m = decode_value(data);
  if(m->sequence) m->seq = m->sequence;
  if(!neighborhood[m->configurl]) neighborhood[m->configurl]=(["seq":-1]);
  ns = neighborhood[m->configurl];
  if(m->last_reboot > ns->last_reboot)
  {
    ns->seq = m->seq -1;
#ifdef NEIGH_DEBUG
    werror("Neighbourhood: Resetting info for "+m->configurl+" ("+m->seq+")\n");
#endif
  }
    
  if(m->seq > ns->seq)
  {
    ns->ok=1;
    ns->seq = m->seq;
#ifdef NEIGH_DEBUG
    werror("Neighbourhood: Got info for "+m->configurl+" ("+m->seq+")\n");
#endif
    m->rec_time = time();
    if(m->last_reboot > ns->last_reboot) {
      m->last_last_reboot = m->last_reboot;
      m->seq_reboots=ns->seq_reboots+1;
    } else {
      m->seq_reboots=0;
    }
    send_to_all(data, from);
  }
#ifdef NEIGH_DEBUG
  else werror("Neighbourhood: Rejecting old info for "+m->configurl+" ("+m->seq+" vs "+ns->seq+")\n");
#endif
  neighborhood[m->configurl] = ns | m;
}

void got_connection(object port)
{
  object o = port->accept();
  if(o)
  {
#ifdef NEIGH_DEBUG
    werror("Neighbourhood: Got TCP connection from "+o->query_address()+"\n");
#endif
    add_neighbour(TCPNeigh(o, 0, this_object()), 1);
  }
}

void create();
void remove_neighbour(object neigh)
{
  remove_call_out(create);
  call_out(create, 60);
  m_delete(low_neighbours,neigh);
}

void create()
{
  foreach(indices(low_neighbours), object o)
  {
    m_delete(low_neighbours, o);
    if(o->me) destruct(o->me);
    destruct(o);
  }
  if(!master)
  {
    master = files.port();
    master->set_id(master);
    if(!master->bind(51521,got_connection))
    {
      master=0;
      add_neighbour(TCPNeigh(0,51521,this_object()),0);
    }
#ifdef NEIGH_DEBUG
    else
      werror("Neighbourhood: Bound to ALL:51521\n");
#endif
  }
  add_neighbour(UDPNeigh(0,51521,this_object()),0);
    
  foreach(tcp_numbers(), string s)
    add_neighbour(TCPNeigh(s,51521,this_object()),0);
  foreach(network_numbers(), string s)
    add_neighbour(UDPNeigh(s,51521,this_object()),0);
  if(roxen->query("neighborhood")) broadcast();else remove_call_out(broadcast);
  remove_call_out(create);
  add_constant("neighborhood", neighborhood);
  call_out(create, 1800);
}
