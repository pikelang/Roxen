#ifndef MODULE_CONSTANTS_H
#define MODULE_CONSTANTS_H 1
// Variable types.
constant TYPE_STRING           = 1;
constant TYPE_FILE             = 2;
constant TYPE_INT              = 3;
constant TYPE_DIR              = 4;
constant TYPE_STRING_LIST      = 5;
constant TYPE_MULTIPLE_STRING  = 5;
constant TYPE_INT_LIST         = 6;
constant TYPE_MULTIPLE_INT     = 6;
constant TYPE_FLAG             = 7;
constant TYPE_TOGGLE           = 7;
constant TYPE_DIR_LIST	       = 9;
constant TYPE_FILE_LIST       = 10;
constant TYPE_LOCATION        = 11;
constant TYPE_TEXT_FIELD      = 13;
constant TYPE_TEXT            = 13;
constant TYPE_PASSWORD        = 14;
constant TYPE_FLOAT           = 15;
constant TYPE_MODULE          = 17;
constant TYPE_FONT            = 19;
constant TYPE_CUSTOM          = 20;

// Variable array indices.
constant VAR_VALUE           = 0;
constant VAR_NAME            = 1;
constant VAR_TYPE            = 2;
constant VAR_DOC_STR         = 3;
constant VAR_MISC            = 4;
constant VAR_CONFIGURABLE    = 5;
constant VAR_SHORTNAME       = 6;
constant VAR_SIZE 	     = 7;

constant VAR_TYPE_MASK     = 255;

// Variable type flags.
constant VAR_EXPERT        = 256;
constant VAR_MORE          = 512;
constant VAR_DEVELOPER    = 1024;
constant VAR_INITIAL      = 2048;

// Module types.
constant MODULE_ZERO              = 0;
constant MODULE_EXTENSION         = (1<<0);
constant MODULE_LOCATION          = (1<<1);
constant MODULE_URL               = (1<<2);
constant MODULE_FILE_EXTENSION    = (1<<3);
constant MODULE_PARSER            = (1<<4);
constant MODULE_LAST              = (1<<5);
constant MODULE_FIRST             = (1<<6);
constant MODULE_AUTH              = (1<<7);
constant MODULE_MAIN_PARSER       = (1<<8);
constant MODULE_TYPES             = (1<<9);
constant MODULE_DIRECTORIES       = (1<<10);
constant MODULE_PROXY             = (1<<11);
constant MODULE_LOGGER            = (1<<12);
constant MODULE_FILTER            = (1<<13);
constant MODULE_PROVIDER          = (1<<15);

// Module type flags. Not _really_ types, only useful for information
// to the roxen administrations, not used by roxen.
constant MODULE_PROTOCOL         = (1<<28);
constant MODULE_CONFIG           = (1<<29);
constant MODULE_SECURITY         = (1<<30);
constant MODULE_EXPERIMENTAL     = (1<<31);

// Module level security.
constant MOD_ALLOW	        = 1;
constant MOD_USER	        = 2;
constant MOD_DENY	        = 3;
constant MOD_PROXY_USER	        = 4;
constant MOD_ACCEPT	        = 5;
constant MOD_ACCEPT_USER	= 6;
constant MOD_ACCEPT_PROXY_USER	= 7;
#endif
