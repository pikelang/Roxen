inherit "read_config";

string cvs_version = "$Id: module_support.pike,v 1.8 1997/01/29 04:59:35 per Exp $";
#include <roxen.h>
#include <module.h>
#include <config.h>

#if DEBUG_LEVEL > 0
#ifndef MODULE_DEBUG
#  define MODULE_DEBUG
#endif
#endif


/* Set later on to something better in roxen.pike::main() */
array (object) configurations;
mapping (string:mixed *) variables=([]); 

/* Variable support for the main Roxen "module". Normally this is
 * inherited from module.pike, but this is not possible, or wanted, in
 * this case.  Instead we define a few support functions.
 */

int setvars( mapping (string:mixed) vars )
{
  string v;
  foreach( indices( vars ), v )
    if(variables[v])
      variables[v][ VAR_VALUE ] = vars[ v ];
  return 1;
}

varargs int globvar(string var, mixed value, string name, int type,
		    string doc_str, mixed misc, int|function not_in_config)
{
  variables[var]                     = allocate( VAR_SIZE );
  variables[var][ VAR_VALUE ]        = value;
  variables[var][ VAR_TYPE ]         = type;
  variables[var][ VAR_DOC_STR ]      = doc_str;
  variables[var][ VAR_NAME ]         = name;
  variables[var][ VAR_MISC ]         = misc;
  
  if(intp(not_in_config))
    variables[var][ VAR_CONFIGURABLE ] = !not_in_config;
  else
    variables[var][ VAR_CONFIGURABLE ] = not_in_config;
  variables[var][ VAR_SHORTNAME ] = var;
}

public mixed query(string var)
{
  if(var && variables[var])
    return variables[var][ VAR_VALUE ];
  error("query("+var+"). Unknown variable.\n");
}

mixed set(string var, mixed val)
{
#if DEBUG_LEVEL > 30
  perror(sprintf("MAIN: set(\"%s\", %O)\n", var, val));
#endif
  if(variables[var])
  {
#if DEBUG_LEVEL > 28
    perror("MAIN:    Setting global variable.\n");
#endif
    return variables[var][VAR_VALUE] = val;
  }
  error("set("+var+"). Unknown variable.\n");
}


/* =============================================== */
/* =============================================== */
/* =============================================== */
/* =============================================== */
/* =============================================== */


program last_loaded();
object load_from_dirs(array q, string);

varargs void store(string what, mapping map, int mode);

/* ================================================= */
/* ================================================= */

 

