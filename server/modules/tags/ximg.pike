constant cvs_version="$Id: ximg.pike,v 1.8 1999/10/18 14:27:35 nilsson Exp $";
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
  if(id->conf->api_functions()->old_rxml_warning)
    id->conf->api_functions()->old_rxml_warning[0](id, "ximg tag ","imgs");
  return make_tag("imgs",m);
}
