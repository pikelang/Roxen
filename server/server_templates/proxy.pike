string name = "Proxy server";
string desc = "A virtual server with all proxy server modules";

array modules = ({"proxy#0", "gopher#0","ftpgateway#0", "contenttypes#0",
		  "wais#0", });

void enable(object config)
{
  foreach(modules, string module)
    config->enable_module(module);
}

