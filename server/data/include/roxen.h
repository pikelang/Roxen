// -*- pike -*-
//
// $Id: roxen.h,v 1.26 2002/07/10 12:42:01 nilsson Exp $

#ifndef _ROXEN_H_

#define _ROXEN_H_
#include <config.h>
#define HOST_TO_IP 'H'
#define IP_TO_HOST 'I'

// Localization support

#ifndef __LOCALEOBJECT
#ifndef IN_ROXEN
#define __LOCALE (roxen.get_locale)
#endif /* !IN_ROXEN */
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

// Debug macros.

#ifdef DEBUG
#define DO_IF_DEBUG(X...) X
#else
#define DO_IF_DEBUG(X...)
#endif

#endif  /* !_ROXEN_H_ */
