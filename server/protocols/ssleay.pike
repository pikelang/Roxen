/* ssleay.pike
 *
 */

inherit "protocols/http" : http;

#include <stdio.h>
#include <roxen.h>
#include <module.h>

#define BUFFER_SIZE 65536

class SSL_decode
{
  inherit "/precompiled/file" : http;
  inherit "/precompiled/ssleay_connection" : ssl;

  object https;
  string buffer = "";

  void die()
  {
    werror("SSL_decode: dying\n");
    if (https) https->close();
    destruct(this_object());
  }

  void handle_input()
  {
    werror("SSL_decode: accepting\n");
    if (ssl::accept() > 0)
      while (1)
	{
	  string data = ssl::read(BUFFER_SIZE);
	  if (!stringp(data))
	    break;
	  werror(sprintf("SSL_decode: read '%s'\n", data));
	  if (http::write(data) != strlen(data))
	    break;
	}
    https->close("r");
  }

  void handle_output()
  {
    werror("output thread\n");
    while (1)
      {
	string data = http::read(BUFFER_SIZE, 1);
	werror(sprintf("SSL_decode: writing '%s'\n", data));
	if (!strlen(data))
	  break;
	if (ssl::write(data) != strlen(data))
	  break;
      }
    die();
  }
	  
  object decode(object f)
  {
    object res = http::pipe();

    https = f;
#if 0
    werror(sprintf("ctx: %O\n", ctx));
    ssl::create(ctx);
#endif
    ssl::set_fd(https->query_fd());
    
    https->set_blocking();
    http::set_blocking();

    thread_create(handle_input);
    thread_create(handle_output);

    return res;
  }
}

mapping parse_args(string options)
{
  mapping res = ([]);
  string line;
  
  foreach(options / "\n", line)
    {
      string key, value;
      if (sscanf(line, "%*[ \t]%s%*[ \t]%s%*[ \t]", key, value) == 5)
	res[key] = value;
    }
  return res;
}


private object get_context(string interface, string port)
{
  mapping contexts = roxen->query_var("ssleay_contexts");
  string key = sprintf("%s:%d", interface, port);
  object ctx;
  
  if (!contexts)
    {
      contexts = ([]);
      roxen->set_var("ssleay_contexts", contexts);
    }
  
  ctx = contexts[key];
  if (!ctx)
    {
      ctx = contexts[key] = ((program)"/precompiled/ssleay")();
    }
  return ctx;
}

array|void real_port(array port)
{
  string cert, key;
  mapping options = parse_args(port[3]);
  object ctx = get_context(port[2], port[0]);

  if (!ctx)
    report_error("No context found\n");

  if (!options["cert-file"])
    report_error("No cert-file specified");

  cert = options["cert-file"];
  key =  options["key-file"] || cert;
  werror(sprintf("Using cert-file: '%s'\n", cert));
  ctx->use_certificate_file(cert);
  werror(sprintf("Using key-file: '%s'\n", key));
  ctx->use_private_key_file(key);
  werror(sprintf("real_port: %O\n", port));
}

void assign(object f, object conf)
{
  object ctx;
  array port;
  
  werror(sprintf("%O\n", indices(conf)));
  werror(sprintf("port_open: %O\n", conf->port_open));
  werror(sprintf("open_ports: %O\n", conf->open_ports));
  if (sizeof(conf->open_ports) != 1)
    report_error("ssleay->assign bug: Only one ssleay port supported\n");
  port = values(conf->open_ports)[0];
  ctx = get_context(port[2], port[0]);
  http::assign(SSL_decode(ctx)->decode(f), conf);
}
