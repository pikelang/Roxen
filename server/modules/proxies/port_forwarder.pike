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

constant cvs_version="$Id: port_forwarder.pike,v 1.3 1999/12/28 04:48:27 nilsson Exp $";

#if DEBUG > 22
#define TCPFORWARDER_DEBUG
#endif

#ifdef TCPFORWARDER_DEBUG
# define TCPFWD_WERR(X) werror("TCPforwarder: "+X+"\n")
#else
# define TCPFWD_WERR(X)
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
		TCPFWD_WERR("Connection::send("+data+")");
		if(!strlen(buffer[to_fd]))
			buffer[to_fd] = data[(sent=to_fd->write(data))..];
		else
			buffer[to_fd] += data;
		traffic += sent;
	}

	void got_data(object f, string data) {
	  TCPFWD_WERR("Got data from "+(f?f->query_address():"unknown")+": "+data);
	  send(otherfd(f),data);
	}

	void client_closed() {
	  TCPFWD_WERR("Connection: Client closed connection.");
	  destruct(this_object());
	}

	void write_more(object f)
	{
	  TCPFWD_WERR("Write_more..");
		if(strlen(buffer[f]))
		{
			int written = otherfd(f)->write(buffer[f]);
			traffic += written;
			TCPFWD_WERR((string)written);
			if(written == 0)
				client_closed();
			else
				buffer[f] = (buffer[f])[written..];
		}
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
		TCPFWD_WERR("Got connection from "+s->query_address()+
			    " to " + d->query_address());
	}

	void destroy() {
		mapping result;
		TCPFWD_WERR("Destroying connection");
		fdescs[0]->close();
		fdescs[1]->close();
		mastermodule->connections-=(<this_object()>);
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

string status() {
	object req;
	if (!sizeof(connections)) {
		return "<B>No connections</B>";
	}
	string retval;
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
  if (accept_port) //I wonder why (at least on my setup) stop isn't called..
    stop();
  TCPFWD_WERR("Opening port "+QUERY(port));
  accept_port=Stdio.Port();
  if (!accept_port)
    THROW("Can't create a port to listen on");
  if (!accept_port->bind(QUERY(port),got_connection))
    THROW("Can't bind");;
  accept_port->set_id(accept_port);
}

void stop() {
  TCPFWD_WERR("Stopping module");
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
  async_connect(QUERY(host),QUERY(r_port),connected,in);
}

void connected (object out, object in) {
  object connection=Connection(in,out,this_object());
  connections[connection]=1;
}
