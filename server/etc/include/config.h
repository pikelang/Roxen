/* -*- Pike -*-
 * $Id: config.h,v 1.13 1998/03/26 07:31:03 neotron Exp $
 *
 * User configurable things not accessible from the normal
 * configuration interface. Not much, but there are some things..  
 */

#ifndef _ROXEN_CONFIG_H_
#define _ROXEN_CONFIG_H_


#if efun(thread_create)
// Some OS's (eg Linux) can get severe problems (PANIC)
// if threads are enabled.
//
// If it works, good for you. If it doesn't, too bad.
#ifndef DISABLE_THREADS
#ifdef ENABLE_THREADS
# define THREADS
#endif /* ENABLE_THREADS */
#endif /* !DISABLE_THREADS */
#endif /* efun(thread_create) */


/* Reply 'PONG\r\n' to the query 'PING\r\n'.
 * For performance tests...
 */
#define SUPPORT_PING_METHOD
#define SUPPORT_HTACCESS




/* Lev  What                          Same as defining
 *----------------------------------------------------
 *   1  Module                        MODULE_DEBUG
 *   2  HTTP                          HTTP_DEBUG
 *   8  Hostname                      HOST_NAME_DEBUG
 *   9  Cache                         CACHE_DEBUG
 *  10  Configuration file handling   DEBUG_CONFIG
 *  20  Socket opening/closing        SOCKET_DEBUG
 *  21  Module: Filesystem            FILESYSTEM_DEBUG
 *  22  Module: Proxy                 PROXY_DEBUG
 *  23  Module: Gopher proxy          GOPHER_DEBUG
 *  40  _More_ cache debug            -
 * >40  Probably even more debug
 * 
 * Each higher level also include the debug of the lower levels.
 * Use the defines in the rightmost column if you want to enable
 * specific debug features.  
 * 
 * You can also start roxen with any debug enabled like this:
 * bin/pike -DMODULE_DEBUG -m etc/master.pike roxenloader
 * 
 * Some other debug thingies:
 *  HTACCESS_DEBUG
 *  SSL_DEBUG
 *  NEIGH_DEBUG
 */

// #define MIRRORSERVER_DEBUG
// #define HTACCESS_DEBUG

/* #undef DEBUG_LEVEL */
#ifndef DEBUG_LEVEL
#define DEBUG_LEVEL DEBUG
#endif

#if DEBUG_LEVEL > 19
#ifndef SOCKET_DEBUG
#define SOCKET_DEBUG
#endif
#endif

#ifdef DEBUG
// Make it easier to track what FD's are doing, to be able to find FD leaks.
#define FD_DEBUG
#endif

/* Do we want module level deny/allow security (IP-numbers and usernames). 
 * 1% speed loss, as an average. (That is, if your CPU is used to the max.
 * it probably isn't..)  
 */
#ifndef NO_MODULE_LEVEL_SECURITY
# define MODULE_LEVEL_SECURITY
#endif

/* Roxen neighbourhood
 *
 * Experimental. Currently does not work on all Operating Systems.
 */
// #define ENABLE_NEIGHBOURHOOD

/* If set, the maximum, minimum and average time used to serve
 * requests is logged.
 * This (rusage()) is broken on some systems, and the server will be
 * somewhat ( < 5% ) slower with this enabled.  
 *
 * CURRENTLY NOT SUPPORTED, WORK IN PROGRESS, It _did_ work in 1.0b4 :-)
 */
#undef USE_RUSAGE


/* Define this if you don't want Roxen to use DNS. Note: This
 * doesn't make the server itself faster. It only reduces the netload
 * some. This option turns off ALL ip -> hostname and hostname -> ip
 * conversion. Thus you can't use if if you want to run a proxy. 
 */

#undef NO_DNS


/* This option turns of all ip->hostname lookups. However the
 * hostname->ip lookups are still functional. This _is_ usable
 * if you run a proxy.. :-)
 */

#undef NO_REVERSE_LOOKUP


/* Should we use sete?id instead of set?id?.
 * There _might_ be security problems with the sete?id functions.
 */

#define SET_EFFECTIVE 


/*---------------- End of configurable options. */

#endif /* if _ROXEN_CONFIG_H_ */

/* Should we be compatible with level b9 and below configuration files? */
#undef COMPAT

/*
 * Should support for URL modules be included?
 * I am trying to phase them out, but..
 */
#define URL_MODULES

/* Basically, should it be o.k. to return "string" as a member of
 * the result mapping? This is only for compability.
 * Normally: ([ "data":long_string, "type":"text/html" ]), was
 * ([ "string":long_string, "type":"text/html" ]), please ignore..
 * Do not use this, unless you _really_ want to make your
 * modules unportable :-)
 */
#undef API_COMPAT
