/*
 * $Id: bare.pike,v 1.3 2001/04/07 11:45:30 per Exp $
 */

string name = "Bare bones";
string desc = "A virtual server with _no_ modules";
array modules = ({ });

void enable(object config)
{
  foreach(modules, string module)
    config->enable_module(module);
}
