constant cvs_version="$Id: ximg.pike,v 1.2 1999/11/27 13:39:43 nilsson Exp $";
#include <module.h>
inherit "module";
inherit "roxenlib";

constant thread_safe=1;

array register_module()
{
  return ({ MODULE_PARSER, "Ximg",
	    "This module is obsolete. It does the same thing as the imgs tag.",0,1 });
}

string tag_ximg(string t, mapping m, RequestID id) {
  call_provider("oldRXMLwarning", old_rxml_warning, id, "ximg tag","imgs");
  return make_tag("imgs",m);
}
