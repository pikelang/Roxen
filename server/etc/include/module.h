// $Id: module.h,v 1.33 2000/02/16 07:07:16 per Exp $
#ifndef ROXEN_MODULE_H
#define ROXEN_MODULE_H
#ifndef MODULE_CONSTANTS_H
#include <module_constants.h>
#endif
// Fast but unreliable.
#define QUERY(var)	variables[ #var ][VAR_VALUE]

// Like query, but for global variables.
#ifdef IN_ROXEN
#define GLOBVAR(x) variables[ #x ][VAR_VALUE]
#else /* !IN_ROXEN */
#define GLOBVAR(x) roxen->variables[ #x ][VAR_VALUE]
#endif /* IN_ROXEN */

#define CACHE(seconds) id->misc->cacheable=min(id->misc->cacheable,seconds)
#define NOCACHE() id->misc->cacheable=0
#define TAGDOCUMENTATION mapping tagdocumentation(){return get_value_from_file(__FILE__,"tagdoc","#define manual\n");}
#endif
