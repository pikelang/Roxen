/*
 * by Francesco Chemolli
 * (C) 1999 Idonex AB
 *
 * Notice: this might look ugly, it's been designed to be split into
 * a "library" program plus a tiny imlpementation module
 */

constant cvs_version="$Id: throttling_bytype.pike,v 1.4 1999/12/18 14:35:02 nilsson Exp $";

#include <module.h>
inherit "throttlelib";

string filter_type="(by type)";

#ifdef THROTTLING_DEBUG
#undef THROTTLING_DEBUG
#define THROTTLING_DEBUG(X) werror("Throttling: "+X+"\n")
#else
#define THROTTLING_DEBUG(X)
#endif

array register_module() {
  return ({
    MODULE_FILTER,
    "Throttling: throttle by type",
    "This module will alter the throttling definitions by content type",
    0,0});
}

array find_rule (mapping res, object id, 
                 array(string) rulenames, mapping rules) {
  if (!res) return 0;
  return low_find_rule(res->type, rulenames, rules);
}

