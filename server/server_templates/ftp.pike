/*
 * $Id: ftp.pike,v 1.2 1997/08/13 21:50:02 grubba Exp $
 */

#include <module.h>

constant name = "FTP server";
constant desc = "An FTP server ";
constant modules = ({ "filesystem#0", "userdb#0", "htaccess#0", });

void enable(object config)
{
  foreach(modules, string module)
    config->enable_module(module);
}

void post(object node)
{
  object o,o2;
  if (o = node->descend("Global", 1)) {
    if (o2 = o->descend("Listen ports", 1)) {
      o2->data[VAR_VALUE] = ({ ({ 21, "ftp", "ANY", "" }) });
    }
    if (o2 = o->descend("Allow named FTP", 1)) {
      o2->folded = 0;
      o2->change(1);
    }
    if (o2 = o->descend("Messages", 1)) {
      o2->folded = 0;
      o2->change(1);
      if (o2 = o2->descend("FTP Welcome", 1)) {
	o2->folded = 0;
	o2->change(1);
      }
    }
    if (o2 = o->descend("Shell database", 1)) {
      o2->folded = 0;
      o2->change(1);
    }
  }
  if (o = node->descend("User database and security", 1)) {
    object o2;
    if (o2 = o->descend("Password database request method", 1)) {
      o2->folded = 0;
      o2->change(1);
    }
    if (o2 = o->descend("Password database file", 1)) {
      o2->folded = 0;
      o2->change(1);
    }
  }
}
