/*
 * By Francesco Chemolli
 * This is a Roxen module. Copyright © 2000, Roxen IS.
 */

constant cvs_version="$Id: throttling_bytime.pike,v 1.4 2000/05/22 19:08:09 kinkie Exp $";


#include <module.h>
inherit "throttlelib";
string filter_type="(by time)";
string rules_doc=
#"Throttling rules. One rule per line, with syntax: <br />
<tt>time modifier [fix]</tt><br />
where <tt>time</tt> has the format <tt>HHMM</tt>

The chosen rule will be the one whose time is the first greater than the
current time. In an example:<br />
<pre>0800 +10240  <-- this will be applied betwheen 00:00 and 08:00
1730 -5916   <-- this will be used between 01:01 and 19:00
1900 +0      <-- no changes to the previous rules from 17:30 to 19:00
2400 +5196   <-- this will be used between 17:31 and 23:59</pre>";

constant module_type = MODULE_FILTER;
constant module_name = "Throttling: throttle by time";
constant module_doc  = 
#"This module will alter a request's bandwidth by time of the day";
constant module_unique=1;

#ifdef THROTTLING_DEBUG
#undef THROTTLING_DEBUG
#define THROTTLING_DEBUG(X) werror("Throttling by time: "+X+"\n")
#else
#define THROTTLING_DEBUG(X)
#endif

//I'll go the simple way, refreshing a cached value once a minute.
//the efficient way would be going for call_outs, but it would be quite harder
//to implement, and generally not worth it.

private static array current_rule;
private mixed update_call_out;

void update_current_rule() {
  THROTTLING_DEBUG("updating current rule");
  update_call_out=call_out(update_current_rule,60);

  if (!rules) {
    THROTTLING_DEBUG("empty rules. Bailing out..");
    return;
  }
  mapping(string:int) tm=localtime(time(1));
  string now=(string)(tm->hour)+(string)(tm->min);
  THROTTLING_DEBUG("now is "+now+", rules are "+(indices(rules)*", "));
  foreach(sort(indices(rules)),string rule) {
    THROTTLING_DEBUG("examining: "+rule);
    if (rule >= now) {
      current_rule=rules[rule];
      THROTTLING_DEBUG("selected rule "+rule);
      return;
    }
  }
  THROTTLING_DEBUG("no rule selected");
  current_rule=0; //no rule found
}

string|void update_rules(string new_rules) {
  THROTTLING_DEBUG("updating rules: "+new_rules);
  string s;
  s=::update_rules(new_rules);
  if (s) return s;
  if (rules)
    rulenames=sort(rulenames); //we really want them sorted now
                               //we'll use this kind of a cache.
  remove_call_out(update_call_out);
  update_call_out=0;
  update_current_rule();
}

array find_rule (mapping res, object id, 
                 array(string) rulenames, mapping rules) {
  return current_rule;
}

void start() {
  THROTTLING_DEBUG("starting");
  ::start();
  if (update_call_out) {
    remove_call_out(update_call_out);
    update_call_out=0;
  }
  update_current_rule();
}

void stop() {
  remove_call_out(update_call_out);
  update_call_out=0;
  //::stop(); What happens if the function is not defined in the parent class?
}
