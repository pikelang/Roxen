// $Id: roxen.h,v 1.12 2000/07/11 01:46:03 nilsson Exp $
#ifndef _ROXEN_H_

#define _ROXEN_H_
#include <config.h>
#define HOST_TO_IP 'H'
#define IP_TO_HOST 'I'

#define perror	roxen_perror

// Localization support
#ifndef _DEF_LOCALE
# if constant(Locale.translate)
#  define _DEF_LOCALE(X,Y)	([string](mixed)Locale.DeferredLocale(GETLOCOBJ,X,Y))
# else
#  define _DEF_LOCALE(X,Y)	([string](mixed)RoxenLocale.DeferredLocale(GETLOCOBJ,X,Y))
# endif
#endif

#ifndef _STR_LOCALE
# if constant(Locale.translate)
#  ifdef IN_ROXEN
#   define _STR_LOCALE(Z,X,Y)	(Locale.translate(locale->get()->Z, X, Y))
#  else
#   define _STR_LOCALE(Z,X,Y)	(Locale.translate(roxen.locale->get()->Z, X, Y))
#  endif
# else
#  ifdef IN_ROXEN
#   define _STR_LOCALE(Z,X,Y)	(RoxenLocale.translate(locale->get()->Z, X, Y))
#  else
#   define _STR_LOCALE(Z,X,Y)	(RoxenLocale.translate(roxen.locale->get()->Z, X, Y))
#  endif
# endif
#endif

#ifndef LOCALE_PROJECT
# ifdef IN_ROXEN
#  define LOCALE_PROJECT(X)	static inline object GETLOCOBJ() {return locale->get()->X;}
# else
#  define LOCALE_PROJECT(X)	static inline object GETLOCOBJ() {return roxen.locale->get()->X;}
# endif
#endif

#endif  /* _ROXEN_H_ */
