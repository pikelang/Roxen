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
#define QUERY(var)      variables["var"][VAR_VALUE]

// Like query, but for global variables.
#define GLOBVAR(x) roxen->variables["x"][VAR_VALUE]

#define MODULE_EXTENSION         (2<<0)
#define MODULE_LOCATION          (2<<1)
#define MODULE_URL	         (2<<2)
#define MODULE_FILE_EXTENSION    (2<<3)
#define MODULE_PARSER            (2<<4)
#define MODULE_LAST              (2<<5)
#define MODULE_FIRST             (2<<6)

#define MODULE_AUTH              (2<<7)
#define MODULE_MAIN_PARSER       (2<<8)
#define MODULE_TYPES             (2<<9)
#define MODULE_DIRECTORIES       (2<<10)

#define MODULE_PROXY             (2<<11)
#define MODULE_LOGGER            (2<<12)
#define MODULE_FILTER            (2<<13)

#define MODULE_SECURITY          (2<<14)

#define MODULE_PROVIDER		 (2<<15)

#define MOD_ALLOW   1
#define MOD_USER    2
#define MOD_DENY    3
#define MOD_PROXY_USER    4

#define DEFFONT(X,Y,Z,Q) \
defvar((X)+"_font", (Y), (Z)+": font", TYPE_FONT, (Q));\
defvar((X)+"_weight", "normal", (Z)+": weight", TYPE_STRING_LIST, "", ({"light","normal","bold","black"}));\
defvar((X)+"_slant", "plain", (Z)+": slant", TYPE_STRING_LIST, "", ({"italic","plain"}))



#endif




