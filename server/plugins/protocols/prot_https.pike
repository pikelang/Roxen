// This is a roxen protocol module.
// Copyright © 2001, Roxen IS.

// $Id: prot_https.pike,v 2.6 2002/10/22 00:13:34 nilsson Exp $

// --- Debug defines ---

#ifdef SSL3_DEBUG
# define SSL3_WERR(X) werror("SSL3: "+X+"\n")
#else
# define SSL3_WERR(X)
#endif

inherit SSLProtocol;

constant supports_ipless = 0;
constant name = "https";
constant prot_name = "https";
constant requesthandlerfile = "plugins/protocols/http.pike";
constant default_port = 443;


class fallback_redirect_request
{
  string in = "";
  string out;
  string default_prefix;
  int port;
  Stdio.File f;

  void die()
  {
    SSL3_WERR(sprintf("fallback_redirect_request::die()"));
    f->close();
    destruct(f);
    destruct(this_object());
  }

  void write_callback(object id)
  {
    SSL3_WERR(sprintf("fallback_redirect_request::write_callback()"));
    int written = id->write(out);
    if (written <= 0)
      die();
    out = out[written..];
    if (!strlen(out))
      die();
  }

  void read_callback(object id, string s)
  {
    SSL3_WERR(sprintf("fallback_redirect_request::read_callback(X, \"%s\")\n", s));
    in += s;
    string name;
    string prefix;

    if (has_value(in, "\r\n\r\n"))
    {
      //      werror("request = '%s'\n", in);
      array(string) lines = in / "\r\n";
      array(string) req = replace(lines[0], "\t", " ") / " ";
      if (sizeof(req) < 2)
      {
	out = "HTTP/1.0 400 Bad Request\r\n\r\n";
      }
      else
      {
	if (sizeof(req) == 2)
	{
	  name = req[1];
	}
	else
	{
	  name = req[1..sizeof(req)-2] * " ";
	  foreach(map(lines[1..], `/, ":"), array header)
	  {
	    if ( (sizeof(header) >= 2) &&
		 (lower_case(header[0]) == "host") )
	      prefix = "https://" + header[1] - " ";
	  }
	}
	if (prefix) {
	  if (prefix[-1] == '/')
	    prefix = prefix[..strlen(prefix)-2];
	  prefix = prefix + ":" + port;
	} else {
	  /* default_prefix (aka MyWorldLocation) already contains the
	   * portnumber.
	   */
	  if (!(prefix = default_prefix)) {
	    /* This case is most unlikely to occur,
	     * but better safe than sorry...
	     */
	    string ip = (f->query_address(1)/" ")[0];
	    prefix = "https://" + ip + ":" + port;
	  } else if (prefix[..4] == "http:") {
	    /* Broken MyWorldLocation -- fix. */
	    prefix = "https:" + prefix[5..];
	  }
	}
	out = sprintf("HTTP/1.0 301 Redirect to secure server\r\n"
		      "Location: %s%s\r\n\r\n", prefix, name);
      }
      f->set_read_callback(0);
      f->set_write_callback(write_callback);
    }
  }

  void create(object socket, string s, string l, int p)
  {
    SSL3_WERR(sprintf("fallback_redirect_request(X, \"%s\", \"%s\", %d)", s, l||"CONFIG PORT", p));
    f = socket;
    default_prefix = l;
    port = p;
    f->set_nonblocking(read_callback, 0, die);
    f->set_id(f);
    read_callback(f, s);
  }
}

class http_fallback
{
  object my_fd;

  void ssl_alert_callback(object alert, object|int n, string data)
  {
    SSL3_WERR(sprintf("http_fallback(X, %O, \"%s\")", n, data));
    //  trace(1);
    if ( (my_fd->current_write_state->seq_num == 0)
	 && has_value(lower_case(data), "http"))
    {
      object raw_fd = my_fd->socket;
      my_fd->socket = 0;

      /* Redirect to a https-url */
      //    my_fd->set_close_callback(0);
      //    my_fd->leave_me_alone = 1;
      fallback_redirect_request(raw_fd, data,
				my_fd->config &&
				my_fd->config->query("MyWorldLocation"),
				port);
      destruct(my_fd);
      destruct(this_object());
      //    my_fd = 0; /* Forget ssl-object */
    }
  }

  void ssl_accept_callback(object id)
  {
    SSL3_WERR(sprintf("ssl_accept_callback(X)"));
    id->set_alert_callback(0); /* Forget about http_fallback */
    my_fd = 0;          /* Not needed any more */
  }

  void create(object fd)
  {
    my_fd = fd;
    fd->set_alert_callback(ssl_alert_callback);
    fd->set_accept_callback(ssl_accept_callback);
  }
}

object accept()
{
  object q = ::accept();

  if (q) {
    http_fallback(q);
  }
  return q;
}

int set_cookie, set_cookie_only_once;
void fix_cvars( Variable.Variable a )
{
  set_cookie = query( "set_cookie" );
  set_cookie_only_once = query( "set_cookie_only_once" );
}

void create( mixed ... args )
{
  roxen.set_up_http_variables( this_object() );
  if( variables[ "set_cookie" ] )
    variables[ "set_cookie" ]->set_changed_callback( fix_cvars );
  if( variables[ "set_cookie_only_once" ] )
    variables[ "set_cookie_only_once" ]->set_changed_callback( fix_cvars );
  fix_cvars(0);
  ::create( @args );
}
