/*
 * $Id: basic.pike,v 1.1 1997/12/15 02:13:06 peter Exp $
 */

constant name = "Basic Server";
constant desc = "A virtual server with the most basic modules";

constant modules = ({
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
