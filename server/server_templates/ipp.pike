/*
 * $Id: ipp.pike,v 1.2 1997/08/13 21:50:42 grubba Exp $
 */

constant name = "IPP Customer Server";
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
