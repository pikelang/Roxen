// $Id: roxen.h,v 1.14 2000/07/15 02:27:43 lange Exp $
#ifndef _ROXEN_H_

#define _ROXEN_H_
#include <config.h>
#define HOST_TO_IP 'H'
#define IP_TO_HOST 'I'

#define perror	roxen_perror

// Localization support
#ifndef _STR_LOCALE
# if constant(Locale.translate)
#  ifdef IN_ROXEN
#   define _STR_LOCALE(Z,X,Y)	(Locale.translate(Z, locale->get(), X, Y))
#  else
#   define _STR_LOCALE(Z,X,Y)	(Locale.translate(Z, roxen.locale->get(), X,Y))
#  endif
# else
#  ifdef IN_ROXEN
#   define _STR_LOCALE(Z,X,Y)	(RoxenLocale.translate(Z, locale->get(), X, Y))
#  else
#   define _STR_LOCALE(Z,X,Y)	(RoxenLocale.translate(Z, roxen.locale->get(), X, Y))
#  endif
# endif
#endif

#ifndef _DEF_LOCALE
# if constant(Locale.translate)
#  define _DEF_LOCALE(Z,X,Y)	([string](mixed)Locale.DeferredLocale(Z,GETLOCLANG,X,Y))
# else
#  define _DEF_LOCALE(Z,X,Y)	([string](mixed)RoxenLocale.DeferredLocale(Z,GETLOCLANG,X,Y))
# endif
#endif

#ifndef USE_DEFERRED_LOCALE
# ifdef IN_ROXEN
#  define USE_DEFERRED_LOCALE static inline string GETLOCLANG() {return locale->get();}
# else
#  define USE_DEFERRED_LOCALE static inline string GETLOCLANG() {return roxen.locale->get();}
# endif
#endif

#ifndef _LOCALE_FUN
# if constant(Locale.call)
#  ifdef IN_ROXEN
#    define _LOCALE_FUN(X,Y,Z)	Locale.call(X,locale->get(),Y,Z)
#  else
#    define _LOCALE_FUN(X,Y,Z)	Locale.call(X,roxen.locale->get(),Y,Z)
#  endif
# else
#  ifdef IN_ROXEN
#    define _LOCALE_FUN(X,Y,Z)	RoxenLocale.call(X,locale->get(),Y,Z)
#  else
#    define _LOCALE_FUN(X,Y,Z)	RoxenLocale.call(X,roxen.locale->get(),Y,Z)
#  endif
# endif
#endif


#endif  /* _ROXEN_H_ */
