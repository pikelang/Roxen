// $Id: roxen.h,v 1.10 1999/11/06 08:28:44 per Exp $
#ifndef _ROXEN_H_

#define _ROXEN_H_
#include <config.h>
#define HOST_TO_IP 'H'
#define IP_TO_HOST 'I'

#define perror	roxen_perror

// Localization support
#ifndef LOW_LOCALE
#ifdef IN_ROXEN
#define LOW_LOCALE	locale->get()
#define SET_LOCALE(X)	locale->set(X)
#else
#define LOW_LOCALE	roxen.locale->get()
#define SET_LOCALE(X)	roxen.locale->set(X)
#endif /* IN_ROXEN */
#endif /* !LOW_LOCALE */

#endif  /* _ROXEN_H_ */
