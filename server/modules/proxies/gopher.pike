// This is a roxen module. Copyright © 1996 - 2009, Roxen IS.

// Gopher proxy module.

constant cvs_version = "$Id$";
constant thread_safe = 1;

#include <config.h>

#define CONNECTION_REFUSED "HTTP/1.0 500 Connection refused by remote "	\
"host\r\nContent-type: text/html\r\n\r\n<title>Roxen: Connection "	\
"refused </title>\n<h1>Proxy request failed</h1><hr /><font "		\
"size=\"+2\"><i>Connection refused by remote host</i></font><hr><font "	\
"size=\"-2\"><a href=http://www.roxen.com/>Roxen</a></font>"

#ifdef GOPHER_DEBUG
# define GOPHER_WERR(X) werror("GOPHER: "+X+"\n")
#else
# define GOPHER_WERR(X)
#endif

inherit "module";
inherit "socket";

#include <module.h>
#include <proxyauth.pike>

constant module_type = MODULE_LOCATION|MODULE_PROXY;
constant module_name = "Gopher Gateway";
constant module_doc  = "This is a caching gopher gateway, might be useful for firewall sites, if "
  "anyone is still using gopher.";

string query_location() { return query("loc"); }

void create()
{
  defvar("loc", "gopher:/", "Location", TYPE_LOCATION|VAR_MORE,
	 "The mountpoint of the gopher proxy");
}


string make_html_line(array(string) s)
{
  if(s)
    return sprintf("<a href=\"%s\"> <img hspace=5 border=0 "
		   "src=\"%s\"> %s</a><br>\n",
		   replace(s[1], " ", "%20"), s[0], replace(s[2], "_", " "));
  else
    return "<p>";
}

void my_pipe_done(array (object) a)
{
//if(a[1]) destruct(a[1]);
  if(a[0]) ::my_pipe_done(a[0]);
}

void write_to_client_and_cache(object client, string data, string key)
{
  object cache;
  object pip;
  if(key)
    cache = roxen->create_cache_file("gopher", key);

  pip=Pipe.pipe();
  if(cache)
  {
    pip->set_done_callback(my_pipe_done, ({ cache, client }));
    pip->output(cache->file);
  }
  if(client->my_fd)
  {
    pip->output(client->my_fd);
    pip->write(data);
  }
}


void done_dir_data(array in)
{
  int i;
  array  dirl=(in[0]-"\r")/"\n";
  object to=in[1];
  destruct(in[2]);

  if(!objectp(to))
    return;

  if(dirl[0] && dirl[0][0] != '<')
  {
    GOPHER_WERR("Done with dir data.");
    dirl -= ({ ".", "" });
    for(i=0; i < sizeof(dirl); i++)
    {
      array a;
      a=dirl[i][1..]/"\t";
#define URL (a[2]+((int)a[3]==70?"":":"+a[3])+"/"+dirl[i][0..0]+a[1])
      switch(dirl[i][0])
      {
       case '0': /* File */
	dirl[i] = ({ "internal-gopher-text", "gopher://"+URL, a[0] });
	break;

       case '1': /* Dir  */
	dirl[i] = ({ "internal-gopher-menu", "gopher://"+URL, a[0] });
	break;

       case '2': /* Phonebook */
	dirl[i] = ({ "internal-gopher-index", "gopher://"+URL, a[0] });
	break;

       case '3': /* Error? */
	dirl[i] = ({ "internal-gopher-binary", "gopher://"+URL, a[0] });
	break;

       case '4': /* BinHex */
       case '5': /* Dos binary */
       case '6': /* Unix UUENCODED file */
       case '9': /* Binary */
	dirl[i] = ({ "internal-gopher-binary", "gopher://"+URL, a[0] });
	break;

       case '7': /* Search */
	dirl[i] = ({ "internal-gopher-index", "gopher://"+URL, a[0] });
	break;

       case '8':
	dirl[i] = ({ "internal-gopher-telnet", "telnet://"+URL, a[0] });
	break;

       case 'T':
	dirl[i] = ({ "internal-gopher-telnet", "tn3270://"+URL, a[0] });
	break;

       case '+':
	dirl[i] = ({ "internal-gopher-menu", "gopher://"+URL, a[0] });
	break;

       case 'I':
       case 'g':
	dirl[i] = ({ "internal-gopher-image", "gopher://"+URL, a[0] });
	break;

       default:  /* Who knows.. */
	if(stringp(a[0] && strlen((string)a[0])))
	   dirl[i] = ({ "internal-gopher-unknown", "gopher://"+URL, a[0] });
	else
	  dirl[i] = 0;
      }
#undef URL
    }
    GOPHER_WERR("Sending dir data to client.");
    write_to_client_and_cache(to, Array.map(dirl, make_html_line)*"" +"<hr>",
			      in[-1]);
  } else {
    GOPHER_WERR("Sending cached dir data to client.");
    write_to_client_and_cache(to, dirl*"\n", 0);
  }
  destruct(to);
}

void got_dir_data(array i, string s)
{
  GOPHER_WERR("Got some dir data.");
  i[0] += s;
  if(i[0][-1] == '.' && i[0][-2]=='\n')
    done_dir_data(i);
}

