constant cvs_version="$Id: ximg.pike,v 1.5 1999/08/02 16:02:04 nilsson Exp $";
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
                      id->conf->api_functions()->old_rxml_warning[0](id, "ximg tag ","imgs");
		      return make_tag("imgs",m);
		    }
  ]);
}
