/*
 * $Id: sitebuilder.pike,v 1.2 1998/08/10 19:58:11 marcus Exp $
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

void post(object node)
{
  object o,o2;
  if (o = node->descend("Site Content Editor", 1)) {
    o->folded = 0;
    if (o = o->descend( "0", 1 )) {
      o->folded = 0;
      if (o2 = o->descend("cvsroot", 1)) {
	o2->folded = 0;
	o2->change(1);
      }
      if (o2 = o->descend("repository", 1)) {
	o2->folded = 0;
	o2->change(1);
      }
      if (o2 = o->descend("storage", 1)) {
	o2->folded = 0;
	o2->change(1);
      }
    }
  }
}
