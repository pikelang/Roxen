/*
 * $Id: basic.pike,v 1.2 1999/09/20 20:33:19 nilsson Exp $
 */

constant name = "Basic Server";
constant desc = "A virtual server with the most basic modules";

constant modules = ({
  "contenttypes#0",
  "ismap#0",
  "rxmlparse#0",
  "rxmltags#0",
  "url_rectifier#0",
  "directories#0",
  "filesystem#0",
});

void enable(object config)
{
  foreach(modules, string module)
    config->enable_module(module);
}
