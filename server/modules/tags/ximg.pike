constant cvs_version="$Id: ximg.pike,v 1.4 1999/08/01 18:02:53 nilsson Exp $";
#include <module.h>
inherit "module";
inherit "roxenlib";

array register_module()
{
  return ({ MODULE_PARSER, "Ximg",
	    "This module is obsolete. It does the same thing as the imgs tag.",0,1 });
}

mapping query_tag_callers()
{
  return ([ "ximg":lambda(string t, mapping m, object id) {
		      return make_tag("imgs",m);
		    }
  ]);
}
