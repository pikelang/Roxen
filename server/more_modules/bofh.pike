string cvs_version = "$Id: bofh.pike,v 1.2 1996/12/01 19:18:47 per Exp $";
#include <module.h>
inherit "module";

string *excuses = ({
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

array register_module()
{
  return ({ MODULE_PARSER,
            "BOFH  Module",
            "Adds an extra tag, 'bofh'.", ({}), 1
            });
}


string bofh_excuse(string tag, mapping m)
{
  return excuses[random(sizeof(excuses))];
}

string info() { return bofh_excuse("", ([])); }

mapping query_tag_callers() { return (["bofh":bofh_excuse,]); }

mapping query_container_callers() { return ([]); }



