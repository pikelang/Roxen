constant cvs_version="$Id: ximg.pike,v 1.4 1999/12/14 02:22:22 nilsson Exp $";
#include <module.h>
inherit "module";
inherit "roxenlib";

constant thread_safe=1;

array register_module()
{
  return ({ MODULE_PARSER, "Ximg",
	    "This module is obsolete. It does the same thing as the imgs tag.",0,1 });
}

RoxenModule rxml_warning_cache;
void old_rxml_warning(RequestID id, string no, string yes) {
  if(!rxml_warning_cache) rxml_warning_cache=my_configuration()->get_provider("oldRXMLwarning");
  if(!rxml_warning_cache) return;
  rxml_warning_cache->old_rxml_warning(id, no, yes);
}

string tag_ximg(string t, mapping m, RequestID id) {
  old_rxml_warning(id, "ximg tag","imgs");
  return make_tag("imgs",m);
}
