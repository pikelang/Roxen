/*
 * $Id: standard.pike,v 1.7 2001/04/07 11:45:31 per Exp $
 */

constant selected = 1;
constant name = "Generic server";
constant desc = "A virtual server with the most popular modules";
array modules = ({
  "cgi#0",
  "contenttypes#0",
  "ismap#0",
  "htaccess#0",
  "htmlparse#0",
  "directories#0",
  "userdb#0",
  "userfs#0",
  "filesystem#0",
  "graphic_text#0",
});

void enable(object config)
{
  foreach(modules, string module)
    config->enable_module(module);
}
