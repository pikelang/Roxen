string name = "Bare bones";
string desc = "A virtual server with _no_ modules";
array modules = ({ });

void enable(object config)
{
  foreach(modules, string module)
    config->enable_module(module);
}
