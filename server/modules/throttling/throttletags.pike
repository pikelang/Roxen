#include <module.h>
inherit "module";
inherit "roxenlib";

constant thread_safe=1;
constant cvs_version="$Id: throttletags.pike,v 1.1 1999/09/29 20:30:44 kinkie Exp $";

#ifdef THROTTLING_DEBUG
#undef THROTTLING_DEBUG
#define THROTTLING_DEBUG(X) perror("throttletags: "+X+"\n")
#else
#define THROTTLING_DEBUG(X)
#endif

#define THROW(X) throw( X+"\n" )

static private int loaded=0;

//wouldn't this better be moved to the module.pike file?
static private string doc()
{
  return !loaded?"":replace(Stdio.read_bytes("modules/tags/doc/throttle")||"",
			    ({ "{", "}" }), ({ "&lt;", "&gt;" }));
}

array register_module() {
  return ({
    MODULE_PARSER,
      "Throttling control tags",
      "This module provides a <tt>&lt;THROTTLE&gt;</tt> tag "
    "that you can use to determine a request's allocated bandwidth"+doc(),
    0,1});
}

mapping query_tag_callers() {
  return (["throttle":tag_throttle]);
}

void start() {
  loaded=1;
}

mixed tag_throttle(string tag, mapping args, object id) {
  mapping t=id->throttle;
  string tmp;
  if (args->help)
    return doc();
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
