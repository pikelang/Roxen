// -*- pike -*-
//
// $Id: roxen.h,v 1.28 2004/04/21 16:02:49 mast Exp $

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

// Debug macros.

#ifdef DEBUG
#define DO_IF_DEBUG(X...) X
#define ASSERT_IF_DEBUG(TEST, ARGS...) do {				\
    if (!(TEST)) error ("Assertion failed: " #TEST, ARGS);		\
  } while (0)
#else
#define DO_IF_DEBUG(X...)
#define ASSERT_IF_DEBUG(TEST, ARGS...) do {} while (0)
#endif

#ifdef DEBUG_CACHEABLE
#  define CACHE(seconds) do {                                                 \
  int old_cacheable = ([mapping(string:mixed)]id->misc)->cacheable;           \
  ([mapping(string:mixed)]id->misc)->cacheable =                              \
    min(([mapping(string:mixed)]id->misc)->cacheable,seconds);                \
  report_debug("%s:%d lowered cacheable to %d (was: %d, now: %d)\n",          \
               __FILE__, __LINE__, seconds, old_cacheable,                    \
               ([mapping(string:mixed)]id->misc)->cacheable);                 \
} while(0)
#  define RAISE_CACHE(seconds) do {                                           \
  int old_cacheable = ([mapping(string:mixed)]id->misc)->cacheable;           \
  ([mapping(string:mixed)]id->misc)->cacheable =                              \
    max(([mapping(string:mixed)]id->misc)->cacheable,seconds);                \
  report_debug("%s:%d raised cacheable to %d (was: %d, now: %d)\n",           \
               __FILE__, __LINE__, seconds, old_cacheable,                    \
               ([mapping(string:mixed)]id->misc)->cacheable);                 \
} while(0)
#  define NOCACHE() do {                                                      \
  int old_cacheable = ([mapping(string:mixed)]id->misc)->cacheable;           \
  ([mapping(string:mixed)]id->misc)->cacheable = 0;                           \
  report_debug("%s:%d set cacheable to 0 (was: %d)\n",                        \
               __FILE__, __LINE__, old_cacheable,                             \
               ([mapping(string:mixed)]id->misc)->cacheable);                 \
} while(0)
#  define NO_PROTO_CACHE() do {                                               \
  ([mapping(string:mixed)]id->misc)->no_proto_cache = 1;                      \
  report_debug("%s:%d disabled proto cache\n", __FILE__, __LINE__);           \
} while(0)
#  define PROTO_CACHE() do {                                               \
  ([mapping(string:mixed)]id->misc)->no_proto_cache = 0;                      \
  report_debug("%s:%d enabled proto cache\n", __FILE__, __LINE__);            \
} while(0)
#else
#  define CACHE(seconds) ([mapping(string:mixed)]id->misc)->cacheable=min(([mapping(string:mixed)]id->misc)->cacheable,seconds)
#  define RAISE_CACHE(seconds) ([mapping(string:mixed)]id->misc)->cacheable=max(([mapping(string:mixed)]id->misc)->cacheable,seconds)
#  define NOCACHE() ([mapping(string:mixed)]id->misc)->cacheable=0
#  define NO_PROTO_CACHE() ([mapping(string:mixed)]id->misc)->no_proto_cache=1
#  define PROTO_CACHE() ([mapping(string:mixed)]id->misc)->no_proto_cache=0
#endif /* DEBUG_CACHEABLE */

#endif  /* !_ROXEN_H_ */
