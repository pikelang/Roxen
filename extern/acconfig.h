/*
 * $Id: acconfig.h,v 1.3 1998/02/28 16:43:25 grubba Exp $
 *
 * Config file for some of Roxen's external binaries.
 *
 * $Author: grubba $
 */
#ifndef EXTERN_CONFIG_H
#define EXTERN_CONFIG_H

/* Define if you have h_errno */
#undef HAVE_H_ERRNO

/* Define if you signals are one-shot. */
#undef SIGNAL_ONESHOT

/* Number of possible filedesriptors */
#define MAX_OPEN_FILEDESCRIPTORS 1024

@TOP@
@BOTTOM@
#endif /* EXTERN_CONFIG_H */
