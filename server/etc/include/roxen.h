// $Id: roxen.h,v 1.7 1998/10/12 23:26:29 grubba Exp $
#ifndef _ROXEN_H_
#define _ROXEN_H_
#include <config.h>
#define HOST_TO_IP 'H'
#define IP_TO_HOST 'I'
#endif

#define perror	roxen_perror

// Localization support
#ifndef LOW_LOCALE
#ifdef THREADS
#ifdef IN_ROXEN
#define LOW_LOCALE	locale->get()
#define SET_LOCALE(X)	locale->set(X)
#else
#define LOW_LOCALE	roxen->locale->get()
#define SET_LOCALE(X)	roxen->locale->set(X)
#endif /* IN_ROXEN */
#else /* !THREADS */
#ifdef IN_ROXEN
#define LOW_LOCALE	locale
#else
#define LOW_LOCALE	roxen->locale
#endif /* IN_ROXEN */
#define SET_LOCALE(X)	LOW_LOCALE=(X)
#endif /* THREADS */
#endif /* !LOW_LOCALE */

#define CONFIGURATION_FILE_LEVEL 6

#ifdef DEBUG_LEVEL
#if DEBUG_LEVEL > 7
#ifndef HOST_NAME_DEBUG
# define HOST_NAME_DEBUG
#endif
#endif
#endif /* DEBUG_LEVEL is not defined from install */
