// -*- pike -*-
//
// $Id$

#ifndef ROXEN_MODULE_H
#define ROXEN_MODULE_H
/* #include "config.h" */
#include <roxen.h>
// compat
//
// NOTE: This used to be a valid lvalue.
//       In the few places where it was used as an lvalue,
//       use set("var", value).
#define QUERY(var)	query( #var )

// Like query, but for global variables.
#ifdef IN_ROXEN
#define GLOBVAR(x) query( #x )
#else /* !IN_ROXEN */
#define GLOBVAR(x) roxenp()->query(#x)
#endif /* IN_ROXEN */

#define TAGDOCUMENTATION mapping tagdocumentation(){return [mapping]get_value_from_file(__FILE__,"tagdoc","#define manual\n");}

#define ROXEN_MAJOR_VERSION 5
#define ROXEN_MINOR_VERSION 5


#define TYPE_STRING            1
#define TYPE_FILE              2
#define TYPE_INT               3
#define TYPE_DIR               4
#define TYPE_STRING_LIST       5
#define TYPE_MULTIPLE_STRING   5
#define TYPE_INT_LIST          6
#define TYPE_MULTIPLE_INT      6
#define TYPE_FLAG              7
#define TYPE_TOGGLE            7
#define TYPE_DIR_LIST	       9
#define TYPE_FILE_LIST        10
#define TYPE_LOCATION         11
#define TYPE_TEXT_FIELD       13
#define TYPE_TEXT             13
#define TYPE_PASSWORD         14
#define TYPE_FLOAT            15
#define TYPE_MODULE           17
#define TYPE_FONT             19
#define TYPE_CUSTOM           20
#define TYPE_URL              21
#define TYPE_URL_LIST         22

#define VAR_TYPE_MASK        255


#define VAR_EXPERT         0x100
#define VAR_MORE           0x200
#define VAR_DEVELOPER      0x400
#define VAR_INITIAL        0x800
#define VAR_NOT_CFIF      0x1000
#define VAR_INVISIBLE     0x2000

#define VAR_PUBLIC        0x4000
#define VAR_NO_DEFAULT    0x8000

#define MOD_ALLOW	         1
#define MOD_USER	         2
#define MOD_DENY	         3
#define MOD_PROXY_USER	         4
#define MOD_ACCEPT	         5
#define MOD_ACCEPT_USER	 	 6
#define MOD_ACCEPT_PROXY_USER	 7

#define ENCODE_RXML_INT(value, type) \
  (type && type != RXML.t_int ? type->encode ((value), RXML.t_int) : (value))
#define ENCODE_RXML_FLOAT(value, type) \
  ((value) ? (type && type != RXML.t_float ? type->encode ((value), RXML.t_float) : (value)) : RXML.nil)
#define ENCODE_RXML_TEXT(value, type) \
  ((value) ? (type && type != RXML.t_text ? type->encode ((value), RXML.t_text) : (value)) : RXML.nil)
#define ENCODE_RXML_XML(value, type) \
  ((value) ? (type && type != RXML.t_xml ? type->encode ((value), RXML.t_xml) : (value)) : RXML.nil)

#if constant (thread_create)
#  define RXML_CONTEXT (_cur_rxml_context->get())
#else
#  define RXML_CONTEXT (_cur_rxml_context)
#endif

// Debug macros.

#ifdef MODULE_DEBUG
#  define DO_IF_MODULE_DEBUG(code...) code
#else
#  define DO_IF_MODULE_DEBUG(code...)
#endif

#ifdef RXML_VERBOSE
#  define TAG_DEBUG_TEST(test) 1
#elif defined (RXML_REQUEST_VERBOSE)
#  define TAG_DEBUG_TEST(test)						\
  ((test) || RXML_CONTEXT->id && RXML_CONTEXT->id->misc->rxml_verbose)
#else
#  define TAG_DEBUG_TEST(test) (test)
#endif

#endif	// !ROXEN_MODULE_H
