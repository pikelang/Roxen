// This is a roxen module. Copyright © 1996 - 2009, Roxen IS.
// This module can be used to turn off logging for some files.


constant cvs_version = "$Id$";
constant thread_safe = 1;

#include <module.h>
inherit "module";

constant module_type = MODULE_LOGGER;
constant module_name = "Logging disabler";
constant module_doc  = "This module can be used to turn off logging for some files. "
  "It is based on "/*"<a href=$docurl/regexp.html>"*/"Regular"
  " expressions"/*"</a>"*/;

class RegexpList {
  inherit Variable.List;

  array verify_set( array(string)values ) {
    string warn="";

    if(catch(Regexp(make_regexp(values))))
      return ({ "Compile error in regular expression.\n", query() });

    return ::verify_set( values );
  }
}

void create()
{

  // Compatibility with old settings
  definvisvar("nlog", "", TYPE_TEXT_FIELD);
  definvisvar("log", "", TYPE_TEXT_FIELD);

  defvar("nLog",
	 RegexpList( ({ }), 0,
		     "No logging for",
		     "All files whose (virtual)filename match the pattern above "
		     "will be excluded from logging. This is a regular expression"
		     ) );

  defvar("Log",
	 RegexpList( ({ ".*" }), 0,
		     "Logging for",
		     "All files whose (virtual)filename match the pattern above "
		     "will be logged, unless they match any of the 'No logging for'"
		     "patterns. This is a regular expression"
		     ) );
}

string make_regexp(array from)
{
  return "("+from*")|("+")";
}

function(string:int) no_log_match, log_match;

void start()
{
  // Compatibility with old settings
  if(query("log") && sizeof(query("log")))
    set("Log", query("log")/"\n"-({""}));
  if(query("nlog") && sizeof(query("nlog")))
    set("nLog", query("nlog")/"\n"-({""}));

  no_log_match = Regexp(make_regexp(query("nLog")-({""})))->match;
  log_match = Regexp(make_regexp(query("Log")-({""})))->match;
}


int nolog(string what)
{
  if(no_log_match(what)) return 1;
  if(log_match(what)) return 0;
}


int log(RequestID id, mapping file)
{
  if(nolog(id->raw_url))
    return 1;
}
