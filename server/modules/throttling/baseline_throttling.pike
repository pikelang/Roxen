#include <module.h>
inherit "module";

constant cvs_version="$Id: baseline_throttling.pike,v 1.1 1999/09/04 22:40:45 kinkie Exp $";

#ifdef THROTTLING_DEBUG
#undef THROTTLING_DEBUG
#define THROTTLING_DEBUG(X) perror("Throttling: "+X+"\n")
#else
#define THROTTLING_DEBUG(X)
#endif

array register_module() {
  return ({
    MODULE_FIRST,
    "Throttling: baseline setting",
#"This module will assign all requests a \"base\" bandwidth. That bandwidth
will usually then be altered by other throttling modules",
    0,1}); //having many is not a problem, but it doesn't really make sense
}

void create() {
  defvar("rate",10240,"Assigned bandwidth",TYPE_INT,
         "Every request will be assigned this much bandwidth.");
}

mixed first_try (object id) {
  THROTTLING_DEBUG("baseline_throttling: setting rate to "+QUERY(rate));
  id->throttle=1;
  id->rate=QUERY(rate);
}
