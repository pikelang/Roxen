/* $Id: ssl3.pike,v 1.28 1998/03/20 03:32:23 per Exp $
 *
 * Copyright © 1996-1998, Idonex AB
 */

// #define SSL3_DEBUG

inherit "protocols/http" : http;
inherit "roxenlib";

mapping to_send;

#include <stdio.h>
#include <roxen.h>
#include <module.h>

mapping parse_args(string options)
{
  mapping res = ([]);
  string line;
  
  foreach(options / "\n", line)
    {
      string key, value;
      if (sscanf(line, "%*[ \t]%s%*[ \t]%s%*[ \t]", key, value) == 5)
	res[key] = value-"\r";
    }
  return res;
}

class roxen_ssl_context {
  inherit SSL.context;
  int port; /* port number */
}

private object new_context(object c)
{
  mapping contexts = roxen->query_var("ssl3_contexts");
  object ctx = roxen_ssl_context();
  
  if (!contexts)
  {
    contexts = ([ c : ctx ]);
    roxen->set_var("ssl3_contexts", contexts);
  }
  else
    contexts[c] = ctx;
  return ctx;
}

private object get_context(object c)
{
  mapping contexts = roxen->query_var("ssl3_contexts");

  return contexts && contexts[c];
}

array|void real_port(array port, object cfg)
{
#ifdef SSL3_DEBUG
  werror("SSL3: real_port()\n");
  werror(sprintf("port = %O\n", port));
#endif

  string cert, key;
  object ctx = new_context(cfg);
  ctx->port = port[0];
  mapping options = parse_args(port[3]);

#ifdef SSL3_DEBUG
  werror(sprintf("options = %O\n", options));
#endif

  if (!options["cert-file"]) {
    ({ report_error, throw }) ("ssl3: No 'cert-file' argument!\n");
  }

  mapping(string:string) parts = SSL.pem.parse_pem(read_file(options["cert-file"]));

  if (!parts || !(cert = parts["CERTIFICATE"]||parts["X509 CERTIFICATE"])) {
    ({ report_error, throw }) ("ssl3: No certificate found.\n");
  }

  if (options["key-file"])
    parts = SSL.pem.parse_pem(read_file(options["key-file"]));
  
  if (!parts || !(key = parts["RSA PRIVATE KEY"])) {
    ({ report_error, throw }) ("ssl3: Private key not found.\n");
  }
  array rsa_parms = Standards.ASN1.decode(key)->get_asn1()[1];
  
  ctx->certificates = ({ cert });
  ctx->rsa = Crypto.rsa();
  ctx->rsa->set_public_key(rsa_parms[1][1], rsa_parms[2][1]);
  ctx->rsa->set_private_key(rsa_parms[3][1]);
  ctx->random = Crypto.randomness.reasonably_random()->read;
}

#define CHUNK 16384

string to_send_buffer;

static void write_more();

void got_data_to_send(mixed fooid, string data)
{
  if (!to_send_buffer) {
    to_send_buffer = data;
    my_fd->set_nonblocking(0, write_more, end);
    return;
  }
  to_send_buffer += data;
}

void no_data_to_send(mixed fooid)
{
  if (to_send->file) {
    to_send->file->set_blocking();
    to_send->file->close();
  }
  to_send->file = 0;
  if (!to_send_buffer) {
    // We need to wake up the sender,
    // so that it can close the connection.
    my_fd->set_nonblocking(0, write_more, end);
  }
}

string get_data()
{
  string s;
  if(to_send->head)
  {
    s = to_send->head;
    to_send->head = 0;
    return s;
  }

  if(to_send->data)
  {
    s = to_send->data;
    to_send->data = 0;
    return s;
  }

  s = to_send_buffer;
  to_send_buffer = 0;

  if(to_send->file) {
    /* There's a file, but no data yet
     * disable ourselves until there is.
     */
    my_fd->set_nonblocking(0, 0, end);
    return s || "";
  }

  return s;
}

string cache;
static void write_more()
{
  string s;
  if(!cache)
    s = get_data();
  else
    s = cache;

  if(!s)
  {
//    perror("SSL3:: Done.\n");
    my_fd->set_blocking();
    my_fd->close();
    my_fd = 0;
    destruct();
    return;
  }    

  if (sizeof(s)) {
    int pos = my_fd->write(s);

    // perror("Wrote "+pos+" bytes ("+s+")\n");
  
    if(pos <= 0) // Ouch.
    {
#ifdef DEBUG
      perror("SSL3:: Broken pipe.\n");
#endif
      my_fd->set_blocking();
      my_fd->close();
      my_fd = 0;
      destruct();
      return;
    }  
    if(pos < strlen(s))
      cache = s[pos..];
    else
      cache = 0;
  } else {
    cache = 0;
  }
}

