// This file is part of Roxen Webserver.
// Copyright © 1999 - 2000, Roxen IS.
// $Id: javamodule.pike,v 1.3 2000/02/20 17:41:33 nilsson Exp $

#include <module.h>
inherit "module";

inherit JavaModule.ModuleWrapper;


static string my_filename;
static object my_conf;


string file_name_and_stuff()
{
  return ("<b>Loaded from:</b> "+my_filename+"<br>");
}

void create(object conf, string filename)
{
  load(my_filename = filename);
  if(!modobj)
    destruct(this_object());
  else {
    foreach(getdefvars(), array dv)
      defvar(@dv);
    init(my_conf = conf);
  }
}
