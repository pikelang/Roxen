/*
 * $Id: proxy.pike,v 1.2 1997/08/13 21:50:20 grubba Exp $
 */

constant name = "Proxy server";
constant desc = "A virtual server with all proxy server modules";

constant modules = ({"proxy#0", "gopher#0","ftpgateway#0", "contenttypes#0",
		     "wais#0", });

void enable(object config)
{
  foreach(modules, string module)
    config->enable_module(module);
}

