string name = "IPP Customer Server";
string desc = "A virtual server with the most basic modules";

array modules = ({
  "contenttypes#0",
  "ismap#0",
  "htmlparse#0",
  "directories#0",
  "filesystem#0",
});

void enable(object config)
{
  foreach(modules, string module)
    config->enable_module(module);
}
