#define BIT_IO_CHROOT        1

#define BIT_IO_CAN_READ      2
#define BIT_IO_CAN_WRITE     4
#define BIT_IO_CAN_CREATE    8

/* Default is unix security, but using the uid/gid in the user object, if any.
 * It is not always a good idea to trust that, though, hence these bits.
 */
#define BIT_IO_OWNED_AND_GROUP   32
#define BIT_IO_ONLY_OWNED        16

/* Bypass all other owner/gid checks (you can still have ONLY_OWNED et. al.). */
#define BIT_IO_USER_OK           64

#define BIT_CALL 		__builtin.security.BIT_CALL
#define BIT_INDEX 		__builtin.security.BIT_INDEX
#define BIT_SET_INDEX 		__builtin.security.BIT_SET_INDEX
#define BIT_SECURITY 		__builtin.security.BIT_SECURITY
#define BIT_NOT_SETUID 		__builtin.security.BIT_NOT_SETUID
#define BIT_CONDITIONAL_IO 	__builtin.security.BIT_CONDITIONAL_IO

// Not in the security class, but used.
#define BIT_DESTRUCT            64

#ifdef SECURITY
#define Creds __builtin.security.Creds
#define CHECK_SECURITY_BIT( X ) do {							\
  Creds x;										\
  if((x = get_current_creds()) && !(x->get_allow_bits()|(BIT_##X)))	\
    error("Permission denied, lacks " #X " bit\n" );					\
} while(0);
#else
#define Creds __builtin
#define CHECK_SECURITY_BIT(X)
#endif
