/*
 * by Francesco Chemolli
 * This is a roxen module. Copyright © 1999 - 2000, Roxen IS.
 *
 * Notice: this might look ugly, it's been designed to be split into
 * a "library" program plus a tiny imlpementation module
 */

constant cvs_version="$Id: throttling_bytype.pike,v 1.6 2000/03/17 14:13:27 nilsson Exp $";

#include <module.h>
inherit "throttlelib";

string filter_type="(by type)";

#ifdef THROTTLING_DEBUG
#undef THROTTLING_DEBUG
#define THROTTLING_DEBUG(X) werror("Throttling: "+X+"\n")
#else
#define THROTTLING_DEBUG(X)
#endif

constant module_type = MODULE_FILTER;
constant module_name = "Throttling: throttle by type";
constant module_doc  = "This module will alter the throttling definitions by content type";
constant module_unique = 0;

array find_rule (mapping res, object id, 
                 array(string) rulenames, mapping rules) {
  if (!res) return 0;
  return low_find_rule(res->type, rulenames, rules);
}

