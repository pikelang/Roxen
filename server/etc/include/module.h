// $Id: module.h,v 1.22 1999/03/27 22:06:27 grubba Exp $
#ifndef ROXEN_MODULE_H
#define ROXEN_MODULE_H

/* Variable types. */
#define TYPE_STRING           1
#define TYPE_FILE             2
#define TYPE_INT              3
#define TYPE_DIR              4

#define TYPE_STRING_LIST      5
#define TYPE_MULTIPLE_STRING  5

#define TYPE_INT_LIST         6
#define TYPE_MULTIPLE_INT     6

#define TYPE_FLAG             7
#define TYPE_TOGGLE           7

#define TYPE_ERROR            8
#define TYPE_DIR_LIST	      9
#define TYPE_FILE_LIST       10
#define TYPE_LOCATION        11
#define TYPE_COLOR	     12
#define TYPE_TEXT_FIELD      13
#define TYPE_TEXT            13
#define TYPE_PASSWORD        14
#define TYPE_FLOAT           15
#define TYPE_PORTS           16
#define TYPE_MODULE          17
#define TYPE_MODULE_LIST     18 /* somewhat buggy.. */
#define TYPE_MULTIPLE_MODULE 18 /* somewhat buggy.. */

#define TYPE_FONT            19

#define TYPE_CUSTOM          20
#define TYPE_NODE            21


/* Variable indexes */
#define VAR_VALUE           0
#define VAR_NAME            1
#define VAR_TYPE            2
#define VAR_DOC_STR         3
#define VAR_MISC            4
#define VAR_CONFIGURABLE    5
#define VAR_SHORTNAME       6

#define VAR_SIZE 	    7

#define VAR_TYPE_MASK     255
#define VAR_EXPERT        256
#define VAR_MORE          512

// Fast but unreliable.
#define QUERY(var)	variables[ #var ][VAR_VALUE]

// Like query, but for global variables.
#ifdef IN_ROXEN
#define GLOBVAR(x) variables[ #x ][VAR_VALUE]
#else /* !IN_ROXEN */
#define GLOBVAR(x) roxen->variables[ #x ][VAR_VALUE]
#endif /* IN_ROXEN */

#define MODULE_EXTENSION         (1<<0)
#define MODULE_LOCATION          (1<<1)
#define MODULE_URL	         (1<<2)
#define MODULE_FILE_EXTENSION    (1<<3)
#define MODULE_PARSER            (1<<4)
#define MODULE_LAST              (1<<5)
#define MODULE_FIRST             (1<<6)

#define MODULE_AUTH              (1<<7)
#define MODULE_MAIN_PARSER       (1<<8)
#define MODULE_TYPES             (1<<9)
#define MODULE_DIRECTORIES       (1<<10)

#define MODULE_PROXY             (1<<11)
#define MODULE_LOGGER            (1<<12)
#define MODULE_FILTER            (1<<13)


// A module which can be called from other modules, protocols, scripts etc.
#define MODULE_PROVIDER		 (1<<15)
// The module implements a protocol.
#define MODULE_PROTOCOL          (1<<16)

// A configuration interface module
#define MODULE_CONFIG            (1<<17)


// Flags.
#define MODULE_SECURITY          (1<<29)
#define MODULE_EXPERIMENTAL      (1<<30)

#define MOD_ALLOW	1
#define MOD_USER	2
#define MOD_DENY	3
#define MOD_PROXY_USER	4
#define MOD_ACCEPT	5
#define MOD_ACCEPT_USER	6
#define MOD_ACCEPT_PROXY_USER	7

#define DEFFONT(X,Y,Z,Q) \
defvar((X)+"_font", (Y), (Z)+": font", TYPE_FONT, (Q));\
defvar((X)+"_weight", "normal", (Z)+": weight", TYPE_STRING_LIST, "", ({"light","normal","bold","black"}));\
defvar((X)+"_slant", "plain", (Z)+": slant", TYPE_STRING_LIST, "", ({"italic","plain"}))


#define CACHE(seconds) id->misc->cacheable=min(id->misc->cacheable,seconds)
#define NOCACHE() id->misc->cacheable=0
#endif





