/*
 * $Id: sitebuilder.pike,v 1.5 1998/12/03 18:28:06 mast Exp $
 */

#include <module.h>

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
  object o, o2;

  if (o = node->descend ("Global", 1)) {
    if (o2 = o->descend ("named_ftp", 1)) {
      o2->data[VAR_VALUE] = 1;
      o2->change (1);
    }
    else report_warning ("Couldn't turn on named FTP\n");
    if (o2 = o->descend ("shells", 1)) {
      o2->data[VAR_VALUE] = "";
      o2->change (1);
    }
    else report_warning ("Couldn't deactivate shells database check\n");
    if (o2 = o->descend ("Ports", 1)) o2->folded = 0;
    o->save();
  }
  else report_warning ("Couldn't initialize in server variables section\n");

  if (o = node->descend("SiteBuilder", 1)) {
    o->folded = 0;
    if (o2 = o->descend("storage", 1)) {
      o2->folded = 0;
      o2->change(1);
    }
  }
  else report_warning ("Couldn't find SiteBuilder module\n");
}