string get_data_file()
{
  string s;
  if(to_send->head)
  {
    s = to_send->head;
    to_send->head = 0;
    return s;
  }

  if(to_send->data)
  {
    s = to_send->data;
    to_send->data = 0;
    return s;
  }

  if(to_send->file) {
    // Read some more data
    s = to_send->file->read(CHUNK,1);
  }

  return s;
}

static void write_more_file()
{
  string s;
  if(!cache)
    s = get_data_file();
  else
    s = cache;

  if(!s)
  {
//    perror("SSL3:: Done.\n");
    my_fd->set_blocking();
    my_fd->close();
    my_fd = 0;
    destruct();
    return;
  }    

  if (sizeof(s)) {
    int pos = my_fd->write(s);

    // perror("Wrote "+pos+" bytes ("+s+")\n");
  
    if(pos <= 0) // Ouch.
    {
#ifdef DEBUG
      perror("SSL3:: Broken pipe.\n");
#endif
      my_fd->set_blocking();
      my_fd->close();
      my_fd = 0;
      destruct();
      return;
    }  
    if(pos < strlen(s))
      cache = s[pos..];
    else
      cache = 0;
  } else {
    cache = 0;
  }
}


void handle_request( )
{
  mixed *err;
  int tmp;
#ifdef KEEP_CONNECTION_ALIVE
  int keep_alive;
#endif
  function funp;
  mapping heads;
  string head_string;
  object thiso=this_object();

#ifndef SPEED_MAX
  remove_call_out(do_timeout);
  remove_call_out(do_timeout);
#endif

  my_fd->set_read_callback(0);
  my_fd->set_close_callback(0); 
  my_fd->set_write_callback(0); 

  if(conf)
  {
//  perror("Handle request, got conf.\n");
    object oc = conf;
    foreach(conf->first_modules(), funp) {
      if(file = funp( thiso)) break;
      if(conf != oc) {handle_request();return;}
    }

    
    if(!file) err=catch(file = conf->get_file(thiso));

    if(err) internal_error(err);
    
    if(!mappingp(file))
      foreach(conf->last_modules(), funp) if(file = funp(thiso)) break;
  } else if(err=catch(file = roxen->configuration_parse( thiso ))) {
    if(err==-1) return;
    internal_error(err);
  }

  if(!mappingp(file))
  {
    if(misc->error_code)
      file = http_low_answer(misc->error_code, errors[misc->error]);
    else if(method != "GET" && method != "HEAD" && method != "POST")
      file = http_low_answer(501, "Not implemented.");
    else
      file=http_low_answer(404,
			   replace(parse_rxml(conf->query("ZNoSuchFile"),
					      thiso),
				   ({"$File", "$Me"}), 
				   ({not_query,
				       conf->query("MyWorldLocation")})));
  } else {
    if((file->file == -1) || file->leave_me) 
    {
      my_fd = 0;
      file = 0;
      return;
    }

    if(file->type == "raw")
      file->raw = 1;
    else if(!file->type)
      file->type="text/plain";
  }
  
  if(!file->raw && prot != "HTTP/0.9")
  {
    string h;
    heads=
      ([
	"Content-type":file["type"],
		      "Server":replace(version(), " ", "·"),
		      "Date":http_date(time)
	 ]);
    
    if(file->encoding)
      heads["Content-Encoding"] = file->encoding;
    
    if(!file->error) 
      file->error=200;
    
    if(file->expires)
      heads->Expires = http_date(file->expires);

    if(!file->len)
    {
      if(objectp(file->file))
	if(!file->stat && !(file->stat=misc->stat))
	  file->stat = (int *)file->file->stat();
      array fstat;
      if(arrayp(fstat = file->stat))
      {
	if(file->file && !file->len)
	  file->len = fstat[1];
    
    
	heads["Last-Modified"] = http_date(fstat[3]);
	
	if(since)
	{
	  if(is_modified(since, fstat[3], fstat[1]))
	  {
	    file->error = 304;
	    method="HEAD";
	  }
	}
      }
      if(stringp(file->data)) 
	file->len += strlen(file->data);
    }

    if(mappingp(file->extra_heads)) 
      heads |= file->extra_heads;

    if(mappingp(misc->moreheads))
      heads |= misc->moreheads;
    
    array myheads = ({prot+" "+(file->rettext||errors[file->error])});
    foreach(indices(heads), h)
      if(arrayp(heads[h]))
	foreach(heads[h], tmp)
	  myheads += ({ `+(h,": ", tmp)});
      else
	myheads +=  ({ `+(h, ": ", heads[h])});


    if(file->len > -1)
      myheads += ({"Content-length: " + file->len });
    head_string = (myheads+({"",""}))*"\r\n";
    
    if(conf) conf->hsent+=strlen(head_string||"");
  }

  if(method == "HEAD")
  {
    file->data = 0;
    file->file = 0;
  }

  
  if(conf)
    conf->sent+=(file->len>0 ? file->len : 1000);

  file->head = head_string;
  to_send = copy_value(file);
  
  if (objectp(to_send->file)) {
    array st = to_send->file->stat && to_send->file->stat();
    if (st && (st[1] >= 0)) {
      // Ordinary file -- can't use non-blocking I/O
      my_fd->set_nonblocking(0, write_more_file, end);
    } else {
      my_fd->set_nonblocking(0, write_more, end);
      to_send->file->set_nonblocking(got_data_to_send, 0, no_data_to_send);
    }
  } else {
    my_fd->set_nonblocking(0, write_more, end);
  }

  if(thiso && conf) conf->log(file, thiso);
}

