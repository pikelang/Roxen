/*
 * $Id: sitebuilder.pike,v 1.3 1998/11/22 17:13:38 mast Exp $
 */

constant selected = 0;
constant name = "SiteBuilder server";
constant desc = "A virtual server with a SiteBuilder";
constant modules = ({
  "contenttypes#0",
  "ismap#0",
  "htmlparse#0",
  "directories#0",
  "graphic_text#0",
  "sitebuilder#0",
});

void enable(object config)
{
  foreach(modules, string module)
    config->enable_module(module);
}

void post(object node)
{
  object o,o2;
  if (o = node->descend("SiteBuilder", 1)) {
    o->folded = 0;
    if (o2 = o->descend("storage", 1)) {
      o2->folded = 0;
      o2->change(1);
    }
  }
}
