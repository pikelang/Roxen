// -*- pike -*-
//
// $Id$

#ifndef _ROXEN_H_

#define _ROXEN_H_
#include <config.h>
#define HOST_TO_IP 'H'
#define IP_TO_HOST 'I'

#ifndef REQUESTID
#define REQUESTID	id
#endif

// Various useful macros

#define TOSTR2(X)	#X
#define TOSTR(X)	TOSTR2(X)

// Localization support

#ifndef __LOCALEOBJECT
#ifdef IN_ROXEN
string get_locale();
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
    if (!(TEST)) error ("Assertion failed: " #TEST "\n", ARGS);		\
  } while (0)
#else
#define DO_IF_DEBUG(X...)
#define ASSERT_IF_DEBUG(TEST, ARGS...) do {} while (0)
#endif

// These macros are for compatibility. The recommended way is to call
// the functions in RequestID directly instead.
#define CACHE(seconds) REQUESTID->lower_max_cache (seconds)
#define RAISE_CACHE(seconds) REQUESTID->raise_max_cache (seconds)
#define NOCACHE() REQUESTID->set_max_cache (0)

#ifdef DEBUG_CACHEABLE
#  define NO_PROTO_CACHE() do {						\
    ([mapping(string:mixed)]REQUESTID->misc)->no_proto_cache = 1;	\
    report_debug("%s:%d disabled proto cache\n", __FILE__, __LINE__);	\
  } while(0)
#  define PROTO_CACHE() do {						\
    ([mapping(string:mixed)]REQUESTID->misc)->no_proto_cache = 0;	\
    report_debug("%s:%d enabled proto cache\n", __FILE__, __LINE__);	\
  } while(0)
#else
#  define NO_PROTO_CACHE()					\
  ([mapping(string:mixed)]REQUESTID->misc)->no_proto_cache = 1
#  define PROTO_CACHE()						\
  ([mapping(string:mixed)]REQUESTID->misc)->no_proto_cache = 0
#endif /* DEBUG_CACHEABLE */

// The OBJ_COUNT_DEBUG define adds a suffix "[xxx]" to the end of many
// _sprintf('O') strings, where xxx is a unique number for the object
// instance. Useful to see the real lifetime of objects.
#ifdef OBJ_COUNT_DEBUG
#define DECLARE_OBJ_COUNT \
  protected int __object_count = ++all_constants()->_obj_count
#define OBJ_COUNT ("[" + this_program::__object_count + "]")
#else
#define DECLARE_OBJ_COUNT ;
#define OBJ_COUNT ""
#endif

#endif  /* !_ROXEN_H_ */
