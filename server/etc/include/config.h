/* -*- Pike -*-
 * $Id$
 *
 * User configurable things not accessible from the normal
 * administration interface. Not much, but there are some things..  
 */


#ifndef _ROXEN_CONFIG_H_
#define _ROXEN_CONFIG_H_



//  If you are running an MySQL older than 3.23.49 (which lacks a patch for
//  a security hole in LOAD DATA LOCAL) you need to set this compatibility
//  flag.
//
//  #define UNSAFE_MYSQL


#if constant(thread_create)
// If it works, good for you. If it doesn't, too bad.
#ifndef DISABLE_THREADS
#ifdef ENABLE_THREADS
# define THREADS
#endif /* ENABLE_THREADS */
#endif /* !DISABLE_THREADS */
#endif /* constant(thread_create) */
#define add_efun add_constant

/* Reply 'PONG\r\n' to the query 'PING\r\n'.
 * For performance tests...
 */
#define SUPPORT_PING_METHOD

/* Do we want module level deny/allow security (IP-numbers and usernames). 
 * 1% speed loss, as an average. (That is, if your CPU is used to the max.
 * it probably isn't..)  
 */
#ifndef NO_MODULE_LEVEL_SECURITY
# define MODULE_LEVEL_SECURITY
#endif

/* If this is disabled, the server won't parse the supports string. This might
 * make the server somewhat faster. If you don't need this feature but need the
 * most speed you can get, it might be a good idea to disable supports.
 */

// #define DISABLE_SUPPORTS


/* Define this if you don't want Roxen to use DNS. Note: This
 * doesn't make the server itself faster. It only reduces the netload
 * some. This option turns off ALL ip -> hostname and hostname -> ip
 * conversion. Thus you can't use if if you want to run a proxy. 
 */

// #undef NO_DNS


/* This option turns of all ip->hostname lookups. However the
 * hostname->ip lookups are still functional. This _is_ usable
 * if you run a proxy.. :-)
 */

// #undef NO_REVERSE_LOOKUP


/* Should we use sete?id instead of set?id?.
 * There _might_ be security problems with the sete?id functions.
 */
#define SET_EFFECTIVE 

#define URL_MODULES

/* Define this to change the main RAM cache retention policy
 * to be based on the time it took to generate the entry and
 * the number of hits it has received.
 */
// #define TIME_BASED_CACHE

/* The namespace prefix for RXML.
 */
#define RXML_NAMESPACE "rxml"

/* Define this to keep support for old (pre-2.0) RXML.
 */
#define OLD_RXML_COMPAT

/* Define this to enable the RoxenConfig cooke */
#define OLD_RXML_CONFIG

// Define to get verbose backtraces in the debug log for each RXML
// error. As opposed to the normal reports of RXML errors, they will
// include the Pike backtraces too.
//#define VERBOSE_RXML_ERRORS

// Define back to which Roxen version you would like to keep 
// compatibility.
#define ROXEN_COMPAT 1.3


//  Cache timeout for RAM cache
#ifndef INITIAL_CACHEABLE
# define INITIAL_CACHEABLE 300
#endif

#ifndef HTTP_BLOCKING_SIZE_THRESHOLD
// Size at below which blocking writes may be performed without penalty.
// Should correspond to the network buffer size (usually 4KB or 1500 bytes).
// Set to zero or negative to always use nonblocking I/O.
#define HTTP_BLOCKING_SIZE_THRESHOLD	1000
#endif /* !HTTP_BLOCKING_SIZE_THRESHOLD */

/*---------------- End of configurable options. */
#endif /* if _ROXEN_CONFIG_H_ */
