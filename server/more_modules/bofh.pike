constant cvs_version = "$Id$";
#include <module.h>
inherit "module";

constant excuses = ({
  "clock speed ",
  "solar flares ",
  "electromagnetic radiation from satellite debris ",
  "static from nylon underwear ",
  "static from plastic slide rules ",
  "global warming ",
  "poor power conditioning ",
  "static buildup ",
  "doppler effect ",
  "hardware stress fractures "});
constant size = sizeof(excuses);

constant module_type = MODULE_PARSER;
constant module_name = "BOFH Module";
constant module_doc  = "Adds the tag &lt;bofh&gt;, which generates an excuse reason.";
constant module_unique = 1;

string tag_bofh()
{
  return excuses[random(size)];
}


