/*
 * $Id: proxy.pike,v 1.5 2001/04/07 11:45:31 per Exp $
 */

constant name = "Proxy server";
constant desc = "A virtual server with all proxy server modules";

array modules = ({ "connect#0", "proxy#0","ftpgateway#0", "contenttypes#0" });

void enable(object config)
{
  foreach(modules, string module)
    config->enable_module(module);
}

