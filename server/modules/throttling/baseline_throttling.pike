// This is a roxen module. Copyright © 1999 - 2000, Roxen IS.

#include <module.h>
inherit "module";

constant cvs_version="$Id: baseline_throttling.pike,v 1.5 2000/03/17 14:13:27 nilsson Exp $";

#ifdef THROTTLING_DEBUG
#undef THROTTLING_DEBUG
#define THROTTLING_DEBUG(X) werror("Throttling: "+X+"\n")
#else
#define THROTTLING_DEBUG(X)
#endif

constant module_type = MODULE_FIRST;
constant module_name = "Throttling: baseline setting";
constant module_doc  = "This module will assign all requests"
  "a \"base\" bandwidth. That bandwidth"
  "will usually then be altered by other throttling modules";

void create() {
  defvar("rate",10240,"Assigned bandwidth",TYPE_INT,
         "Every request will be assigned this much bandwidth.");
}

mixed first_try (object id) {
  THROTTLING_DEBUG("baseline_throttling: setting rate to "+QUERY(rate));
  id->throttle->doit=1;
  id->throttle->rate=QUERY(rate);
}
