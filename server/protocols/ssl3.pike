/* $Id: ssl3.pike,v 1.3 1997/04/07 23:23:44 per Exp $
 *
 * © 1997 Informationsvävarna AB
 *
 * This is unpublished alpha source code of Infovav AB.
 *
 * Do NOT redistribute!
 */

// #define SSL3_DEBUG

inherit "protocols/http" : http;

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

object begin_pem = Regexp("-----BEGIN (.*)----- *$");
object end_pem = Regexp("-----END (.*)----- *$");

mapping(string:string) parse_pem(string f)
{
#ifdef SSL3_DEBUG
  werror(sprintf("parse_pem: '%s'\n", f));
#endif
  if(!f)
  {
    report_error("SSL3: No certificate found.\n");
    return 0;
  }
  array(string) lines = f / "\n";
  string name = 0;
  int start_line;
  mapping(string:string) parts = ([ ]);

  for(int i = 0; i < sizeof(lines); i++)
  {
    array(string) res;
    if (res = begin_pem->split(lines[i]))
    {
#ifdef SSL3_DEBUG
      werror(sprintf("Matched start of '%s'\n", res[0]));
#endif
      if (name) /* Bad syntax */
	return 0;
      name = res[0];
      start_line = i + 1;
    }
    else if (res = end_pem->split(lines[i]))
    {
#ifdef SSL3_DEBUG
      werror(sprintf("Matched end of '%s'\n", res[0]));      
#endif
      if (name != res[0]) /* Bad syntax */
	return 0;
      parts[name] = MIME.decode_base64(lines[start_line .. i - 1] * "");
      name = 0;
    }
  }
  if (name) /* Bad syntax */
    return 0;
#ifdef SSL3_DEBUG
  werror(sprintf("pem contents: %O\n", parts));
#endif
  return parts;
}
    
private object new_context(object c)
{
  mapping contexts = roxen->query_var("ssl3_contexts");
  object ctx = SSL.context();;
  
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

array|void real_port(array port)
{
#ifdef SSL3_DEBUG
  werror("SSL3: real_port()\n");
  werror(sprintf("port = %O\n", port));
#endif
  string cert, key;
  object ctx = new_context(roxen->current_configuration);
  mapping options = parse_args(port[3]);

#ifdef SSL3_DEBUG
  werror(sprintf("options = %O\n", options));
#endif
  mapping(string:string) parts = parse_pem(read_file(options["cert-file"]));

  if (!parts || !(cert = parts["CERTIFICATE"]))
    report_error("No certificate found.\n");

  if (options["key-file"])
    parts = parse_pem(read_file(options["key-file"]));
  
  if (!parts || !(key = parts["RSA PRIVATE KEY"]))
    report_error("Private key not found.\n");
  array rsa_parms = SSL.asn1.ber_decode(key)->get_asn1()[1];
  
  ctx->certificates = ({ cert });
  ctx->rsa = Crypto.rsa();
  ctx->rsa->set_public_key(rsa_parms[1][1], rsa_parms[2][1]);
  ctx->rsa->set_private_key(rsa_parms[3][1]);
  ctx->random = Crypto.randomness.reasonably_random()->read;
}

#define CHUNK 15000

string get_data()
{
  string s;
  if(to_send->head)
  {
    s = to_send->head;
    to_send->head=0;
    return s;
  }

  if(to_send->data)
  {
    s = to_send->data;
    to_send->data=0;
    return s;
  }

  if(to_send->file)
  {
    s = to_send->file->read(CHUNK);
    if(s && strlen(s))
      return s;
    to_send->file = 0;
  }

  return 0;
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
  
  int pos = my_fd->write(s);

//  perror("Wrote "+pos+" bytes ("+s+")\n");
  
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
  remove_call_out(timeout);
#endif

  my_fd->set_read_callback(0);
  my_fd->set_close_callback(0); 
  my_fd->set_write_callback(0); 

  if(conf)
  {
//  perror("Handle request, got conf.\n");
    foreach(conf->first_modules(), funp) if(file = funp( thiso)) break;
    
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
//    perror("Leave me...\n");
//      if(!file->stay) { destruct(thiso); }
      my_fd = file = 0;
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
		      "Server":version(),
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
  
  my_fd->set_nonblocking(0, write_more, end);

  if(conf) conf->log(file, thiso);
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
    // http::create(SSL.sslfile(f, ctx), c);
    my_fd = SSL.sslfile(f, ctx);
    conf = c;
    my_fd->set_nonblocking(got_data,0,end);
  } else {
    // Main object. 
  }
}
