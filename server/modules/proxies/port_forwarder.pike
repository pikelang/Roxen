inherit "roxenlib";
inherit "module";
inherit "socket";
#include <module.h>;

/*
 * This software is (C) 1998 Francesco Chemolli,
 * and is freely availible under the terms of the
 * GNU General Public License, version 2.
 * This software comes with NO WARRANTY of ANY KIND, EITHER IMPLICIT
 * OR EXPLICIT. Use at your own risk.
 *
 * This is a TCP port forwarding module for the Roxen webserver.
 * Using it is very simple, just add it to your virtual server of choice.
 */

//#define TCPFORWARDER_DEBUG
/*
 * Define this to enable debugging. It will also be turned on if DEBUGLVL is
 * >= 22 (the same as http proxy)
 */

/*
 * Notice that Connection is not a class proper, as the module accesses its
 * variables directly. But it's not worth the effort for such a simple
 * thing...
 */

constant cvs_version="$Id: port_forwarder.pike,v 1.4 2000/02/06 20:11:56 kinkie Exp $";

#if DEBUG > 22
#define TCPFORWARDER_DEBUG
#endif

#ifdef TCPFORWARDER_DEBUG
#define debug_perror perror
#else
#define debug_perror
#endif

#define THROW(X) throw( ({X,backtrace()}) )

object accept_port;

/*
 * A bidirectional pipe over HTTP.
 */
class Connection
{
	object *fdescs;
	mapping buffer;
	object mastermodule, master_id;
	int traffic=0;

	object otherfd (object fd) {
		if (fd==fdescs[0])
			return fdescs[1];
		else
			return fdescs[0];
	}

	void send(object to_fd, string data) {
		int sent=0;
		debug_perror("Connection::send("+data+")\n");
		if(!strlen(buffer[to_fd]))
			buffer[to_fd] = data[(sent=to_fd->write(data))..];
		else
			buffer[to_fd] += data;
		traffic += sent;
	}

	void got_data(object f, string data) {
    debug_perror ("Got data from "+(f?f->query_address():"unknown")+": "+data+"\n");
		send(otherfd(f),data);
	}

	void client_closed() {
		debug_perror("Connection: Client closed connection.\n");
		destruct(this_object());
	}

	void write_more(object f)
	{
    debug_perror("Write_more..\n");
		if(strlen(buffer[f]))
		{
			int written = otherfd(f)->write(buffer[f]);
			traffic += written;
			debug_perror((string)written);
			if(written == 0)
				client_closed();
			else
				buffer[f] = (buffer[f])[written..];
		}
    debug_perror("\n");
	}

  //s=source filedes, d=dest filedes, m=the instantiating object
	void create(object s, object d, object m)
	{
		fdescs=({s,d});
		buffer=([s:"",d:""]);
		s->set_nonblocking(got_data,write_more,client_closed);
		s->set_id(s);
		d->set_nonblocking(got_data,write_more,client_closed);
		d->set_id(d);
		mastermodule=m;
		debug_perror("Got connection from "+s->query_address()+
				" to " + d->query_address()+"\n");
	}

	void destroy() {
		mapping result;
		debug_perror("Destroying connection\n");
		fdescs[0]->close();
		fdescs[1]->close();
		mastermodule->connections-=(<this_object()>);
		mastermodule->total_transferred_kb+=(traffic/1024);
	}
};

array register_module() {
	return ({
			0,
			"TCP Port Forwarder",
			"A basic port-forwarder"
			"&copy; 1998 Francesco Chemolli "
			"&lt;kinkie@kame.usr.dsi.unimi.it&gt;,<BR>\nfreely distributed "
			"under the terms of the GNU General Public License, version 2"
			});
}

multiset connections=(<>);
int total_connections_number=0, total_transferred_kb=0;


string status() {
	object req;
	string retval;
	if (!sizeof(connections)) {
		retval="<B>No connections</B><br>";
	} else {
		retval="<B>"+sizeof(connections)+" connections</B><BR>\n";
		retval += "<TABLE border=1><TR><TH align=center>From<TH>To<TH>Traffic";
		foreach(indices(connections),req) {
			retval+=sprintf("<TR><TD>%s<TD>%s<TD>%d",
					req->fdescs[0]->query_address(),
					req->fdescs[1]->query_address(),
					req->traffic
					);
		}
		retval += "</TABLE>";
	}
	retval +="I've managed "+total_connections_number+" connections, "
		"transferring about "+total_transferred_kb+" Kb.";
	return retval;
}

void create() {
  defvar("port", 4711, "Port", TYPE_INT,
         "The port to wait for connections on.");
  defvar("host", "localhost", "Remote Host", TYPE_STRING,
         "The hostname to forward connections to.");
  defvar("r_port", 4711, "Remote Port", TYPE_INT,
         "The port on the remote host to connect to.");
}

void start() {
	object privs;
	int port;

	port=QUERY(port);
  if (accept_port) //I wonder why (at least on my setup) stop isn't called..
    stop();
  debug_perror("Opening port "+port+"\n");
  accept_port=Stdio.Port();
  if (!accept_port)
    THROW("Can't create a port to listen on");
	if (port<1024)
		privs=Privs("Opening forwarded port");
  if (!(accept_port->bind(port,got_connection)))
    THROW("Can't bind (errno="+accept_port->errno()+": \""+strerror(accept_port->errno())+"\")\n");;
	privs=0;
  accept_port->set_id(accept_port);
}

void stop() {
  debug_perror("Stopping module\n");
  accept_port->set_id(0);
  destruct(accept_port);
  accept_port=0; //double-check there's no more references
  foreach(indices(connections),object foo) destruct(foo);
}

void got_connection (mixed port) {
  object in;
  in=port->accept();
  if (!in)
    THROW("Couldn't accept connection");
	total_connections_number++;
  async_connect(QUERY(host),QUERY(r_port),connected,in);
}

void connected (object out, object in) {
  object connection=Connection(in,out,this_object());
  connections[connection]=1;
}
