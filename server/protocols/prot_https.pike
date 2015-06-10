// This is a roxen protocol module.
// Copyright © 2001 - 2009, Roxen IS.

// $Id$

// --- Debug defines ---

#ifdef SSL3_DEBUG
# define SSL3_WERR(X) werror("SSL3: "+X+"\n")
#else
# define SSL3_WERR(X)
#endif

inherit SSLProtocol;

// SSL in Pike 8.0 and later supports SNI, and even in older versions
// it is possible to use glob-certs that match several sites.
constant supports_ipless = 1;
constant name = "https";
constant prot_name = "https";
constant requesthandlerfile = "protocols/http.pike";
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
    f->set_blocking();
    f->close();
  }

  void write_callback()
  {
    SSL3_WERR(sprintf("fallback_redirect_request::write_callback()"));
    int written = f->write(out);
    if (written <= 0)
      die();
    else {
      out = out[written..];
      if (!strlen(out))
	die();
    }
  }

  void timeout()
  {
    SSL3_WERR("fallback_redirect_request::timeout()");
    die();
  }

  void read_callback(mixed ignored, string s)
  {
    SSL3_WERR(sprintf("fallback_redirect_request::read_callback(X, %O)\n", s));
    in += s;
    string name;
    string prefix;

    remove_call_out(timeout);
    if (search(in, "\r\n\r\n") >= 0)
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
	    /* RFC 3986 3.2.2. Host
	     *
	     * host       = IP-literal / IPv4address / reg-name
	     * IP-literal = "[" ( IPv6address / IPvFuture  ) "]"
	     * IPvFuture  = "v" 1*HEXDIG "." 1*( unreserved / sub-delims / ":" )
	     *
	     * IPv6address is as in RFC3513.
	     */
	    if (has_value(ip, ":")) {
	      // IPv6
	      ip = "[" + ip + "]";
	    }
	    prefix = "https://" + ip + ":" + port;
	  } else {
	    mixed err = catch {
		object uri = Standards.URI(prefix);
		uri->scheme = "https";
		uri->port = port;
		prefix = (string)uri;
	      };
	    if(err)
	      report_error("Malformed Primary Server URL : %O\n", prefix);
	  }
	}
	out = sprintf("HTTP/1.0 301 Redirect to secure server\r\n"
		      "Location: %s%s\r\n\r\n", prefix, name);
      }
      f->set_read_callback(0);
      f->set_write_callback(write_callback);
    } else {
      if (sizeof(in) > 5) {
	string q = replace(upper_case(in[..10]), "\t", " ");
	if (!(has_prefix(q, "GET ") ||
	      has_prefix(q, "HEAD ") ||
	      has_prefix(q, "OPTIONS ") ||
	      has_prefix(q, "PUT ") ||
	      has_prefix(q, "PROPFIND "))) {
	  // Doesn't look like a HTTP request.
	  // Bail out.
	  SSL3_WERR(sprintf("fallback_redirect_request->read_callback():\n"
			    "Doesn't look like HTTP (method: %O)\n", q));
	  die();
	  return;
	}
      }
      call_out(timeout, 30);
    }
  }

  void create(Stdio.File socket, string s, string l, int p)
  {
    SSL3_WERR(sprintf("fallback_redirect_request(X, %O, %O, %d)", s, l||"CONFIG PORT", p));
    f = socket;
    default_prefix = sizeof(l) && l;
    port = p;
    f->set_nonblocking(read_callback, 0, die);
    read_callback(f, s);
  }

  string _sprintf (int flag)
  {
    return flag == 'O' && sprintf ("fallback_redirect_request(%O)", f);
  }
}

class http_fallback
{
  SSL.sslfile my_fd;

  void ssl_alert_callback(object alert, object|int n, string data)
  {
    SSL3_WERR(sprintf("http_fallback(X, %O, %O)", n, data));
    //  trace(1);
    if (((my_fd->current_write_state||
	  my_fd->query_connection()->current_write_state)->seq_num == 0) &&
      search(lower_case(data), "http"))
    {
      if (function close_cb = my_fd->query_close_callback())
	// Pretend there was a close of the old fd. This is necessary
	// to make the http RequestID cleanup and destruct itself
	// properly.
	close_cb (my_fd->query_id());
      
      Stdio.File raw_fd;
      if (my_fd->shutdown) {
	raw_fd = my_fd->shutdown();
      } else {
	raw_fd = my_fd->socket;
	my_fd->socket = 0;
      }

      /* Redirect to an https-url */
      Configuration conf;
      foreach(values(urls)->conf, conf) {
	if (conf->query("default_server")) {
	  // This configuration has been tagged as a default server.
	  break;
	}
      }
      // FIXME: Consider the case where the port has been remapped.
      fallback_redirect_request(raw_fd, data,
				conf && conf->query("MyWorldLocation"),
				port);

      if (!my_fd->shutdown) {
	// Old sslfile contains cyclic references.
	destruct(my_fd);
      }

      // Break cyclic refs.
      my_fd = 0;
    }
  }

  void ssl_accept_callback (mixed ignored)
  {
    SSL3_WERR(sprintf("ssl_accept_callback()"));
    my_fd->set_alert_callback(0); /* Forget about http_fallback */
    my_fd->set_accept_callback(0);
    my_fd = 0;          /* Not needed any more */
  }

  void create(SSL.sslfile|Stdio.File fd)
  {
    my_fd = fd;
    fd->set_alert_callback(ssl_alert_callback);
    fd->set_accept_callback(ssl_accept_callback);
  }

  string _sprintf (int flag)
  {
    return flag == 'O' && sprintf ("http_fallback(%O)", my_fd);
  }
}

Stdio.File accept()
{
  object(Stdio.File)|SSL.sslfile q = ::accept();

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
