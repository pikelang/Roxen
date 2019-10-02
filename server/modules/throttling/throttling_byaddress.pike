/*
 * By Francesco Chemolli
 * This is a Roxen module. Copyright © 2000 - 2009, Roxen IS.
 */

constant cvs_version="$Id$";

#include <module.h>
inherit "throttlelib";
string filter_type="(by address)";
string rules_doc=
#"Throttling rules. One rule per line, whose format is:<br />
<tt>ip_with_mask modifier [fix]</tt><br />
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

class IP_with_mask 
{
  int net;
  int mask;
  private int ip_to_int(string ip)
  {
    int res;
    foreach(((ip/".") + ({ "0", "0", "0" }))[..3], string num) {
      res = res*256 + (int)num;
    }
    return(res);
  }
  void create(string _ip, string|int _mask)
  {
    net = ip_to_int(_ip);
    if (intp(_mask)) {
      if (_mask > 32) {
	report_error(sprintf("Bad netmask: %s/%d\n"
			     "Using %s/32\n", _ip, _mask, _ip));
	_mask = 32;
      }
      mask = ~0<<(32-_mask);
    } else {
      mask = ip_to_int(_mask);
    }
    if (net & ~mask) {
      report_error(sprintf("Bad netmask: %s for network %s\n"
			   "Ignoring node-specific bits\n", _ip, _mask));
      net &= mask;
    }
  }
  int `()(string ip)
  {
    return((ip_to_int(ip) & mask) == net);
  }
}

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

string|void update_rules(string new_rules) {
   rules_cache=([]);
   return ::update_rules(new_rules);
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
