/* $Id: ssl3.pike,v 1.1.2.2 1997/03/26 20:47:27 grubba Exp $
 *
 * © 1997 Informationsvävarna AB
 *
 * This is unpublished alpha source code of Infovav AB.
 *
 * Do NOT redistribute!
 */

inherit "protocols/http" : http;

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
	res[key] = value;
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

void assign(object f, object c)
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
  http::assign(SSL.sslfile(f, ctx), c);
}
