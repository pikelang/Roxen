// This file is part of Roxen WebServer.
// Copyright © 1996 - 2009, Roxen IS.
// $Id$

// Mostly compatibility file
inherit "roxenlib";
mapping proxy_auth_needed(RequestID id)
{
  mixed res = id->conf->check_security(proxy_auth_needed, id);
  if(res)
  {
    if(res==1) // Nope...
      return Roxen.http_low_answer(403, "You are not allowed to access this proxy");
    if(!mappingp(res))
      return 0; // Error, really.
    res->error = 407;
    return res;
  }
  return 0;
}
