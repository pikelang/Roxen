/* -*- Pike -*-
 * $Id: config.h,v 1.18 2000/02/16 16:21:40 mast Exp $
 *
 * User configurable things not accessible from the normal
 * configuration interface. Not much, but there are some things..  
 */

#ifndef _ROXEN_CONFIG_H_
#define _ROXEN_CONFIG_H_

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

#define URL_MODULES

/* Define this to keep support for old (pre-2.0) RXML.
 */
#define OLD_RXML_COMPAT

/*---------------- End of configurable options. */
#endif /* if _ROXEN_CONFIG_H_ */
