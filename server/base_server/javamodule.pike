#include <module.h>
inherit "module";

inherit JavaModule.ModuleWrapper;

void create(object conf, string filename)
{
  load(filename);
  if(!modobj)
    destruct(this_object());
  else
    init(conf);
}
