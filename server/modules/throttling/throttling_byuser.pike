/*
 * By Francesco Chemolli
 * This is a Roxen module. Copyright © 2000 - 2009, Roxen IS.
 *
 * This module was developed while traveling by plane, while returning
 * from Sweden.
 * It can be probably assumed that my development server is
 * the fastetst Roxen server up to date, and that this module is the 
 * fastest-developed module.
 */

constant cvs_version="$Id$";

#include <module.h>
inherit "throttlelib";
string filter_type="(by user)";
string rules_doc=
#"Throttling rules. One rule per line, whose format is:<br>
<tt>username modifier [fix]</tt><br>
If <tt>username</tt> matches (exactly), the assocuated rule will be 
applied.<br>
Special usernames: <tt>any</tt> means any authenticated user.
<tt>noauth</tt> means unidentified user (the opposite of <tt>any</tt>).<br>
A failed authentication challenge will be handled as if no authentication
had taken place at all.<br>
The search will be stopped at the first match.";


#ifdef THROTTLING_DEBUG
#undef THROTTLING_DEBUG
#define THROTTLING_DEBUG(X) werror("Throttling by user: "+X+"\n")
#else
#define THROTTLING_DEBUG(X)
#endif

constant module_type = MODULE_FILTER;
constant module_name = "Throttling: throttle by user";
constant module_doc  = #"This module will alter a request's bandwidth by user
name. It will <b>not</b> require any user authentication, which is to be
requested by other modules. However, if authentication info is present, it
will be matched against this module's rules";
constant module_unique=1;

array find_rule (mapping res, object id, 
                 array(string) rulenames, mapping rules) {
  if (!res) return 0; //This request is likely to end up as a 404 not found.
  THROTTLING_DEBUG(sprintf("id->auth is %O",id->auth));
  string user=(id->auth&&arrayp(id->auth)&&id->auth[0]?
               ((id->auth[1])/":")[0]:"noauth");
  THROTTLING_DEBUG("Got user "+user);
  foreach(rulenames,string rule) {
    THROTTLING_DEBUG("examining: "+rule);
    if (rule==user || rule=="any") {
      THROTTLING_DEBUG("!!matched!!");
      return(rules[rule]);
      break;
    }
  }
}
