/* 
 * fcgimisc.h --
 *
 *      Miscellaneous definitions
 *
 *
 * Copyright (c) 1996 Open Market, Inc.
 *
 * See the file "LICENSE.TERMS" for information on usage and redistribution
 * of this file, and for a DISCLAIMER OF ALL WARRANTIES.
 *
 * $Id: fcgimisc.h,v 1.2 1997/06/01 15:43:47 grubba Exp $
 */

#ifndef _FCGIMISC_H
#define _FCGIMISC_H

#include <stdio.h>
#include <limits.h>

#include <fcgi_config.h>

#ifdef HAVE_SYS_SELECT_H
#include <sys/select.h>
#endif
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#ifdef HAVE_ARPA_INET_H
#include <arpa/inet.h>
#endif /* HAVE_ARPA_INET_H */
#include <sys/un.h>

/*
 * Where does this junk normally come from?
 */
#ifndef FALSE
#define FALSE (0)
#endif

#ifndef TRUE
#define TRUE  (1)
#endif

#ifndef min
#define min(a,b) ((a) < (b) ? (a) : (b))
#endif

#ifndef max
#define max(a,b) ((a) > (b) ? (a) : (b))
#endif

#ifndef ASSERT
#define ASSERT(assertion) (assert(assertion))
#endif

#endif	/* _FCGIMISC_H */
