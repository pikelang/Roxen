// This is a roxen module. Copyright © 1996 - 2009, Roxen IS.

// An implementation of the CONNECT methos, used for SSL tunneling in
// Netscape (the "Secure proxy" field)

constant cvs_version = "$Id$";
constant thread_safe = 1;


inherit "module";
inherit "socket";

#include <module.h>
#include <proxyauth.pike>

#define CONN_REFUSED query("ConRefused")

/* Simply relay a request to another server if the data was not found. */

constant module_type = MODULE_FIRST|MODULE_PROXY;
constant module_name = "SSL Proxy";
constant module_doc  = "Implements the CONNECT method."
  " Useful for tunneling of SSL connections (Secure proxy in Netscape).";

void nope(object hmm)
{
  if(hmm)
  {
    hmm->my_fd->write(CONN_REFUSED);
    hmm->do_not_disconnect = 0;
    hmm->end();
  }
}

void create()
{
  defvar("ConRefused", 
	 /**/
	 "505 Connection Refused by remote server\n"
	 "Content-type: text/html\n\n"
	 "<title>Connection refused by remote server</title>\n"
	 "<h1 align=center>Connection refused by remote server</h1>\n"
	 "<hr noshade>\n<font size=+2>Please try again later.</font>\n"
	 "<i>Sorry</i>\n<hr noshade>",
	 /**/
	 "Connection refused message",
	 TYPE_TEXT_FIELD,
	 "The message to send when the requested host deny the connection.");

  defvar("NoHost", 
	 /**/
	 "505 No such host\nContent-type: text/html\n\n"
	 "<title>The host does not exist</title>\n" 
	 "<h1 align=center>I am unable to locate that host</h1>\n"
	 "<i>Sorry</i>\n<hr noshade>",
	 /**/
	 "No such host message",
	 TYPE_TEXT_FIELD,
	 "The message to send when the requested host cannot be found.");

  defvar("AllowedPorts", ({ "1-65535" }), "Allowed Ports",
         TYPE_STRING_LIST,
         "Connections will only be made to ports matching this list "
         "The syntax is <tt>from-to</tt> or <tt>port</tt> "
         "It might be desireable to disallow access to some ports, see the "
         "Forbidden Ports variable.");

  defvar("DenyPorts", ({ "" }), "Forbidden Ports", 
         TYPE_STRING_LIST,
         "The syntax is as for Allowed Ports.");
}

array allowed, denied;

void start()
{
  string p;
  int a, b;
  allowed = ({ });
  foreach(query("AllowedPorts"), p)
    if(sscanf(p, "%d-%d", a, b)==2)
      allowed += ({ ({ a, b }) });
    else
      allowed += ({ (int) p });
  denied = ({ });
  foreach(query("DenyPorts"), p)
    if(sscanf(p, "%d-%d", a, b)==2)
      denied += ({ ({ a, b }) });
    else
      denied += ({ (int) p });
}


int allow(int portno)
{
  array|int p;
  foreach(denied, p)
    if(arrayp(p) && (portno>=p[0] && portno<=p[1]))
      return 0;
    else if(p==portno)
      return 0;
  foreach(allowed, p)
    if(arrayp(p) && (portno>=p[0] && portno<=p[1]))
      return 1;
    else if(p==portno)
      return 1;
  return 0;
}

void end_it(array t)
{
  catch {
 //   Log here...
    destruct(function_object(t[1][0]));
    destruct(function_object(t[1][1]));
  };
}

void write_some(array to)
{
  int sent;
// Creative indexing. 
  sent = to[1][to[0]]( to[1][2+!to[0]] );
  to[1][2+!to[0]] = to[1][2+!to[0]][sent..strlen(to[1][2+!to[0]])];
}

void send_some(array to, string data)
{
  to[1][2+to[0]] += data;
// to[-1][-1] += strlen(data);
  write_some(({ !to[0], to[1] }));
}

void connected(object to, object id)
{
  array myid, hmm;
  if(!to) {
    nope(id);
    return;
  }

  myid = ({  id->my_fd->write, to->write, "", "" });
  hmm = ({ id->not_query, 0 });

  id->my_fd->write("HTTP/1.0 200 Connected\r\n\r\n");

  to->set_id(({ 1, myid, hmm }));
  to->set_nonblocking(send_some,write_some,end_it);

  id->my_fd->set_id(({ 0, myid, hmm }));
  id->my_fd->set_nonblocking(send_some, write_some, end_it);
  id->do_not_disconnect = 0;
  id->my_fd = 0;
  id->disconnect();
}

inline private string find_host(string from)
{
  return (from/":")[0];
}

inline private int find_port(string from)
{
  return (int)(((from/":")+({80}))[1]);
}

mapping relay(object fid)
{
  int p;
  fid->do_not_disconnect = 1;
  p = find_port(fid->not_query);
  if(allow(p))
    async_connect(find_host(fid->not_query), p, connected, fid);
  else
    return Roxen.http_string_answer(query("InvalidPort"));
  return http_pipe_in_progress();
}

mapping first_try(object fid)
{
  if(fid->method != "CONNECT")
    return 0;
  mapping tmp;
  if(tmp = proxy_auth_needed(fid))
    return tmp;
  return relay(fid);
}
