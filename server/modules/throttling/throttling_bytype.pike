/*
 * by Francesco Chemolli
 * This is a roxen module. Copyright © 1999 - 2009, Roxen IS.
 *
 * Notice: this might look ugly, it's been designed to be split into
 * a "library" program plus a tiny imlpementation module
 */

constant cvs_version="$Id$";

#include <module.h>
inherit "throttlelib";

string filter_type="(by type)";
string rules_doc=
#"Throttling rules. One rule per line, whose format is:<br>
<tt>type-glob modifier [fix]</tt><br>
<tt>type-glob</tt> is matched on the Content Type header.
(i.e. <tt>image/gif</tt> or <tt>text/html</tt>).<p>
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
The entries are scanned in order, and processing is stopped as soon as 
a match is found.<p>
Lines starting with <tt>#</tt> are considered comments.";


#ifdef THROTTLING_DEBUG
#undef THROTTLING_DEBUG
#define THROTTLING_DEBUG(X) werror("Throttling: "+X+"\n")
#else
#define THROTTLING_DEBUG(X)
#endif

constant module_type = MODULE_FILTER;
constant module_name = "Throttling: throttle by type";
constant module_doc  = "This module will alter the throttling definitions by content type";
constant module_unique = 1;

array find_rule (mapping res, object id, 
                 array(string) rulenames, mapping rules) {
  if (!res) return 0;
  string|array(string) type = res->type;
  if (arrayp(type))
    type = type[0];
  return low_find_rule(type, rulenames, rules);
}

