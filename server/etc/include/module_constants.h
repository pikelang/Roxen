#ifndef MODULE_CONSTANTS_H
#define MODULE_CONSTANTS_H 1
// Module types.
constant MODULE_ZERO              = 0;
constant MODULE_EXTENSION         = (1<<0);
constant MODULE_LOCATION          = (1<<1);
constant MODULE_URL               = (1<<2);
constant MODULE_FILE_EXTENSION    = (1<<3);
constant MODULE_TAG               = (1<<4);
constant MODULE_PARSER            = MODULE_TAG; // Compatibility
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
constant MODULE_USERDB            = (1<<16);
constant MODULE_WEBSOCKET         = (1<<17);

// Mask for the above.
constant MODULE_TYPE_MASK	  = ((1<<28)-1);

// Module type flags. Not _really_ types, only useful for information
// to the roxen administrations, not used by roxen.
constant MODULE_PROTOCOL         = (1<<28);
constant MODULE_CONFIG           = (1<<29);
constant MODULE_SECURITY         = (1<<30);
constant MODULE_EXPERIMENTAL     = (1<<31);
#endif
