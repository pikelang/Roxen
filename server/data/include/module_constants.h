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

// Module type flags. Not _really_ types, only useful for information
// to the roxen administrations, not used by roxen.
constant MODULE_PROTOCOL         = (1<<28);
constant MODULE_CONFIG           = (1<<29);
constant MODULE_SECURITY         = (1<<30);
constant MODULE_EXPERIMENTAL     = (1<<31);

//! See @[RoxenModule.check_locks].
enum LockFlag {
  LOCK_NONE		= 0,
  LOCK_SHARED_BELOW	= 2,
  LOCK_SHARED_AT	= 3,
  LOCK_OWN_BELOW	= 4,
  LOCK_EXCL_BELOW	= 6,
  LOCK_EXCL_AT		= 7
};

//! How to handle an existing destination when files or directories
//! are moved or copied in a filesystem.
enum Overwrite {
  NEVER_OVERWRITE = -1,
  //! Fail if the destination exists. Corresponds to an Overwrite
  //! header with the value "F" (RFC 2518 9.6).

  MAYBE_OVERWRITE = 0,
  //! If the source and destination are directories, overwrite the
  //! properties only. If the source and destination are files,
  //! overwrite the file along with the properties. Otherwise fail if
  //! the destination exists.

  DO_OVERWRITE = 1,
  //! If the destination exists then delete it recursively before
  //! writing the new content. Corresponds to an Overwrite header with
  //! the value "T" (RFC 2518 9.6).
};

#endif
