// $Id: roxen.h,v 1.11 2000/07/10 17:39:26 nilsson Exp $
#ifndef _ROXEN_H_

#define _ROXEN_H_
#include <config.h>
#define HOST_TO_IP 'H'
#define IP_TO_HOST 'I'

#define perror	roxen_perror

// Localization support
#ifndef LOW_LOCALE
# if constant(Locale.translate)
#  define LOW_LOCALE(X,Y)	([string](mixed)Locale.DeferredLocale(GETLOCOBJ,X,Y))
# else
#  define LOW_LOCALE(X,Y)	([string](mixed)RoxenLocale.DeferredLocale(GETLOCOBJ,X,Y))
# endif // Locale.translate
# ifdef IN_ROXEN
#  define LOCALE_PROJECT(X)	static object GETLOCOBJ() {return locale->get()->X;}
# else
#  define LOCALE_PROJECT(X)	static object GETLOCOBJ() {return roxen.locale->get()->X;}
# endif // IN_ROXEN
#endif // !LOW_LOCALE

#endif  /* _ROXEN_H_ */
