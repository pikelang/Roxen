#include <module.h>
inherit "module";
inherit "roxenlib";

constant thread_safe=1;
constant cvs_version="$Id: throttletags.pike,v 1.4 2000/02/12 16:09:30 nilsson Exp $";

#ifdef THROTTLING_DEBUG
#undef THROTTLING_DEBUG
#define THROTTLING_DEBUG(X) werror("throttletags: "+X+"\n")
#else
#define THROTTLING_DEBUG(X)
#endif

#define THROW(X) throw( X+"\n" )

constant module_type = MODULE_PARSER;
constant module_name = "Throttling control tags";
constant module_doc  = "This module provides a <tt>&lt;THROTTLE&gt;</tt> tag "
  "that you can use to determine a request's allocated bandwidth";

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=(["throttle":"<desc tag></desc>"]);
#endif

string|int tag_throttle(string tag, mapping args, RequestID id) {
  mapping t=id->throttle;
  string tmp;
  if (t->fixed) {
    THROTTLING_DEBUG("Fixed. returning");
    return 0;
  }
  if (args->not) {
    THROTTLING_DEBUG("Don't want to throttle.");
    t->doit=0;
    t->fixed=1;
    return 0;
  }

  if (tmp=args->add) {
    t->rate+=(int)tmp;
    t->doit=1;
    THROTTLING_DEBUG("added "+tmp);
  }
  if (tmp=args->subtract) {
    t->rate-=(int)tmp;
    t->doit=1;
    THROTTLING_DEBUG("subtracted "+tmp);
  }
  if (tmp=args->multiply) {
    t->rate=(int)(t->rate*(float)tmp);
    t->doit=1;
    THROTTLING_DEBUG("multiplied by "+tmp);
  }
  if (tmp=args->divide) {
    t->rate=(int)(t->rate/(float)tmp);
    t->doit=1;
    THROTTLING_DEBUG("divided by "+tmp);
  }
  if (tmp=args->rate) {
    t->rate=(int)tmp;
    t->doit=1;
    THROTTLING_DEBUG("rate set to "+tmp);
  }
  if (args["final"]) {
    t->fixed=1;
    t->doit=1;
    THROTTLING_DEBUG("finalized setting");
  }

  return "";
}
