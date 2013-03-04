/*
 * By Francesco Chemolli
 * This is a Roxen module. Copyright © 2000 - 2009, Roxen IS.
 */

constant cvs_version="$Id$";

#include <module.h>
inherit "throttlelib";

string filter_type="(by hostname)";
string rules_doc=
#"Throttling rules. One rule per line, whose format is:<br>
<tt>hostname_pattern modifier [fix]</tt>
<tt>hostname_pattern</tt> is a glob that is matched against the client's
hostname.<br>
<i>modifier</i> is the altering rule. There are six possible rule types:<br>
<tt>+{number}</tt> adds <i>number</i> bytes/sec to the request<br>
<tt>-{number}</tt> subtracts <i>number</i> bytes/sec to the request<br>
<tt>*{number}</tt> multiplies the bandwidth assigned to the request
  by <i>number</i> (a floating-point number)<br>
<tt>/{number}</tt> divides the bandwidth assigned to the request
  by <i>number</i> (a floating-point number)<br>
<tt>={number}</tt> assigns the request <i>number</i> bytes/sec of 
  bandwidth<br>
<tt>nothrottle</tt> asserts that the request is not to be throttled.
  It implies using <tt>fix</tt>.<p>
  The optional keyword <tt>fix</tt> will make the assigned bandwidth final.
The rules are scanned in order, and processing is stopped as soon as 
a match is found.<p>
Lines starting with <tt>#</tt> are considered comments.<p>
Since we don't want to wait for a DNS reverse query to be carried out,
it might happen that the first hit (or few hits) from an host are not
correctly recognized. This is a feature, not a bug.";

#ifdef THROTTLING_DEBUG
#undef THROTTLING_DEBUG
#define THROTTLING_DEBUG(X) werror("Throttling: "+X+"\n")
#else
#define THROTTLING_DEBUG(X)
#endif

constant module_type = MODULE_FILTER;
constant module_name = "Throttling: throttle by hostname";
constant module_doc  = 
"This module will alter the assigned bandwith matching the client's hostname";
constant module_unique = 1;


array find_rule (mapping res, object id, 
                 array(string) rulenames, mapping rules) {
  if (!res) return 0;
  return low_find_rule(roxen->quick_ip_to_host(id->remoteaddr), 
                       rulenames, rules);
}
