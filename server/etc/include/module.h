// $Id: module.h,v 1.40 2000/08/28 05:31:12 per Exp $
#ifndef ROXEN_MODULE_H
#define ROXEN_MODULE_H
#include "config.h"
// compat
#define QUERY(var)	query( #var )

// Like query, but for global variables.
#ifdef IN_ROXEN
#define GLOBVAR(x) query( #x )
#else /* !IN_ROXEN */
#define GLOBVAR(x) roxenp()->query(#x)
#endif /* IN_ROXEN */

#define CACHE(seconds) ([mapping(string:mixed)]id->misc)->cacheable=min(([mapping(string:mixed)]id->misc)->cacheable,seconds)
#define NOCACHE() ([mapping(string:mixed)]id->misc)->cacheable=0
#define TAGDOCUMENTATION mapping tagdocumentation(){return [mapping]get_value_from_file(__FILE__,"tagdoc","#define manual\n");}

#define ROXEN_MAJOR_VERSION 2
#define ROXEN_MINOR_VERSION 1


#define TYPE_STRING            1
#define TYPE_FILE              2
#define TYPE_INT               3
#define TYPE_DIR               4
#define TYPE_STRING_LIST       5
#define TYPE_MULTIPLE_STRING   5
#define TYPE_INT_LIST          6
#define TYPE_MULTIPLE_INT      6
#define TYPE_FLAG              7
#define TYPE_TOGGLE            7
#define TYPE_DIR_LIST	       9
#define TYPE_FILE_LIST        10
#define TYPE_LOCATION         11
#define TYPE_TEXT_FIELD       13
#define TYPE_TEXT             13
#define TYPE_PASSWORD         14
#define TYPE_FLOAT            15
#define TYPE_MODULE           17
#define TYPE_FONT             19
#define TYPE_CUSTOM           20
#define TYPE_URL              21
#define TYPE_URL_LIST         22

#define VAR_TYPE_MASK        255


/* Not normally needed. */
#define VAR_EXPERT         256
#define VAR_MORE           512
#define VAR_DEVELOPER     1024
#define VAR_INITIAL       2048

#define MOD_ALLOW	         1
#define MOD_USER	         2
#define MOD_DENY	         3
#define MOD_PROXY_USER	         4
#define MOD_ACCEPT	         5
#define MOD_ACCEPT_USER	 	 6
#define MOD_ACCEPT_PROXY_USER	 7
#endif
