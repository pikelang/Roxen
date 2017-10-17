#ifndef ACME_H
#define ACME_H

#ifdef ACME_DEBUG
# define TRACE(X...)werror("%s:%d: %s",basename(__FILE__),__LINE__,sprintf(X))
#else
# define TRACE(X...)0
#endif

#endif
