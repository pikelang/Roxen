// This file is part of ChiliMoon.
// Copyright © 1999 - 2001, Roxen IS.
// $Id: javamodule.pike,v 1.8 2004/04/04 14:26:43 mani Exp $

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
    destruct(this);
  else {
    foreach(getdefvars(), array dv)
      defvar(@dv);
    init(my_conf = conf);
  }
}
