/*
 * $Id: proxy.pike,v 1.3 1997/08/22 16:42:27 neotron Exp $
 */

constant name = "Proxy server";
constant desc = "A virtual server with all proxy server modules";

constant modules = ({"connect#0", "proxy#0", "gopher#0","ftpgateway#0",
		     "contenttypes#0", "wais#0",  });

void enable(object config)
{
  foreach(modules, string module)
    config->enable_module(module);
}

