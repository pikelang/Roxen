/*
 * By Francesco Chemolli
 * This is a Roxen module. Copyright © 2000, Roxen IS.
 */

constant cvs_version="$Id: throttling_byaddress.pike,v 1.1 2000/05/15 19:59:23 kinkie Exp $";

#include <module.h>
inherit "throttlelib";
string filter_type="(by address)";
string rules_doc=
#"Throttling rules. One rule per line, whose format is:<br>
<tt>ip_with_mask modifier [fix]</tt><br>
where ip_with_mask can be an ip address, or 
ip_address/bits, or ip_address:netmask<p>
The search will be stopped at the first match.";

#ifdef THROTTLING_DEBUG
#undef THROTTLING_DEBUG
#define THROTTLING_DEBUG(X) werror("Throttling by address: "+X+"\n")
#else
#define THROTTLING_DEBUG(X)
#endif

constant module_type = MODULE_FILTER;
constant module_name = "Throttling: throttle by address";
constant module_doc  = 
#"This module will alter a request's bandwidth by client address.";
constant module_unique=1;

mapping(string:object(IP_with_mask)) rules_cache=([]);
//I'm not using the global cache because these are going to have a long
//lifespan anyways

object(IP_with_mask) add_to_cache(string rule) {
  array(mixed) a;
  if (sizeof(a=rule/"/")==2) { // ip / bits
    a[1]=(int)a[1];
    return IP_with_mask(@a);
  }
  if (sizeof(a=rule/":")==2) { // ip : mask
    return IP_with_mask(@a);
  }
  if (sscanf(rule,"%*d.%*d.%*d.%*d")==4) { //exact IP
    return IP_with_mask(rule,32);
  }
  throw( ({ "Can't parse rule: "+rule , backtrace() }) );
}

string update_rules() {
   rules_cache=([]);
   ::update_rules();
}

//FIXME: non e` la regola giusta!
array find_rule (mapping res, object id, 
                 array(string) rulenames, mapping rules) {
  string ra=id->remoteaddr;
  THROTTLING_DEBUG("remote is "+ra);
  foreach(rulenames,string rule) {
    object(IP_with_mask) cr;
    if (!rules_cache[rule]) cr=add_to_cache(rule);
    THROTTLING_DEBUG("examining: "+rule);
    if (cr(ra)) {
      THROTTLING_DEBUG("!!matched!!");
      return(rules[rule]);
      break;
    }
  }
  return 0;
}
