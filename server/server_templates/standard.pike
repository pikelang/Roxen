string name = "Generic server";
string desc = "A virtual server with the most popular modules";
array modules = ({
  "cgi#0",
  "contenttypes#0",
  "ismap#0",
  "pikescript#0",
  "htmlparse#0",
  "directories#0",
  "userdb#0",
  "userfs#0",
  "filesystem#0",
  "gtext#0",
});

void enable(object config)
{
  foreach(modules, string module)
    config->enable_module(module);
}
