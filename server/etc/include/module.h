// $Id: module.h,v 1.35 2000/03/28 15:00:46 nilsson Exp $
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

#define CACHE(seconds) ([mapping(string:mixed)]id->misc)->cacheable=min(([mapping(string:mixed)]id->misc)->cacheable,seconds)
#define NOCACHE() ([mapping(string:mixed)]id->misc)->cacheable=0
#define TAGDOCUMENTATION mapping tagdocumentation(){return get_value_from_file(__FILE__,"tagdoc","#define manual\n");}

#define ROXEN_MAJOR_VERSION 2
#define ROXEN_MINOR_VERSION 0

#endif
