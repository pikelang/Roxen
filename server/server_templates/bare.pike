/*
 * $Id: bare.pike,v 1.2 1997/08/13 21:51:06 grubba Exp $
 */

string name = "Bare bones";
string desc = "A virtual server with _no_ modules";
constant modules = ({ });

void enable(object config)
{
  foreach(modules, string module)
    config->enable_module(module);
}
