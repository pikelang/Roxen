// -*- pike -*-
//
// $Id: roxen.h,v 1.24 2003/03/05 13:47:25 mast Exp $

#ifndef _ROXEN_H_

#define _ROXEN_H_
#include <config.h>
#define HOST_TO_IP 'H'
#define IP_TO_HOST 'I'

// Localization support

#ifndef __LOCALEOBJECT
#ifdef IN_ROXEN
mixed get_locale();
#define __LOCALE (get_locale)
#else /* !IN_ROXEN */
#define __LOCALE (roxen.get_locale)
#endif /* IN_ROXEN */
#endif /* !__LOCALEOBJECT */

#ifndef _STR_LOCALE
#define _STR_LOCALE(X, Y, Z)    Locale.translate(X, __LOCALE(), Y, Z)
#endif /* !_STR_LOCALE */

#ifndef _DEF_LOCALE
#  define _DEF_LOCALE(X, Y, Z) ([object(Locale.DeferredLocale)|string]((mixed)Locale.DeferredLocale(X,__LOCALE,Y,Z)))
#endif /* !_DEF_LOCALE */

#ifndef _LOCALE_FUN
#define _LOCALE_FUN(X, Y, Z)    Locale.call(X, __LOCALE(), Y, Z)
#endif /* !_LOCALE_FUN */

// Needed to get core dumps of seteuid()'ed processes on Linux.
#if constant(System.dumpable)
#define enable_coredumps(X)	System.dumpable(X)
#elif constant(system.dumpable)
// Pike 7.2.
#define enable_coredumps(X)	system.dumpable(X)
#else
#define enable_coredumps(X)
#endif

// Debug macros.

#ifdef DEBUG
#define DO_IF_DEBUG(X...) X
#else
#define DO_IF_DEBUG(X...)
#endif

#endif  /* !_ROXEN_H_ */
