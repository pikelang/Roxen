/*
 * $Id: basic.pike,v 1.2 2001/04/07 11:45:30 per Exp $
 */

constant name = "Basic Server";
constant desc = "A virtual server with the most basic modules";

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