class fallback_redirect_request {
  string in = "";
  string out;
  string prefix;
  int port;
  object f;

  void die()
  {
#if 0
    /* Close the file, DAMMIT */
    object dummy = Stdio.File();
    if (dummy->open("/dev/null", "rw"))
      dummy->dup2(f);
#endif    
    f->close();
    destruct(f);
    destruct(this_object());
  }
  
  void write_callback(object id)
  {
    int written = id->write(out);
    if (written <= 0)
      die();
    out = out[written..];
    if (!strlen(out))
      die();
  }

  void read_callback(object id, string s)
  {
    in += s;
    string name;

    if (search(in, "\r\n\r\n") >= 0)
    {
//      werror(sprintf("request = '%s'\n", in));
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
	  foreach(Array.map(lines[1..], `/, ":"), array header)
	  {
	    if ( (lower_case(header[0]) == "host")
		 &&  (sizeof(header) >= 2))
	      prefix = "https://" + header[1] - " ";
	  }
	}
	if (prefix[-1] == '/')
	  prefix = prefix[..strlen(prefix)-2];
	out = sprintf("HTTP/1.0 301 Redirect to secure server\r\n"
		      "Location: %s:%d%s\r\n\r\n", prefix, port, name);
      }
      f->set_read_callback(0);
      f->set_write_callback(write_callback);
    }
  }
  
  void create(object socket, string s, string l, int p)
  {
    f = socket;
    prefix = l;
    port = p;
    f->set_nonblocking(read_callback, 0, die);
    f->set_id(f);
    read_callback(f, s);
  }
}

void http_fallback(object alert, object|int n, string data)
{
//  trace(1);
#if 0
  werror(sprintf("ssl3->http_fallback: alert(%d, %d)\n"
		 "seq_num = %s\n"
		 "data = '%s'", alert->level, alert->description,
		 (string) n, data));
#endif
  if ( (my_fd->current_write_state->seq_num == 0)
       && search(lower_case(data), "http"))
  {
    /* Redirect to a https-url */
//    my_fd->set_close_callback(0);
//    my_fd->leave_me_alone = 1;
    fallback_redirect_request(my_fd->raw_file, data,
			      (my_fd->config &&
			       my_fd->config->query("MyWorldLocation")) || "/",
			      my_fd->context->port);
    destruct(my_fd);
    destruct(this_object());
//    my_fd = 0; /* Forget ssl-object */
  }
}

void ssl_accept_callback(object id)
{
  id->set_alert_callback(0); /* Forget about http_fallback */
  id->raw_file = 0;          /* Not needed any more */
}

class roxen_sslfile {
  inherit SSL.sslfile : ssl;

  object raw_file;
  object config;

  constant no_destruct=1; /* Kludge to avoid http.pike destructing us */

#if 0
  int leave_me_alone; /* If this is set, don't let
		       * the ssl-code shut down the connection. */

  void die(int status)
  {
//    werror("ssl3.pike, roxen_ssl_file: die called\n");
    if (!leave_me_alone)
      ssl::die(status);
  }
#endif
  
  void create(object f, object ctx, object id)
  {
    raw_file = f;
    config = id;
    ssl::create(f, ctx);
  }
}

void create(object f, object c)
{
  if(f)
  {
    object ctx;
    array port;

#if 0
    werror(sprintf("%O\n", indices(conf)));
    werror(sprintf("port_open: %O\n", conf->port_open));
    werror(sprintf("open_ports: %O\n", conf->open_ports));
    if (sizeof(conf->open_ports) != 1)
      report_error("ssl3->assign bug: Only one ssl port supported\n");
    port = values(conf->open_ports)[0];
#endif
    ctx = get_context(c);
    if (!ctx)
    {
      roxen_perror("ssl3.pike: No SSL context!\n");
      throw( ({ "ssl3.pike: No SSL context!\n", backtrace() }) );
    }
    my_fd = roxen_sslfile(f, ctx, c);
    if(my_fd->set_alert_callback)
      my_fd->set_alert_callback(http_fallback);
    my_fd->set_accept_callback(ssl_accept_callback);
    conf = c;
    my_fd->set_nonblocking(got_data,0,end);
  } else {
    // Main object. 
  }
}
