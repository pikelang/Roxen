// This file is part of Roxen WebServer.
// Copyright © 1999 - 2001, Roxen IS.
// $Id: javamodule.pike,v 1.5 2001/06/17 20:07:09 nilsson Exp $

#include <module.h>
inherit "module";

inherit JavaModule.ModuleWrapper;


static string my_filename;
static Configuration my_conf;


string file_name_and_stuff()
{
  return ("<b>Loaded from:</b> "+my_filename+"<br />");
}

void create(Configuration conf, string filename)
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