void gopher_done(object id)
{
  id->end();
}

void connected(object ok, string file, object send_to, string query,
	       string key)
{
  string type;

  GOPHER_WERR("Connected");

  if(!send_to)
  {
    destruct(ok);
    return;
  }

  if(!ok)
  {
    send_to->end(CONNECTION_REFUSED);
    return;
  }

  if(strlen(file) < 2)
  {
    type="1";
    file="";
  } else {
    type=file[0..0];
    file=file[1..strlen(file)-1];
  }

  GOPHER_WERR("Requesting file");

  switch(type)
  {
   case "1": /* Directory, must be parsed. */
     GOPHER_WERR("Is a menu");
    ok->write(file + "\r\n");
    ok->set_id(({ "", send_to, ok, key}));
    ok->set_nonblocking(got_dir_data, lambda(){}, done_dir_data);
    send_to->my_fd->write("HTTP/1.0 200 Yo! Gopher dir comming soon to a "
			  "screen near you\nContent-Type: text/html\n\n"
			  "<h1>Gopher menu</h1><hr>");
    return;

    /* 2 is phonebook(?). Should probably be parsed.. */
    /* 3 is error (?) */

   case "4": /* Mac binhex (of all types...) */
    ok->write(file + "\r\n");
    send_to->my_fd->write("HTTP/1.0 200 Yo! Gopher data comming soon to a "
			  "screen near you\n"
			  "Content-Type: application/mac-binhex\n\n");
    break;

   case "5": /* Dos binary (of all types...) */
    ok->write(file + "\r\n");
    send_to->my_fd->write("HTTP/1.0 200 Yo!\n"
			  "Content-Type: application/x-dosbinary\n\n");
    break;

   case "6": /* Unix UUENCODE */
    ok->write(file + "\r\n");
    send_to->my_fd->write("HTTP/1.0 200 Yo!\n"
		   "Content-Type: application/x-uuencode\n\n");
    break;

   case "9": /* Binary */
    ok->write(file + "\r\n");
    send_to->my_fd->write("HTTP/1.0 200 Yo!\n"
			  "Content-Type: application/binary\n\n");
    break;

   case "g": /* Gif image */
    ok->write(file + "\r\n");
    send_to->my_fd->write("HTTP/1.0 200 Gopher data\n"
			  "Content-Type: image/gif\n\n");
    break;

   case "I": /* _some_ image, lets pretend it's a jpeg.. :) */
    ok->write(file + "\r\n");
    send_to->my_fd->write("HTTP/1.0 200  to a screen near you\n"
			  "Content-Type: image/jpeg\n\n");
    break;

   case "7": /* Search, should be handled separately.. */
    if(!query)
    {
      send_to->my_fd->write("HTTP/1.0 200 Yo! Gopher data comming soon to a "
			    "screen near you\nContent-Type: text/html\n\n"
			    "<h1>Gopher search</h1>"
			    "<isindex prompt=\"Gopher search:  \">");
      destruct(ok);
      destruct(send_to);
      return;
    }
    send_to->my_fd->write("HTTP/1.0 200 Yo! Gopher data comming soon to a "
		   "screen near you\nContent-Type: text/html\n\n"
		   "<h1>Gopher Search</h1>"
		   "<isindex prompt=\"Gopher search:  \">");
    ok->write(file + "	" + query + "\r\n");
    ok->set_id(({ "", send_to, ok}));
    ok->set_nonblocking(got_dir_data, lambda(){}, done_dir_data);
    return;

   case "T": /* Tn 3270, shouldn't be here */
   case "+": /* Extra server, shouldn't be here */
   case "8": /* Shouldn't be here... */
   default:
    ok->write(file + "\r\n");
    send_to->my_fd->write("HTTP/1.0 200 Yo! Gopher data comming soon to a "
			  "screen near you\nContent-Type: text/plain\n\n");

  }
  async_pipe(send_to->my_fd, ok, 0, 0, "gopher", key);
  send_to->disconnect();
  /* Go for it... :) */
  return;
}

mapping find_file(string fi, object id)
{
  mixed tmp;
  string h, f, q;
  int p;
  GOPHER_WERR("find_file()");

  if(tmp = proxy_auth_needed(id))
    return tmp;

  sscanf(fi, "%[^/]/%s", h, f);
  if(!f)  f="";
  if (has_prefix(h, "[")) {
    //  IPv6
    if (sscanf(h, "[%s]:%d", h, p))
      h = "[" + h + "]";
  } else {
    sscanf(h, "%s:%d", h, p);
  }
  if(!p)  p=70;
  GOPHER_WERR("host = "+h+"\nfile = "+f+"\nport = "+p);
  sscanf(id->raw_url, "%*s?%s", q);
  if(id->pragma["no-cache"] || id->method != "GET")
  {
    async_connect(h, p, connected, f, id, q, h+":"+p+"/"+f);
   } else {
    async_cache_connect(h, p, "gopher", h+":"+p+"/"+f,
			connected, f, id, q, h+":"+p+"/"+f);
  }
  id->do_not_disconnect = 1;
  return http_pipe_in_progress();
}

string info()
{
  return "This is a simple gopher proxy, useful for firewall sites.";
}
