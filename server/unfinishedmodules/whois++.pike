// Experimental whois++ *client* module
// (c) Infovav 
// Written by Pontus Hagland
#include <module.h>

inherit "module";
inherit "roxenlib";

#define MY_URL (roxen->query("MyWorldLocation") + QUERY(mountpoint))

int request_counter=0;
array hosts;

void create()
{
  defvar("mountpoint", "whois++/", "Mount point", TYPE_LOCATION, 
	 "Whois++ client module is located at this point in the virtual "
	 "filesystem.");
  defvar("defaulthost", "sunic.sunet.se", "Default host", TYPE_STRING, 
	 "Default whois++ server host.");
  defvar("defaultport", 7070, "Default port", TYPE_INT, 
	 "Default whois++ server port number.");
}
#define MODULE_LOCATION 0
mixed *register_module()
{
  return ({ 
    MODULE_LOCATION,
    "Whois++ client", 
    "Experimental module.",
    });
}

string query_location()
{
  return query("mountpoint");
}

void got_data(array v,string s)
{
  v[4] += s;
}

int oldrow=0;

void fixa_data(object pipe,string s)
{
  pipe->write("<table border=1>\n");
  map_array(s/"\n#",
	    lambda(string s,object pipe)
	    {
	      array v,v2;
	      if (!sizeof(v=s/"\n"-({""}))) return;
	      if (!sizeof(v2=v[0]/" "-({""}))) return;
	      switch (upper_case(v2[0]))
	      {
	       case "USER":
	       case "SERVICES":
		pipe->write("<tr></tr><tr></tr>\n");
		oldrow=0;
		map_array(v[1..10000],
			  lambda(string s,object pipe)
			  {
			    string t=0,u;
			    sscanf(s,"%*[ \t]%s:%*[ \t]%s",t,u);
			    if (t) switch (t)
			    {
			     case "Email-address":
			     case "Sysadmin-Email":
			     case "Admin-Email":
			     case "Tech-Email":
			     case "Email": 
			      u="<a href=\"mailto:"+u+"\">"+u+"</a>"; 
			      break;
			     case "Description-URI": 
			      u="<a href=\""+u+"\">"+u+"</a>";
			      break;
			    }
			    if (oldrow && t)
			      pipe->write("</td></tr>\n"),oldrow=0;
			    if (t)
			      pipe->write("<tr><th align=left>"+t+
					  "</td><td>"+u+"\n"),oldrow=1;
			    else 
			    {
			      if (!oldrow)
				pipe->write("<tr><td></td><td>");
			      pipe->write(s);
			      oldrow=1;
			    }
			  },pipe);
		pipe->write("<tr></tr><tr></tr>\n");
		break;
	       case "SERVERS-TO-ASK":
		if (oldrow)
		  pipe->write("</td></tr>\n"),oldrow=0;
		string u,q;
		sscanf(s,"%*sBody-of-Query:%*[ \t]%s\n",q);
		sscanf(s,"%*sNext-Servers:%*[\n\r\t \v]%s",u);
		map_array(u/"\n",
			  lambda(string s,object pipe,string q)
			  {
			    string v,w;
			    sscanf(s,"%*[ \t]%*s%*[ \t]%s%*[ \t]%s%*[ \t\n\r\v]",v,w);
			    pipe->write("<tr><td colspan=2 align=center>"+
					"<a href=\"?host="+v+"&port="+w+"&tag="+q+">"+
					"Recommended whois++ server: <i>"+v+" port "+w+"</i>"+
					"</a></td></tr>\n");
			    hosts|=({v+" "+w});
			  },pipe,q);
		break;
	      }
	      if (oldrow) pipe->write("</td></tr>\n");
	    },pipe);
  pipe->write("</table>\n");
}

void server_closed(array v)
{
   object pipe;
   pipe=Pipe();
   fixa_data(pipe,v[4]);
   pipe->output(v[1]);
   v[2]->disconnect();
}

void connected_to_server(array v)
{
   v[1]->write("HTTP/1.0 200 Ok\r\n"
	       "Content-type: text/html\r\n\r\n"
	       "<title>Whois++: "+v[3]["tag"]+"</title>\n");

   v[0]->write(v[3]["tag"]+"\n");
   v[0]->set_nonblocking(got_data,0,server_closed);
}

void failed_to_connect(array v)
{
   mapping id;

   if (objectp(v[1]))
   {
      v[2]->end("HTTP/1.0 200 Ok\r\n"
		"Content-type: text/html\r\n\r\n"
		"<title>Whois++: can't connect to "+v[3]["host"]+" port "+v[3]["port"]+"</title>\n"
		"<h3>Can't connect to "+v[3]["host"]+" port "+v[3]["port"]+".</h3>\n");
   }
   if (objectp(v[0])) { v[0]->set_id(0); destruct(v[0]); }
}

void serv_request(string host,object id,mapping var)
{
  object pipe;
  object server;

  if (!host)
  {
    if (objectp(id))
    {
      id->end("HTTP/1.0 200 Ok\r\n"
	      "Content-type: text/html\r\n\r\n"
	      "<title>Whois++: No such host: "+var["host"]+"</title>\n"
	      "<h3>No such host: <i>"+var["host"]+"</i></h3>\n");
    }
    return;
  }
  server=File();
  if (!server->open_socket())
  {
    destruct(server);

    if (objectp(id))
    {
      id->end("HTTP/1.0 200 Ok\r\n"
	      "Content-type: text/html\r\n\r\n"
	      "<title>Whois++: can't open socket</title>\n"
	      "<h3>Can't open socket, please try again.</h3>\n");
    }
    return;
  }
//#ifdef DEBUG
  mark_fd(server->query_fd(), "whois++: Remote host connection");
//#endif
  server->set_id(({server,id->my_fd,id,var,""}));
  server->set_nonblocking(0, connected_to_server, failed_to_connect);
  server->connect(host, (int)var["port"]);
}

mapping search_entry(string f,object id,mapping var)
{
  if (var["hosttype"]&&var["hosttype"]!="use fields below")
  {
     sscanf(var["hosttype"],"%s %s",var["host"],var["port"]);
  }
  roxen->host_to_ip(var["host"], serv_request, id, var);
  return http_pipe_in_progress();
}

mapping find_file( string f , object id )
{
  if (id->variables && id->variables->host)
     return search_entry(f, id, id->variables);

  return 
    http_string_answer("<html><head><title>Whois++</title></head>"+
      "<body>"+
      "<form action=\"\" method=get>\n"+
      "\n<p>Search for: <input name=\"tag\" size=60 value=\"\">"+
      "\n<p><input type=submit value=\"Search\">"+
      "<table border=1 width=100%><td align=left>\n"+
      "<select name=hosttype>\n"+
      "  <option selected>"+QUERY(defaulthost)+" "+QUERY(defaultport)+
      map_array(hosts-({QUERY(defaulthost)+" "+QUERY(defaultport)}),
		lambda(string s) { return "  <option>"+s; })*""+
      "  <option>use fields below\n"+
      "</select>"+
      "\nHost: <input name=\"host\" size=30 value=\"\">"+
      "\nPort: <input name=\"port\" size=10 value=\"\">"+
      "</td></table>\n"+
      "</form>\n"+
      "</body></html>");
}

string comment()
{
  return query("mountpoint");
}

string status()
{
  return ""+request_counter+" requests served.\n";
}

void start()
{
  hosts=({ QUERY(defaulthost)+" "+QUERY(defaultport) });
}

