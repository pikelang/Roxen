/*
 * $Id: sitebuilder.pike,v 1.1 1998/02/21 13:11:28 mirar Exp $
 */

constant selected = 0;
constant name = "Sitebuilder server";
constant desc = "A virtual server with Sitebuilder";
constant modules = ({
  "contenttypes#0",
  "ismap#0",
  "htmlparse#0",
  "directories#0",
  "graphic_text#0",
  "content_editor#0",
});

void enable(object config)
{
  foreach(modules, string module)
    config->enable_module(module);
}
