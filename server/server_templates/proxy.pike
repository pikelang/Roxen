/*
 * $Id: proxy.pike,v 1.4 1998/11/03 09:15:08 peter Exp $
 */

constant name = "Proxy server";
constant desc = "A virtual server with all proxy server modules";

constant modules = ({"connect#0", "proxy#0", "ftpgateway#0",
		     "contenttypes#0" });

void enable(object config)
{
  foreach(modules, string module)
    config->enable_module(module);
}

