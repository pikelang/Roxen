// This is a roxen module. Copyright © 1999 - 2009, Roxen IS.

#include <module.h>
inherit "module";

constant thread_safe=1;
constant cvs_version="$Id$";

#ifdef THROTTLING_DEBUG
#undef THROTTLING_DEBUG
#define THROTTLING_DEBUG(X) werror("throttletags: "+X+"\n")
#else
#define THROTTLING_DEBUG(X)
#endif

constant module_type = MODULE_TAG;
constant module_name = "Throttling control tags";
constant module_doc  = "This module provides a <tt>&lt;THROTTLE&gt;</tt> tag "
  "that you can use to determine a request's allocated bandwidth";
constant module_unique = 1;

TAGDOCUMENTATION;
#ifdef manual
constant tagdoc=(["throttle":#"<desc tag='tag'><p><short>
 This tag determines a request's allocated bandwidth.</short></p>
</desc>

<attr name='not'><p>
Disables all and any throttling for the current request. Implies the
'final' arg.</p>
</attr>

<attr name='add' value='rate'><p>
Adds 'rate' bytes/sec to the current rate for the current request.</p>
</attr>

<attr name='subtract' value='rate'><p>
Subtracts 'rate' bytes/sec from the current rate for the current
request.</p>
</attr>

<attr name='multiply' value='float'><p>
Multiplies this requests' bandwidth by 'float'.</p>
</attr>

<attr name='divide' value='float'><p>
Divides this requests' bandwidth by 'float'.</p>
</attr>

<attr name='rate' value='value'><p>
Sets this request's bandwidth to 'value'.</p>
</attr>

<attr name='final' required='required'><p>
No subsequent modifications will be done to this request's bandwidth
after the current one.</p>
</attr>",
		]);
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
