// $Id: roxen.h,v 1.22 2000/11/24 16:50:35 per Exp $
// -*- Pike -*-

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

#endif  /* !_ROXEN_H_ */
