/* $Id: proxyauth.pike,v 1.5 1999/11/29 22:09:41 per Exp $ */

inherit "http";

mapping proxy_auth_needed(RequestID id)
{
  mixed res = id->conf->check_security(proxy_auth_needed, id);
  if(res)
  {
    if(res==1) // Nope...
      return http_low_answer(403, "You are not allowed to access this proxy");
    if(!mappingp(res))
      return 0; // Error, really.
    res->error = 407;
    return res;
  }
  return 0;
}
